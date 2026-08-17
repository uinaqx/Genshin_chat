import { index, integer, primaryKey, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const conversations = sqliteTable(
  "conversations",
  {
    id: text("id").primaryKey(),
    ownerId: text("owner_id").notNull(),
    title: text("title").notNull(),
    type: text("type").notNull(),
    memberIds: text("member_ids").notNull(),
    createdAt: text("created_at").notNull(),
    updatedAt: text("updated_at").notNull(),
  },
  (table) => [index("conversations_owner_updated_idx").on(table.ownerId, table.updatedAt)],
);

export const messages = sqliteTable(
  "messages",
  {
    id: text("id").primaryKey(),
    conversationId: text("conversation_id").notNull(),
    ownerId: text("owner_id").notNull(),
    role: text("role").notNull(),
    characterId: text("character_id"),
    authorName: text("author_name"),
    content: text("content").notNull(),
    createdAt: text("created_at").notNull(),
  },
  (table) => [
    index("messages_conversation_created_idx").on(
      table.ownerId,
      table.conversationId,
      table.createdAt,
    ),
  ],
);

export const dailyUsage = sqliteTable(
  "daily_usage",
  {
    ownerId: text("owner_id").notNull(),
    usageDay: text("usage_day").notNull(),
    callCount: integer("call_count").notNull().default(0),
  },
  (table) => [primaryKey({ columns: [table.ownerId, table.usageDay] })],
);

export const replyQueue = sqliteTable(
  "reply_queue",
  {
    messageId: text("message_id").primaryKey(),
    conversationId: text("conversation_id").notNull(),
    ownerId: text("owner_id").notNull(),
    createdAt: text("created_at").notNull(),
  },
  (table) => [
    index("reply_queue_owner_conversation_idx").on(
      table.ownerId,
      table.conversationId,
      table.createdAt,
    ),
  ],
);

export const replyJobs = sqliteTable("reply_jobs", {
  conversationId: text("conversation_id").primaryKey(),
  ownerId: text("owner_id").notNull(),
  lockToken: text("lock_token").notNull(),
  leaseUntil: text("lease_until").notNull(),
});
