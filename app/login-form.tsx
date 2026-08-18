"use client";

import { ArrowRight } from "lucide-react";
import { FormEvent, useState } from "react";

type Mode = "login" | "register";

export function LoginForm() {
  const [mode, setMode] = useState<Mode>("login");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError("");
    const data = new FormData(event.currentTarget);
    const response = await fetch(`/api/auth/${mode}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: data.get("email"),
        password: data.get("password"),
      }),
    }).catch(() => null);
    if (response?.ok) {
      window.location.assign("/chat");
      return;
    }
    const payload = response
      ? ((await response.json().catch(() => ({}))) as { error?: string })
      : {};
    setError(payload.error || "暂时无法登录，请稍后再试");
    setSubmitting(false);
  }

  return (
    <form className="auth-form" onSubmit={submit}>
      <div className="auth-segment" role="tablist" aria-label="账号操作">
        <button
          type="button"
          role="tab"
          aria-selected={mode === "login"}
          className={mode === "login" ? "active" : ""}
          onClick={() => {
            setMode("login");
            setError("");
          }}
        >
          登录
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={mode === "register"}
          className={mode === "register" ? "active" : ""}
          onClick={() => {
            setMode("register");
            setError("");
          }}
        >
          注册
        </button>
      </div>
      <label className="auth-field">
        <span>邮箱</span>
        <input name="email" type="email" autoComplete="email" required />
      </label>
      <label className="auth-field">
        <span>密码</span>
        <input
          name="password"
          type="password"
          autoComplete={mode === "login" ? "current-password" : "new-password"}
          minLength={8}
          maxLength={128}
          required
        />
      </label>
      {error && <p className="auth-error" role="alert">{error}</p>}
      <button className="primary-action auth-submit" type="submit" disabled={submitting}>
        <span>{submitting ? "请稍候" : mode === "login" ? "登录" : "创建账号"}</span>
        {!submitting && <ArrowRight aria-hidden="true" size={18} />}
      </button>
    </form>
  );
}
