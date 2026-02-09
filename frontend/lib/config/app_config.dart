class AppConfig {
  /// Production API base URL
  /// Backend hosted on Render
  /// Face recognition service hosted on Hugging Face (called via backend)
  static const String baseUrl = 'https://hostel-attendance-nc8a.onrender.com/api';

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
