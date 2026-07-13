import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiService {
  static const String baseUrl =
      'http://192.168.31.212:8000';

  // -------------------------------------------------
  // HEALTH CHECK
  // -------------------------------------------------

  Future<bool> checkHealth() async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/health',
          ),
        )
        .timeout(
          const Duration(seconds: 10),
        );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    return data['status'] == 'ok';
  }

  // -------------------------------------------------
  // REFERENCE SELFIE + FACE SEARCH
  // -------------------------------------------------

  Future<Map<String, dynamic>> uploadReferenceSelfie({
    required XFile selfie,
    required List<String> roomIds,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/face/reference',
    ).replace(
      queryParameters: {
        'room_ids': roomIds.join(','),
      },
    );

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'selfie',
        selfie.path,
      ),
    );

    final streamedResponse = await request
        .send()
        .timeout(
          const Duration(seconds: 60),
        );

    final response =
        await http.Response.fromStream(
      streamedResponse,
    );

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Unable to search for matching photos.',
      );
    }

    return data;
  }

  // -------------------------------------------------
  // PROCESS ROOM PHOTO
  // -------------------------------------------------

  Future<Map<String, dynamic>> processRoomPhoto({
    required String roomId,
    required String photoId,
    required String imageUrl,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/process',
    ).replace(
      queryParameters: {
        'room_id': roomId,
        'photo_id': photoId,
        'image_url': imageUrl,
      },
    );

    final response = await http
        .post(uri)
        .timeout(
          const Duration(seconds: 60),
        );

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Unable to process room photo.',
      );
    }

    return data;
  }



  // --------------------------------------------------
  // GET QUALITY-INDEXED PHOTO IDS
  // --------------------------------------------------

  Future<List<String>> getQualityIndexedPhotoIds({
    required String roomId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/quality-indexed',
    ).replace(
      queryParameters: {
        'room_id': roomId,
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load quality index status.',
      );
    }

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    final photoIds =
        data['photoIds'] as List<dynamic>? ?? [];

    return photoIds
        .map(
          (id) => id.toString(),
        )
        .toList();
  }




  // --------------------------------------------------
  // PROCESS PHOTO QUALITY
  // --------------------------------------------------

  Future<void> processPhotoQuality({
    required String roomId,
    required String photoId,
    required String imageUrl,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/quality',
    ).replace(
      queryParameters: {
        'room_id': roomId,
        'photo_id': photoId,
        'image_url': imageUrl,
      },
    );

    final response = await http
        .post(uri)
        .timeout(
          const Duration(seconds: 60),
        );

    if (response.statusCode != 200) {
      String message =
          'Unable to process photo quality.';

      try {
        final data = jsonDecode(
          response.body,
        ) as Map<String, dynamic>;

        message =
            data['detail'] as String? ??
                message;
      } catch (_) {
        // Keep fallback message.
      }

      throw Exception(message);
    }
  }


    Future<Map<String, dynamic>> searchPhotos({
    required String query,
    required List<String> roomIds,
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/search',
    ).replace(
      queryParameters: {
        'query': query,
        'room_ids': roomIds.join(','),
        'limit': limit.toString(),
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 60),
        );

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Unable to search photos.',
      );
    }

    return data;
  }

    Future<Map<String, dynamic>> getCategoryPhotos({
    required String category,
    required List<String> roomIds,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/category',
    ).replace(
      queryParameters: {
        'category': category,
        'room_ids': roomIds.join(','),
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 60),
        );

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Unable to load category photos.',
      );
    }

    return data;
  }

    Future<Map<String, dynamic>> getSimilarPhotos({
    required String roomId,
    required String photoId,
    required List<String> roomIds,
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/similar',
    ).replace(
      queryParameters: {
        'room_id': roomId,
        'photo_id': photoId,
        'room_ids': roomIds.join(','),
        'limit': limit.toString(),
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 60),
        );

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Unable to find similar photos.',
      );
    }

    return data;
  }



  Future<Map<String, dynamic>> getDuplicatePhotos({
    required String roomId,
    required String photoId,
    required List<String> roomIds,
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/duplicates',
    ).replace(
      queryParameters: {
        'room_id': roomId,
        'photo_id': photoId,
        'room_ids': roomIds.join(','),
        'limit': limit.toString(),
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 60),
        );

    if (response.statusCode != 200) {
      try {
        final errorData = jsonDecode(
          response.body,
        ) as Map<String, dynamic>;

        throw Exception(
          errorData['detail'] ??
              'Unable to find duplicate photos.',
        );
      } on FormatException {
        throw Exception(
          'Backend error '
          '(${response.statusCode}): '
          '${response.body}',
        );
      }
    }

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    return data;
  }



  Future<Map<String, dynamic>> getDuplicateGroups({
    required List<String> roomIds,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/duplicate-groups',
    ).replace(
      queryParameters: {
        'room_ids': roomIds.join(','),
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(minutes: 3),
        );

    if (response.statusCode != 200) {
      try {
        final errorData = jsonDecode(
          response.body,
        ) as Map<String, dynamic>;

        throw Exception(
          errorData['detail'] ??
              'Unable to load duplicate groups.',
        );
      } on FormatException {
        throw Exception(
          'Backend error '
          '(${response.statusCode}): '
          '${response.body}',
        );
      }
    }

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    return data;
  }





  


  // -------------------------------------------------
  // DELETE ONE PHOTO FROM AI INDEX
  // -------------------------------------------------

  Future<void> deletePhotoIndex({
    required String roomId,
    required String photoId,
    required String publicId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/index',
    ).replace(
      queryParameters: {
        'room_id': roomId,
        'photo_id': photoId,
        'public_id': publicId,
      },
    );

    final response = await http
        .delete(uri)
        .timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode != 200) {
      String message =
          'Unable to delete photo.';

      try {
        final data = jsonDecode(
          response.body,
        ) as Map<String, dynamic>;

        message =
            data['detail'] as String? ??
                message;
      } catch (_) {
        // Keep fallback message.
      }

      throw Exception(message);
    }
  }

  // -------------------------------------------------
  // DELETE ENTIRE ROOM FROM AI INDEX
  // -------------------------------------------------

  Future<void> deleteRoomIndex({
    required String roomId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/rooms/index',
    ).replace(
      queryParameters: {
        'room_id': roomId,
      },
    );

    final response = await http
        .delete(uri)
        .timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode != 200) {
      String message =
          'Unable to delete room AI index.';

      try {
        final data = jsonDecode(
          response.body,
        ) as Map<String, dynamic>;

        message =
            data['detail'] as String? ?? message;
      } catch (_) {
        // Keep fallback message.
      }

      throw Exception(message);
    }
  }

    Future<Set<String>> getIndexedPhotoIds({
    required String roomId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/rooms/indexed-photos',
    ).replace(
      queryParameters: {
        'room_id': roomId,
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 30),
        );

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Unable to read indexed photos.',
      );
    }

    final rawPhotoIds =
        data['photoIds'] as List<dynamic>? ?? [];

    return rawPhotoIds
        .map(
          (photoId) => photoId.toString(),
        )
        .toSet();
  }
  Future<Set<String>> getSemanticIndexedPhotoIds({
  required String roomId,
}) async {
  final uri = Uri.parse(
    '$baseUrl/api/v1/photos/semantic-indexed',
  ).replace(
    queryParameters: {
      'room_id': roomId,
    },
  );

  final response = await http
      .get(uri)
      .timeout(
        const Duration(seconds: 30),
      );

  final data = jsonDecode(
    response.body,
  ) as Map<String, dynamic>;

  if (response.statusCode != 200) {
    throw Exception(
      data['detail'] ??
          'Unable to load semantic index status.',
    );
  }

  final rawPhotoIds =
      data['photoIds'] as List<dynamic>? ?? [];

  return rawPhotoIds
      .map(
        (photoId) => photoId.toString(),
      )
      .toSet();
}


  Future<Set<String>> getCategorizedPhotoIds({
    required String roomId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/categorized',
    ).replace(
      queryParameters: {
        'room_id': roomId,
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 30),
        );

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Unable to load category status.',
      );
    }

    final rawPhotoIds =
        data['photoIds'] as List<dynamic>? ?? [];

    return rawPhotoIds
        .map(
          (photoId) => photoId.toString(),
        )
        .toSet();
  }


  Future<Set<String>> getHashedPhotoIds({
    required String roomId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos/hashed',
    ).replace(
      queryParameters: {
        'room_id': roomId,
      },
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 30),
        );

    final data = jsonDecode(
      response.body,
    ) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Unable to load photo hash status.',
      );
    }

    final rawPhotoIds =
        data['photoIds'] as List<dynamic>? ?? [];

    return rawPhotoIds
        .map(
          (photoId) => photoId.toString(),
        )
        .toSet();
  }






    Future<void> deletePhoto({
    required String roomId,
    required String photoId,
    required String publicId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/photos',
    ).replace(
      queryParameters: {
        'room_id': roomId,
        'photo_id': photoId,
        'public_id': publicId,
      },
    );

    final response = await http
        .delete(uri)
        .timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode != 200) {
      String message =
          'Unable to delete photo.';

      try {
        final data = jsonDecode(
          response.body,
        ) as Map<String, dynamic>;

        message =
            data['detail'] as String? ??
                message;
      } catch (_) {
        // Keep fallback message.
      }

      throw Exception(message);
    }
  }
    Future<void> deleteRoomAssets({
    required String roomId,
    required List<String> publicIds,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/rooms/delete-assets',
    ).replace(
      queryParameters: {
        'room_id': roomId,
      },
    );

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'public_ids': publicIds,
          }),
        )
        .timeout(
          const Duration(seconds: 120),
        );

    if (response.statusCode != 200) {
      String message =
          'Unable to delete room assets.';

      try {
        final data = jsonDecode(
          response.body,
        ) as Map<String, dynamic>;

        message =
            data['detail'] as String? ??
                message;
      } catch (_) {
        // Keep fallback message.
      }

      throw Exception(message);
    }
  }
}   