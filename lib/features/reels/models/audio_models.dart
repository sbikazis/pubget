import 'package:cloud_firestore/cloud_firestore.dart';

enum ReelAudioStatus { extracting, ready, failed }

ReelAudioStatus parseAudioStatus(String? raw) {
  return ReelAudioStatus.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => ReelAudioStatus.extracting,
  );
}

final class ReelAudio {
  const ReelAudio({
    required this.audioId,
    required this.creatorId,
    required this.originalReelId,
    required this.name,
    required this.displayName,
    required this.storagePath,
    required this.durationMs,
    required this.startMs,
    required this.usageCount,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.failureReason,
    this.schemaVersion = 1,
    this.creatorName,
    this.creatorAvatar,
  });

  final String audioId;
  final String creatorId;
  final String originalReelId;
  final String name;
  final String displayName;
  final String storagePath;
  final int durationMs;
  final int startMs;
  final int usageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ReelAudioStatus status;
  final String? failureReason;
  final int schemaVersion;
  final String? creatorName;
  final String? creatorAvatar;

  bool get isReady => status == ReelAudioStatus.ready;
  bool get isExtracting => status == ReelAudioStatus.extracting;
  bool get hasFailed => status == ReelAudioStatus.failed;

  String get durationFormatted {
    final seconds = (durationMs / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory ReelAudio.fromMap(Map<String, dynamic> map, {required String id}) {
    return ReelAudio(
      audioId: id,
      creatorId: map['creatorId'] as String? ?? '',
      originalReelId: map['originalReelId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      durationMs: map['durationMs'] as int? ?? 0,
      startMs: map['startMs'] as int? ?? 0,
      usageCount: map['usageCount'] as int? ?? 0,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      status: parseAudioStatus(map['status'] as String?),
      failureReason: map['failureReason'] as String?,
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      creatorName: map['creatorName'] as String?,
      creatorAvatar: map['creatorAvatar'] as String?,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

final class ReelAudioPage {
  const ReelAudioPage(this.items, {this.hasMore = false});
  final List<ReelAudio> items;
  final bool hasMore;
}