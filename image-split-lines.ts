import { parseArgs } from "node:util";
import { $ } from "zx";
import { existsSync, mkdtempDisposableSync } from "node:fs";
import path from "node:path";

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
  console.log(`image-split-lines.ts <file>

Split an image into multiple images each containing one line using Tesseract.

Options:
  --help: show help (this message)`);
  process.exit(0);
}
const file = parsedArgs.positionals[0];
if (!file) err("File must be provided");
if (!existsSync(file)) err(`File ${file} does not exist`);

using tmpdir = mkdtempDisposableSync("hocr");

const $$ = $({ verbose: true });
await $$`tesseract ${file} ${path.join(tmpdir.path, "outbase")} ${[
  ...["--psm", "single_block"],
  ...["--oem", "lstm_only"],
  ...["-l", "eng"],
  ...["-c", "page_separator=''"],
  "hocr",
]}`;
await $$`uv run hocr-extract-images ${path.join(tmpdir.path, "outbase.hocr")} ${[
  "--pattern",
  `${path.basename(file)}-line-%03d.png`,
]}`;
