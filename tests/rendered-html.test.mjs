import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("ships the finished login surface", async () => {
  const [page, layout, styles] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  ]);
  assert.match(page, /提瓦特微信/);
  assert.match(page, /使用 ChatGPT 登录/);
  assert.match(page, /聊天记录仅对当前账号可见/);
  assert.match(layout, /og\.png/);
  assert.match(styles, /backdrop-filter:\s*blur/);
  assert.doesNotMatch(
    `${page}\n${layout}\n${styles}`,
    /codex-preview|Your site is taking shape/,
  );
});

test("keeps identity, persistence, and model credentials server-side", async () => {
  const [chatPage, viewer, chatRoute, storage, hosting, exampleEnv] =
    await Promise.all([
      readFile(new URL("../app/chat/page.tsx", import.meta.url), "utf8"),
      readFile(new URL("../app/lib/viewer.ts", import.meta.url), "utf8"),
      readFile(new URL("../app/api/chat/route.ts", import.meta.url), "utf8"),
      readFile(new URL("../app/lib/storage.ts", import.meta.url), "utf8"),
      readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
      readFile(new URL("../.env.example", import.meta.url), "utf8"),
    ]);

  assert.match(chatPage, /requireViewer/);
  assert.match(viewer, /getChatGPTUser/);
  assert.match(chatRoute, /viewer\.email/);
  assert.match(chatRoute, /DEEPSEEK_API_KEY/);
  assert.match(storage, /CREATE TABLE IF NOT EXISTS conversations/);
  assert.match(hosting, /"d1": "DB"/);
  assert.match(exampleEnv, /DEEPSEEK_API_KEY=/);
  assert.doesNotMatch(
    `${chatRoute}\n${storage}\n${exampleEnv}`,
    /sk-[A-Za-z0-9_-]{20,}/,
  );
});
