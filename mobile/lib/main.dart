import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/notifications/notification_service.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Client
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: AppConfig.supabaseAnonKey,
  );

  bool isGuest = false;
  try {
    const storage = FlutterSecureStorage();
    final guestVal = await storage.read(key: 'varanti_guest_mode_enabled');
    isGuest = (guestVal == 'true');
  } catch (_) {}

  final notificationSettings = await NotificationSettings.load();
  await NotificationService.instance.init();

  runApp(
    ProviderScope(
      overrides: [
        initialGuestProvider.overrideWithValue(isGuest),
        initialNotificationSettingsProvider.overrideWithValue(notificationSettings),
      ],
      child: const VarantiApp(),
    ),
  );
}

class VarantiApp extends ConsumerWidget {
  const VarantiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: (authState.isAuthenticated || authState.isGuest)
          ? const DashboardScreen()
          : const LoginScreen(),
    );
  }
}
