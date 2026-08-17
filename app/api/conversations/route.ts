import { characterById, validCharacterIds } from "../../lib/characters";
import { apiError, ensureSchema, runtimeEnv } from "../../lib/storage";
import { getViewer } from "../../lib/viewer";

export const dynamic = "force-dynamic";

type ConversationRow = {
  id: string;
  title: string;
  type: "single" | "group";
  member_ids: string;
  created_at: string;
  updated_at: string;
};

type MessageRow = {
  id: string;
  conversation_id: string;
  role: "user" | "assistant";
  character_id: string | null;
  author_name: string | null;
  content: string;
  created_at: string;
};

const defaultGroupMembers = [
  "nahida",
  "zhongli",
  "furina",
  "venti",
  "raiden",
  "hu-tao",
];

export async function GET() {
  const viewer = await getViewer();
  if (!viewer) {
    return Response.json({ error: "请先登录" }, { status: 401 });
  }
  try {
    await ensureSchema();
    await ensureDefaultGroup(viewer.email);
    const { DB } = runtimeEnv();
    const conversations = await DB.prepare(
      `SELECT id, title, type, member_ids, created_at, updated_at
       FROM conversations WHERE owner_id = ?
       ORDER BY updated_at DESC`,
    )
      .bind(viewer.email)
      .all<ConversationRow>();
    const messageRows = await DB.prepare(
      `SELECT id, conversation_id, role, character_id, author_name, content, created_at
       FROM messages WHERE owner_id = ?
       ORDER BY created_at ASC`,
    )
      .bind(viewer.email)
      .all<MessageRow>();
    const messagesByConversation = new Map<string, MessageRow[]>();
    for (const message of messageRows.results) {
      const list = messagesByConversation.get(message.conversation_id) ?? [];
      list.push(message);
      messagesByConversation.set(message.conversation_id, list.slice(-80));
    }
    return Response.json({
      conversations: conversations.results.map((conversation) => ({
        id: conversation.id,
        title: conversation.title,
        type: conversation.type,
        memberIds: JSON.parse(conversation.member_ids),
        createdAt: conversation.created_at,
        updatedAt: conversation.updated_at,
        messages: (messagesByConversation.get(conversation.id) ?? []).map(
          (message) => ({
            id: message.id,
            role: message.role,
            characterId: message.character_id,
            authorName: message.author_name,
            content: message.content,
            createdAt: message.created_at,
          }),
        ),
      })),
    });
  } catch (error) {
    return apiError(error);
  }
}

export async function POST(request: Request) {
  const viewer = await getViewer();
  if (!viewer) {
    return Response.json({ error: "请先登录" }, { status: 401 });
  }
  try {
    const payload = (await request.json()) as {
      type?: "single" | "group";
      title?: string;
      memberIds?: string[];
    };
    const type = payload.type === "group" ? "group" : "single";
    const memberIds = validCharacterIds(payload.memberIds ?? []).slice(
      0,
      type === "group" ? 12 : 1,
    );
    if (memberIds.length < (type === "group" ? 2 : 1)) {
      return Response.json({ error: "请选择角色" }, { status: 400 });
    }
    await ensureSchema();
    const { DB } = runtimeEnv();
    if (type === "single") {
      const existing = await DB.prepare(
        `SELECT id, title, type, member_ids, created_at, updated_at FROM conversations
         WHERE owner_id = ? AND type = 'single' AND member_ids = ?
         LIMIT 1`,
      )
        .bind(viewer.email, JSON.stringify(memberIds))
        .first<ConversationRow>();
      if (existing) {
        const conversation = await loadConversation(
          viewer.email,
          existing,
        );
        return Response.json({ id: existing.id, conversation });
      }
    }
    const id = crypto.randomUUID();
    const now = new Date().toISOString();
    const fallbackTitle =
      type === "single"
        ? characterById(memberIds[0])?.name ?? "新对话"
        : memberIds
            .slice(0, 3)
            .map((id) => characterById(id)?.name)
            .filter(Boolean)
            .join("、");
    const title = (payload.title?.trim() || fallbackTitle || "新群聊").slice(
      0,
      30,
    );
    await DB.prepare(
      `INSERT INTO conversations
       (id, owner_id, title, type, member_ids, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        id,
        viewer.email,
        title,
        type,
        JSON.stringify(memberIds),
        now,
        now,
      )
      .run();
    return Response.json(
      {
        id,
        conversation: {
          id,
          title,
          type,
          memberIds,
          createdAt: now,
          updatedAt: now,
          messages: [],
        },
      },
      { status: 201 },
    );
  } catch (error) {
    return apiError(error);
  }
}

async function loadConversation(ownerId: string, conversation: ConversationRow) {
  const { DB } = runtimeEnv();
  const messages = await DB.prepare(
    `SELECT id, conversation_id, role, character_id, author_name, content, created_at
     FROM messages
     WHERE owner_id = ? AND conversation_id = ?
     ORDER BY created_at DESC LIMIT 80`,
  )
    .bind(ownerId, conversation.id)
    .all<MessageRow>();
  return {
    id: conversation.id,
    title: conversation.title,
    type: conversation.type,
    memberIds: JSON.parse(conversation.member_ids),
    createdAt: conversation.created_at,
    updatedAt: conversation.updated_at,
    messages: messages.results.reverse().map((message) => ({
      id: message.id,
      role: message.role,
      characterId: message.character_id,
      authorName: message.author_name,
      content: message.content,
      createdAt: message.created_at,
    })),
  };
}

async function ensureDefaultGroup(ownerId: string) {
  const { DB } = runtimeEnv();
  const existing = await DB.prepare(
    "SELECT id FROM conversations WHERE owner_id = ? LIMIT 1",
  )
    .bind(ownerId)
    .first();
  if (existing) return;
  const now = new Date().toISOString();
  await DB.prepare(
    `INSERT INTO conversations
     (id, owner_id, title, type, member_ids, created_at, updated_at)
     VALUES (?, ?, ?, 'group', ?, ?, ?)`,
  )
    .bind(
      crypto.randomUUID(),
      ownerId,
      "提瓦特群聊",
      JSON.stringify(defaultGroupMembers),
      now,
      now,
    )
    .run();
}
