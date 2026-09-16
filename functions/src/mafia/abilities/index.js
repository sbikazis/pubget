"use strict";

const mafia = require('./mafia');
const don = require('./don');
const doctor = require('./doctor');
const detective = require('./detective');
const citizen = require('./citizen');

const ALL_ABILITIES = {
  [mafia.roleName]: mafia,
  [don.roleName]: don,
  [doctor.roleName]: doctor,
  [detective.roleName]: detective,
  [citizen.roleName]: citizen,
};

function getAbility(roleName) {
  return ALL_ABILITIES[roleName] || null;
}

module.exports = {
  ALL_ABILITIES,
  getAbility
};
