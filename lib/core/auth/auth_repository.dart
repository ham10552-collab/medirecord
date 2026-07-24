import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_storage.dart';
import '../database/database_helper.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final DatabaseHelper _db;
  final StreamController<String?> _localSessionController = StreamController<String?>.broadcast();

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    DatabaseHelper? db,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _db = db ?? DatabaseHelper();

  Stream<User?> get authStateChanges {
    try {
      return _firebaseAuth.authStateChanges();
    } catch (_) {
      return _localSessionController.stream.map((email) => null);
    }
  }

  User? get currentUser {
    try {
      return _firebaseAuth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<bool> loginLocally(String email, String displayName, String role) async {
    await AppStorage.write('local_session', email);
    await AppStorage.write('user_email', email);
    await _db.insertUser({
      'id': email.hashCode.toString(),
      'email': email,
      'display_name': displayName,
      'role': role,
      'phone': null,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email, password: password);
    await AppStorage.write('user_email', email);
    return credential;
  }

  Future<UserCredential> createUserWithEmailPassword(
      String email, String password, String displayName, String role) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email, password: password);
    await credential.user?.updateDisplayName(displayName);

    await _db.insertUser({
      'id': credential.user!.uid,
      'email': email,
      'display_name': displayName,
      'role': role,
      'phone': null,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    return credential;
  }

  Future<void> signOut() async {
    try { await _firebaseAuth.signOut(); } catch (_) {}
    await AppStorage.delete('user_email');
    await AppStorage.delete('local_session');
  }

  Future<String?> getSavedEmail() async {
    return await AppStorage.read('user_email');
  }

  Future<Map<String, dynamic>?> getLocalUser(String uid) async {
    return await _db.getUserByEmail(uid);
  }

  Future<bool> isBiometricEnabled() async {
    final value = await AppStorage.read('biometric_enabled');
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      await AppStorage.write('biometric_enabled', 'true');
    } else {
      await AppStorage.delete('biometric_enabled');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }
}
