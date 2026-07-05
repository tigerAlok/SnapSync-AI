class PhotoModel {
  final String id;
  final String roomId;
  final String imageUrl;
  final String publicId;
  final String uploaderId;
  final String? uploaderName;
  final DateTime createdAt;

  const PhotoModel({
    required this.id,
    required this.roomId,
    required this.imageUrl,
    required this.publicId,
    required this.uploaderId,
    this.uploaderName,
    required this.createdAt,
  });

  factory PhotoModel.fromMap(
    String documentId,
    Map<String, dynamic> map,
  ) {
    return PhotoModel(
      id: documentId,
      roomId: map['roomId'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      publicId: map['publicId'] as String? ?? '',
      uploaderId: map['uploaderId'] as String? ?? '',
      uploaderName: map['uploaderName'] as String?,
      createdAt: map['createdAt'] != null
          ? map['createdAt'].toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'imageUrl': imageUrl,
      'publicId': publicId,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'createdAt': createdAt,
    };
  }
}