class AppConfig {
  /// Local development API base URL
  /// Use 'http://localhost:5000/api' for Web/iOS Simulator
  /// Use 'http://10.0.2.2:5000/api' for Android Emulator
  static const String baseUrl = 'http://localhost:5000/api';

  /// Face recognition timeout settings
  static const Duration faceRecognitionTimeout = Duration(seconds: 30);
  static const Duration coldStartTimeout = Duration(seconds: 60);

  /// Debug flag - set to false for production
  static const bool isDebugMode = false;

  static void printDebug(String message) {
    if (isDebugMode) {
      print('[AppConfig] $message');
    }
  }
}
