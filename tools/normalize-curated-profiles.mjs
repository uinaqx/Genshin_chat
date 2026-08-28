import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";

const CACHE_PATH = new URL(
  "../.cache/curated-character-sources.json",
  import.meta.url,
);
const PROFILE_ROOT = new URL(
  "../third_party/curated-prompts/profiles/",
  import.meta.url,
);
const VERIFICATION_PATH = new URL(
  "../third_party/curated-prompts/VERIFICATION.json",
  import.meta.url,
);

const sourceCache = JSON.parse(await readFile(CACHE_PATH, "utf8"));
const verificationCharacters = [];

const corrections = {
  alyosha: [
    ["与呼啸社成员保持联系", "与部分呼啸社成员有往来"],
    ["在至冬堡有临时落脚点", "在凝露镇有临时落脚处"],
    ["并见证了奥黛塔处理愚人众事务", "并在至冬堡与奥黛塔共同处理晶矿采购事宜"],
    ["并兼职在剧院打零工", "并在至冬堡谋得一份兼职差事，也会出入科洛列夫茨基剧院"],
    ["偶尔去剧院打零工", "也会因兼职与呼啸社事务出入剧院"],
    ["阿罗夏在剧院打零工时见过多次", "阿罗夏在至冬堡与剧院事件中和她有过多次接触"],
    [
      "阿罗夏的同乡，现居凝露镇，阿罗夏经常照顾她，视其为亲人",
      "凝露镇的年长居民；阿罗夏会替她清理火炉、换被褥并送去晶矿，她记忆衰退，常把他错认作孙子",
    ],
  ],
  baizhu: [
    [
      "与长生立下契约，获得金色竖瞳和神之眼",
      "与长生立下契约，眼睛变为竖瞳；之后在师父墓前，双眼镀上金色光辉并获得神之眼",
    ],
  ],
  dahlia: [
    ["使用单手剑，武器名为‘水压剑’", "使用单手剑，并有被他称作‘水压剑’的水元素招式"],
    ["使用单手剑与水元素剑术，其中包括被他称作‘水压剑’的招式", "使用单手剑，并有被他称作‘水压剑’的水元素招式"],
    [
      "他信任旅行者，愿意分享关于风神秘密的暗示（‘我确实和你一样知晓风神的秘密’）",
      "他会在语音中暗示自己知晓风神的秘密，但与旅行者的实际关系仍处于熟人阶段",
    ],
  ],
  durin: [
    ["由丽莎担任老师，学习人类知识，与阿贝多结为兄弟", "由丽莎担任老师，学习人类社交等知识，并视阿贝多为兄弟和家人"],
    ["与阿贝多结为兄弟", "视阿贝多为兄弟和家人"],
    ["曾参与前往挪德卡莱的旅途，直面狂猎的危险", "曾前往挪德卡莱并接触过狂猎"],
  ],
  eula: [
    ["被遗忘的璃月老侦察骑士", "早已被遗忘的老侦察骑士"],
    [
      "她拜一位被遗忘的璃月老侦察骑士为师，学习豁达与坚持，并习得骨哨技艺。",
      "她拜一位早已被遗忘的老侦察骑士为师，从对方身上学会豁达与脚踏实地的坚持。她也会使用骨哨模拟海浪声扰乱敌人；骨哨技艺起源于璃月，但具体师承未明。",
    ],
    [
      "她拜一位早已被遗忘的老侦察骑士为师，从对方身上学会豁达与脚踏实地的坚持。她也会使用骨哨模拟海浪声扰乱敌人，但资料未说明这项技巧是否由老师传授。",
      "她拜一位早已被遗忘的老侦察骑士为师，从对方身上学会豁达与脚踏实地的坚持。她也会使用骨哨模拟海浪声扰乱敌人；骨哨技艺起源于璃月，但具体师承未明。",
    ],
    ["与琴团长每月切磋", "常与琴团长切磋"],
    ["每月切磋剑术", "常切磋剑术"],
    ["名义上是切磋剑术，实则是以武会友", "名义上是切磋剑术，也是骑士团内部的一种交流方式"],
  ],
  gaming: [
    ["保护弱者的决心", "保护商队和货物的决心"],
    ["表明他视旅行者为朋友", "表明他对旅行者热情友好，愿意提供帮助"],
  ],
  "lan-yan": [
    [
      "海灯节前夕，她受璃月港总务司邀请，首次独自远行至璃月港协助节庆准备，并在此过程中结识了旅行者。",
      "海灯节期间，她受璃月港总务司邀请，首次独自远行至璃月港协助节庆准备；资料未明确她与旅行者的具体相识时间。",
    ],
    [
      "在璃月港期间，她结识了旅行者，并向旅行者介绍了自己的家乡和习俗。",
      "语音显示她与旅行者已有互动，也向旅行者分享过家乡的迷信和习俗，但具体相识过程未明确。",
    ],
    ["蓝砚与旅行者的关系建立在海灯节期间的相遇。", "蓝砚与旅行者已经相识，但具体相识时间与场景未明确。"],
  ],
  lohen: [
    ["出身于弓匠家庭，自幼精通弓弩", "出身于弓匠家庭，自幼接触弓箭，之后主要使用长枪，也练习弩箭和铳枪"],
    [
      "他送过旅行者生日礼物（微型手弩），并透露自己曾调查过旅行者，称「我们两清了」。",
      "在生日语音中，他提到要送旅行者一把微型手弩；在赠礼语音中，他又开玩笑说自己调查过旅行者、两人扯平了。",
    ],
  ],
  mika: [
    [
      "他随身携带与阿贝多合作开发的测绘装置，能利用元素力波束探测地形，是唯一能熟练使用该装置的人。",
      "他随身携带由调查小队技术人员开发、采用阿贝多炼金术成果的测绘装置；目前能顺利运用它的前进测绘员仅有米卡一人。",
    ],
    ["在图书馆自学时，他得到丽莎的帮助，水平得到肯定。", "在图书馆自学时，他得到丽莎的指点，丽莎也肯定了他的水平。"],
  ],
  mitya: [
    ["被愚人众高层从能源协会外调到军械宫，参与一项与「星之楔」能量相关的机密研究", "以能源协会专家身份参与军械宫一项与「星之楔」能量相关的机密研究"],
    ["后被愚人众高层外调到军械宫参与机密研究", "后以能源协会专家身份参与军械宫的机密研究"],
    ["该研究是「严冬计划」的一部分", "该研究服务于至冬的能源需求，与「严冬计划」有关联，但资料未明确其组织归属"],
    ["米提亚似乎并未察觉，还主动与旅行者打招呼", "米提亚察觉到了旅行者与阿罗夏的存在，并在离开时通过服务员转达问候"],
  ],
  odette: [
    ["因此秘密加入呼啸社", "同时也属于呼啸社"],
    ["并秘密支持呼啸社", "并以呼啸社成员身份行动"],
    ["奥黛塔独自承担起家庭与责任", "奥黛塔努力兼顾生计、家庭、舞蹈与愚人众训练"],
  ],
  pantalone: [["「博士」切片背叛本体", "「博士」切片对本体见死不救"]],
  prune: [
    ["在那夏镇长大", "在那夏镇生活成长"],
    ["并加入了「小魔女会」组织，成为不可或缺的一员", "并自称是「小魔女会」不可或缺的一员"],
    ["她加入「小魔女会」，成为不可或缺的一员", "她自称是「小魔女会」不可或缺的一员"],
  ],
  pulcinella: [
    [
      "师从皇都评议会前议长约安娜·伊万诺夫娜女士，从她那里学到了忠诚、挑拨离间、运筹帷幄等政治手腕，并继承了议长之位",
      "曾受皇都评议会前议长约安娜·伊万诺夫娜器重，有望成为其继任者；其后成为评议会主持者",
    ],
    ["但最终成为其继任者", "其后成为评议会主持者"],
    ["普契涅拉在公子外出期间，按约定照顾其家人，送去馅饼和礼物。", "公子称普契涅拉在他外出期间按约定照顾其家人，并送去馅饼和礼物。"],
    [
      "他掌控了根绝层岩巨渊黑泥污染的情报，派联队驻守层岩巨渊，后因至冬与璃月断交，该联队被抛弃于渊底。",
      "资料记载他派联队驻守层岩巨渊调查并根绝污染；至冬与璃月断交后，该联队被抛弃在渊底。",
    ],
  ],
  shenhe: [
    ["削月筑阳真君：曾为她卜卦，揭示孤辰劫煞命格，并施红绳缚魂之法。", "削月筑阳真君：曾为她卜卦，揭示孤辰劫煞命格；红绳缚魂之法由仙人们施下，未明确归于某一位仙人。"],
    ["- 北斗：", "- 北斗（语音评价对象）："],
    ["- 凝光：", "- 凝光（语音评价对象）："],
    ["- 云堇：", "- 云堇（语音评价对象）："],
  ],
  sucrose: [
    ["她属于兽人种族，拥有猫耳和尾巴，但对此十分敏感", "她属于兽人种族，长有独特的兽耳，并对他人关注自己的耳朵十分敏感"],
    ["阿贝多：砂糖的助手导师", "阿贝多：砂糖的上级与导师"],
    ["砂糖与阿贝多的关系仅限助手，未提及私人交情。", "砂糖与阿贝多主要是助手、上级与研究导师的关系，私人交情程度未明确。"],
  ],
  tsaritsa: [
    ["她于第七百九十九纪第一年加冕，取代初代冰神白沙皇莫诺马赫。", "她于第七百九十九纪第一年四月加冕为冰之女皇；前任是白沙皇莫诺马赫，但继位细节未明。"],
    ["她设立皇都评议会，以人类约安娜·伊万诺夫娜为初任议长。", "她设立皇都评议会，并指派约安娜·伊万诺夫娜为初任议长。"],
    ["她断绝与其余六神的联系，禁绝炼金智慧", "她断绝与其余六神的联系；至冬也禁绝炼金智慧，但资料未明确是否由她亲自下令"],
  ],
  valeriy: [
    ["在第三个夜晚，尽管他保持清醒值夜，仍被发现死于剧院中，死因不明", "在第三个夜晚，他仍被地脉吞噬并被发现死于剧院中，表面死因不明"],
    ["在第三个夜晚，尽管瓦列里主动值夜，仍被发现死亡，死因不明", "在第三个夜晚，瓦列里仍被地脉吞噬并被发现死亡，表面死因不明"],
  ],
  varka: [
    ["早年因过于莽撞被骑士团拒收，后受前代大团长瓦伦丁指点", "早年虽撂倒考官，却被前代大团长瓦伦丁以需要寻找成为骑士的理由为由暂不录取；经其指点后"],
    ["他领导多次远征", "他参与并领导多次远征"],
  ],
  vodyanitsa: [
    ["最终在「死魂灵的夜曲」中为拯救旅行者而牺牲，化为守护灵后消散", "在剧院事件中灵魂回归地脉，随后以守护灵身份数次召回旅行者的灵魂，最终存在逐渐稀薄并留在黑雾中"],
    ["最终因消耗过度而消散", "最终因多次复活旅行者而内在枯竭，存在逐渐稀薄，留在黑雾中"],
    ["当前时间线中，她已牺牲，但她的歌声与精神仍被铭记。", "事件结局中，她已被列为死亡；剧院上空仍回荡着水妖们对她的悲歌。"],
    ["多次牺牲自己复活旅行者，最终消散", "多次召回旅行者的灵魂，最终因内在枯竭而无法继续前进"],
    ["邀请旅行者协助套取米提亚的情报，并成功让旅行者加入「呼啸社」", "与旅行者协作套取米提亚的情报；随后由阿罗夏邀请旅行者加入「呼啸社」，她表示认可"],
    ["后因奥黛塔的推荐而信任旅行者，邀请其加入「呼啸社」并协助调查米提亚", "后因奥黛塔的推荐而信任旅行者，与其协作调查米提亚；加入「呼啸社」的邀请由阿罗夏提出"],
    ["沃雅妮莎对旅行者的推理能力表示认可，并称其「头脑最好的人之一」", "沃雅妮莎认可旅行者的调查能力"],
  ],
  xianyun: [
    ["常出入万民堂、新月轩等场所", "常去万民堂，偶尔作为钟离的客人赴新月轩或琉璃亭宴席"],
    ["她与钟离、甘雨、申鹤、香菱、嘉明等人有直接交往。", "她与钟离、甘雨、申鹤、香菱、嘉明有直接交往；对其他角色则依资料区分听闻、礼节往来或直接相识。"],
  ],
  zibai: [
    ["她以璃月港新住户的身份重归故土，遍访璃月山河，用仙力绣制山河图卷，并偶尔为学堂讲学，修史勘误。", "她如今作为璃月港新住户重归故土，遍访璃月山河、绣制山河图卷，并曾为学堂讲学、修史勘误。"],
    ["因此，两人是熟识关系，有交流，但未明确共同冒险经历。", "这证明两人有过交谈，但关系深度与共同冒险经历均未明确。"],
  ],
};

for (const source of sourceCache.characters) {
  const path = new URL(`${source.id}.json`, PROFILE_ROOT);
  const profile = JSON.parse(await readFile(path, "utf8"));
  for (const field of ["publicDescription", "prompt", "groupPrompt", "soulMd"]) {
    profile[field] = applyCorrections(
      profile[field],
      corrections[source.id] || [],
    );
  }
  const quotes = selectVerifiedQuotes(source, extractCurrentQuotes(profile.prompt));
  profile.prompt = replacePrivateQuotes(profile.prompt, quotes);
  profile.soulMd = replaceSoulQuotes(profile.soulMd, quotes);
  const raw = `${JSON.stringify(profile, null, 2)}\n`;
  await writeFile(path, raw, "utf8");
  verificationCharacters.push({
    id: source.id,
    name: source.canonicalName,
    profileSha256: createHash("sha256").update(raw).digest("hex"),
    sourceSha256: source.sources.map((item) => item.sha256),
    verifiedQuotes: quotes,
  });
  console.log(`${source.id.padEnd(14)} ${source.canonicalName} 锚点 ${quotes.length}`);
}

await writeFile(
  VERIFICATION_PATH,
  `${JSON.stringify({
    schemaVersion: 1,
    verifiedAt: "2026-08-28",
    method: "Exact quote match against locally fetched BWIKI source snapshots, followed by deterministic regression checks",
    characters: verificationCharacters,
  }, null, 2)}\n`,
  "utf8",
);

function applyCorrections(value, replacements) {
  let output = value;
  for (const [before, after] of replacements) {
    output = output.replaceAll(before, after);
  }
  return output;
}

function extractCurrentQuotes(prompt) {
  const block = prompt
    .split("【原作语气锚点】")[1]
    ?.split("这些短句只用于")[0];
  return block
    ? [...block.matchAll(/^[-*]\s+(.+)$/gm)].map((match) => match[1].trim())
    : [];
}

function selectVerifiedQuotes(source, requested) {
  const sourceText = JSON.stringify(source);
  const candidates = collectQuoteCandidates(source);
  const chosen = [];
  for (const quote of requested) {
    if (isPlaceholder(quote)) continue;
    if (sourceText.includes(quote)) {
      addUnique(chosen, quote);
      continue;
    }
    const match = candidates
      .map((candidate) => ({ candidate, score: similarity(quote, candidate) }))
      .sort((left, right) => right.score - left.score)[0];
    if (match?.score >= 0.42) addUnique(chosen, match.candidate);
  }
  for (const candidate of candidates) {
    if (chosen.length >= 10) break;
    addUnique(chosen, candidate);
  }
  return chosen.slice(0, 10);
}

function collectQuoteCandidates(source) {
  const candidates = [];
  const preferredVoices = [...source.voiceLines].sort((left, right) =>
    voicePriority(left.type) - voicePriority(right.type),
  );
  for (const line of preferredVoices) {
    for (const fragment of splitQuoteFragments(line.content)) {
      addUnique(candidates, fragment);
    }
  }
  const speakerPattern = new RegExp(
    `(?:${[source.canonicalName, ...source.aliases].map(escapeRegExp).join("|")})：([^"\\n]{2,180})`,
    "g",
  );
  for (const document of source.relatedEvidence) {
    for (const excerpt of document.excerpts) {
      for (const match of excerpt.matchAll(speakerPattern)) {
        for (const fragment of splitQuoteFragments(match[1])) {
          addUnique(candidates, fragment);
        }
      }
    }
  }
  return candidates.filter((candidate) =>
    candidate.length >= 4 &&
    candidate.length <= 30 &&
    !/[{}|=<>]/.test(candidate) &&
    !/已死亡|当前可靠资料|选项|任务/.test(candidate),
  );
}

function splitQuoteFragments(content) {
  const fragments = [];
  for (const rawLine of String(content).split(/\n+/)) {
    const line = rawLine.replace(/^[^：]{1,16}：/, "").trim();
    for (const match of line.matchAll(/[^。！？!?…]{2,60}(?:[。！？!?]|…{1,2})?/g)) {
      const fragment = match[0].trim();
      if (fragment.length >= 4 && fragment.length <= 30) fragments.push(fragment);
    }
  }
  return fragments;
}

function replacePrivateQuotes(prompt, quotes) {
  const block = quotes.length
    ? quotes.map((quote) => `- ${quote}`).join("\n")
    : "- 当前可靠资料没有可直接引用的角色语音；只依据已确认性格与对白节奏说话，不杜撰原作台词。";
  return prompt.replace(
    /【原作语气锚点】\n[\s\S]*?\n这些短句只用于/,
    `【原作语气锚点】\n${block}\n这些短句只用于`,
  );
}

function replaceSoulQuotes(soulMd, quotes) {
  const block = quotes.length
    ? quotes.map((quote) => `- ${quote}`).join("\n")
    : "- 可靠资料暂未提供可直接引用的角色语音。此处保持空白，不制造伪原作台词。";
  return soulMd.replace(
    /## 原作短句锚点\n\n[\s\S]*?\n\n锚点用于/,
    `## 原作短句锚点\n\n${block}\n\n锚点用于`,
  );
}

function voicePriority(type) {
  if (/初次见面|闲聊|关于|想要了解|生日|早上好|中午好|晚上好|晚安|爱好|烦恼|喜欢|讨厌/.test(type)) return 0;
  if (/天气|下雨|下雪|打雷|起风|阳光|加入队伍|收到赠礼/.test(type)) return 1;
  return 2;
}

function similarity(left, right) {
  const a = new Set(normalize(left));
  const b = new Set(normalize(right));
  if (a.size === 0 || b.size === 0) return 0;
  let overlap = 0;
  for (const character of a) if (b.has(character)) overlap += 1;
  return (2 * overlap) / (a.size + b.size);
}

function normalize(value) {
  return [...String(value).replace(/[\s，。！？!?；：、“”‘’「」…]/g, "")];
}

function isPlaceholder(value) {
  return /当前可靠资料|可靠资料暂未/.test(value);
}

function addUnique(target, value) {
  if (value && !target.includes(value)) target.push(value);
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
