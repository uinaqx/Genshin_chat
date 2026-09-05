package com.local.genshin.genshin_chat;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

final class SecureApiKeyStore {
    private static final String KEYSTORE_PROVIDER = "AndroidKeyStore";
    private static final String KEY_ALIAS = "teyvat_api_key_v1";
    private static final String ENCRYPTED_PREFS = "teyvat_encrypted_secrets";
    private static final String LEGACY_PREFS = "teyvat_secure_settings";
    private static final String LEGACY_API_KEY = "api_key";
    private static final String CIPHERTEXT = "api_key_ciphertext";
    private static final String INITIALIZATION_VECTOR = "api_key_iv";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";

    private SecureApiKeyStore() {
    }

    static synchronized void save(Context context, String apiKey) throws Exception {
        SharedPreferences encrypted = encryptedPrefs(context);
        String normalized = apiKey == null ? "" : apiKey.trim();
        if (normalized.isEmpty()) {
            encrypted.edit().remove(CIPHERTEXT).remove(INITIALIZATION_VECTOR).commit();
            clearLegacy(context);
            return;
        }

        Cipher cipher = Cipher.getInstance(TRANSFORMATION);
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey());
        cipher.updateAAD(context.getPackageName().getBytes(StandardCharsets.UTF_8));
        byte[] ciphertext = cipher.doFinal(normalized.getBytes(StandardCharsets.UTF_8));
        boolean written = encrypted.edit()
                .putString(CIPHERTEXT, Base64.encodeToString(ciphertext, Base64.NO_WRAP))
                .putString(
                        INITIALIZATION_VECTOR,
                        Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP)
                )
                .commit();
        if (!written) {
            throw new IllegalStateException("无法写入加密凭据");
        }
        clearLegacy(context);
    }

    static synchronized String load(Context context) throws Exception {
        SharedPreferences encrypted = encryptedPrefs(context);
        String encodedCiphertext = encrypted.getString(CIPHERTEXT, "");
        String encodedIv = encrypted.getString(INITIALIZATION_VECTOR, "");
        if (encodedCiphertext == null || encodedCiphertext.isEmpty()
                || encodedIv == null || encodedIv.isEmpty()) {
            return migrateLegacy(context);
        }

        KeyStore keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER);
        keyStore.load(null);
        SecretKey key = (SecretKey) keyStore.getKey(KEY_ALIAS, null);
        if (key == null) {
            throw new IllegalStateException("加密密钥不可用，请重新填写 API Key");
        }

        Cipher cipher = Cipher.getInstance(TRANSFORMATION);
        cipher.init(
                Cipher.DECRYPT_MODE,
                key,
                new GCMParameterSpec(128, Base64.decode(encodedIv, Base64.NO_WRAP))
        );
        cipher.updateAAD(context.getPackageName().getBytes(StandardCharsets.UTF_8));
        byte[] plaintext = cipher.doFinal(
                Base64.decode(encodedCiphertext, Base64.NO_WRAP)
        );
        clearLegacy(context);
        return new String(plaintext, StandardCharsets.UTF_8);
    }

    private static String migrateLegacy(Context context) throws Exception {
        String legacy = context.getSharedPreferences(LEGACY_PREFS, Context.MODE_PRIVATE)
                .getString(LEGACY_API_KEY, "");
        if (legacy == null || legacy.trim().isEmpty()) {
            clearLegacy(context);
            return "";
        }
        save(context, legacy);
        return legacy.trim();
    }

    private static SecretKey getOrCreateKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER);
        keyStore.load(null);
        SecretKey existing = (SecretKey) keyStore.getKey(KEY_ALIAS, null);
        if (existing != null) {
            return existing;
        }

        KeyGenerator generator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                KEYSTORE_PROVIDER
        );
        generator.init(new KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT
        )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .setKeySize(256)
                .build());
        return generator.generateKey();
    }

    private static SharedPreferences encryptedPrefs(Context context) {
        return context.getSharedPreferences(ENCRYPTED_PREFS, Context.MODE_PRIVATE);
    }

    private static void clearLegacy(Context context) {
        context.getSharedPreferences(LEGACY_PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(LEGACY_API_KEY)
                .commit();
    }
}
