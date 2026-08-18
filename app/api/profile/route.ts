import { apiError, ensureSchema, runtimeEnv } from "../../lib/storage";
import { getViewer } from "../../lib/viewer";

export const dynamic = "force-dynamic";

export async function PATCH(request: Request) {
  try {
    const viewer = await getViewer();
    if (!viewer) {
      return Response.json({ error: "请先登录" }, { status: 401 });
    }
    const payload = (await request.json()) as { travelerGender?: unknown };
    const travelerGender = payload.travelerGender;
    if (travelerGender !== "aether" && travelerGender !== "lumine") {
      return Response.json({ error: "旅行者选择不正确" }, { status: 400 });
    }
    await ensureSchema();
    const { DB } = runtimeEnv();
    await DB.prepare(
      "UPDATE users SET traveler_gender = ?, display_name = '旅行者' WHERE email = ?",
    )
      .bind(travelerGender, viewer.email)
      .run();
    return Response.json({ travelerGender });
  } catch (error) {
    return apiError(error);
  }
}
