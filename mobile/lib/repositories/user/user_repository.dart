import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user/app_user.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users {
    return _firestore.collection('users');
  }

  Future<void> createUserIfNotExists(AppUser user) async {
    final document = _users.doc(user.id);
    final snapshot = await document.get();

    if (!snapshot.exists) {
      await document.set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<AppUser?> getUser(String userId) async {
    final snapshot = await _users.doc(userId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return AppUser.fromMap(snapshot.data()!);
  }

  Future<void> updateUser({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    await _users.doc(userId).update(data);
  }

  Stream<AppUser?> watchUser(String userId) {
    return _users.doc(userId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return AppUser.fromMap(data);
    });
  }
}