# Changelog

## 2.0.0+20

- Rebuilt context assembly around a bounded recent-history budget with local timestamps.
- Added relevant MemoryMD retrieval so only topic-related memory fragments are injected.
- Added time-aware dialogue planning with stricter WeChat-style sentence and character limits.
- Added deterministic local reply shaping as a fallback when model rewriting is unavailable.
- Added planner-controlled one-to-three-bubble private-chat replies with natural delivery spacing.
- Reworked proactive chat with quiet hours, topic deduplication, no-repeat behavior when the user has not replied, contextual follow-ups, and character-life messages.
- Added phrase-level duplicate checks, time-of-day validation, stage-direction cleanup, and bounded topic rewrites for proactive messages.
- Merged Android worker writes back into live in-memory conversations so background messages appear without losing state.
- Added shared foreground/background file locking, atomic replacement, and message reconciliation to prevent concurrent saves from overwriting new chat bubbles.
- Added per-character speaking recency to improve group speaker variety and reduce queue-like replies.
- Updated the Android background worker to use the same proactive scheduling and short-message rules.
- Added reasoning-model token budgets and truncation rejection for OpenAI-compatible DeepSeek-style responses.
- Replaced hidden API test snackbars with visible success and failure dialogs.
- Read the displayed app version from Android package metadata to prevent stale version labels.
- Added automated tests for memory retrieval, daily-chat planning, hard reply limits, proactive anti-spam behavior, and concurrent foreground/background saves.

## 1.9.1+19

- Stopped writing LLM failure notices into the chat as system messages; failures now only show a transient in-app toast.
- Increased LLM request waiting time to reduce false failures on slower proxy or relay services.
- Made optional web search failures non-blocking so search issues no longer interrupt normal character replies.
- Clarified local error messages for missing API keys, daily call limits, and timeouts.

## 1.9.0+18

- Added one-click API testing in setup and settings.
- Improved OpenAI-compatible response parsing for non-string message content, direct text fields, and clearer returned-format errors.
- Made validator, memory, and follow-up post-processing failures stop blocking an already generated visible reply.
- Fixed a malformed reply-normalization regular expression that could crash after a successful LLM response.
- Saved local LLM failure details as system messages in the chat so failures are visible and diagnosable.
- Hid backend SoulMD and speech examples from the contact profile UI, replacing them with concise public character info.
- Added API format selection for OpenAI-compatible chat completions and Anthropic Messages API.
- Fixed API URL normalization, Anthropic history conversion, and clearer HTTP error messages.
- Refactored the chat system into role profiles, dialogue planning, response generation, validation, group orchestration, memory, and proactive scheduling.
- Improved single chat replies so they are shorter and less like AI assistant answers.
- Improved group chat so each turn selects 0 to 3 speakers instead of making every member reply.
- Added context-based real chat follow-ups for unfinished topics.
- Added API cost controls such as max tokens, daily call limit, group speaker cap, and cooldowns.
- Moved Android API Key storage away from the normal settings JSON file.
- Updated GitHub preparation files and documentation.
