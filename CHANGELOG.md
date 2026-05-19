# Changelog

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
