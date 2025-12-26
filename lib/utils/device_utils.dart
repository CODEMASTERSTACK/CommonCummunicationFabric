import 'dart:io';

class DeviceUtils {
  /// Get platform-specific device type
  static String getDeviceType() {
    if (Platform.isAndroid) {
      return 'phone';
    } else if (Platform.isIOS) {
      return 'iphone';
    } else if (Platform.isWindows) {
      return 'pc';
    } else if (Platform.isMacOS) {
      return 'laptop';
    } else if (Platform.isLinux) {
      return 'pc';
    }
    return 'unknown';
  }

  /// Get device icon based on type
  static String getDeviceIcon(String deviceType) {
    switch (deviceType) {
      case 'phone':
        return '📱';
      case 'pc':
        return '🖥️';
      case 'laptop':
        return '💻';
      default:
        return '📱';
    }
  }

  /// Get platform name
  static String getPlatformName() {
    if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isLinux) {
      return 'Linux';
    }
    return 'Unknown';
  }

  /// Check if running on mobile (Android/iOS)
  static bool isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Check if running on desktop
  static bool isDesktop() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }
}
