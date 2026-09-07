// functions/src/mafia/abilities/good_boy.js
// Simplest citizen-aligned variant: no night action, town win condition.
// Investigated as citizens via team. Assigned at ≥8 players.

module.exports = {
  roleName: 'good_boy',
  team: 'citizens',
  hasNightAction: false,
};
