import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Varanti';

  // Supabase Project Credentials
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mvlyfbfmeagxjkwpzotx.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12bHlmYmZtZWFneGprd3B6b3R4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA0Mjg3ODcsImV4cCI6MjEwNjAwNDc4N30.ZS9MbSRBJNcGLPybu-SByqzzN3iVdXsuC4uB-mIKUTM',
  );

  // FastAPI Base URL
  // Android Emulator uses 10.0.2.2 to reach host machine localhost:8000
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // Working Defaults
  static const List<String> categories = [
    'Consumer Tech',
    'Home Appliances',
    'Computing',
    'Audio',
    'Power Tools',
    'Other',
  ];

  static const String defaultCategory = 'Consumer Tech';
  static const int defaultDurationMonths = 12;
  static const String defaultCurrency = 'USD';

  // Image acquisition defaults
  static const int imageQuality = 65;
  static const double maxImageDimension = 1600.0;
}
