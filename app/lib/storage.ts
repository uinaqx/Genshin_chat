import { Pool, type PoolClient, type QueryResult, type QueryResultRow } from "pg";

type BoundValue = string | number | null;

export type RuntimeEnv = {
  DB: PostgresDatabase;
  DEEPSEEK_API_KEY?: string;
  DEEPSEEK_BASE_URL?: string;
  DEEPSEEK_MODEL?: string;
};

type RunResult = {
  meta: { changes: number };
};

class PostgresStatement {
  readonly sql: string;
  readonly values: BoundValue[];
  private readonly database: PostgresDatabase;

  constructor(
    database: PostgresDatabase,
    sql: string,
    values: BoundValue[] = [],
  ) {
    this.database = database;
    this.sql = sql;
    this.values = values;
  }

  bind(...values: BoundValue[]) {
    return new PostgresStatement(this.database, this.sql, values);
  }

  async all<T extends QueryResultRow>(): Promise<{ results: T[] }> {
    const result = await this.database.query<T>(this.sql, this.values);
    return { results: result.rows };
  }

  async first<T extends QueryResultRow>(): Promise<T | null> {
    const result = await this.database.query<T>(this.sql, this.values);
    return result.rows[0] ?? null;
  }

  async run(): Promise<RunResult> {
    const result = await this.database.query(this.sql, this.values);
    return { meta: { changes: result.rowCount ?? 0 } };
  }
}

export class PostgresDatabase {
  private readonly pool: Pool;

  constructor(connectionString: string) {
    const local = /localhost|127\.0\.0\.1/.test(connectionString);
    this.pool = new Pool({
      connectionString,
      max: 10,
      ssl:
        process.env.DATABASE_SSL === "false" || local
          ? false
          : { rejectUnauthorized: false },
    });
  }

  prepare(sql: string) {
    return new PostgresStatement(this, sql);
  }

  async batch(statements: PostgresStatement[]) {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const results = [];
      for (const statement of statements) {
        results.push(await this.query(statement.sql, statement.values, client));
      }
      await client.query("COMMIT");
      return results;
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async query<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    values: BoundValue[],
    client?: PoolClient,
  ): Promise<QueryResult<T>> {
    return (client ?? this.pool).query<T>(replacePlaceholders(sql), values);
  }
}

function replacePlaceholders(sql: string): string {
  let index = 0;
  return sql.replace(/\?/g, () => `$${++index}`);
}

let database: PostgresDatabase | null = null;

export function runtimeEnv(): RuntimeEnv {
  const connectionString = process.env.DATABASE_URL?.trim();
  if (!connectionString) throw new Error("DATABASE_URL 尚未配置");
  database ??= new PostgresDatabase(connectionString);
  return {
    DB: database,
    DEEPSEEK_API_KEY: process.env.DEEPSEEK_API_KEY,
    DEEPSEEK_BASE_URL: process.env.DEEPSEEK_BASE_URL,
    DEEPSEEK_MODEL: process.env.DEEPSEEK_MODEL,
  };
}

let schemaReady: Promise<void> | null = null;

export function ensureSchema(): Promise<void> {
  schemaReady ??= createSchema().catch((error) => {
    schemaReady = null;
    throw error;
  });
  return schemaReady;
}

async function createSchema(): Promise<void> {
  const { DB } = runtimeEnv();
  await DB.batch([
    DB.prepare(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    `),
    DB.prepare(`
      CREATE TABLE IF NOT EXISTS sessions (
        token_hash TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL
      )
    `),
    DB.prepare(`
      CREATE INDEX IF NOT EXISTS sessions_user_expires_idx
      ON sessions(user_id, expires_at)
    `),
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
    DB.prepare(`
      CREATE TABLE IF NOT EXISTS reply_queue (
        message_id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    `),
    DB.prepare(`
      CREATE INDEX IF NOT EXISTS reply_queue_owner_conversation_idx
      ON reply_queue(owner_id, conversation_id, created_at)
    `),
    DB.prepare(`
      CREATE TABLE IF NOT EXISTS reply_jobs (
        conversation_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        lock_token TEXT NOT NULL,
        lease_until TEXT NOT NULL
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
