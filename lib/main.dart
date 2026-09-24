import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'core/errors/error_reporter.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline cache: reads keep working without a connection. Financial
  // operations use transactions, which require the server, so balances can
  // never diverge while offline.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024,
  );

  // Local development against the Firebase emulators:
  //   flutter run --dart-define=USE_EMULATOR=true
  if (const bool.fromEnvironment('USE_EMULATOR')) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8085);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }

  if (!kIsWeb && Platform.isAndroid) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  } else {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      ErrorReporter.report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReporter.report(error, stack, fatal: true);
      return true;
    };
  }

  Intl.defaultLocale = 'ar';
  await initializeDateFormatting('ar');

  runApp(const ProviderScope(child: AlfardosApp()));
}
