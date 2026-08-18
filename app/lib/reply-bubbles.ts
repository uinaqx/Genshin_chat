const TERMINAL_PUNCTUATION = /[^。！？!?…\n]+(?:[。！？!?]+|…{2,}|$)/g;

export function splitReplyIntoBubbles(value: string): string[] {
  const source = value.replace(/\r/g, "").trim();
  if (!source) return [];

  const bubbles = source
    .split(/\n+/)
    .flatMap((paragraph) => paragraph.match(TERMINAL_PUNCTUATION) ?? [paragraph])
    .map((part) => part.trim())
    .filter(Boolean);

  if (bubbles.length <= 1) return bubbles;
  if (bubbles.length <= 8) return bubbles;
  return [...bubbles.slice(0, 7), bubbles.slice(7).join("")];
}
