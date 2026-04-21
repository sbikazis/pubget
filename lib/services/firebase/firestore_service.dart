//firestore_service
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? instance})
      : _firestore = instance ?? FirebaseFirestore.instance;

  // ==============================
  // CREATE
  // ==============================

  Future<void> createDocument({
    required String path,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final docRef = _firestore.collection(path).doc(docId);
    await docRef.set(data);
  }

  // ==============================
  // UPDATE
  // ==============================

  Future<void> updateDocument({
    required String path,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final docRef = _firestore.collection(path).doc(docId);
    await docRef.update(data);
  }

  // ==============================
  // DELETE
  // ==============================

  Future<void> deleteDocument({
    required String path,
    required String docId,
  }) async {
    final docRef = _firestore.collection(path).doc(docId);
    await docRef.delete();
  }

  // ==============================
  // GET SINGLE DOCUMENT
  // ==============================

  Future<Map<String, dynamic>?> getDocument({
    required String path,
    required String docId,
  }) async {
    final docRef = _firestore.collection(path).doc(docId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return null;

    return snapshot.data();
  }

  // ==============================
  // STREAM SINGLE DOCUMENT
  // ==============================

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocument({
    required String path,
    required String docId,
  }) {
    return _firestore.collection(path).doc(docId).snapshots();
  }

  // ==============================
  // STREAM COLLECTION
  // ==============================

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection({
    required String path,
    Query<Map<String, dynamic>>? query,
  }) {
    if (query != null) {
      return query.snapshots();
    }
    return _firestore.collection(path).snapshots();
  }

  // ==============================
  // GET COLLECTION ONCE
  // ==============================

  Future<QuerySnapshot<Map<String, dynamic>>> getCollection({
    required String path,
    Query<Map<String, dynamic>>? query,
  }) async {
    if (query != null) {
      return query.get();
    }
    return _firestore.collection(path).get();
  }

  // ==============================
  // QUERY BUILDER
  // ==============================

  Query<Map<String, dynamic>> buildQuery({
    required String path,
    List<QueryCondition>? conditions,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(path);

    if (conditions != null) {
      for (final condition in conditions) {
        query = query.where(
          condition.field,
          isEqualTo: condition.isEqualTo,
          isNotEqualTo: condition.isNotEqualTo,
          isLessThan: condition.isLessThan,
          isLessThanOrEqualTo: condition.isLessThanOrEqualTo, // 🔥 تم الإضافة
          isGreaterThan: condition.isGreaterThan,
          isGreaterThanOrEqualTo: condition.isGreaterThanOrEqualTo, // 🔥 تم الإضافة
          arrayContains: condition.arrayContains,
        );
      }
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query;
  }

  // ==============================
  // TRANSACTION
  // ==============================

  Future<void> runTransaction(
    Future<void> Function(Transaction transaction) action,
  ) async {
    await _firestore.runTransaction(action);
  }

  // ==============================
  // BATCH WRITE
  // ==============================

  Future<void> runBatch(
    Future<void> Function(WriteBatch batch) action,
  ) async {
    final batch = _firestore.batch();
    await action(batch);
    await batch.commit();
  }
}

// ==================================
// QUERY CONDITION HELPER CLASS
// ==================================

class QueryCondition {
  final String field;
  final dynamic isEqualTo;
  final dynamic isNotEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo; // 🔥 تم الإضافة
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo; // 🔥 تم الإضافة
  final dynamic arrayContains;

  QueryCondition({
    required this.field,
    this.isEqualTo,
    this.isNotEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo, // 🔥 تم الإضافة
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo, // 🔥 تم الإضافة
    this.arrayContains,
  });
}