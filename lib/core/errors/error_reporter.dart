import 'dart:io' show Platform;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Sends technical errors to Crashlytics where the platform supports it
/// (Android), and to the debug console everywhere.
abstract final class ErrorReporter {
  static bool get crashlyticsSupported => !kIsWeb && Platform.isAndroid;

  static void report(Object error, StackTrace? stack, {bool fatal = false}) {
    debugPrint('ERROR: $error\n${stack ?? ''}');
    if (crashlyticsSupported) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
    }
  }

  static void log(String message) {
    if (crashlyticsSupported) FirebaseCrashlytics.instance.log(message);
  }
}
