# Android Configuration Guide

## Required Permissions

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
```

## Network Security

Create `android/app/src/main/res/xml/network_security_config.xml` (if not exists):

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">192.168.1.0/24</domain>
        <domain includeSubdomains="true">10.0.0.0/8</domain>
        <domain includeSubdomains="true">172.16.0.0/12</domain>
    </domain-config>
</network-security-config>
```

Reference this in `AndroidManifest.xml`:

```xml
<application android:networkSecurityConfig="@xml/network_security_config" ...>
```

## Gradle Configuration

Ensure `android/app/build.gradle.kts` has minimum SDK 21:

```kotlin
android {
    compileSdk = 34
    defaultConfig {
        minSdk = 21
        targetSdk = 34
    }
}
```

## Build and Run

```bash
# Build APK
flutter build apk

# Run on device
flutter run -d <device_id>
```

## Troubleshooting

### Connection Refused
- Ensure both devices are on the same network
- Check firewall settings
- Verify the port 5000 is not blocked

### Permission Denied
- Grant internet permissions when prompted
- Check device settings for app permissions
- Restart the app after granting permissions

### No Network Access
- Check WiFi connection
- Ensure mobile data is not interfering
- Verify IP address ranges
