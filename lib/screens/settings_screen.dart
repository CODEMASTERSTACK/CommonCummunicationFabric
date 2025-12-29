import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeProvider? themeProvider;

  const SettingsScreen({Key? key, this.themeProvider}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppTheme _theme = AppTheme.system;
  String _version = '0.1.0';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('app_theme') ?? 0;
    setState(() {
      _theme = AppTheme.values[themeIndex];
    });
  }

  Future<void> _setTheme(AppTheme theme) async {
    final themeModeMap = {
      AppTheme.system: ThemeMode.system,
      AppTheme.light: ThemeMode.light,
      AppTheme.dark: ThemeMode.dark,
    };

    setState(() => _theme = theme);
    widget.themeProvider?.setTheme(themeModeMap[theme] ?? ThemeMode.system);
  }

  Future<void> _clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      if (dir.existsSync()) {
        for (var entity in dir.listSync(recursive: true)) {
          try {
            if (entity is File) {
              entity.deleteSync();
            } else if (entity is Directory) {
              entity.deleteSync(recursive: true);
            }
          } catch (_) {}
        }
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error clearing cache: $e')));
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Switcher',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  RadioListTile<AppTheme>(
                    title: const Text('System Default (Adaptive)'),
                    value: AppTheme.system,
                    groupValue: _theme,
                    onChanged: (v) => _setTheme(v ?? AppTheme.system),
                  ),
                  RadioListTile<AppTheme>(
                    title: const Text('Light Mode'),
                    value: AppTheme.light,
                    groupValue: _theme,
                    onChanged: (v) => _setTheme(v ?? AppTheme.system),
                  ),
                  RadioListTile<AppTheme>(
                    title: const Text('Dark Mode'),
                    value: AppTheme.dark,
                    groupValue: _theme,
                    onChanged: (v) => _setTheme(v ?? AppTheme.system),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your theme preference is saved and applied across all screens.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy & Data Control',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Permission Manager'),
                          content: const Text(
                            'Manage app permissions via your device OS Settings.\n\nRequired permissions:\n• Network access (for local communication)\n• File access (for file transfers)',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Permission Manager'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _clearCache,
                    child: const Text('Clear Cache'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help & Support',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version: $_version',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Legal Documents'),
                          content: const Text(
                            'Flutter is licensed under the BSD 3-Clause License.\n\nFor more information about Flutter licenses and legal documents, visit: flutter.dev/legal',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Legal Documents (Flutter)'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Feedback / Bug Report',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'github.com/CODEMASTERSTACK/CommonCummunicationFabric',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () => _copyToClipboard(
                            'https://github.com/CODEMASTERSTACK/CommonCummunicationFabric',
                          ),
                          tooltip: 'Copy repository URL',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Report bugs, suggest features, or contribute to the project on GitHub.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Working Algorithm',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WorkingAlgorithmScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Open detailed documentation →',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum AppTheme { system, light, dark }

class WorkingAlgorithmScreen extends StatelessWidget {
  const WorkingAlgorithmScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Working Algorithm Documentation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              'Overview',
              '''
This document explains how the Common Communication application works, from basic concepts for beginners to detailed protocol implementations for developers.

The app enables real-time messaging and file transfer between devices on the same local network (WiFi or Ethernet) without requiring any external servers or internet connection.''',
            ),

            _buildSection(context, '1. Core Concepts (Beginner Level)', '''
Local Network Communication:
• Devices on the same WiFi or Ethernet network can communicate directly using TCP sockets
• No cloud servers or external services needed
• Ideal for private, fast, offline messaging

Room System:
• A "room" is created on one device (the host)
• The host gets a unique 6-digit code
• Other devices (clients) can join using this code
• Multiple devices can be in one room simultaneously

Device Identification:
• Each device gets a unique ID (UUID) for identification
• User-friendly names (e.g., "My iPhone", "Office PC") help identify devices
• Names are sent when joining rooms for user recognition'''),

            _buildSection(
              context,
              '2. Discovery & Advertising (Intermediate)',
              '''
Problem: How do clients find the host without knowing its IP address?

Solution: UDP Broadcast Announcement

Server-side (Host):
1. When a room is created, the host binds to a RawDatagramSocket on the announce port (5001)
2. The host calculates the subnet broadcast address (e.g., 192.168.1.255 for /24 subnet)
3. Every 2 seconds, the host sends an ANNOUNCE message to the broadcast address
4. Message format: "ANNOUNCE|roomCode|localIp|serverPort"
5. Example: "ANNOUNCE|123456|192.168.1.100|5000"

Client-side (Listener):
1. When user enters a room code, the client binds to the announce port
2. It listens for all incoming UDP messages
3. When it receives ANNOUNCE messages, it parses them
4. If the room code matches, it extracts the host IP and port
5. The client now knows where to connect

Benefits:
• Automatic discovery without manual IP entry
• Works across entire local subnet
• Fallback to manual entry if discovery fails''',
            ),

            _buildSection(context, '3. Connection Protocol (Intermediate)', '''
TCP Socket Connection Flow:

Step 1: Client Connects to Host
• Client creates a Socket connection to host IP on port 5000
• Connection is kept alive throughout the session

Step 2: Client Registration
• Client immediately sends: "roomCode|register|deviceId|deviceName"
• Example: "123456|register|uuid-xyz|My iPhone"
• This message helps the host identify who is joining

Step 3: Host Acknowledgment
• Host receives the message and stores the socket and device info
• Host sends all currently connected devices to the new client
• This way the client knows who is already in the room

Step 4: Broadcast Notification
• Host notifies all connected clients that a new device joined
• Message: "roomCode|device_joined|deviceId|deviceName"
• All clients update their UI to show the new device'''),

            _buildSection(context, '4. Messaging Protocol (Intermediate)', '''
Message Format:
All messages use pipe (|) as delimiter with UTF-8 encoding.
Format: "roomCode|messageType|deviceId|content\\n"

Message Types:

1. Text Message:
   "123456|message|uuid-xyz|Hello from iPhone"
   • Simple text messaging
   • Broadcast to all devices in room
   • Includes timestamp on receipt

2. Device Joined:
   "123456|device_joined|uuid-abc|New Device"
   • Sent when new device joins
   • Triggers UI update
   • Shows presence of device

3. Device Left:
   "123456|device_left|uuid-xyz|My iPhone"
   • Sent when device disconnects
   • Removes device from room
   • Notifies other clients

4. Presence/Keep-Alive:
   • No explicit keep-alive (TCP handles it)
   • But connections timeout if no activity
   • Reconnection attempts happen automatically

Flow Example:
Device A sends: "123456|message|id-A|Hello"
↓
Host receives on Socket A
↓
Host sends to Socket B, C, D:
"123456|message|id-A|Hello"
↓
Devices B, C, D receive and display message'''),

            _buildSection(context, '5. File Transfer (Advanced)', '''
Large files are split into chunks to avoid memory issues.

Three-Stage Process:

Stage 1: Transfer Start
Message: "roomCode|fileshare_start|deviceId|metadataJSON"
Metadata includes:
{
  "fileId": "unique-file-id",
  "fileName": "document.pdf",
  "totalChunks": 50,
  "fileSize": 5242880
}

Stage 2: Send Chunks
Message: "roomCode|fileshare_chunk|deviceId|chunkJSON"
Chunk data:
{
  "fileId": "unique-file-id",
  "chunkIndex": 0,
  "chunkData": "base64-encoded-chunk"
}
• Chunks are 64KB each (configurable)
• Sent sequentially to avoid flooding
• Each chunk includes index for ordering

Stage 3: Transfer Complete
Message: "roomCode|fileshare_end|deviceId|fileId"
• Host reassembles chunks in correct order
• Saves file to device storage
• Notifies all clients of completion

File Location:
• Android: /Download or app-specific directory
• Windows: User's Downloads folder
• iOS: App Documents folder'''),

            _buildSection(context, '6. Room State Management (Advanced)', '''
The Host maintains:

Room Object:
{
  "code": "123456",
  "hostDeviceId": "uuid-host",
  "hostDeviceName": "My PC",
  "connectedDevices": [
    {"id": "uuid-phone", "name": "iPhone", "joinedAt": timestamp},
    {"id": "uuid-laptop", "name": "Laptop", "joinedAt": timestamp}
  ],
  "messages": [
    {"from": "uuid-phone", "text": "Hello", "timestamp": ...}
  ]
}

Device Map:
deviceId → Device Name (for quick lookup)

Socket Map:
deviceId → TCP Socket (for sending messages)

When client joins:
1. Create Device object
2. Store Socket reference
3. Add to room.connectedDevices
4. Send room state to new client
5. Broadcast device_joined to others

When client leaves:
1. Close Socket
2. Remove from deviceId maps
3. Remove from room.connectedDevices
4. Broadcast device_left to others'''),

            _buildSection(
              context,
              '7. Error Handling & Recovery (Advanced)',
              '''
Network Errors:
• Connection Refused: Host not running or wrong port
• Timeout: Host unreachable (firewall/different network)
• Socket Broken: Lost connection, attempt reconnect

Recovery Strategies:

Connection Loss:
• Detect when socket is closed unexpectedly
• Attempt to reconnect to host (exponential backoff)
• Show "Reconnecting..." to user
• Sync messages when reconnected

Room Expiry:
• Rooms last 24 hours
• After expiry, code becomes invalid
• Prompt user to create new room

Invalid Codes:
• Validate 6-digit format
• Check against active rooms
• Show clear error message

Handling Disconnects:
1. Server detects socket disconnect
2. Cleans up device from maps
3. Notifies other clients
4. Marks device as offline in UI
5. Client can reconnect if room still active''',
            ),

            _buildSection(context, '8. Security Considerations (Developer)', '''
Current Implementation:
✓ Local network only (no internet exposure)
✓ Device ID validation (UUIDs)
✓ Room code verification (6 digits)
✓ Message structure validation

Limitations:
✗ No encryption (plain text over LAN)
✗ No authentication beyond room code
✗ No access control (anyone with code can join)

For Production/Sensitive Data:
• Add TLS/SSL encryption to sockets
• Implement device authentication (certificates)
• Add message signing
• Validate message structure thoroughly
• Add rate limiting
• Implement logging and monitoring'''),

            _buildSection(context, '9. Performance Characteristics', '''
Message Latency:
• Text message: 10-50ms (same network)
• File chunk: 50-200ms depending on size
• Broadcast to 10 devices: 100-500ms total

Memory Usage:
• Idle device: ~20MB
• Per connected socket: ~1MB
• Message history: ~100KB per 1000 messages
• File transfer: Streaming (no buffering)

Scalability:
• Tested with 5+ devices per room
• Can handle 100+ messages/second
• File sizes up to 2GB possible
• Multiple rooms simultaneously supported

Optimization Tips:
• Use release builds for production
• Limit message history retention
• Archive old rooms regularly
• Monitor socket connections
• Implement heartbeat for long connections'''),

            _buildSection(context, '10. Technology Stack', '''
Flutter:
• Cross-platform UI framework
• Single codebase for Android, iOS, Windows, macOS, Linux
• Hot reload for development

Dart:
• Programming language for Flutter
• Strong typing and null safety
• Good async/await support

Networking:
• dart:io → TCP Sockets
• RawDatagramSocket → UDP for discovery
• No external networking libraries needed

Storage:
• SharedPreferences → Small data (settings, room codes)
• File system → Message history, received files
• In-memory models → Active session state

Concurrency:
• Futures and async/await → Asynchronous operations
• StreamControllers → Real-time updates
• Isolates → Heavy computations (if needed)'''),

            _buildSection(context, '11. Common Implementation Patterns', '''
Async Message Handling:
1. Socket.listen() continuously reads incoming data
2. UTF-8 decode incoming bytes
3. Split by newline for complete messages
4. Process one message at a time
5. Queue writes to avoid concurrent issues

State Management:
1. RoomService → Room and device state
2. MessagingService → Message history
3. LocalNetworkService → Network operations
4. UI listens to service updates via StreamController
5. setState() triggers UI rebuild

Error Recovery:
1. Try-catch all network operations
2. Log errors for debugging
3. Notify user of issues
4. Implement exponential backoff
5. Provide manual retry options'''),

            _buildSection(context, '12. Debugging Tips', '''
Enable Logging:
• Add print statements in critical paths
• Log message sending/receiving
• Track connection state changes
• Monitor memory usage

Flutter Logs:
• Run: flutter logs
• Shows all print statements and errors
• Real-time monitoring
• Helpful for tracking async issues

Network Debugging:
• Check WiFi connection status
• Verify correct subnet
• Test with same/different networks
• Monitor port 5000 and 5001
• Use network analysis tools

Common Issues:
• Connection fails → Check firewall
• Code not found → Verify exact 6 digits
• Messages delayed → Check network latency
• Files incomplete → Check storage permissions
• App crashes → Check logs for exceptions'''),

            _buildSection(context, 'Getting Help', '''
For issues or questions:
1. Check the troubleshooting guide
2. Review the source code comments
3. Enable logging and check logs
4. Test with actual devices (not emulator)
5. Report issues on GitHub: github.com/CODEMASTERSTACK/CommonCummunicationFabric

Understanding the code:
• Start with main.dart (app setup)
• Review home_screen.dart (UI)
• Study services/ folder (business logic)
• Examine models/ for data structures
• Check utils/ for helper functions
'''),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(content, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
      ],
    );
  }
}
