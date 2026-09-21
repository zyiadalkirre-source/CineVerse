import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'l10n/translations.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/media_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'core/firebase_bootstrap.dart';
import 'core/app_bootstrap.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
      debugPrint('FLUTTER ERROR: ' + details.exception.toString());
      debugPrintStack(stackTrace: details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PLATFORM ERROR: ' + error.toString());
      debugPrintStack(stackTrace: stack);
      return true;
    };

    ErrorWidget.builder = (details) => _ReleaseErrorView(details: details);

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }

    runApp(const CineVerseApp());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppBootstrap.initAll());
    });
  }, (error, stack) {
    debugPrint('CINEVERSE ZONE ERROR: ' + error.toString());
    debugPrintStack(stackTrace: stack);
  });
}

class _ReleaseErrorView extends StatelessWidget {
  const _ReleaseErrorView({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final message = details.exception.toString();
    final shortMessage =
        message.length > 360 ? message.substring(0, 360) + '…' : message;

    return Material(
      color: const Color(0xFFF5F5FA),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
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
                  'حدث خطأ أثناء تشغيل الواجهة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shortMessage,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => runApp(const CineVerseApp()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
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
    // Keep providers explicitly typed and nested. This avoids any runtime
    // ambiguity from a dynamically typed provider list during release builds.
    Widget app = const _CineVerseMaterialApp();

    app = ChangeNotifierProvider<AiProvider>(
      create: (_) => AiProvider(),
      child: app,
    );
    app = ChangeNotifierProvider<MediaProvider>(
      create: (_) => MediaProvider(),
      child: app,
    );

    if (FirebaseBootstrap.configured) {
      app = ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: app,
      );
    }

    app = ChangeNotifierProvider<SettingsProvider>(
      create: (_) => SettingsProvider(),
      child: app,
    );
    app = ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: app,
    );

    return app;
  }
}

class _CineVerseMaterialApp extends StatelessWidget {
  const _CineVerseMaterialApp();

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final sp = context.watch<SettingsProvider>();

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
  }
}
