import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/models/group_models.dart';

void main() {
  test('default role with manageEvents can manage events', () {
    expect(
      const GroupMember(uid: 'c1', role: PubgetRank.hatamoto).canManageEvents,
      isTrue,
    );
    expect(
      const GroupMember(uid: 's1', role: PubgetRank.shogun).canManageEvents,
      isTrue,
    );
  });

  test('plain members can create events without manageEvents', () {
    expect(
      memberCanCreateEvents(const GroupMember(uid: 'm1', role: PubgetRank.ronin)),
      isTrue,
    );
    expect(memberCanCreateEvents(null), isFalse);
  });

  test('default role without manageEvents cannot manage events', () {
    expect(
      const GroupMember(uid: 'm1', role: PubgetRank.ronin).canManageEvents,
      isFalse,
    );
    expect(
      const GroupMember(uid: 's2', role: PubgetRank.samurai).canManageEvents,
      isFalse,
    );
  });

  test('custom role with manageEvents can manage events', () {
    final member = const GroupMember(
      uid: 'm1',
      role: PubgetRank.ronin,
      customRoleId: 'moderator',
    ).withEffectivePermissions({GroupPermission.manageEvents});
    expect(member.canManageEvents, isTrue);
    expect(memberCanManageEvents(member), isTrue);
  });

  test('custom role without manageEvents cannot manage events', () {
    final member = const GroupMember(
      uid: 'c1',
      role: PubgetRank.hatamoto,
    ).withEffectivePermissions({GroupPermission.invite});
    expect(member.canManageEvents, isFalse);
  });

  test('non-member cannot manage events', () {
    expect(memberCanManageEvents(null), isFalse);
  });

  test('founder and shogun can manage members; members cannot', () {
    expect(
      const GroupMember(uid: 'a1', role: PubgetRank.mikado).canManageMembers,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'a2', role: PubgetRank.shogun).canManageMembers,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'c1', role: PubgetRank.daimyo).canManageMembers,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'm1', role: PubgetRank.ronin).canManageMembers,
      isFalse,
    );
    expect(
      const GroupMember(uid: 's1', role: PubgetRank.gokenin).canManageMembers,
      isFalse,
    );
    expect(memberCanManageMembers(null), isFalse);
  });

  test('founder and shogun can manage settings; members cannot', () {
    expect(
      const GroupMember(uid: 'a1', role: PubgetRank.mikado).canManageSettings,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'a2', role: PubgetRank.shogun).canManageSettings,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'c1', role: PubgetRank.daimyo).canManageSettings,
      isFalse,
    );
    expect(
      const GroupMember(uid: 'm1', role: PubgetRank.ronin).canManageSettings,
      isFalse,
    );
    expect(memberCanManageSettings(null), isFalse);
  });

  test('founder can manage settings even with an empty role document', () {
    expect(
      const GroupMember(
        uid: 'a1',
        role: PubgetRank.mikado,
      ).withEffectivePermissions(const <GroupPermission>{}).canManageSettings,
      isTrue,
    );
  });

  test('custom role with manageSettings can manage settings', () {
    final member = const GroupMember(
      uid: 'm1',
      role: PubgetRank.ronin,
    ).withEffectivePermissions({GroupPermission.manageSettings});
    expect(member.canManageSettings, isTrue);
  });

  test('founder can manage members even with an empty role document', () {
    expect(
      const GroupMember(
        uid: 'a1',
        role: PubgetRank.mikado,
      ).withEffectivePermissions(const <GroupPermission>{}).canManageMembers,
      isTrue,
    );
  });

  test('founder and admin-equivalent roles can manage events', () {
    expect(
      const GroupMember(uid: 'a1', role: PubgetRank.mikado).canManageEvents,
      isTrue,
    );
    expect(
      const GroupMember(
        uid: 'a1',
        role: PubgetRank.mikado,
      ).withEffectivePermissions(const <GroupPermission>{}).canManageEvents,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'a2', role: PubgetRank.shogun).canManageEvents,
      isTrue,
    );
  });
}
