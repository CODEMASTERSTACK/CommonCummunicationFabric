import 'dart:io';
import 'package:uuid/uuid.dart';

class LocalNetworkService {
  static const int defaultPort = 5000;
  late ServerSocket _serverSocket;
  final String deviceId = const Uuid().v4();
  final Map<String, Socket> _connectedClients = {};
  final Function(String roomCode, Map<String, dynamic> message)?
  onMessageReceived;
  final Function(String deviceId)? onDeviceConnected;
  final Function(String deviceId)? onDeviceDisconnected;

  LocalNetworkService({
    this.onMessageReceived,
    this.onDeviceConnected,
    this.onDeviceDisconnected,
  });

  /// Start server on this device
  Future<void> startServer(String deviceName, {int port = defaultPort}) async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      print('Server started on port $port');

      _serverSocket.listen((Socket client) {
        _handleClientConnection(client, deviceName);
      });
    } catch (e) {
      print('Error starting server: $e');
      rethrow;
    }
  }

  void _handleClientConnection(Socket client, String deviceName) {
    print('Client connected: ${client.remoteAddress}');

    client.listen(
      (List<int> data) {
        try {
          String message = String.fromCharCodes(data).trim();
          _processIncomingMessage(message, client);
        } catch (e) {
          print('Error processing message: $e');
        }
      },
      onError: (error) {
        print('Client error: $error');
        client.close();
      },
      onDone: () {
        print('Client disconnected');
        client.close();
      },
    );
  }

  void _processIncomingMessage(String message, Socket client) {
    try {
      // Simple protocol: roomCode|type|deviceId|content
      List<String> parts = message.split('|');
      if (parts.length >= 4) {
        String roomCode = parts[0];
        String type = parts[1];
        String deviceId = parts[2];
        String content = parts.sublist(3).join('|');

        if (type == 'register') {
          _connectedClients[deviceId] = client;
          onDeviceConnected?.call(deviceId);
        } else if (type == 'message') {
          onMessageReceived?.call(roomCode, {
            'deviceId': deviceId,
            'content': content,
            'timestamp': DateTime.now().toIso8601String(),
          });
          // Broadcast to other clients
          _broadcastMessage(roomCode, deviceId, content);
        }
      }
    } catch (e) {
      print('Error processing message: $e');
    }
  }

  void _broadcastMessage(
    String roomCode,
    String senderDeviceId,
    String content,
  ) {
    String messageData = '$roomCode|message|$senderDeviceId|$content';
    for (var client in _connectedClients.values) {
      try {
        client.write('$messageData\n');
      } catch (e) {
        print('Error broadcasting message: $e');
      }
    }
  }

  /// Connect to a server
  Future<Socket?> connectToServer(
    String serverAddress,
    String deviceId,
    String deviceName, {
    int port = defaultPort,
  }) async {
    try {
      Socket socket = await Socket.connect(serverAddress, port);
      // Register this device with the server
      socket.write('register|$deviceId|$deviceName\n');
      return socket;
    } catch (e) {
      print('Error connecting to server: $e');
      return null;
    }
  }

  /// Send message through existing connection
  void sendMessage(
    Socket socket,
    String roomCode,
    String deviceId,
    String message,
  ) {
    try {
      socket.write('$roomCode|message|$deviceId|$message\n');
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  /// Close server
  Future<void> closeServer() async {
    await _serverSocket.close();
    for (var client in _connectedClients.values) {
      await client.close();
    }
    _connectedClients.clear();
  }

  /// Get local IP address
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (e) {
      print('Error getting IP: $e');
    }
    return null;
  }
}
