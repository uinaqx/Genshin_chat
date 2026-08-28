import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";

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
const VERIFICATION_PATH = new URL(
  "../third_party/curated-prompts/VERIFICATION.json",
  import.meta.url,
);
const EXPECTED_PROJECT = "Teyvat WeChat curated character profiles";
const REQUIRED_IDS = [
  "aloy",
  "baizhu",
  "gaming",
  "rosaria",
  "mika",
  "mona",
  "sucrose",
  "shenhe",
  "xianyun",
  "yaoyao",
  "eula",
  "yun-jin",
  "lan-yan",
  "dahlia",
  "durin",
  "zibai",
  "varka",
  "lohen",
  "prune",
  "vodyanitsa",
  "alyosha",
  "odette",
  "valeriy",
  "pulcinella",
  "pantalone",
  "vesna",
  "danica",
  "noy",
  "mitya",
  "tsaritsa",
];
const promptSections = [
  "【身份锁定】",
  "【角色核心】",
  "【经历与当下】",
  "【与旅行者的关系】",
  "【确认关系网】",
  "【语言DNA】",
  "【微信聊天执行】",
  "【原作语气锚点】",
  "【示例回复】",
  "【未知边界】",
];
const soulSections = [
  "## 身份与世界锚点",
  "## 人格内核与矛盾",
  "## 经历与当前时间线",
  "## 与旅行者",
  "## 已确认关系网",
  "## 日常生活与自主性",
  "## 能做什么与不能做什么",
  "## 语言 DNA",
  "## 原作短句锚点",
  "## 微信聊天行为",
  "## 记忆与关系变化",
  "## 示例回复",
  "## 事实与未知边界",
  "## 资料来源",
];

const data = JSON.parse(await readFile(DATA_PATH, "utf8"));
const manifest = JSON.parse(await readFile(MANIFEST_PATH, "utf8"));
const sources = JSON.parse(await readFile(SOURCES_PATH, "utf8"));
const verification = JSON.parse(await readFile(VERIFICATION_PATH, "utf8"));
const byId = new Map(data.characters.map((character) => [character.id, character]));
const sourceById = new Map(sources.characters.map((character) => [character.id, character]));
const verificationById = new Map(
  verification.characters.map((character) => [character.id, character]),
);
const failures = [];
const profileFiles = (await readdir(PROFILE_ROOT))
  .filter((file) => file.endsWith(".json"))
  .sort();

if (manifest.project !== EXPECTED_PROJECT) failures.push("档案项目名错误");
if (manifest.profiles.length !== 30) failures.push("档案清单不是 30 份");
if (profileFiles.length !== 30) failures.push("profiles 目录不是 30 份");
if (sources.characters.length !== 30) failures.push("来源清单不是 30 名角色");
if (verification.characters.length !== 30) failures.push("逐角色验证清单不是 30 份");
if (JSON.stringify([...REQUIRED_IDS].sort()) !== JSON.stringify(manifest.profiles.map((entry) => entry.id).sort())) {
  failures.push("档案角色 ID 集合不正确");
}
if (JSON.stringify([...REQUIRED_IDS].sort()) !== JSON.stringify(sources.characters.map((entry) => entry.id).sort())) {
  failures.push("来源角色 ID 集合不正确");
}

const descriptions = new Set();
const specificSignatures = new Set();
for (const entry of manifest.profiles) {
  const raw = await readFile(new URL(`${entry.id}.json`, PROFILE_ROOT), "utf8");
  const profile = JSON.parse(raw);
  const character = byId.get(entry.id);
  const source = sourceById.get(entry.id);
  const proof = verificationById.get(entry.id);
  const prefix = `${entry.id} (${profile.name})`;
  if (!character || !source || !proof) {
    failures.push(`${prefix}: 数据库、来源或验证映射缺失`);
    continue;
  }
  const hash = createHash("sha256").update(raw).digest("hex");
  if (hash !== entry.sha256) failures.push(`${prefix}: 档案哈希错误`);
  if (hash !== proof.profileSha256) failures.push(`${prefix}: 验证清单中的档案哈希错误`);
  const expectedSourceHashes = source.sources.map((item) => item.sha256);
  if (JSON.stringify(proof.sourceSha256) !== JSON.stringify(expectedSourceHashes)) {
    failures.push(`${prefix}: 验证清单中的来源快照哈希错误`);
  }
  if (profile.prompt.length < 2200) failures.push(`${prefix}: Prompt 少于 2200 字符`);
  if (profile.groupPrompt.length < 800) failures.push(`${prefix}: 群聊 Prompt 少于 800 字符`);
  if (profile.soulMd.length < 4200) failures.push(`${prefix}: SoulMD 少于 4200 字符`);
  if (profile.publicDescription.length < 25 || profile.publicDescription.length > 180) {
    failures.push(`${prefix}: 公开简介长度异常`);
  }
  for (const section of promptSections) {
    if (!profile.prompt.includes(section)) failures.push(`${prefix}: 缺少 ${section}`);
  }
  for (const section of soulSections) {
    if (!profile.soulMd.includes(section)) failures.push(`${prefix}: 缺少 ${section}`);
  }
  for (const [label, content] of [
    ["Prompt", profile.prompt],
    ["群聊 Prompt", profile.groupPrompt],
    ["SoulMD", profile.soulMd],
  ]) {
    if (!content.includes("用户就是旅行者")) {
      failures.push(`${prefix}: ${label} 未锁定旅行者身份`);
    }
    if (!content.includes(profile.name)) {
      failures.push(`${prefix}: ${label} 未包含正式角色名`);
    }
  }
  const sampleBlock = profile.prompt.split("【示例回复】")[1]?.split("【未知边界】")[0] || "";
  if ((sampleBlock.match(/^[-*]\s+/gm) || []).length < 12) {
    failures.push(`${prefix}: 示例回复少于 12 条`);
  }
  if (/角色语气核心：|如果只是闲聊，我可以听一会儿/.test(profile.prompt)) {
    failures.push(`${prefix}: 仍含旧版占位模板`);
  }
  const quoteBlock = profile.prompt
    .split("【原作语气锚点】")[1]
    ?.split("这些短句只用于")[0] || "";
  const profileQuotes = [...quoteBlock.matchAll(/^[-*]\s+(.+)$/gm)]
    .map((match) => match[1].trim())
    .filter((quote) => !/当前可靠资料|可靠资料暂未/.test(quote));
  if (JSON.stringify(profileQuotes) !== JSON.stringify(proof.verifiedQuotes)) {
    failures.push(`${prefix}: 原作短句与逐字验证清单不一致`);
  }
  const regressionPatterns = [
    /猫耳和尾巴/,
    /武器名为[‘']水压剑[’']/,
    /被遗忘的璃月老侦察骑士/,
    /过于莽撞被骑士团拒收/,
    /头脑最好的人之一/,
    /「博士」切片背叛本体/,
    /并未察觉，还主动与旅行者打招呼/,
  ];
  for (const pattern of regressionPatterns) {
    if (pattern.test(profile.prompt)) failures.push(`${prefix}: 命中已修正事实回归 ${pattern}`);
  }
  if (profile.promptProvenance?.project !== EXPECTED_PROJECT) {
    failures.push(`${prefix}: 来源项目记录错误`);
  }
  const expectedUrls = source.sources.map((item) => item.url).sort();
  if (JSON.stringify([...profile.promptSources].sort()) !== JSON.stringify(expectedUrls)) {
    failures.push(`${prefix}: 来源 URL 不完整`);
  }
  for (const field of [
    "name",
    "description",
    "prompt",
    "groupPrompt",
    "soulMd",
    "promptVersion",
  ]) {
    const expected = field === "description" ? profile.publicDescription : profile[field];
    if (character[field] !== expected) failures.push(`${prefix}: 数据库字段 ${field} 未同步`);
  }
  if (descriptions.has(profile.publicDescription)) failures.push(`${prefix}: 公开简介与其他角色重复`);
  descriptions.add(profile.publicDescription);
  const signature = extractSpecificSignature(profile.prompt);
  if (specificSignatures.has(signature)) failures.push(`${prefix}: 角色核心和语言 DNA 与其他角色重复`);
  specificSignatures.add(signature);
}

if (byId.get("alyosha")?.name !== "阿罗夏") failures.push("未修正阿罗夏正式中文名");
if (byId.get("vesna")?.name !== "薇斯纳") failures.push("未修正薇斯纳正式中文名");
if (data.curatedPromptImport?.importedCharacters !== 30) {
  failures.push("数据库顶部未记录 30 名补充角色");
}

console.log("项目补充角色档案审计：30 份");
if (failures.length) {
  console.error(`\n发现 ${failures.length} 个错误：`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  const totals = manifest.profiles.reduce(
    (sum, entry) => ({
      prompt: sum.prompt + entry.promptLength,
      group: sum.group + entry.groupPromptLength,
      soul: sum.soul + entry.soulMdLength,
    }),
    { prompt: 0, group: 0, soul: 0 },
  );
  console.log(
    `Prompt ${totals.prompt.toLocaleString()} / 群聊 ${totals.group.toLocaleString()} / SoulMD ${totals.soul.toLocaleString()} 字符`,
  );
  console.log("来源、哈希、长度、结构、旅行者身份、逐字台词、事实回归、样例与数据库同步全部通过。");
}

function extractSpecificSignature(prompt) {
  const core = prompt.split("【角色核心】")[1]?.split("【经历与当下】")[0] || "";
  const speech = prompt.split("【语言DNA】")[1]?.split("【微信聊天执行】")[0] || "";
  return createHash("sha256")
    .update(`${core}\n${speech}`.replace(/\s+/g, " ").trim())
    .digest("hex");
}
