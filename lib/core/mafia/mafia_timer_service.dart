import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaTimerService {
  final FirebaseFirestore _firestore;

  MafiaTimerService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  int remainingSeconds(DateTime? endsAt) {
    if (endsAt == null) return 0;
    final now = DateTime.now().toUtc();
    return endsAt.toUtc().difference(now).inSeconds.clamp(0, 999999);
  }
}
