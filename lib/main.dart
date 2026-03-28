import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // Catch all uncaught errors globally
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Catch Flutter framework errors (widget build errors, etc.)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);

        if (kReleaseMode) {
          // In production: log to crash reporting service
          _logError(details.exception, details.stack);
        }
      };

      // Catch platform channel errors globally
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('=== GLOBAL PLATFORM ERROR ===');
        debugPrint('Error: $error');
        debugPrint('Stack: $stack');

        if (error is PlatformException) {
          debugPrint('PlatformException code: ${error.code}');
          debugPrint('PlatformException message: ${error.message}');
          debugPrint('PlatformException details: ${error.details}');
        }

        // Return true = error handled, don't crash the app
        return true;
      };

      runApp(
        const ProviderScope(
          child: CattleShieldApp(),
        ),
      );
    },
    // Catch any async errors that escape the Flutter framework
    (error, stackTrace) {
      debugPrint('=== UNCAUGHT ASYNC ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack: $stackTrace');

      if (kReleaseMode) {
        _logError(error, stackTrace);
      }
    },
  );
}

/// Log errors to crash reporting service (Sentry, Firebase Crashlytics, etc.)
/// For now, just prints in debug mode. Replace with real service in production.
void _logError(Object error, StackTrace? stack) {
  debugPrint('[CattleShield Error] $error');
  if (stack != null) {
    debugPrint('[CattleShield Stack] $stack');
  }

  // TODO: In production, send to crash reporting:
  // FirebaseCrashlytics.instance.recordError(error, stack);
  // Sentry.captureException(error, stackTrace: stack);
}
