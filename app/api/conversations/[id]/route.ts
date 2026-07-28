import { apiError, ensureSchema, runtimeEnv } from "../../../lib/storage";
import { getViewer } from "../../../lib/viewer";

export const dynamic = "force-dynamic";

export async function DELETE(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const viewer = await getViewer();
  if (!viewer) {
    return Response.json({ error: "请先登录" }, { status: 401 });
  }
  try {
    await ensureSchema();
    const { id } = await context.params;
    const { DB } = runtimeEnv();
    await DB.batch([
      DB.prepare(
        "DELETE FROM messages WHERE owner_id = ? AND conversation_id = ?",
      ).bind(viewer.email, id),
      DB.prepare(
        "DELETE FROM conversations WHERE owner_id = ? AND id = ?",
      ).bind(viewer.email, id),
    ]);
    return Response.json({ ok: true });
  } catch (error) {
    return apiError(error);
  }
}
