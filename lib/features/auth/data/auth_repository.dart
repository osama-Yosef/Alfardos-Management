import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/audit/audit_entry.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/settings/company_settings.dart';
import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<AppUser?> watchProfile(String uid) => _db
      .collection(Col.users)
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? AppUser.fromDoc(s) : null);

  Future<bool> isInitialized() async {
    final snap = await _db.collection(Col.meta).doc(DocIds.bootstrap).get();
    return snap.exists;
  }

  Future<void> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    final profile = await _db.collection(Col.users).doc(uid).get();
    if (!profile.exists || profile.data()?['active'] != true) {
      await _auth.signOut();
      throw const AppException(
          'هذا الحساب غير مفعل في النظام. تواصل مع مدير النظام لتفعيله.');
    }
    await _audit(uid, profile.data()?['name'] as String? ?? '', AuditAction.login,
        'تسجيل دخول');
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser!;
    final cred = EmailAuthProvider.credential(email: user.email!, password: current);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(next);
  }

  Future<void> updateOwnProfile({required String name, required String phone}) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection(Col.users).doc(uid).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// First-run setup: creates the administrator account and seeds the
  /// database (roles, company settings, main cashbox, expense categories)
  /// in one atomic batch. Security rules allow this only while
  /// `meta/bootstrap` does not exist, so it can run exactly once.
  Future<void> setupFirstAdmin({
    required String companyName,
    required String currencySymbol,
    required String name,
    required String email,
    required String password,
  }) async {
    if (await isInitialized()) {
      throw const AppException('تم إعداد النظام مسبقاً. سجّل الدخول بحساب المدير.');
    }
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    await cred.user!.updateDisplayName(name.trim());

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    batch.set(_db.collection(Col.meta).doc(DocIds.bootstrap), {
      'adminUid': uid,
      'createdAt': now,
    });

    for (final role in DefaultRoles.all) {
      batch.set(_db.collection(Col.roles).doc(role.id), {
        'name': role.name,
        'permissions': [for (final p in role.permissions) p.id],
        'system': true,
        'createdAt': now,
        'createdBy': uid,
      });
    }

    batch.set(_db.collection(Col.users).doc(uid), {
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
      'phone': '',
      'roleId': DefaultRoles.admin.id,
      'roleName': DefaultRoles.admin.name,
      'permissions': [Permission.admin.id],
      'active': true,
      'createdAt': now,
      'createdBy': uid,
    });

    final cashboxRef = _db.collection(Col.cashboxes).doc();
    batch.set(cashboxRef, {
      'name': 'الخزنة الرئيسية',
      'kind': 'cash',
      'balance': 0,
      'totalIn': 0,
      'totalOut': 0,
      'active': true,
      'notes': '',
      'createdAt': now,
      'createdBy': uid,
    });

    batch.set(
      _db.collection(Col.settings).doc(DocIds.companySettings),
      {
        ...CompanySettings(
          companyName: companyName.trim(),
          currencySymbol: currencySymbol.trim(),
          defaultCashboxId: cashboxRef.id,
        ).toMap(),
        'updatedAt': now,
        'updatedBy': uid,
      },
    );

    const categories = [
      'إيجار', 'كهرباء', 'مياه', 'رواتب', 'مواصلات',
      'صيانة', 'تسويق', 'إنترنت واتصالات', 'أخرى',
    ];
    for (var i = 0; i < categories.length; i++) {
      batch.set(_db.collection(Col.expenseCategories).doc(), {
        'name': categories[i],
        'active': true,
        'order': i,
        'createdAt': now,
        'createdBy': uid,
      });
    }

    batch.set(_db.collection(Col.auditLogs).doc(), AuditEntry(
      action: AuditAction.create,
      entityType: Col.meta,
      entityId: DocIds.bootstrap,
      summary: 'إعداد النظام وإنشاء حساب المدير $email',
    ).toMap(uid: uid, userName: name.trim()));

    try {
      await batch.commit();
    } catch (_) {
      // Leave no orphan auth account if seeding was rejected.
      await cred.user!.delete();
      rethrow;
    }
  }

  Future<void> _audit(String uid, String name, AuditAction action, String summary) async {
    try {
      await _db.collection(Col.auditLogs).add(AuditEntry(
        action: action,
        entityType: Col.users,
        entityId: uid,
        summary: summary,
      ).toMap(uid: uid, userName: name));
    } catch (_) {
      // Login auditing must never block sign-in.
    }
  }
}
