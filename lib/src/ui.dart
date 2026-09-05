part of '../main.dart';

class WeChatHomeShell extends StatelessWidget {
  const WeChatHomeShell({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.chatsPage,
    required this.contactsPage,
    required this.mePage,
  });

  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final Widget chatsPage;
  final Widget contactsPage;
  final Widget mePage;

  @override
  Widget build(BuildContext context) {
    final titles = ['提瓦特微信', '通讯录', '我的'];
    final pages = [chatsPage, contactsPage, mePage];
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: const Color(0xCFFFFFFF),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x9EFFFFFF),
                border: Border(
                  bottom: BorderSide(color: _wechatLine, width: 0.6),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          titles[currentIndex],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFB), Color(0xFFF0F4F2), Color(0xFFF7F5EF)],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.018, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(currentIndex),
            child: pages[currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: _WeChatTabBar(
        currentIndex: currentIndex,
        onChanged: onTabChanged,
      ),
    );
  }
}

class _WeChatTabBar extends StatelessWidget {
  const _WeChatTabBar({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _wechatBar,
              border: Border.all(color: const Color(0x7AFFFFFF), width: 0.8),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A27313A),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  _WeChatTabItem(
                    icon: Icons.chat_bubble_outline,
                    selectedIcon: Icons.chat_bubble,
                    label: '聊天',
                    selected: currentIndex == 0,
                    onTap: () => onChanged(0),
                  ),
                  _WeChatTabItem(
                    icon: Icons.perm_contact_calendar_outlined,
                    selectedIcon: Icons.perm_contact_calendar,
                    label: '通讯录',
                    selected: currentIndex == 1,
                    onTap: () => onChanged(1),
                  ),
                  _WeChatTabItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: '我',
                    selected: currentIndex == 2,
                    onTap: () => onChanged(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeChatTabItem extends StatelessWidget {
  const _WeChatTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _wechatGreen : const Color(0xFF737A82);
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        splashColor: Colors.transparent,
        highlightColor: const Color(0x11000000),
        child: AnimatedScale(
          scale: selected ? 1.03 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x1607C160)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatsHomePage extends StatelessWidget {
  const ChatsHomePage({
    super.key,
    required this.conversations,
    required this.characters,
    required this.typingLabel,
    required this.onCreateGroup,
    required this.onOpen,
  });

  final List<ConversationState> conversations;
  final Map<String, Character> characters;
  final String? Function(String id) typingLabel;
  final VoidCallback onCreateGroup;
  final ValueChanged<ConversationState> onOpen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 108),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 7),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final subtitle =
                typingLabel(conversation.id) ?? conversation.preview;
            return Material(
              color: const Color(0xDFFFFFFF),
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                splashColor: Colors.transparent,
                highlightColor: const Color(0x11000000),
                onTap: () => onOpen(conversation),
                child: SizedBox(
                  height: 76,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _conversationAvatar(conversation, characters),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conversation.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        height: 1.15,
                                        fontWeight: FontWeight.w500,
                                        color: _wechatText,
                                      ),
                                    ),
                                  ),
                                  if (conversation.realChatEnabled) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                      color: _wechatGreen,
                                    ),
                                  ],
                                ],
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.15,
                                    color: typingLabel(conversation.id) != null
                                        ? _wechatGreen
                                        : _wechatSubText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (conversation.messages.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 28),
                            child: Text(
                              _formatListTime(conversation.updatedAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB2B2B2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 98,
          child: SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: 'create-group-fab',
              onPressed: onCreateGroup,
              elevation: 0,
              backgroundColor: _wechatGreen,
              foregroundColor: Colors.white,
              child: const Icon(Icons.group_add_outlined),
            ),
          ),
        ),
      ],
    );
  }

  Widget _conversationAvatar(
    ConversationState conversation,
    Map<String, Character> characters,
  ) {
    if (conversation.type == 'group') {
      return const Avatar(isGroup: true, size: 54, label: '群');
    }
    final character =
        characters[conversation.memberIds.isEmpty
            ? conversation.id
            : conversation.memberIds.first];
    return Avatar(character: character, size: 54);
  }
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({
    super.key,
    required this.characters,
    required this.showGuide,
    required this.onOpenContact,
    required this.onCreateGroup,
  });

  final List<Character> characters;
  final bool showGuide;
  final ValueChanged<Character> onOpenContact;
  final VoidCallback onCreateGroup;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.characters.where((character) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim();
      return character.name.contains(q) ||
          character.enName.toLowerCase().contains(q.toLowerCase()) ||
          character.vision.contains(q) ||
          character.nation.contains(q);
    }).toList();

    return Column(
      children: [
        Material(
          color: const Color(0xCFFFFFFF),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showGuide)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xBFEAF8EF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '先从通讯录选择角色并发出第一条消息，私聊才会出现在聊天页。',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                TextField(
                  controller: _controller,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: '搜索角色名字、元素或地区',
                    filled: true,
                    fillColor: const Color(0xBFFFFFFF),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xAFFFFFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '角色库',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '这里是全部原神角色。你可以发起私聊，也可以把角色加入群聊。',
                        style: TextStyle(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 104),
            itemCount: filtered.length + 1,
            separatorBuilder: (_, __) => const Divider(
              height: 0.5,
              thickness: 0.5,
              indent: 72,
              color: _wechatLine,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Material(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _jade,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.group_add, color: Colors.white),
                    ),
                    title: const Text('创建群聊'),
                    subtitle: const Text('选择角色，创建一个新的提瓦特群聊'),
                    onTap: widget.onCreateGroup,
                  ),
                );
              }
              final character = filtered[index - 1];
              return Material(
                color: Colors.white,
                child: ListTileTheme(
                  minVerticalPadding: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Avatar(character: character, size: 48),
                    title: Text(
                      character.name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        color: _wechatText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      character.publicInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _wechatSubText),
                    ),
                    onTap: () => widget.onOpenContact(character),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.settings,
    required this.liveConversationCount,
    required this.totalConversationCount,
    required this.onEditSettings,
    required this.onToggleSearch,
    required this.onSelectTraveler,
  });

  final AppSettings settings;
  final int liveConversationCount;
  final int totalConversationCount;
  final VoidCallback onEditSettings;
  final ValueChanged<bool> onToggleSearch;
  final ValueChanged<String> onSelectTraveler;

  @override
  Widget build(BuildContext context) {
    final apiReady = settings.apiKey.trim().isNotEmpty;
    final traveler = settings.traveler;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 108),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D2C3A43),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          child: Row(
            children: [
              Avatar(
                imageUrl: traveler.avatarUrl,
                label: traveler.name,
                size: 68,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '旅行者 · ${traveler.name}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      apiReady ? 'API 已准备好，可以开始聊天。' : '请先填写 API Key。',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: traveler.name == '空' ? '切换为荧' : '切换为空',
                child: IconButton.filledTonal(
                  onPressed: () => onSelectTraveler(
                    settings.travelerId == 'aether' ? 'lumine' : 'aether',
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _MeSection(
          children: [
            _MeSwitchTile(
              icon: Icons.travel_explore_outlined,
              title: '联网搜索',
              subtitle: settings.searchEnabled ? '已开启' : '已关闭',
              value: settings.searchEnabled,
              onChanged: onToggleSearch,
            ),
            _MeTile(
              icon: Icons.key_outlined,
              title: 'API 设置',
              subtitle: apiReady ? settings.model : '请先填写 API Key',
              onTap: onEditSettings,
            ),
            _MeTile(
              icon: Icons.schedule_outlined,
              title: '待跟进提醒数',
              subtitle: '$liveConversationCount 个待处理提醒',
            ),
            _MeTile(
              icon: Icons.chat_bubble_outline,
              title: '当前聊天数量',
              subtitle: '$totalConversationCount 个聊天窗口',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MeSection(
          children: [
            _MeTile(
              icon: Icons.info_outline,
              title: '系统信息',
              subtitle: '聊天记录、角色设定和角色记忆都只保存在本地。',
            ),
            _MeTile(
              icon: Icons.new_releases_outlined,
              title: '当前版本',
              subtitle: _appVersion,
            ),
          ],
        ),
      ],
    );
  }
}

class WelcomeSetupPage extends StatefulWidget {
  const WelcomeSetupPage({
    super.key,
    required this.initialSettings,
    required this.onSave,
  });

  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onSave;

  @override
  State<WelcomeSetupPage> createState() => _WelcomeSetupPageState();
}

class _WelcomeSetupPageState extends State<WelcomeSetupPage> {
  late final TextEditingController _apiKey;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late String _apiFormat;
  late bool _searchEnabled;
  bool _testingApi = false;

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController(text: widget.initialSettings.apiKey);
    _baseUrl = TextEditingController(text: widget.initialSettings.baseUrl);
    _model = TextEditingController(text: widget.initialSettings.model);
    _apiFormat = widget.initialSettings.apiFormat;
    _searchEnabled = widget.initialSettings.searchEnabled;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  void _changeApiFormat(String value) {
    setState(() {
      final oldFormat = _apiFormat;
      _apiFormat = value;
      if (oldFormat != value) {
        if (value == 'anthropic') {
          if (_baseUrl.text.trim().isEmpty ||
              _baseUrl.text.contains('openai.com')) {
            _baseUrl.text = 'https://api.anthropic.com/v1/messages';
          }
          if (_model.text.trim().isEmpty || _model.text.startsWith('gpt-')) {
            _model.text = 'claude-3-5-sonnet-latest';
          }
        } else {
          if (_baseUrl.text.trim().isEmpty ||
              _baseUrl.text.contains('anthropic.com')) {
            _baseUrl.text = 'https://api.openai.com/v1/chat/completions';
          }
          if (_model.text.trim().isEmpty || _model.text.startsWith('claude-')) {
            _model.text = 'gpt-4.1-mini';
          }
        }
      }
    });
  }

  AppSettings _currentSettings() {
    return widget.initialSettings.copyWith(
      apiKey: _apiKey.text.trim(),
      apiFormat: _apiFormat,
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
      searchEnabled: _searchEnabled,
    );
  }

  Future<void> _testApi() async {
    if (_apiKey.text.trim().isEmpty) {
      await _showApiTestDialog(
        context,
        success: false,
        message: '请先填写 API Key。',
      );
      return;
    }
    setState(() => _testingApi = true);
    try {
      await LlmClient(HttpTextClient()).testConnection(_currentSettings());
      if (!mounted) return;
      await _showApiTestDialog(
        context,
        success: true,
        message: '连接成功，当前接口地址、API Key 和模型均可正常调用。',
      );
    } catch (error) {
      if (!mounted) return;
      await _showApiTestDialog(
        context,
        success: false,
        message: _friendlyLocalError(error),
      );
    } finally {
      if (mounted) setState(() => _testingApi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _jade,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '欢迎来到提瓦特微信',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                '先填好你自己的 LLM API Key，我们就能开始聊天了。默认首页只会显示一个提瓦特群聊，之后你可以去通讯录添加角色，发出第一条消息后，对话就会自动出现在聊天列表里。',
                style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 28),
              _SettingsFormCard(
                apiKey: _apiKey,
                apiFormat: _apiFormat,
                onApiFormatChanged: _changeApiFormat,
                baseUrl: _baseUrl,
                model: _model,
                testingApi: _testingApi,
                onTestApi: _testApi,
                searchEnabled: _searchEnabled,
                onSearchChanged: (value) =>
                    setState(() => _searchEnabled = value),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  if (_apiKey.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先填写 API Key')),
                    );
                    return;
                  }
                  widget.onSave(_currentSettings());
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _jade,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('保存并进入'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConversationListPage extends StatelessWidget {
  const ConversationListPage({
    super.key,
    required this.conversations,
    required this.characters,
    required this.typingLabel,
    required this.onCreateGroup,
    required this.onOpen,
    required this.onSettings,
  });

  final List<ConversationState> conversations;
  final Map<String, Character> characters;
  final String? Function(String id) typingLabel;
  final VoidCallback onCreateGroup;
  final ValueChanged<ConversationState> onOpen;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDF1EA),
        title: const Text('提瓦特微信'),
        actions: [
          IconButton(
            tooltip: '创建群聊',
            onPressed: onCreateGroup,
            icon: const Icon(Icons.group_add_outlined),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ChatsHomePage(
        conversations: conversations,
        characters: characters,
        typingLabel: typingLabel,
        onCreateGroup: onCreateGroup,
        onOpen: onOpen,
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    required this.characters,
    required this.traveler,
    required this.updates,
    required this.typingLabel,
    required this.onSend,
    required this.onEditGroup,
    required this.onDeleteGroup,
    required this.onToggleRealChat,
  });

  final ConversationState conversation;
  final Map<String, Character> characters;
  final TravelerProfile traveler;
  final ValueListenable<int> updates;
  final String? Function(String id) typingLabel;
  final Future<void> Function(ConversationState conversation, String text)
  onSend;
  final ValueChanged<ConversationState> onEditGroup;
  final ValueChanged<ConversationState> onDeleteGroup;
  final ValueChanged<ConversationState> onToggleRealChat;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {});
    await widget.onSend(widget.conversation, text);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.updates,
      builder: (context, _, __) {
        final conversation = widget.conversation;
        final isGroup = conversation.type == 'group';
        final typing = isGroup ? null : widget.typingLabel(conversation.id);
        final messages = conversation.messages;

        return Scaffold(
          backgroundColor: _wechatChatBg,
          appBar: AppBar(
            toolbarHeight: 48,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    border: const Border(
                      bottom: BorderSide(color: _wechatLine, width: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (typing != null)
                  Text(
                    typing,
                    style: const TextStyle(fontSize: 12, color: _jade),
                  ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: conversation.realChatEnabled ? '关闭真实聊天' : '开启真实聊天',
                onPressed: () {
                  if (!conversation.realChatEnabled) {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('开启真实聊天？'),
                        content: const Text(
                          '开启后角色会根据上下文和记忆主动跟进未完成的话题，可能增加 API 调用和 token 消耗。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              widget.onToggleRealChat(conversation);
                            },
                            child: const Text('开启'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    widget.onToggleRealChat(conversation);
                  }
                },
                icon: Icon(
                  conversation.realChatEnabled
                      ? Icons.auto_awesome
                      : Icons.auto_awesome_outlined,
                  color: conversation.realChatEnabled ? _wechatGreen : null,
                ),
              ),
              if (isGroup)
                IconButton(
                  tooltip: '管理成员',
                  onPressed: () => widget.onEditGroup(conversation),
                  icon: const Icon(Icons.groups_2_outlined),
                ),
              if (isGroup)
                IconButton(
                  tooltip: '删除群聊',
                  onPressed: () => widget.onDeleteGroup(conversation),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4F6F8), Color(0xFFF0F5F2)],
              ),
            ),
            child: Column(
              children: [
                if (isGroup)
                  GroupMembersBar(
                    memberIds: conversation.memberIds,
                    characters: widget.characters,
                  ),
                Expanded(
                  child: ListView.builder(
                    key: PageStorageKey(conversation.id),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      final character = message.characterId == null
                          ? null
                          : widget.characters[message.characterId!];
                      return MessageBubble(
                        message: message,
                        character: character,
                        traveler: widget.traveler,
                        showAuthor: isGroup && !message.isUser,
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.76),
                          border: const Border(
                            top: BorderSide(color: _wechatLine, width: 0.5),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: null,
                              icon: Icon(
                                Icons.keyboard_voice_outlined,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 5,
                                  textInputAction: TextInputAction.send,
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (_) => _send(),
                                  decoration: const InputDecoration(
                                    hintText: '输入消息',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 9,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: _controller.text.trim().isEmpty
                                  ? IconButton(
                                      key: const ValueKey('more'),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: null,
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        color: Colors.grey.shade600,
                                      ),
                                    )
                                  : FilledButton(
                                      key: const ValueKey('send'),
                                      onPressed: _send,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _wechatGreen,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(58, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text('发送'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.character,
    this.imageUrl,
    this.label,
    this.size = 52,
    this.isGroup = false,
  });

  final Character? character;
  final String? imageUrl;
  final String? label;
  final double size;
  final bool isGroup;

  Widget _fallback() {
    if (isGroup) {
      return const Center(
        child: Icon(Icons.groups_rounded, color: Colors.white),
      );
    }
    return Center(
      child: Text(
        (label ?? character?.name ?? '旅').characters.first,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? character?.avatarUrl ?? '';
    final radius = BorderRadius.circular(isGroup ? 12 : 8);
    final background = isGroup ? _gold : const Color(0xFFF2F2F2);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: background, borderRadius: radius),
      child: url.isEmpty
          ? _fallback()
          : url.startsWith('asset://')
          ? Image.asset(
              url.substring('asset://'.length),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _AvatarImage(url: url, fallback: _fallback()),
    );
  }
}

class _AvatarImage extends StatefulWidget {
  const _AvatarImage({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  State<_AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<_AvatarImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await AvatarCache.instance.load(widget.url);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null || _bytes!.isEmpty) {
      return widget.fallback;
    }
    return Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true);
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.character,
    required this.traveler,
    required this.showAuthor,
  });

  final ChatMessage message;
  final Character? character;
  final TravelerProfile traveler;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final avatar = isUser
        ? Avatar(imageUrl: traveler.avatarUrl, label: traveler.name, size: 42)
        : Avatar(character: character, label: message.authorName, size: 42);
    final bubbleColor = isUser ? const Color(0xFF95EC69) : Colors.white;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.circular(5);
    final maxWidth = MediaQuery.of(context).size.width * 0.68;

    return TweenAnimationBuilder<double>(
      key: ValueKey(
        '${message.createdAt.microsecondsSinceEpoch}-${message.sender}',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(isUser ? (1 - value) * 10 : -(1 - value) * 10, 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isUser) avatar,
            if (!isUser) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: align,
                children: [
                  if (showAuthor && (message.authorName ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 2,
                        right: 2,
                        bottom: 3,
                      ),
                      child: Text(
                        message.authorName!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 12,
                        left: isUser ? null : -4,
                        right: isUser ? -4 : null,
                        child: CustomPaint(
                          size: const Size(7, 10),
                          painter: _BubbleTailPainter(
                            color: bubbleColor,
                            right: isUser,
                          ),
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: radius,
                          border: isUser
                              ? null
                              : Border.all(
                                  color: const Color(0xFFE7E7E7),
                                  width: 0.5,
                                ),
                        ),
                        child: Text(
                          message.content,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.42,
                            color: _wechatText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isUser) const SizedBox(width: 8),
            if (isUser) avatar,
          ],
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.color, required this.right});

  final Color color;
  final bool right;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (right) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.right != right;
  }
}

class GroupMembersBar extends StatelessWidget {
  const GroupMembersBar({
    super.key,
    required this.memberIds,
    required this.characters,
  });

  final List<String> memberIds;
  final Map<String, Character> characters;

  @override
  Widget build(BuildContext context) {
    final members = memberIds
        .map((id) => characters[id])
        .whereType<Character>()
        .toList();
    return Container(
      height: 86,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final character = members[index];
          return SizedBox(
            width: 62,
            child: Column(
              children: [
                Avatar(character: character, size: 42),
                const SizedBox(height: 4),
                Text(
                  character.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: members.length,
      ),
    );
  }
}

class CreateGroupResult {
  const CreateGroupResult({required this.title, required this.memberIds});

  final String title;
  final List<String> memberIds;
}

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({
    super.key,
    required this.characters,
    this.initialTitle = '',
    this.initialMemberIds = const [],
    required this.actionLabel,
  });

  final List<Character> characters;
  final String initialTitle;
  final List<String> initialMemberIds;
  final String actionLabel;

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _searchController;
  late Set<String> _selectedIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialTitle);
    _searchController = TextEditingController();
    _selectedIds = widget.initialMemberIds.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.characters.where((character) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim();
      return character.name.contains(q) ||
          character.vision.contains(q) ||
          character.nation.contains(q);
    }).toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: min(MediaQuery.of(context).size.height * 0.82, 720.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.actionLabel,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '群聊名称',
                  hintText: '选填，不填则自动生成',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '搜索角色名字、元素或地区',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _SelectedMembersStrip(
                characters: widget.characters,
                selectedIds: _selectedIds,
                onRemove: _toggle,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final character = filtered[index];
                    final selected = _selectedIds.contains(character.id);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: _jade,
                      contentPadding: EdgeInsets.zero,
                      secondary: Avatar(character: character, size: 42),
                      title: Text(character.name),
                      subtitle: Text(
                        '${character.vision} / ${character.nation.isEmpty ? '未知地区' : character.nation}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (_) => _toggle(character.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _jade),
                  onPressed: _selectedIds.isEmpty ? null : _submit,
                  child: Text(widget.actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _submit() {
    final selectedCharacters = widget.characters
        .where((character) => _selectedIds.contains(character.id))
        .toList();
    final title = _nameController.text.trim().isEmpty
        ? selectedCharacters.take(3).map((c) => c.name).join('、')
        : _nameController.text.trim();
    Navigator.of(context).pop(
      CreateGroupResult(
        title: title.isEmpty ? '新群聊' : title,
        memberIds: selectedCharacters.map((c) => c.id).toList(),
      ),
    );
  }
}

class _SelectedMembersStrip extends StatelessWidget {
  const _SelectedMembersStrip({
    required this.characters,
    required this.selectedIds,
    required this.onRemove,
  });

  final List<Character> characters;
  final Set<String> selectedIds;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (selectedIds.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '已选角色会显示在这里',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final selectedCharacters = characters
        .where((c) => selectedIds.contains(c.id))
        .toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final character in selectedCharacters)
          InputChip(
            avatar: Avatar(character: character, size: 28),
            label: Text(character.name),
            onDeleted: () => onRemove(character.id),
          ),
      ],
    );
  }
}

class ContactActionSheet extends StatelessWidget {
  const ContactActionSheet({
    super.key,
    required this.character,
    required this.onMessage,
    required this.onAddToGroup,
  });

  final Character character;
  final VoidCallback onMessage;
  final VoidCallback onAddToGroup;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Avatar(character: character, size: 82)),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  character.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  character.shortInfo,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '角色资料',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      character.publicInfo,
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onMessage,
                  style: FilledButton.styleFrom(
                    backgroundColor: _jade,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('发消息'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: onAddToGroup,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('加入群聊'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupPickerSheet extends StatelessWidget {
  const GroupPickerSheet({
    super.key,
    required this.groups,
    required this.character,
  });

  final List<ConversationState> groups;
  final Character character;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '把${character.name}加入群聊',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _jade,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group_add, color: Colors.white),
              ),
              title: const Text('创建新群聊'),
              onTap: () => Navigator.of(context).pop('__new__'),
            ),
            ...groups.map(
              (group) => ListTile(
                leading: const Avatar(isGroup: true, size: 42, label: '群'),
                title: Text(group.title),
                subtitle: Text('${group.memberIds.length} 位成员'),
                onTap: () => Navigator.of(context).pop(group.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeSection extends StatelessWidget {
  const _MeSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _MeTile extends StatelessWidget {
  const _MeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4A4A4A)),
      title: Text(title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _MeSwitchTile extends StatelessWidget {
  const _MeSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: const Color(0xFF4A4A4A)),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      activeThumbColor: _jade,
      onChanged: onChanged,
    );
  }
}

class _SettingsFormCard extends StatelessWidget {
  const _SettingsFormCard({
    required this.apiKey,
    required this.apiFormat,
    required this.onApiFormatChanged,
    required this.baseUrl,
    required this.model,
    required this.testingApi,
    required this.onTestApi,
    required this.searchEnabled,
    required this.onSearchChanged,
  });

  final TextEditingController apiKey;
  final String apiFormat;
  final ValueChanged<String> onApiFormatChanged;
  final TextEditingController baseUrl;
  final TextEditingController model;
  final bool testingApi;
  final Future<void> Function() onTestApi;
  final bool searchEnabled;
  final ValueChanged<bool> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        children: [
          _settingsField('LLM API Key', apiKey, obscure: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: apiFormat,
              decoration: InputDecoration(
                labelText: 'API 格式',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'openai', child: Text('OpenAI 兼容格式')),
                DropdownMenuItem(
                  value: 'anthropic',
                  child: Text('Anthropic 格式'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onApiFormatChanged(value);
                }
              },
            ),
          ),
          _settingsField('接口地址', baseUrl),
          _settingsField('模型名称', model),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: testingApi ? null : onTestApi,
                icon: testingApi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(testingApi ? '正在测试 API...' : '一键测试 API'),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: searchEnabled,
            activeThumbColor: _jade,
            title: const Text('联网搜索'),
            subtitle: const Text('开启后，角色会在需要时联网补充版本、活动等最新信息。'),
            onChanged: onSearchChanged,
          ),
        ],
      ),
    );
  }

  Widget _settingsField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _apiKey;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late String _apiFormat;
  late bool _searchEnabled;
  bool _testingApi = false;

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController(text: widget.settings.apiKey);
    _baseUrl = TextEditingController(text: widget.settings.baseUrl);
    _model = TextEditingController(text: widget.settings.model);
    _apiFormat = widget.settings.apiFormat;
    _searchEnabled = widget.settings.searchEnabled;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  void _changeApiFormat(String value) {
    setState(() {
      final oldFormat = _apiFormat;
      _apiFormat = value;
      if (oldFormat != value) {
        if (value == 'anthropic') {
          if (_baseUrl.text.trim().isEmpty ||
              _baseUrl.text.contains('openai.com')) {
            _baseUrl.text = 'https://api.anthropic.com/v1/messages';
          }
          if (_model.text.trim().isEmpty || _model.text.startsWith('gpt-')) {
            _model.text = 'claude-3-5-sonnet-latest';
          }
        } else {
          if (_baseUrl.text.trim().isEmpty ||
              _baseUrl.text.contains('anthropic.com')) {
            _baseUrl.text = 'https://api.openai.com/v1/chat/completions';
          }
          if (_model.text.trim().isEmpty || _model.text.startsWith('claude-')) {
            _model.text = 'gpt-4.1-mini';
          }
        }
      }
    });
  }

  AppSettings _currentSettings() {
    return widget.settings.copyWith(
      apiKey: _apiKey.text.trim(),
      apiFormat: _apiFormat,
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
      searchEnabled: _searchEnabled,
    );
  }

  Future<void> _testApi() async {
    if (_apiKey.text.trim().isEmpty) {
      await _showApiTestDialog(
        context,
        success: false,
        message: '请先填写 API Key。',
      );
      return;
    }
    setState(() => _testingApi = true);
    try {
      await LlmClient(HttpTextClient()).testConnection(_currentSettings());
      if (!mounted) return;
      await _showApiTestDialog(
        context,
        success: true,
        message: '连接成功，当前接口地址、API Key 和模型均可正常调用。',
      );
    } catch (error) {
      if (!mounted) return;
      await _showApiTestDialog(
        context,
        success: false,
        message: _friendlyLocalError(error),
      );
    } finally {
      if (mounted) setState(() => _testingApi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'API 设置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _SettingsFormCard(
                apiKey: _apiKey,
                apiFormat: _apiFormat,
                onApiFormatChanged: _changeApiFormat,
                baseUrl: _baseUrl,
                model: _model,
                testingApi: _testingApi,
                onTestApi: _testApi,
                searchEnabled: _searchEnabled,
                onSearchChanged: (value) =>
                    setState(() => _searchEnabled = value),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _jade),
                  onPressed: () {
                    Navigator.of(context).pop(_currentSettings());
                  },
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatListTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(time.year, time.month, time.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  if (diff == 1) return '昨天';
  if (diff < 7) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${weekdays[max(0, time.weekday - 1)]}';
  }
  return '${time.month}/${time.day}';
}
