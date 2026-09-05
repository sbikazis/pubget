import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/models/group_models.dart';

void main() {
  test('default role with manageEvents can manage events', () {
    expect(
      const GroupMember(uid: 'c1', role: GroupRole.captain).canManageEvents,
      isTrue,
    );
    expect(
      const GroupMember(uid: 's1', role: GroupRole.shogun).canManageEvents,
      isTrue,
    );
  });

  test('default role without manageEvents cannot manage events', () {
    expect(
      const GroupMember(uid: 'm1', role: GroupRole.member).canManageEvents,
      isFalse,
    );
    expect(
      const GroupMember(uid: 's2', role: GroupRole.sensei).canManageEvents,
      isFalse,
    );
  });

  test('custom role with manageEvents can manage events', () {
    final member = const GroupMember(
      uid: 'm1',
      role: GroupRole.member,
      customRoleId: 'moderator',
    ).withEffectivePermissions({GroupPermission.manageEvents});
    expect(member.canManageEvents, isTrue);
    expect(memberCanManageEvents(member), isTrue);
  });

  test('custom role without manageEvents cannot manage events', () {
    final member = const GroupMember(
      uid: 'c1',
      role: GroupRole.captain,
    ).withEffectivePermissions({GroupPermission.invite});
    expect(member.canManageEvents, isFalse);
  });

  test('non-member cannot manage events', () {
    expect(memberCanManageEvents(null), isFalse);
  });

  test('founder and shogun can manage members; members cannot', () {
    expect(
      const GroupMember(uid: 'a1', role: GroupRole.founder).canManageMembers,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'a2', role: GroupRole.shogun).canManageMembers,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'c1', role: GroupRole.commander).canManageMembers,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'm1', role: GroupRole.member).canManageMembers,
      isFalse,
    );
    expect(
      const GroupMember(uid: 's1', role: GroupRole.senpai).canManageMembers,
      isFalse,
    );
    expect(memberCanManageMembers(null), isFalse);
  });

  test('founder can manage members even with an empty role document', () {
    expect(
      const GroupMember(
        uid: 'a1',
        role: GroupRole.founder,
      ).withEffectivePermissions(const <GroupPermission>{}).canManageMembers,
      isTrue,
    );
  });

  test('founder and admin-equivalent roles can manage events', () {
    expect(
      const GroupMember(uid: 'a1', role: GroupRole.founder).canManageEvents,
      isTrue,
    );
    expect(
      const GroupMember(
        uid: 'a1',
        role: GroupRole.founder,
      ).withEffectivePermissions(const <GroupPermission>{}).canManageEvents,
      isTrue,
    );
    expect(
      const GroupMember(uid: 'a2', role: GroupRole.shogun).canManageEvents,
      isTrue,
    );
  });
}
