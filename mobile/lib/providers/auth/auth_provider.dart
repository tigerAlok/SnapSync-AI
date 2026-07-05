import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user/app_user.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../repositories/user/user_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(userRepositoryProvider),
  );
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;
  final UserRepository _userRepository;

  AuthController(
    this._repository,
    this._userRepository,
  ) : super(const AsyncValue.data(null));

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _repository.signInWithEmail(
        email: email,
        password: password,
      );

      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();

    try {
      final user = await _repository.signUpWithEmail(
        email: email,
        password: password,
      );

      await _userRepository.createUserIfNotExists(user);

      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _repository.sendPasswordResetEmail(
        email: email,
      );

      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncValue.loading();

    try {
      final user = await _repository.signInWithGoogle();

      await _userRepository.createUserIfNotExists(user);

      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();

    try {
      await _repository.signOut();

      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}