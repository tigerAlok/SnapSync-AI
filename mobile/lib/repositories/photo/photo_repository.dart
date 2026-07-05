import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/photo/photo_model.dart';

class PhotoRepository {
  final FirebaseFirestore _firestore;

  PhotoRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _photos(
    String roomId,
  ) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('photos');
  }

  Future<PhotoModel> savePhoto({
    required String roomId,
    required String imageUrl,
    required String publicId,
    required String uploaderId,
    String? uploaderName,
  }) async {
    final document = _photos(roomId).doc();

    await document.set({
      'roomId': roomId,
      'imageUrl': imageUrl,
      'publicId': publicId,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return PhotoModel(
      id: document.id,
      roomId: roomId,
      imageUrl: imageUrl,
      publicId: publicId,
      uploaderId: uploaderId,
      uploaderName: uploaderName,
      createdAt: DateTime.now(),
    );
  }

  Stream<List<PhotoModel>> watchRoomPhotos(
    String roomId,
  ) {
    return _photos(roomId)
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((document) {
        return PhotoModel.fromMap(
          document.id,
          document.data(),
        );
      }).toList();
    });
  }

  Future<PhotoModel?> getPhoto({
    required String roomId,
    required String photoId,
  }) async {
    final snapshot =
        await _photos(roomId).doc(photoId).get();

    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return PhotoModel.fromMap(
      snapshot.id,
      data,
    );
  }

  Future<void> deletePhotoMetadata({
    required String roomId,
    required String photoId,
  }) async {
    await _photos(roomId).doc(photoId).delete();
  }
}