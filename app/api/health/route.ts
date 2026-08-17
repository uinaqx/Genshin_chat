import { ensureSchema, runtimeEnv } from "../../lib/storage";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    await ensureSchema();
    const { DB } = runtimeEnv();
    await DB.prepare("SELECT 1 AS ok").first();
    return Response.json({ status: "ok" });
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown error";
    console.error("[health] database unavailable:", message);
    return Response.json({ status: "unavailable" }, { status: 503 });
  }
}
