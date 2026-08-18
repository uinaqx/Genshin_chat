import { createHash } from "node:crypto";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ensureSchema, runtimeEnv } from "./storage";

export const SESSION_COOKIE = "teyvat_session";

export type Viewer = {
  displayName: string;
  email: string;
  fullName: string | null;
  travelerGender: "aether" | "lumine";
};

type ViewerRow = {
  email: string;
  traveler_gender: string;
};

export function hashSessionToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

export async function getViewer(): Promise<Viewer | null> {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  if (!token) return null;
  await ensureSchema();
  const { DB } = runtimeEnv();
  const viewer = await DB.prepare(
    `SELECT u.email, u.traveler_gender
     FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.token_hash = ? AND s.expires_at > ?`,
  )
    .bind(hashSessionToken(token), new Date().toISOString())
    .first<ViewerRow>();
  if (!viewer) return null;
  const travelerGender = viewer.traveler_gender === "lumine" ? "lumine" : "aether";
  return {
    displayName: "旅行者",
    email: viewer.email,
    fullName: "旅行者",
    travelerGender,
  };
}

export async function requireViewer(returnTo: string): Promise<Viewer> {
  const viewer = await getViewer();
  if (viewer) return viewer;
  redirect(`/?return_to=${encodeURIComponent(safeReturnPath(returnTo))}`);
}

function safeReturnPath(value: string) {
  return value.startsWith("/") && !value.startsWith("//") ? value : "/chat";
}
