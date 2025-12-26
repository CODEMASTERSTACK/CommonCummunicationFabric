import 'package:flutter/material.dart';
import 'dart:io';
import 'screens/device_name_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'services/room_service.dart';
import 'services/messaging_service.dart';
import 'services/local_network_service.dart';

void main() {
  runApp(const MainApp());
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
  String? _deviceName;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    String deviceName = _getDeviceIdentifier();
    _roomService = RoomService(deviceName: deviceName);
    _initMessagingAndNetwork(deviceName);
    _deviceName = deviceName;
  }

  void _initMessagingAndNetwork(String deviceName) {
    _messagingService = MessagingService();

    _networkService = LocalNetworkService(
      roomService: _roomService,
      onMessageReceived: (roomCode, message) {
        try {
          _messagingService.addMessage(
            senderDeviceId: message['deviceId'] as String,
            senderDeviceName:
                (message['deviceName'] as String?) ??
                (message['deviceId'] as String),
            content: message['content'] as String,
            roomCode: roomCode,
          );
        } catch (_) {}
      },

      onDeviceConnected: (deviceId) {
        // placeholder: roomService will be updated by LocalNetworkService on register
      },
    );
  }

  String _getDeviceIdentifier() {
    // Detect device type and name
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
    // If device name has been selected, show HomeScreen, otherwise show DeviceNameScreen
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
          );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Common Communication',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
            ),
          );
        }
        return null;
      },
    );
  }
}
