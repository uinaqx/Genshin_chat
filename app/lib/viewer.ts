import { headers } from "next/headers";
import { redirect } from "next/navigation";
import {
  chatGPTSignInPath,
  getChatGPTUser,
  type ChatGPTUser,
} from "../chatgpt-auth";

const previewUser: ChatGPTUser = {
  displayName: "旅行者",
  email: "preview@localhost",
  fullName: "旅行者",
};

export async function getViewer(): Promise<ChatGPTUser | null> {
  const user = await getChatGPTUser();
  if (user) return user;

  const requestHeaders = await headers();
  const host = requestHeaders.get("host") ?? "";
  if (host.startsWith("localhost") || host.startsWith("127.0.0.1")) {
    return previewUser;
  }
  return null;
}

export async function requireViewer(returnTo: string): Promise<ChatGPTUser> {
  const viewer = await getViewer();
  if (viewer) return viewer;
  redirect(chatGPTSignInPath(returnTo));
}
