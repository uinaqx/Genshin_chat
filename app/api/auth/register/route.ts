import { hash } from "bcryptjs";
import { createSession, normalizeEmail } from "../../../lib/auth";
import { apiError, ensureSchema, runtimeEnv } from "../../../lib/storage";

export async function POST(request: Request) {
  try {
    const payload = (await request.json()) as {
      email?: unknown;
      password?: unknown;
    };
    const email = normalizeEmail(payload.email);
    const password = typeof payload.password === "string" ? payload.password : "";
    if (!/^\S+@\S+\.\S+$/.test(email)) {
      return Response.json({ error: "请输入有效邮箱" }, { status: 400 });
    }
    if (password.length < 8 || password.length > 128) {
      return Response.json({ error: "密码至少需要 8 位" }, { status: 400 });
    }
    await ensureSchema();
    const { DB } = runtimeEnv();
    const existing = await DB.prepare("SELECT id FROM users WHERE email = ?")
      .bind(email)
      .first();
    if (existing) {
      return Response.json({ error: "这个邮箱已经注册" }, { status: 409 });
    }
    const id = crypto.randomUUID();
    await DB.prepare(
      `INSERT INTO users(id, email, display_name, password_hash, created_at)
       VALUES (?, ?, ?, ?, ?)`,
    )
      .bind(id, email, "旅行者", await hash(password, 12), new Date().toISOString())
      .run();
    await createSession(id);
    return Response.json({ ok: true }, { status: 201 });
  } catch (error) {
    return apiError(error);
  }
}
