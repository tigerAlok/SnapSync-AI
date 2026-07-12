import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/room/room_model.dart';

class RoomRepository {
  final FirebaseFirestore _firestore;

  RoomRepository({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>
      get _rooms {
    return _firestore.collection('rooms');
  }

  CollectionReference<Map<String, dynamic>>
      get _roomCodes {
    return _firestore.collection('roomCodes');
  }

  String _generateRoomCode() {
    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    final random = Random.secure();

    return List.generate(
      6,
      (_) => characters[
          random.nextInt(characters.length)],
    ).join();
  }

  Future<String> _generateUniqueRoomCode() async {
    for (int attempt = 0; attempt < 10; attempt++) {
      final code = _generateRoomCode();

      final codeSnapshot =
          await _roomCodes.doc(code).get();

      if (!codeSnapshot.exists) {
        return code;
      }
    }

    throw Exception(
      'Could not generate a unique room code. '
      'Please try again.',
    );
  }

  Future<RoomModel> createRoom({
    required String name,
    required String ownerId,
  }) async {
    final code = await _generateUniqueRoomCode();

    final roomDocument = _rooms.doc();

    final room = RoomModel(
      id: roomDocument.id,
      name: name,
      code: code,
      ownerId: ownerId,
      memberIds: [ownerId],
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    batch.set(
      roomDocument,
      {
        'name': room.name,
        'code': room.code,
        'ownerId': room.ownerId,
        'memberIds': room.memberIds,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      _roomCodes.doc(code),
      {
        'roomId': roomDocument.id,
      },
    );

    await batch.commit();

    return room;
  }

  Future<RoomModel> joinRoom({
    required String code,
    required String userId,
  }) async {
    final normalizedCode =
        code.trim().toUpperCase();

    final codeSnapshot =
        await _roomCodes.doc(normalizedCode).get();

    final codeData = codeSnapshot.data();

    if (!codeSnapshot.exists || codeData == null) {
      throw Exception(
        'Room not found. Check the code and try again.',
      );
    }

    final roomId =
        codeData['roomId'] as String?;

    if (roomId == null || roomId.isEmpty) {
      throw Exception(
        'Invalid room code.',
      );
    }

    final roomDocument = _rooms.doc(roomId);

    await roomDocument.update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });

    final updatedSnapshot =
        await roomDocument.get();

    final data = updatedSnapshot.data();

    if (data == null) {
      throw Exception(
        'Unable to load room.',
      );
    }

    return RoomModel.fromMap(
      updatedSnapshot.id,
      data,
    );
  }

  Future<RoomModel?> getRoom(
    String roomId,
  ) async {
    final snapshot =
        await _rooms.doc(roomId).get();

    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return RoomModel.fromMap(
      snapshot.id,
      data,
    );
  }

  Stream<List<RoomModel>> watchUserRooms(
    String userId,
  ) {
    return _rooms
        .where(
          'memberIds',
          arrayContains: userId,
        )
        .snapshots()
        .map((snapshot) {
      final rooms = snapshot.docs
          .map(
            (document) =>
                RoomModel.fromMap(
              document.id,
              document.data(),
            ),
          )
          .toList();

      rooms.sort(
        (a, b) =>
            b.createdAt.compareTo(a.createdAt),
      );

      return rooms;
    });
  }

  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    await _rooms.doc(roomId).update({
      'memberIds':
          FieldValue.arrayRemove([userId]),
    });
  }

  Stream<RoomModel?> watchRoom(
    String roomId,
  ) {
    return _rooms
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
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
    final roomDocument =
        _rooms.doc(roomId);

    final roomSnapshot =
        await roomDocument.get();

    final roomData =
        roomSnapshot.data();

    if (!roomSnapshot.exists ||
        roomData == null) {
      throw Exception(
        'Room not found.',
      );
    }

    final ownerId =
        roomData['ownerId'] as String? ?? '';

    if (ownerId != userId) {
      throw Exception(
        'Only the room owner can delete this room.',
      );
    }

    final roomCode =
        roomData['code'] as String? ?? '';

    final photosSnapshot =
        await roomDocument
            .collection('photos')
            .get();

    final batch = _firestore.batch();

    for (final photoDocument
        in photosSnapshot.docs) {
      batch.delete(
        photoDocument.reference,
      );
    }

    if (roomCode.isNotEmpty) {
      batch.delete(
        _roomCodes.doc(roomCode),
      );
    }

    batch.delete(roomDocument);

    await batch.commit();
  }
}