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

  test('color hex values match RankColors MIKADO edition palette', () {
    expect(pubgetRankCoreColor(PubgetRank.ronin), const Color(0xFF0A2A6B));
    expect(pubgetRankCoreColor(PubgetRank.gokenin), const Color(0xFF0F3D2E));
    expect(pubgetRankCoreColor(PubgetRank.samurai), const Color(0xFF8B1A1A));
    expect(pubgetRankCoreColor(PubgetRank.hatamoto), const Color(0xFF14A092));
    expect(pubgetRankCoreColor(PubgetRank.daimyo), const Color(0xFF0E8FB8));
    expect(pubgetRankCoreColor(PubgetRank.shogun), const Color(0xFF9C1225));
    expect(pubgetRankCoreColor(PubgetRank.mikado), const Color(0xFF7A1FFF));

    expect(
      rankColorResolver(PubgetRank.ronin, isDarkMode: false),
      const Color(0xFF0A2A6B),
    );
    expect(
      rankColorResolver(PubgetRank.shogun, isDarkMode: false),
      const Color(0xFF9C1225),
    );
    expect(
      rankColorResolver(PubgetRank.mikado, isDarkMode: true),
      const Color(0xFF7A1FFF),
    );
  });

  test('SAMURAI and SHŌGUN badge assets are distinct', () {
    expect(pubgetRankBadgeAsset(PubgetRank.samurai), isNotNull);
    expect(pubgetRankBadgeAsset(PubgetRank.shogun), isNotNull);
    expect(
      pubgetRankBadgeAsset(PubgetRank.samurai),
      isNot(pubgetRankBadgeAsset(PubgetRank.shogun)),
    );
    expect(
      pubgetRankBadgeAsset(PubgetRank.shogun),
      'assets/images/ranks/shogun.png',
    );
    expect(
      pubgetRankBadgeAsset(PubgetRank.samurai),
      'assets/images/ranks/samurai.png',
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

  test('bubble badges glow stronger as rank climbs', () {
    expect(rankShowsBubbleBadge(PubgetRank.ronin), isTrue);
    expect(
      rankBadgeGlowStrength(PubgetRank.mikado) >
          rankBadgeGlowStrength(PubgetRank.ronin),
      isTrue,
    );
    expect(
      rankBadgeGlowStrength(PubgetRank.shogun) >
          rankBadgeGlowStrength(PubgetRank.samurai),
      isTrue,
    );
    expect(rankBadgeGlowColor(PubgetRank.mikado), const Color(0xFF7A1FFF));
    expect(rankBadgeGlowColor(PubgetRank.shogun), const Color(0xFFC9A227));
  });
}
