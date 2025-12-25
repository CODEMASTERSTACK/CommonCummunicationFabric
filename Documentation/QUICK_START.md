# Quick Start Guide

## Setup (5 minutes)

### 1. Install Dependencies
```bash
cd common_com
flutter pub get
```

### 2. Choose Your Platform

#### For Android
```bash
# Connect an Android device or start an emulator
flutter devices  # List available devices

# Run on your device
flutter run -d <device_id>
```

#### For Windows
```bash
# Run on Windows
flutter run -d windows

# Or build for distribution
flutter build windows --release
```

### 3. Build APK (Android)
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

---

## Using the App

### Scenario: Connect Phone to PC

#### Step 1: Create Room on PC
1. Open app on Windows PC
2. Click **"Create New Room"**
3. A 6-digit code appears (e.g., `523847`)
4. Note the code

#### Step 2: Join Room on Phone
1. Open app on Android phone
2. Click **"Join Existing Room"**
3. Enter the 6-digit code (`523847`)
4. Click **"Join Room"**
5. You're now connected!

#### Step 3: Send Messages
1. Type message in input field
2. Tap send button (arrow icon)
3. Message appears on both devices instantly

---

## Connecting Multiple Devices

### Device 1 (Creator)
- Creates room with code: `234567`

### Device 2 (Joiner)
- Enters code: `234567`
- Joins room

### Device 3 (Another Joiner)
- Enters code: `234567`
- Joins room

**Result**: All 3 devices can now communicate!

---

## Troubleshooting

### "Connection refused"
- [ ] Both devices on same WiFi
- [ ] No firewall blocking port 5000
- [ ] Correct room code entered
- [ ] Creator device app still running

### "Room code not found"
- [ ] Code is 6 digits
- [ ] Code created within last 24 hours
- [ ] Creator device online

### App won't start
```bash
# Clean project
flutter clean

# Get dependencies again
flutter pub get

# Run again
flutter run
```

### Port already in use
```bash
# Windows: Find and kill process on port 5000
netstat -ano | findstr :5000
taskkill /PID <PID> /F

# Linux/Mac: Find and kill process
lsof -i :5000
kill -9 <PID>
```

---

## Network Requirements

✓ **Same WiFi Network** (Recommended)
- PC and phone on same WiFi
- Best performance and stability

✓ **Ethernet + WiFi**
- PC on Ethernet, phone on WiFi (same network)
- Works if on same subnet

✗ **Different Networks**
- Phone on one WiFi, PC on another
- Will NOT work (unless using VPN)

---

## Testing on Emulator

### Android Emulator
```bash
# Start emulator
emulator -avd Pixel_4_API_30

# Run app
flutter run

# Access from host PC
# Use 10.0.2.2 instead of localhost
```

### Multiple Emulators
```bash
# Start first emulator
emulator -avd Pixel_4_API_30

# Start second emulator  
emulator -avd Pixel_5_API_31

# List devices
flutter devices

# Run on specific device
flutter run -d emulator-5554  # First emulator
flutter run -d emulator-5556  # Second emulator
```

---

## Features Overview

| Feature | Status | Notes |
|---------|--------|-------|
| Create Room | ✅ | 6-digit code generation |
| Join Room | ✅ | Code-based joining |
| Send Messages | ✅ | Real-time sync |
| Show Devices | ✅ | All connected devices |
| Device Names | ✅ | Auto-detected from platform |
| Message History | ✅ | Stored in memory |
| Network Broadcast | ✅ | All devices get messages |

---

## Next Steps

After basic testing, consider:

1. **Persistence**: Save rooms and messages to device storage
2. **Encryption**: Add message encryption for security
3. **File Transfer**: Allow users to share files
4. **Better UI**: Add avatars, user profiles, themes
5. **Voice Chat**: Add audio communication
6. **Device Discovery**: Auto-find devices on network

---

## Performance Tips

- 🚀 Use **Release builds** for testing (faster)
- 📱 Test on **actual devices** (emulator has limitations)
- 🌐 Check **WiFi strength** for connectivity
- 💾 Clear app data if experiencing issues
- 🔄 Restart both apps if connection drops

---

## File Structure Reminder

```
lib/
├── main.dart                 ← App entry point
├── screens/
│   ├── home_screen.dart     ← Create/Join room
│   └── chat_screen.dart     ← Messaging
├── services/
│   ├── room_service.dart    ← Room logic
│   ├── messaging_service.dart
│   └── local_network_service.dart
├── models/
│   ├── room.dart
│   ├── device.dart
│   └── message.dart
└── utils/
    └── device_utils.dart
```

---

## Getting Help

1. Check the error message carefully
2. Review IMPLEMENTATION_GUIDE.md for architecture
3. Check platform-specific guides:
   - ANDROID_SETUP.md
   - WINDOWS_SETUP.md
4. Look at the code comments
5. Use `flutter logs` for debugging

---

## Common Commands

```bash
# List devices
flutter devices

# Run with verbose logging
flutter run -v

# Show app logs
flutter logs

# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Build APK
flutter build apk --release

# Build Windows exe
flutter build windows --release

# Profile app
flutter run --profile

# Analyze code
flutter analyze

# Format code
flutter format .
```

Enjoy building! 🎉
