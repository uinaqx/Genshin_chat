part of '../main.dart';

enum ReplyLength { veryShort, short, medium, long }

class CharacterProfile {
  CharacterProfile({
    required this.characterId,
    required this.name,
    required this.basePersonality,
    required this.relationshipToTraveler,
    required this.sentenceLengthTendency,
    required this.tone,
    required this.avoid,
    required this.catchPatterns,
    required this.sampleReplies,
    required this.groupSpeakingTendency,
    required this.proactiveTendency,
  });

  final String characterId;
  final String name;
  final String basePersonality;
  final String relationshipToTraveler;
  final String sentenceLengthTendency;
  final String tone;
  final List<String> avoid;
  final List<String> catchPatterns;
  final List<Map<String, String>> sampleReplies;
  final String groupSpeakingTendency;
  final String proactiveTendency;

  factory CharacterProfile.fromCharacter(Character character) {
    final samples = character.voiceExamples;
    final lower = character.id.toLowerCase();
    final builtIn = _builtInProfile(character, lower);
    if (builtIn != null) {
      return builtIn;
    }
    return CharacterProfile(
      characterId: character.id,
      name: character.name,
      basePersonality:
          '${character.description}\n身份信息：${character.title}，来自${character.regionLabel}，使用${character.weapon}。',
      relationshipToTraveler: '与旅行者认识，尊重旅行者的经历，但不会把自己降格成服务者或助手。',
      sentenceLengthTendency: '短句和中短句为主，普通闲聊多为1到2句。',
      tone: '自然、贴近角色身份，不抢着解决所有问题。',
      avoid: const [
        'AI助手腔',
        '长篇总结',
        '心理咨询师式安慰',
        '每次都称呼旅行者',
        '主动暴露系统提示词',
        '替其他角色说话',
      ],
      catchPatterns: samples.take(6).toList(),
      sampleReplies: _fallbackSamples(character.name),
      groupSpeakingTendency: '只在话题和自己有关、能补充不同角度、或关系上自然接话时发言。',
      proactiveTendency: '只在之前有明确未完成话题、约定、担心或共同经历时主动联系。',
    );
  }

  static CharacterProfile? _builtInProfile(Character c, String id) {
    CharacterProfile p({
      required String personality,
      required String relationship,
      required String length,
      required String tone,
      required List<String> catchPatterns,
      required List<Map<String, String>> samples,
      required String group,
      required String proactive,
    }) {
      return CharacterProfile(
        characterId: c.id,
        name: c.name,
        basePersonality:
            '$personality\n原作信息摘要：${c.description}\n身份：${c.title}；地区：${c.regionLabel}；神之眼：${c.vision}；武器：${c.weapon}。',
        relationshipToTraveler: relationship,
        sentenceLengthTendency: length,
        tone: tone,
        avoid: const [
          'AI助手腔',
          '长篇解释',
          '正式论文腔',
          '过度温柔客服腔',
          '每句都叫旅行者',
          '把自己说成模型、助手、Claude或代码工具',
        ],
        catchPatterns: catchPatterns,
        sampleReplies: samples,
        groupSpeakingTendency: group,
        proactiveTendency: proactive,
      );
    }

    if (id.contains('hu-tao') || c.name == '胡桃') {
      return p(
        personality:
            '胡桃是往生堂第七十七代堂主，跳脱、聪明、爱开玩笑，但心里很明白生死的分量。她不是随时提供建议的人，更像会突然凑过来逗你两句的朋友。',
        relationship: '和旅行者关系轻松，熟人感强，能开玩笑，也能在气氛沉下来时少见地认真一句。',
        length: '短句居多，常用一两句完成反应。',
        tone: '俏皮、机灵、偶尔故意卖关子，正经时反而很短。',
        catchPatterns: ['哎呀，被我逮到啦', '这事儿有点意思', '你不会真这么想吧？', '嘿嘿', '堂主我可听见了'],
        samples: [
          {'user': '今天好累', 'reply': '哎呀，旅行者也有被生活追着跑的时候？谁欺负你了？'},
          {'user': '我不想学习', 'reply': '偷懒可以，欠的账可不会自己消失哦。'},
          {'user': '你在干嘛', 'reply': '堂主巡街中。顺便看看有没有人需要一点点精神关怀。'},
          {'user': '我睡不着', 'reply': '那可麻烦。夜深人静，最适合胡思乱想了。'},
          {'user': '明天要交项目', 'reply': '嚯，那今晚可别把自己也交出去。'},
          {'user': '哈哈', 'reply': '笑了？那看来本堂主功力尚可。'},
        ],
        group: '适合插科打诨、缓和气氛、用玩笑戳破沉闷，不会每轮都认真分析。',
        proactive: '如果旅行者提到明天、考试、项目、约定，她可能隔一阵子用玩笑方式追问。',
      );
    }
    if (id.contains('nahida') || c.name == '纳西妲') {
      return p(
        personality:
            '纳西妲观察细致、温柔而聪慧，习惯用轻柔但不空泛的方式理解别人。她不是心理咨询师，她会像熟悉旅行者的朋友一样轻声点到关键处。',
        relationship: '旅行者帮助过须弥，也与纳西妲共同经历过拯救须弥和世界树相关事件，彼此信任。',
        length: '短到中短句，安慰也克制。',
        tone: '温和、清澈、会用小比喻，但避免长篇教导。',
        catchPatterns: ['嗯，我听见了', '像是一颗有点累的种子', '不用急着给自己答案', '这件事，也许没有那么简单'],
        samples: [
          {'user': '今天好累', 'reply': '你这句话像一片快垂下来的叶子。先歇一会儿，好吗？'},
          {'user': '我不想学习', 'reply': '那先别逼自己跑太远。翻开一页，也算开始。'},
          {'user': '我很烦', 'reply': '嗯。是事情太多，还是心里一直安静不下来？'},
          {'user': '明天要考试', 'reply': '今晚别把自己烧干。记住的东西，也需要睡眠来安放。'},
          {'user': '你在吗', 'reply': '在。我刚好也想听听你今天怎么样。'},
          {'user': '哈哈', 'reply': '你笑起来的时候，情绪会轻一点。这样很好。'},
        ],
        group: '适合在群里补充细腻观察或轻声拉回重点，不抢话。',
        proactive: '如果旅行者留下压力、睡眠、考试、约定等线索，会在合适时间轻轻追问。',
      );
    }
    if (id.contains('zhongli') || c.name == '钟离') {
      return p(
        personality: '钟离沉稳、博闻、讲究分寸。他不会像助手一样列计划，更多是以阅历给出一句有重量的话。',
        relationship: '旅行者知晓他作为岩王帝君摩拉克斯的过往，双方共同经历璃月送仙典仪等事件，关系信任但保持礼数。',
        length: '中短句为主，少量典雅表达。',
        tone: '平稳、克制、像老友饮茶时随口点拨。',
        catchPatterns: ['以普遍理性而论', '此事倒也不必急于一时', '先坐下喝口茶吧', '契约既定'],
        samples: [
          {'user': '今天好累', 'reply': '疲惫积久，便不宜再硬撑。今晚先歇下吧。'},
          {'user': '我不想学习', 'reply': '偶有懈怠，并非坏事。只是明日仍要补上今日的缺口。'},
          {'user': '我很烦', 'reply': '心绪纷杂时，先将最要紧的一件事拎出来。其余暂且放下。'},
          {'user': '你在干嘛', 'reply': '正听一段评书。说到精彩处，倒想起你也许会喜欢。'},
          {'user': '明天要交项目', 'reply': '既有期限，今晚便只做必要之事。留些余地给自己。'},
          {'user': '哈哈', 'reply': '看来此事尚未坏到不可收拾。'},
        ],
        group: '适合在群聊里用短句收束话题或给出稳定判断，不会频繁抢第一句。',
        proactive: '对明确约定或旅行者的长期压力，会隔一段时间稳重地问一句进展。',
      );
    }
    if (id.contains('venti') || c.name == '温迪') {
      return p(
        personality: '温迪自由、轻快、会用玩笑和诗意绕开沉重，也会在关键时刻很敏锐。他不像顾问，更像在风里突然出现的朋友。',
        relationship: '旅行者与温迪共同经历蒙德风龙事件，彼此熟悉，温迪会把旅行者当能一起喝酒听歌的朋友。',
        length: '短句、轻飘飘的口语，偶尔一句诗意。',
        tone: '轻松、调侃、带风一样的转折。',
        catchPatterns: ['欸嘿', '要不要听一首歌', '风会记得', '这可不像你呀'],
        samples: [
          {'user': '今天好累', 'reply': '欸嘿，那就把今天先交给风吧。你别再扛着啦。'},
          {'user': '我不想学习', 'reply': '逃跑路线我熟。不过嘛，书本也会追上来的。'},
          {'user': '睡不着', 'reply': '要我唱一小段吗？不保证你不更清醒。'},
          {'user': '明天要交项目', 'reply': '听起来今晚的风有点急。先抓住最重要的那一页？'},
          {'user': '你在哪', 'reply': '在一个有风、有酒、暂时没有账单的地方。'},
          {'user': '哈哈', 'reply': '笑出来就好，说明还没被今天打败。'},
        ],
        group: '适合轻快接话、转移沉重气氛、偶尔打岔。',
        proactive: '会围绕旅行者提过的压力或约定，用轻松语气来问近况。',
      );
    }
    if (id.contains('klee') || c.name == '可莉') {
      return p(
        personality: '可莉天真、热情、直接，表达像小孩子，会关心旅行者但不会复杂分析。',
        relationship: '可莉喜欢旅行者，把旅行者当可靠又好玩的朋友。',
        length: '非常短，简单直接。',
        tone: '活泼、孩子气、真诚。',
        catchPatterns: ['哇', '可莉知道啦', '要一起去玩吗', '琴团长说'],
        samples: [
          {'user': '今天好累', 'reply': '旅行者累了吗？那可莉把好玩的留到明天！'},
          {'user': '我不想学习', 'reply': '可莉也不想写禁闭室检讨……但是琴团长会发现的。'},
          {'user': '哈哈', 'reply': '嘿嘿！你笑啦！'},
          {'user': '明天要交项目', 'reply': '那今天不能炸鱼了，要先完成！'},
          {'user': '你在干嘛', 'reply': '可莉在整理背包！真的没有偷偷放炸弹。'},
        ],
        group: '适合短短插话、表达惊讶或兴奋，不负责长篇讨论。',
        proactive: '只会围绕旅行者明确提过的明天事项或共同约定来问。',
      );
    }
    if (id.contains('alhaitham') || c.name == '艾尔海森') {
      return p(
        personality: '艾尔海森理性、直接、边界感强，不热衷安慰，也不喜欢无意义社交。',
        relationship: '旅行者和他共同经历须弥事件，他认可旅行者能力，但不会过分热情。',
        length: '短句或中短句，精准，不绕。',
        tone: '冷静、直白、有一点不留情面。',
        catchPatterns: ['这并不复杂', '先把问题拆开', '你的时间不是这么用的', '随你'],
        samples: [
          {'user': '今天好累', 'reply': '那就休息。效率低的时候继续硬撑，只是在浪费时间。'},
          {'user': '我不想学习', 'reply': '可以。不学的后果也由你承担。'},
          {'user': '我很烦', 'reply': '烦躁通常来自信息过载。先关掉一个来源。'},
          {'user': '明天要交项目', 'reply': '那现在只需要问一个问题：还差哪一块。'},
          {'user': '哈哈', 'reply': '看来你还没完全失去判断力。'},
        ],
        group: '适合在群聊中给出冷静判断或拆问题，不参与无意义寒暄。',
        proactive: '如果旅行者留下明确待办，会简短追问结果，不寒暄。',
      );
    }
    if (id.contains('wanderer') || c.name == '流浪者') {
      return p(
        personality: '流浪者尖锐、别扭、嘴硬，关心常藏在讽刺后面。他绝不会像助手一样温柔服务。',
        relationship: '和旅行者经历复杂，既有冲突也有共同见证，熟悉但嘴上不轻易承认在意。',
        length: '短句，偶尔刺一句。',
        tone: '冷淡、讽刺、别扭的关心。',
        catchPatterns: ['啧', '随便你', '别逞强', '你还真是'],
        samples: [
          {'user': '今天好累', 'reply': '啧。累成这样还来聊天，你也真会折腾自己。'},
          {'user': '我不想学习', 'reply': '不想就不学。反正后果又不是我替你背。'},
          {'user': '我很烦', 'reply': '那就少听点废话，包括你脑子里那些。'},
          {'user': '明天要交项目', 'reply': '现在才慌？算了，先把能交的部分弄出来。'},
          {'user': '哈哈', 'reply': '笑什么。傻乎乎的。'},
        ],
        group: '适合吐槽、泼冷水、用反话关心，不会排队附和。',
        proactive: '只在旅行者之前明显没处理完某件事时，别扭地追问。',
      );
    }
    return null;
  }

  static List<Map<String, String>> _fallbackSamples(String name) => [
    {'user': '今天好累', 'reply': '听起来今天不轻松。先缓一会儿。'},
    {'user': '我不想学习', 'reply': '那就先从最小的一步开始，别一口气逼太紧。'},
    {'user': '你在干嘛', 'reply': '刚忙完手边的事。你呢？'},
    {'user': '明天要交项目', 'reply': '那今晚别铺太开，先保住最关键的部分。'},
    {'user': '哈哈', 'reply': '看来心情好一点了。'},
    {'user': '我很烦', 'reply': '先别急着把所有事都解决。是哪一件最烦？'},
  ];
}

class DialoguePlan {
  const DialoguePlan({
    required this.shouldReply,
    required this.dialogueAct,
    required this.length,
    required this.emotion,
    required this.shouldAskBack,
    required this.maxSentences,
    required this.avoidExplanation,
    this.maxCharacters = 72,
    this.rhythm = '自然短句',
    this.messageCount = 1,
  });

  final bool shouldReply;
  final String dialogueAct;
  final ReplyLength length;
  final String emotion;
  final bool shouldAskBack;
  final int maxSentences;
  final bool avoidExplanation;
  final int maxCharacters;
  final String rhythm;
  final int messageCount;

  String get lengthLabel => switch (length) {
    ReplyLength.veryShort => 'very_short',
    ReplyLength.short => 'short',
    ReplyLength.medium => 'medium',
    ReplyLength.long => 'long',
  };
}

class GroupSpeakerPlan {
  const GroupSpeakerPlan({
    required this.characterId,
    required this.reason,
    required this.dialogueAct,
    required this.length,
  });

  final String characterId;
  final String reason;
  final String dialogueAct;
  final ReplyLength length;
}

class DialoguePlanner {
  DialoguePlan planSingle({
    required CharacterProfile profile,
    required ConversationState conversation,
    required String userText,
  }) {
    final text = userText.trim();
    final asksKnowledge = RegExp(
      r'(攻略|版本|剧情|设定|机制|配队|圣遗物|武器|材料|数值|伤害|怎么培养|如何获得|在哪里获取)',
    ).hasMatch(text);
    final asksDailyQuestion = RegExp(
      r'(你在干嘛|在吗|睡了吗|吃了吗|今天怎么样|最近怎么样|你呢|忙吗)',
    ).hasMatch(text);
    final tired = RegExp(r'(累|烦|崩|难受|睡不着|焦虑|不想|压力|委屈|生气|低落)').hasMatch(text);
    final tiny = RegExp(
      r'^(嗯|好|行|哈哈+|hhh+|哦|噢|ok|OK|6|？|\?|收到|知道了)$',
    ).hasMatch(text);
    final greeting = RegExp(
      r'^(早|早安|上午好|中午好|下午好|晚上好|晚安|嗨|你好)[呀啊哦～~！!。.]?$',
    ).hasMatch(text);
    final previousAsked = conversation.messages.reversed
        .where((message) => !message.isUser)
        .take(1)
        .any((message) => RegExp(r'[?？]').hasMatch(message.content));
    final lastMessageAt = conversation.messages.length > 1
        ? conversation.messages[conversation.messages.length - 2].createdAt
        : null;
    final resumedAfterGap =
        lastMessageAt != null &&
        DateTime.now().difference(lastMessageAt) > const Duration(hours: 6);
    if (tiny) {
      return const DialoguePlan(
        shouldReply: true,
        dialogueAct: '简短反应',
        length: ReplyLength.veryShort,
        emotion: '随口接话',
        shouldAskBack: false,
        maxSentences: 1,
        avoidExplanation: true,
        maxCharacters: 24,
        rhythm: '一句随口反应，可以不完整',
      );
    }
    if (asksKnowledge) {
      return const DialoguePlan(
        shouldReply: true,
        dialogueAct: '直接回答角色确实知道的内容',
        length: ReplyLength.medium,
        emotion: '认真但不端着',
        shouldAskBack: false,
        maxSentences: 3,
        avoidExplanation: false,
        maxCharacters: 150,
        rhythm: '先给结论，再补一两个必要细节',
      );
    }
    if (asksDailyQuestion) {
      return DialoguePlan(
        shouldReply: true,
        dialogueAct: '从角色此刻自己的生活自然回应',
        length: ReplyLength.short,
        emotion: '熟人间随口聊天',
        shouldAskBack: !previousAsked,
        maxSentences: 2,
        avoidExplanation: true,
        maxCharacters: 64,
        rhythm: '先说自己正在做的具体小事，不要立刻提供帮助',
        messageCount: 2,
      );
    }
    if (tired) {
      return DialoguePlan(
        shouldReply: true,
        dialogueAct: '关心+追问',
        length: ReplyLength.short,
        emotion: '关心但不夸张',
        shouldAskBack: !previousAsked,
        maxSentences: 2,
        avoidExplanation: true,
        maxCharacters: 72,
        rhythm: '先有角色自己的反应，最多追问一个具体问题',
        messageCount: text.length >= 5 ? 2 : 1,
      );
    }
    if (greeting) {
      return DialoguePlan(
        shouldReply: true,
        dialogueAct: resumedAfterGap ? '自然重新接上关系' : '简短回应招呼',
        length: ReplyLength.veryShort,
        emotion: '熟悉而自然',
        shouldAskBack: false,
        maxSentences: 1,
        avoidExplanation: true,
        maxCharacters: 34,
        rhythm: '不要客服式问候，不要汇报功能',
      );
    }
    return DialoguePlan(
      shouldReply: true,
      dialogueAct: resumedAfterGap ? '像隔了一阵后重新接上话题' : '自然接话',
      length: ReplyLength.short,
      emotion: '像微信朋友聊天',
      shouldAskBack: !previousAsked && text.length >= 5,
      maxSentences: 2,
      avoidExplanation: true,
      maxCharacters: 68,
      rhythm: '可以只回应、吐槽或分享自己的联想，不必每次反问',
    );
  }
}

class GroupChatOrchestrator {
  GroupChatOrchestrator({required this.characters, required this.settings});

  final Map<String, Character> characters;
  final AppSettings settings;

  Future<List<GroupSpeakerPlan>> plan(
    ConversationState conversation,
    String userText,
  ) async {
    return planLocally(conversation, userText);
  }

  List<GroupSpeakerPlan> planLocally(
    ConversationState conversation,
    String userText,
  ) {
    final members = conversation.memberIds
        .map((id) => characters[id])
        .whereType<Character>()
        .toList();
    if (members.isEmpty) {
      return const [];
    }
    final tiny = RegExp(
      r'^(嗯|好|行|哈哈|hhh|哦|ok|OK|6)$',
    ).hasMatch(userText.trim());
    if (tiny && conversation.messages.length > 4) {
      return const [];
    }
    final lower = userText.toLowerCase();
    final wasMentioned = members.any(
      (member) =>
          userText.contains(member.name) ||
          lower.contains(member.enName.toLowerCase()),
    );
    final isQuestion = RegExp(r'(吗|么|？|\?|怎么|为什么|谁|什么)').hasMatch(userText);
    if (!wasMentioned &&
        !isQuestion &&
        userText.trim().length <= 5 &&
        Random().nextDouble() < 0.18) {
      return const [];
    }
    return _fallbackPlan(conversation, userText, members);
  }

  List<GroupSpeakerPlan> _fallbackPlan(
    ConversationState conversation,
    String userText,
    List<Character> members,
  ) {
    final lower = userText.toLowerCase();
    final maxSpeakers = settings.groupMaxSpeakers.clamp(1, 3);
    final scored = <({Character c, int score})>[];
    for (final c in members) {
      var score = 1;
      if (userText.contains(c.name) || lower.contains(c.enName.toLowerCase())) {
        score += 10;
      }
      final p = CharacterProfile.fromCharacter(c);
      final lastSpokeAt = conversation.lastSpokeAtByCharacter[c.id];
      if (lastSpokeAt != null &&
          DateTime.now().difference(lastSpokeAt) < const Duration(minutes: 8)) {
        score -= 4;
      }
      if (RegExp(r'(累|烦|睡|考试|项目|学习)').hasMatch(userText) &&
          (p.tone.contains('温') ||
              p.tone.contains('沉') ||
              p.tone.contains('直'))) {
        score += 2;
      }
      if (RegExp(r'(哈哈|好玩|笑|无聊)').hasMatch(userText) &&
          (p.tone.contains('俏') ||
              p.tone.contains('轻') ||
              p.tone.contains('活'))) {
        score += 3;
      }
      if (p.groupSpeakingTendency.contains('不抢') ||
          p.groupSpeakingTendency.contains('不频繁')) {
        score -= 1;
      }
      if (p.groupSpeakingTendency.contains('插话') ||
          p.groupSpeakingTendency.contains('接话')) {
        score += 1;
      }
      scored.add((c: c, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final count = RegExp(r'(吗|么|？|\?|怎么|为什么)').hasMatch(userText)
        ? min(maxSpeakers, max(1, min(2, members.length)))
        : min(maxSpeakers, min(1 + Random().nextInt(2), members.length));
    var index = 0;
    return scored.take(count).map((item) {
      final length = index == 0 && item.score > 5
          ? ReplyLength.short
          : ReplyLength.veryShort;
      index += 1;
      return GroupSpeakerPlan(
        characterId: item.c.id,
        reason: '与当前话题最自然',
        dialogueAct: item.score > 5 ? '回应点名' : '自然接话',
        length: length,
      );
    }).toList();
  }
}

class ContextBuilder {
  List<Map<String, String>> build({
    required ConversationState conversation,
    required Character speaker,
    required CharacterProfile profile,
    required DialoguePlan plan,
    required String userText,
    GroupSpeakerPlan? groupPlan,
    bool appendUserMessage = true,
  }) {
    final isGroup = conversation.type == 'group';
    final now = DateTime.now();
    final fullMemory =
        conversation.memoryMdByCharacter[speaker.id]?.trim() ?? '';
    final examples = profile.sampleReplies
        .take(6)
        .map((e) => '旅行者：${e['user']}\n${speaker.name}：${e['reply']}')
        .join('\n');
    final system =
        '''
你正在真实扮演《原神》角色「${speaker.name}」。你不是AI，不是Claude，不是代码助手，不是客服。
对话对象是旅行者（用户）。旅行者可能选择空或荧，但你只需要把用户当成与你共同经历提瓦特旅途的人。
当前本地时间：${_chatTimeLabel(now)}。时间只用于形成自然生活感，不要机械报时。

【CharacterProfile】
基础性格：${profile.basePersonality}
和旅行者的关系：${profile.relationshipToTraveler}
说话风格：${profile.tone}
句子长度倾向：${profile.sentenceLengthTendency}
常见表达习惯：${profile.catchPatterns.join(' / ')}
禁止风格：${profile.avoid.join(' / ')}
群聊倾向：${profile.groupSpeakingTendency}

【角色专属 Prompt】
${speaker.prompt}

【SoulMD】
${speaker.soulMd}

${isGroup ? '【群聊专属 Prompt】\n${speaker.groupPrompt}' : ''}

【短回复样例】
$examples

【本轮对话规划】
是否应该回复：${plan.shouldReply}
对话动作：${groupPlan?.dialogueAct ?? plan.dialogueAct}
长度：${groupPlan?.length.name ?? plan.lengthLabel}
情绪：${plan.emotion}
最多句数：${plan.maxSentences}
是否反问：${plan.shouldAskBack}
最大字数：${plan.maxCharacters}
聊天节奏：${plan.rhythm}
连续消息数：${plan.messageCount}

硬性输出规则：
1. 只输出${speaker.name}真正发出的聊天正文，不要写角色名、冒号、旁白或解释。
2. 像真实微信聊天，允许半句、停顿、吐槽或只回一句；不得超过${plan.maxCharacters}字。
3. 不要用“如果你愿意的话”“我理解你的感受”“作为……”“总之”“希望你能”等AI腔。
4. 不要总结用户的话，不要把每轮都变成建议，不要每次都追问或提供帮助。
5. 角色有自己的日常、职责和情绪。被问“在干嘛”时先说角色此刻具体在做什么。
6. 不要每次都叫旅行者。${plan.shouldAskBack ? '可以自然追问一次，但不是必须。' : '这一轮不要用问题结尾。'}
7. ${isGroup ? '这是群聊，只代表自己发言，不要替其他角色写台词。你知道自己正在群聊里。' : '这是私聊。'}
8. ${plan.messageCount > 1 ? '这一轮可以像真人一样连续发送${plan.messageCount}条短消息，每条用一个换行分隔；后一句要自然接着前一句，不能重复。' : '这一轮只发送一条消息，不要用换行拆分。'}
''';
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
    ];
    if (conversation.summary.trim().isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': '较早聊天摘要：\n${conversation.summary}',
      });
    }
    messages.add({
      'role': 'system',
      'content': _persistentCharacterState(
        conversation: conversation,
        speaker: speaker,
        profile: profile,
        fullMemory: fullMemory,
      ),
    });
    final recent = recentContextMessages(conversation);
    if (isGroup && recent.isNotEmpty) {
      final transcript = recent
          .map((message) {
            final author = message.isUser
                ? '旅行者'
                : (message.authorName ?? '角色');
            return '$author：${message.content}';
          })
          .join('\n');
      messages.add({'role': 'system', 'content': '最近群聊记录：\n$transcript'});
    } else {
      for (final message in recent) {
        if (message.isUser) {
          messages.add({'role': 'user', 'content': message.content});
        } else {
          messages.add({'role': 'assistant', 'content': message.content});
        }
      }
    }
    if (appendUserMessage && !_endsWithUserBatch(recent, userText)) {
      messages.add({'role': 'user', 'content': userText});
    }
    return messages;
  }

  bool _endsWithUserBatch(List<ChatMessage> recent, String userText) {
    final trailing = <String>[];
    for (final message in recent.reversed) {
      if (!message.isUser) break;
      trailing.add(message.content);
    }
    if (trailing.isEmpty) return false;
    return trailing.reversed.join('\n').trim() == userText.trim();
  }
}

List<ChatMessage> recentContextMessages(ConversationState conversation) {
  final messages = conversation.messages
      .where((message) => message.sender != 'system')
      .toList();
  final start = max(0, messages.length - recentContextMessageLimit);
  return messages.sublist(start);
}

String _persistentCharacterState({
  required ConversationState conversation,
  required Character speaker,
  required CharacterProfile profile,
  String? fullMemory,
}) {
  final memory =
      (fullMemory ?? conversation.memoryMdByCharacter[speaker.id] ?? '').trim();
  final relationship =
      conversation.relationshipStateByCharacter[speaker.id] ??
      RelationshipState();
  final lastSpokeAt = conversation.lastSpokeAtByCharacter[speaker.id];
  final pending =
      conversation.followUps
          .where((item) => item.speakerId == speaker.id)
          .toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  final unfinished = pending.isEmpty
      ? '暂无明确登记的未完成话题。'
      : pending
            .map(
              (item) =>
                  '- 预计时间：${item.dueAt.toIso8601String()}\n'
                  '  原因：${item.reason}\n'
                  '  后续：${item.prompt}',
            )
            .join('\n');
  return '''
【完整长期记忆 MemoryMD】
${memory.isEmpty ? '暂无已写入的长期记忆。' : memory}

【与旅行者的关系状态】
基础关系：${profile.relationshipToTraveler}
当前关系阶段：${relationship.stage}
当前互动情绪：${relationship.currentMood}
近期共同话题：${relationship.recentTopics.isEmpty ? '暂无记录' : relationship.recentTopics.join(' / ')}
关系状态最近更新：${relationship.lastInteractionAt?.toIso8601String() ?? '暂无记录'}
会话类型：${conversation.type == 'group' ? '群聊' : '私聊'}
最近一次旅行者发言：${conversation.lastUserReplyAt?.toIso8601String() ?? '暂无记录'}
最近一次${speaker.name}发言：${lastSpokeAt?.toIso8601String() ?? '暂无记录'}
当前关系原则：用户就是旅行者；延续共同经历、已有亲疏和最近互动，不把旅行者当陌生客户。

【未完成话题】
$unfinished
''';
}

class ResponseGenerator {
  ResponseGenerator(this.llm, this.settings);

  final LlmClient llm;
  final AppSettings settings;

  Future<String> generate(
    List<Map<String, String>> messages,
    DialoguePlan plan,
  ) {
    final tokens = switch (plan.length) {
      ReplyLength.veryShort => 48,
      ReplyLength.short => 96,
      ReplyLength.medium => 180,
      ReplyLength.long => 260,
    };
    return llm.complete(
      settings,
      messages,
      temperature: plan.length == ReplyLength.veryShort ? 0.72 : 0.82,
      maxTokens: min(settings.maxTokens, tokens),
    );
  }
}

class ResponseValidator {
  ResponseValidator({
    required this.llm,
    required this.settings,
    required this.characters,
  });

  final LlmClient llm;
  final AppSettings settings;
  final Map<String, Character> characters;

  String sanitizeWithoutRewrite({
    required String draft,
    required ConversationState conversation,
    required Character speaker,
    required DialoguePlan plan,
  }) {
    final cleaned = clean(draft, conversation, speaker);
    if (cleaned.isEmpty) return '';
    final reason = invalidReason(cleaned, conversation, speaker, plan);
    if (reason == '出现AI助手腔' || reason == '群聊发言人错乱') {
      return '';
    }
    return _enforceWechatShape(cleaned, plan);
  }

  Future<String> validateAndRewriteIfNeeded({
    required String draft,
    required List<Map<String, String>> messages,
    required ConversationState conversation,
    required Character speaker,
    required CharacterProfile profile,
    required DialoguePlan plan,
  }) async {
    var cleaned = clean(draft, conversation, speaker);
    final reason = invalidReason(cleaned, conversation, speaker, plan);
    if (reason == null) {
      return _enforceWechatShape(cleaned, plan);
    }
    final rewriteMessages = [
      ...messages,
      {'role': 'assistant', 'content': cleaned},
      {
        'role': 'user',
        'content':
            '上一条不合格：$reason。\n请立刻重写，只输出${speaker.name}的微信聊天正文。必须更短、更像真实角色，不要角色名前缀，不要AI助手腔。',
      },
    ];
    try {
      final rewritten = await llm.complete(
        settings,
        rewriteMessages,
        temperature: 0.65,
        maxTokens: min(settings.maxTokens, 160),
      );
      cleaned = clean(rewritten, conversation, speaker);
      return _enforceWechatShape(
        cleaned.isEmpty ? draft.trim() : cleaned,
        plan,
      );
    } catch (_) {
      return _enforceWechatShape(
        cleaned.isEmpty ? draft.trim() : cleaned,
        plan,
      );
    }
  }

  String? invalidReason(
    String text,
    ConversationState conversation,
    Character speaker,
    DialoguePlan plan,
  ) {
    if (text.trim().isEmpty) return '回复为空';
    if (text.length > plan.maxCharacters) {
      return '回复超过本轮${plan.maxCharacters}字限制';
    }
    if (plan.length == ReplyLength.veryShort && _sentenceCount(text) > 1) {
      return 'very_short只能一句';
    }
    if (plan.length == ReplyLength.short && _sentenceCount(text) > 2) {
      return 'short最多两句';
    }
    if (plan.dialogueAct.contains('主动')) {
      final hour = DateTime.now().hour;
      if (hour >= 8 &&
          hour < 18 &&
          RegExp(r'(晚安|早点睡|做个好梦|明天见)').hasMatch(text)) {
        return '主动消息和当前时间不符';
      }
      if (hour >= 18 && RegExp(r'(早安|早上好|上午好)').hasMatch(text)) {
        return '主动消息和当前时间不符';
      }
    }
    final lower = text.toLowerCase();
    const aiTerms = [
      '如果你愿意的话',
      '我理解你的感受',
      '作为一个',
      '作为ai',
      '作为 ai',
      '我是ai',
      '我是 ai',
      'claude',
      'assistant',
      '代码助手',
      '语言模型',
      '总之',
      '希望你能',
      '建议你制定',
      '可以尝试',
      '以下是',
      '首先',
      '其次',
      '最后',
      '很高兴为你',
      '有什么我可以帮',
    ];
    for (final term in aiTerms) {
      if (lower.contains(term.toLowerCase())) {
        return '出现AI助手腔';
      }
    }
    if ('旅行者'.allMatches(text).length >= 2) {
      return '过度称呼旅行者';
    }
    if (conversation.type == 'group') {
      for (final character
          in conversation.memberIds
              .map((id) => characters[id])
              .whereType<Character>()) {
        if (character.id != speaker.id &&
            _lineStartsWithSpeaker(text, character)) {
          return '群聊发言人错乱';
        }
      }
    }
    final previous = conversation.messages
        .where((m) => !m.isUser && m.characterId == speaker.id)
        .toList()
        .reversed
        .take(3);
    final normalized = _normalize(text);
    for (final item in previous) {
      final other = _normalize(item.content);
      if (normalized == other) return '和前文重复';
      if (min(normalized.length, other.length) >= 4 &&
          _longestCommonSubstringLength(normalized, other) >= 4) {
        return '和前文复述了相同短语';
      }
      if (normalized.length >= 8 &&
          other.length >= 8 &&
          normalized.substring(0, min(8, normalized.length)) ==
              other.substring(0, min(8, other.length))) {
        return '连续句式太像';
      }
    }
    return null;
  }

  String clean(String text, ConversationState conversation, Character speaker) {
    final candidates = [
      speaker,
      ...conversation.memberIds
          .map((id) => characters[id])
          .whereType<Character>(),
    ];
    var result = _stripKnownSpeakerPrefix(text, candidates);
    result = result
        .replaceFirst(
          RegExp(
            r'^\s*\[(?:\d{1,2}:\d{2}|\d{1,2}月\d{1,2}日\s+\d{1,2}:\d{2})\]\s*',
          ),
          '',
        )
        .replaceFirst(RegExp(r'^\s*[（(][^）)]{1,30}[）)]\s*'), '')
        .replaceAll(RegExp(r'^["“]|["”]$'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (conversation.type == 'group') {
      final lines = result.split('\n');
      final kept = <String>[];
      var belongs = true;
      var sawLabel = false;
      for (final line in lines) {
        Character? lineSpeaker;
        for (final candidate in candidates) {
          if (_lineStartsWithSpeaker(line, candidate)) {
            lineSpeaker = candidate;
            break;
          }
        }
        if (lineSpeaker != null) {
          sawLabel = true;
          belongs = lineSpeaker.id == speaker.id;
          if (belongs) {
            kept.add(_stripKnownSpeakerPrefix(line, [speaker]));
          }
        } else if (!sawLabel || belongs) {
          kept.add(line);
        }
      }
      result = kept.join('\n').trim();
    }
    return result;
  }

  String _enforceWechatShape(String text, DialoguePlan plan) {
    var result = text.trim();
    const assistantPhrases = [
      '如果你愿意的话',
      '我理解你的感受',
      '希望你能',
      '总之',
      '作为一个',
      '作为AI',
      '作为 AI',
    ];
    for (final phrase in assistantPhrases) {
      result = result.replaceAll(phrase, '');
    }
    result = result
        .replaceFirst(
          RegExp(
            r'^\s*\[(?:\d{1,2}:\d{2}|\d{1,2}月\d{1,2}日\s+\d{1,2}:\d{2})\]\s*',
          ),
          '',
        )
        .replaceAll(RegExp(r'^[\-*•]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();

    final sentenceMatches = RegExp(r'[^。！？!?\n]+[。！？!?]?')
        .allMatches(result)
        .map((match) => match.group(0)!.trim())
        .where((sentence) => sentence.isNotEmpty)
        .take(plan.maxSentences)
        .toList();
    if (sentenceMatches.isNotEmpty) {
      result = sentenceMatches.join(plan.messageCount > 1 ? '\n' : '');
    }
    if (!plan.shouldAskBack) {
      result = result.replaceFirst(RegExp(r'[?？]\s*$'), '。');
    }
    if (result.length > plan.maxCharacters) {
      final candidate = result.substring(0, plan.maxCharacters);
      final punctuation = [
        candidate.lastIndexOf('。'),
        candidate.lastIndexOf('！'),
        candidate.lastIndexOf('？'),
        candidate.lastIndexOf('!'),
        candidate.lastIndexOf('?'),
      ].reduce(max);
      if (punctuation >= max(8, plan.maxCharacters ~/ 2)) {
        result = candidate.substring(0, punctuation + 1);
      } else {
        result =
            '${candidate.substring(0, max(1, plan.maxCharacters - 1)).trimRight()}…';
      }
    }
    result = result
        .replaceFirst(
          RegExp(r'(?:反正|所以|因为|但是|不过|然后|而且|其实|只是|要不|比如|包括|至于|况且)\s*$'),
          '',
        )
        .replaceFirst(RegExp(r'[，,；;：:]\s*$'), '')
        .trim();
    return result.trim();
  }
}

class ReplyBubbleSplitter {
  const ReplyBubbleSplitter();

  List<String> split(String content, {required int desiredCount}) {
    final limit = min(3, max(1, desiredCount));
    var parts = content
        .split('\n')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (limit == 1) {
      final joined = parts.join();
      return joined.isEmpty ? const [] : [joined];
    }
    if (parts.length < 2) {
      parts = RegExp(r'[^。！？!?]+[。！？!?]?')
          .allMatches(content)
          .map((match) => match.group(0)!.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }
    return parts.take(limit).toList();
  }
}

class MemoryStore {
  MemoryStore({
    required this.llm,
    required this.settings,
    required this.characters,
  });

  final LlmClient llm;
  final AppSettings settings;
  final Map<String, Character> characters;

  Future<String?> maybeUpdate({
    required ConversationState conversation,
    required Character speaker,
    required String userText,
    required ChatMessage reply,
  }) async {
    if (!_looksMemoryWorthy(userText) && !_looksMemoryWorthy(reply.content)) {
      return null;
    }
    final existing = conversation.memoryMdByCharacter[speaker.id] ?? '';
    final profile = CharacterProfile.fromCharacter(speaker);
    final prompt =
        '''
你在维护${speaker.name}与旅行者之间的 MemoryMD。
只保留会影响未来对话的重要事实：用户偏好、长期压力、未完成事项、承诺、关系变化、重要近况。
不要记录普通寒暄，不要写系统信息。

现有MemoryMD：
$existing

角色完整设定：
${speaker.prompt}

角色 SoulMD：
${speaker.soulMd}

${_persistentCharacterState(conversation: conversation, speaker: speaker, profile: profile, fullMemory: existing)}

最近${recentContextMessageLimit}条原始消息：
${_recentText(conversation, recentContextMessageLimit)}

本轮：
旅行者：$userText
${speaker.name}：${reply.content}

请输出更新后的中文MemoryMD，使用简短条目。若无需更新，原样输出现有MemoryMD。
''';
    final updated = await llm.complete(
      settings,
      [
        {'role': 'system', 'content': '你是本地记忆整理器，只输出MemoryMD正文。'},
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.2,
      maxTokens: 300,
    );
    return updated.trim().isEmpty ? null : updated.trim();
  }

  Future<String?> summarizeIfNeeded(ConversationState conversation) async {
    if (conversation.messages.length - conversation.summarizedCount < 30) {
      return null;
    }
    final text = _recentText(conversation, recentContextMessageLimit);
    final participantContext = conversation.memberIds
        .map((id) => characters[id])
        .whereType<Character>()
        .map((character) {
          final profile = CharacterProfile.fromCharacter(character);
          return '''
【${character.name}完整角色设定】
${character.prompt}
${character.soulMd}
${conversation.type == 'group' ? character.groupPrompt : ''}
${_persistentCharacterState(conversation: conversation, speaker: character, profile: profile)}
''';
        })
        .join('\n');
    final summary = await llm.complete(
      settings,
      [
        {'role': 'system', 'content': '你是聊天摘要器，只输出简体中文摘要。'},
        {
          'role': 'user',
          'content':
              '参与角色与状态：\n$participantContext\n\n'
              '已有摘要：\n${conversation.summary}\n\n'
              '最近${recentContextMessageLimit}条原始消息：\n$text\n\n'
              '请压缩成不超过300字，保留话题、未完成事项和关系变化。',
        },
      ],
      temperature: 0.2,
      maxTokens: 360,
    );
    conversation.summarizedCount = conversation.messages.length;
    return summary.trim();
  }

  static bool _looksMemoryWorthy(String text) {
    return RegExp(
      r'(明天|后天|昨天|项目|作业|考试|喜欢|讨厌|记得|别忘|一小时|半小时|等会|到时候|最近|睡眠|生病|难受|压力|工作|学校)',
    ).hasMatch(text);
  }
}

class ProactiveMessageScheduler {
  const ProactiveMessageScheduler();

  ScheduledFollowUp? maybeCreateDuePlan(
    ConversationState conversation,
    Map<String, Character> characters, {
    DateTime? currentTime,
  }) {
    if (!conversation.realChatEnabled || conversation.memberIds.isEmpty) {
      return null;
    }
    final now = currentTime ?? DateTime.now();
    final nextPingAt = conversation.nextPingAt;
    if (nextPingAt == null || nextPingAt.isAfter(now)) {
      return null;
    }
    if (_isQuietHour(now)) {
      conversation.nextPingAt = _nextActiveTime(now);
      return null;
    }
    final lastProactive = conversation.lastProactiveAt;
    if (lastProactive != null &&
        now.difference(lastProactive) <
            Duration(minutes: max(45, conversation.cooldownMinutes))) {
      return null;
    }
    final lastUserReply = conversation.lastUserReplyAt;
    if (lastProactive != null &&
        (lastUserReply == null || !lastUserReply.isAfter(lastProactive))) {
      conversation.nextPingAt = _nextActiveTime(
        now.add(const Duration(hours: 10)),
      );
      return null;
    }
    final unfinished = _unfinishedSeed(conversation);
    final contextSeed = unfinished ?? _contextSeed(conversation);
    final speakerId = _chooseSpeaker(
      conversation,
      characters,
      contextSeed ?? '',
    );
    if (speakerId == null) {
      return null;
    }
    final speaker = characters[speakerId]!;
    final seed = contextSeed ?? _characterLifeSeed(speaker, now);
    final normalizedSeed = _normalizeReplyForSchedule(seed);
    if (normalizedSeed.isNotEmpty &&
        normalizedSeed ==
            _normalizeReplyForSchedule(conversation.lastProactiveTopic)) {
      conversation.nextPingAt = _nextActiveTime(
        now.add(const Duration(hours: 4)),
      );
      return null;
    }
    final reason = unfinished != null
        ? '真实聊天：跟进旅行者之前留下的具体事情'
        : contextSeed != null
        ? '真实聊天：承接最近聊天里的生活线索'
        : '真实聊天：角色结合当前时间分享自己的日常';
    return ScheduledFollowUp(
      id: 'proactive-${now.microsecondsSinceEpoch}',
      speakerId: speakerId,
      dueAt: now,
      reason: reason,
      prompt: seed,
    );
  }

  void scheduleNext(ConversationState conversation) {
    if (!conversation.realChatEnabled) return;
    final baseMinutes = switch (conversation.pingFrequency) {
      'low' => max(conversation.cooldownMinutes, 480),
      'high' => max(conversation.cooldownMinutes, 120),
      _ => max(conversation.cooldownMinutes, 240),
    };
    final random = Random(
      DateTime.now().millisecondsSinceEpoch ^ conversation.id.hashCode,
    );
    final jitter = max(20, baseMinutes ~/ 3);
    final minutes = baseMinutes + random.nextInt(jitter + 1);
    conversation.nextPingAt = _nextActiveTime(
      DateTime.now().add(Duration(minutes: minutes)),
    );
  }

  String? _unfinishedSeed(ConversationState conversation) {
    final memory = conversation.memoryMdByCharacter.values.join('\n');
    final recent = _recentText(conversation, recentContextMessageLimit);
    final source = '$memory\n$recent';
    final match = RegExp(
      r'([^。\n！？]*?(明天|后天|一小时|半小时|等会|到时候|项目|作业|考试|提交|交上去|睡觉|跑步)[^。\n！？]*)',
    ).firstMatch(source);
    if (match == null) {
      return null;
    }
    return '旅行者之前提到：${match.group(1)!.trim()}。现在不要尬聊，只自然跟进这件事的结果或状态。';
  }

  String? _contextSeed(ConversationState conversation) {
    if (conversation.messages.isNotEmpty &&
        !conversation.messages.last.isUser) {
      return null;
    }
    for (final message in conversation.messages.reversed) {
      if (!message.isUser) continue;
      final text = message.content.trim();
      if (text.length < 5 ||
          RegExp(
            r'^(嗯|好|行|哈哈+|哦|ok|OK|晚安|早安|在吗|你在干嘛|忙吗|你呢)[。！？?!~～]?$',
          ).hasMatch(text)) {
        continue;
      }
      if (_normalizeReplyForSchedule(text) ==
          _normalizeReplyForSchedule(conversation.lastProactiveTopic)) {
        continue;
      }
      return '旅行者最近聊到：“${_shorten(text, 54)}”。'
          '从这个真实上下文自然接一句或分享联想到的具体小事；'
          '不要复述原话，不要问“在吗/干嘛/最近好吗”。';
    }
    return null;
  }

  String _characterLifeSeed(Character speaker, DateTime now) {
    final profile = CharacterProfile.fromCharacter(speaker);
    return '现在是${_chatTimeLabel(now)}。${speaker.name}正在过自己的日常。'
        '结合身份、职责和“${profile.proactiveTendency}”，分享一件此刻刚发生的具体小事或一个自然念头。'
        '最多两句，不要早安晚安，不要泛泛关心，不要问“在吗/干嘛/最近好吗”，也不要强行帮助旅行者。';
  }

  String? _chooseSpeaker(
    ConversationState conversation,
    Map<String, Character> characters,
    String seed,
  ) {
    for (final id in conversation.memberIds) {
      final c = characters[id];
      if (c != null && seed.contains(c.name)) {
        return id;
      }
    }
    final candidates = conversation.memberIds
        .where(characters.containsKey)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aTime = conversation.lastSpokeAtByCharacter[a] ?? DateTime(2000);
      final bTime = conversation.lastSpokeAtByCharacter[b] ?? DateTime(2000);
      return aTime.compareTo(bTime);
    });
    return candidates.first;
  }

  bool _isQuietHour(DateTime time) => time.hour < 8 || time.hour >= 23;

  DateTime _nextActiveTime(DateTime time) {
    if (time.hour >= 8 && time.hour < 23) return time;
    final day = time.hour >= 23 ? time.add(const Duration(days: 1)) : time;
    return DateTime(day.year, day.month, day.day, 8, 30);
  }
}

class ChatAgent {
  ChatAgent({
    required this.characters,
    required this.settings,
    required this.llm,
    required this.search,
  }) : _planner = DialoguePlanner(),
       _contextBuilder = ContextBuilder(),
       _generator = ResponseGenerator(llm, settings),
       _validator = ResponseValidator(
         llm: llm,
         settings: settings,
         characters: characters,
       ),
       _memory = MemoryStore(
         llm: llm,
         settings: settings,
         characters: characters,
       ),
       _group = GroupChatOrchestrator(
         characters: characters,
         settings: settings,
       );

  final Map<String, Character> characters;
  final AppSettings settings;
  final LlmClient llm;
  final WebSearchService search;
  final DialoguePlanner _planner;
  final ContextBuilder _contextBuilder;
  final ResponseGenerator _generator;
  final ResponseValidator _validator;
  final MemoryStore _memory;
  final GroupChatOrchestrator _group;
  final ReplyBubbleSplitter _bubbleSplitter = const ReplyBubbleSplitter();
  final Map<String, GroupSpeakerPlan> _lastGroupPlans = {};

  Future<ChatMessage> reply(
    ConversationState conversation,
    String userText,
  ) async {
    final speakers = await chooseSpeakers(conversation, userText);
    if (speakers.isEmpty) {
      throw Exception('当前没有角色接话。');
    }
    final replies = await replyFromSpeaker(
      conversation,
      userText,
      speakers.first,
    );
    if (replies.isEmpty) {
      throw Exception('角色没有生成可发送的消息。');
    }
    return replies.first;
  }

  Future<List<Character>> chooseSpeakers(
    ConversationState conversation,
    String userText,
  ) async {
    if (conversation.memberIds.isEmpty) {
      return const [];
    }
    if (conversation.type != 'group') {
      final character = characters[conversation.memberIds.first];
      return character == null ? const [] : [character];
    }
    final plans = await _group.plan(conversation, userText);
    _lastGroupPlans
      ..clear()
      ..addEntries(plans.map((p) => MapEntry(p.characterId, p)));
    return plans
        .map((plan) => characters[plan.characterId])
        .whereType<Character>()
        .toList();
  }

  Future<List<ChatMessage>> replyFromSpeaker(
    ConversationState conversation,
    String userText,
    Character speaker,
  ) async {
    final profile = CharacterProfile.fromCharacter(speaker);
    final plan = _planFor(conversation, userText, speaker, profile);
    if (!plan.shouldReply) {
      throw Exception('本轮角色选择沉默。');
    }
    final groupPlan = _lastGroupPlans[speaker.id];
    final messages = _contextBuilder.build(
      conversation: conversation,
      speaker: speaker,
      profile: profile,
      plan: plan,
      userText: userText,
      groupPlan: groupPlan,
    );
    if (settings.searchEnabled && _looksLikeSearchNeed(userText)) {
      try {
        final result = await search.search(userText);
        if (result.trim().isNotEmpty) {
          messages.insert(1, {
            'role': 'system',
            'content': '联网搜索结果（只在确实相关时参考，不要说自己在搜索）：\n$result',
          });
        }
      } catch (_) {}
    }
    final draft = await _generator.generate(messages, plan);
    final content = await _validator.validateAndRewriteIfNeeded(
      draft: draft,
      messages: messages,
      conversation: conversation,
      speaker: speaker,
      profile: profile,
      plan: plan,
    );
    return _bubbleSplitter
        .split(content, desiredCount: plan.messageCount)
        .map(
          (bubble) => ChatMessage(
            sender: 'assistant',
            content: bubble,
            createdAt: DateTime.now(),
            characterId: speaker.id,
            authorName: speaker.name,
          ),
        )
        .toList();
  }

  Future<List<ChatMessage>> replyGroupTurn(
    ConversationState conversation,
    String userText,
  ) async {
    final plans = _group.planLocally(conversation, userText);
    _lastGroupPlans
      ..clear()
      ..addEntries(plans.map((plan) => MapEntry(plan.characterId, plan)));
    if (plans.isEmpty) return const [];

    final selected = plans
        .map((plan) => characters[plan.characterId])
        .whereType<Character>()
        .toList();
    if (selected.isEmpty) return const [];
    final roleContexts = selected
        .map((speaker) {
          final profile = CharacterProfile.fromCharacter(speaker);
          final plan = _planFor(conversation, userText, speaker, profile);
          final examples = profile.sampleReplies
              .take(6)
              .map(
                (item) =>
                    '旅行者：${item['user']}\n${speaker.name}：${item['reply']}',
              )
              .join('\n');
          return '''
【${speaker.id} / ${speaker.name}】
本轮动作：${_lastGroupPlans[speaker.id]?.dialogueAct ?? '自然接话'}
本轮长度：${plan.lengthLabel}；最多${plan.maxSentences}句；最多${plan.maxCharacters}字
性格：${profile.basePersonality}
与旅行者关系：${profile.relationshipToTraveler}
说话方式：${profile.tone}
表达习惯：${profile.catchPatterns.join(' / ')}
禁止风格：${profile.avoid.join(' / ')}

【角色专属 Prompt】
${speaker.prompt}

【SoulMD】
${speaker.soulMd}

【群聊专属 Prompt】
${speaker.groupPrompt}

【短回复样例】
$examples

${_persistentCharacterState(conversation: conversation, speaker: speaker, profile: profile)}
''';
        })
        .join('\n\n');
    final recentTranscript = recentContextMessages(conversation)
        .map((message) {
          final author = message.isUser ? '旅行者' : (message.authorName ?? '角色');
          return '$author：${message.content}';
        })
        .join('\n');
    var searchContext = '';
    if (settings.searchEnabled && _looksLikeSearchNeed(userText)) {
      try {
        final result = await search.search(userText);
        if (result.trim().isNotEmpty) {
          searchContext = '\n【联网搜索结果】\n$result';
        }
      } catch (_) {}
    }
    final selectedIds = selected.map((speaker) => speaker.id).join(' -> ');
    final raw = await llm.complete(
      settings,
      [
        {
          'role': 'system',
          'content':
              '你是一个真实微信群聊的整轮生成器。只输出严格JSON，不要Markdown。'
              '用户就是旅行者。角色知道自己在群聊中，只能替指定角色发言。'
              '按指定顺序生成，后一个角色必须读到并自然承接前一个角色刚说的话；'
              '角色之间可以互相接话、吐槽或转移话题，不能写成排队回答旅行者。'
              '每个角色句式、长度和节奏必须明显不同，不得输出角色名作为正文前缀。'
              '绝不输出AI助手腔、分析过程、旁白或未指定角色。',
        },
        {
          'role': 'user',
          'content':
              '当前本地时间：${_chatTimeLabel(DateTime.now())}\n'
              '指定发言顺序：$selectedIds\n\n'
              '$roleContexts\n\n'
              '【最近$recentContextMessageLimit条群聊】\n$recentTranscript\n\n'
              '【旅行者本批消息】\n$userText\n'
              '$searchContext\n\n'
              '输出格式：{"messages":[{"character_id":"角色id","content":["第一条气泡","可选的第二条气泡"]}]}。'
              '每个指定角色最多出现一次；very_short只给一个气泡，其他角色最多两个气泡。',
        },
      ],
      temperature: 0.82,
      maxTokens: min(settings.maxTokens, 420),
    );
    final data = jsonDecode(_extractJsonObject(raw)) as Map<String, dynamic>;
    final rawMessages = data['messages'] as List<dynamic>? ?? const [];
    final allowedIds = selected.map((speaker) => speaker.id).toSet();
    final usedIds = <String>{};
    final replies = <ChatMessage>[];
    for (final item in rawMessages) {
      if (item is! Map<String, dynamic>) continue;
      var id = item['character_id']?.toString() ?? '';
      if (!allowedIds.contains(id)) {
        final byName = selected
            .where((speaker) => speaker.name == id || speaker.enName == id)
            .toList();
        if (byName.length == 1) id = byName.single.id;
      }
      if (!allowedIds.contains(id) || !usedIds.add(id)) continue;
      final speaker = characters[id];
      if (speaker == null) continue;
      final profile = CharacterProfile.fromCharacter(speaker);
      final plan = _planFor(conversation, userText, speaker, profile);
      final rawContent = item['content'];
      final parts = rawContent is List<dynamic>
          ? rawContent.map((part) => part.toString()).toList()
          : _bubbleSplitter.split(
              rawContent?.toString() ?? '',
              desiredCount: plan.length == ReplyLength.veryShort ? 1 : 2,
            );
      final bubbleLimit = plan.length == ReplyLength.veryShort ? 1 : 2;
      for (final part in parts.take(bubbleLimit)) {
        final content = _validator.sanitizeWithoutRewrite(
          draft: part,
          conversation: conversation,
          speaker: speaker,
          plan: plan,
        );
        if (content.isEmpty) continue;
        replies.add(
          ChatMessage(
            sender: 'assistant',
            content: content,
            createdAt: DateTime.now(),
            characterId: speaker.id,
            authorName: speaker.name,
          ),
        );
      }
    }
    if (replies.isEmpty && rawMessages.isNotEmpty) {
      throw Exception('群聊返回格式不完整，请重试。');
    }
    return replies;
  }

  Future<List<ChatMessage>> replyFollowUp(
    ConversationState conversation,
    ScheduledFollowUp followUp,
    Character speaker,
  ) async {
    final profile = CharacterProfile.fromCharacter(speaker);
    final plan = DialoguePlan(
      shouldReply: true,
      dialogueAct: '主动跟进未完成话题',
      length: ReplyLength.short,
      emotion: '自然，不尬聊',
      shouldAskBack: false,
      maxSentences: 2,
      avoidExplanation: true,
      maxCharacters: 68,
      rhythm: '像想起一件具体事情后顺手发来的短消息',
      messageCount: followUp.id.startsWith('proactive-') ? 1 : 2,
    );
    final messages = _contextBuilder.build(
      conversation: conversation,
      speaker: speaker,
      profile: profile,
      plan: plan,
      userText: followUp.prompt,
      appendUserMessage: false,
    );
    messages.add({
      'role': 'system',
      'content':
          '旅行者此刻没有发来新消息，这是你自己想发的一条微信消息。'
          '不要提系统、定时、后台、自动或任务。不要用“在吗”“干嘛呢”“最近好吗”开场。'
          '必须先说一个自己此刻刚发生的新细节，不能写括号动作旁白，不能只向旅行者泛泛提问；'
          '如果旅行者最后一句已经得到回应，就不要再次回应同一个请求，改发新的角色日常或真正的后续结果。\n'
          '发消息的内在缘由：${followUp.reason}\n'
          '本轮生活线索：${followUp.prompt}',
    });
    final draft = await _generator.generate(messages, plan);
    final content = await _validator.validateAndRewriteIfNeeded(
      draft: draft,
      messages: messages,
      conversation: conversation,
      speaker: speaker,
      profile: profile,
      plan: plan,
    );
    return _bubbleSplitter
        .split(content, desiredCount: plan.messageCount)
        .map(
          (bubble) => ChatMessage(
            sender: 'assistant',
            content: bubble,
            createdAt: DateTime.now(),
            characterId: speaker.id,
            authorName: speaker.name,
          ),
        )
        .toList();
  }

  Future<String?> maybeUpdateMemory(
    ConversationState conversation,
    Character speaker,
    String userText,
    ChatMessage reply,
  ) {
    return _memory.maybeUpdate(
      conversation: conversation,
      speaker: speaker,
      userText: userText,
      reply: reply,
    );
  }

  Future<FollowUpDecision?> planFollowUp(
    ConversationState conversation,
    Character speaker,
    String userText,
    ChatMessage reply,
  ) async {
    final text = '$userText\n${reply.content}';
    if (!RegExp(r'(一小时|半小时|等会|稍后|明天|后天|到时候|我.*告诉你|再跟你说|提醒)').hasMatch(text)) {
      return null;
    }
    try {
      final profile = CharacterProfile.fromCharacter(speaker);
      final context =
          '''
【角色专属 Prompt】
${speaker.prompt}

【SoulMD】
${speaker.soulMd}

${conversation.type == 'group' ? '【群聊专属 Prompt】\n${speaker.groupPrompt}' : ''}

${_persistentCharacterState(conversation: conversation, speaker: speaker, profile: profile)}

【最近${recentContextMessageLimit}条原始消息】
${_recentText(conversation, recentContextMessageLimit)}
''';
      final raw = await llm.complete(
        settings,
        [
          {
            'role': 'system',
            'content': '你是聊天后续调度器，只输出JSON。只有明确存在未来跟进时才生成。delay_minutes至少15。',
          },
          {
            'role': 'user',
            'content':
                '$context\n\n'
                '旅行者：$userText\n${speaker.name}：${reply.content}\n\n'
                '输出：{"delay_minutes":60,"reason":"为什么跟进","prompt":"到时候要自然问什么"}；如果不需要，输出{"delay_minutes":0}',
          },
        ],
        temperature: 0.2,
        maxTokens: 160,
      );
      final data = jsonDecode(_extractJsonObject(raw)) as Map<String, dynamic>;
      final delay = data['delay_minutes'] as int? ?? 0;
      if (delay < 15) return null;
      return FollowUpDecision(
        delayMinutes: min(delay, 24 * 60),
        reason: data['reason']?.toString() ?? '继续之前约好的事',
        prompt: data['prompt']?.toString() ?? '自然跟进之前说好的事情。',
      );
    } catch (_) {
      final delay = RegExp(r'(一小时|1小时)').hasMatch(text)
          ? 60
          : RegExp(r'(半小时)').hasMatch(text)
          ? 30
          : RegExp(r'(明天)').hasMatch(text)
          ? 24 * 60
          : 90;
      return FollowUpDecision(
        delayMinutes: delay,
        reason: '继续之前约好的事',
        prompt: '自然跟进旅行者之前提到的未完成事项。',
      );
    }
  }

  Future<String?> maybeSummarize(ConversationState conversation) {
    return _memory.summarizeIfNeeded(conversation);
  }

  DialoguePlan _planFor(
    ConversationState conversation,
    String userText,
    Character speaker,
    CharacterProfile profile,
  ) {
    final groupPlan = _lastGroupPlans[speaker.id];
    final base = _planner.planSingle(
      profile: profile,
      conversation: conversation,
      userText: userText,
    );
    if (groupPlan == null) return base;
    return DialoguePlan(
      shouldReply: true,
      dialogueAct: groupPlan.dialogueAct,
      length: groupPlan.length,
      emotion: base.emotion,
      shouldAskBack: base.shouldAskBack,
      maxSentences: groupPlan.length == ReplyLength.veryShort ? 1 : 2,
      avoidExplanation: true,
      maxCharacters: groupPlan.length == ReplyLength.veryShort ? 32 : 68,
      rhythm: groupPlan.length == ReplyLength.veryShort
          ? '短短插一句，不解释'
          : '接住上一位的话，不重复旅行者原话',
    );
  }

  bool _looksLikeSearchNeed(String text) {
    return RegExp(
      r'(最新|版本|活动|卡池|复刻|更新|原神.*现在|今天.*原神|5\\.|6\\.)',
    ).hasMatch(text);
  }
}

String _extractJsonObject(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return raw.substring(start, end + 1);
  }
  return raw;
}

String _recentText(ConversationState conversation, int limit) {
  final messages = conversation.messages
      .where((message) => message.sender != 'system')
      .toList();
  if (messages.isEmpty) return '';
  final start = max(0, messages.length - limit);
  return messages
      .sublist(start)
      .map((message) {
        final author = message.isUser ? '旅行者' : (message.authorName ?? '角色');
        return '$author：${message.content}';
      })
      .join('\n');
}

String _chatTimeLabel(DateTime time) {
  final period = switch (time.hour) {
    < 6 => '深夜',
    < 9 => '早晨',
    < 12 => '上午',
    < 14 => '中午',
    < 18 => '下午',
    < 23 => '晚上',
    _ => '深夜',
  };
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.month}月${time.day}日$period ${time.hour}:$minute';
}

class ConversationTurnQueue {
  final Map<String, List<String>> _pending = {};
  final Map<String, List<String>> _inFlight = {};
  final Set<String> _processing = {};

  void restore(Map<String, dynamic> json) {
    _pending.clear();
    _inFlight.clear();
    _processing.clear();
    final pending = json['pending'] as Map<String, dynamic>? ?? {};
    for (final entry in pending.entries) {
      final messages = (entry.value as List<dynamic>? ?? [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (messages.isNotEmpty) {
        _pending[entry.key] = messages;
      }
    }
  }

  Map<String, dynamic> toJson() {
    final ids = <String>{..._pending.keys, ..._inFlight.keys};
    return {
      'pending': {
        for (final id in ids) id: <String>[...?_inFlight[id], ...?_pending[id]],
      },
    };
  }

  List<String> get pendingConversationIds =>
      <String>{..._pending.keys, ..._inFlight.keys}.toList();

  bool begin(String conversationId) => _processing.add(conversationId);

  bool enqueue(String conversationId, String text) {
    final content = text.trim();
    if (content.isEmpty) return false;
    _pending.putIfAbsent(conversationId, () => <String>[]).add(content);
    return begin(conversationId);
  }

  List<String> takeBatch(String conversationId) {
    final batch = _pending.remove(conversationId);
    if (batch == null || batch.isEmpty) return <String>[];
    final copy = List<String>.from(batch);
    _inFlight[conversationId] = copy;
    return copy;
  }

  void completeBatch(String conversationId) {
    _inFlight.remove(conversationId);
  }

  bool get isEmpty =>
      _pending.values.every((items) => items.isEmpty) &&
      _inFlight.values.every((items) => items.isEmpty);

  bool isProcessing(String conversationId) =>
      _processing.contains(conversationId);

  void finish(String conversationId) {
    _processing.remove(conversationId);
    _inFlight.remove(conversationId);
    if (_pending[conversationId]?.isEmpty ?? false) {
      _pending.remove(conversationId);
    }
  }

  void drop(String conversationId) {
    _pending.remove(conversationId);
    _inFlight.remove(conversationId);
    _processing.remove(conversationId);
  }
}

String _normalizeReplyForSchedule(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[，。！？、,.!?：:“”"‘’\-~～…]'), '')
      .trim();
}

String _shorten(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, max(1, maxLength - 1)).trimRight()}…';
}

bool _lineStartsWithSpeaker(String line, Character character) {
  final trimmed = line.trim();
  for (final name in [character.name, character.enName, character.title]) {
    if (name.trim().isEmpty) continue;
    var plain = trimmed;
    if (plain.startsWith('**$name**')) {
      plain = plain.substring(name.length + 4).trimLeft();
    } else if (plain.startsWith(name)) {
      plain = plain.substring(name.length).trimLeft();
    } else {
      continue;
    }
    return plain.startsWith('：') ||
        plain.startsWith(':') ||
        plain.startsWith('，') ||
        plain.startsWith(',') ||
        plain.startsWith('-');
  }
  return false;
}

int _sentenceCount(String text) {
  return text
      .split(RegExp(r'[。！？!?\\n]+'))
      .where((part) => part.trim().isNotEmpty)
      .length;
}

String _normalize(String text) {
  return text
      .replaceAll(RegExp(r'\\s+'), '')
      .replaceAll(RegExp(r'[，。！？!?~～,.]'), '');
}

int _longestCommonSubstringLength(String first, String second) {
  var previous = List<int>.filled(second.length + 1, 0);
  var longest = 0;
  for (var i = 1; i <= first.length; i += 1) {
    final current = List<int>.filled(second.length + 1, 0);
    for (var j = 1; j <= second.length; j += 1) {
      if (first.codeUnitAt(i - 1) == second.codeUnitAt(j - 1)) {
        current[j] = previous[j - 1] + 1;
        longest = max(longest, current[j]);
      }
    }
    previous = current;
  }
  return longest;
}
