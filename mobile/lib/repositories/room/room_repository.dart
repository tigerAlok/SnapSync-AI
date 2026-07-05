import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/room/room_model.dart';

class RoomRepository {
  final FirebaseFirestore _firestore;

  RoomRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rooms {
    return _firestore.collection('rooms');
  }

  // Generate a random 6-character room code
  String _generateRoomCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    return List.generate(
      6,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  // Generate a code that doesn't already exist
  Future<String> _generateUniqueRoomCode() async {
    for (int attempt = 0; attempt < 10; attempt++) {
      final code = _generateRoomCode();

      final result = await _rooms
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (result.docs.isEmpty) {
        return code;
      }
    }

    throw Exception(
      'Could not generate a unique room code. Please try again.',
    );
  }

  // Create a new room
  Future<RoomModel> createRoom({
    required String name,
    required String ownerId,
  }) async {
    final code = await _generateUniqueRoomCode();
    final document = _rooms.doc();

    final room = RoomModel(
      id: document.id,
      name: name,
      code: code,
      ownerId: ownerId,
      memberIds: [ownerId],
      createdAt: DateTime.now(),
    );

    await document.set({
      'name': room.name,
      'code': room.code,
      'ownerId': room.ownerId,
      'memberIds': room.memberIds,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return room;
  }

  // Join a room using its code
  Future<RoomModel> joinRoom({
    required String code,
    required String userId,
  }) async {
    final normalizedCode = code.trim().toUpperCase();

    final result = await _rooms
        .where('code', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      throw Exception('Room not found. Check the code and try again.');
    }

    final document = result.docs.first;

    await document.reference.update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });

    final updatedSnapshot = await document.reference.get();
    final data = updatedSnapshot.data();

    if (data == null) {
      throw Exception('Unable to load room.');
    }

    return RoomModel.fromMap(
      updatedSnapshot.id,
      data,
    );
  }

  // Get one room
  Future<RoomModel?> getRoom(String roomId) async {
    final snapshot = await _rooms.doc(roomId).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return RoomModel.fromMap(
      snapshot.id,
      data,
    );
  }

  // Watch all rooms belonging to a user
  Stream<List<RoomModel>> watchUserRooms(String userId) {
    return _rooms
        .where(
          'memberIds',
          arrayContains: userId,
        )
        .snapshots()
        .map((snapshot) {
      final rooms = snapshot.docs
          .map(
            (document) => RoomModel.fromMap(
              document.id,
              document.data(),
            ),
          )
          .toList();

      rooms.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return rooms;
    });
  }

  // Leave a room
  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    await _rooms.doc(roomId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
    });
  }

    Stream<RoomModel?> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return RoomModel.fromMap(
        snapshot.id,
        data,
      );
    });
  }
    Future<void> deleteRoom({
    required String roomId,
    required String userId,
  }) async {
    final roomDocument = _rooms.doc(roomId);
    final roomSnapshot = await roomDocument.get();

    final roomData = roomSnapshot.data();

    if (!roomSnapshot.exists || roomData == null) {
      throw Exception('Room not found.');
    }

    final ownerId = roomData['ownerId'] as String? ?? '';

    if (ownerId != userId) {
      throw Exception(
        'Only the room owner can delete this room.',
      );
    }

    // Delete photo metadata stored inside the room.
    final photosSnapshot = await roomDocument
        .collection('photos')
        .get();

    final batch = _firestore.batch();

    for (final photoDocument in photosSnapshot.docs) {
      batch.delete(photoDocument.reference);
    }

    batch.delete(roomDocument);

    await batch.commit();
  }
}