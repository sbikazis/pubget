import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/edits_model.dart';
import '../../models/edit_interaction_model.dart';
import '../../core/logic/feed_ranking_logic.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════
  // ── تسجيل تفاعل المستخدم
  // ══════════════════════════════════════════════

  Future<void> recordInteraction(EditInteractionModel interaction) async {
    try {
      await _firestore
          .collection('user_interactions')
          .doc(interaction.userId)
          .collection('interactions')
          .add(interaction.toMap());
    } catch (e) {
      debugPrint('❌ FeedService.recordInteraction: $e');
    }
  }

  // ══════════════════════════════════════════════
  // ── جلب تفاعلات المستخدم (لبناء بصمة الاهتمام)
  // ── آخر 100 تفاعل فقط للكفاءة
  // ══════════════════════════════════════════════

  Future<List<EditInteractionModel>> getUserInteractions(String userId) async {
    try {
      final snap = await _firestore
          .collection('user_interactions')
          .doc(userId)
          .collection('interactions')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snap.docs
          .map((doc) => EditInteractionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ FeedService.getUserInteractions: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════
  // ── جلب قائمة المشاهَد من Firestore
  // ── مع استثناء ما شوهد منذ أكثر من 30 يوماً
  // ══════════════════════════════════════════════

  Future<List<String>> getSeenIds(String userId) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final snap = await _firestore
          .collection('user_seen')
          .doc(userId)
          .collection('seen_edits')
          .where('seenAt', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      return snap.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('❌ FeedService.getSeenIds: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════
  // ── تسجيل إيديت كـ "مشاهَد" في Firestore
  // ══════════════════════════════════════════════

  Future<void> markAsSeen(String userId, String editId) async {
    try {
      await _firestore
          .collection('user_seen')
          .doc(userId)
          .collection('seen_edits')
          .doc(editId)
          .set({'seenAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('❌ FeedService.markAsSeen: $e');
    }
  }

  // ══════════════════════════════════════════════
  // ── جلب الـ Feed الذكي الكامل
  // ══════════════════════════════════════════════

  Future<List<EditModel>> fetchSmartFeed({
    required String userId,
    required List<String> seenIds,
  }) async {
    try {
      // 1. جلب الإيديتات الأخيرة (50 كحد أقصى)
      final snap = await _firestore
          .collection('edits')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final all = snap.docs
          .map((doc) => EditModel.fromFirestore(doc))
          .toList();

      // 2. فصل المشاهَدة (مع السماح بما مضى عليه 30 يوم — تتكفل getSeenIds بذلك)
      final unseen = all.where((e) => !seenIds.contains(e.id)).toList();

      if (unseen.isEmpty) return [];

      // 3. جلب تفاعلات المستخدم
      final interactions = await getUserInteractions(userId);

      // 4. Cold Start أو تخصيص؟
      if (!FeedRankingLogic.isPastColdStart(interactions)) {
        // مستخدم جديد → أفضل الإيديتات عالمياً
        final ranked = FeedRankingLogic.coldStartRank(unseen);
        return ranked.take(10).toList();
      }

      // 5. بناء بصمة الاهتمام
      final animeMap =
          FeedRankingLogic.buildAnimeInterestMap(interactions);
      final uploaderMap =
          FeedRankingLogic.buildUploaderInterestMap(interactions);

      // 6. ترتيب مخصص مع التنوع
      return FeedRankingLogic.rankAndDiversify(unseen, animeMap, uploaderMap);
    } catch (e) {
      debugPrint('❌ FeedService.fetchSmartFeed: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════
  // ── مسح قائمة المشاهَد (عند "عرض من البداية")
  // ── مع معالجة حد الـ 500 عملية لكل batch
  // ══════════════════════════════════════════════

  Future<void> clearSeenIds(String userId) async {
    try {
      const batchLimit = 500;
      final Query query = _firestore
          .collection('user_seen')
          .doc(userId)
          .collection('seen_edits')
          .limit(batchLimit);

      while (true) {
        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (snap.docs.length < batchLimit) break;
      }
    } catch (e) {
      debugPrint('❌ FeedService.clearSeenIds: $e');
    }
  }
}