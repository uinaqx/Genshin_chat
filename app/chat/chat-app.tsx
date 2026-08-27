"use client";

import {
  ArrowLeft,
  Check,
  ChevronRight,
  ContactRound,
  ExternalLink,
  Github,
  LogOut,
  MessageCircleMore,
  MoreHorizontal,
  Plus,
  RefreshCw,
  Search,
  Send,
  ShieldCheck,
  Sparkles,
  Trash2,
  UserRound,
  UsersRound,
  X,
} from "lucide-react";
import Image from "next/image";
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";

type Character = {
  id: string;
  name: string;
  title?: string;
  vision?: string;
  nation?: string;
  description?: string;
  avatarUrl?: string;
};

type Message = {
  id: string;
  role: "user" | "assistant";
  characterId: string | null;
  authorName: string | null;
  content: string;
  createdAt: string;
};

type Conversation = {
  id: string;
  title: string;
  type: "single" | "group";
  memberIds: string[];
  createdAt: string;
  updatedAt: string;
  messages: Message[];
};

type Tab = "chats" | "contacts" | "profile";
type TravelerGender = "aether" | "lumine";

const TRAVELERS = {
  aether: {
    name: "空",
    label: "男旅行者",
    avatarUrl: "https://gi.yatta.moe/assets/UI/UI_AvatarIcon_PlayerBoy.png",
  },
  lumine: {
    name: "荧",
    label: "女旅行者",
    avatarUrl: "https://gi.yatta.moe/assets/UI/UI_AvatarIcon_PlayerGirl.png",
  },
} as const;

export function ChatApp({
  user,
}: {
  user: { displayName: string; travelerGender: TravelerGender };
}) {
  const [characters, setCharacters] = useState<Character[]>([]);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [activeTab, setActiveTab] = useState<Tab>("chats");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [draft, setDraft] = useState("");
  const [processingIds, setProcessingIds] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [showGroupModal, setShowGroupModal] = useState(false);
  const [showConversationMenu, setShowConversationMenu] = useState(false);
  const [travelerGender, setTravelerGender] = useState<TravelerGender>(
    user.travelerGender,
  );
  const messagesRef = useRef<HTMLDivElement>(null);
  const processingRef = useRef(new Set<string>());
  const pendingReplyIdsRef = useRef(new Map<string, string[]>());
  const saveChainsRef = useRef(new Map<string, Promise<void>>());
  const retryCountsRef = useRef(new Map<string, number>());

  const characterMap = useMemo(
    () => new Map(characters.map((character) => [character.id, character])),
    [characters],
  );
  const selectedConversation =
    conversations.find((conversation) => conversation.id === selectedId) ?? null;

  useEffect(() => {
    void loadWorkspace();
    // Initial hydration runs once; later refreshes are triggered explicitly.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useLayoutEffect(() => {
    const element = messagesRef.current;
    if (element) {
      element.scrollTop = element.scrollHeight;
    }
  }, [selectedId, selectedConversation?.messages.length]);

  async function loadWorkspace(preferredId?: string) {
    try {
      const [characterResponse, conversationResponse] = await Promise.all([
        fetch("/api/characters"),
        fetch("/api/conversations"),
      ]);
      const characterPayload = (await characterResponse.json()) as {
        characters?: Character[];
        error?: string;
      };
      const conversationPayload = (await conversationResponse.json()) as {
        conversations?: Conversation[];
        error?: string;
      };
      if (!characterResponse.ok || !conversationResponse.ok) {
        throw new Error(
          characterPayload.error || conversationPayload.error || "加载失败",
        );
      }
      setCharacters(characterPayload.characters ?? []);
      setConversations(conversationPayload.conversations ?? []);
      if (preferredId) setSelectedId(preferredId);
      void resumePendingReplies();
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "加载失败");
    } finally {
      setLoading(false);
    }
  }

  async function openCharacter(character: Character) {
    setError("");
    const existing = conversations.find(
      (conversation) =>
        conversation.type === "single" &&
        conversation.memberIds[0] === character.id,
    );
    if (existing) {
      setSelectedId(existing.id);
      setActiveTab("chats");
      return;
    }
    const response = await fetch("/api/conversations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type: "single", memberIds: [character.id] }),
    });
    const payload = (await response.json()) as {
      id?: string;
      conversation?: Conversation;
      error?: string;
    };
    if (!response.ok) {
      setError(payload.error || "无法发起聊天");
      return;
    }
    if (!payload.id || !payload.conversation) return;
    setConversations((current) => [payload.conversation!, ...current]);
    setSelectedId(payload.id);
    setActiveTab("chats");
  }

  function sendMessage() {
    const content = draft.trim();
    const conversation = selectedConversation;
    if (!content || !conversation) return;
    setDraft("");
    setError("");
    const tempId = `temp-${crypto.randomUUID()}`;
    const optimistic: Message = {
      id: tempId,
      role: "user",
      characterId: null,
      authorName: "旅行者",
      content,
      createdAt: new Date().toISOString(),
    };
    appendMessages(conversation.id, [optimistic]);
    const previousSave = saveChainsRef.current.get(conversation.id) ??
      Promise.resolve();
    const saveTask = previousSave.catch(() => undefined).then(async () => {
      const response = await fetch("/api/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ conversationId: conversation.id, content }),
      });
      const payload = (await response.json()) as {
        message?: Message;
        error?: string;
      };
      if (!response.ok) throw new Error(payload.error || "消息发送失败");
      if (!payload.message) throw new Error("消息保存失败");
      replaceMessage(conversation.id, tempId, payload.message);
      enqueueReply(conversation.id, [payload.message.id]);
    });
    saveChainsRef.current.set(conversation.id, saveTask);
    void saveTask
      .catch((sendError) => {
        removeMessage(conversation.id, tempId);
        setDraft((current) => current || content);
        setError(
          sendError instanceof Error ? sendError.message : "消息发送失败",
        );
      })
      .finally(() => {
        if (saveChainsRef.current.get(conversation.id) === saveTask) {
          saveChainsRef.current.delete(conversation.id);
        }
      });
  }

  async function resumePendingReplies() {
    try {
      const response = await fetch("/api/messages");
      if (!response.ok) return;
      const payload = (await response.json()) as {
        pending?: Array<{ conversationId: string; messageIds: string[] }>;
      };
      for (const pending of payload.pending ?? []) {
        enqueueReply(pending.conversationId, pending.messageIds);
      }
    } catch {
      // The next successfully saved message will retry any durable pending work.
    }
  }

  function enqueueReply(conversationId: string, messageIds: string[]) {
    const queued = pendingReplyIdsRef.current.get(conversationId) ?? [];
    const next = Array.from(new Set([...queued, ...messageIds]));
    pendingReplyIdsRef.current.set(conversationId, next);
    void processReplyQueue(conversationId);
  }

  async function processReplyQueue(conversationId: string) {
    if (processingRef.current.has(conversationId)) return;
    processingRef.current.add(conversationId);
    setProcessingIds((current) => new Set(current).add(conversationId));

    try {
      while (true) {
        const queued = pendingReplyIdsRef.current.get(conversationId) ?? [];
        if (queued.length === 0) break;
        const batch = queued.splice(0, 30);
        pendingReplyIdsRef.current.set(conversationId, queued);

        const response = await fetch("/api/chat", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ conversationId, messageIds: batch }),
        });
        const payload = (await response.json()) as {
          busy?: boolean;
          retryAfterMs?: number;
          replies?: Message[];
          error?: string;
        };
        if (response.status === 202 && payload.busy) {
          pendingReplyIdsRef.current.set(conversationId, [
            ...batch,
            ...(pendingReplyIdsRef.current.get(conversationId) ?? []),
          ]);
          await wait(payload.retryAfterMs ?? 900);
          continue;
        }
        if (!response.ok) {
          pendingReplyIdsRef.current.set(conversationId, [
            ...batch,
            ...(pendingReplyIdsRef.current.get(conversationId) ?? []),
          ]);
          throw new Error(payload.error || "回复暂时失败");
        }
        retryCountsRef.current.delete(conversationId);
        for (const reply of payload.replies ?? []) {
          await wait(420);
          appendMessages(conversationId, [reply]);
        }
      }
    } catch (replyError) {
      const retryCount = (retryCountsRef.current.get(conversationId) ?? 0) + 1;
      retryCountsRef.current.set(conversationId, retryCount);
      const reason = (
        replyError instanceof Error ? replyError.message : "回复暂时失败"
      ).replace(/[。！!，,\s]+$/, "");
      setError(
        `${reason}，消息已保存，稍后发送或重新打开页面时会自动续上。`,
      );
    } finally {
      processingRef.current.delete(conversationId);
      setProcessingIds((current) => {
        const next = new Set(current);
        next.delete(conversationId);
        return next;
      });
      if (
        (pendingReplyIdsRef.current.get(conversationId)?.length ?? 0) > 0 &&
        (retryCountsRef.current.get(conversationId) ?? 0) <= 1
      ) {
        window.setTimeout(() => void processReplyQueue(conversationId), 2500);
      }
    }
  }

  async function deleteConversation() {
    if (!selectedConversation) return;
    const response = await fetch(
      `/api/conversations/${encodeURIComponent(selectedConversation.id)}`,
      { method: "DELETE" },
    );
    if (!response.ok) {
      setError("暂时无法删除这个对话");
      return;
    }
    setConversations((current) =>
      current.filter((item) => item.id !== selectedConversation.id),
    );
    setSelectedId(null);
    setShowConversationMenu(false);
  }

  async function updateTravelerGender(nextGender: TravelerGender) {
    if (nextGender === travelerGender) return;
    const previousGender = travelerGender;
    setTravelerGender(nextGender);
    const response = await fetch("/api/profile", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ travelerGender: nextGender }),
    });
    const payload = (await response.json()) as { error?: string };
    if (!response.ok) {
      setTravelerGender(previousGender);
      throw new Error(payload.error || "旅行者头像保存失败");
    }
  }

  function appendMessages(conversationId: string, messages: Message[]) {
    setConversations((current) =>
      current.map((conversation) =>
        conversation.id === conversationId
          ? {
              ...conversation,
              messages: [...conversation.messages, ...messages],
              updatedAt: new Date().toISOString(),
            }
          : conversation,
      ),
    );
  }

  function replaceMessage(
    conversationId: string,
    messageId: string,
    message: Message,
  ) {
    setConversations((current) =>
      current.map((conversation) =>
        conversation.id === conversationId
          ? {
              ...conversation,
              messages: conversation.messages.map((item) =>
                item.id === messageId ? message : item,
              ),
            }
          : conversation,
      ),
    );
  }

  function removeMessage(conversationId: string, messageId: string) {
    setConversations((current) =>
      current.map((conversation) =>
        conversation.id === conversationId
          ? {
              ...conversation,
              messages: conversation.messages.filter(
                (message) => message.id !== messageId,
              ),
            }
          : conversation,
      ),
    );
  }

  const filteredConversations = conversations.filter((conversation) =>
    `${conversation.title} ${conversation.messages.at(-1)?.content ?? ""}`
      .toLowerCase()
      .includes(search.toLowerCase()),
  );
  const filteredCharacters = characters.filter((character) =>
    `${character.name} ${character.nation ?? ""} ${character.title ?? ""}`
      .toLowerCase()
      .includes(search.toLowerCase()),
  );

  return (
    <main className="app-stage">
      <div className={`messenger-shell ${selectedConversation ? "has-chat" : ""}`}>
        <aside className="sidebar">
          <header className="sidebar-header">
            <div>
              <p className="section-kicker">提瓦特微信</p>
              <h1>{tabTitle(activeTab)}</h1>
            </div>
            {activeTab === "chats" && (
              <button
                className="icon-button"
                type="button"
                aria-label="新建群聊"
                title="新建群聊"
                onClick={() => setShowGroupModal(true)}
              >
                <Plus size={20} />
              </button>
            )}
          </header>
          {activeTab !== "profile" && (
            <label className="search-box">
              <Search size={17} aria-hidden="true" />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder={activeTab === "chats" ? "搜索聊天" : "搜索角色"}
                aria-label={activeTab === "chats" ? "搜索聊天" : "搜索角色"}
              />
              {search && (
                <button
                  type="button"
                  aria-label="清空搜索"
                  onClick={() => setSearch("")}
                >
                  <X size={15} />
                </button>
              )}
            </label>
          )}
          <div className="sidebar-content">
            {loading ? (
              <LoadingRows />
            ) : activeTab === "chats" ? (
              <ConversationList
                conversations={filteredConversations}
                characterMap={characterMap}
                selectedId={selectedId}
                onSelect={setSelectedId}
              />
            ) : activeTab === "contacts" ? (
              <ContactList
                characters={filteredCharacters}
                onSelect={openCharacter}
              />
            ) : (
              <ProfilePanel
                user={{ displayName: "旅行者", travelerGender }}
                conversations={conversations}
                onTravelerChange={updateTravelerGender}
              />
            )}
          </div>
          <nav className="tab-bar" aria-label="主导航">
            <TabButton
              active={activeTab === "chats"}
              label="聊天"
              icon={<MessageCircleMore size={21} />}
              onClick={() => setActiveTab("chats")}
            />
            <TabButton
              active={activeTab === "contacts"}
              label="通讯录"
              icon={<ContactRound size={21} />}
              onClick={() => setActiveTab("contacts")}
            />
            <TabButton
              active={activeTab === "profile"}
              label="我的"
              icon={<UserRound size={21} />}
              onClick={() => setActiveTab("profile")}
            />
          </nav>
        </aside>

        <section className="content-pane">
          {selectedConversation ? (
            <div className="chat-view">
              <header className="chat-header">
                <button
                  className="icon-button mobile-back"
                  type="button"
                  aria-label="返回"
                  onClick={() => setSelectedId(null)}
                >
                  <ArrowLeft size={21} />
                </button>
                <ConversationAvatar
                  conversation={selectedConversation}
                  characterMap={characterMap}
                  size="small"
                />
                <div className="chat-heading">
                  <h2>
                    {processingIds.has(selectedConversation.id) &&
                    selectedConversation.type === "single"
                      ? "正在输入..."
                      : selectedConversation.title}
                  </h2>
                  {selectedConversation.type === "group" && (
                    <span>{selectedConversation.memberIds.length} 位成员</span>
                  )}
                </div>
                <button
                  className="icon-button header-menu"
                  type="button"
                  aria-label="对话设置"
                  title="对话设置"
                  onClick={() =>
                    setShowConversationMenu((current) => !current)
                  }
                >
                  <MoreHorizontal size={22} />
                </button>
                {showConversationMenu && (
                  <div className="conversation-menu">
                    <button type="button" onClick={deleteConversation}>
                      <Trash2 size={17} />
                      删除对话
                    </button>
                  </div>
                )}
              </header>
              <div className="message-list" ref={messagesRef}>
                {selectedConversation.messages.length === 0 ? (
                  <div className="empty-chat">
                    <ConversationAvatar
                      conversation={selectedConversation}
                      characterMap={characterMap}
                      size="large"
                    />
                    <h3>{selectedConversation.title}</h3>
                    <p>
                      {selectedConversation.type === "group"
                        ? "群里安静着。发句话，看看谁会先接上。"
                        : "从一句自然的招呼开始。"}
                    </p>
                  </div>
                ) : (
                  selectedConversation.messages.map((message) => (
                    <MessageBubble
                      key={message.id}
                      message={message}
                      character={message.characterId ? characterMap.get(message.characterId) : null}
                      userAvatarUrl={TRAVELERS[travelerGender].avatarUrl}
                      showName={selectedConversation.type === "group"}
                    />
                  ))
                )}
              </div>
              <div className="composer-wrap">
                {error && <div className="error-toast">{error}</div>}
                <div className="composer">
                  <textarea
                    value={draft}
                    onChange={(event) => setDraft(event.target.value)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" && !event.shiftKey) {
                        event.preventDefault();
                        void sendMessage();
                      }
                    }}
                    placeholder="输入消息"
                    rows={1}
                    aria-label="输入消息"
                  />
                  <button
                    className="send-button"
                    type="button"
                    aria-label="发送"
                    title="发送"
                    disabled={!draft.trim()}
                    onClick={sendMessage}
                  >
                    <Send size={19} />
                  </button>
                </div>
              </div>
            </div>
          ) : (
            <div className="welcome-pane">
              <div className="welcome-symbol">
                <Sparkles size={31} strokeWidth={1.5} />
              </div>
              <h2>提瓦特，正在发生</h2>
              <p>从左侧选择一个对话，或在通讯录里找到想见的人。</p>
            </div>
          )}
        </section>
      </div>
      {showGroupModal && (
        <GroupModal
          characters={characters}
          onClose={() => setShowGroupModal(false)}
          onCreated={async (id) => {
            setShowGroupModal(false);
            await loadWorkspace(id);
            setActiveTab("chats");
          }}
        />
      )}
    </main>
  );
}

function ConversationList({
  conversations,
  characterMap,
  selectedId,
  onSelect,
}: {
  conversations: Conversation[];
  characterMap: Map<string, Character>;
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  if (conversations.length === 0) {
    return <EmptyList text="还没有对话，从通讯录里找个人吧。" />;
  }
  return (
    <div className="conversation-list">
      {conversations.map((conversation) => {
        const lastMessage = conversation.messages.at(-1);
        return (
          <button
            type="button"
            key={conversation.id}
            className={`conversation-row ${
              selectedId === conversation.id ? "active" : ""
            }`}
            onClick={() => onSelect(conversation.id)}
          >
            <ConversationAvatar
              conversation={conversation}
              characterMap={characterMap}
            />
            <span className="row-main">
              <span className="row-title-line">
                <strong>{conversation.title}</strong>
                <time>{formatListTime(conversation.updatedAt)}</time>
              </span>
              <span className="row-preview">
                {lastMessage?.content || "还没有消息"}
              </span>
            </span>
          </button>
        );
      })}
    </div>
  );
}

function ContactList({
  characters,
  onSelect,
}: {
  characters: Character[];
  onSelect: (character: Character) => void;
}) {
  if (characters.length === 0) {
    return <EmptyList text="没有找到匹配的角色。" />;
  }
  return (
    <div className="contact-list">
      {characters.map((character) => (
        <button
          type="button"
          key={character.id}
          className="contact-row"
          onClick={() => void onSelect(character)}
        >
          <Avatar character={character} />
          <span className="row-main">
            <strong>{character.name}</strong>
            <span>
              {character.nation || "提瓦特"} · {character.title || "角色"}
            </span>
          </span>
          <ChevronRight size={18} aria-hidden="true" />
        </button>
      ))}
    </div>
  );
}

function ProfilePanel({
  user,
  conversations,
  onTravelerChange,
}: {
  user: { displayName: string; travelerGender: TravelerGender };
  conversations: Conversation[];
  onTravelerChange: (gender: TravelerGender) => Promise<void>;
}) {
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");
  const traveler = TRAVELERS[user.travelerGender];

  async function toggleTraveler() {
    if (saving) return;
    const nextGender: TravelerGender =
      user.travelerGender === "aether" ? "lumine" : "aether";
    setSaving(true);
    setSaveError("");
    try {
      await onTravelerChange(nextGender);
    } catch (profileError) {
      setSaveError(
        profileError instanceof Error ? profileError.message : "保存失败",
      );
    } finally {
      setSaving(false);
    }
  }

  const nextTraveler =
    user.travelerGender === "aether" ? TRAVELERS.lumine : TRAVELERS.aether;

  return (
    <div className="profile-panel">
      <div className="account-row">
        <span className="user-avatar large traveler-avatar">
          <Image
            src={traveler.avatarUrl}
            alt={`${traveler.name}头像`}
            width={60}
            height={60}
            priority
            unoptimized
          />
        </span>
        <span className="account-copy">
          <strong>{user.displayName}</strong>
          <small>{traveler.name} · {traveler.label}</small>
        </span>
        <button
          className={`traveler-switch-button ${saving ? "is-saving" : ""}`}
          type="button"
          disabled={saving}
          aria-label={`切换为${nextTraveler.name}`}
          title={`切换为${nextTraveler.name} · ${nextTraveler.label}`}
          onClick={() => void toggleTraveler()}
        >
          <RefreshCw size={17} aria-hidden="true" />
        </button>
      </div>
      {saveError && <p className="profile-error" role="alert">{saveError}</p>}
      <div className="settings-group">
        <div className="setting-row">
          <ShieldCheck size={20} />
          <span>
            <strong>账号数据隔离</strong>
            <small>聊天记录只属于当前登录账号</small>
          </span>
        </div>
        <div className="setting-row">
          <UsersRound size={20} />
          <span>
            <strong>{conversations.length} 个对话</strong>
            <small>记录已安全保存在云端</small>
          </span>
        </div>
        <a
          className="setting-row setting-action"
          href="https://github.com/uinaqx/Genshin_chat"
          target="_blank"
          rel="noreferrer"
        >
          <Github size={20} />
          <span className="setting-copy">
            <strong>GitHub 开源</strong>
            <small>查看源码、版本记录与发行说明</small>
          </span>
          <ExternalLink className="setting-trailing" size={17} />
        </a>
      </div>
      <a className="signout-link" href="/api/auth/logout">
        <LogOut size={18} />
        退出登录
      </a>
      <p className="version-label">提瓦特微信 Web · 2.2.1</p>
    </div>
  );
}

function MessageBubble({
  message,
  character,
  userAvatarUrl,
  showName,
}: {
  message: Message;
  character?: Character | null;
  userAvatarUrl: string;
  showName: boolean;
}) {
  const isUser = message.role === "user";
  return (
    <div className={`message-row ${isUser ? "user" : "assistant"}`}>
      {!isUser && <Avatar character={character ?? undefined} size="message" />}
      <div className="message-content">
        {!isUser && showName && (
          <span className="message-author">
            {message.authorName || character?.name}
          </span>
        )}
        <div className="bubble">{message.content}</div>
      </div>
      {isUser && (
        <span className="user-avatar message traveler-avatar">
          <Image
            src={userAvatarUrl}
            alt="旅行者头像"
            width={36}
            height={36}
            unoptimized
          />
        </span>
      )}
    </div>
  );
}

function ConversationAvatar({
  conversation,
  characterMap,
  size = "normal",
}: {
  conversation: Conversation;
  characterMap: Map<string, Character>;
  size?: "small" | "normal" | "large";
}) {
  if (conversation.type === "single") {
    return (
      <Avatar
        character={characterMap.get(conversation.memberIds[0])}
        size={size === "large" ? "large" : size === "small" ? "small" : "normal"}
      />
    );
  }
  const members = conversation.memberIds
    .slice(0, 4)
    .map((id) => characterMap.get(id))
    .filter(Boolean) as Character[];
  return (
    <span className={`group-avatar avatar-${size}`}>
      {members.map((member) => (
        member.avatarUrl ? (
          <Image
            key={member.id}
            src={member.avatarUrl}
            alt=""
            width={48}
            height={48}
            unoptimized
          />
        ) : (
          <span key={member.id}>{member.name.slice(0, 1)}</span>
        )
      ))}
    </span>
  );
}

function Avatar({
  character,
  size = "normal",
}: {
  character?: Character;
  size?: "small" | "normal" | "large" | "message";
}) {
  if (character?.avatarUrl) {
    return (
      <Image
        className={`avatar avatar-${size}`}
        src={character.avatarUrl}
        alt={`${character.name}头像`}
        width={72}
        height={72}
        loading="lazy"
        unoptimized
      />
    );
  }
  return (
    <span className={`avatar avatar-${size} avatar-fallback`}>
      {character?.name.slice(0, 1) || "群"}
    </span>
  );
}

function TabButton({
  active,
  label,
  icon,
  onClick,
}: {
  active: boolean;
  label: string;
  icon: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className={active ? "active" : ""}
      onClick={onClick}
    >
      {icon}
      <span>{label}</span>
    </button>
  );
}

function GroupModal({
  characters,
  onClose,
  onCreated,
}: {
  characters: Character[];
  onClose: () => void;
  onCreated: (id: string) => Promise<void>;
}) {
  const [selected, setSelected] = useState<string[]>([]);
  const [name, setName] = useState("");
  const [search, setSearch] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const characterMap = new Map(
    characters.map((character) => [character.id, character]),
  );
  const visibleCharacters = characters.filter((character) =>
    `${character.name}${character.nation ?? ""}`.includes(search),
  );

  async function createGroup() {
    if (selected.length < 2 || saving) return;
    setSaving(true);
    const response = await fetch("/api/conversations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        type: "group",
        title: name.trim(),
        memberIds: selected,
      }),
    });
    const payload = (await response.json()) as {
      id?: string;
      error?: string;
    };
    if (!response.ok) {
      setError(payload.error || "创建失败");
      setSaving(false);
      return;
    }
    if (payload.id) {
      await onCreated(payload.id);
    }
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <section
        className="group-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="group-modal-title"
      >
        <header>
          <button className="icon-button" type="button" onClick={onClose} aria-label="关闭">
            <X size={20} />
          </button>
          <h2 id="group-modal-title">新建群聊</h2>
          <button
            className="text-action"
            type="button"
            disabled={selected.length < 2 || saving}
            onClick={() => void createGroup()}
          >
            创建
          </button>
        </header>
        <input
          className="group-name-input"
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="群聊名称（可选）"
          aria-label="群聊名称"
        />
        <label className="search-box modal-search">
          <Search size={17} />
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="搜索角色"
            aria-label="搜索角色"
          />
        </label>
        {selected.length > 0 && (
          <div className="selected-people">
            {selected.map((id) => {
              const character = characterMap.get(id);
              if (!character) return null;
              return (
                <button
                  type="button"
                  key={id}
                  onClick={() =>
                    setSelected((current) => current.filter((item) => item !== id))
                  }
                >
                  <Avatar character={character} size="small" />
                  <span>{character.name}</span>
                  <X size={13} />
                </button>
              );
            })}
          </div>
        )}
        <div className="modal-contact-list">
          {visibleCharacters.map((character) => {
            const checked = selected.includes(character.id);
            return (
              <button
                type="button"
                key={character.id}
                className="modal-contact-row"
                onClick={() =>
                  setSelected((current) =>
                    checked
                      ? current.filter((id) => id !== character.id)
                      : [...current, character.id].slice(0, 12),
                  )
                }
              >
                <span className={`selection-control ${checked ? "checked" : ""}`}>
                  {checked && <Check size={14} />}
                </span>
                <Avatar character={character} size="small" />
                <span>
                  <strong>{character.name}</strong>
                  <small>{character.nation || "提瓦特"}</small>
                </span>
              </button>
            );
          })}
        </div>
        {error && <p className="modal-error">{error}</p>}
      </section>
    </div>
  );
}

function LoadingRows() {
  return (
    <div className="loading-rows" aria-label="正在加载">
      {[0, 1, 2, 3].map((item) => (
        <div key={item}>
          <span />
          <i />
        </div>
      ))}
    </div>
  );
}

function EmptyList({ text }: { text: string }) {
  return <div className="empty-list">{text}</div>;
}

function tabTitle(tab: Tab) {
  if (tab === "contacts") return "通讯录";
  if (tab === "profile") return "我的";
  return "聊天";
}

function formatListTime(value: string) {
  const date = new Date(value);
  const today = new Date();
  if (date.toDateString() === today.toDateString()) {
    return date.toLocaleTimeString("zh-CN", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
  }
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

function wait(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
