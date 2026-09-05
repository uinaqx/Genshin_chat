package com.local.genshin.genshin_chat;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.HashSet;
import java.util.Iterator;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

final class TeyvatDatabase extends SQLiteOpenHelper {
    private static final String DATABASE_NAME = "teyvat_chat_v3.db";
    private static final int DATABASE_VERSION = 1;
    private static volatile TeyvatDatabase instance;

    static TeyvatDatabase get(Context context) {
        if (instance == null) {
            synchronized (TeyvatDatabase.class) {
                if (instance == null) {
                    instance = new TeyvatDatabase(context.getApplicationContext());
                }
            }
        }
        return instance;
    }

    private TeyvatDatabase(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
        setWriteAheadLoggingEnabled(true);
    }

    @Override
    public void onConfigure(SQLiteDatabase db) {
        super.onConfigure(db);
        db.setForeignKeyConstraintsEnabled(true);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE conversations ("
                + "id TEXT PRIMARY KEY NOT NULL,"
                + "metadata_json TEXT NOT NULL,"
                + "updated_at INTEGER NOT NULL)");
        db.execSQL("CREATE TABLE messages ("
                + "conversation_id TEXT NOT NULL,"
                + "position INTEGER NOT NULL,"
                + "payload_json TEXT NOT NULL,"
                + "PRIMARY KEY (conversation_id, position),"
                + "FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE)");
        db.execSQL("CREATE TABLE character_memories ("
                + "conversation_id TEXT NOT NULL,"
                + "character_id TEXT NOT NULL,"
                + "memory_md TEXT NOT NULL,"
                + "PRIMARY KEY (conversation_id, character_id),"
                + "FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE)");
        db.execSQL("CREATE TABLE follow_ups ("
                + "conversation_id TEXT NOT NULL,"
                + "item_id TEXT NOT NULL,"
                + "position INTEGER NOT NULL,"
                + "payload_json TEXT NOT NULL,"
                + "PRIMARY KEY (conversation_id, item_id),"
                + "FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE)");
        db.execSQL("CREATE TABLE reply_queue ("
                + "conversation_id TEXT NOT NULL,"
                + "position INTEGER NOT NULL,"
                + "content TEXT NOT NULL,"
                + "PRIMARY KEY (conversation_id, position))");
        db.execSQL("CREATE INDEX messages_conversation_idx "
                + "ON messages(conversation_id, position)");
        db.execSQL("CREATE INDEX follow_ups_conversation_idx "
                + "ON follow_ups(conversation_id, position)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        throw new IllegalStateException("Unsupported database upgrade " + oldVersion + " -> " + newVersion);
    }

    synchronized JSONObject loadConversations() throws Exception {
        SQLiteDatabase db = getReadableDatabase();
        JSONArray items = new JSONArray();
        try (Cursor cursor = db.query(
                "conversations",
                new String[]{"id", "metadata_json"},
                null,
                null,
                null,
                null,
                "updated_at ASC"
        )) {
            while (cursor.moveToNext()) {
                String conversationId = cursor.getString(0);
                JSONObject conversation = new JSONObject(cursor.getString(1));
                conversation.put("messages", loadPayloadArray(
                        db,
                        "messages",
                        conversationId,
                        "payload_json"
                ));
                conversation.put("followUps", loadPayloadArray(
                        db,
                        "follow_ups",
                        conversationId,
                        "payload_json"
                ));
                conversation.put("memoryMdByCharacter", loadMemories(db, conversationId));
                items.put(conversation);
            }
        }
        return new JSONObject().put("items", items);
    }

    synchronized void saveConversations(JSONObject state) throws Exception {
        SQLiteDatabase db = getWritableDatabase();
        JSONArray items = state.optJSONArray("items");
        if (items == null) {
            items = new JSONArray();
        }
        db.beginTransaction();
        try {
            Set<String> retainedIds = new HashSet<>();
            for (int index = 0; index < items.length(); index += 1) {
                JSONObject conversation = items.optJSONObject(index);
                if (conversation == null) {
                    continue;
                }
                String id = conversation.optString("id", "");
                if (id.isEmpty()) {
                    continue;
                }
                retainedIds.add(id);
                saveConversation(db, id, conversation);
            }
            deleteMissingConversations(db, retainedIds);
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    synchronized JSONObject loadReplyQueue() throws Exception {
        JSONObject pending = new JSONObject();
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query(
                "reply_queue",
                new String[]{"conversation_id", "content"},
                null,
                null,
                null,
                null,
                "conversation_id ASC, position ASC"
        )) {
            while (cursor.moveToNext()) {
                String conversationId = cursor.getString(0);
                JSONArray items = pending.optJSONArray(conversationId);
                if (items == null) {
                    items = new JSONArray();
                    pending.put(conversationId, items);
                }
                items.put(cursor.getString(1));
            }
        }
        return new JSONObject().put("pending", pending);
    }

    synchronized void saveReplyQueue(JSONObject state) throws Exception {
        SQLiteDatabase db = getWritableDatabase();
        JSONObject pending = state.optJSONObject("pending");
        db.beginTransaction();
        try {
            db.delete("reply_queue", null, null);
            if (pending != null) {
                Iterator<String> keys = pending.keys();
                while (keys.hasNext()) {
                    String conversationId = keys.next();
                    JSONArray messages = pending.optJSONArray(conversationId);
                    if (messages == null) {
                        continue;
                    }
                    for (int position = 0; position < messages.length(); position += 1) {
                        String content = messages.optString(position, "").trim();
                        if (content.isEmpty()) {
                            continue;
                        }
                        ContentValues values = new ContentValues();
                        values.put("conversation_id", conversationId);
                        values.put("position", position);
                        values.put("content", content);
                        db.insertOrThrow("reply_queue", null, values);
                    }
                }
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    private static void saveConversation(
            SQLiteDatabase db,
            String id,
            JSONObject source
    ) throws Exception {
        JSONObject metadata = new JSONObject(source.toString());
        JSONArray messages = metadata.optJSONArray("messages");
        JSONArray followUps = metadata.optJSONArray("followUps");
        JSONObject memories = metadata.optJSONObject("memoryMdByCharacter");
        metadata.remove("messages");
        metadata.remove("followUps");
        metadata.remove("memoryMdByCharacter");

        ContentValues values = new ContentValues();
        values.put("id", id);
        values.put("metadata_json", metadata.toString());
        values.put("updated_at", System.currentTimeMillis());
        db.insertWithOnConflict(
                "conversations",
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE
        );

        db.delete("messages", "conversation_id = ?", new String[]{id});
        savePayloadArray(db, "messages", id, messages, false);
        db.delete("follow_ups", "conversation_id = ?", new String[]{id});
        savePayloadArray(db, "follow_ups", id, followUps, true);
        db.delete("character_memories", "conversation_id = ?", new String[]{id});
        if (memories != null) {
            Iterator<String> characterIds = memories.keys();
            while (characterIds.hasNext()) {
                String characterId = characterIds.next();
                ContentValues memoryValues = new ContentValues();
                memoryValues.put("conversation_id", id);
                memoryValues.put("character_id", characterId);
                memoryValues.put("memory_md", memories.optString(characterId, ""));
                db.insertOrThrow("character_memories", null, memoryValues);
            }
        }
    }

    private static void savePayloadArray(
            SQLiteDatabase db,
            String table,
            String conversationId,
            JSONArray items,
            boolean includeItemId
    ) throws Exception {
        if (items == null) {
            return;
        }
        for (int position = 0; position < items.length(); position += 1) {
            JSONObject item = items.optJSONObject(position);
            if (item == null) {
                continue;
            }
            ContentValues values = new ContentValues();
            values.put("conversation_id", conversationId);
            values.put("position", position);
            values.put("payload_json", item.toString());
            if (includeItemId) {
                values.put("item_id", item.optString("id", "follow-up-" + position));
            }
            db.insertOrThrow(table, null, values);
        }
    }

    private static JSONArray loadPayloadArray(
            SQLiteDatabase db,
            String table,
            String conversationId,
            String payloadColumn
    ) throws Exception {
        JSONArray result = new JSONArray();
        try (Cursor cursor = db.query(
                table,
                new String[]{payloadColumn},
                "conversation_id = ?",
                new String[]{conversationId},
                null,
                null,
                "position ASC"
        )) {
            while (cursor.moveToNext()) {
                result.put(new JSONObject(cursor.getString(0)));
            }
        }
        return result;
    }

    private static JSONObject loadMemories(SQLiteDatabase db, String conversationId) {
        JSONObject result = new JSONObject();
        try (Cursor cursor = db.query(
                "character_memories",
                new String[]{"character_id", "memory_md"},
                "conversation_id = ?",
                new String[]{conversationId},
                null,
                null,
                "character_id ASC"
        )) {
            while (cursor.moveToNext()) {
                result.put(cursor.getString(0), cursor.getString(1));
            }
        } catch (Exception ignored) {
        }
        return result;
    }

    private static void deleteMissingConversations(SQLiteDatabase db, Set<String> retainedIds) {
        List<String> removedIds = new ArrayList<>();
        try (Cursor cursor = db.query(
                "conversations",
                new String[]{"id"},
                null,
                null,
                null,
                null,
                null
        )) {
            while (cursor.moveToNext()) {
                String id = cursor.getString(0);
                if (!retainedIds.contains(id)) {
                    removedIds.add(id);
                }
            }
        }
        for (String id : removedIds) {
            db.delete("conversations", "id = ?", new String[]{id});
        }
    }
}
