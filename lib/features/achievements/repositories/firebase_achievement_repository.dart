import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/achievement_models.dart';
import 'achievement_repository.dart';

const _catalog = <AchievementItem>[
  AchievementItem(
    id: 'first_group',
    type: 'community',
    title: 'First Circle',
    description: 'Create your first group.',
    icon: 'group',
    unlocked: false,
    rewardCoins: 5,
  ),
  AchievementItem(
    id: 'first_edit',
    type: 'creator',
    title: 'First Cut',
    description: 'Publish your first edit.',
    icon: 'edit',
    unlocked: false,
  ),
  AchievementItem(
    id: 'first_friend',
    type: 'social',
    title: 'First Friend',
    description: 'Accept or form your first friendship.',
    icon: 'friend',
    unlocked: false,
  ),
  AchievementItem(
    id: 'first_fan',
    type: 'social',
    title: 'First Fan',
    description: 'Receive your first fan through Respect.',
    icon: 'fan',
    unlocked: false,
  ),
  AchievementItem(
    id: 'first_event_participation',
    type: 'event',
    title: 'Show Up',
    description: 'Participate in your first event.',
    icon: 'event',
    unlocked: false,
  ),
  AchievementItem(
    id: 'first_event_win',
    type: 'event',
    title: 'Event Victor',
    description: 'Win your first event.',
    icon: 'trophy',
    unlocked: false,
  ),
  AchievementItem(
    id: 'first_game_win',
    type: 'game',
    title: 'First Victory',
    description: 'Win your first game.',
    icon: 'game',
    unlocked: false,
  ),
  AchievementItem(
    id: 'creator_milestone',
    type: 'creator',
    title: 'Creator',
    description: 'Publish your first Fan Work.',
    icon: 'creator',
    unlocked: false,
  ),
  AchievementItem(
    id: 'community_milestone',
    type: 'community',
    title: 'In the Mix',
    description: 'Finish your first game as a participant.',
    icon: 'community',
    unlocked: false,
  ),
  AchievementItem(
    id: 'autumn_2026_rally',
    type: 'seasonal',
    title: 'Autumn Rally',
    description: 'Win a game during the Autumn 2026 season.',
    icon: 'season',
    unlocked: false,
    rewardCoins: 10,
    seasonId: 'autumn_2026',
    seasonStartAt: DateTime.utc(2026, 9, 1),
    seasonEndAt: DateTime.utc(2026, 11, 30, 23, 59, 59, 999),
    seasonState: 'active',
    trigger: 'game_won',
  ),
];

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
  Future<Result<List<AchievementItem>>> list() async {
    try {
      final result = await _functions.httpsCallable('getAchievements').call();
      final data = Map<String, dynamic>.from(result.data as Map);
      final items = (data['items'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map>()
          .map(_fromMap)
          .toList(growable: false);
      return Success(items);
    } on Object catch (error) {
      return FailureResult(_fail(error));
    }
  }

  @override
  Stream<Result<List<AchievementItem>>> watch(String userId) {
    return _firestore
        .collection('user_achievements')
        .doc(userId)
        .collection('items')
        .snapshots()
        .map((snapshot) {
          final unlocked = <String, Map<String, dynamic>>{
            for (final doc in snapshot.docs) doc.id: doc.data(),
          };
          return Success(
            _catalog
                .map((item) {
                  final data = unlocked[item.id];
                  return AchievementItem(
                    id: item.id,
                    type: item.type,
                    title: item.title,
                    description: item.description,
                    icon: item.icon,
                    unlocked: data != null,
                    unlockedAt: _date(data?['unlockedAt']),
                    rewardCoins: item.rewardCoins,
                    seasonId: item.seasonId,
                    seasonStartAt: item.seasonStartAt,
                    seasonEndAt: item.seasonEndAt,
                    seasonState: item.seasonState,
                    trigger: item.trigger,
                  );
                })
                .toList(growable: false),
          );
        })
        .handleError(
          (Object error) =>
              FailureResult<List<AchievementItem>>(_fail(error)),
        );
  }
}

AchievementItem _fromMap(Map<dynamic, dynamic> raw) {
  final map = Map<String, dynamic>.from(raw);
  return AchievementItem(
    id: map['id'] as String? ?? '',
    type: map['type'] as String? ?? '',
    title: map['title'] as String? ?? '',
    description: map['description'] as String? ?? '',
    icon: map['icon'] as String? ?? '',
    unlocked: map['unlocked'] == true,
    unlockedAt: _date(map['unlockedAt']),
    rewardCoins: (map['rewardCoins'] as num?)?.toInt() ?? 0,
    seasonId: map['seasonId'] as String?,
    seasonStartAt: _date(map['seasonStartAt']),
    seasonEndAt: _date(map['seasonEndAt']),
    seasonState: map['seasonState'] as String? ?? 'evergreen',
    trigger: map['trigger'] as String?,
  );
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
