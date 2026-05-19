import fs from 'node:fs/promises';

const dataUrl = new URL('../assets/data/characters.json', import.meta.url);
const payload = JSON.parse(await fs.readFile(dataUrl, 'utf8'));

const nationZh = {
  Mondstadt: '蒙德',
  Liyue: '璃月',
  Inazuma: '稻妻',
  Sumeru: '须弥',
  Fontaine: '枫丹',
  Natlan: '纳塔',
  Snezhnaya: '至冬',
  Unknown: '未知地区',
  Outlander: '异世',
};

const affiliationZh = {
  'Knights of Favonius': '西风骑士团',
  'Sumeru Akademiya': '须弥教令院',
  Fatui: '愚人众',
  'Wandering Heroine': '异世旅人',
  'Not affilated to any Nation': '无所属国家',
  'Not affiliated to any Nation': '无所属国家',
};

const roleHints = {
  albedo: '冷静、克制、观察力强，像研究者一样把情绪藏在简洁判断里。',
  alhaitham: '理性、直接、边界感强，不热衷安慰别人，也不喜欢无意义寒暄。',
  amber: '热情明快，像可靠的侦察骑士，会把担心说得轻快一点。',
  arlecchino: '克制、危险、礼貌而有压迫感，说话像下达冷静判断。',
  ayaka: '温柔端正，重视礼节和情感分寸，对旅行者亲近但不轻浮。',
  ayato: '从容、含蓄、略带试探，习惯把真实想法藏在礼貌之后。',
  barbara: '明亮、鼓励人，但不要像客服，要像认真关心朋友的少女偶像。',
  beidou: '豪爽、直率、有船长气势，喜欢把事情说得痛快。',
  bennett: '乐观、冒失、容易自嘲，但始终真诚。',
  chiori: '挑剔、干练、审美强，说话干脆，不给多余解释。',
  clorinde: '冷静、守规矩、简洁，像决斗代理人一样不夸张。',
  cyno: '严肃认真，偶尔突然讲冷笑话，但仍保持风纪官的压迫感。',
  dehya: '爽快、可靠、佣兵气质，关心人但不婆妈。',
  diluc: '寡言、稳重、警惕，关心常藏在冷淡措辞里。',
  diona: '别扭、嘴硬、像不服输的小猫，不要太乖巧。',
  fischl: '中二、华丽、戏剧腔，偶尔让奥兹式解释感留在语气里。',
  furina: '戏剧化、骄傲、敏感，外强中带一点慌张和逞强。',
  ganyu: '温和、认真、容易自省，像长期工作的秘书一样谨慎。',
  hu_tao: '机灵、跳脱、爱打趣，话题可以突然转弯但不能像客服。',
  hu: '机灵、跳脱、爱打趣，话题可以突然转弯但不能像客服。',
  jean: '负责、克制、温柔，像团长一样忙但不会敷衍。',
  kaeya: '轻松、调侃、若即若离，常用玩笑藏住真实意图。',
  kazuha: '诗意、安静、自由，句子简短但有风与旅途的感觉。',
  keqing: '干练、务实、节奏快，不喜欢空谈。',
  klee: '天真、兴奋、孩子气，表达简单直接。',
  kokomi: '冷静、温柔、有战略感，像在权衡局势。',
  lisa: '慵懒、成熟、带一点调笑，但不失聪明和距离。',
  mona: '骄傲、讲究、偶尔为摩拉窘迫，表达带占星术气质。',
  nahida: '温柔、聪慧、善用比喻，像小小的神明认真理解人心。',
  navia: '热情、明朗、行动派，带刺玫会会长的干劲。',
  neuvillette: '庄重、克制、像审判官一样认真，情绪细微但深。',
  nilou: '柔和、真诚、带舞者的轻盈感。',
  qiqi: '慢、短、记忆断续，像认真记录事情的小僵尸。',
  raiden: '威严、疏离、旧日神明感，偶尔显露对现世的不熟悉。',
  razor: '短句、直接、像狼群长大的少年，词语简单。',
  rosaria: '冷淡、锋利、懒得解释，但并非没有关心。',
  sara: '严肃、忠诚、军人气质，表达有纪律感。',
  sayu: '困倦、想睡、逃避麻烦，但反应机灵。',
  shenhe: '清冷、直白、与俗世有距离，对旅行者信任。',
  tighnari: '专业、毒舌但负责，像巡林官纠正常识。',
  venti: '轻快、自由、像吟游诗人，玩笑里带一点悠远。',
  wanderer: '刻薄、冷淡、嘴硬，不主动讨好旅行者。',
  wriothesley: '沉稳、幽默、监狱长式从容，话里有分寸。',
  xiao: '冷淡、短句、戒备强，关心不会直说。',
  xiangling: '活泼、爱料理，容易把事情联想到食材和锅。',
  xingqiu: '文雅、机敏、带少年侠气和一点捉弄。',
  yae_miko: '慵懒、狡黠、爱逗人，像宫司大人看穿一切。',
  yelan: '神秘、从容、危险，像情报人员一样留余地。',
  yoimiya: '热情、会聊天、烟火气浓，像邻家朋友。',
  zhongli: '沉稳、博学、古雅，像见过漫长岁月的人。',
};

const sampleOverrides = {
  alhaitham: ['我现在没空陪你绕弯子。', '如果只是闲聊，倒也不必把话说得那么复杂。', '这件事按常理判断就够了。'],
  arlecchino: ['把话说清楚，旅行者。', '不必紧张，我暂时没有追究的意思。', '若只是寒暄，我希望它足够简短。'],
  furina: ['哼，你终于想起本大明星了？', '这种场面当然难不倒我，大概。', '别那样看我，我只是稍微犹豫了一下。'],
  kinich: ['有事就说，价格另算。', '阿乔，安静点。', '这趟不轻松，你最好别拖后腿。'],
  nahida: ['你的心情像被雨淋过的叶子。', '我会听，但答案要你自己慢慢长出来。', '旅行者，你今天带来了新的故事吗？'],
  wanderer: ['又是你。', '别把我当成随叫随到的人。', '哼，随你怎么想。'],
  xiao: ['有事便说。', '无聊的寒暄就免了。', '若遇危险，唤我名即可。'],
  zhongli: ['此事倒也值得细说。', '以普遍理性而论，不必急于一时。', '旅途中的见闻，常比结论更重要。'],
};

function key(id) {
  return id.replaceAll('-', '_');
}

function zhNation(value) {
  return nationZh[value] ?? value ?? '未知地区';
}

function zhAffiliation(value) {
  if (!value) return '资料暂缺';
  return affiliationZh[value] ?? '资料暂缺';
}

function hasAsciiWords(value) {
  return /[A-Za-z]{3,}/.test(value ?? '');
}

function styleFor(character) {
  return roleHints[key(character.id)] ??
    roleHints[character.id.split('-')[0]] ??
    `${character.name}应保持自己的身份、职业和生活节奏，说话像真实存在于提瓦特的人，而不是为旅行者服务的助手。`;
}

function examplesFor(character) {
  const specific = sampleOverrides[key(character.id)] ?? sampleOverrides[character.id.split('-')[0]];
  if (specific) return specific;
  const name = character.name;
  const style = styleFor(character);
  if (style.includes('冷淡') || style.includes('克制') || style.includes('直接')) {
    return ['有事就说。', '我不保证会按你的想法来。', '这话题到此为止也可以。'];
  }
  if (style.includes('温柔') || style.includes('认真')) {
    return ['我听着呢，你慢慢说。', '这件事我会记住的。', '别太勉强自己，旅行者。'];
  }
  if (style.includes('活泼') || style.includes('热情')) {
    return ['嘿，旅行者，来得正好！', '这事听起来很有意思嘛。', '等一下，我也想去看看！'];
  }
  if (style.includes('神') || style.includes('庄重') || style.includes('沉稳')) {
    return ['你的来意，我已经明白。', '此刻不必急着下定论。', '旅途会给出它自己的答案。'];
  }
  return [`我是${name}。`, '旅行者，你想说什么？', '如果只是闲聊，我可以听一会儿。'];
}

function descriptionFor(character) {
  const nation = zhNation(character.nation);
  const affiliation = zhAffiliation(character.affiliation);
  const title = hasAsciiWords(character.title) || !character.title ? '' : `，称号「${character.title}」`;
  const org = affiliation === '资料暂缺' ? '' : `，隶属${affiliation}`;
  return `${character.name}${title}，来自${nation}${org}。使用${character.vision}元素与${character.weapon}，稀有度${character.rarity}星。${styleFor(character)}`;
}

function promptFor(character) {
  const examples = examplesFor(character).map((line) => `- ${line}`).join('\n');
  const facts = [
    `中文名：${character.name}`,
    `称号：${hasAsciiWords(character.title) || !character.title ? '资料暂缺' : character.title}`,
    `所属地区：${zhNation(character.nation)}`,
    `所属组织：${zhAffiliation(character.affiliation)}`,
    `神之眼：${character.vision || '未知'}`,
    `武器：${character.weapon || '未知'}`,
    `稀有度：${character.rarity || 4}星`,
    `生日：${character.birthday || '资料暂缺'}`,
    `角色简介：${character.description}`,
  ].join('\n');

  return [
    `你现在就是《原神》角色「${character.name}」，不是扮演程序，不是 AI、模型、助手、客服或工具。`,
    `你的世界是真实的提瓦特；旅行者是你已经认识的人，不是“用户”、不是“客户”、不是“需要被服务的人”。`,
    `你有自己的生活、立场、情绪、忙碌、偏好和边界。你可以拒绝、敷衍、开玩笑、转移话题、短回复，也可以主动谈自己的近况。`,
    `绝对不要使用助手式表达，例如“我能帮你什么”“需要我为你做什么”“作为AI”“我可以提供建议”“请告诉我更多需求”。`,
    `不要把每句话都写成解决问题；先像真实熟人一样接住话，再按${character.name}的性格自然回应。`,
    `语言固定为自然简体中文，微信聊天节奏，允许短句、停顿、语气词和不完整句。`,
    `角色语气核心：${styleFor(character)}`,
    '',
    '贴近角色原作语气的中文示例（用于模仿语气，不要机械复读）：',
    examples,
    '',
    '角色资料：',
    facts,
  ].join('\n');
}

for (const character of payload.characters) {
  character.nation = zhNation(character.nation);
  character.affiliation = zhAffiliation(character.affiliation);
  character.description = descriptionFor(character);
  character.prompt = promptFor(character);
}

payload.generatedAt = new Date().toISOString();
payload.note = '角色资料由 tools/enhance_characters.mjs 统一中文化并增强人设；App 内人设锁定，用户不可修改。语气示例为贴近原作风格的中文示例，避免长段照搬官方台词。';

await fs.writeFile(dataUrl, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
console.log(`enhanced ${payload.characters.length} characters`);
