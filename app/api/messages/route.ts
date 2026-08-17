import { apiError, ensureSchema, runtimeEnv } from "../../lib/storage";
import { getViewer } from "../../lib/viewer";

export const dynamic = "force-dynamic";

type PendingRow = {
  message_id: string;
  conversation_id: string;
};

export async function GET() {
  const viewer = await getViewer();
  if (!viewer) {
    return Response.json({ error: "请先登录" }, { status: 401 });
  }
  try {
    await ensureSchema();
    const { DB } = runtimeEnv();
    const pending = await DB.prepare(
      `SELECT message_id, conversation_id
       FROM reply_queue
       WHERE owner_id = ?
       ORDER BY created_at ASC`,
    )
      .bind(viewer.email)
      .all<PendingRow>();
    const byConversation = new Map<string, string[]>();
    for (const row of pending.results) {
      const ids = byConversation.get(row.conversation_id) ?? [];
      ids.push(row.message_id);
      byConversation.set(row.conversation_id, ids);
    }
    return Response.json({
      pending: [...byConversation].map(([conversationId, messageIds]) => ({
        conversationId,
        messageIds,
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
      conversationId?: string;
      content?: string;
    };
    const conversationId = payload.conversationId?.trim() ?? "";
    const content = payload.content?.trim() ?? "";
    if (!conversationId || !content || content.length > 1000) {
      return Response.json({ error: "消息内容不正确" }, { status: 400 });
    }

    await ensureSchema();
    const { DB } = runtimeEnv();
    const conversation = await DB.prepare(
      "SELECT id FROM conversations WHERE id = ? AND owner_id = ?",
    )
      .bind(conversationId, viewer.email)
      .first<{ id: string }>();
    if (!conversation) {
      return Response.json({ error: "对话不存在" }, { status: 404 });
    }

    const now = new Date().toISOString();
    const message = {
      id: crypto.randomUUID(),
      role: "user" as const,
      characterId: null,
      authorName: "旅行者",
      content,
      createdAt: now,
    };
    await DB.batch([
      DB.prepare(
        `INSERT INTO messages
         (id, conversation_id, owner_id, role, character_id, author_name, content, created_at)
         VALUES (?, ?, ?, 'user', NULL, '旅行者', ?, ?)`,
      ).bind(message.id, conversationId, viewer.email, content, now),
      DB.prepare(
        `INSERT INTO reply_queue(message_id, conversation_id, owner_id, created_at)
         VALUES (?, ?, ?, ?)`,
      ).bind(message.id, conversationId, viewer.email, now),
      DB.prepare(
        "UPDATE conversations SET updated_at = ? WHERE id = ? AND owner_id = ?",
      ).bind(now, conversationId, viewer.email),
    ]);
    return Response.json({ message }, { status: 201 });
  } catch (error) {
    return apiError(error);
  }
}
