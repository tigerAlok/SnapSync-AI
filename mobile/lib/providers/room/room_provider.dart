import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/room/room_model.dart';
import '../../repositories/photo/photo_repository.dart';
import '../../repositories/room/room_repository.dart';
import '../../services/api/api_service.dart';
import '../api/api_service_provider.dart';
import '../auth/auth_provider.dart';
import '../photo/photo_provider.dart';


// =================================================
// ROOM REPOSITORY PROVIDER
// =================================================

final roomRepositoryProvider =
    Provider<RoomRepository>((ref) {
  return RoomRepository();
});


// =================================================
// USER ROOMS STREAM
// =================================================

final userRoomsProvider =
    StreamProvider<List<RoomModel>>((ref) {
  final authState = ref.watch(
    authStateProvider,
  );

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(
          <RoomModel>[],
        );
      }

      final repository = ref.watch(
        roomRepositoryProvider,
      );

      return repository.watchUserRooms(
        user.id,
      );
    },
    loading: () {
      return Stream.value(
        <RoomModel>[],
      );
    },
    error: (_, _) {
      return Stream.value(
        <RoomModel>[],
      );
    },
  );
});


// =================================================
// ROOM DETAILS STREAM
// =================================================

final roomDetailsProvider =
    StreamProvider.family<
        RoomModel?,
        String>((ref, roomId) {
  final repository = ref.watch(
    roomRepositoryProvider,
  );

  return repository.watchRoom(
    roomId,
  );
});


// =================================================
// ROOM CONTROLLER PROVIDER
// =================================================

final roomControllerProvider =
    StateNotifierProvider<
        RoomController,
        AsyncValue<void>>((ref) {
  return RoomController(
    ref.watch(
      roomRepositoryProvider,
    ),
    ref.watch(
      apiServiceProvider,
    ),
    ref.watch(
      photoRepositoryProvider,
    ),
  );
});


// =================================================
// ROOM CONTROLLER
// =================================================

class RoomController
    extends StateNotifier<AsyncValue<void>> {
  final RoomRepository _repository;
  final ApiService _apiService;
  final PhotoRepository _photoRepository;

  RoomController(
    this._repository,
    this._apiService,
    this._photoRepository,
  ) : super(
          const AsyncValue.data(null),
        );


  // =================================================
  // CREATE ROOM
  // =================================================

  Future<RoomModel?> createRoom({
    required String name,
    required String ownerId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final room = await _repository.createRoom(
        name: name,
        ownerId: ownerId,
      );

      state = const AsyncValue.data(
        null,
      );

      return room;
    } catch (error, stackTrace) {
      state = AsyncValue.error(
        error,
        stackTrace,
      );

      return null;
    }
  }


  // =================================================
  // JOIN ROOM
  // =================================================

  Future<RoomModel?> joinRoom({
    required String code,
    required String userId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final room = await _repository.joinRoom(
        code: code,
        userId: userId,
      );

      state = const AsyncValue.data(
        null,
      );

      return room;
    } catch (error, stackTrace) {
      state = AsyncValue.error(
        error,
        stackTrace,
      );

      return null;
    }
  }


  // =================================================
  // LEAVE ROOM
  // =================================================

  Future<bool> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _repository.leaveRoom(
        roomId: roomId,
        userId: userId,
      );

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


  // =================================================
  // DELETE ROOM
  // =================================================

  Future<bool> deleteRoom({
    required String roomId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();

    try {
      // ---------------------------------------------
      // 1. FETCH ALL ROOM PHOTOS
      //
      // This must happen before Firestore deletion,
      // because we need the Cloudinary public IDs.
      // ---------------------------------------------

      final photos =
          await _photoRepository.getRoomPhotos(
        roomId,
      );


      // ---------------------------------------------
      // 2. COLLECT CLOUDINARY PUBLIC IDS
      // ---------------------------------------------

      final publicIds = photos
          .map(
            (photo) => photo.publicId,
          )
          .where(
            (publicId) =>
                publicId.isNotEmpty,
          )
          .toList();


      // ---------------------------------------------
      // 3. DELETE CLOUDINARY ASSETS + AI INDEX
      //
      // Backend deletes:
      //
      // - Cloudinary room images
      // - face_embeddings rows
      // - processed_photos rows
      // ---------------------------------------------

      await _apiService.deleteRoomAssets(
        roomId: roomId,
        publicIds: publicIds,
      );


      // ---------------------------------------------
      // 4. DELETE FIRESTORE ROOM DATA
      //
      // This should remove:
      //
      // - photo metadata
      // - room document
      // - any other room data handled by repository
      // ---------------------------------------------

      await _repository.deleteRoom(
        roomId: roomId,
        userId: userId,
      );


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