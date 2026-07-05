import '../../core/constants/mafia_constants.dart';

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

  void register(String roleName, RoleAbilityBuilder builder) {
    _registry[roleName] = builder;
  }

  MafiaRoleAbility? createAbility(String roleName) {
    final builder = _registry[roleName];
    if (builder == null) return null;
    return builder();
  }

  bool contains(String roleName) => _registry.containsKey(roleName);
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
    // دور المافيا يرسل طلبه فقط.
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
    // دور الطبيب يرسل طلبه فقط.
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
    // دور المحقق يرسل طلبه فقط.
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
    // دور القناص يرسل طلبه فقط.
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
    // دور المُسكِّت يرسل طلبه فقط.
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
    // دور الصديق الطيب يرسل طلبه فقط.
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
