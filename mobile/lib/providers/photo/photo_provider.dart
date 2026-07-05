import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/photo/photo_model.dart';
import '../../repositories/photo/photo_repository.dart';
import '../../services/cloudinary/cloudinary_service.dart';

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository();
});

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  const cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );

  const uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  if (cloudName.isEmpty || uploadPreset.isEmpty) {
    throw StateError(
      'Cloudinary configuration is missing.',
    );
  }

  return const CloudinaryService(
    cloudName: cloudName,
    uploadPreset: uploadPreset,
  );
});

final roomPhotosProvider = StreamProvider.family<
    List<PhotoModel>, String>((ref, roomId) {
  final repository = ref.watch(photoRepositoryProvider);

  return repository.watchRoomPhotos(roomId);
});

final photoUploadControllerProvider = StateNotifierProvider<
    PhotoUploadController, AsyncValue<void>>((ref) {
  return PhotoUploadController(
    ref.watch(cloudinaryServiceProvider),
    ref.watch(photoRepositoryProvider),
  );
});

class PhotoUploadController
    extends StateNotifier<AsyncValue<void>> {
  final CloudinaryService _cloudinaryService;
  final PhotoRepository _photoRepository;

  PhotoUploadController(
    this._cloudinaryService,
    this._photoRepository,
  ) : super(const AsyncValue.data(null));

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
        final uploadResult =
            await _cloudinaryService.uploadImage(image);

        await _photoRepository.savePhoto(
          roomId: roomId,
          imageUrl: uploadResult.imageUrl,
          publicId: uploadResult.publicId,
          uploaderId: uploaderId,
          uploaderName: uploaderName,
        );
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
}