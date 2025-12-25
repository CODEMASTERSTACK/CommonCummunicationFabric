# Troubleshooting & Debugging Guide

## Console Logging

### View App Logs
```bash
# View all logs
flutter logs

# Clear logs first
flutter logs -c
```

### Add Debug Logging
```dart
// In your code
print('Debug message: $variable');
debugPrint('Safe debug output');

// Use Flutter's logger
import 'dart:developer' as developer;
developer.log('Detailed message', name: 'CategoryName');
```

---

## Network Debugging

### Check IP Address

**Android:**
```bash
adb shell ifconfig
# Look for inet addr in wlan0
```

**Windows PowerShell:**
```powershell
ipconfig
# IPv4 Address: 192.168.x.x
```

**Linux/Mac:**
```bash
ifconfig
# inet 192.168.x.x
```

### Test Connectivity
```bash
# Ping other device
ping 192.168.1.100

# Test port
telnet 192.168.1.100 5000

# Port forwarding (if needed)
adb forward tcp:5000 tcp:5000
```

### Check Network Interface
```dart
// In your app
import 'dart:io';

Future<void> checkNetworkInfo() async {
  final interfaces = await NetworkInterface.list();
  for (var interface in interfaces) {
    print('Interface: ${interface.name}');
    for (var address in interface.addresses) {
      print('  Address: ${address.address}');
    }
  }
}
```

---

## Common Issues & Solutions

### Issue 1: "Connection Refused"

**Symptoms:**
- Socket connection fails
- Message: "Failed to connect"

**Debugging:**
```bash
# Check if server is running
netstat -ano | findstr :5000  # Windows
lsof -i :5000                 # Linux/Mac
ss -tulpn | grep 5000         # Linux

# Check firewall
# Windows: Settings > Firewall > Allow app
```

**Solutions:**
1. Ensure device 1 app is running
2. Verify both devices on same WiFi
3. Check firewall settings
4. Try restarting both apps
5. Change port if 5000 is in use

### Issue 2: "Room Code Not Found"

**Symptoms:**
- Code verification fails
- Message: "Invalid or expired code"

**Debugging:**
```dart
// Add logging to RoomService
print('Current rooms: ${_rooms.keys}');
print('Verifying code: $code');
print('Code valid: ${verifyRoomCode(code)}');
```

**Solutions:**
1. Check code is exactly 6 digits
2. Verify creator device app is running
3. Ensure code hasn't expired (24 hours)
4. Try creating a new room

### Issue 3: "Messages Not Appearing"

**Symptoms:**
- Send message but it doesn't appear on other device
- Message appears only locally

**Debugging:**
```dart
// Add to messaging_service.dart
void addMessage({...}) {
  print('Adding message: $content');
  print('Room code: $roomCode');
  print('Total messages: ${_messages.length}');
  
  // ... rest of code
}

// Add to chat_screen.dart
void _sendMessage() {
  print('Sending: ${_messageController.text}');
  print('Device: ${widget.roomService.currentDeviceId}');
}
```

**Solutions:**
1. Verify network connection
2. Check if devices still in same room
3. Verify message service is initialized
4. Check console logs for errors
5. Restart both apps

### Issue 4: "Devices Not Showing"

**Symptoms:**
- Connected devices list is empty
- Only current device shows

**Debugging:**
```dart
// In chat_screen.dart
@override
void initState() {
  super.initState();
  print('Room code: ${widget.roomCode}');
  final room = widget.roomService.getCurrentRoom();
  print('Room exists: ${room != null}');
  print('Devices: ${room?.connectedDevices.length ?? 0}');
}
```

**Solutions:**
1. Verify you're in a room (room code visible)
2. Check other device joined successfully
3. Restart the app
4. Verify device joined with correct code

### Issue 5: "App Crashes on Startup"

**Symptoms:**
- App closes immediately
- Yellow error screen or crash log

**Debugging:**
```bash
# Run with verbose logging
flutter run -v

# Check logs
flutter logs

# Look for errors in console
```

**Solutions:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run -v

# Check pubspec.yaml for dependency issues
flutter pub get --no-example

# Downgrade problematic package if needed
flutter pub downgrade <package_name>
```

---

## Debugging Tools

### Flutter DevTools
```bash
# Start DevTools
flutter pub global activate devtools
devtools

# Run app with DevTools
flutter run --devtools-server-address http://localhost:9100
```

### Android Studio Debugger
1. Open project in Android Studio
2. Run app with debugger
3. Set breakpoints
4. Step through code

### VS Code Debugging
1. Install Flutter extension
2. Press F5 to start debugging
3. Set breakpoints by clicking line number
4. Use Debug Console for logging

---

## Performance Debugging

### Check Memory Usage
```bash
# Monitor memory
flutter run --profile

# In DevTools, check Memory tab
```

### Check Frame Rate
```bash
# Enable performance overlay
flutter run --enable-software-rendering

# Or use DevTools Performance tab
```

### Check Network Traffic
**Windows:**
```powershell
# Install WireShark for packet inspection
# Or use Windows netstat
netstat -s
```

---

## Device-Specific Debugging

### Android
```bash
# Connect device
adb devices

# View device logs
adb logcat

# Run specific app
flutter run -d <device_id>

# Clear app data
adb shell pm clear com.example.common_com
```

### Windows
```powershell
# Check running processes
Get-Process | Select Name, Id, Memory

# Monitor network
netstat -o -n -a | findstr :5000
```

---

## Code Debugging Tips

### Add Logging Points
```dart
// Service level logging
class RoomService {
  RoomService({required String deviceName}) {
    print('[RoomService] Initialized with device: $deviceName');
  }
  
  void createRoom() {
    print('[RoomService] Creating new room...');
    // ...
    print('[RoomService] Room created: $code');
  }
}

// UI level logging
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() {
    print('[HomeScreen] Creating state');
    return _HomeScreenState();
  }
}
```

### Check Variable States
```dart
void _joinRoom() {
  final code = _codeController.text.trim();
  print('Code entered: $code');
  print('Code length: ${code.length}');
  print('Code matches regex: ${RegExp(r'^\d{6}$').hasMatch(code)}');
  
  final success = widget.roomService.joinRoom(code, ...);
  print('Join result: $success');
}
```

### Use Assertions
```dart
assert(code.length == 6, 'Code must be 6 digits');
assert(socket != null, 'Socket should not be null');
assert(_currentRoom != null, 'Should have current room');
```

---

## Testing Scenarios

### Scenario 1: Basic Connection
```
Device 1: Create room → Code: 123456
Device 2: Join with 123456 → Success
Result: ✅ Devices connected
```

### Scenario 2: Message Flow
```
Device 1: "Hello" → Sent
Device 2: Receives "Hello"
Device 2: "Hi back" → Sent
Device 1: Receives "Hi back"
Result: ✅ Bidirectional messaging works
```

### Scenario 3: Multiple Devices
```
Device 1: Creates room → Code: 654321
Device 2: Joins → Success
Device 3: Joins → Success
All send messages → All receive
Result: ✅ Group messaging works
```

### Scenario 4: Edge Cases
```
- Leave room and rejoin
- Multiple rooms simultaneously (Device per room)
- Rapid message sending
- Large message content
- Network interruption
```

---

## Error Messages Guide

| Error | Cause | Solution |
|-------|-------|----------|
| Connection refused | Server not running | Start creator device |
| Room code not found | Invalid/expired code | Verify code, restart |
| Socket closed | Connection lost | Reconnect, check WiFi |
| Timeout exception | Network unreachable | Check network, restart |
| Permission denied | App permissions | Grant in Settings |
| Port in use | Port 5000 occupied | Kill process, change port |

---

## Getting Detailed Logs

### Create Debug Mode
```dart
// lib/config/app_config.dart
class AppConfig {
  static const bool DEBUG_MODE = true;
  
  static void log(String tag, String message) {
    if (DEBUG_MODE) {
      print('[$tag] $message');
    }
  }
}

// Usage
AppConfig.log('RoomService', 'Room created with code: $code');
AppConfig.log('ChatScreen', 'Sending message: $message');
```

### Export Logs
```bash
# Save logs to file
flutter logs > flutter_logs.txt

# Analyze logs
grep "Error" flutter_logs.txt
grep "Exception" flutter_logs.txt
```

---

## Before Reporting Issues

Checklist:
- [ ] Read the error message completely
- [ ] Check Flutter version: `flutter --version`
- [ ] Verify network: `ping <device_ip>`
- [ ] Check logs: `flutter logs`
- [ ] Try clean rebuild: `flutter clean && flutter pub get && flutter run`
- [ ] Test on actual device (not emulator only)
- [ ] Verify pubspec.yaml dependencies
- [ ] Check platform-specific setup guides

---

## Quick Reference Commands

```bash
# View logs
flutter logs

# Run with verbose
flutter run -v

# Run specific device
flutter run -d <device_id>

# List devices
flutter devices

# Format code
flutter format .

# Analyze code
flutter analyze

# Clean project
flutter clean

# Check dependencies
flutter pub get

# Update dependencies
flutter pub upgrade

# Run in debug mode
flutter run -d <device_id>

# Run in release mode
flutter run -d <device_id> --release

# Run in profile mode
flutter run -d <device_id> --profile
```

---

**Need help?** Check the relevant setup guide first, then use these debugging techniques!
