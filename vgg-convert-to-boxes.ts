import { $ } from "zx";
import { writeFile } from "node:fs/promises";
import path from "node:path";

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
 * Assumes all files are located within `basedir`.
 */
async function convert(data: Data, basedir: string) {
  for (const [_, obj] of Object.entries(data)) {
    const filename = obj.filename;
    const fileHeight = (await dims(filename))?.height;
    if (!fileHeight) continue;
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
    await writeFile(path.join(basedir, fNoExt(filename) + ".box"), buf);
  }
}
