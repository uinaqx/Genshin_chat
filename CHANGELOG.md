# Changelog

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
