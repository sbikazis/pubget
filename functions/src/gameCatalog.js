"use strict";

// Server-owned trivia catalog for Guess Character, Anime Chain, and
// Emoji Anime Guess. Titles and character names are factual identifiers
// only — no copyrighted artwork URLs.

const ANIME = Object.freeze([
  {
    id: "one_piece",
    title: "One Piece",
    studio: "Toei Animation",
    genres: ["adventure", "shonen"],
    characters: [
      { id: "luffy", name: "Monkey D. Luffy", clue: "Straw-hat captain who stretches like rubber and hunts the One Piece." },
      { id: "zoro", name: "Roronoa Zoro", clue: "Three-sword swordsman who often gets lost." },
      { id: "nami", name: "Nami", clue: "Navigator of the Straw Hats with a love of treasure maps and weather." },
    ],
    emojiClues: ["👒", "🏴‍☠️", "🍖"],
  },
  {
    id: "naruto",
    title: "Naruto",
    studio: "Pierrot",
    genres: ["action", "shonen"],
    characters: [
      { id: "naruto", name: "Naruto Uzumaki", clue: "Noisy orange-clad ninja who carries a nine-tailed fox." },
      { id: "sasuke", name: "Sasuke Uchiha", clue: "Last loyal Uchiha avenger with a Sharingan and a rival in the same village." },
      { id: "sakura", name: "Sakura Haruno", clue: "Medical ninja of Team 7 with devastating chakra-enhanced punches." },
    ],
    emojiClues: ["🍜", "🦊", "🍥"],
  },
  {
    id: "bleach",
    title: "Bleach",
    studio: "Pierrot",
    genres: ["action", "supernatural"],
    characters: [
      { id: "ichigo", name: "Ichigo Kurosaki", clue: "Substitute Soul Reaper with orange hair and a massive Zanpakuto." },
      { id: "rukia", name: "Rukia Kuchiki", clue: "Soul Reaper who first lent her powers to a human teenager." },
    ],
    emojiClues: ["⚔️", "👻", "🧡"],
  },
  {
    id: "attack_on_titan",
    title: "Attack on Titan",
    studio: "Wit Studio",
    genres: ["action", "drama"],
    characters: [
      { id: "eren", name: "Eren Yeager", clue: "Survey Corps soldier whose rage against Titans hides a Founding secret." },
      { id: "mikasa", name: "Mikasa Ackerman", clue: "Scarfed Ackerman who fights to protect her adopted brother." },
      { id: "levi", name: "Levi Ackerman", clue: "Humanity's strongest soldier, famously devoted to clean blades." },
    ],
    emojiClues: ["🧱", "🗡️", "🪶"],
  },
  {
    id: "demon_slayer",
    title: "Demon Slayer",
    studio: "Ufotable",
    genres: ["action", "historical"],
    characters: [
      { id: "tanjiro", name: "Tanjiro Kamado", clue: "Kind swordsman with a hanafuda earring who hunts demons to save his sister." },
      { id: "nezuko", name: "Nezuko Kamado", clue: "Bamboo-muzzled demon who still protects humans." },
    ],
    emojiClues: ["🔥", "🗡️", "🌸"],
  },
  {
    id: "jujutsu_kaisen",
    title: "Jujutsu Kaisen",
    studio: "MAPPA",
    genres: ["action", "supernatural"],
    characters: [
      { id: "yuji", name: "Yuji Itadori", clue: "Vessel of Sukuna who punches curses instead of running from them." },
      { id: "gojo", name: "Satoru Gojo", clue: "Blindfolded sorcerer who calls himself the strongest." },
    ],
    emojiClues: ["👊", "👁️", "🌀"],
  },
  {
    id: "my_hero_academia",
    title: "My Hero Academia",
    studio: "Bones",
    genres: ["action", "school"],
    characters: [
      { id: "deku", name: "Izuku Midoriya", clue: "Quirkless boy who inherited One For All and over-analyzes every fight." },
      { id: "bakugo", name: "Katsuki Bakugo", clue: "Explosive blonde rival who shouts his way through U.A." },
    ],
    emojiClues: ["💥", "🦸", "🏫"],
  },
  {
    id: "fullmetal_alchemist",
    title: "Fullmetal Alchemist",
    studio: "Bones",
    genres: ["adventure", "steampunk"],
    characters: [
      { id: "edward", name: "Edward Elric", clue: "Short-tempered alchemist with automail limbs searching for the Philosopher's Stone." },
      { id: "alphonse", name: "Alphonse Elric", clue: "Gentle soul bound to a towering suit of armor." },
    ],
    emojiClues: ["⚗️", "🦾", "🪙"],
  },
  {
    id: "spy_x_family",
    title: "Spy x Family",
    studio: "Wit Studio",
    genres: ["comedy", "slice_of_life"],
    characters: [
      { id: "loid", name: "Loid Forger", clue: "Master spy posing as a psychiatrist and fake husband for a world-peace mission." },
      { id: "anya", name: "Anya Forger", clue: "Telepathic child who wants peanuts and 'spy family' points." },
      { id: "yor", name: "Yor Forger", clue: "City hall clerk whose other job is assassin Thorn Princess." },
    ],
    emojiClues: ["🕵️", "🥜", "🔫"],
  },
  {
    id: "frieren",
    title: "Frieren: Beyond Journey's End",
    studio: "Madhouse",
    genres: ["fantasy", "adventure"],
    characters: [
      { id: "frieren", name: "Frieren", clue: "Elf mage who outlives her hero party and slowly learns what time meant." },
      { id: "fern", name: "Fern", clue: " stoic young mage raised to keep her teacher on schedule." },
    ],
    emojiClues: ["🧙", "⏳", "🍂"],
  },
  {
    id: "hunter_x_hunter",
    title: "Hunter x Hunter",
    studio: "Madhouse",
    genres: ["adventure", "shonen"],
    characters: [
      { id: "gon", name: "Gon Freecss", clue: "Optimistic Hunter candidate searching for his father." },
      { id: "killua", name: "Killua Zoldyck", clue: "Assassin-family prodigy who runs on lightning Nen." },
    ],
    emojiClues: ["🎣", "⚡", "🃏"],
  },
  {
    id: "death_note",
    title: "Death Note",
    studio: "Madhouse",
    genres: ["mystery", "psychological"],
    characters: [
      { id: "light", name: "Light Yagami", clue: "Honor student who finds a notebook that kills by name." },
      { id: "l", name: "L", clue: "World's greatest detective who crouches, sweets in hand." },
    ],
    emojiClues: ["📓", "🍎", "🕵️"],
  },
  {
    id: "chainsaw_man",
    title: "Chainsaw Man",
    studio: "MAPPA",
    genres: ["action", "dark"],
    characters: [
      { id: "denji", name: "Denji", clue: "Devil hunter whose heart is a chainsaw fiend named Pochita." },
      { id: "power", name: "Power", clue: "Blood fiend who would burn the world for her cat Meowy." },
    ],
    emojiClues: ["🪚", "🐶", "🩸"],
  },
  {
    id: "haikyuu",
    title: "Haikyu!!",
    studio: "Production I.G",
    genres: ["sports", "school"],
    characters: [
      { id: "hinata", name: "Shoyo Hinata", clue: "Tiny Karasuno spiker who jumps like he has springs." },
      { id: "kageyama", name: "Tobio Kageyama", clue: "Genius setter nicknamed the King of the Court." },
    ],
    emojiClues: ["🏐", "🐦‍⬛", "🏆"],
  },
  {
    id: "your_name",
    title: "Your Name",
    studio: "CoMix Wave Films",
    genres: ["romance", "drama"],
    characters: [
      { id: "taki", name: "Taki Tachibana", clue: "Tokyo teen who swaps bodies with a girl from a mountain town." },
      { id: "mitsuha", name: "Mitsuha Miyamizu", clue: "Shrine maiden who keeps waking up in a boy's life." },
    ],
    emojiClues: ["☄️", "🧵", "🌄"],
  },
  {
    id: "spirited_away",
    title: "Spirited Away",
    studio: "Studio Ghibli",
    genres: ["fantasy", "adventure"],
    characters: [
      { id: "chihiro", name: "Chihiro Ogino", clue: "Girl renamed Sen who works a bathhouse to free her parents." },
      { id: "haku", name: "Haku", clue: "River spirit who helps a lost girl remember her name." },
    ],
    emojiClues: ["🛁", "🐲", "🐷"],
  },
]);

function allCharacters() {
  const list = [];
  for (const anime of ANIME) {
    for (const character of anime.characters) {
      list.push({
        ...character,
        animeId: anime.id,
        animeTitle: anime.title,
      });
    }
  }
  return list;
}

function byAnimeId(id) {
  return ANIME.find((item) => item.id === id) || null;
}

function characterById(id) {
  return allCharacters().find((item) => item.id === id) || null;
}

function animeByTitle(raw) {
  const needle = normalizeTitle(raw);
  if (!needle) return null;
  return ANIME.find((item) => normalizeTitle(item.title) === needle) || null;
}

function normalizeTitle(value) {
  if (typeof value !== "string") return "";
  return value
    .trim()
    .toLowerCase()
    .replace(/[!?.:,'"’]/g, "")
    .replace(/\s+/g, " ");
}

function sharesRelation(fromId, toId) {
  const from = byAnimeId(fromId);
  const to = byAnimeId(toId);
  if (!from || !to || from.id === to.id) return false;
  if (from.studio && from.studio === to.studio) return true;
  const fromChars = new Set(from.characters.map((item) => item.id));
  return to.characters.some((item) => fromChars.has(item.id));
}

module.exports = {
  ANIME,
  allCharacters,
  byAnimeId,
  characterById,
  animeByTitle,
  normalizeTitle,
  sharesRelation,
};
