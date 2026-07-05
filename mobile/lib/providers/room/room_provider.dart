import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/room/room_model.dart';
import '../../repositories/room/room_repository.dart';
import '../auth/auth_provider.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository();
});

final userRoomsProvider =
    StreamProvider<List<RoomModel>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value([]);
      }

      final repository = ref.watch(roomRepositoryProvider);

      return repository.watchUserRooms(user.id);
    },
    loading: () => Stream.value([]),
    error: (_, _) => Stream.value([]),
  );
});

final roomDetailsProvider =
    StreamProvider.family<RoomModel?, String>((ref, roomId) {
  final repository = ref.watch(roomRepositoryProvider);

  return repository.watchRoom(roomId);
});

final roomControllerProvider =
    StateNotifierProvider<RoomController, AsyncValue<void>>(
  (ref) {
    return RoomController(
      ref.watch(roomRepositoryProvider),
    );
  },
);

class RoomController extends StateNotifier<AsyncValue<void>> {
  final RoomRepository _repository;

  RoomController(this._repository)
      : super(const AsyncValue.data(null));

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

      state = const AsyncValue.data(null);

      return room;
    } catch (error, stackTrace) {
      state = AsyncValue.error(
        error,
        stackTrace,
      );

      return null;
    }
  }

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

      state = const AsyncValue.data(null);

      return room;
    } catch (error, stackTrace) {
      state = AsyncValue.error(
        error,
        stackTrace,
      );

      return null;
    }
  }

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

      state = const AsyncValue.data(null);

      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(
        error,
        stackTrace,
      );

      return false;
    }
  }
  Future<bool> deleteRoom({
  required String roomId,
  required String userId,
}) async {
  state = const AsyncValue.loading();

  try {
    await _repository.deleteRoom(
      roomId: roomId,
      userId: userId,
    );

    state = const AsyncValue.data(null);
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