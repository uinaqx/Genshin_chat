import { createHash } from "node:crypto";
import { readdir, readFile, writeFile } from "node:fs/promises";

const DATA_PATH = new URL("../data/characters.json", import.meta.url);
const PROFILE_ROOT = new URL(
  "../third_party/curated-prompts/profiles/",
  import.meta.url,
);
const MANIFEST_PATH = new URL(
  "../third_party/curated-prompts/MANIFEST.json",
  import.meta.url,
);
const SOURCES_PATH = new URL(
  "../third_party/curated-prompts/SOURCES.json",
  import.meta.url,
);
const EXPECTED_PROJECT = "Teyvat WeChat curated character profiles";

const data = JSON.parse(await readFile(DATA_PATH, "utf8"));
const manifest = JSON.parse(await readFile(MANIFEST_PATH, "utf8"));
const sources = JSON.parse(await readFile(SOURCES_PATH, "utf8"));
const profileFiles = (await readdir(PROFILE_ROOT))
  .filter((file) => file.endsWith(".json"))
  .sort();
if (profileFiles.length !== 30) {
  throw new Error(`应有 30 份项目补充档案，实际 ${profileFiles.length} 份`);
}
if (manifest.project !== EXPECTED_PROJECT || manifest.profiles.length !== 30) {
  throw new Error("补充档案清单不完整或项目名错误");
}

const characters = new Map(data.characters.map((character) => [character.id, character]));
const sourceById = new Map(sources.characters.map((character) => [character.id, character]));
const imported = [];

for (const file of profileFiles) {
  const raw = await readFile(new URL(file, PROFILE_ROOT), "utf8");
  const profile = JSON.parse(raw);
  const manifestEntry = manifest.profiles.find((entry) => entry.id === profile.id);
  const character = characters.get(profile.id);
  const source = sourceById.get(profile.id);
  if (!manifestEntry || !character || !source) {
    throw new Error(`${profile.id}: 档案、角色数据库与来源清单映射不完整`);
  }
  const hash = createHash("sha256").update(raw).digest("hex");
  if (hash !== manifestEntry.sha256) {
    throw new Error(`${profile.id}: 档案哈希与清单不一致`);
  }

  character.name = profile.name;
  character.description = profile.publicDescription;
  character.prompt = profile.prompt;
  character.groupPrompt = profile.groupPrompt;
  character.soulMd = profile.soulMd;
  character.promptSources = profile.promptSources;
  character.promptUpdatedAt = profile.promptUpdatedAt;
  character.promptVersion = profile.promptVersion;
  character.promptProvenance = profile.promptProvenance;
  imported.push({ id: profile.id, name: profile.name });
}

data.note =
  "角色基础资料来自 genshin.dev 镜像；97 名角色使用 DGP-Studio/Genshin.Skill 完整设定，另有 30 名角色使用项目基于当前 BWIKI 资料整理的中文私聊 Prompt、群聊 Prompt 与 SoulMD。";
data.curatedPromptImport = {
  project: EXPECTED_PROJECT,
  version: manifest.version,
  generatedAt: manifest.generatedAt,
  generatedWith: manifest.generatedWith,
  source: sources.source,
  sourceBaseUrl: sources.sourceBaseUrl,
  sourceLicense: sources.sourceLicense,
  sourceRetrievedAt: sources.retrievedAt,
  importedCharacters: imported.length,
  characters: imported,
};

if (data.promptImport?.uncoveredCharacters) {
  data.promptImport.uncoveredCharacters = data.promptImport.uncoveredCharacters.map(
    (entry) => ({
      id: entry.id,
      name: characters.get(entry.id)?.name || entry.name,
    }),
  );
}

await writeFile(DATA_PATH, `${JSON.stringify(data, null, 2)}\n`, "utf8");
console.log(`已将 ${imported.length} 份项目补充角色档案写入角色数据库。`);
