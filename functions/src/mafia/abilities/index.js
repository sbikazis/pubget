// functions/src/mafia/abilities/index.js
//
// نقطة تجميع واحدة لكل الأدوار (مطابقة تماماً لأسماء الأدوار في
// lib/core/constants/mafia_constants.dart -> MafiaRoles).
// أي دور جديد مستقبلاً يُضاف كملف هنا فقط ويُسجَّل في ALL_ABILITIES،
// بدون الحاجة لتعديل roleAssigner.js أو أي منطق آخر — تماشياً مع
// قاعدة "قابلية التطوير" في التصميم الأصلي.

const mafia = require('./mafia');
const doctor = require('./doctor');
const detective = require('./detective');
const sniper = require('./spiner');
const silencer = require('./silencer');
const goodBoy = require('./good_boy');
const citizen = require('./citizen');

const ALL_ABILITIES = {
  [mafia.roleName]: mafia,
  [doctor.roleName]: doctor,
  [detective.roleName]: detective,
  [sniper.roleName]: sniper,
  [silencer.roleName]: silencer,
  [goodBoy.roleName]: goodBoy,
  [citizen.roleName]: citizen,
};

function getAbility(roleName) {
  return ALL_ABILITIES[roleName] || null;
}

module.exports = { ALL_ABILITIES, getAbility };