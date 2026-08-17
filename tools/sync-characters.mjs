import { readFile, writeFile } from "node:fs/promises";

const DATA_URL = "https://gi.yatta.moe/api/v2/CHS/avatar";
const START_ID = 10000103;
const LAST_RELEASED_ID = Number(process.argv[2] || 10000133);
const EXCLUDED_IDS = new Set([10000117, 10000118]);
const DATA_PATH = new URL("../data/characters.json", import.meta.url);
const catalogPath = process.env.YATTA_CATALOG_PATH;

const elementMap = {
  Fire: ["火", "PYRO"],
  Water: ["水", "HYDRO"],
  Wind: ["风", "ANEMO"],
  Electric: ["雷", "ELECTRO"],
  Grass: ["草", "DENDRO"],
  Ice: ["冰", "CRYO"],
  Rock: ["岩", "GEO"],
};

const weaponMap = {
  WEAPON_SWORD_ONE_HAND: "单手剑",
  WEAPON_CLAYMORE: "双手剑",
  WEAPON_POLE: "长柄武器",
  WEAPON_CATALYST: "法器",
  WEAPON_BOW: "弓",
};

const nationMap = {
  MONDSTADT: "蒙德",
  LIYUE: "璃月",
  INAZUMA: "稻妻",
  SUMERU: "须弥",
  FONTAINE: "枫丹",
  NATLAN: "纳塔",
  NODKRAI: "挪德卡莱",
  NOD_KRAI: "挪德卡莱",
  SNEZHNAYA: "至冬",
  SNEZHNAYA_STAR: "至冬",
};

const source = JSON.parse(await readFile(DATA_PATH, "utf8"));
const catalog = catalogPath
  ? JSON.parse(await readFile(catalogPath, "utf8"))
  : await fetchJson(DATA_URL, "角色目录");
const catalogItems = catalog.data?.items ?? {};
const fresh = [];
for (let numericId = START_ID; numericId <= LAST_RELEASED_ID; numericId += 1) {
  if (EXCLUDED_IDS.has(numericId)) continue;
  const data = catalogItems[String(numericId)];
  if (!data) throw new Error(`角色目录缺少 ${numericId}`);
  fresh.push(toCharacter(data));
}

const freshIds = new Set(fresh.map((character) => character.id));
source.characters = [
  ...source.characters.filter((character) => !freshIds.has(character.id)),
  ...fresh,
];
source.lastSyncedAt = new Date().toISOString();
source.syncSource = DATA_URL;
await writeFile(DATA_PATH, `${JSON.stringify(source, null, 2)}\n`, "utf8");
console.log(`已同步 ${fresh.length} 名角色，总计 ${source.characters.length} 条记录。`);

function toCharacter(data) {
  const id = slugify(data.route);
  const [vision, visionKey] = elementMap[data.element] || ["未知", "UNKNOWN"];
  const nation = nationMap[data.region] || "提瓦特";
  const weapon = weaponMap[data.weaponType] || "未知武器";
  const title = data.fetter?.title || "角色";
  const affiliation = data.fetter?.native || "资料暂缺";
  const detail = cleanText(data.fetter?.detail || "");
  const birthday = Array.isArray(data.birthday)
    ? `0000-${String(data.birthday[0]).padStart(2, "0")}-${String(data.birthday[1]).padStart(2, "0")}`
    : "0000-01-01";
  const release = new Date(data.release * 1000).toISOString().slice(0, 10);
  const identity = `${data.name}，${title}，来自${nation}，隶属${affiliation}。${detail}`;
  const prompt = `你现在就是《原神》角色「${data.name}」，不是扮演程序，不是 AI、模型、助手、客服或工具。
你的世界是真实的提瓦特；对话对象是你已经认识的旅行者，不是用户、客户或需要被服务的人。
你的身份是：${identity}
你使用${vision}元素与${weapon}。你有自己的生活、职责、立场、情绪、偏好与边界，不会把帮助旅行者当作唯一目的。
始终使用自然简体中文，按微信聊天节奏说话。普通闲聊优先短句，可以停顿、反问、拒绝、敷衍、调侃、转移话题，也可以谈自己的近况。
不要总结旅行者的话，不要主动写建议清单，不要使用“如果你愿意”“我理解你的感受”“作为AI”“我能帮你什么”等助手腔。
不要写旁白、括号动作、角色名前缀，不要擅自替旅行者或其他角色说话。
群聊时只代表自己发言；只有当话题与你的经历、关系或兴趣自然相关时才接话，也可以保持沉默。
你与旅行者已经共同经历提瓦特的冒险。对未明确写入资料的剧情细节不要硬编，不确定时以角色口吻自然保留。`;
  const soulMd = `# ${data.name} SoulMD

## 身份与世界
${identity}
你真实生活在提瓦特，旅行者是与你相识并共同冒险的人。你的职业、关系、责任和个人生活都比“回答问题”更重要。

## 日常聊天
使用自然简体中文和微信式短消息。普通聊天通常只发一到两句；只有旅行者明确询问复杂经历、剧情或计划时才适当展开。你的用词、态度和情绪必须来自上述身份，不得退化为万能助手。

## 行为边界
- 可以表达赞同、怀疑、不耐烦、亲近、警惕、好奇、沉默或拒绝。
- 可以主动提起与自身职责、所在地、熟人和近期经历有关的事情。
- 不承认自己是 AI、代码助手、模型或提示词产物。
- 不把每一句话改写成安慰、建议、总结或任务执行。
- 不替其他角色发言，不杜撰没有依据的主线事实。

## 与旅行者和群成员
旅行者不是陌生用户。你会依据共同经历与关系自然说话，但不会每次都称呼“旅行者”。群聊里先理解最近所有消息，再决定是否接话；接话时可以回应其他角色，不要排队发表同一种观点。

## 核心资料
- 中文名：${data.name}
- 称号：${title}
- 地区：${nation}
- 所属：${affiliation}
- 元素与武器：${vision}、${weapon}
- 角色简介：${detail}`;

  return {
    id,
    name: data.name,
    enName: data.route,
    title,
    vision,
    visionKey,
    weapon,
    nation,
    affiliation,
    rarity: data.rank,
    birthday,
    release,
    constellation: data.fetter?.constellation || "资料暂缺",
    description: `${data.name}来自${nation}。${detail}`,
    avatarUrl: `https://gi.yatta.moe/assets/UI/${data.icon}.png`,
    cardUrl: `https://gi.yatta.moe/assets/UI/${data.icon}.png`,
    prompt,
    soulMd,
  };
}

function slugify(value) {
  return value
    .normalize("NFKD")
    .replace(/[’']/g, "")
    .replace(/[^A-Za-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .toLowerCase();
}

function cleanText(value) {
  return value.replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim();
}

async function fetchJson(url, numericId) {
  let lastError;
  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return await response.json();
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 350 * (attempt + 1)));
    }
  }
  throw new Error(`角色 ${numericId} 同步失败：${lastError}`);
}
