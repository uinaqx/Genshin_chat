import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";

const DATA_PATH = new URL("../data/characters.json", import.meta.url);
const MANIFEST_PATH = new URL(
  "../third_party/Genshin.Skill/MANIFEST.json",
  import.meta.url,
);
const SKILLS_ROOT = new URL("../third_party/Genshin.Skill/skills/", import.meta.url);
const EXPECTED_PROJECT = "DGP-Studio/Genshin.Skill";
const EXPECTED_COMMIT = "1abc5c9f8daa5a98ecc7e02472cb82ea1047d10e";

const data = JSON.parse(await readFile(DATA_PATH, "utf8"));
const manifest = JSON.parse(await readFile(MANIFEST_PATH, "utf8"));
const characters = new Map(data.characters.map((character) => [character.id, character]));
const failures = [];

if (manifest.project !== EXPECTED_PROJECT) {
  failures.push(`清单项目名错误：${manifest.project}`);
}
if (manifest.commit !== EXPECTED_COMMIT) {
  failures.push(`清单提交版本错误：${manifest.commit}`);
}
if (manifest.license !== "MIT") failures.push("清单未声明 MIT 许可");
if (manifest.files.length !== 97) {
  failures.push(`清单应含 97 份文件，实际 ${manifest.files.length} 份`);
}

const sourceDirectories = (await readdir(SKILLS_ROOT, { withFileTypes: true }))
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort();
const manifestDirectories = manifest.files
  .map((entry) => entry.sourcePath.split("/")[0])
  .sort();
if (JSON.stringify(sourceDirectories) !== JSON.stringify(manifestDirectories)) {
  failures.push("本地 SKILL 目录与导入清单不一致");
}

const requiredPromptSections = [
  "【最高优先级身份】",
  "【人物本质】",
  "【经历与当前剧情】",
  "【与旅行者】",
  "【确认的人物关系】",
  "【未知关系边界】",
  "【语言与聊天方式】",
  "【原作语气锚点】",
  "【诚实与事实边界】",
];
const requiredSourceHeadings = [
  "## 角色扮演规则（最重要）",
  "## 身份卡",
  "## 核心心智模型",
  "## 人物时间线（关键节点）",
  "## 诚实边界",
  "## 关系图谱",
  "### 关键引用",
];

for (const entry of manifest.files) {
  const prefix = `${entry.characterId} (${entry.characterName})`;
  const character = characters.get(entry.characterId);
  if (!character) {
    failures.push(`${prefix}: 在角色数据库中不存在`);
    continue;
  }

  const raw = await readFile(new URL(entry.sourcePath, SKILLS_ROOT), "utf8");
  const hash = createHash("sha256").update(raw).digest("hex");
  if (hash !== entry.sha256) failures.push(`${prefix}: 上游文件哈希不一致`);
  for (const heading of requiredSourceHeadings) {
    if (!raw.includes(heading)) failures.push(`${prefix}: 上游文件缺少 ${heading}`);
  }
  if (!/## 表达\s*DNA/.test(raw)) failures.push(`${prefix}: 上游文件缺少表达 DNA`);

  if ((character.prompt || "").length < 1000) {
    failures.push(`${prefix}: 私聊提示词不足 1000 字符`);
  }
  if ((character.groupPrompt || "").length < 700) {
    failures.push(`${prefix}: 群聊提示词不足 700 字符`);
  }
  if ((character.soulMd || "").length < 6000) {
    failures.push(`${prefix}: SoulMD 不足 6000 字符`);
  }
  for (const section of requiredPromptSections) {
    if (!character.prompt?.includes(section)) {
      failures.push(`${prefix}: 私聊提示词缺少 ${section}`);
    }
  }
  if (!character.prompt?.includes("用户就是旅行者")) {
    failures.push(`${prefix}: 未锁定用户的旅行者身份`);
  }
  if (!character.groupPrompt?.includes("用户就是旅行者")) {
    failures.push(`${prefix}: 群聊提示词未锁定旅行者身份`);
  }
  if (!character.soulMd?.includes(stripFrontmatter(raw).trim())) {
    failures.push(`${prefix}: SoulMD 未完整保存上游正文`);
  }
  if (character.promptProvenance?.project !== EXPECTED_PROJECT) {
    failures.push(`${prefix}: 来源项目记录错误`);
  }
  if (character.promptProvenance?.commit !== EXPECTED_COMMIT) {
    failures.push(`${prefix}: 来源提交记录错误`);
  }
  if (character.promptProvenance?.path !== entry.sourcePath) {
    failures.push(`${prefix}: 来源路径记录错误`);
  }
  if (character.promptProvenance?.license !== "MIT") {
    failures.push(`${prefix}: 来源许可记录错误`);
  }
  const pinnedSource = `https://github.com/${EXPECTED_PROJECT}/blob/${EXPECTED_COMMIT}/${entry.sourcePath}`;
  if (!character.promptSources?.includes(pinnedSource)) {
    failures.push(`${prefix}: 缺少固定提交版本的来源链接`);
  }
}

const importedCharacters = data.characters.filter(
  (character) => character.promptProvenance?.project === EXPECTED_PROJECT,
);
const uncoveredCharacters = data.characters.filter(
  (character) =>
    !character.id.startsWith("traveler-") &&
    character.promptProvenance?.project !== EXPECTED_PROJECT,
);
if (importedCharacters.length !== manifest.files.length) {
  failures.push(
    `数据库导入角色数 ${importedCharacters.length} 与清单 ${manifest.files.length} 不一致`,
  );
}
if (data.promptImport?.importedCharacters !== manifest.files.length) {
  failures.push("数据库顶部的导入数量与清单不一致");
}
if (data.promptImport?.uncoveredCharacters?.length !== uncoveredCharacters.length) {
  failures.push("数据库顶部的未覆盖角色数量不一致");
}

console.log(`DGP 角色提示词导入审计：${manifest.files.length} 份`);
console.log(`未被上游仓库覆盖：${uncoveredCharacters.length} 名`);
if (uncoveredCharacters.length) {
  console.log(
    `未覆盖名单：${uncoveredCharacters.map((character) => character.name).join("、")}`,
  );
}
if (failures.length) {
  console.error(`\n发现 ${failures.length} 个错误：`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log("\n97 份上游文件、哈希、映射、完整正文与聊天适配全部校验通过。");
}

function stripFrontmatter(value) {
  return value.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, "");
}
