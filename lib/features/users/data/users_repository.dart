import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/audit/audit_entry.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/firebase/collections.dart';
import '../../auth/domain/app_user.dart';

class Role {
  const Role({required this.id, required this.name, required this.permissions, this.system = false});

  final String id;
  final String name;
  final Set<String> permissions;
  final bool system;

  factory Role.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return Role(
      id: d.id,
      name: m['name'] as String? ?? '',
      permissions: ((m['permissions'] as List?) ?? const []).cast<String>().toSet(),
      system: m['system'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) => other is Role && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Users and roles.
///
/// A user's permissions are copied from their role onto `users/{uid}` so
/// security rules need a single read per request. Changing a role's
/// permissions rewrites every user holding that role in the same batch.
class UsersRepository {
  UsersRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection(Col.users);
  CollectionReference<Map<String, dynamic>> get _roles => _db.collection(Col.roles);

  Stream<List<AppUser>> watchUsers() =>
      _users.orderBy('name').snapshots().map((s) => s.docs.map(AppUser.fromDoc).toList());

  Stream<List<Role>> watchRoles() =>
      _roles.orderBy('name').snapshots().map((s) => s.docs.map(Role.fromDoc).toList());

  /// Creates the Firebase Auth account through a secondary app instance so
  /// the administrator's own session is not replaced, then writes the
  /// profile document (allowed by rules only for `manage_users`).
  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required Role role,
    required AppUser admin,
  }) async {
    final app = await _secondaryApp();
    final auth = FirebaseAuth.instanceFor(app: app);
    final UserCredential cred;
    try {
      cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user!.updateDisplayName(name.trim());
    } finally {
      await auth.signOut();
    }
    final uid = cred.user!.uid;
    final batch = _db.batch()
      ..set(_users.doc(uid), {
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        'phone': '',
        'roleId': role.id,
        'roleName': role.name,
        'permissions': role.permissions.toList(),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': admin.uid,
      });
    final audit = AuditEntry(
      action: AuditAction.create,
      entityType: Col.users,
      entityId: uid,
      summary: 'إضافة مستخدم: ${name.trim()} (${role.name})',
      after: {'email': email.trim(), 'role': role.name},
    );
    batch.set(audit.newRef(_db), audit.toMap(uid: admin.uid, userName: admin.name));
    await batch.commit();
  }

  Future<FirebaseApp> _secondaryApp() async {
    const name = 'user-admin';
    for (final app in Firebase.apps) {
      if (app.name == name) return app;
    }
    return Firebase.initializeApp(name: name, options: Firebase.app().options);
  }

  Future<void> updateUser(AppUser user, {required Role role, required bool active, required AppUser admin}) async {
    if (user.uid == admin.uid && (!active || !role.permissions.contains('admin'))) {
      throw const AppException('لا يمكنك إيقاف حسابك أو إزالة صلاحية المدير عن نفسك.');
    }
    final batch = _db.batch()
      ..update(_users.doc(user.uid), {
        'roleId': role.id,
        'roleName': role.name,
        'permissions': role.permissions.toList(),
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': admin.uid,
      });
    final audit = AuditEntry(
      action: AuditAction.permissions,
      entityType: Col.users,
      entityId: user.uid,
      summary: 'تعديل مستخدم: ${user.name}',
      before: {'role': user.roleName, 'active': user.active},
      after: {'role': role.name, 'active': active},
    );
    batch.set(audit.newRef(_db), audit.toMap(uid: admin.uid, userName: admin.name));
    await batch.commit();
  }

  Future<void> saveRole({
    Role? existing,
    required String name,
    required Set<String> permissions,
    required AppUser admin,
  }) async {
    final ref = existing == null ? _roles.doc() : _roles.doc(existing.id);
    final batch = _db.batch()
      ..set(
        ref,
        {
          'name': name.trim(),
          'permissions': permissions.toList(),
          if (existing == null) 'system': false,
          if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': admin.uid,
        },
        SetOptions(merge: true),
      );
    if (existing != null) {
      final holders = await _users.where('roleId', isEqualTo: existing.id).get();
      for (final u in holders.docs) {
        if (u.id == admin.uid && !permissions.contains('admin')) {
          throw const AppException('لا يمكن إزالة صلاحية المدير من الدور الذي تستخدمه.');
        }
        batch.update(u.reference, {'permissions': permissions.toList(), 'roleName': name.trim()});
      }
    }
    final audit = AuditEntry(
      action: AuditAction.permissions,
      entityType: Col.roles,
      entityId: ref.id,
      summary: '${existing == null ? 'إنشاء' : 'تعديل'} دور: ${name.trim()}',
      before: existing == null ? null : {'permissions': existing.permissions.toList()},
      after: {'permissions': permissions.toList()},
    );
    batch.set(audit.newRef(_db), audit.toMap(uid: admin.uid, userName: admin.name));
    await batch.commit();
  }
}
