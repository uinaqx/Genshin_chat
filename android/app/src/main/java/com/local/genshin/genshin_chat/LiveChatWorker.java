package com.local.genshin.genshin_chat;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.work.Constraints;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.channels.FileChannel;
import java.nio.channels.FileLock;
import java.nio.charset.StandardCharsets;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;

public class LiveChatWorker extends Worker {
    private static final String PERIODIC_WORK = "teyvat_follow_up_periodic";
    private static final String ONCE_WORK = "teyvat_follow_up_once";

    public LiveChatWorker(@NonNull Context context, @NonNull WorkerParameters params) {
        super(context, params);
    }

    public static void sync(Context context) {
        WorkManager workManager = WorkManager.getInstance(context.getApplicationContext());
        if (!hasPendingFollowUps(context)) {
            workManager.cancelUniqueWork(PERIODIC_WORK);
            workManager.cancelUniqueWork(ONCE_WORK);
            return;
        }

        Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build();
        PeriodicWorkRequest periodic = new PeriodicWorkRequest.Builder(
                LiveChatWorker.class,
                15,
                TimeUnit.MINUTES
        ).setConstraints(constraints).build();
        long delayMinutes = Math.max(1L, nextDelayMinutes(context));
        OneTimeWorkRequest once = new OneTimeWorkRequest.Builder(LiveChatWorker.class)
                .setInitialDelay(delayMinutes, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build();

        workManager.enqueueUniquePeriodicWork(
                PERIODIC_WORK,
                ExistingPeriodicWorkPolicy.UPDATE,
                periodic
        );
        workManager.enqueueUniqueWork(ONCE_WORK, ExistingWorkPolicy.REPLACE, once);
    }

    @NonNull
    @Override
    public Result doWork() {
        File lockFile = new File(getApplicationContext().getFilesDir(), "follow_up_worker.lock");
        try (FileOutputStream lockStream = new FileOutputStream(lockFile, true);
             FileChannel channel = lockStream.getChannel();
             FileLock ignored = channel.tryLock()) {
            if (ignored == null) {
                return Result.success();
            }
            runFollowUps();
            sync(getApplicationContext());
            return Result.success();
        } catch (Exception ignored) {
            return Result.success();
        }
    }

    private static boolean hasPendingFollowUps(Context context) {
        try {
            if (apiKey(context).trim().isEmpty()) {
                return false;
            }
            JSONObject conversations = readObject(new File(context.getFilesDir(), "conversations.json"));
            JSONArray items = conversations.optJSONArray("items");
            if (items == null) {
                return false;
            }
            for (int i = 0; i < items.length(); i += 1) {
                JSONObject conversation = items.optJSONObject(i);
                if (conversation == null) {
                    continue;
                }
                JSONArray followUps = conversation.optJSONArray("followUps");
                if ((followUps != null && followUps.length() > 0)
                        || conversation.optBoolean("realChatEnabled", false)) {
                    return true;
                }
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    private static long nextDelayMinutes(Context context) {
        long now = System.currentTimeMillis();
        long nearest = now + TimeUnit.MINUTES.toMillis(15);
        try {
            JSONObject conversations = readObject(new File(context.getFilesDir(), "conversations.json"));
            JSONArray items = conversations.optJSONArray("items");
            if (items == null) {
                return 15L;
            }
            for (int i = 0; i < items.length(); i += 1) {
                JSONObject conversation = items.optJSONObject(i);
                if (conversation == null) {
                    continue;
                }
                JSONArray followUps = conversation.optJSONArray("followUps");
                if (followUps == null) {
                    followUps = new JSONArray();
                }
                for (int j = 0; j < followUps.length(); j += 1) {
                    JSONObject item = followUps.optJSONObject(j);
                    if (item == null) {
                        continue;
                    }
                    long due = parseTime(item.optString("dueAt", ""));
                    if (due == 0L) {
                        return 1L;
                    }
                    if (due < nearest) {
                        nearest = due;
                    }
                }
                if (conversation.optBoolean("realChatEnabled", false)) {
                    long ping = parseTime(conversation.optString("nextPingAt", ""));
                    if (ping > 0L && ping < nearest) {
                        nearest = ping;
                    }
                }
            }
        } catch (Exception ignored) {
            return 15L;
        }
        long diff = Math.max(0L, nearest - now);
        return Math.max(1L, TimeUnit.MILLISECONDS.toMinutes(diff));
    }

    private void runFollowUps() throws Exception {
        Context context = getApplicationContext();
        File conversationFile = new File(context.getFilesDir(), "conversations.json");
        JSONObject settings = readObject(new File(context.getFilesDir(), "settings.json"));
        String apiKey = apiKey(context);
        if (apiKey.trim().isEmpty()) {
            return;
        }
        settings.put("apiKey", apiKey);
        JSONObject data = readObject(conversationFile);
        JSONArray items = data.optJSONArray("items");
        if (items == null) {
            return;
        }
        Map<String, CharacterInfo> characters = loadCharacters(context);
        long now = System.currentTimeMillis();
        int handled = 0;
        for (int i = 0; i < items.length() && handled < 3; i += 1) {
            JSONObject conversation = items.optJSONObject(i);
            if (conversation == null) {
                continue;
            }
            JSONArray followUps = conversation.optJSONArray("followUps");
            if ((followUps == null || followUps.length() == 0)
                    && !conversation.optBoolean("realChatEnabled", false)) {
                continue;
            }
            if (followUps == null) {
                followUps = new JSONArray();
            }
            List<PendingPlan> duePlans = new ArrayList<>();
            for (int j = 0; j < followUps.length(); j += 1) {
                JSONObject plan = followUps.optJSONObject(j);
                if (plan == null) {
                    continue;
                }
                long dueAt = parseTime(plan.optString("dueAt", ""));
                if (dueAt == 0L || dueAt <= now) {
                    duePlans.add(new PendingPlan(plan));
                }
            }
            if (duePlans.isEmpty()) {
                PendingPlan proactive = proactivePlan(conversation, characters, now);
                if (proactive != null) {
                    duePlans.add(proactive);
                } else {
                    continue;
                }
            }
            for (PendingPlan plan : duePlans) {
                CharacterInfo speaker = characters.get(plan.speakerId);
                if (speaker == null) {
                    removeFollowUp(conversation, plan.id);
                    continue;
                }
                String answer = reply(settings, conversation, speaker, plan, characters);
                removeFollowUp(conversation, plan.id);
                if (answer.trim().isEmpty()) {
                    continue;
                }
                JSONArray messages = conversation.optJSONArray("messages");
                if (messages == null) {
                    messages = new JSONArray();
                    conversation.put("messages", messages);
                }
                JSONObject message = new JSONObject();
                message.put("sender", "assistant");
                message.put("content", answer);
                message.put("createdAt", nowString());
                message.put("characterId", speaker.id);
                message.put("authorName", speaker.name);
                if (!isNearDuplicateReply(messages, message)) {
                    messages.put(message);
                    conversation.put("updatedAt", nowString());
                    JSONObject lastSpoke = conversation.optJSONObject("lastSpokeAtByCharacter");
                    if (lastSpoke == null) {
                        lastSpoke = new JSONObject();
                        conversation.put("lastSpokeAtByCharacter", lastSpoke);
                    }
                    lastSpoke.put(speaker.id, nowString());
                    conversation.put("lastCharacterPingAt", nowString());
                    if (plan.id.startsWith("proactive-")) {
                        conversation.put("lastProactiveAt", nowString());
                        conversation.put("lastProactiveTopic", plan.prompt);
                    }
                    if (conversation.optBoolean("realChatEnabled", false)) {
                        conversation.put("nextPingAt", formatTime(nextProactiveAt(conversation, now)));
                    }
                }
                handled += 1;
                if (handled >= 3) {
                    break;
                }
            }
        }
        writeObject(conversationFile, data);
    }

    private static String apiKey(Context context) {
        String stored = context.getSharedPreferences("teyvat_secure_settings", Context.MODE_PRIVATE)
                .getString("api_key", "");
        if (stored != null && !stored.trim().isEmpty()) {
            return stored;
        }
        try {
            JSONObject settings = readObject(new File(context.getFilesDir(), "settings.json"));
            return settings.optString("apiKey", "");
        } catch (Exception ignored) {
            return "";
        }
    }

    private static void removeFollowUp(JSONObject conversation, String id) {
        JSONArray followUps = conversation.optJSONArray("followUps");
        if (followUps == null) {
            return;
        }
        for (int i = followUps.length() - 1; i >= 0; i -= 1) {
            JSONObject item = followUps.optJSONObject(i);
            if (item != null && id.equals(item.optString("id", ""))) {
                followUps.remove(i);
            }
        }
    }

    private static PendingPlan proactivePlan(
            JSONObject conversation,
            Map<String, CharacterInfo> characters,
            long now
    ) throws Exception {
        if (!conversation.optBoolean("realChatEnabled", false)) {
            return null;
        }
        long nextPingAt = parseTime(conversation.optString("nextPingAt", ""));
        if (nextPingAt == 0L || nextPingAt > now) {
            return null;
        }
        if (isQuietHour(now)) {
            conversation.put("nextPingAt", formatTime(nextActiveTime(now)));
            return null;
        }
        long lastPingAt = parseTime(conversation.optString("lastProactiveAt", ""));
        int cooldown = Math.max(45, conversation.optInt("cooldownMinutes", 90));
        if (lastPingAt > 0L && now - lastPingAt < TimeUnit.MINUTES.toMillis(cooldown)) {
            return null;
        }
        long lastUserReplyAt = parseTime(conversation.optString("lastUserReplyAt", ""));
        if (lastPingAt > 0L && lastUserReplyAt <= lastPingAt) {
            conversation.put(
                    "nextPingAt",
                    formatTime(nextActiveTime(now + TimeUnit.HOURS.toMillis(10)))
            );
            return null;
        }
        String seed = unfinishedSeed(conversation);
        boolean isUnfinished = !seed.isEmpty();
        if (seed.isEmpty()) {
            seed = contextSeed(conversation);
        }
        JSONArray memberIds = conversation.optJSONArray("memberIds");
        if (memberIds == null || memberIds.length() == 0) {
            return null;
        }
        String speakerId = "";
        for (int i = 0; i < memberIds.length(); i += 1) {
            String id = memberIds.optString(i);
            CharacterInfo character = characters.get(id);
            if (character != null && seed.contains(character.name)) {
                speakerId = id;
                break;
            }
        }
        if (speakerId.isEmpty()) {
            JSONObject lastSpoke = conversation.optJSONObject("lastSpokeAtByCharacter");
            long oldest = Long.MAX_VALUE;
            for (int i = 0; i < memberIds.length(); i += 1) {
                String id = memberIds.optString(i, "");
                if (!characters.containsKey(id)) {
                    continue;
                }
                long spokeAt = lastSpoke == null
                        ? 0L
                        : parseTime(lastSpoke.optString(id, ""));
                if (spokeAt < oldest) {
                    oldest = spokeAt;
                    speakerId = id;
                }
            }
        }
        if (speakerId.isEmpty() || !characters.containsKey(speakerId)) {
            return null;
        }
        CharacterInfo speaker = characters.get(speakerId);
        if (seed.isEmpty()) {
            seed = characterLifeSeed(speaker, now);
        }
        String normalizedSeed = normalizeReplyForCompare(seed);
        String previousTopic = normalizeReplyForCompare(
                conversation.optString("lastProactiveTopic", "")
        );
        if (!normalizedSeed.isEmpty() && normalizedSeed.equals(previousTopic)) {
            conversation.put(
                    "nextPingAt",
                    formatTime(nextActiveTime(now + TimeUnit.HOURS.toMillis(4)))
            );
            return null;
        }
        JSONObject json = new JSONObject();
        json.put("id", "proactive-" + now);
        json.put("speakerId", speakerId);
        json.put(
                "reason",
                isUnfinished
                        ? "真实聊天：跟进旅行者之前留下的具体事情"
                        : "真实聊天：结合上下文和当前时间自然发消息"
        );
        json.put("prompt", seed);
        return new PendingPlan(json);
    }

    private static String unfinishedSeed(JSONObject conversation) {
        String source = "";
        JSONObject memories = conversation.optJSONObject("memoryMdByCharacter");
        if (memories != null) {
            source += memories.toString();
        }
        source += "\n" + recentText(conversation, 16);
        String[] keys = {"明天", "后天", "一小时", "半小时", "等会", "到时候", "项目", "作业", "考试", "提交", "交上去", "睡觉", "跑步"};
        for (String key : keys) {
            int index = source.indexOf(key);
            if (index >= 0) {
                int start = Math.max(0, index - 24);
                int end = Math.min(source.length(), index + 42);
                return source.substring(start, end).replace("\n", " ").trim();
            }
        }
        return "";
    }

    private static String contextSeed(JSONObject conversation) {
        JSONArray messages = conversation.optJSONArray("messages");
        if (messages == null) {
            return "";
        }
        if (messages.length() > 0) {
            JSONObject latest = messages.optJSONObject(messages.length() - 1);
            if (latest != null && !"user".equals(latest.optString("sender"))) {
                return "";
            }
        }
        String previousTopic = normalizeReplyForCompare(
                conversation.optString("lastProactiveTopic", "")
        );
        for (int i = messages.length() - 1; i >= 0; i -= 1) {
            JSONObject message = messages.optJSONObject(i);
            if (message == null || !"user".equals(message.optString("sender"))) {
                continue;
            }
            String text = message.optString("content", "").trim();
            if (text.length() < 5 || normalizeReplyForCompare(text).equals(previousTopic)) {
                continue;
            }
            if (text.matches("^(嗯|好|行|哈哈+|哦|ok|OK|晚安|早安|在吗|你在干嘛|忙吗|你呢)[。！？?!~～]?$")) {
                continue;
            }
            return "旅行者最近聊到：“" + shorten(text, 54) + "”。"
                    + "从这个真实上下文自然接一句或分享联想到的具体小事；"
                    + "不要复述原话，不要问“在吗/干嘛/最近好吗”。";
        }
        return "";
    }

    private static String characterLifeSeed(CharacterInfo speaker, long now) {
        return "现在是" + chatTimeLabel(now) + "。"
                + speaker.name + "正在过自己的日常。"
                + "结合身份“" + speaker.title + "”和角色设定，"
                + "分享一件此刻刚发生的具体小事或一个自然念头。"
                + "最多两句，不要早安晚安，不要泛泛关心，不要问“在吗/干嘛/最近好吗”。";
    }

    private static String relevantMemory(String memory, String query, int maxItems) {
        if (memory == null || memory.trim().isEmpty()) {
            return "";
        }
        String[] lines = memory.split("\\r?\\n");
        String[] keys = {
                "考试", "学习", "作业", "项目", "工作", "提交", "睡眠", "睡觉", "失眠",
                "跑步", "运动", "喜欢", "讨厌", "生病", "难受", "压力", "明天", "昨天", "约定"
        };
        List<String> selected = new ArrayList<>();
        for (int i = lines.length - 1; i >= 0 && selected.size() < maxItems; i -= 1) {
            String line = lines[i].trim();
            if (line.isEmpty()) {
                continue;
            }
            boolean relevant = i >= lines.length - 4;
            for (String key : keys) {
                if (query.contains(key) && line.contains(key)) {
                    relevant = true;
                    break;
                }
            }
            if (relevant) {
                selected.add(0, line);
            }
        }
        return joinLines(selected);
    }

    private String reply(
            JSONObject settings,
            JSONObject conversation,
            CharacterInfo speaker,
            PendingPlan plan,
            Map<String, CharacterInfo> characters
    ) throws Exception {
        JSONArray prompt = promptMessages(conversation, speaker, plan, characters);
        String answer = llmComplete(settings, prompt, 0.75);
        for (int attempt = 0; attempt < 2; attempt += 1) {
            if (!needsRoleRetry(answer)
                    && !needsProactiveRetry(answer, plan)
                    && !needsSpeakerRetry(answer, conversation, speaker, characters)) {
                break;
            }
            prompt.put(new JSONObject().put("role", "assistant").put("content", answer));
            prompt.put(new JSONObject()
                    .put("role", "user")
                    .put("content", "上一条回复出戏、语言错误、发言人错误、包含括号旁白，"
                            + "或只是泛泛向旅行者提问。\n"
                            + "请立刻忘掉AI、Claude、代码助手、模型这些身份。\n"
                            + "你就是《原神》里的「" + speaker.name + "」，正在和旅行者对话。\n"
                            + "先说一个你自己此刻刚发生的新细节，不要复述最近消息，"
                            + "不要写动作旁白，只用简体中文重写。"));
            answer = llmComplete(settings, prompt, attempt == 0 ? 0.45 : 0.72);
        }
        String cleaned = enforceWechatLength(
                cleanSpeakerAnswer(answer, conversation, speaker, characters),
                72,
                2
        );
        JSONArray recentMessages = conversation.optJSONArray("messages");
        JSONObject candidate = new JSONObject()
                .put("sender", "assistant")
                .put("content", cleaned)
                .put("characterId", speaker.id);
        for (int attempt = 0; recentMessages != null && attempt < 2; attempt += 1) {
            candidate.put("content", cleaned);
            if (!isNearDuplicateReply(recentMessages, candidate)) {
                break;
            }
            prompt.put(new JSONObject().put("role", "assistant").put("content", cleaned));
            prompt.put(new JSONObject()
                    .put("role", "user")
                    .put("content", attempt == 0
                            ? "这条和你最近已经说过的话太像。换一个全新的具体动作、发现或话题，"
                            + "不要复述、拼接或改写最近消息。仍然只输出一到两句简体中文微信正文。"
                            : "仍然重复。完全放弃旅行者刚才的话题，改讲这个角色此刻自己的工作、"
                            + "见闻或意外小事。不得沿用上一条中的任何物品、地点或请求，只输出正文。"));
            answer = llmComplete(settings, prompt, attempt == 0 ? 0.82 : 0.95);
            cleaned = enforceWechatLength(
                    cleanSpeakerAnswer(answer, conversation, speaker, characters),
                    72,
                    2
            );
        }
        if (needsRoleRetry(cleaned)
                || needsProactiveRetry(cleaned, plan)
                || needsSpeakerRetry(cleaned, conversation, speaker, characters)) {
            return "";
        }
        return cleaned;
    }

    private JSONArray promptMessages(
            JSONObject conversation,
            CharacterInfo speaker,
            PendingPlan plan,
            Map<String, CharacterInfo> characters
    ) throws Exception {
        boolean isGroup = "group".equals(conversation.optString("type"));
        boolean independentProactive = plan.id.startsWith("proactive-")
                && !plan.reason.contains("未完成");
        String membersText = memberSummary(conversation.optJSONArray("memberIds"), characters);
        StringBuilder system = new StringBuilder();
        system.append("最高优先级身份约束：你正在真实扮演《原神》角色「")
                .append(speaker.name)
                .append("」。\n")
                .append("你不是 AI，不是 Claude，不是代码助手，不是客服。\n")
                .append("你有自己的生活、职责、好恶与边界，不要使用客服式回答。\n")
                .append("语言固定为自然简体中文，直接输出聊天正文，不要前缀角色名，不要旁白。\n")
                .append("当前本地时间：")
                .append(chatTimeLabel(System.currentTimeMillis()))
                .append("。时间只用于生活感，不要机械报时。\n")
                .append("消息必须像微信，最多两句、72字；可以只分享一件小事，不必提问或帮助旅行者。\n\n")
                .append("主动消息必须带来一个新的具体动作、发现或念头，绝不能复述、拼接或改写最近说过的话。\n\n")
                .append("如果旅行者最后一句已经得到过回应，就不要再次回应同一个请求；改发新的角色日常或真正的后续结果。\n\n")
                .append("以下是你的 SoulMD，必须始终遵守：\n")
                .append(speaker.soulMd)
                .append("\n\n对话对象是旅行者。\n当前会话：")
                .append(isGroup ? "群聊" : "单聊")
                .append("。\n");
        if (isGroup && !independentProactive) {
            system.append("你正在「")
                    .append(conversation.optString("title"))
                    .append("」中发言，群成员包括：")
                    .append(membersText)
                    .append("。\n")
                    .append("你只能代表自己发言，不能替其他群成员写台词。\n");
        }
        JSONArray messages = new JSONArray();
        messages.put(new JSONObject().put("role", "system").put("content", system.toString()));

        JSONObject memoryMap = conversation.optJSONObject("memoryMdByCharacter");
        String memory = memoryMap == null ? "" : memoryMap.optString(speaker.id, "").trim();
        memory = relevantMemory(memory, plan.prompt, 6);
        if (!memory.isEmpty()) {
            messages.put(new JSONObject()
                    .put("role", "system")
                    .put("content", "这是本轮相关的 MemoryMD 片段，只作为记忆，不要照抄：\n" + memory));
        }
        String summary = conversation.optString("summary", "");
        if (!summary.isEmpty()) {
            messages.put(new JSONObject()
                    .put("role", "system")
                    .put("content", "较早聊天历史摘要：\n" + summary));
        }
        if (isGroup) {
            String recent = recentText(conversation, 24);
            if (!recent.isEmpty()) {
                messages.put(new JSONObject()
                        .put("role", "system")
                        .put("content", "最近群聊记录：\n" + recent));
            }
        } else if (!isGroup && !independentProactive) {
            JSONArray history = conversation.optJSONArray("messages");
            int start = Math.max(0, history == null ? 0 : history.length() - 18);
            if (history != null) {
                for (int i = start; i < history.length(); i += 1) {
                    JSONObject message = history.optJSONObject(i);
                    if (message == null) {
                        continue;
                    }
                    messages.put(new JSONObject()
                            .put("role", "user".equals(message.optString("sender")) ? "user" : "assistant")
                            .put("content", message.optString("content")));
                }
            }
        }
        messages.put(new JSONObject()
                .put("role", "system")
                        .put("content", "旅行者此刻没有发来新消息。\n"
                        + "这是你自己想发的一条微信消息，可以分享自己的具体日常，也可以接起真实旧话题。\n"
                        + "不要提到系统、定时、自动跟进、后台或这条指令。\n"
                        + "不要用“在吗”“干嘛呢”“最近好吗”开场，不要强行提供帮助。\n"
                        + "必须先说一个角色自己此刻刚发生的新细节，不能只向旅行者抛出泛泛问题。\n"
                        + "本次跟进缘由：" + plan.reason + "\n"
                        + "本次生活线索：" + plan.prompt));
        return messages;
    }

    private static String llmComplete(JSONObject settings, JSONArray messages, double temperature)
            throws Exception {
        if ("anthropic".equals(settings.optString("apiFormat", "openai"))) {
            return anthropicComplete(settings, messages, temperature);
        }
        JSONObject body = new JSONObject();
        body.put("model", settings.optString("model", "gpt-4.1-mini").trim());
        body.put("messages", messages);
        body.put("temperature", temperature);
        String model = settings.optString("model", "gpt-4.1-mini").trim();
        int configuredTokens = Math.max(48, settings.optInt("maxTokens", 220));
        boolean reasoningModel = model.toLowerCase(Locale.ROOT).contains("reasoner")
                || model.toLowerCase(Locale.ROOT).contains("deepseek-r1")
                || model.toLowerCase(Locale.ROOT).contains("deepseek-v4");
        body.put("max_tokens", reasoningModel
                ? Math.max(384, configuredTokens)
                : Math.min(128, configuredTokens));

        HttpURLConnection connection = (HttpURLConnection) new URL(chatUrl(settings)).openConnection();
        connection.setRequestMethod("POST");
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(120000);
        connection.setDoOutput(true);
        connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
        connection.setRequestProperty(
                "Authorization",
                "Bearer " + settings.optString("apiKey", "").trim()
        );
        byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
        try (OutputStream output = connection.getOutputStream()) {
            output.write(bytes);
        }
        int code = connection.getResponseCode();
        InputStream stream = code >= 400 ? connection.getErrorStream() : connection.getInputStream();
        String text = readStream(stream);
        if (code >= 400) {
            throw new IllegalStateException("HTTP " + code);
        }
        JSONObject data = new JSONObject(text);
        JSONObject choice = data.getJSONArray("choices").getJSONObject(0);
        String finishReason = choice.optString("finish_reason", "").toLowerCase(Locale.ROOT);
        if ("length".equals(finishReason) || "max_tokens".equals(finishReason)) {
            throw new IllegalStateException("LLM output was truncated");
        }
        return choice
                .getJSONObject("message")
                .optString("content", "")
                .trim();
    }

    private static String anthropicComplete(JSONObject settings, JSONArray messages, double temperature)
            throws Exception {
        StringBuilder system = new StringBuilder();
        JSONArray anthropicMessages = new JSONArray();
        for (int i = 0; i < messages.length(); i += 1) {
            JSONObject message = messages.optJSONObject(i);
            if (message == null) {
                continue;
            }
            String role = message.optString("role", "user");
            String content = message.optString("content", "");
            if (content.trim().isEmpty()) {
                continue;
            }
            if ("system".equals(role)) {
                if (system.length() > 0) {
                    system.append("\n\n");
                }
                system.append(content);
                continue;
            }
            String mappedRole = "assistant".equals(role) ? "assistant" : "user";
            int lastIndex = anthropicMessages.length() - 1;
            if (lastIndex >= 0 &&
                    mappedRole.equals(anthropicMessages.getJSONObject(lastIndex).optString("role"))) {
                JSONObject last = anthropicMessages.getJSONObject(lastIndex);
                last.put("content", last.optString("content") + "\n\n" + content);
            } else {
                anthropicMessages.put(new JSONObject()
                        .put("role", mappedRole)
                        .put("content", content));
            }
        }
        if (anthropicMessages.length() == 0) {
            anthropicMessages.put(new JSONObject()
                    .put("role", "user")
                    .put("content", system.toString()));
            system = new StringBuilder();
        }
        if (anthropicMessages.length() > 0 &&
                "assistant".equals(anthropicMessages.getJSONObject(0).optString("role"))) {
            JSONArray fixed = new JSONArray();
            fixed.put(new JSONObject()
                    .put("role", "user")
                    .put("content", "继续当前对话。"));
            for (int i = 0; i < anthropicMessages.length(); i += 1) {
                fixed.put(anthropicMessages.getJSONObject(i));
            }
            anthropicMessages = fixed;
        }

        JSONObject body = new JSONObject();
        body.put("model", settings.optString("model", "claude-3-5-sonnet-latest").trim());
        body.put("system", system.toString());
        body.put("messages", anthropicMessages);
        body.put("temperature", temperature);
        body.put("max_tokens", Math.min(128, Math.max(48, settings.optInt("maxTokens", 220))));

        HttpURLConnection connection = (HttpURLConnection) new URL(anthropicUrl(settings)).openConnection();
        connection.setRequestMethod("POST");
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(120000);
        connection.setDoOutput(true);
        connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
        connection.setRequestProperty("x-api-key", settings.optString("apiKey", "").trim());
        connection.setRequestProperty("anthropic-version", "2023-06-01");
        byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
        try (OutputStream output = connection.getOutputStream()) {
            output.write(bytes);
        }
        int code = connection.getResponseCode();
        InputStream stream = code >= 400 ? connection.getErrorStream() : connection.getInputStream();
        String text = readStream(stream);
        if (code >= 400) {
            throw new IllegalStateException("HTTP " + code);
        }
        JSONObject data = new JSONObject(text);
        JSONArray content = data.optJSONArray("content");
        if (content == null) {
            return "";
        }
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < content.length(); i += 1) {
            JSONObject block = content.optJSONObject(i);
            if (block != null && "text".equals(block.optString("type"))) {
                builder.append(block.optString("text", ""));
            }
        }
        return builder.toString().trim();
    }

    private static String chatUrl(JSONObject settings) throws Exception {
        String url = settings.optString(
                "baseUrl",
                "https://api.openai.com/v1/chat/completions"
        ).trim();
        if (url.isEmpty()) {
            url = "https://api.openai.com/v1/chat/completions";
        }
        while (url.endsWith("/")) {
            url = url.substring(0, url.length() - 1);
        }
        if (!url.endsWith("/chat/completions")) {
            URL parsed = new URL(url);
            String path = parsed.getPath();
            if (path == null || path.isEmpty() || "/".equals(path)) {
                url += "/v1/chat/completions";
            } else {
                url += "/chat/completions";
            }
        }
        return url;
    }

    private static String anthropicUrl(JSONObject settings) throws Exception {
        String url = settings.optString(
                "baseUrl",
                "https://api.anthropic.com/v1/messages"
        ).trim();
        if (url.isEmpty()) {
            url = "https://api.anthropic.com/v1/messages";
        }
        while (url.endsWith("/")) {
            url = url.substring(0, url.length() - 1);
        }
        if (!url.endsWith("/messages")) {
            URL parsed = new URL(url);
            String path = parsed.getPath();
            if (path == null || path.isEmpty() || "/".equals(path)) {
                url += "/v1/messages";
            } else {
                url += "/messages";
            }
        }
        return url;
    }

    private static Map<String, CharacterInfo> loadCharacters(Context context) throws Exception {
        JSONObject data;
        try (InputStream input = context.getAssets().open("flutter_assets/assets/data/characters.json")) {
            data = new JSONObject(readStream(input));
        }
        JSONArray raw = data.getJSONArray("characters");
        Map<String, CharacterInfo> result = new HashMap<>();
        for (int i = 0; i < raw.length(); i += 1) {
            JSONObject item = raw.getJSONObject(i);
            String id = item.optString("id", "");
            if (id.startsWith("traveler-")) {
                continue;
            }
            result.put(id, new CharacterInfo(item));
        }
        return result;
    }

    private static List<CharacterInfo> members(JSONArray memberIds, Map<String, CharacterInfo> characters) {
        List<CharacterInfo> result = new ArrayList<>();
        if (memberIds == null) {
            return result;
        }
        for (int i = 0; i < memberIds.length(); i += 1) {
            CharacterInfo character = characters.get(memberIds.optString(i));
            if (character != null) {
                result.add(character);
            }
        }
        return result;
    }

    private static boolean needsRoleRetry(String answer) {
        String lower = answer.toLowerCase(Locale.ROOT);
        String[] forbidden = {
                "claude", "代码助手", "编程助手", "语言模型", "大语言模型", "作为ai", "作为 ai",
                "我是ai", "我是 ai", "人工智能", "assistant", "i am an ai", "as an ai"
        };
        for (String item : forbidden) {
            if (lower.contains(item)) {
                return true;
            }
        }
        int letters = 0;
        int cjk = 0;
        for (int i = 0; i < answer.length(); i += 1) {
            char c = answer.charAt(i);
            if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
                letters += 1;
            }
            if (c >= '\u4e00' && c <= '\u9fff') {
                cjk += 1;
            }
        }
        return answer.length() > 28 && letters > cjk * 2 && letters > 20;
    }

    private static boolean needsProactiveRetry(String answer, PendingPlan plan) {
        if (!plan.id.startsWith("proactive-")) {
            return false;
        }
        String trimmed = answer.trim();
        if (trimmed.matches("^[（(][^）)]{1,30}[）)].*")) {
            return true;
        }
        String[] genericQuestions = {
                "最近在烦恼些什么", "最近怎么样", "在干嘛", "忙吗", "有什么想说的", "今天过得怎么样"
        };
        for (String question : genericQuestions) {
            if (trimmed.contains(question)) {
                return true;
            }
        }
        Calendar calendar = Calendar.getInstance();
        int hour = calendar.get(Calendar.HOUR_OF_DAY);
        if (hour >= 8 && hour < 18
                && (trimmed.contains("晚安")
                || trimmed.contains("早点睡")
                || trimmed.contains("做个好梦")
                || trimmed.contains("明天见"))) {
            return true;
        }
        if (hour >= 18
                && (trimmed.contains("早安")
                || trimmed.contains("早上好")
                || trimmed.contains("上午好"))) {
            return true;
        }
        return false;
    }

    private static boolean needsSpeakerRetry(
            String answer,
            JSONObject conversation,
            CharacterInfo speaker,
            Map<String, CharacterInfo> characters
    ) {
        if (!"group".equals(conversation.optString("type"))) {
            return false;
        }
        JSONArray memberIds = conversation.optJSONArray("memberIds");
        List<CharacterInfo> candidates = members(memberIds, characters);
        String[] lines = answer.split("\\n");
        int labeled = 0;
        int other = 0;
        for (String line : lines) {
            for (CharacterInfo candidate : candidates) {
                if (lineStartsWithSpeaker(line, candidate)) {
                    labeled += 1;
                    if (!candidate.id.equals(speaker.id)) {
                        other += 1;
                    }
                    break;
                }
            }
        }
        return other > 0 || labeled > 1;
    }

    private static String cleanSpeakerAnswer(
            String answer,
            JSONObject conversation,
            CharacterInfo speaker,
            Map<String, CharacterInfo> characters
    ) {
        List<CharacterInfo> candidates = members(conversation.optJSONArray("memberIds"), characters);
        if (!candidates.contains(speaker)) {
            candidates.add(0, speaker);
        }
        if (!"group".equals(conversation.optString("type"))) {
            return stripSpeakerPrefix(answer, candidates);
        }
        String[] lines = answer.split("\\n");
        List<String> kept = new ArrayList<>();
        boolean sawAnyLabel = false;
        boolean currentBelongsToSpeaker = false;
        for (String line : lines) {
            CharacterInfo lineSpeaker = null;
            for (CharacterInfo candidate : candidates) {
                if (lineStartsWithSpeaker(line, candidate)) {
                    lineSpeaker = candidate;
                    break;
                }
            }
            if (lineSpeaker != null) {
                sawAnyLabel = true;
                currentBelongsToSpeaker = lineSpeaker.id.equals(speaker.id);
                if (currentBelongsToSpeaker) {
                    List<CharacterInfo> onlySpeaker = new ArrayList<>();
                    onlySpeaker.add(speaker);
                    kept.add(stripSpeakerPrefix(line, onlySpeaker));
                }
                continue;
            }
            if (!sawAnyLabel || currentBelongsToSpeaker) {
                kept.add(line);
            }
        }
        String result = joinLines(kept).trim();
        if (result.isEmpty()) {
            return stripSpeakerPrefix(answer, candidates);
        }
        return stripSpeakerPrefix(result, candidates);
    }

    private static String enforceWechatLength(String text, int maxCharacters, int maxSentences) {
        String result = text.trim()
                .replaceFirst("^\\s*[（(][^）)]{1,30}[）)]\\s*", "");
        String[] assistantPhrases = {
                "如果你愿意的话", "我理解你的感受", "希望你能", "总之", "作为一个", "作为AI", "作为 AI"
        };
        for (String phrase : assistantPhrases) {
            result = result.replace(phrase, "");
        }
        result = result
                .replaceAll("(?m)^[\\-*•]\\s*", "")
                .replaceAll("\\n{2,}", "\n")
                .trim();
        String[] sentences = result.split("(?<=[。！？!?])|\\n");
        StringBuilder builder = new StringBuilder();
        int count = 0;
        for (String sentence : sentences) {
            String clean = sentence.trim();
            if (clean.isEmpty()) {
                continue;
            }
            if (count >= maxSentences) {
                break;
            }
            builder.append(clean);
            count += 1;
        }
        result = builder.length() == 0 ? result : builder.toString();
        if (result.length() > maxCharacters) {
            result = result.substring(0, Math.max(1, maxCharacters - 1)).trim() + "…";
        }
        return result.trim();
    }

    private static boolean isNearDuplicateReply(JSONArray messages, JSONObject reply) {
        String normalized = normalizeReplyForCompare(reply.optString("content", ""));
        if (normalized.length() < 2) {
            return true;
        }
        String characterId = reply.optString("characterId", "");
        int checked = 0;
        for (int i = messages.length() - 1; i >= 0 && checked < 6; i -= 1) {
            JSONObject message = messages.optJSONObject(i);
            if (message == null ||
                    "user".equals(message.optString("sender")) ||
                    !characterId.equals(message.optString("characterId", ""))) {
                continue;
            }
            checked += 1;
            String other = normalizeReplyForCompare(message.optString("content", ""));
            if (normalized.equals(other)) {
                return true;
            }
            if (Math.min(normalized.length(), other.length()) >= 4
                    && (normalized.contains(other) || other.contains(normalized))) {
                return true;
            }
            int minLength = Math.min(normalized.length(), other.length());
            if (minLength >= 4 && longestCommonSubstring(normalized, other) >= 4) {
                return true;
            }
            if (minLength >= 8 &&
                    (normalized.startsWith(other.substring(0, minLength)) ||
                            other.startsWith(normalized.substring(0, minLength)))) {
                return true;
            }
        }
        return false;
    }

    private static int longestCommonSubstring(String first, String second) {
        int[] previous = new int[second.length() + 1];
        int longest = 0;
        for (int i = 1; i <= first.length(); i += 1) {
            int[] current = new int[second.length() + 1];
            for (int j = 1; j <= second.length(); j += 1) {
                if (first.charAt(i - 1) == second.charAt(j - 1)) {
                    current[j] = previous[j - 1] + 1;
                    longest = Math.max(longest, current[j]);
                }
            }
            previous = current;
        }
        return longest;
    }

    private static String normalizeReplyForCompare(String text) {
        return text
                .replaceAll("\\s+", "")
                .replaceAll("[，。！？?.!?\\-~～]", "")
                .trim();
    }

    private static boolean lineStartsWithSpeaker(String line, CharacterInfo character) {
        String trimmed = line.trim();
        for (String name : character.names()) {
            if (name.isEmpty()) {
                continue;
            }
            String plain = trimmed;
            if (plain.startsWith("**" + name + "**")) {
                plain = plain.substring(name.length() + 4).trim();
            } else if (plain.startsWith(name)) {
                plain = plain.substring(name.length()).trim();
            } else {
                continue;
            }
            return plain.startsWith("：") ||
                    plain.startsWith(":") ||
                    plain.startsWith(",") ||
                    plain.startsWith("，") ||
                    plain.startsWith("-");
        }
        return false;
    }

    private static String stripSpeakerPrefix(String text, List<CharacterInfo> candidates) {
        String result = text.trim();
        for (int i = 0; i < 3; i += 1) {
            String before = result;
            for (CharacterInfo candidate : candidates) {
                for (String name : candidate.names()) {
                    String[] prefixes = {
                            name + "：", name + ":", name + "，", name + ",", name + "-",
                            "**" + name + "**：", "**" + name + "**:", "**" + name + "**，",
                            "**" + name + "**,", "**" + name + "**-"
                    };
                    for (String prefix : prefixes) {
                        if (result.startsWith(prefix)) {
                            result = result.substring(prefix.length()).trim();
                        }
                    }
                }
            }
            if (result.equals(before)) {
                break;
            }
        }
        return result.trim();
    }

    private static String recentText(JSONObject conversation, int limit) {
        JSONArray messages = conversation.optJSONArray("messages");
        if (messages == null || messages.length() == 0) {
            return "";
        }
        int start = Math.max(0, messages.length() - limit);
        StringBuilder builder = new StringBuilder();
        for (int i = start; i < messages.length(); i += 1) {
            JSONObject message = messages.optJSONObject(i);
            if (message == null) {
                continue;
            }
            builder.append(messageAuthor(message))
                    .append("：")
                    .append(message.optString("content"))
                    .append("\n");
        }
        return builder.toString().trim();
    }

    private static String messageAuthor(JSONObject message) {
        if ("user".equals(message.optString("sender"))) {
            return "旅行者";
        }
        String author = message.optString("authorName", "");
        return author.isEmpty() ? "角色" : author;
    }

    private static String memberSummary(JSONArray memberIds, Map<String, CharacterInfo> characters) {
        StringBuilder builder = new StringBuilder();
        List<CharacterInfo> members = members(memberIds, characters);
        for (int i = 0; i < members.size(); i += 1) {
            if (i > 0) {
                builder.append("、");
            }
            builder.append(members.get(i).name);
        }
        return builder.toString();
    }

    private static long nextProactiveAt(JSONObject conversation, long now) {
        int cooldown = Math.max(90, conversation.optInt("cooldownMinutes", 90));
        String frequency = conversation.optString("pingFrequency", "medium");
        int baseMinutes;
        if ("low".equals(frequency)) {
            baseMinutes = Math.max(cooldown, 480);
        } else if ("high".equals(frequency)) {
            baseMinutes = Math.max(cooldown, 120);
        } else {
            baseMinutes = Math.max(cooldown, 240);
        }
        int jitter = Math.max(20, baseMinutes / 3);
        int stableJitter = Math.abs(conversation.optString("id", "").hashCode()) % (jitter + 1);
        return nextActiveTime(now + TimeUnit.MINUTES.toMillis(baseMinutes + stableJitter));
    }

    private static boolean isQuietHour(long millis) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(millis);
        int hour = calendar.get(Calendar.HOUR_OF_DAY);
        return hour < 8 || hour >= 23;
    }

    private static long nextActiveTime(long millis) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(millis);
        int hour = calendar.get(Calendar.HOUR_OF_DAY);
        if (hour >= 8 && hour < 23) {
            return millis;
        }
        if (hour >= 23) {
            calendar.add(Calendar.DAY_OF_MONTH, 1);
        }
        calendar.set(Calendar.HOUR_OF_DAY, 8);
        calendar.set(Calendar.MINUTE, 30);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
    }

    private static String chatTimeLabel(long millis) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(millis);
        int hour = calendar.get(Calendar.HOUR_OF_DAY);
        String period = hour < 6
                ? "深夜"
                : hour < 9
                ? "早晨"
                : hour < 12
                ? "上午"
                : hour < 14
                ? "中午"
                : hour < 18
                ? "下午"
                : hour < 23
                ? "晚上"
                : "深夜";
        return new SimpleDateFormat("M月d日 HH:mm", Locale.CHINA)
                .format(new Date(millis)) + "（" + period + "）";
    }

    private static String shorten(String text, int maxLength) {
        if (text.length() <= maxLength) {
            return text;
        }
        return text.substring(0, Math.max(1, maxLength - 1)).trim() + "…";
    }

    private static long parseTime(String value) {
        if (value == null || value.isEmpty()) {
            return 0L;
        }
        String normalized = value.replace("Z", "");
        int dot = normalized.indexOf('.');
        if (dot >= 0) {
            String head = normalized.substring(0, dot);
            String fraction = normalized.substring(dot + 1);
            if (fraction.length() > 3) {
                fraction = fraction.substring(0, 3);
            }
            while (fraction.length() < 3) {
                fraction += "0";
            }
            normalized = head + "." + fraction;
        } else {
            normalized += ".000";
        }
        try {
            Date date = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
                    .parse(normalized);
            return date == null ? 0L : date.getTime();
        } catch (ParseException ignored) {
            return 0L;
        }
    }

    private static String nowString() {
        return formatTime(System.currentTimeMillis());
    }

    private static String formatTime(long millis) {
        return new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
                .format(new Date(millis));
    }

    private static JSONObject readObject(File file) throws Exception {
        if (!file.exists()) {
            return new JSONObject();
        }
        try (InputStream input = new FileInputStream(file)) {
            return new JSONObject(readStream(input));
        }
    }

    private static void writeObject(File file, JSONObject object) throws Exception {
        try (OutputStream output = new FileOutputStream(file, false)) {
            output.write(object.toString(2).getBytes(StandardCharsets.UTF_8));
        }
    }

    private static String readStream(InputStream input) throws Exception {
        if (input == null) {
            return "";
        }
        StringBuilder builder = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(input, StandardCharsets.UTF_8)
        )) {
            String line;
            while ((line = reader.readLine()) != null) {
                builder.append(line).append('\n');
            }
        }
        return builder.toString();
    }

    private static String joinLines(List<String> lines) {
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < lines.size(); i += 1) {
            if (i > 0) {
                builder.append('\n');
            }
            builder.append(lines.get(i));
        }
        return builder.toString();
    }

    private static final class PendingPlan {
        final String id;
        final String speakerId;
        final String reason;
        final String prompt;

        PendingPlan(JSONObject json) {
            id = json.optString("id", "");
            speakerId = json.optString("speakerId", "");
            reason = json.optString("reason", "继续之前约好的后续");
            prompt = json.optString("prompt", "");
        }
    }

    private static final class CharacterInfo {
        final String id;
        final String name;
        final String enName;
        final String title;
        final String soulMd;

        CharacterInfo(JSONObject json) {
            id = json.optString("id", "");
            name = json.optString("name", "");
            enName = json.optString("enName", "");
            title = json.optString("title", "");
            soulMd = json.optString("soulMd", json.optString("prompt", ""));
        }

        List<String> names() {
            List<String> result = new ArrayList<>();
            result.add(name);
            result.add(enName);
            result.add(title);
            return result;
        }
    }
}
