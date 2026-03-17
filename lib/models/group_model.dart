import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/group_type.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String slogan;
  final String imageUrl;

  final GroupType type;
  final String? animeName; // Only for roleplay groups

  final String founderId;

  final int membersCount;
  final int maxMembers;

  final bool isPromoted;
  final DateTime? promotionExpiresAt;

  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.slogan,
    required this.imageUrl,
    required this.type,
    this.animeName,
    required this.founderId,
    required this.membersCount,
    required this.maxMembers,
    required this.isPromoted,
    this.promotionExpiresAt,
    required this.createdAt,
  });

  /// Convert Firestore → Model
  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      slogan: map['slogan'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      type: GroupType.fromString(map['type'] ?? 'public'),
      animeName: map['animeName'],
      founderId: map['founderId'] ?? '',
      membersCount: map['membersCount'] ?? 0,
      maxMembers: map['maxMembers'] ?? 100,
      isPromoted: map['isPromoted'] ?? false,
      promotionExpiresAt: map['promotionExpiresAt'] != null
          ? (map['promotionExpiresAt'] as Timestamp).toDate()
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Convert Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'slogan': slogan,
      'imageUrl': imageUrl,
      'type': type.name,
      'animeName': animeName,
      'founderId': founderId,
      'membersCount': membersCount,
      'maxMembers': maxMembers,
      'isPromoted': isPromoted,
      'promotionExpiresAt': promotionExpiresAt,
      'createdAt': createdAt,
    };
  }

  /// Clone with modifications
  GroupModel copyWith({
    String? name,
    String? description,
    String? slogan,
    String? imageUrl,
    GroupType? type,
    String? animeName,
    int? membersCount,
    int? maxMembers,
    bool? isPromoted,
    DateTime? promotionExpiresAt,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      slogan: slogan ?? this.slogan,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      animeName: animeName ?? this.animeName,
      founderId: founderId,
      membersCount: membersCount ?? this.membersCount,
      maxMembers: maxMembers ?? this.maxMembers,
      isPromoted: isPromoted ?? this.isPromoted,
      promotionExpiresAt: promotionExpiresAt ?? this.promotionExpiresAt,
      createdAt: createdAt,
    );
  }
}