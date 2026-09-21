import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/api_config.dart';
import 'l10n/translations.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/media_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'core/firebase_bootstrap.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  ErrorWidget.builder = (_) => const _ReleaseErrorView();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // IMPORTANT: render the first Flutter frame before any native/plugin
  // initialization. A release APK must never depend on Firebase, secure
  // storage, Hive, notifications, or network services to show its UI.
  runApp(const CineVerseApp());

  // Everything below is deliberately deferred until after runApp().
  // A failed/slow plugin cannot block the first frame anymore.
  unawaited(_initializeAfterFirstFrame());
}

Future<void> _initializeAfterFirstFrame() async {
  // Firebase is optional for the initial UI. If it becomes available,
  // the app can use it for auth/sync without delaying startup.
  try {
    await FirebaseBootstrap.initialize().timeout(const Duration(seconds: 5));
  } catch (_) {
    FirebaseBootstrap.configured = false;
  }

  try {
    await ApiConfig.init().timeout(const Duration(seconds: 3));
  } catch (_) {}

  try {
    await CacheService.init().timeout(const Duration(seconds: 5));
  } catch (_) {}

  try {
    await NotificationService.init().timeout(const Duration(seconds: 5));
  } catch (_) {}

  if (FirebaseBootstrap.configured) {
    try {
      await AuthService.instance.initialize().timeout(const Duration(seconds: 5));
      CloudSyncService.instance.start();
    } catch (_) {}
  }
}

class _ReleaseErrorView extends StatelessWidget {
  const _ReleaseErrorView();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5FA),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'تعذر تحميل CineVerse',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'حدث خطأ أثناء تشغيل الواجهة. أعد فتح التطبيق وحاول مرة أخرى.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CineVerseApp extends StatelessWidget {
  const CineVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final providers = <ChangeNotifierProvider<dynamic>>[
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => MediaProvider()),
      ChangeNotifierProvider(create: (_) => AiProvider()),
    ];

    if (FirebaseBootstrap.configured) {
      providers.add(
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      );
    }

    return MultiProvider(
      providers: providers,
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, tp, sp, _) {
          return MaterialApp(
            title: 'CineVerse',
            debugShowCheckedModeBanner: false,
            locale: sp.locale,
            supportedLocales: AppTranslations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.build(Brightness.light, tp.effectiveSeed),
            darkTheme: AppTheme.build(Brightness.dark, tp.effectiveSeed),
            themeMode: sp.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
