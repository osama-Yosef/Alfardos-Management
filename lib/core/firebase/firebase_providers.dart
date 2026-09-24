import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../ledger/ledger_service.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final storageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

/// The accounting engine bound to the signed-in user.
final ledgerProvider = Provider<LedgerService>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw StateError('Ledger used without a signed-in user');
  return LedgerService(
    ref.watch(firestoreProvider),
    LedgerActor(uid: user.uid, name: user.name),
  );
});

/// True while Firestore is serving from local cache only (no connection).
/// Uses a lightweight listener on the settings document with metadata.
final offlineProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(firestoreProvider);
  if (ref.watch(currentUserProvider) == null) return Stream.value(false);
  return db
      .collection('settings')
      .doc('company')
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.metadata.isFromCache);
});
