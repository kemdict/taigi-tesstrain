import { parseArgs } from "node:util";
import { readFileSync, mkdirSync, existsSync } from "node:fs";
import { writeFile } from "node:fs/promises";
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
    outdir: { type: "string" },
    base: { type: "string" },
  },
});
if (parsedArgs.values.help) {
  console.log(`splitFile.ts <file> --outdir <dir>

Split a file into multiple files in outdir, one for each non-empty line.

Options:
  --outdir <dir>: output directory
  --base: output file base name
  --help: show help (this message)`);
  process.exit(0);
}
const input = parsedArgs.positionals[0];
const outdir = parsedArgs.values.outdir;
const base = parsedArgs.values.base;
if (!input) err("Input must be provided");
if (!existsSync(input)) err("Input file does not exist");
if (!base) err("Output basename must be provided");
if (!outdir) err("Output directory must be provided");
mkdirSync(outdir, { recursive: true });

// similar logic to pytesstrain's create_ground_truth
// https://github.com/wincentbalin/pytesstrain/blob/7d9237bba/pytesstrain/cli/create_ground_truth.py
const lines = readFileSync(input, { encoding: "utf-8" }).split(/\r?\n/);
for (let i = 1; i < lines.length; i++) {
  const line = lines[i].trimEnd();
  // skip empty lines
  if (line === "") continue;
  await writeFile(path.join(outdir, `${base}.${i + 1}.txt`), line + "\n");
}
