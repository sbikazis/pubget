import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/models/group_authority.dart';
import 'package:pubget/features/groups/models/group_models.dart';

void main() {
  GroupMember member(PubgetRank role, {String uid = 'u1'}) => GroupMember(
        uid: uid,
        role: role,
        joinedAt: DateTime.utc(2024, 1, 1),
        rankChangedAt: DateTime.utc(2024, 6, 1),
      );

  test('authority matrix gates invite kick unban roles', () {
    expect(GroupAuthority.canInvite(member(PubgetRank.ronin)), isFalse);
    expect(GroupAuthority.canInvite(member(PubgetRank.gokenin)), isTrue);
    expect(GroupAuthority.canKickBan(member(PubgetRank.hatamoto)), isFalse);
    expect(GroupAuthority.canKickBan(member(PubgetRank.daimyo)), isTrue);
    expect(GroupAuthority.canUnban(member(PubgetRank.daimyo)), isFalse);
    expect(GroupAuthority.canUnban(member(PubgetRank.shogun)), isTrue);
    expect(GroupAuthority.canManageRoles(member(PubgetRank.daimyo)), isFalse);
    expect(GroupAuthority.canManageRoles(member(PubgetRank.shogun)), isTrue);
  });

  test('promotion and demotion lists never include MIKADO', () {
    expect(
      GroupAuthority.promotionDestinations(PubgetRank.samurai),
      <PubgetRank>[
        PubgetRank.hatamoto,
        PubgetRank.daimyo,
        PubgetRank.shogun,
      ],
    );
    expect(
      GroupAuthority.demotionDestinations(PubgetRank.samurai),
      <PubgetRank>[PubgetRank.gokenin, PubgetRank.ronin],
    );
    expect(
      GroupAuthority.promotionDestinations(PubgetRank.shogun),
      isEmpty,
    );
  });

  test('sort uses rank then seniority then uid', () {
    final older = member(PubgetRank.samurai, uid: 'a').copyWith(
      rankChangedAt: DateTime.utc(2024, 1, 1),
    );
    final newer = member(PubgetRank.samurai, uid: 'b').copyWith(
      rankChangedAt: DateTime.utc(2024, 2, 1),
    );
    final shogun = member(PubgetRank.shogun, uid: 'c');
    final list = <GroupMember>[newer, older, shogun]
      ..sort(compareMembersByRankThenJoined);
    expect(list.map((m) => m.uid).toList(), <String>['c', 'a', 'b']);
  });

  test('daimyo cannot promote to shogun; mikado can', () {
    final target = member(PubgetRank.samurai, uid: 't');
    expect(
      GroupAuthority.authorizedDestinations(
        actor: member(PubgetRank.daimyo, uid: 'd'),
        target: target,
        promote: true,
      ),
      isEmpty,
    );
    expect(
      GroupAuthority.authorizedDestinations(
        actor: member(PubgetRank.mikado, uid: 'm'),
        target: target,
        promote: true,
      ),
      contains(PubgetRank.shogun),
    );
  });

  test('occupancy marks full ranks without inventing unlimited caps', () {
    final members = <GroupMember>[
      member(PubgetRank.mikado, uid: 'm'),
      member(PubgetRank.shogun, uid: 's'),
      for (var i = 0; i < 5; i++) member(PubgetRank.samurai, uid: 'sa$i'),
      member(PubgetRank.ronin, uid: 'r1'),
      member(PubgetRank.ronin, uid: 'r2'),
    ];
    final occupancy = computeRankOccupancy(members);
    final shogun = occupancy.firstWhere((o) => o.rank == PubgetRank.shogun);
    final samurai = occupancy.firstWhere((o) => o.rank == PubgetRank.samurai);
    final ronin = occupancy.firstWhere((o) => o.rank == PubgetRank.ronin);
    expect(shogun.isFull, isTrue);
    expect(samurai.isFull, isTrue);
    expect(ronin.isUnlimited, isTrue);
    expect(ronin.count, 2);
  });
}
