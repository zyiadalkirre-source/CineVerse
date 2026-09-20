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

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Optional startup services must never prevent the UI from launching.
  try {
    await CacheService.init();
  } catch (_) {}

  try {
    await ApiConfig.init();
  } catch (_) {}

  try {
    await NotificationService.init();
  } catch (_) {}

  await FirebaseBootstrap.initialize();

  if (FirebaseBootstrap.configured) {
    try {
      await AuthService.instance.initialize();
      CloudSyncService.instance.start();
    } catch (_) {}
  }

  runApp(const CineVerseApp());
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
