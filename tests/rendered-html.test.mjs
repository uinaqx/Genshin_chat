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
  assert.doesNotMatch(form, /name="displayName"/);
  assert.match(viewer, /teyvat_session/);
  assert.match(viewer, /travelerGender/);
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
  assert.match(storage, /connectionTimeoutMillis:\s*5_000/);
  assert.match(auth, /httpOnly:\s*true/);
  assert.match(blueprint, /property:\s*connectionString/);
  assert.match(blueprint, /DEEPSEEK_API_KEY[\s\S]*sync:\s*false/);
  assert.equal(blueprint.match(/region:\s*oregon/g)?.length, 2);
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
  assert.match(styles, /grid-template-areas:[\s\S]*?"tabs"/);
});

test("ships the current released character catalog", async () => {
  const data = JSON.parse(
    await readFile(new URL("../data/characters.json", import.meta.url), "utf8"),
  );
  assert.equal(data.characters.length, 132);
  assert.equal(
    data.characters.filter((character) => !character.id.startsWith("traveler-"))
      .length,
    127,
  );
  assert.equal(data.characters.at(-1).id, "tsaritsa");
});

test("splits multi-sentence model output into durable chat bubbles", async () => {
  const [{ splitReplyIntoBubbles }, chatRoute] = await Promise.all([
    import(new URL("../app/lib/reply-bubbles.ts", import.meta.url)),
    readFile(new URL("../app/api/chat/route.ts", import.meta.url), "utf8"),
  ]);
  assert.deepEqual(
    splitReplyIntoBubbles("先等等。\n我马上回来！别走？"),
    ["先等等。", "我马上回来！", "别走？"],
  );
  assert.deepEqual(splitReplyIntoBubbles("版本是 1.5，网址 example.com。"), [
    "版本是 1.5，网址 example.com。",
  ]);
  assert.match(chatRoute, /splitReplyIntoBubbles\(reply\.content\)/);
  assert.match(chatRoute, /savedReplies = bubbleReplies\.map/);
});

test("publishes the 2.0.0 release and prominent web entry", async () => {
  const [manifestText, readme, client] = await Promise.all([
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../README.md", import.meta.url), "utf8"),
    readFile(new URL("../app/chat/chat-app.tsx", import.meta.url), "utf8"),
  ]);
  assert.equal(JSON.parse(manifestText).version, "2.0.0");
  assert.match(readme.slice(0, 300), /https:\/\/teyvat-wechat\.onrender\.com/);
  assert.match(readme, /### 2\.0\.0 - 2026-08-18/);
  assert.match(client, /提瓦特微信 Web · 2\.0\.0/);
});
