import { compare } from "bcryptjs";
import { createSession, normalizeEmail } from "../../../lib/auth";
import { apiError, ensureSchema, runtimeEnv } from "../../../lib/storage";

type UserRow = { id: string; password_hash: string };

export async function POST(request: Request) {
  try {
    const payload = (await request.json()) as { email?: unknown; password?: unknown };
    const email = normalizeEmail(payload.email);
    const password = typeof payload.password === "string" ? payload.password : "";
    await ensureSchema();
    const { DB } = runtimeEnv();
    const user = await DB.prepare(
      "SELECT id, password_hash FROM users WHERE email = ?",
    )
      .bind(email)
      .first<UserRow>();
    if (!user || !(await compare(password, user.password_hash))) {
      return Response.json({ error: "邮箱或密码不正确" }, { status: 401 });
    }
    await createSession(user.id);
    return Response.json({ ok: true });
  } catch (error) {
    return apiError(error);
  }
}
