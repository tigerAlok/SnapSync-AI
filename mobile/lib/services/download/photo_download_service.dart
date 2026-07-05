import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

class PhotoDownloadService {
  Future<void> savePhotoToGallery(
    String imageUrl,
  ) async {
    final response = await http.get(
      Uri.parse(imageUrl),
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Unable to download photo.',
      );
    }

    final Uint8List imageBytes = response.bodyBytes;

    final hasAccess = await Gal.hasAccess();

    if (!hasAccess) {
      await Gal.requestAccess();
    }

    await Gal.putImageBytes(
      imageBytes,
      name:
          'snapsync_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}