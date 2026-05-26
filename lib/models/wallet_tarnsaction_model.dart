// lib/models/wallet_transaction_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionModel {
  final String id;
  final int amount; 
  final String type; 
  final DateTime timestamp;
  final String description;

  WalletTransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.timestamp,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
    };
  }

  factory WalletTransactionModel.fromMap(Map<String, dynamic> map) {
    return WalletTransactionModel(
      id: map['id'] ?? '',
      amount: map['amount'] ?? 0,
      type: map['type'] ?? '',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      description: map['description'] ?? '',
    );
  }
}
