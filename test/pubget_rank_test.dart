import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/models/pubget_rank.dart';

void main() {
  test('rank ordinals match MIKADO edition ladder', () {
    expect(PubgetRank.ronin.index, 0);
    expect(PubgetRank.mikado.index, 6);
    expect(PubgetRank.daimyo.index > PubgetRank.hatamoto.index, isTrue);
  });

  test('legacy names parse to new ranks; corrupt → ronin', () {
    expect(parsePubgetRank('founder'), PubgetRank.mikado);
    expect(parsePubgetRank('commander'), PubgetRank.daimyo);
    expect(parsePubgetRank('captain'), PubgetRank.hatamoto);
    expect(parsePubgetRank('sensei'), PubgetRank.samurai);
    expect(parsePubgetRank('senpai'), PubgetRank.gokenin);
    expect(parsePubgetRank('member'), PubgetRank.ronin);
    expect(parsePubgetRank(null), PubgetRank.ronin);
    expect(parsePubgetRank('???'), PubgetRank.ronin);
  });

  test('color hex values match the engineering table', () {
    expect(pubgetRankCoreColor(PubgetRank.ronin), const Color(0xFF25204A));
    expect(pubgetRankCoreColor(PubgetRank.gokenin), const Color(0xFF4B2A73));
    expect(pubgetRankCoreColor(PubgetRank.samurai), const Color(0xFF8F2636));
    expect(pubgetRankCoreColor(PubgetRank.hatamoto), const Color(0xFF302A68));
    expect(pubgetRankCoreColor(PubgetRank.daimyo), const Color(0xFF5B2A86));
    expect(pubgetRankCoreColor(PubgetRank.shogun), const Color(0xFF111018));
    expect(pubgetRankCoreColor(PubgetRank.mikado), const Color(0xFF5E2A84));

    expect(
      rankColorResolver(PubgetRank.ronin, isDarkMode: false),
      const Color(0xFF362D76),
    );
    expect(
      rankColorResolver(PubgetRank.shogun, isDarkMode: false),
      const Color(0xFF8C1728),
    );
    expect(
      rankColorResolver(PubgetRank.mikado, isDarkMode: true),
      const Color(0xFFB989DC),
    );
  });

  test('permission matrix and assignment ceiling', () {
    expect(rankHasPermission(PubgetRank.ronin, GroupPermission.invite), isFalse);
    expect(rankHasPermission(PubgetRank.gokenin, GroupPermission.invite), isTrue);
    expect(
      rankHasPermission(PubgetRank.daimyo, GroupPermission.kickBan),
      isTrue,
    );
    expect(
      rankHasPermission(PubgetRank.daimyo, GroupPermission.unban),
      isFalse,
    );
    expect(
      canAssignRank(
        actor: PubgetRank.mikado,
        targetCurrent: PubgetRank.ronin,
        desired: PubgetRank.shogun,
      ),
      isTrue,
    );
    expect(
      canAssignRank(
        actor: PubgetRank.shogun,
        targetCurrent: PubgetRank.ronin,
        desired: PubgetRank.shogun,
      ),
      isFalse,
    );
  });

  test('dashboard tabs are built from permissions, always include chat', () {
    final gokenin = dashboardTabsFor(permissionsForRank(PubgetRank.gokenin));
    expect(gokenin, contains(RankDashboardTab.invite));
    expect(gokenin, contains(RankDashboardTab.chat));
    expect(gokenin, isNot(contains(RankDashboardTab.games)));

    final hatamoto = dashboardTabsFor(permissionsForRank(PubgetRank.hatamoto));
    expect(hatamoto, contains(RankDashboardTab.events));
    expect(hatamoto, isNot(contains(RankDashboardTab.games)));

    final mikado = dashboardTabsFor(permissionsForRank(PubgetRank.mikado));
    expect(mikado, contains(RankDashboardTab.roles));
    expect(mikado, contains(RankDashboardTab.audit));
  });
}
