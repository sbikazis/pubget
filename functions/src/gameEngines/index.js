"use strict";

const guessCharacter = require("./guessCharacter");
const animeChain = require("./animeChain");
const emojiAnimeGuess = require("./emojiAnimeGuess");

const ENGINES = {
  guessCharacter,
  animeChain,
  emojiAnimeGuess,
};

function engineFor(type) {
  return ENGINES[type] || null;
}

module.exports = {
  engineFor,
  ENGINES,
};
