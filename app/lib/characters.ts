import characterData from "../../data/characters.json";

export type CharacterRecord = {
  id: string;
  name: string;
  enName?: string;
  title?: string;
  vision?: string;
  weapon?: string;
  nation?: string;
  rarity?: number;
  description?: string;
  avatarUrl?: string;
  prompt?: string;
  soulMd?: string;
};

export type PublicCharacter = Pick<
  CharacterRecord,
  "id" | "name" | "title" | "vision" | "nation" | "description" | "avatarUrl"
>;

const characters = (characterData.characters as CharacterRecord[]).filter(
  (character) => !character.id.startsWith("traveler-"),
);
const byId = new Map(characters.map((character) => [character.id, character]));

export function allCharacters(): CharacterRecord[] {
  return characters;
}

export function publicCharacters(): PublicCharacter[] {
  return characters.map((character) => ({
    id: character.id,
    name: character.name,
    title: character.title,
    vision: character.vision,
    nation: character.nation,
    description: character.description,
    avatarUrl: character.avatarUrl,
  }));
}

export function characterById(id: string): CharacterRecord | null {
  return byId.get(id) ?? null;
}

export function validCharacterIds(ids: string[]): string[] {
  return [...new Set(ids)].filter((id) => byId.has(id));
}
