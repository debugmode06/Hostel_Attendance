import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConfig {
  /// API base URL - platform-aware with override support
  ///
  /// Platform defaults:
  /// - Web: http://localhost:5000/api (uses localhost for browser)
  /// - Android emulator: http://10.0.2.2:5000/api (special Android emulator IP)
  /// - iOS simulator: http://localhost:5000/api
  /// - Physical device: requires --dart-define=API_URL=http://192.168.X.X:5000/api
  ///
  /// Override: flutter run --dart-define=API_URL=http://your-server:5000/api
  static String get baseUrl => _baseUrl;

  static late final String _baseUrl = _initBaseUrl();

  static String _initBaseUrl() {
    // Check if custom URL was provided via --dart-define
    const customUrl = String.fromEnvironment('API_URL');
    if (customUrl.isNotEmpty) {
      print('[AppConfig] Using custom API_URL: $customUrl');
      return customUrl;
    }

    // Platform-specific defaults
    String url;
    if (kIsWeb) {
      url = 'http://localhost:5000/api'; // Web browser
      print('[AppConfig] Using Web URL: $url');
    } else if (Platform.isAndroid) {
      url = 'http://10.0.2.2:5000/api'; // Android emulator (special IP)
      print('[AppConfig] Using Android emulator URL: $url');
    } else if (Platform.isIOS) {
      url = 'http://localhost:5000/api'; // iOS simulator
      print('[AppConfig] Using iOS simulator URL: $url');
    } else {
      url = 'http://localhost:5000/api'; // Desktop (Windows/Mac/Linux)
      print('[AppConfig] Using Desktop URL: $url');
    }

    return url;
  }
}
