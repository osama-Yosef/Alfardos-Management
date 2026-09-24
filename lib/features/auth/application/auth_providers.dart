import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(authProvider), ref.watch(firestoreProvider)),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authProvider).authStateChanges(),
);

/// Live profile of the signed-in user (null when signed out or missing).
final userProfileProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(user.uid);
});

final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(userProfileProvider).value,
);

/// Whether the first administrator has been created.
final systemInitializedProvider = FutureProvider<bool>(
  (ref) => ref.watch(authRepositoryProvider).isInitialized(),
);

/// Permission check usable from widgets: `ref.watch(canProvider(Permission.x))`.
final canProvider = Provider.family<bool, Permission>((ref, permission) {
  return ref.watch(currentUserProvider)?.can(permission) ?? false;
});
