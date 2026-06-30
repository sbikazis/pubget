import 'package:cloud_firestore/cloud_firestore.dart';

class PhysicalProductModel {
  final String id;
  final String name;
  final String imageUrl;
  final String affiliateUrl;
  final String price;
  final double? rating; // null = "non" (لا يوجد تقييم)
  final int order;
  final bool isActive;
  final DateTime? createdAt;

  PhysicalProductModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.affiliateUrl,
    required this.price,
    this.rating,
    this.order = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory PhysicalProductModel.fromMap(String id, Map<String, dynamic> map) {
    return PhysicalProductModel(
      id: id,
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      affiliateUrl: map['affiliateUrl'] ?? '',
      price: map['price'] ?? '',
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      order: map['order'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'affiliateUrl': affiliateUrl,
      'price': price,
      'rating': rating,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}