package com.local.genshin.genshin_chat;

import android.Manifest;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.pm.PackageInfoCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        LiveChatWorker.sync(this);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "genshin_chat/files")
                .setMethodCallHandler((call, result) -> {
                    if ("getFilesDir".equals(call.method)) {
                        result.success(getFilesDir().getAbsolutePath());
                    } else if ("getAppVersion".equals(call.method)) {
                        try {
                            PackageInfo info = getPackageManager().getPackageInfo(getPackageName(), 0);
                            long buildNumber = PackageInfoCompat.getLongVersionCode(info);
                            result.success(info.versionName + "+" + buildNumber);
                        } catch (PackageManager.NameNotFoundException error) {
                            result.error("VERSION_UNAVAILABLE", "无法读取应用版本", null);
                        }
                    } else if ("saveApiKey".equals(call.method)) {
                        String apiKey = call.arguments instanceof String ? (String) call.arguments : "";
                        try {
                            SecureApiKeyStore.save(this, apiKey);
                            result.success(null);
                        } catch (Exception error) {
                            result.error("SECURE_STORAGE_WRITE_FAILED", "无法安全保存 API Key", null);
                        }
                    } else if ("loadApiKey".equals(call.method)) {
                        try {
                            result.success(SecureApiKeyStore.load(this));
                        } catch (Exception error) {
                            result.error("SECURE_STORAGE_READ_FAILED", "无法读取加密 API Key", null);
                        }
                    } else if ("loadConversations".equals(call.method)) {
                        try {
                            result.success(TeyvatDatabase.get(this).loadConversations().toString());
                        } catch (Exception error) {
                            result.error("DATABASE_READ_FAILED", "无法读取本地聊天数据库", null);
                        }
                    } else if ("saveConversations".equals(call.method)) {
                        try {
                            String payload = call.arguments instanceof String
                                    ? (String) call.arguments
                                    : "{\"items\":[]}";
                            TeyvatDatabase.get(this).saveConversations(new org.json.JSONObject(payload));
                            result.success(null);
                        } catch (Exception error) {
                            result.error("DATABASE_WRITE_FAILED", "无法写入本地聊天数据库", null);
                        }
                    } else if ("loadReplyQueue".equals(call.method)) {
                        try {
                            result.success(TeyvatDatabase.get(this).loadReplyQueue().toString());
                        } catch (Exception error) {
                            result.error("QUEUE_READ_FAILED", "无法读取待回复队列", null);
                        }
                    } else if ("saveReplyQueue".equals(call.method)) {
                        try {
                            String payload = call.arguments instanceof String
                                    ? (String) call.arguments
                                    : "{\"pending\":{}}";
                            TeyvatDatabase.get(this).saveReplyQueue(new org.json.JSONObject(payload));
                            result.success(null);
                        } catch (Exception error) {
                            result.error("QUEUE_WRITE_FAILED", "无法写入待回复队列", null);
                        }
                    } else if ("requestNotificationPermission".equals(call.method)) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                                && ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.POST_NOTIFICATIONS
                        ) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(
                                    this,
                                    new String[]{Manifest.permission.POST_NOTIFICATIONS},
                                    901
                            );
                        }
                        result.success(null);
                    } else if ("syncLiveWorker".equals(call.method)) {
                        LiveChatWorker.sync(this);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });
    }
}
