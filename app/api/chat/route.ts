import { characterById } from "../../lib/characters";
import {
  buildGroupCharacterSystemPrompt,
  buildSingleCharacterSystemPrompt,
} from "../../lib/character-context";
import { splitReplyIntoBubbles } from "../../lib/reply-bubbles";
import { apiError, ensureSchema, runtimeEnv } from "../../lib/storage";
import { getViewer } from "../../lib/viewer";

export const dynamic = "force-dynamic";

type ConversationRow = {
  id: string;
  title: string;
  type: "single" | "group";
  member_ids: string;
};

type PendingRow = {
  message_id: string;
  created_at: string;
};

type HistoryRow = {
  id: string;
  role: "user" | "assistant";
  character_id: string | null;
  author_name: string | null;
  content: string;
  is_pending: number;
};

type Reply = {
  characterId: string;
  authorName: string;
  content: string;
};

export async function POST(request: Request) {
  const viewer = await getViewer();
  if (!viewer) {
    return Response.json({ error: "请先登录" }, { status: 401 });
  }

  let lockToken: string | null = null;
  let conversationId = "";
  try {
    const payload = (await request.json()) as {
      conversationId?: string;
      messageIds?: string[];
    };
    conversationId = payload.conversationId?.trim() ?? "";
    const messageIds = Array.from(
      new Set(
        (payload.messageIds ?? []).filter(
          (id): id is string => typeof id === "string" && id.length > 0,
        ),
      ),
    ).slice(0, 30);
    if (!conversationId || messageIds.length === 0) {
      return Response.json({ error: "待回复消息不正确" }, { status: 400 });
    }

    await ensureSchema();
    const { DB } = runtimeEnv();
    const conversation = await DB.prepare(
      `SELECT id, title, type, member_ids
       FROM conversations WHERE id = ? AND owner_id = ?`,
    )
      .bind(conversationId, viewer.email)
      .first<ConversationRow>();
    if (!conversation) {
      return Response.json({ error: "对话不存在" }, { status: 404 });
    }

    lockToken = await claimReplyJob(viewer.email, conversationId);
    if (!lockToken) {
      return Response.json(
        { busy: true, retryAfterMs: 900 },
        { status: 202 },
      );
    }

    const placeholders = messageIds.map(() => "?").join(", ");
    const pending = await DB.prepare(
      `SELECT q.message_id, q.created_at
       FROM reply_queue q
       WHERE q.owner_id = ? AND q.conversation_id = ?
         AND q.message_id IN (${placeholders})
       ORDER BY q.created_at ASC`,
    )
      .bind(viewer.email, conversationId, ...messageIds)
      .all<PendingRow>();
    if (pending.results.length === 0) {
      return Response.json({ replies: [], processedMessageIds: [] });
    }

    const limitResponse = await claimDailyCall(viewer.email);
    if (limitResponse) return limitResponse;

    const selectedIds = new Set(pending.results.map((row) => row.message_id));
    const historyRows = await DB.prepare(
      `SELECT m.id, m.role, m.character_id, m.author_name, m.content,
              CASE WHEN q.message_id IS NULL THEN 0 ELSE 1 END AS is_pending
       FROM messages m
       LEFT JOIN reply_queue q ON q.message_id = m.id
       WHERE m.owner_id = ? AND m.conversation_id = ?
       ORDER BY m.created_at DESC LIMIT 64`,
    )
      .bind(viewer.email, conversationId)
      .all<HistoryRow>();
    const history = historyRows.results
      .reverse()
      .filter((message) => !message.is_pending || selectedIds.has(message.id))
      .slice(-(20 + selectedIds.size));

    const memberIds = JSON.parse(conversation.member_ids) as string[];
    const replies =
      conversation.type === "group"
        ? await generateGroupReplies(memberIds, history)
        : await generateSingleReplies(memberIds[0], history);

    const bubbleReplies = replies.flatMap((reply) =>
      splitReplyIntoBubbles(reply.content).map((content) => ({
        ...reply,
        content,
      })),
    );
    const savedReplies = bubbleReplies.map((reply, index) => ({
      id: crypto.randomUUID(),
      role: "assistant" as const,
      ...reply,
      createdAt: new Date(Date.now() + index).toISOString(),
    }));
    const updatedAt = new Date().toISOString();
    await DB.batch([
      ...savedReplies.map((reply) =>
        DB.prepare(
          `INSERT INTO messages
           (id, conversation_id, owner_id, role, character_id, author_name, content, created_at)
           VALUES (?, ?, ?, 'assistant', ?, ?, ?, ?)`,
        ).bind(
          reply.id,
          conversationId,
          viewer.email,
          reply.characterId,
          reply.authorName,
          reply.content,
          reply.createdAt,
        ),
      ),
      ...pending.results.map((row) =>
        DB.prepare(
          "DELETE FROM reply_queue WHERE message_id = ? AND owner_id = ?",
        ).bind(row.message_id, viewer.email),
      ),
      DB.prepare(
        "UPDATE conversations SET updated_at = ? WHERE id = ? AND owner_id = ?",
      ).bind(updatedAt, conversationId, viewer.email),
    ]);

    return Response.json({
      replies: savedReplies,
      processedMessageIds: pending.results.map((row) => row.message_id),
    });
  } catch (error) {
    return apiError(error);
  } finally {
    if (lockToken && conversationId) {
      await releaseReplyJob(viewer.email, conversationId, lockToken).catch(
        () => undefined,
      );
    }
  }
}

async function claimReplyJob(
  ownerId: string,
  conversationId: string,
): Promise<string | null> {
  const { DB } = runtimeEnv();
  const token = crypto.randomUUID();
  const now = new Date().toISOString();
  const leaseUntil = new Date(Date.now() + 150_000).toISOString();
  const result = await DB.prepare(
    `INSERT INTO reply_jobs(conversation_id, owner_id, lock_token, lease_until)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(conversation_id) DO UPDATE SET
       owner_id = excluded.owner_id,
       lock_token = excluded.lock_token,
       lease_until = excluded.lease_until
     WHERE reply_jobs.owner_id = excluded.owner_id
       AND reply_jobs.lease_until <= ?`,
  )
    .bind(conversationId, ownerId, token, leaseUntil, now)
    .run();
  return (result.meta.changes ?? 0) > 0 ? token : null;
}

async function releaseReplyJob(
  ownerId: string,
  conversationId: string,
  lockToken: string,
) {
  const { DB } = runtimeEnv();
  await DB.prepare(
    `DELETE FROM reply_jobs
     WHERE conversation_id = ? AND owner_id = ? AND lock_token = ?`,
  )
    .bind(conversationId, ownerId, lockToken)
    .run();
}

async function claimDailyCall(ownerId: string): Promise<Response | null> {
  const { DB } = runtimeEnv();
  const day = new Date().toISOString().slice(0, 10);
  await DB.prepare(
    `INSERT INTO daily_usage(owner_id, usage_day, call_count)
     VALUES (?, ?, 0)
     ON CONFLICT(owner_id, usage_day) DO NOTHING`,
  )
    .bind(ownerId, day)
    .run();
  const usage = await DB.prepare(
    "SELECT call_count FROM daily_usage WHERE owner_id = ? AND usage_day = ?",
  )
    .bind(ownerId, day)
    .first<{ call_count: number }>();
  if ((usage?.call_count ?? 0) >= 80) {
    return Response.json(
      { error: "今天聊得够久啦，明天再继续吧。" },
      { status: 429 },
    );
  }
  await DB.prepare(
    `UPDATE daily_usage SET call_count = call_count + 1
     WHERE owner_id = ? AND usage_day = ?`,
  )
    .bind(ownerId, day)
    .run();
  return null;
}

async function generateSingleReplies(
  characterId: string,
  history: HistoryRow[],
): Promise<Reply[]> {
  const character = characterById(characterId);
  if (!character) return [];
  const system = buildSingleCharacterSystemPrompt(character);
  const raw = await complete([
    { role: "system", content: system },
    ...history.map((message) => ({
      role: message.role,
      content: message.content,
    })),
  ]);
  const messages = extractSingleMessages(raw);
  if (messages.length === 0) {
    throw new Error("模型回复格式无效");
  }
  return messages.map((content) => ({
    characterId,
    authorName: character.name,
    content,
  }));
}

async function generateGroupReplies(
  memberIds: string[],
  history: HistoryRow[],
): Promise<Reply[]> {
  const members = memberIds
    .map((id) => characterById(id))
    .filter((item) => item !== null);
  if (members.length === 0) return [];
  const transcript = history
    .map((message) => `${message.author_name || "旅行者"}：${message.content}`)
    .join("\n");
  const raw = await complete([
    {
      role: "system",
      content: buildGroupCharacterSystemPrompt(members, transcript),
    },
    {
      role: "user",
      content: "根据上面的完整群聊记录，输出本轮 JSON。",
    },
  ]);
  const parsed = parseJson(raw) as {
    messages?: Array<{ character_id?: unknown; content?: unknown }>;
  };
  if (!Array.isArray(parsed.messages)) {
    throw new Error("群聊回复格式无效");
  }
  return parsed.messages
    .map((item) => {
      const characterId =
        typeof item.character_id === "string" ? item.character_id : "";
      const character = members.find((member) => member.id === characterId);
      const content =
        typeof item.content === "string" ? cleanReply(item.content) : "";
      if (!character || !content) return null;
      return { characterId, authorName: character.name, content };
    })
    .filter((reply): reply is Reply => reply !== null)
    .slice(0, 3);
}

async function complete(
  messages: Array<{ role: string; content: string }>,
): Promise<string> {
  const runtime = runtimeEnv();
  const apiKey = runtime.DEEPSEEK_API_KEY?.trim();
  if (!apiKey) {
    throw new Error("模型服务尚未配置");
  }
  const baseUrl = (runtime.DEEPSEEK_BASE_URL || "https://api.deepseek.com").replace(
    /\/+$/,
    "",
  );
  let lastError = "模型没有返回正文";

  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      const response = await fetch(`${baseUrl}/v1/chat/completions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        signal: AbortSignal.timeout(45_000),
        body: JSON.stringify({
          model: runtime.DEEPSEEK_MODEL || "deepseek-v4-flash",
          messages,
          temperature: attempt === 0 ? 0.9 : 0.72,
          max_tokens: 700,
          thinking: { type: "disabled" },
          ...(attempt === 0
            ? { response_format: { type: "json_object" } }
            : {}),
        }),
      });
      if (!response.ok) {
        const errorText = await response.text();
        lastError = `模型服务返回 ${response.status}: ${errorText.slice(0, 180)}`;
        if (attempt === 0 && (response.status === 429 || response.status >= 500)) {
          await wait(650);
          continue;
        }
        throw new Error(lastError);
      }
      const data = (await response.json()) as {
        choices?: Array<{
          finish_reason?: string;
          message?: { content?: string | null };
        }>;
      };
      const content = data.choices?.[0]?.message?.content?.trim() ?? "";
      if (content) return content;
      lastError = `模型没有返回正文（${data.choices?.[0]?.finish_reason || "empty"}）`;
    } catch (error) {
      lastError = error instanceof Error ? error.message : lastError;
    }
    if (attempt === 0) await wait(500);
  }
  throw new Error(lastError);
}

function extractSingleMessages(raw: string): string[] {
  const parsed = parseJson(raw) as { messages?: unknown[] };
  const structured = Array.isArray(parsed.messages)
    ? parsed.messages
        .filter((item): item is string => typeof item === "string")
        .map(cleanReply)
        .filter(Boolean)
        .slice(0, 3)
    : [];
  if (structured.length > 0) return structured;

  if (!raw.trim().startsWith("{")) {
    return raw
      .split(/\n{2,}/)
      .map(cleanReply)
      .filter(Boolean)
      .slice(0, 3);
  }
  return [];
}

function parseJson(raw: string): unknown {
  const clean = raw.replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
  const start = clean.indexOf("{");
  const end = clean.lastIndexOf("}");
  if (start < 0 || end <= start) return {};
  try {
    return JSON.parse(clean.slice(start, end + 1));
  } catch {
    return {};
  }
}

function cleanReply(value: string): string {
  return value
    .replace(/^\s*[^：:\n]{1,12}[：:]\s*/, "")
    .replace(/[ \t]+/g, " ")
    .trim()
    .slice(0, 220);
}

function wait(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
