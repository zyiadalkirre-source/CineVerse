import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CacheService.init();
  await NotificationService.init();

  runApp(const CineVerseApp());
}

class CineVerseApp extends StatelessWidget {
  const CineVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'CineVerse',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            locale: themeProvider.locale,
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
              Locale('fr'),
            ],
            theme: AppTheme.build(
              Brightness.light,
              const Color(AppColors.primary),
            ),
            darkTheme: AppTheme.build(
              Brightness.dark,
              const Color(AppColors.primary),
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
