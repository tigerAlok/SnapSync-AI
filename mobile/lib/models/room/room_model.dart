class RoomModel {
  final String id;
  final String name;
  final String code;
  final String ownerId;
  final List<String> memberIds;
  final DateTime createdAt;

  const RoomModel({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerId,
    required this.memberIds,
    required this.createdAt,
  });

  factory RoomModel.fromMap(
    String documentId,
    Map<String, dynamic> map,
  ) {
    return RoomModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      memberIds: List<String>.from(
        map['memberIds'] ?? [],
      ),
      createdAt: map['createdAt'] != null
          ? map['createdAt'].toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'createdAt': createdAt,
    };
  }

  RoomModel copyWith({
    String? id,
    String? name,
    String? code,
    String? ownerId,
    List<String>? memberIds,
    DateTime? createdAt,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}