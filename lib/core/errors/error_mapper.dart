import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../accounting/accounting_exception.dart';
import 'error_reporter.dart';

/// A user-facing validation or business error raised by repositories.
class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => 'AppException($message)';
}

/// Converts any error into a friendly Arabic message. Raw Firebase exceptions
/// are never shown to users; unexpected errors are reported to Crashlytics.
abstract final class ErrorMapper {
  static String message(Object error, [StackTrace? stack]) {
    if (error is AccountingException) return error.message;
    if (error is AppException) return error.message;
    if (error is FirebaseAuthException) return _auth(error.code);
    if (error is FirebaseException) {
      final msg = _firestore(error.code);
      if (msg == null) ErrorReporter.report(error, stack);
      return msg ?? _generic;
    }
    if (error is TimeoutException) return _offline;
    ErrorReporter.report(error, stack);
    return _generic;
  }

  static const _generic = 'حدث خطأ غير متوقع. حاول مرة أخرى، وإذا تكررت المشكلة تواصل مع مدير النظام.';
  static const _offline =
      'تعذر الاتصال بالخادم. العمليات المالية تتطلب اتصالاً بالإنترنت لضمان دقة الأرصدة. تحقق من الاتصال وحاول مرة أخرى.';

  static String? _firestore(String code) => switch (code) {
        'permission-denied' => 'ليس لديك صلاحية لتنفيذ هذه العملية.',
        'unavailable' || 'deadline-exceeded' => _offline,
        'not-found' => 'السجل المطلوب غير موجود.',
        'already-exists' => 'هذا السجل موجود مسبقاً.',
        'aborted' => 'تم تعديل البيانات من مستخدم آخر أثناء الحفظ. حاول مرة أخرى.',
        'failed-precondition' => 'لا يمكن تنفيذ العملية حالياً. قد تحتاج قاعدة البيانات إلى فهرس جديد أو إعداد إضافي.',
        'resource-exhausted' => 'تم تجاوز الحد المسموح من العمليات. حاول بعد قليل.',
        'unauthenticated' => 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
        'cancelled' => 'تم إلغاء العملية.',
        'object-not-found' => 'الملف غير موجود.',
        'unauthorized' => 'ليس لديك صلاحية لرفع أو قراءة هذا الملف.',
        'retry-limit-exceeded' => _offline,
        'quota-exceeded' => 'تم تجاوز مساحة التخزين المتاحة.',
        _ => null,
      };

  static String _auth(String code) => switch (code) {
        'invalid-email' => 'البريد الإلكتروني غير صالح.',
        'user-disabled' => 'تم إيقاف هذا الحساب. تواصل مع مدير النظام.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
        'email-already-in-use' => 'هذا البريد الإلكتروني مستخدم بحساب آخر.',
        'weak-password' => 'كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل.',
        'too-many-requests' => 'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.',
        'network-request-failed' => 'لا يوجد اتصال بالإنترنت.',
        'requires-recent-login' => 'لأسباب أمنية، سجّل الخروج ثم الدخول مرة أخرى.',
        'operation-not-allowed' => 'طريقة تسجيل الدخول هذه غير مفعلة في المشروع.',
        _ => 'تعذر إتمام عملية تسجيل الدخول. حاول مرة أخرى.',
      };
}
