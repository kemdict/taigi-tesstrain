import fs from "node:fs";
import { parseArgs } from "node:util";

const articles = JSON.parse(
  fs.readFileSync("pojbh.json", { encoding: "utf-8" }),
) as Array<{
  hanlo: string[];
  pianho: string;
  tailo: string[];
  作者: string;
  刊名: string;
  卷期: string;
  日期: string;
  本次: string;
  篇名: string;
  頁數: string;
}>;

const parsedArgs = parseArgs({
  args: process.argv.slice(2),
  allowPositionals: true,
  options: {
    help: { type: "boolean", short: "h" },
  },
});

if (parsedArgs.values.help) {
  console.log(`extract.ts <dir>
Extract articles to <dir>.`);
  process.exit(0);
}
const dir = parsedArgs.positionals[0];
if (!dir) {
  console.log("Dir not provided");
  process.exit(1);
}

const buckets: string[][] = [];
for (let i = 0; i < articles.length; i++) {
  const article = articles[i];
  const size = 100;
  const bucketIndex = Math.floor(i / size);
  buckets[bucketIndex] ||= [];
  const bucket = buckets[bucketIndex];

  // not perfect, eg. "許Khó-niá Khó͘ Khó-niá" becomes "Khó-niá Khó͘ Khó-niá" even
  // though it should be just Khó͘ Khó-niá
  // but for recognition this should be fine?
  const author = article.作者
    .replaceAll(/[、\p{Script=Han}]/gv, "")
    .replaceAll("，", ", ")
    .replaceAll("/", " ")
    .replaceAll(/  +/g, " ")
    .trim();
  const title = article.篇名.replace(/^.*\[ (.*) \]$/, "$1");
  bucket.push(title);
  if (author) bucket.push(author);
  bucket.push(article.日期);
  for (const line of article.tailo) {
    bucket.push(
      line
        .replaceAll("（", " (")
        .replaceAll("）", ")")
        .replaceAll(" ", " ")
        .replaceAll(/^([a-z\d]+)\.([^ ])/g, "$1. $2"),
    );
  }
  bucket.push("");
}

for (let i = 0; i < buckets.length; i++) {
  const bucket = buckets[i];
  fs.writeFileSync(`${dir}/ftg.training_text.${i}.poj`, bucket.join("\n"));
}

fs.writeFileSync(
  `${dir}/ftg.training_text.all.poj`,
  buckets.map((bucket) => bucket.join("\n")).join("\n"),
);
