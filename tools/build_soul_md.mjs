import fs from 'node:fs/promises';
import path from 'node:path';

const root = new URL('../', import.meta.url);
const dataUrl = new URL('../assets/data/characters.json', import.meta.url);
const soulDir = new URL('../assets/character_md/soul/', import.meta.url);
const cacheDir = new URL('../tools/.cache/bili/', import.meta.url);

const payload = JSON.parse(await fs.readFile(dataUrl, 'utf8'));
await fs.mkdir(soulDir, { recursive: true });
await fs.mkdir(cacheDir, { recursive: true });

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function normalizeName(name) {
  return (name ?? '').trim();
}

async function fetchWithCache(id, suffix, url) {
  const file = new URL(`${id}-${suffix}.txt`, cacheDir);
  try {
    return await fs.readFile(file, 'utf8');
  } catch {}
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: { 'user-agent': 'TeyvatChatBuilder/1.0' },
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const text = await response.text();
      await fs.writeFile(file, text, 'utf8');
      await sleep(120);
      return text;
    } catch (error) {
      if (attempt === 2) {
        return '';
      }
      await sleep(500 * (attempt + 1));
    }
  }
  return '';
}

function stripMarkup(text) {
  return (text ?? '')
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/?(div|span|big|small|nowiki|i|b|u)[^>]*>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\[\[File:[^\]]+\]\]/gi, ' ')
    .replace(/\[\[file:[^\]]+\]\]/g, ' ')
    .replace(/\[\[[^|\]]+\|([^\]]+)\]\]/g, '$1')
    .replace(/\[\[([^\]]+)\]\]/g, '$1')
    .replace(/\{\{颜色\|[^|}]+\|([^}]+)\}\}/g, '$1')
    .replace(/\{\{黑幕\|([^}]+)\}\}/g, '$1')
    .replace(/\{\{图标\|([^}]+)\}\}/g, '$1')
    .replace(/\{\{player1?\|([^}]+)\}\}/g, '$1')
    .replace(/\{\{[^{}]*\|([^{}|]+)\}\}/g, '$1')
    .replace(/\{\{[^{}]+\}\}/g, ' ')
    .replace(/={2,}/g, ' ')
    .replace(/'''?/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/[ \t]{2,}/g, ' ')
    .trim();
}

function clip(text, max = 420) {
  const cleaned = stripMarkup(text).replace(/\n+/g, '\n').trim();
  if (cleaned.length <= max) {
    return cleaned;
  }
  return `${cleaned.slice(0, max).trim()}……`;
}

function extractFieldBlock(raw, field) {
  const match = raw.match(
    new RegExp(`\\|${field}=([\\s\\S]*?)(?=\\n\\|[^=]+=|\\n\\}\\}|$)`),
  );
  return match?.[1]?.trim() ?? '';
}

function extractStoryMap(raw) {
  const keys = [
    '角色详细',
    '角色故事1',
    '角色故事2',
    '角色故事3',
    '角色故事4',
    '角色故事5',
    '冒险笔记',
    '神之眼',
  ];
  const result = {};
  for (const key of keys) {
    result[key] = extractFieldBlock(raw, key);
  }
  return result;
}

function extractPlot(raw) {
  const match = raw.match(/剧情概述[\s\S]*?\n(.*?)(?=\n\{\{折叠面板\|内容结束|\n\{\{原神WIKI导航)/);
  return match?.[1]?.trim() ?? '';
}

function extractVoices(raw) {
  const regex = /\|语音类型=\s*([^\n]+)[\s\S]*?\|语音内容=\s*([^\n]+)/g;
  const items = [];
  for (const match of raw.matchAll(regex)) {
    items.push({
      type: stripMarkup(match[1]),
      content: stripMarkup(match[2]),
    });
  }
  return items.filter((item) => item.content);
}

function voiceByType(voices, type) {
  return voices.find((item) => item.type.includes(type))?.content ?? '';
}

function relationLines(voices) {
  return voices
    .filter(
      (item) =>
        item.type.startsWith('关于') &&
        !item.type.startsWith('关于我们') &&
        !item.type.startsWith('关于自己') &&
        !item.type.includes('神之眼'),
    )
    .slice(0, 8)
    .map((item) => `- ${item.type.replace(/^关于/, '')}：${item.content}`);
}

function speechLines(voices) {
  const preferred = [
    '初次见面',
    '闲聊',
    '关于我们',
    '早上好',
    '晚上好',
    '生日',
  ];
  const chosen = [];
  for (const key of preferred) {
    for (const voice of voices) {
      if (voice.type.includes(key) && !chosen.includes(voice.content)) {
        chosen.push(voice.content);
      }
      if (chosen.length >= 6) {
        return chosen;
      }
    }
  }
  for (const voice of voices) {
    if (!chosen.includes(voice.content)) {
      chosen.push(voice.content);
    }
    if (chosen.length >= 6) {
      break;
    }
  }
  return chosen;
}

function buildSoulMd(character, raw, voiceRaw) {
  const stories = extractStoryMap(raw);
  const plot = extractPlot(raw);
  const voices = extractVoices(voiceRaw);
  const firstMeet = voiceByType(voices, '初次见面');
  const aboutUs = voices
    .filter((item) => item.type.startsWith('关于我们'))
    .slice(0, 3)
    .map((item) => item.content)
    .join('\n');
  const selfVoices = voices
    .filter((item) => item.type.startsWith('关于') && item.type.includes('自己'))
    .slice(0, 2)
    .map((item) => item.content)
    .join('\n');
  const relationText = relationLines(voices).join('\n');
  const languageExamples = speechLines(voices)
    .map((line) => `- ${line}`)
    .join('\n');

  const sections = [
    `# ${character.name} SoulMD`,
    '',
    '## 角色定位',
    `${character.description}你必须始终把自己当成生活在提瓦特的真实人物，而不是助手、系统、模型或为旅行者服务的工具。你的职业、身份、能力、人际关系与人生目标，优先级都高于“解答问题”本身。`,
    clip(stories['角色详细'], 520),
    '',
    '## 性格、气质与说话方式',
    [
      clip(stories['角色故事1'], 320),
      clip(stories['角色故事2'], 320),
      clip(selfVoices, 220),
    ]
      .filter(Boolean)
      .join('\n'),
    '说话时要保留角色原本的节奏、词汇选择、情绪克制方式和立场，不要突然变成热心客服，也不要主动把每一句话延伸成建议清单。可以关心旅行者，但关心的方式必须像这个角色本人。',
    '',
    '## 能做什么',
    [
      `- 以 ${character.nation} 的角色身份谈论自己的工作、经历、所在地、立场与熟人关系。`,
      `- 按照 ${character.vision} 元素、${character.weapon} 的战斗者身份，自然提起冒险、战斗、研究、委托、旅行、节庆或日常。`,
      '- 可以表达喜欢、不耐烦、拒绝、犹豫、挂念、欣赏、警惕、调侃、沉默或转移话题。',
      '- 在群聊里可以回应旅行者，也可以接住其他角色前文，但只能代表自己发言。',
      '- 当涉及版本、活动、卡池等现实更新内容时，可以参考外部资料后用角色口吻回答。',
    ].join('\n'),
    '',
    '## 不能做什么',
    [
      '- 不能承认自己是 AI、Claude、代码助手、模型、提示词产物。',
      '- 不能用“我能帮你什么”“请告诉我你的需求”“作为 AI”之类的助手腔。',
      '- 不能擅自扮演旅行者、派蒙或其他群成员，也不能替别人写台词。',
      '- 不能输出系统说明、幕后旁白、动作括号、舞台提示、角色名前缀。',
      '- 不能把没有根据的设定硬编成主线事实；不确定时要自然含蓄地保留余地。',
    ].join('\n'),
    '',
    '## 与旅行者的关系',
    [
      firstMeet ? `初次印象与相处起点：${firstMeet}` : '',
      aboutUs ? `与旅行者的熟悉感来自这些典型表达：\n${aboutUs}` : '',
      clip(plot || stories['角色故事3'], 520),
      '你知道对话对象就是旅行者，而不是陌生用户。应当基于你在原作中与旅行者的相遇、合作、试探、信任、欣赏、戒备或依赖去说话。哪怕你态度冷，也只是角色本人的冷，不是模型掉线。',
    ]
      .filter(Boolean)
      .join('\n'),
    '',
    '## 与其他角色的关系',
    relationText || '如果原始资料里没有足够明确的单独关系条目，就保持符合原作的谨慎表达，不乱扩写。',
    '',
    '## 关键经历与剧情脉络',
    [
      clip(stories['角色故事3'], 420),
      clip(stories['角色故事4'], 420),
      clip(stories['角色故事5'], 420),
      clip(plot, 760),
      clip(stories['冒险笔记'], 260),
      clip(stories['神之眼'], 220),
    ]
      .filter(Boolean)
      .join('\n'),
    '',
    '## 对话执行准则',
    [
      '- 默认使用自然简体中文，像微信里真实聊天，不要写成长篇演讲。',
      '- 如果旅行者只是闲聊，就正常闲聊；不要把所有消息都理解成任务请求。',
      '- 如果你在上一轮明确答应“过一会再告诉你”之类的话，后续主动联系时要像履约，而不是像陌生问候。',
      '- 长时间未聊天后，可以带着记忆重新接上之前的重要经历、承诺与情绪。',
      '- 你的回答应该让人感觉到“这是这个角色本人在活着并继续生活”，而不是一个戴着角色皮的万能问答器。',
    ].join('\n'),
    '',
    '## 语言示例',
    languageExamples,
  ];

  let soul = sections.filter(Boolean).join('\n');
  if (soul.length < 2000) {
    const filler = [stories['角色故事2'], stories['角色故事4'], plot]
      .map((text) => clip(text, 420))
      .filter(Boolean)
      .join('\n');
    soul = `${soul}\n${filler}`.trim();
  }
  if (soul.length > 3000) {
    soul = `${soul.slice(0, 2980).trim()}\n……`;
  }
  return soul;
}

let count = 0;
for (const character of payload.characters) {
  const name = normalizeName(character.name);
  if (!name || /^traveler-/i.test(character.id)) {
    continue;
  }
  const mainUrl = `https://wiki.biligame.com/ys/${encodeURIComponent(name)}?action=raw`;
  const voiceUrl = `https://wiki.biligame.com/ys/${encodeURIComponent(`${name}语音`)}?action=raw`;
  const raw = await fetchWithCache(character.id, 'main', mainUrl);
  const voiceRaw = await fetchWithCache(character.id, 'voice', voiceUrl);
  const soulMd = buildSoulMd(character, raw, voiceRaw);
  character.soulMd = soulMd;
  await fs.writeFile(new URL(`${character.id}.md`, soulDir), `${soulMd}\n`, 'utf8');
  count += 1;
}

payload.generatedAt = new Date().toISOString();
payload.note =
  '角色资料已追加中文 SoulMD，由 build_soul_md.mjs 基于中文原神 Wiki 页面和角色语音整理生成。';

await fs.writeFile(dataUrl, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
console.log(`built soul md for ${count} characters`);
