import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../data/achievement_catalog.dart';
import '../models/achievement_models.dart';
import 'achievement_repository.dart';

final class FirebaseAchievementRepository implements AchievementRepository {
  FirebaseAchievementRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Result<List<AchievementItem>>> list({String? userId}) async {
    try {
      final result = await _functions.httpsCallable('getAchievements').call(
        userId == null ? null : <String, dynamic>{'userId': userId},
      );
      final data = Map<String, dynamic>.from(result.data as Map);
      final items = (data['items'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map>()
          .map(_fromServerMap)
          .toList(growable: false);
      if (items.isEmpty) {
        return Success(AchievementCatalog.lockedItems());
      }
      return Success(items);
    } on Object catch (error) {
      return FailureResult(_fail(error));
    }
  }

  @override
  Stream<Result<List<AchievementItem>>> watch(String userId) {
    final unlockedQuery = _firestore
        .collection('user_achievements')
        .doc(userId)
        .collection('unlocked');
    final progressQuery = _firestore
        .collection('user_achievement_progress')
        .doc(userId)
        .collection('progress');

    late final StreamController<Result<List<AchievementItem>>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? unlockedSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? progressSub;
    QuerySnapshot<Map<String, dynamic>>? unlockedSnap;
    QuerySnapshot<Map<String, dynamic>>? progressSnap;
    var unlockedReady = false;
    var progressReady = false;
    var emitting = false;

    Future<void> emit() async {
      if (!unlockedReady || !progressReady || emitting || controller.isClosed) {
        return;
      }
      emitting = true;
      try {
        final unlocked = <String, Map<String, dynamic>>{
          for (final doc in unlockedSnap?.docs ?? const []) doc.id: doc.data(),
        };
        if (unlocked.isEmpty) {
          final legacy = await _firestore
              .collection('user_achievements')
              .doc(userId)
              .collection('items')
              .get();
          for (final doc in legacy.docs) {
            unlocked[doc.id] = doc.data();
          }
        }
        final progress = <String, Map<String, dynamic>>{
          for (final doc in progressSnap?.docs ?? const []) doc.id: doc.data(),
        };
        if (!controller.isClosed) {
          controller.add(Success(_merge(unlocked, progress)));
        }
      } on Object catch (error) {
        if (!controller.isClosed) {
          controller.add(FailureResult(_fail(error)));
        }
      } finally {
        emitting = false;
      }
    }

    controller = StreamController<Result<List<AchievementItem>>>(
      onListen: () {
        unlockedSub = unlockedQuery.snapshots().listen(
          (snap) {
            unlockedSnap = snap;
            unlockedReady = true;
            unawaited(emit());
          },
          onError: (Object error) {
            if (!controller.isClosed) {
              controller.add(FailureResult(_fail(error)));
            }
          },
        );
        progressSub = progressQuery.snapshots().listen(
          (snap) {
            progressSnap = snap;
            progressReady = true;
            unawaited(emit());
          },
          onError: (Object error) {
            if (!controller.isClosed) {
              controller.add(FailureResult(_fail(error)));
            }
          },
        );
      },
      onCancel: () async {
        await unlockedSub?.cancel();
        await progressSub?.cancel();
      },
    );

    return controller.stream;
  }

  List<AchievementItem> _merge(
    Map<String, Map<String, dynamic>> unlocked,
    Map<String, Map<String, dynamic>> progress,
  ) {
    return AchievementCatalog.definitions.map((definition) {
      final u = unlocked[definition.id];
      final p = progress[definition.id];
      final conditions = _conditionsFrom(definition, p, unlocked: u != null);
      return AchievementItem(
        definition: definition,
        unlocked: u != null,
        unlockedAt: _date(u?['unlockedAt']),
        currentValue: (p?['currentValue'] as num?) ?? 0,
        targetValue: (p?['targetValue'] as num?) ??
            (definition.conditions.isEmpty
                ? 0
                : definition.conditions.first.target),
        conditions: conditions,
      );
    }).toList(growable: false);
  }

  List<AchievementConditionProgress> _conditionsFrom(
    AchievementDefinition definition,
    Map<String, dynamic>? progress, {
    required bool unlocked,
  }) {
    final raw = progress?['conditions'];
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return definition.conditions.map((c) {
      final entry = map[c.id];
      final data = entry is Map ? Map<String, dynamic>.from(entry) : null;
      return AchievementConditionProgress(
        id: c.id,
        labelEn: c.labelEn,
        labelAr: c.labelAr,
        current: (data?['current'] as num?) ?? 0,
        target: (data?['target'] as num?) ?? c.target,
        met: unlocked || data?['met'] == true,
      );
    }).toList(growable: false);
  }

  AchievementItem _fromServerMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    final id = map['id'] as String? ?? '';
    final local = AchievementCatalog.byId(id);
    final definition = local ??
        AchievementDefinition(
          id: id,
          rarity: parseRarity(map['rarity'] as String?),
          nameEn: map['nameEn'] as String? ?? map['title'] as String? ?? id,
          nameAr: map['nameAr'] as String? ?? map['title'] as String? ?? id,
          descriptionEn: map['descriptionEn'] as String? ??
              map['description'] as String? ??
              '',
          descriptionAr: map['descriptionAr'] as String? ??
              map['description'] as String? ??
              '',
          meaningEn: map['meaningEn'] as String? ?? '',
          meaningAr: map['meaningAr'] as String? ?? '',
          assetPath: map['assetPath'] as String? ??
              'assets/achievements/$id/badge.png',
          animationType: parseAnimationType(map['animationType'] as String?),
          rewardCoins: (map['rewardCoins'] as num?)?.toInt() ?? 0,
          conditions: const <AchievementConditionProgress>[],
        );

    final conditionsRaw = map['conditions'];
    final conditions = <AchievementConditionProgress>[];
    if (conditionsRaw is List) {
      for (final entry in conditionsRaw.whereType<Map>()) {
        final c = Map<String, dynamic>.from(entry);
        conditions.add(
          AchievementConditionProgress(
            id: c['id'] as String? ?? '',
            labelEn: c['labelEn'] as String? ?? '',
            labelAr: c['labelAr'] as String? ?? '',
            current: (c['current'] as num?) ?? 0,
            target: (c['target'] as num?) ?? 0,
            met: c['met'] == true,
          ),
        );
      }
    }

    return AchievementItem(
      definition: definition,
      unlocked: map['unlocked'] == true,
      unlockedAt: _date(map['unlockedAt']),
      currentValue: (map['currentValue'] as num?) ?? 0,
      targetValue: (map['targetValue'] as num?) ?? 0,
      conditions: conditions.isNotEmpty ? conditions : definition.conditions,
    );
  }
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

Failure _fail(Object error) {
  if (error is FirebaseFunctionsException) {
    return ValidationError(error.message ?? 'Achievements could not load.');
  }
  return UnknownError(error.toString());
}
