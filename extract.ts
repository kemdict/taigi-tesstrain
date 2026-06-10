import fs from "node:fs";
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

const lines: string[] = [];
for (const article of articles) {
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
  lines.push(title);
  if (author) lines.push(author);
  lines.push(article.日期);
  for (const line of article.tailo) {
    lines.push(
      line
        .replaceAll("（", " (")
        .replaceAll("）", ")")
        .replaceAll(" ", " ")
        .replaceAll(/^([a-z\d]+)\.([^ ])/g, "$1. $2"),
    );
  }
  lines.push("");
}

process.stdout.write(lines.join("\n"));
