import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const sourcePath = path.join(root, "data", "characters.json");
const targetPath = path.join(root, "assets", "data", "characters.json");
const source = JSON.parse(await readFile(sourcePath, "utf8"));

if (!Array.isArray(source.characters)) {
  throw new Error("data/characters.json 缺少 characters 数组");
}

const chatable = source.characters.filter(
  (character) => !String(character.id ?? "").startsWith("traveler-"),
);
const incomplete = chatable.filter(
  (character) =>
    !String(character.prompt ?? "").trim() ||
    !String(character.soulMd ?? "").trim() ||
    !String(character.groupPrompt ?? "").trim(),
);

if (chatable.length !== 127 || incomplete.length > 0) {
  throw new Error(
    `角色资料校验失败：可聊天角色 ${chatable.length}，资料不完整 ${incomplete
      .map((character) => character.id)
      .join(", ") || "0"}`,
  );
}

await mkdir(path.dirname(targetPath), { recursive: true });
await writeFile(targetPath, `${JSON.stringify(source, null, 2)}\n`, "utf8");

console.log(
  `已同步 ${source.characters.length} 条记录，其中 ${chatable.length} 名角色可聊天。`,
);
