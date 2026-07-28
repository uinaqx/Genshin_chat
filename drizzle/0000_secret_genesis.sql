CREATE TABLE `conversations` (
	`id` text PRIMARY KEY NOT NULL,
	`owner_id` text NOT NULL,
	`title` text NOT NULL,
	`type` text NOT NULL,
	`member_ids` text NOT NULL,
	`created_at` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX `conversations_owner_updated_idx` ON `conversations` (`owner_id`,`updated_at`);--> statement-breakpoint
CREATE TABLE `daily_usage` (
	`owner_id` text NOT NULL,
	`usage_day` text NOT NULL,
	`call_count` integer DEFAULT 0 NOT NULL,
	PRIMARY KEY(`owner_id`, `usage_day`)
);
--> statement-breakpoint
CREATE TABLE `messages` (
	`id` text PRIMARY KEY NOT NULL,
	`conversation_id` text NOT NULL,
	`owner_id` text NOT NULL,
	`role` text NOT NULL,
	`character_id` text,
	`author_name` text,
	`content` text NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX `messages_conversation_created_idx` ON `messages` (`owner_id`,`conversation_id`,`created_at`);