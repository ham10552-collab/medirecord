import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_storage.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return auth.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    final dbUser = await ref.read(authRepositoryProvider).getLocalUser(user.uid);
    if (dbUser != null) return dbUser['role'] as String?;
  }
  return null;
});

final isLoggedInProvider = Provider<bool>((ref) {
  final fbUser = ref.watch(currentUserProvider);
  if (fbUser != null) return true;
  return ref.watch(localSessionProvider).valueOrNull != null;
});

final localSessionProvider = FutureProvider<String?>((ref) async {
  return await AppStorage.read('local_session');
});
