import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'screens/device_name_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'services/room_service.dart';
import 'services/messaging_service.dart';
import 'services/local_network_service.dart';
import 'services/recent_connections_service.dart';
import 'services/file_service.dart';

void main() {
  runApp(const MainApp());
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeAsync();
  }

  Future<void> _loadThemeAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('app_theme') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme', mode.index);
    notifyListeners();
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late RoomService _roomService;
  late MessagingService _messagingService;
  late LocalNetworkService _networkService;
  late RecentConnectionsService _recentConnectionsService;
  late FileService _fileService;
  late ThemeProvider _themeProvider;
  String? _deviceName;
  final Map<String, String> _deviceNameMap = {};

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    String deviceName = _getDeviceIdentifier();
    _roomService = RoomService(deviceName: deviceName);
    _recentConnectionsService = RecentConnectionsService();
    await _recentConnectionsService.initialize();
    _initMessagingAndNetwork(deviceName);
    _deviceName = deviceName;
  }

  void _initMessagingAndNetwork(String deviceName) {
    _messagingService = MessagingService();
    _fileService = FileService();

    _networkService = LocalNetworkService(
      roomService: _roomService,
      fileService: _fileService,
      onMessageReceived: (roomCode, message) {
        try {
          final devId = message['deviceId'] as String;
          final devName = (message['deviceName'] as String?) ?? devId;
          _deviceNameMap[devId] = devName;

          _messagingService.addMessage(
            senderDeviceId: devId,
            senderDeviceName: devName,
            content: message['content'] as String,
            roomCode: roomCode,
            type: (message['type'] as String?) ?? 'message',
            fileName: message['fileName'] as String?,
            fileMimeType: message['fileMimeType'] as String?,
            fileSize: message['fileSize'] as int?,
            localFilePath: message['localFilePath'] as String?,
          );
        } catch (_) {}
      },
      onDeviceConnected: (deviceId) {},
      onDeviceDisconnected: (deviceId) {},
      onVisitorJoined: (deviceName) {
        _recentConnectionsService.addVisitor(deviceName);
      },
    );
  }

  String _getDeviceIdentifier() {
    if (Platform.isAndroid) {
      return 'Android Device';
    } else if (Platform.isWindows) {
      return 'Windows PC';
    } else if (Platform.isLinux) {
      return 'Linux Device';
    } else if (Platform.isMacOS) {
      return 'Mac Device';
    } else if (Platform.isIOS) {
      return 'iOS Device';
    }
    return 'Unknown Device';
  }

  @override
  Widget build(BuildContext context) {
    Widget homeWidget =
        _deviceName == null || _deviceName == _getDeviceIdentifier()
        ? DeviceNameScreen(
            defaultName: _deviceName ?? 'Unknown Device',
            onNameSelected: (selectedName) {
              setState(() {
                _deviceName = selectedName;
                _roomService = RoomService(deviceName: selectedName);
                _initMessagingAndNetwork(selectedName);
              });
            },
          )
        : HomeScreen(
            roomService: _roomService,
            networkService: _networkService,
            recentConnectionsService: _recentConnectionsService,
            themeProvider: _themeProvider,
          );

    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Common Communication',
          themeMode: _themeProvider.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          home: homeWidget,
          onGenerateRoute: (settings) {
            if (settings.name == '/chat') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => ChatScreen(
                  roomCode: args['roomCode'],
                  roomService: _roomService,
                  messagingService: _messagingService,
                  networkService: _networkService,
                  remoteSocket: args['remoteSocket'] as Socket?,
                  deviceNameMap: _deviceNameMap,
                ),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
