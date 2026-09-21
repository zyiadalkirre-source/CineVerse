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
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details);
    ErrorWidget.builder = (details) => _ReleaseErrorView(details: details);
    if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
    runApp(const CineVerseApp());
    unawaited(_initializeAfterFirstFrame());
  }, (error, stack) {
    debugPrint('CINEVERSE ZONE ERROR: $error');
    debugPrintStack(stackTrace: stack);
  });
}

Future<void> _initializeAfterFirstFrame() async {
  try { await FirebaseBootstrap.initialize().timeout(const Duration(seconds: 5)); }
  catch (error, stack) { debugPrint('Firebase init failed: $error'); debugPrintStack(stackTrace: stack); FirebaseBootstrap.configured = false; }
  try { await ApiConfig.init().timeout(const Duration(seconds: 3)); }
  catch (error, stack) { debugPrint('API config init failed: $error'); debugPrintStack(stackTrace: stack); }
  try { await CacheService.init().timeout(const Duration(seconds: 5)); }
  catch (error, stack) { debugPrint('Cache init failed: $error'); debugPrintStack(stackTrace: stack); }
  try { await NotificationService.init().timeout(const Duration(seconds: 5)); }
  catch (error, stack) { debugPrint('Notification init failed: $error'); debugPrintStack(stackTrace: stack); }
  if (FirebaseBootstrap.configured) {
    try { await AuthService.instance.initialize().timeout(const Duration(seconds: 5)); CloudSyncService.instance.start(); }
    catch (error, stack) { debugPrint('Auth/sync init failed: $error'); debugPrintStack(stackTrace: stack); }
  }
}

class _ReleaseErrorView extends StatelessWidget {
  const _ReleaseErrorView({required this.details});
  final FlutterErrorDetails details;
  @override
  Widget build(BuildContext context) {
    final message = details.exception.toString();
    final shortMessage = message.length > 280 ? '${message.substring(0, 280)}…' : message;
    return Material(
      color: const Color(0xFFF5F5FA),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 16),
              const Text('تعذر تحميل CineVerse', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('حدث خطأ أثناء تشغيل الواجهة.', textAlign: TextAlign.center),
              const SizedBox(height: 14),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(.06), borderRadius: BorderRadius.circular(12)), child: Text(shortMessage, textDirection: TextDirection.ltr, textAlign: TextAlign.left, style: const TextStyle(fontSize: 12))),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => runApp(const CineVerseApp()), icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
            ]),
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
    if (FirebaseBootstrap.configured) providers.add(ChangeNotifierProvider(create: (_) => AuthProvider()));
    return MultiProvider(
      providers: providers,
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, tp, sp, _) => MaterialApp(
          title: 'CineVerse',
          debugShowCheckedModeBanner: false,
          locale: sp.locale,
          supportedLocales: AppTranslations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          theme: AppTheme.build(Brightness.light, tp.effectiveSeed),
          darkTheme: AppTheme.build(Brightness.dark, tp.effectiveSeed),
          themeMode: sp.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
