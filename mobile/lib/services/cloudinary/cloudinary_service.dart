import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryUploadResult {
  final String imageUrl;
  final String publicId;

  const CloudinaryUploadResult({
    required this.imageUrl,
    required this.publicId,
  });
}

class CloudinaryService {
  final String cloudName;
  final String uploadPreset;

  const CloudinaryService({
    required this.cloudName,
    required this.uploadPreset,
  });

  Future<CloudinaryUploadResult> uploadImage(
    XFile image,
  ) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        image.path,
      ),
    );

    final streamedResponse = await request.send();
    final response =
        await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Image upload failed. Please try again.',
      );
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    final secureUrl = data['secure_url'] as String?;
    final publicId = data['public_id'] as String?;

    if (secureUrl == null || publicId == null) {
      throw Exception(
        'Invalid response received from image service.',
      );
    }

    return CloudinaryUploadResult(
      imageUrl: secureUrl,
      publicId: publicId,
    );
  }
}