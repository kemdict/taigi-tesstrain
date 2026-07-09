#!/usr/bin/env node
import { Command } from "@commander-js/extra-typings";
import { existsSync, mkdtempDisposableSync } from "node:fs";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { $ } from "zx";

const $$ = $({ verbose: true });

function err(msg: string): never {
  console.log(msg);
  process.exit(1);
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
    }
    return file.substring(0, match.index);
  } else {
    return filename;
  }
}

async function splitLines(file: string) {
  if (!existsSync(file)) err(`File ${file} does not exist`);

  using tmpdir = mkdtempDisposableSync("hocr");
  await $$`tesseract ${file} ${path.join(tmpdir.path, "outbase")} ${[
    ...["--psm", "single_block"],
    ...["--oem", "lstm_only"],
    ...["-l", "eng"],
    ...["-c", "page_separator=''"],
    "hocr",
  ]}`;
  await $$`uv run hocr-extract-images ${path.join(tmpdir.path, "outbase.hocr")} ${[
    "--pattern",
    `${path.basename(file, ".png")}-line-%03d.png`,
  ]}`;
}

/** Download file from `url` and write it to `path`. */
async function downloadOne(path: string, url: string) {
  if (existsSync(path)) return;
  console.log(`Downloading ${path} from ${url}...`);
  await $$`wget -O ${path} ${url}`;
}

async function populateInitialGt() {
  downloadOne(
    "data/ftg-best.traineddata",
    "https://github.com/kemdict/taigi-tesstrain/releases/download/v0.1.5/ftg-best.traineddata",
  );

  const groundTruthDir = "data/ftg-ground-truth/";
  const images = (
    await $`find ${groundTruthDir} ${
      // prettier-ignore
      [
      "(",
      "-path", "*.png",
      "-or", "-path", "*.tif",
      "-or", "-path", "*.JPG",
      ")",
      ]
    }`
  ).stdout
    .split("\n")
    .filter(Boolean);

  for (const file of images) {
    const noExt = fNoExt(file);
    const gtFile = `${noExt}.gt.txt`;
    if (existsSync(gtFile)) continue;
    console.log(`Creating ${gtFile}...`);
    await $$`tesseract --tessdata-dir data -l ftg-best ${file} ${noExt}.gt`;
  }
}

interface VggData {
  [name: string]: {
    filename: string,
    size: number,
    regions: Array<{
      shape_attributes: {
        name: string,
        x: number,
        y: number,
        width: number,
        height: number,
      },
    }>,
  };
}

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

/**
 * Convert VGG exported `data` into boxes.
 * This needs to be able to read the image files. They are assumed to be in
 * `basedir`.
 */
async function convertVggToBoxes(data: VggData, basedir: string) {
  for (const [_, obj] of Object.entries(data)) {
    const filename = path.join(basedir, obj.filename);
    const fileHeight = (await dims(filename))?.height;
    if (!fileHeight) {
      console.log(`Unable to read ${filename}, skipping...`);
      continue;
    }
    const gt = (
      await readFile(`${fNoExt(filename)}.gt.txt`, {
        encoding: "utf-8",
      })
    ).split("\n");
    let buf = "";
    for (let i = 0; i < obj.regions.length; i++) {
      const region = obj.regions[i];
      const line = gt[i];
      if (region.shape_attributes.name !== "rect") continue;
      const { x, width, height } = region.shape_attributes;
      // y value from the annotator output has 0 = top, whereas tesseract boxes
      // have 0 = bottom
      const y = fileHeight - region.shape_attributes.y;
      for (const char of [...line]) {
        buf += `${char} ${x} ${y} ${x + width} ${y + height}\n`;
      }
      buf += `\t ${x + width} ${y + height - 1} ${x + width + 1} ${y + height}\n`;
    }
    console.log(`Written ${fNoExt(filename)}.box`);
    await writeFile(fNoExt(filename) + ".box", buf);
  }
}

const program = new Command();

program
  .command("image-split-lines")
  .description(
    "Split an image into multiple images each containing one line using Tesseract.",
  )
  .argument("<file>", "image file to split")
  .action(splitLines);

program
  .command("populate-initial-gt")
  .description(
    "Run tesseract on images to get initial ground truth text for later editing.",
  )
  .action(populateInitialGt);

program
  .command("vgg-convert-to-boxes")
  .description(
    "Convert JSON exported from VGG Image Annotator into box files in basedir.",
  )
  .argument("<json>", "VGG Image Annotator JSON export")
  .argument(
    "<basedir>",
    "directory containing the image and ground truth files",
  )
  .action(async (exported: string, basedir: string) => {
    if (!existsSync(exported)) err("The data file specified does not exist");
    if (!existsSync(basedir))
      err("The base directory for output box files does not exist");
    await convertVggToBoxes(
      JSON.parse(await readFile(exported, { encoding: "utf-8" })),
      basedir,
    );
  });

program
  .command("clean")
  .description("Clean up the workspace (but keep downloaded stuff around)")
  .action(async () => {
    await $$`git clean -xdf ${["data/ftg-ground-truth", "data/ftg", "data/langdata/ftg"]}`;
  });

await program.parseAsync();
