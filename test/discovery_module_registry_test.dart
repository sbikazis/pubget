import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/home/discovery_module.dart';
import 'package:pubget/features/home/models/home_models.dart';

void main() {
  test('pinned modules are the three fixed §5.2 surfaces, in order', () {
    expect(
      DiscoveryModuleRegistry.pinned.map((module) => module.id).toList(),
      <String>['promoted', 'edits', 'people'],
    );
  });

  test('rotating modules exclude every pinned module', () {
    final pinnedIds = DiscoveryModuleRegistry.pinned
        .map((module) => module.id)
        .toSet();
    final rotatingIds = DiscoveryModuleRegistry.rotating
        .map((module) => module.id)
        .toList();

    expect(rotatingIds, isNotEmpty);
    expect(rotatingIds.toSet().intersection(pinnedIds), isEmpty);
    expect(
      DiscoveryModuleRegistry.pinned.length +
          DiscoveryModuleRegistry.rotating.length,
      DiscoveryModuleRegistry.all.length,
    );
  });

  test('every registry id is unique', () {
    final ids = DiscoveryModuleRegistry.all.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('provider-backed modules declare the section kind they read', () {
    for (final module in DiscoveryModuleRegistry.all) {
      final needsKind =
          module.type == DiscoveryModuleType.groupStrip ||
          module.type == DiscoveryModuleType.peopleStrip ||
          module.type == DiscoveryModuleType.rankedRow;
      if (needsKind) {
        expect(module.kind, isNotNull, reason: '${module.id} needs a kind');
      }
    }
  });

  test('ranked rows map to the getHomeSections wire keys', () {
    final rankedKinds = DiscoveryModuleRegistry.all
        .where((m) => m.type == DiscoveryModuleType.rankedRow)
        .map((m) => m.kind)
        .whereType<HomeSectionKind>()
        .toList();
    expect(rankedKinds, isNotEmpty);
  });

  test('disabled modules are dropped and require a documented reason', () {
    const modules = <DiscoveryModule>[
      DiscoveryModule(
        id: 'on',
        type: DiscoveryModuleType.events,
        pinned: false,
      ),
      DiscoveryModule(
        id: 'off',
        type: DiscoveryModuleType.events,
        pinned: false,
        enabled: false,
        disabledReason: 'No event source configured in this environment.',
      ),
    ];

    expect(
      DiscoveryModuleRegistry.enabledOf(modules).map((m) => m.id),
      <String>['on'],
    );
    expect(
      DiscoveryModuleRegistry.rotatingOf(modules).map((m) => m.id),
      <String>['on'],
    );
  });

  test('a See all path, when present, is an in-app absolute route', () {
    for (final module in DiscoveryModuleRegistry.all) {
      final path = module.seeMorePath;
      if (path == null) continue;
      expect(path.startsWith('/'), isTrue, reason: '${module.id}: $path');
    }
  });
}
