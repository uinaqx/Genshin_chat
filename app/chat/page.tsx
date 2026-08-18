import type { Metadata } from "next";
import { requireViewer } from "../lib/viewer";
import { ChatApp } from "./chat-app";

export const metadata: Metadata = {
  title: "聊天 | 提瓦特微信",
};

export const dynamic = "force-dynamic";

export default async function ChatPage() {
  const viewer = await requireViewer("/chat");
  return (
    <ChatApp
      user={{
        displayName: viewer.displayName,
        travelerGender: viewer.travelerGender,
      }}
    />
  );
}
