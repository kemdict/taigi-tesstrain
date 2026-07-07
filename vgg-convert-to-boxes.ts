import { $ } from "zx";
import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";

/** Return the width and height of `file`. */
async function dims(file: string) {
  try {
    const [w, h] = (await $`file ${file}`).stdout
      .trim()
      .split(", ")[7]
      .split("x");
    return { width: parseInt(w), height: parseInt(h) };
  } catch (_e) {
    return undefined;
  }
}

interface Data {
  [name: string]: {
    filename: string;
    size: number;
    regions: Array<{
      shape_attributes: {
        name: string;
        x: number;
        y: number;
        width: number;
        height: number;
      };
    }>;
  };
}

// Port of f-no-ext / file-name-sans-extension
// I still want an f.el equivalent in JS...
function fNoExt(filename: string) {
  const file = path.basename(filename);
  const match = file.match(/\.[^.]*$/);
  if (match && match.index !== 0) {
    const directory = path.dirname(filename);
    if (directory) {
      return path.join(directory, file.substring(0, match.index));
    } else {
      return file.substring(0, match.index);
    }
  } else {
    return filename;
  }
}

/**
 * Convert VGG exported `data` into boxes.
 * This needs to be able to read the image files. They are assumed to be in
 * `basedir`.
 */
async function convert(data: Data, basedir: string) {
  for (const [_, obj] of Object.entries(data)) {
    const filename = path.join(basedir, obj.filename);
    const fileHeight = (await dims(filename))?.height;
    if (!fileHeight) {
      console.log(`Unable to read ${filename}, skipping...`);
      continue;
    }
    let buf = "";
    for (const region of obj.regions) {
      if (region.shape_attributes.name !== "rect") continue;
      const { x, width, height } = region.shape_attributes;
      // y value from the annotator output has 0 = top, whereas tesseract boxes
      // have 0 = bottom
      const y = fileHeight - region.shape_attributes.y;
      buf += `a ${x} ${y} ${x + width} ${y + height}\n`;
      buf += `\t ${x + width} ${y + height} ${x + width + 1} ${y + height + 1}\n`;
    }
    await writeFile(fNoExt(filename) + ".box", buf);
  }
}

function err(msg: string): never {
  console.log(msg);
  process.exit(1);
}

const parsedArgs = parseArgs({
  args: process.argv.slice(2),
  allowPositionals: true,
  options: {
    help: { type: "boolean", short: "h" },
  },
});

if (parsedArgs.values.help) {
  console.log(`vgg-convert-to-boxes.ts json basedir
Convert \`json\` exported from VGG Image Annotator into box files in \`basedir\`.

Options:
  -h, --help: show help (this string)`);
  process.exit(0);
}
if (parsedArgs.positionals.length !== 2) {
  err("Please specify exactly two arguments");
}
const [exported, basedir] = parsedArgs.positionals;
if (!existsSync(exported)) {
  err("The data file specified does not exist");
}
if (!existsSync(basedir)) {
  err("The base directory for output box files does not exist");
}

await convert(
  JSON.parse(await readFile(exported, { encoding: "utf-8" })),
  basedir,
);
