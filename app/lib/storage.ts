import { env } from "cloudflare:workers";

export type RuntimeEnv = {
  DB: D1Database;
  DEEPSEEK_API_KEY?: string;
  DEEPSEEK_BASE_URL?: string;
  DEEPSEEK_MODEL?: string;
};

export function runtimeEnv(): RuntimeEnv {
  return env as unknown as RuntimeEnv;
}

let schemaReady: Promise<void> | null = null;

export function ensureSchema(): Promise<void> {
  schemaReady ??= createSchema();
  return schemaReady;
}

async function createSchema(): Promise<void> {
  const { DB } = runtimeEnv();
  await DB.batch([
    DB.prepare(`
      CREATE TABLE IF NOT EXISTS conversations (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        member_ids TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    `),
    DB.prepare(`
      CREATE INDEX IF NOT EXISTS conversations_owner_updated_idx
      ON conversations(owner_id, updated_at)
    `),
    DB.prepare(`
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        role TEXT NOT NULL,
        character_id TEXT,
        author_name TEXT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    `),
    DB.prepare(`
      CREATE INDEX IF NOT EXISTS messages_conversation_created_idx
      ON messages(owner_id, conversation_id, created_at)
    `),
    DB.prepare(`
      CREATE TABLE IF NOT EXISTS daily_usage (
        owner_id TEXT NOT NULL,
        usage_day TEXT NOT NULL,
        call_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(owner_id, usage_day)
      )
    `),
  ]);
}

export function apiError(error: unknown): Response {
  const message = error instanceof Error ? error.message : "请求暂时失败";
  console.error("[teyvat-web]", message);
  return Response.json(
    { error: "提瓦特的信号暂时不稳定，请稍后再试。" },
    { status: 500 },
  );
}
