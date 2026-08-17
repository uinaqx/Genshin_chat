import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("ships independent account login and registration", async () => {
  const [page, form, viewer, styles] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/login-form.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/viewer.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  ]);
  assert.match(page, /提瓦特微信/);
  assert.match(form, /api\/auth\/\$\{mode\}/);
  assert.match(form, /创建账号/);
  assert.match(viewer, /teyvat_session/);
  assert.match(styles, /backdrop-filter:\s*blur/);
  assert.doesNotMatch(`${page}\n${viewer}`, /signin-with-chatgpt|oai-authenticated/);
});

test("keeps credentials and persistence server-side", async () => {
  const [chatPage, chatRoute, storage, auth, blueprint, exampleEnv] =
    await Promise.all([
      readFile(new URL("../app/chat/page.tsx", import.meta.url), "utf8"),
      readFile(new URL("../app/api/chat/route.ts", import.meta.url), "utf8"),
      readFile(new URL("../app/lib/storage.ts", import.meta.url), "utf8"),
      readFile(new URL("../app/lib/auth.ts", import.meta.url), "utf8"),
      readFile(new URL("../render.yaml", import.meta.url), "utf8"),
      readFile(new URL("../.env.example", import.meta.url), "utf8"),
    ]);
  assert.match(chatPage, /requireViewer/);
  assert.match(chatRoute, /viewer\.email/);
  assert.match(storage, /CREATE TABLE IF NOT EXISTS users/);
  assert.match(storage, /CREATE TABLE IF NOT EXISTS conversations/);
  assert.match(auth, /httpOnly:\s*true/);
  assert.match(blueprint, /property:\s*connectionString/);
  assert.match(blueprint, /DEEPSEEK_API_KEY[\s\S]*sync:\s*false/);
  assert.match(exampleEnv, /DATABASE_URL=/);
  assert.doesNotMatch(
    `${chatRoute}\n${storage}\n${auth}\n${blueprint}\n${exampleEnv}`,
    /sk-[A-Za-z0-9_-]{20,}/,
  );
});

test("keeps chat input available while durable reply batches run", async () => {
  const [client, chatRoute, messageRoute, storage, styles] = await Promise.all([
    readFile(new URL("../app/chat/chat-app.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/api/chat/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/messages/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/storage.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  ]);
  assert.match(client, /fetch\("\/api\/messages"/);
  assert.match(client, /pendingReplyIdsRef/);
  assert.match(client, /messageIds:\s*batch/);
  assert.doesNotMatch(client, /disabled=\{sending\}/);
  assert.match(messageRoute, /INSERT INTO reply_queue/);
  assert.match(chatRoute, /claimReplyJob/);
  assert.match(storage, /CREATE TABLE IF NOT EXISTS reply_jobs/);
  assert.match(styles, /\.tab-bar\s*\{[\s\S]*?z-index:\s*6/);
});

test("ships the current released character catalog", async () => {
  const data = JSON.parse(
    await readFile(new URL("../data/characters.json", import.meta.url), "utf8"),
  );
  assert.equal(data.characters.length, 121);
  assert.equal(
    data.characters.filter((character) => !character.id.startsWith("traveler-"))
      .length,
    116,
  );
  assert.equal(data.characters.at(-1).id, "sandrone");
});
