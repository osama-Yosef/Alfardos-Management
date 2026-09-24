import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/audit/audit_entry.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/settings/company_settings.dart';
import '../../auth/domain/app_user.dart';

class SettingsRepository {
  SettingsRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(Col.settings).doc(DocIds.companySettings);

  Stream<CompanySettings> watch() =>
      _doc.snapshots().map((s) => CompanySettings.fromMap(s.data()));

  Future<void> save(CompanySettings before, CompanySettings after, AppUser user) async {
    final batch = _db.batch();
    batch.set(_doc, {
      ...after.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
    final changedBefore = <String, dynamic>{};
    final changedAfter = <String, dynamic>{};
    final a = before.toMap();
    final b = after.toMap();
    for (final k in b.keys) {
      if (a[k] != b[k]) {
        changedBefore[k] = a[k];
        changedAfter[k] = b[k];
      }
    }
    batch.set(_db.collection(Col.auditLogs).doc(), AuditEntry(
      action: AuditAction.update,
      entityType: Col.settings,
      entityId: DocIds.companySettings,
      summary: 'تعديل إعدادات الشركة',
      before: changedBefore,
      after: changedAfter,
    ).toMap(uid: user.uid, userName: user.name));
    await batch.commit();
  }

  /// Uploads the company logo and returns its download URL.
  Future<String> uploadLogo(Uint8List bytes, String extension) async {
    final ref = _storage.ref('company/logo.$extension');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/$extension'));
    return ref.getDownloadURL();
  }
}
