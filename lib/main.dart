import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palert/providers/product_provider.dart';
import 'package:palert/providers/status_provider.dart';
import 'package:palert/providers/theme_provider.dart';
import 'package:palert/providers/engine_settings_provider.dart';
import 'package:palert/providers/service_monitor_provider.dart';
import 'package:palert/providers/notification_settings_provider.dart';
import 'package:palert/screens/home_page.dart';
import 'package:palert/src/rust/frb_generated.dart';
import 'package:palert/theme/app_theme.dart';
import 'package:palert/widgets/status_bar.dart';
import 'package:palert/services/notification_service.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Rust library
  await RustLib.init();

  // Initialize the Engine Settings Provider
  final engineSettingsProvider = EngineSettingsProvider();

  // Wait for settings to load
  await Future.delayed(const Duration(milliseconds: 100));

  // Initialize notification service
  await NotificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: engineSettingsProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => StatusProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ServiceMonitorProvider()),
        ChangeNotifierProvider(create: (_) => NotificationSettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Palert',
          theme: AppTheme.lightTheme(themeProvider.primaryColor),
          darkTheme: AppTheme.darkTheme(themeProvider.primaryColor),
          themeMode: themeProvider.themeMode,
          home: const AppWithStatusBar(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

/// Wrapper widget that provides the status bar at app level
class AppWithStatusBar extends StatelessWidget {
  const AppWithStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomePage(),
        // Global status bar positioned at the bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: const StatusBar(),
        ),
      ],
    );
  }
}
