CREATE TABLE `reply_jobs` (
	`conversation_id` text PRIMARY KEY NOT NULL,
	`owner_id` text NOT NULL,
	`lock_token` text NOT NULL,
	`lease_until` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `reply_queue` (
	`message_id` text PRIMARY KEY NOT NULL,
	`conversation_id` text NOT NULL,
	`owner_id` text NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX `reply_queue_owner_conversation_idx` ON `reply_queue` (`owner_id`,`conversation_id`,`created_at`);