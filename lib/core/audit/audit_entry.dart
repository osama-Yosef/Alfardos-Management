import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase/collections.dart';

/// Auditable actions. Labels are shown in the audit log screen.
enum AuditAction {
  create('إضافة'),
  update('تعديل'),
  cancel('إلغاء'),
  deactivate('إيقاف'),
  activate('تفعيل'),
  delete('حذف'),
  post('ترحيل قيد'),
  login('تسجيل دخول'),
  permissions('تغيير صلاحيات');

  const AuditAction(this.label);
  final String label;

  static AuditAction parse(String v) =>
      AuditAction.values.firstWhere((e) => e.name == v, orElse: () => update);
}

/// Who did what, when, where, with before/after values.
class AuditEntry {
  const AuditEntry({
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.summary,
    this.before,
    this.after,
  });

  final AuditAction action;

  /// Collection name of the affected entity (e.g. `sales`).
  final String entityType;
  final String entityId;
  final String summary;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  static String get platformName {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return 'other';
  }

  Map<String, dynamic> toMap({required String uid, required String userName}) => {
        'action': action.name,
        'entityType': entityType,
        'entityId': entityId,
        'summary': summary,
        'before': before == null ? null : _sanitize(before!),
        'after': after == null ? null : _sanitize(after!),
        'userId': uid,
        'userName': userName,
        'platform': platformName,
        'at': FieldValue.serverTimestamp(),
      };

  /// Drops server sentinels (not allowed inside nested maps) and keeps the
  /// audit record small.
  static Map<String, dynamic> _sanitize(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v is FieldValue) return;
      if (v is DocumentReference) {
        out[k] = v.path;
      } else if (v is Map<String, dynamic>) {
        out[k] = _sanitize(v);
      } else if (v is List && v.length > 20) {
        out[k] = '${v.length} عنصر';
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  DocumentReference<Map<String, dynamic>> newRef(FirebaseFirestore db) =>
      db.collection(Col.auditLogs).doc();
}
