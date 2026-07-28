import { publicCharacters } from "../../lib/characters";
import { getViewer } from "../../lib/viewer";

export const dynamic = "force-dynamic";

export async function GET() {
  const viewer = await getViewer();
  if (!viewer) {
    return Response.json({ error: "请先登录" }, { status: 401 });
  }
  return Response.json({ characters: publicCharacters() });
}
