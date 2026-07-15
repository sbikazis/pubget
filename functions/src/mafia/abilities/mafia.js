// functions/src/mafia/abilities/mafia.js
//
// وصف دور "المافيا" من ناحية السيرفر: الفريق والقدرة الليلية.
// التنفيذ الفعلي لحل الليلة (من قُتل فعلياً) هو مسؤولية nightResolver.js
// في المرحلة 4، وليس هذا الملف. هذا الملف حالياً وصفي فقط (Metadata)
// يُستخدم من roleAssigner.js لمعرفة الفريق عند التوزيع.

module.exports = {
  roleName: 'mafia',
  team: 'mafias',
  hasNightAction: true,
};