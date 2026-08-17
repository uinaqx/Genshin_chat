import { randomBytes } from "node:crypto";
import { cookies } from "next/headers";
import { runtimeEnv } from "./storage";
import { SESSION_COOKIE, hashSessionToken } from "./viewer";

const SESSION_SECONDS = 60 * 60 * 24 * 30;

export function normalizeEmail(value: unknown) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

export async function createSession(userId: string) {
  const token = randomBytes(32).toString("base64url");
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_SECONDS * 1000);
  const { DB } = runtimeEnv();
  await DB.prepare(
    `INSERT INTO sessions(token_hash, user_id, created_at, expires_at)
     VALUES (?, ?, ?, ?)`,
  )
    .bind(hashSessionToken(token), userId, now.toISOString(), expiresAt.toISOString())
    .run();
  (await cookies()).set(SESSION_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: SESSION_SECONDS,
  });
}

export async function destroySession() {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;
  if (token) {
    const { DB } = runtimeEnv();
    await DB.prepare("DELETE FROM sessions WHERE token_hash = ?")
      .bind(hashSessionToken(token))
      .run();
  }
  cookieStore.delete(SESSION_COOKIE);
}
