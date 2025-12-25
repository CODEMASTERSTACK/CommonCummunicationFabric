/// Application configuration constants
class AppConfig {
  // Network
  static const int networkPort = 5000;
  static const int connectionTimeout = 5000; // milliseconds
  static const int messageBufferSize = 1024;

  // Room
  static const int roomCodeLength = 6;
  static const int roomExpirationHours = 24;
  static const int maxDevicesPerRoom = 10;

  // UI
  static const String appName = 'Common Communication';
  static const String appVersion = '1.0.0';

  // Message
  static const int maxMessageLength = 1000;
  static const int messageRetryAttempts = 3;

  // Timeouts
  static const Duration deviceCheckInterval = Duration(seconds: 5);
  static const Duration messageRetryDelay = Duration(seconds: 2);
  static const Duration connectionCheckTimeout = Duration(seconds: 10);
}
