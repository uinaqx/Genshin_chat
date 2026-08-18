import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "gi.yatta.moe" },
      { protocol: "https", hostname: "genshin.jmp.blue" },
    ],
  },
};

export default nextConfig;
