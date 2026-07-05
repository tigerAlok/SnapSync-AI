import 'package:firebase_auth/firebase_auth.dart';

import '../../core/exceptions/auth_exception.dart';
import '../../models/user/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  // Convert Firebase User to our AppUser model
  AppUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;

    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  // Current logged-in user
  AppUser? get currentUser {
    return _mapFirebaseUser(_firebaseAuth.currentUser);
  }

  // Listen for login/logout changes
  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapFirebaseUser);
  }

  // Register with email and password
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = _mapFirebaseUser(credential.user);

      if (user == null) {
        throw const AuthException(
          'Account creation failed. Please try again.',
        );
      }

      return user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_getErrorMessage(error.code));
    }
  }

  // Login with email and password
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = _mapFirebaseUser(credential.user);

      if (user == null) {
        throw const AuthException(
          'Login failed. Please try again.',
        );
      }

      return user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_getErrorMessage(error.code));
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(
        email: email.trim(),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_getErrorMessage(error.code));
    }
  }

  // Logout
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<AppUser> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser =
        await GoogleSignIn().signIn();

    if (googleUser == null) {
      throw const AuthException(
        'Google Sign-In was cancelled.',
      );
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _firebaseAuth.signInWithCredential(credential);

    final user = _mapFirebaseUser(userCredential.user);

    if (user == null) {
      throw const AuthException(
        'Google Sign-In failed. Please try again.',
      );
    }

    return user;
  } on FirebaseAuthException catch (error) {
    throw AuthException(_getErrorMessage(error.code));
  } on AuthException {
    rethrow;
  } catch (_) {
    throw const AuthException(
      'Google Sign-In failed. Please try again.',
    );
  }
}

  // Convert Firebase error codes into readable messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'weak-password':
        return 'Password must be at least 6 characters long.';

      case 'email-already-in-use':
        return 'An account already exists with this email.';

      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'Please check your internet connection.';

      default:
        return 'Authentication failed. Please try again.';
    }
  }
}