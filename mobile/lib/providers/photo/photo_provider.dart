import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/photo/photo_model.dart';
import '../../repositories/photo/photo_repository.dart';
import '../../services/api/api_service.dart';
import '../../services/cloudinary/cloudinary_service.dart';
import '../api/api_service_provider.dart';


// =================================================
// REPOSITORY PROVIDER
// =================================================

final photoRepositoryProvider =
    Provider<PhotoRepository>((ref) {
  return PhotoRepository();
});


// =================================================
// CLOUDINARY PROVIDER
// =================================================

final cloudinaryServiceProvider =
    Provider<CloudinaryService>((ref) {
  const cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );

  const uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  if (cloudName.isEmpty ||
      uploadPreset.isEmpty) {
    throw StateError(
      'Cloudinary configuration is missing.',
    );
  }

  return const CloudinaryService(
    cloudName: cloudName,
    uploadPreset: uploadPreset,
  );
});


// =================================================
// ROOM PHOTOS STREAM
// =================================================

final roomPhotosProvider =
    StreamProvider.family<
        List<PhotoModel>,
        String>((ref, roomId) {
  final repository = ref.watch(
    photoRepositoryProvider,
  );

  return repository.watchRoomPhotos(
    roomId,
  );
});


// =================================================
// PHOTO UPLOAD CONTROLLER PROVIDER
// =================================================

final photoUploadControllerProvider =
    StateNotifierProvider<
        PhotoUploadController,
        AsyncValue<void>>((ref) {
  return PhotoUploadController(
    ref.watch(
      cloudinaryServiceProvider,
    ),
    ref.watch(
      photoRepositoryProvider,
    ),
    ref.watch(
      apiServiceProvider,
    ),
  );
});


// =================================================
// PHOTO BACKFILL CONTROLLER PROVIDER
// =================================================

final photoBackfillControllerProvider =
    StateNotifierProvider<
        PhotoBackfillController,
        AsyncValue<void>>((ref) {
  return PhotoBackfillController(
    ref.watch(
      photoRepositoryProvider,
    ),
    ref.watch(
      apiServiceProvider,
    ),
  );
});


// =================================================
// PHOTO DELETE CONTROLLER PROVIDER
// =================================================

final photoDeleteControllerProvider =
    StateNotifierProvider<
        PhotoDeleteController,
        AsyncValue<void>>((ref) {
  return PhotoDeleteController(
    ref.watch(
      photoRepositoryProvider,
    ),
    ref.watch(
      apiServiceProvider,
    ),
  );
});


// =================================================
// PHOTO UPLOAD CONTROLLER
// =================================================

class PhotoUploadController
    extends StateNotifier<AsyncValue<void>> {
  final CloudinaryService _cloudinaryService;
  final PhotoRepository _photoRepository;
  final ApiService _apiService;

  PhotoUploadController(
    this._cloudinaryService,
    this._photoRepository,
    this._apiService,
  ) : super(
          const AsyncValue.data(null),
        );


  Future<bool> uploadPhotos({
    required List<XFile> images,
    required String roomId,
    required String uploaderId,
    String? uploaderName,
  }) async {
    if (images.isEmpty) {
      return false;
    }

    state = const AsyncValue.loading();

    try {
      for (final image in images) {

        // -----------------------------------------
        // 1. UPLOAD ORIGINAL IMAGE
        // -----------------------------------------

        final uploadResult =
            await _cloudinaryService.uploadImage(
          image,
        );


        // -----------------------------------------
        // 2. SAVE FIRESTORE METADATA
        // -----------------------------------------

        final savedPhoto =
            await _photoRepository.savePhoto(
          roomId: roomId,
          imageUrl: uploadResult.imageUrl,
          publicId: uploadResult.publicId,
          uploaderId: uploaderId,
          uploaderName: uploaderName,
        );


        // -----------------------------------------
        // 3. AI FACE PROCESSING
        // -----------------------------------------

        try {
          final result =
              await _apiService.processRoomPhoto(
            roomId: roomId,
            photoId: savedPhoto.id,
            imageUrl: uploadResult.imageUrl,
          );

          final caption =
              result['caption'] as String?;

          if (caption != null &&
              caption.trim().isNotEmpty) {
            await _photoRepository.updateAiCaption(
              roomId: roomId,
              photoId: savedPhoto.id,
              caption: caption.trim(),
            );
          }

          debugPrint(
            'AI processing completed for '
            '${savedPhoto.id}: '
            '${result['faceCount']} face(s), '
            'caption: $caption',
          );
        } catch (error) {
          // The original upload remains valid even
          // if AI processing temporarily fails.
          //
          // Backfill can process it later.

          debugPrint(
            'AI processing failed for '
            '${savedPhoto.id}: $error',
          );
        }
      }

      state = const AsyncValue.data(
        null,
      );

      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(
        error,
        stackTrace,
      );

      return false;
    }
  }
}


// =================================================
// PHOTO BACKFILL CONTROLLER
// =================================================

class PhotoBackfillController
    extends StateNotifier<AsyncValue<void>> {
  final PhotoRepository _photoRepository;
  final ApiService _apiService;

  PhotoBackfillController(
    this._photoRepository,
    this._apiService,
  ) : super(
          const AsyncValue.data(null),
        );


Future<int> backfillRooms({
  required List<String> roomIds,
}) async {
  if (roomIds.isEmpty) {
    return 0;
  }

  state = const AsyncValue.loading();

  int processedCount = 0;

  try {
    for (final roomId in roomIds) {
      final photos =
          await _photoRepository.getRoomPhotos(
        roomId,
      );

      final faceIndexedPhotoIds =
          await _apiService.getIndexedPhotoIds(
        roomId: roomId,
      );

      final semanticIndexedPhotoIds =
          await _apiService
              .getSemanticIndexedPhotoIds(
        roomId: roomId,
      );


      final categorizedPhotoIds =
          await _apiService
              .getCategorizedPhotoIds(
        roomId: roomId,
      );

      final hashedPhotoIds =
          await _apiService.getHashedPhotoIds(
        roomId: roomId,
      );

      for (final photo in photos) {
        final hasFaceProcessing =
            faceIndexedPhotoIds.contains(
          photo.id,
        );

        final hasSemanticEmbedding =
            semanticIndexedPhotoIds.contains(
          photo.id,
        );

        final hasCaption =
            photo.aiCaption != null &&
            photo.aiCaption!.trim().isNotEmpty;


        final hasCategory =
              categorizedPhotoIds.contains(
            photo.id,
          );

          final hasPhotoHash =
              hashedPhotoIds.contains(
            photo.id,
          );

        // Skip only when all AI processing
        // stages are already complete.
        // Skip only when every AI stage
        // is already complete.
        if (hasFaceProcessing &&
            hasSemanticEmbedding &&
            hasCaption &&
            hasCategory &&
            hasPhotoHash) {
          continue;
        }

        try {
          final result =
              await _apiService.processRoomPhoto(
            roomId: roomId,
            photoId: photo.id,
            imageUrl: photo.imageUrl,
          );

          final caption =
              result['caption'] as String?;

          if (caption != null &&
              caption.trim().isNotEmpty) {
            await _photoRepository.updateAiCaption(
              roomId: roomId,
              photoId: photo.id,
              caption: caption.trim(),
            );
          }

          processedCount++;

          debugPrint(
            'Backfill processed photo: '
            '${photo.id}, caption: $caption',
          );
        } catch (error) {
          debugPrint(
            'Backfill failed for '
            '${photo.id}: $error',
          );
        }
      }
    }

    state = const AsyncValue.data(null);

    return processedCount;
  } catch (error, stackTrace) {
    state = AsyncValue.error(
      error,
      stackTrace,
    );

    return processedCount;
  }
}
}


// =================================================
// PHOTO DELETE CONTROLLER
// =================================================

class PhotoDeleteController
    extends StateNotifier<AsyncValue<void>> {
  final PhotoRepository _photoRepository;
  final ApiService _apiService;

  PhotoDeleteController(
    this._photoRepository,
    this._apiService,
  ) : super(
          const AsyncValue.data(null),
        );


  Future<bool> deletePhotos({
    required List<PhotoModel> photos,
  }) async {
    if (photos.isEmpty) {
      return false;
    }

    state = const AsyncValue.loading();

    try {
      for (final photo in photos) {

        // -----------------------------------------
        // 1. BACKEND CLEANUP
        //
        // FastAPI deletes:
        //
        // - Cloudinary image
        // - face_embeddings rows
        // - processed_photos row
        // -----------------------------------------

        await _apiService.deletePhoto(
          roomId: photo.roomId,
          photoId: photo.id,
          publicId: photo.publicId,
        );


        // -----------------------------------------
        // 2. DELETE FIRESTORE METADATA
        // -----------------------------------------

        await _photoRepository.deletePhotoMetadata(
          roomId: photo.roomId,
          photoId: photo.id,
        );


        debugPrint(
          'Photo deleted successfully: '
          '${photo.id}',
        );
      }

      state = const AsyncValue.data(
        null,
      );

      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(
        error,
        stackTrace,
      );

      debugPrint(
        'Photo deletion failed: $error',
      );

      return false;
    }
  }
}