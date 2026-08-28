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

test("publishes the 3.0.0 complete character profile release", async () => {
  const [
    manifestText,
    readme,
    client,
    styles,
    characterText,
    importText,
    curatedManifestText,
    curatedSourcesText,
    curatedVerificationText,
    healthRoute,
  ] = await Promise.all([
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../README.md", import.meta.url), "utf8"),
    readFile(new URL("../app/chat/chat-app.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
    readFile(new URL("../data/characters.json", import.meta.url), "utf8"),
    readFile(
      new URL("../third_party/Genshin.Skill/MANIFEST.json", import.meta.url),
      "utf8",
    ),
    readFile(
      new URL("../third_party/curated-prompts/MANIFEST.json", import.meta.url),
      "utf8",
    ),
    readFile(
      new URL("../third_party/curated-prompts/SOURCES.json", import.meta.url),
      "utf8",
    ),
    readFile(
      new URL("../third_party/curated-prompts/VERIFICATION.json", import.meta.url),
      "utf8",
    ),
    readFile(new URL("../app/api/health/route.ts", import.meta.url), "utf8"),
  ]);
  const characterData = JSON.parse(characterText);
  const importManifest = JSON.parse(importText);
  const curatedManifest = JSON.parse(curatedManifestText);
  const curatedSources = JSON.parse(curatedSourcesText);
  const curatedVerification = JSON.parse(curatedVerificationText);
  assert.equal(JSON.parse(manifestText).version, "3.0.0");
  assert.match(readme.slice(0, 300), /https:\/\/teyvat-wechat\.onrender\.com/);
  assert.match(readme, /### 3\.0\.0 - 2026-08-28/);
  assert.match(client, /提瓦特微信 Web · 3\.0\.0/);
  assert.match(healthRoute, /version:\s*"3\.0\.0"/);
  assert.equal(importManifest.files.length, 97);
  assert.equal(curatedManifest.profiles.length, 30);
  assert.equal(curatedSources.characters.length, 30);
  assert.equal(curatedVerification.characters.length, 30);
  assert.equal(characterData.promptImport.importedCharacters, 97);
  assert.equal(characterData.promptImport.uncoveredCharacters.length, 30);
  assert.equal(characterData.curatedPromptImport.importedCharacters, 30);
  assert.equal(
    characterData.characters.filter(
      (character) =>
        character.promptProvenance?.project === "DGP-Studio/Genshin.Skill",
    ).length,
    97,
  );
  assert.match(client, /className=\{`traveler-switch-button/);
  assert.match(client, /async function toggleTraveler/);
  assert.doesNotMatch(client, /TravelerPickerPanel|profileView/);
  assert.doesNotMatch(styles, /traveler-choice-list|traveler-picker-page/);
  assert.match(client, /https:\/\/github\.com\/uinaqx\/Genshin_chat/);
  assert.match(styles, /\.tab-bar\s*\{[\s\S]*?height:\s*62px/);
  assert.match(styles, /\.tab-bar button\s*\{[\s\S]*?min-height:\s*0/);
});

test("sends all 127 character profiles to private and group models without truncation", async () => {
  const [contextBuilder, characterText, chatRoute] = await Promise.all([
    import(new URL("../app/lib/character-context.ts", import.meta.url)),
    readFile(new URL("../data/characters.json", import.meta.url), "utf8"),
    readFile(new URL("../app/api/chat/route.ts", import.meta.url), "utf8"),
  ]);
  const characterData = JSON.parse(characterText);
  const importedCharacters = characterData.characters.filter(
    (character) => !character.id.startsWith("traveler-"),
  );

  assert.equal(importedCharacters.length, 127);
  for (const character of importedCharacters) {
    const singleContext = contextBuilder.buildSingleCharacterSystemPrompt(character);
    const groupContext = contextBuilder.buildGroupCharacterSystemPrompt(
      [character],
      "旅行者：测试完整上下文",
    );

    for (const [mode, context] of [
      ["私聊", singleContext],
      ["群聊", groupContext],
    ]) {
      assert.ok(
        context.includes(character.prompt),
        `${character.name} 的${mode}请求缺少完整 Prompt`,
      );
      assert.ok(
        context.includes(character.soulMd),
        `${character.name} 的${mode}请求缺少完整 SoulMD`,
      );
      if (mode === "群聊") {
        assert.ok(
          context.includes(character.groupPrompt),
          `${character.name} 的群聊请求缺少完整群聊 Prompt`,
        );
      }
      assert.ok(
        context.includes(character.prompt.slice(-256)),
        `${character.name} 的${mode} Prompt 末尾被截断`,
      );
      assert.ok(
        context.includes(character.soulMd.slice(-256)),
        `${character.name} 的${mode} SoulMD 末尾被截断`,
      );
    }
  }

  assert.match(chatRoute, /buildSingleCharacterSystemPrompt\(character\)/);
  assert.match(
    chatRoute,
    /buildGroupCharacterSystemPrompt\(members, transcript\)/,
  );
  assert.doesNotMatch(chatRoute, /slice\(0,\s*(?:7000|4500|perMemberPromptLimit)/);
});

test("keeps private character prompts out of the public character API", async () => {
  const [charactersModule, charactersRoute] = await Promise.all([
    readFile(new URL("../app/lib/characters.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/characters/route.ts", import.meta.url), "utf8"),
  ]);
  assert.match(charactersRoute, /publicCharacters\(\)/);
  const publicMapper = charactersModule.split("export function publicCharacters")[1];
  assert.doesNotMatch(publicMapper, /prompt:\s*character\.prompt/);
  assert.doesNotMatch(publicMapper, /groupPrompt:\s*character\.groupPrompt/);
  assert.doesNotMatch(publicMapper, /soulMd:\s*character\.soulMd/);
});
