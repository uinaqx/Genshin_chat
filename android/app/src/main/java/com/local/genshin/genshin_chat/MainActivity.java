package com.local.genshin.genshin_chat;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.NonNull;
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
                    } else if ("saveApiKey".equals(call.method)) {
                        String apiKey = call.arguments instanceof String ? (String) call.arguments : "";
                        securePrefs().edit().putString("api_key", apiKey).apply();
                        result.success(null);
                    } else if ("loadApiKey".equals(call.method)) {
                        result.success(securePrefs().getString("api_key", ""));
                    } else if ("syncLiveWorker".equals(call.method)) {
                        LiveChatWorker.sync(this);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private SharedPreferences securePrefs() {
        return getSharedPreferences("teyvat_secure_settings", Context.MODE_PRIVATE);
    }
}
