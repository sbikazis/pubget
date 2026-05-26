// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/subscription_type.dart';

class UserModel {
  final String id;
  final String email;
  final String username;
  final String? nickname;
  final String avatarUrl;
  final String bio;
  final List<String> favoriteAnimes;
  final int? age;
  final String? country;
  final SubscriptionType subscriptionType;
  final DateTime? premiumSince;
  final DateTime? premiumExpiresAt;
  final bool autoRenewPremium;
  final String? nameColor;
  final int totalRespect;
  final int fansCount;
  final bool isProfileCompleted;
  final bool isBanned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int coinsBalance;
  final int customMaxMembersLimit;
  final int customMaxJoinedGroupsLimit;
  final int customMaxCreatedGroupsLimit;
  final String? invitedBy;
  final bool hasClaimedReferral;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.nickname,
    required this.avatarUrl,
    required this.bio,
    required this.favoriteAnimes,
    this.age,
    this.country,
    required this.subscriptionType,
    this.premiumSince,
    this.premiumExpiresAt,
    this.autoRenewPremium = true,
    this.nameColor,
    required this.totalRespect,
    required this.fansCount,
    required this.isProfileCompleted,
    required this.isBanned,
    required this.createdAt,
    required this.updatedAt,
    this.coinsBalance = 0,
    this.customMaxMembersLimit = 0,
    this.customMaxJoinedGroupsLimit = 0,
    this.customMaxCreatedGroupsLimit = 0,
    this.invitedBy,
    this.hasClaimedReferral = false,
  });

  bool get isPremium => subscriptionType == SubscriptionType.premium && 
                       (premiumExpiresAt?.isAfter(DateTime.now()) ?? false);

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      nickname: map['nickname'],
      avatarUrl: map['avatarUrl'] ?? '',
      bio: map['bio'] ?? '',
      favoriteAnimes: List<String>.from(map['favoriteAnimes'] ?? []),
      age: map['age'],
      country: map['country'],
      subscriptionType: SubscriptionType.fromString(map['subscriptionType'] ?? 'free'),
      premiumSince: map['premiumSince'] != null ? _toDateTime(map['premiumSince']) : null,
      premiumExpiresAt: map['premiumExpiresAt'] != null ? _toDateTime(map['premiumExpiresAt']) : null,
      autoRenewPremium: map['autoRenewPremium'] ?? true,
      nameColor: map['nameColor'],
      totalRespect: map['totalRespect'] ?? 0,
      fansCount: map['fansCount'] ?? 0,
      isProfileCompleted: map['isProfileCompleted'] ?? false,
      isBanned: map['isBanned'] ?? false,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      coinsBalance: map['coinsBalance'] ?? 0,
      customMaxMembersLimit: map['customMaxMembersLimit'] ?? 0,
      customMaxJoinedGroupsLimit: map['customMaxJoinedGroupsLimit'] ?? 0,
      customMaxCreatedGroupsLimit: map['customMaxCreatedGroupsLimit'] ?? 0,
      invitedBy: map['invitedBy'],
      hasClaimedReferral: map['hasClaimedReferral'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'favoriteAnimes': favoriteAnimes,
      'age': age,
      'country': country,
      'subscriptionType': subscriptionType.name,
      'premiumSince': premiumSince,
      'premiumExpiresAt': premiumExpiresAt,
      'autoRenewPremium': autoRenewPremium,
      'nameColor': nameColor,
      'totalRespect': totalRespect,
      'fansCount': fansCount,
      'isProfileCompleted': isProfileCompleted,
      'isBanned': isBanned,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'coinsBalance': coinsBalance,
      'customMaxMembersLimit': customMaxMembersLimit,
      'customMaxJoinedGroupsLimit': customMaxJoinedGroupsLimit,
      'customMaxCreatedGroupsLimit': customMaxCreatedGroupsLimit,
      'invitedBy': invitedBy,
      'hasClaimedReferral': hasClaimedReferral,
    };
  }

  UserModel copyWith({
    String? username,
    String? nickname,
    String? avatarUrl,
    String? bio,
    List<String>? favoriteAnimes,
    int? age,
    String? country,
    SubscriptionType? subscriptionType,
    DateTime? premiumSince,
    DateTime? premiumExpiresAt,
    bool? autoRenewPremium,
    String? nameColor,
    int? totalRespect,
    int? fansCount,
    bool? isProfileCompleted,
    bool? isBanned,
    DateTime? updatedAt,
    int? coinsBalance,
    int? customMaxMembersLimit,
    int? customMaxJoinedGroupsLimit,
    int? customMaxCreatedGroupsLimit,
    String? invitedBy,
    bool? hasClaimedReferral,
  }) {
    return UserModel(
      id: id,
      email: email,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      favoriteAnimes: favoriteAnimes ?? this.favoriteAnimes,
      age: age ?? this.age,
      country: country ?? this.country,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      premiumSince: premiumSince ?? this.premiumSince,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      autoRenewPremium: autoRenewPremium ?? this.autoRenewPremium,
      nameColor: nameColor ?? this.nameColor,
      totalRespect: totalRespect ?? this.totalRespect,
      fansCount: fansCount ?? this.fansCount,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      coinsBalance: coinsBalance ?? this.coinsBalance,
      customMaxMembersLimit: customMaxMembersLimit ?? this.customMaxMembersLimit,
      customMaxJoinedGroupsLimit: customMaxJoinedGroupsLimit ?? this.customMaxJoinedGroupsLimit,
      customMaxCreatedGroupsLimit: customMaxCreatedGroupsLimit ?? this.customMaxCreatedGroupsLimit,
      invitedBy: invitedBy ?? this.invitedBy,
      hasClaimedReferral: hasClaimedReferral ?? this.hasClaimedReferral,
    );
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}