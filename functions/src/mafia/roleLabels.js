"use strict";

// Master Spec 13.7: an eliminated player's role is revealed to the table. The
// same wording is used for every kind of elimination — night, vote, and leave —
// so the reveal reads the same way wherever it happens. Kept in one place so a
// new elimination path cannot quietly invent its own phrasing.
const ROLE_LABELS = {
  mafia: "Mafia",
  don: "Don",
  doctor: "the Doctor",
  detective: "the Detective",
  citizen: "a Citizen",
};

function roleLabel(role) {
  return ROLE_LABELS[role] || "a villager";
}

module.exports = { ROLE_LABELS, roleLabel };
