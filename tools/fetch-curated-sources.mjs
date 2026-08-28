import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";

const DATA_PATH = new URL("../data/characters.json", import.meta.url);
const CACHE_DIR = new URL("../.cache/", import.meta.url);
const CACHE_PATH = new URL("../.cache/curated-character-sources.json", import.meta.url);
const OUTPUT_DIR = new URL("../third_party/curated-prompts/", import.meta.url);
const SOURCES_PATH = new URL(
  "../third_party/curated-prompts/SOURCES.json",
  import.meta.url,
);
const WIKI_ROOT = "https://wiki.biligame.com/ys";
const RETRIEVED_AT = new Date().toISOString().slice(0, 10);

const sourcePlans = [
  plan("aloy", "埃洛伊", "埃洛伊", "埃洛伊语音"),
  plan("baizhu", "白术", "白术", "白术语音"),
  plan("gaming", "嘉明", "嘉明", "嘉明语音"),
  plan("rosaria", "罗莎莉亚", "罗莎莉亚", "罗莎莉亚语音"),
  plan("mika", "米卡", "米卡", "米卡语音"),
  plan("mona", "莫娜", "莫娜", "莫娜语音"),
  plan("sucrose", "砂糖", "砂糖", "砂糖语音"),
  plan("shenhe", "申鹤", "申鹤", "申鹤语音"),
  plan("xianyun", "闲云", "闲云", "闲云语音"),
  plan("yaoyao", "瑶瑶", "瑶瑶", "瑶瑶语音"),
  plan("eula", "优菈", "优菈", "优菈语音"),
  plan("yun-jin", "云堇", "云堇", "云堇语音"),
  plan("lan-yan", "蓝砚", "蓝砚", "蓝砚语音"),
  plan("dahlia", "塔利雅", "塔利雅", "塔利雅语音"),
  plan("durin", "杜林", "杜林", "杜林语音"),
  plan("zibai", "兹白", "兹白", "兹白语音"),
  plan("varka", "法尔伽", "法尔伽", "法尔伽语音"),
  plan("lohen", "洛恩", "洛恩", "洛恩语音"),
  plan("prune", "布伦妮", "布伦妮", "布伦妮语音"),
  plan("vodyanitsa", "沃雅妮莎", "沃雅妮莎", null, [
    "冬日静默如谜",
    "白幕降下",
    "死魂灵的夜曲",
    "唯沉默不受眷顾",
  ]),
  plan("alyosha", "阿罗夏", "阿罗夏", "阿罗夏语音", [
    "冰原上的伟业",
    "沉寂之地的枪声",
  ], ["阿罗夏", "阿廖沙"]),
  plan("odette", "奥黛塔", "奥黛塔", "奥黛塔语音", [
    "冬日静默如谜",
    "白幕降下",
  ]),
  plan("valeriy", "瓦列里", null, null, [
    "向导笔记/人物",
    "冬日静默如谜",
    "白幕降下",
    "死魂灵的夜曲",
    "莱莱可的自白",
  ]),
  plan("pulcinella", "普契涅拉", null, null, [
    "愚人众",
    "唯沉默不受眷顾",
    "血红之证",
    "达达利亚",
  ], ["普契涅拉", "「公鸡」", "公鸡"]),
  plan("pantalone", "潘塔罗涅", null, null, [
    "愚人众",
    "虚空劫灰往世书",
    "血红之证",
    "乌髓孑灯",
  ], ["潘塔罗涅", "「富人」", "富人"]),
  plan("vesna", "薇斯纳", "薇斯纳", null, [
    "血红之证",
    "唯沉默不受眷顾",
  ], ["薇斯纳", "维斯娜"]),
  plan("danica", "达妮卡", null, null, ["薇斯纳", "未实装", "至冬"]),
  plan("noy", "诺伊", null, null, ["未实装", "至冬", "第七章"]),
  plan("mitya", "米提亚", null, null, [
    "向导笔记/人物",
    "冬日静默如谜",
    "白幕降下",
    "死魂灵的夜曲",
    "槲寄生",
    "唯沉默不受眷顾",
  ]),
  plan("tsaritsa", "安娜丝塔夏", null, null, [
    "至冬",
    "愚人众",
    "哥伦比娅",
    "《至冬国通史》",
    "唯沉默不受眷顾",
  ], ["安娜丝塔夏", "冰之女皇", "女皇陛下"]),
];

const characterData = JSON.parse(await readFile(DATA_PATH, "utf8"));
const byId = new Map(
  characterData.characters.map((character) => [character.id, character]),
);
const cache = {
  schemaVersion: 1,
  retrievedAt: RETRIEVED_AT,
  source: "Genshin Impact BWIKI",
  sourceLicense: "CC BY-NC-SA 4.0",
  characters: [],
};
const manifest = {
  schemaVersion: 1,
  project: "Teyvat WeChat curated character prompts",
  retrievedAt: RETRIEVED_AT,
  source: "Genshin Impact BWIKI",
  sourceBaseUrl: WIKI_ROOT,
  sourceLicense: "CC BY-NC-SA 4.0",
  characters: [],
};

await mkdir(CACHE_DIR, { recursive: true });
await mkdir(OUTPUT_DIR, { recursive: true });

for (const sourcePlan of sourcePlans) {
  const character = byId.get(sourcePlan.id);
  if (!character) throw new Error(`角色数据库缺少 ${sourcePlan.id}`);
  const documents = [];

  if (sourcePlan.mainPage) {
    documents.push(await fetchWikiPage(sourcePlan.mainPage, "character"));
  }
  if (sourcePlan.voicePage) {
    documents.push(await fetchWikiPage(sourcePlan.voicePage, "voice"));
  }
  for (const page of sourcePlan.extraPages) {
    documents.push(await fetchWikiPage(page, "related"));
  }

  const mainDocument = documents.find((document) => document.kind === "character");
  const voiceDocument = documents.find((document) => document.kind === "voice");
  const relatedDocuments = documents.filter((document) => document.kind === "related");
  const sourceRecord = {
    id: sourcePlan.id,
    canonicalName: sourcePlan.canonicalName,
    aliases: sourcePlan.aliases,
    existingRecord: {
      name: character.name,
      enName: character.enName,
      title: character.title,
      vision: character.vision,
      weapon: character.weapon,
      nation: character.nation,
      affiliation: character.affiliation,
      description: character.description,
    },
    characterPage: mainDocument ? extractCharacterPage(mainDocument.raw) : null,
    voiceLines: voiceDocument ? extractVoiceLines(voiceDocument.raw) : [],
    relatedEvidence: relatedDocuments.map((document) => ({
      title: document.title,
      excerpts: extractRelatedEvidence(document.raw, sourcePlan.aliases),
    })),
    sources: documents.map(publicDocumentMetadata),
  };

  cache.characters.push(sourceRecord);
  manifest.characters.push({
    id: sourcePlan.id,
    canonicalName: sourcePlan.canonicalName,
    aliases: sourcePlan.aliases,
    sources: documents.map(publicDocumentMetadata),
  });
  console.log(
    `${sourcePlan.id.padEnd(14)} ${sourcePlan.canonicalName.padEnd(6)} ` +
      `${sourceRecord.voiceLines.length} 条语音 / ${documents.length} 个页面`,
  );
}

await writeFile(CACHE_PATH, `${JSON.stringify(cache, null, 2)}\n`, "utf8");
await writeFile(SOURCES_PATH, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
console.log(`\n已生成 ${sourcePlans.length} 名角色的资料缓存与来源清单。`);

function plan(
  id,
  canonicalName,
  mainPage,
  voicePage,
  extraPages = [],
  aliases = [canonicalName],
) {
  return { id, canonicalName, mainPage, voicePage, extraPages, aliases };
}

async function fetchWikiPage(title, kind) {
  const endpoint = new URL(`${WIKI_ROOT}/api.php`);
  endpoint.searchParams.set("action", "parse");
  endpoint.searchParams.set("format", "json");
  endpoint.searchParams.set("prop", "wikitext");
  endpoint.searchParams.set("page", title);
  let payload;
  let lastError = "请求失败";
  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      const response = await fetch(endpoint, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140 Safari/537.36",
          Referer: `${WIKI_ROOT}/`,
        },
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      payload = await response.json();
      break;
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
      if (attempt < 3) await wait(600 * (attempt + 1));
    }
  }
  if (!payload) throw new Error(`${title}: ${lastError}`);
  if (payload.error || !payload.parse) {
    throw new Error(`${title}: ${payload.error?.info || "页面不存在"}`);
  }
  const raw = payload.parse.wikitext?.["*"] || "";
  return {
    title,
    kind,
    pageId: payload.parse.pageid,
    revisionId: payload.parse.revid,
    url: `${WIKI_ROOT}/${encodeURIComponent(title)}`,
    sha256: createHash("sha256").update(raw).digest("hex"),
    raw,
  };
}

function publicDocumentMetadata(document) {
  return {
    title: document.title,
    kind: document.kind,
    pageId: document.pageId,
    revisionId: document.revisionId,
    url: document.url,
    sha256: document.sha256,
  };
}

function extractCharacterPage(raw) {
  const fields = {};
  const keys = [
    "名称",
    "称号",
    "全名",
    "英文名称",
    "所属",
    "种族",
    "介绍",
    "元素属性",
    "武器类型",
    "性别",
    "职业",
    "归属",
    "身份",
    "生日",
    "角色详细",
    "角色故事1",
    "角色故事2",
    "角色故事3",
    "角色故事4",
    "角色故事5",
    "冒险笔记",
    "神之眼",
  ];
  for (const key of keys) {
    const value = extractTemplateField(raw, key);
    if (value) fields[key] = cleanWikiText(value);
  }
  return fields;
}

function extractVoiceLines(raw) {
  const lines = [];
  const blocks = raw.split(/{{角色\/语音1?(?=\n|\|)/).slice(1);
  for (const block of blocks) {
    const type = cleanWikiText(extractTemplateField(block, "语音类型"));
    const content = cleanWikiText(extractTemplateField(block, "语音内容"));
    if (!type || !content) continue;
    lines.push({ type, content });
  }
  return lines;
}

function extractRelatedEvidence(raw, aliases) {
  const lines = raw.split(/\r?\n/);
  const selected = new Set();
  const aliasPattern = new RegExp(
    aliases.map((alias) => escapeRegExp(alias)).join("|"),
  );
  for (let index = 0; index < lines.length; index += 1) {
    if (!aliasPattern.test(lines[index])) continue;
    for (
      let nearby = Math.max(0, index - 3);
      nearby <= Math.min(lines.length - 1, index + 14);
      nearby += 1
    ) {
      const clean = cleanWikiText(lines[nearby]);
      if (clean && clean.length > 2) selected.add(clean);
    }
  }
  return [...selected].slice(0, 320);
}

function extractTemplateField(raw, key) {
  const pattern = new RegExp(
    `(?:^|\\n)\\|${escapeRegExp(key)}=([\\s\\S]*?)(?=\\n\\|[^=\\n]+=|\\n}}|$)`,
  );
  return raw.match(pattern)?.[1]?.trim() || "";
}

function cleanWikiText(value) {
  return (value || "")
    .replace(/<br\s*\/?\s*>/gi, "\n")
    .replace(/<!--([\s\S]*?)-->/g, "")
    .replace(/<[^>]+>/g, "")
    .replace(/\[\[(?:[^\]|]+\|)?([^\]]+)]]/g, "$1")
    .replace(/\[(?:https?:\/\/\S+)\s+([^\]]+)]/g, "$1")
    .replace(/{{黑幕\|([^{}]+)}}/g, "$1")
    .replace(/{{颜色\|[^|{}]+\|([^{}]+)}}/g, "$1")
    .replace(/{{[^{}]*}}/g, "")
    .replace(/^\*+/gm, "")
    .replace(/'{2,}/g, "")
    .replace(/&nbsp;|&#160;/g, " ")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
