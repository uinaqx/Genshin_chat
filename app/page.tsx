import type { Metadata } from "next";
import { ArrowRight, LockKeyhole, MessageCircleMore } from "lucide-react";
import { LoginForm } from "./login-form";
import { getViewer } from "./lib/viewer";

export const metadata: Metadata = {
  title: "登录 | 提瓦特微信",
  description: "登录提瓦特微信，每个账号拥有独立聊天记录。",
};

export const dynamic = "force-dynamic";

const portraitUrls = [
  "https://genshin.jmp.blue/characters/nahida/icon-big",
  "https://genshin.jmp.blue/characters/furina/icon-big",
  "https://genshin.jmp.blue/characters/zhongli/icon-big",
  "https://genshin.jmp.blue/characters/hu-tao/icon-big",
  "https://genshin.jmp.blue/characters/venti/icon-big",
];

export default async function Home() {
  const viewer = await getViewer();
  return (
    <main className="login-page">
      <div className="login-portrait-field" aria-hidden="true">
        {portraitUrls.map((url, index) => (
          <img key={url} src={url} alt="" className={`ambient-avatar ambient-${index + 1}`} />
        ))}
      </div>
      <section className="login-sheet" aria-labelledby="login-title">
        <div className="brand-mark">
          <MessageCircleMore aria-hidden="true" size={26} strokeWidth={1.8} />
        </div>
        <p className="login-eyebrow">TEYVAT MESSAGES</p>
        <h1 id="login-title">提瓦特微信</h1>
        <p className="login-copy">
          那些熟悉的人，正在提瓦特的另一端等你回信。
        </p>
        {viewer ? (
          <a className="primary-action" href="/chat">
            <span>进入聊天</span>
            <ArrowRight aria-hidden="true" size={18} />
          </a>
        ) : (
          <LoginForm />
        )}
        <div className="privacy-note">
          <LockKeyhole aria-hidden="true" size={15} />
          <span>密码加密保存，聊天记录仅对当前账号可见</span>
        </div>
      </section>
      <p className="fan-note">非官方粉丝作品 · 角色版权归原权利方所有</p>
    </main>
  );
}
