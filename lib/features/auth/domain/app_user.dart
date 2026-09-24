import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/permissions/permissions.dart';

/// Application user profile stored in `users/{uid}`.
///
/// [permissions] is denormalised from the user's role so security rules can
/// authorise any request with a single document read.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.roleId,
    required this.roleName,
    required this.permissions,
    required this.active,
    this.phone = '',
    this.createdAt,
  });

  final String uid;
  final String email;
  final String name;
  final String roleId;
  final String roleName;
  final Set<String> permissions;
  final bool active;
  final String phone;
  final DateTime? createdAt;

  bool get isAdmin => permissions.contains(Permission.admin.id);

  bool can(Permission p) => active && (isAdmin || permissions.contains(p.id));

  bool canAny(Iterable<Permission> ps) => ps.any(can);

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      email: m['email'] as String? ?? '',
      name: m['name'] as String? ?? '',
      roleId: m['roleId'] as String? ?? '',
      roleName: m['roleName'] as String? ?? '',
      permissions: ((m['permissions'] as List?) ?? const []).cast<String>().toSet(),
      active: m['active'] as bool? ?? false,
      phone: m['phone'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
