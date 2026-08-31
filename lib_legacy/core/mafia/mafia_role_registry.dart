// lib/core/mafia/mafia_role_registry.dart

import '../constants/mafia_constants.dart';

typedef RoleAbilityBuilder = MafiaRoleAbility Function();

abstract class MafiaRoleAbility {
  String get roleName;
  String get team;

  Future<void> execute({
    required String gameId,
    required String playerId,
    String? targetId,
  });
}

class MafiaRoleRegistry {
  final Map<String, RoleAbilityBuilder> _registry = {};

  // ✅ الحل: constructor صريح فارغ.
  // بدونه، Dart يُسقط الـ constructor الافتراضي غير المسمّى بمجرد
  // وجود أي constructor آخر معرّف في الكلاس (هنا factory .standard()).
  MafiaRoleRegistry();

  void register(String roleName, RoleAbilityBuilder builder) {
    _registry[roleName] = builder;
  }

  MafiaRoleAbility? createAbility(String roleName) {
    final builder = _registry[roleName];
    if (builder == null) return null;
    return builder();
  }

  bool contains(String roleName) => _registry.containsKey(roleName);

  /// أسماء كل الأدوار المسجّلة حالياً في هذا النسخة من التطبيق.
  List<String> get registeredRoles => _registry.keys.toList(growable: false);

  // ══════════════════════════════════════════════════════════
  // ✅ التفعيل الفعلي: نسخة وحيدة (Singleton) مُهيّأة بكل الأدوار
  // الأساسية عند أول استخدام. هذا يجعل السجل "حياً" بدل أن يكون
  // مجرد Class مُعرَّف بلا أي Instance يستخدمه أحد.
  //
  // الاستخدام المستقبلي (المرحلة 4 - واجهات الليل):
  //   final ability = MafiaRoleRegistry.instance.createAbility(player.role);
  //   إذا null => الدور لا يملك قدرة ليلية (مواطن مثلاً).
  // ══════════════════════════════════════════════════════════
  static final MafiaRoleRegistry instance = MafiaRoleRegistry.standard();

  factory MafiaRoleRegistry.standard() {
    final registry = MafiaRoleRegistry();
    registry.register(MafiaRoles.mafia, () => MafiaAbility());
    registry.register(MafiaRoles.doctor, () => MedicAbility());
    registry.register(MafiaRoles.detective, () => DetectiveAbility());
    registry.register(MafiaRoles.sniper, () => SniperAbility());
    registry.register(MafiaRoles.silencer, () => SilencerAbility());
    registry.register(MafiaRoles.goodBoy, () => GoodBoyAbility());
    registry.register(MafiaRoles.citizen, () => CitizenAbility());
    return registry;
  }
}

class MafiaAbility extends MafiaRoleAbility {
  @override
  String get roleName => MafiaRoles.mafia;

  @override
  String get team => MafiaTeams.mafias;

  @override
  Future<void> execute({
    required String gameId,
    required String playerId,
    String? targetId,
  }) async {
    // TODO(Stage 4): إرسال قرار القتل الليلي إلى night_actions.
    // التنفيذ الفعلي (تحديد من مات) يحدث حصراً في roleAssigner/nightResolver
    // على السيرفر — هذا الأسلوب هنا مجرد نقطة دخول لواجهة اللاعب مستقبلاً.
  }
}

class MedicAbility extends MafiaRoleAbility {
  @override
  String get roleName => MafiaRoles.doctor;

  @override
  String get team => MafiaTeams.citizens;

  @override
  Future<void> execute({
    required String gameId,
    required String playerId,
    String? targetId,
  }) async {
    // TODO(Stage 4): إرسال قرار الحماية الليلي إلى night_actions.
  }
}

class DetectiveAbility extends MafiaRoleAbility {
  @override
  String get roleName => MafiaRoles.detective;

  @override
  String get team => MafiaTeams.citizens;

  @override
  Future<void> execute({
    required String gameId,
    required String playerId,
    String? targetId,
  }) async {
    // TODO(Stage 4): إرسال قرار الفحص الليلي إلى night_actions.
  }
}

class SniperAbility extends MafiaRoleAbility {
  @override
  String get roleName => MafiaRoles.sniper;

  @override
  String get team => MafiaTeams.citizens;

  @override
  Future<void> execute({
    required String gameId,
    required String playerId,
    String? targetId,
  }) async {
    // TODO(Stage 4): إرسال قرار الرصاصة الليلية (usedBullet) إلى night_actions.
  }
}

class SilencerAbility extends MafiaRoleAbility {
  @override
  String get roleName => MafiaRoles.silencer;

  @override
  String get team => MafiaTeams.citizens;

  @override
  Future<void> execute({
    required String gameId,
    required String playerId,
    String? targetId,
  }) async {
    // TODO(Stage 4): إرسال قرار الإسكات الليلي إلى night_actions.
  }
}

class GoodBoyAbility extends MafiaRoleAbility {
  @override
  String get roleName => MafiaRoles.goodBoy;

  @override
  String get team => MafiaTeams.citizens;

  @override
  Future<void> execute({
    required String gameId,
    required String playerId,
    String? targetId,
  }) async {
    // لا قدرة ليلية فعلية — دور اجتماعي/خاص حسب قواعد اللعبة المستقبلية.
  }
}

class CitizenAbility extends MafiaRoleAbility {
  @override
  String get roleName => MafiaRoles.citizen;

  @override
  String get team => MafiaTeams.citizens;

  @override
  Future<void> execute({
    required String gameId,
    required String playerId,
    String? targetId,
  }) async {
    // دور المواطن لا يملك قدرة ليلية خاصة.
  }
}