  //user_model
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
    final DateTime? premiumSince; // ✅ مضاف: تاريخ الترقية
    final String? nameColor; // ✅ مضاف: لون الاسم المميز

    final int totalRespect;
    final int fansCount;

    final bool isProfileCompleted;
    final bool isBanned;

    final DateTime createdAt;
    final DateTime updatedAt;

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
      this.nameColor,
      required this.totalRespect,
      required this.fansCount,
      required this.isProfileCompleted,
      required this.isBanned,
      required this.createdAt,
      required this.updatedAt,
    });

    // ✅ Getter ذكي للتحقق من حالة البريميوم بسهولة
    bool get isPremium => subscriptionType == SubscriptionType.premium;

    // =========================================================
    // From Firestore
    // =========================================================
    factory UserModel.fromMap(
      Map<String, dynamic> map,
      String documentId,
    ) {
      return UserModel(
        id: documentId,
        email: map['email'] ?? '',

        username: map['username'] ?? '',
        nickname: map['nickname'],

        avatarUrl: map['avatarUrl'] ?? '',
        bio: map['bio'] ?? '',
        favoriteAnimes:
            List<String>.from(map['favoriteAnimes'] ?? []),

        age: map['age'],
        country: map['country'],

        subscriptionType: SubscriptionType.fromString(
          map['subscriptionType'] ?? 'free',
        ),
        premiumSince: map['premiumSince'] != null ? _toDateTime(map['premiumSince']) : null,
        nameColor: map['nameColor'],

        totalRespect: map['totalRespect'] ?? 0,
        fansCount: map['fansCount'] ?? 0,

        isProfileCompleted:
            map['isProfileCompleted'] ?? false,
        isBanned: map['isBanned'] ?? false,

        createdAt: _toDateTime(map['createdAt']),
        updatedAt: _toDateTime(map['updatedAt']),
      );
    }

    // =========================================================
    // To Firestore
    // =========================================================
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
        'nameColor': nameColor,
        'totalRespect': totalRespect,
        'fansCount': fansCount,
        'isProfileCompleted': isProfileCompleted,
        'isBanned': isBanned,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
    }

    // =========================================================
    // CopyWith
    // =========================================================
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
      String? nameColor,
      int? totalRespect,
      int? fansCount,
      bool? isProfileCompleted,
      bool? isBanned,
      DateTime? updatedAt,
    }) {
      return UserModel(
        id: id,
        email: email,
        username: username ?? this.username,
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        favoriteAnimes:
            favoriteAnimes ?? this.favoriteAnimes,
        age: age ?? this.age,
        country: country ?? this.country,
        subscriptionType:
            subscriptionType ?? this.subscriptionType,
        premiumSince: premiumSince ?? this.premiumSince,
        nameColor: nameColor ?? this.nameColor,
        totalRespect:
            totalRespect ?? this.totalRespect,
        fansCount: fansCount ?? this.fansCount,
        isProfileCompleted:
            isProfileCompleted ?? this.isProfileCompleted,
        isBanned: isBanned ?? this.isBanned,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
    }

    // =========================================================
    // Private Helper
    // =========================================================
    static DateTime _toDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }
  }