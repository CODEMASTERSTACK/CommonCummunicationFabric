import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'room_service.dart';
import '../models/room.dart';

class LocalNetworkService {
  static const int defaultPort = 5000;
  static const int announcePort = 5001;

  ServerSocket? _serverSocket;
  final String deviceId = const Uuid().v4();
  final Map<String, Socket> _connectedClients = {};
  final Map<String, String> _deviceNames = {};
  final Map<String, String> _clientRooms = {}; // deviceId -> roomCode

  final Function(String roomCode, Map<String, dynamic> message)?
  onMessageReceived;
  final Function(String deviceId)? onDeviceConnected;
  final Function(String deviceId)? onDeviceDisconnected;
  final Function(String deviceName)?
  onVisitorJoined; // Track visitors joining our rooms

  final RoomService? roomService;

  RawDatagramSocket? _announceSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _advertiseTimer;

  /// Get connected clients (for file broadcasting)
  Map<String, Socket> get connectedClients => _connectedClients;

  LocalNetworkService({
    this.onMessageReceived,
    this.onDeviceConnected,
    this.onDeviceDisconnected,
    this.onVisitorJoined,
    this.roomService,
  });

  /// Start TCP server on this device
  Future<void> startServer(String deviceName, {int port = defaultPort}) async {
    try {
      // Close any existing server first
      await closeServer();
      // Small delay to ensure port is released
      await Future.delayed(const Duration(milliseconds: 500));

      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);

      _serverSocket!.listen((Socket client) {
        _handleClientConnection(client, deviceName);
      });
    } catch (e) {
      print('Error starting server: $e');
      rethrow;
    }
  }

  void _handleClientConnection(Socket client, String deviceName) {
    client.listen(
      (List<int> data) {
        try {
          String message = utf8.decode(data).trim();
          _processIncomingMessage(message, client);
        } catch (e) {
          print('Error processing message: $e');
        }
      },
      onError: (error) {
        // Handle disconnect
        _handleClientDisconnect(client);
        client.close();
      },
      onDone: () {
        // Client closed connection
        _handleClientDisconnect(client);
        client.close();
      },
    );
  }

  void _processIncomingMessage(String message, Socket client) {
    try {
      // Protocol: roomCode|type|deviceId|content
      List<String> parts = message.split('|');
      if (parts.length >= 4) {
        String roomCode = parts[0];
        String type = parts[1];
        String deviceId = parts[2];
        String content = parts.sublist(3).join('|');

        if (type == 'register') {
          // Store socket and device name for this connection
          _connectedClients[deviceId] = client;
          _deviceNames[deviceId] =
              content; // store device name sent during register
          // remember which room this client joined
          _clientRooms[deviceId] = roomCode;
          onDeviceConnected?.call(deviceId);
          // Track visitor joining our room
          onVisitorJoined?.call(content);

          // If we have a RoomService (we are host), send current room membership
          // to the newly connected client first so it learns about the host and
          // any already-joined devices, then add the new device and broadcast.
          if (roomService != null) {
            // Send existing devices in this room to the newly connected client
            final Room? existingRoom = roomService!.getRoom(roomCode);
            if (existingRoom != null) {
              for (var d in existingRoom.connectedDevices) {
                try {
                  client.write('$roomCode|device_joined|${d.id}|${d.name}\n');
                  client.flush();
                } catch (e) {
                  // ignore
                }
              }
            }

            // Now add the new device to the host's room using the remote deviceId
            roomService!.joinRoom(
              roomCode,
              deviceId: deviceId,
              deviceName: content,
            );

            // Broadcast device join event to all connected clients (including the new one)
            _broadcastDeviceJoined(roomCode, deviceId, content);
          }
        } else if (type == 'leave') {
          // client explicitly left
          // Remove mapping and notify
          final room = _clientRooms.remove(deviceId);
          _connectedClients.remove(deviceId);
          final name = _deviceNames.remove(deviceId) ?? deviceId;
          onDeviceDisconnected?.call(deviceId);
          if (roomService != null && room != null) {
            roomService!.removeDeviceFromRoom(room, deviceId);
            _broadcastDeviceLeft(room, deviceId, name);
          }
        } else if (type == 'message') {
          final deviceName = _deviceNames[deviceId] ?? deviceId;
          onMessageReceived?.call(roomCode, {
            'deviceId': deviceId,
            'deviceName': deviceName,
            'content': content,
            'timestamp': DateTime.now().toIso8601String(),
          });
          _broadcastMessage(roomCode, deviceId, content);
        } else if (type == 'fileshare') {
          // Handle file share message from client
          final deviceName = _deviceNames[deviceId] ?? deviceId;
          print('Received fileshare from $deviceName');
          // Broadcast to all other connected clients
          hostBroadcastFileShare(roomCode, deviceId, content);
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
        client.flush();
      } catch (e) {
        print('Error broadcasting message: $e');
      }
    }
  }

  void _broadcastDeviceJoined(
    String roomCode,
    String deviceId,
    String deviceName,
  ) {
    String msg = '$roomCode|device_joined|$deviceId|$deviceName';
    for (var client in _connectedClients.values) {
      try {
        client.write('$msg\n');
        client.flush();
      } catch (e) {
        // ignore
      }
    }
  }

  void _broadcastDeviceLeft(
    String roomCode,
    String deviceId,
    String deviceName,
  ) {
    String msg = '$roomCode|device_left|$deviceId|$deviceName';
    for (var client in _connectedClients.values) {
      try {
        client.write('$msg\n');
        client.flush();
      } catch (e) {
        // ignore
      }
    }
  }

  void _handleClientDisconnect(Socket client) {
    try {
      String? foundId;
      _connectedClients.forEach((id, sock) {
        if (sock == client) foundId = id;
      });
      if (foundId == null) return;
      final deviceId = foundId!;
      final deviceName = _deviceNames.remove(deviceId) ?? deviceId;
      final roomCode = _clientRooms.remove(deviceId);
      _connectedClients.remove(deviceId);
      onDeviceDisconnected?.call(deviceId);
      if (roomService != null && roomCode != null) {
        roomService!.removeDeviceFromRoom(roomCode, deviceId);
        _broadcastDeviceLeft(roomCode, deviceId, deviceName);
      }
    } catch (e) {
      // ignore
    }
  }

  /// Host broadcasts a message from itself to all connected clients
  void hostBroadcastMessage(String roomCode, String deviceId, String message) {
    String msg = '$roomCode|message|$deviceId|$message';
    for (var client in _connectedClients.values) {
      try {
        client.write('$msg\n');
        client.flush();
      } catch (e) {
        print('Error broadcasting host message: $e');
      }
    }
  }

  /// Host broadcasts a file share message to all connected clients
  void hostBroadcastFileShare(String roomCode, String deviceId, String fileMetadata) {
    String msg = '$roomCode|fileshare|$deviceId|$fileMetadata';
    for (var client in _connectedClients.values) {
      try {
        client.write('$msg\n');
        client.flush();
      } catch (e) {
        print('Error broadcasting file to client: $e');
      }
    }
  }

  /// Connect to a server and register for a room
  Future<Socket?> connectToServer(
    String serverAddress,
    String deviceId,
    String deviceName, {
    int port = defaultPort,
    String? roomCode,
  }) async {
    try {
      Socket socket = await Socket.connect(serverAddress, port);
      // Register this device with the server including room code
      if (roomCode != null) {
        socket.write('$roomCode|register|$deviceId|$deviceName\n');
      } else {
        socket.write('register|$deviceId|$deviceName\n');
      }
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

  /// Stop server
  Future<void> closeServer() async {
    await _serverSocket?.close();
    for (var client in _connectedClients.values) {
      await client.close();
    }
    _connectedClients.clear();
    await stopAdvertising();
  }

  /// Start advertising a hosted room via UDP broadcasts
  Future<void> advertiseRoom(String roomCode, {int intervalMs = 2000}) async {
    try {
      _announceSocket ??= await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      _announceSocket!.broadcastEnabled = true;
      String? localIp = await getLocalIpAddress();
      if (localIp == null) return;

      // Calculate subnet broadcast address from IP and netmask
      String broadcastAddr = _calculateBroadcastAddress(localIp);

      _advertiseTimer?.cancel();
      _advertiseTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
        final msg = utf8.encode('ANNOUNCE|$roomCode|$localIp|$defaultPort');
        try {
          _announceSocket!.send(
            msg,
            InternetAddress(broadcastAddr),
            announcePort,
          );
        } catch (e) {
          // ignore send errors
        }
      });
    } catch (e) {
      print('Error advertising room: $e');
    }
  }

  Future<void> stopAdvertising() async {
    _advertiseTimer?.cancel();
    _advertiseTimer = null;
    _announceSocket?.close();
    _announceSocket = null;
  }

  /// Listen for announcements from hosts
  Future<void> listenForAnnouncements({
    required void Function(String roomCode, String host, int port)
    onAnnouncement,
  }) async {
    try {
      _listenSocket ??= await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        announcePort,
      );
      _listenSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final dg = _listenSocket!.receive();
          if (dg == null) return;
          final msg = utf8.decode(dg.data).trim();
          if (msg.startsWith('ANNOUNCE|')) {
            final parts = msg.split('|');
            if (parts.length >= 4) {
              final room = parts[1];
              final host = parts[2];
              final port = int.tryParse(parts[3]) ?? defaultPort;
              onAnnouncement(room, host, port);
            }
          }
        }
      });
    } catch (e) {
      print('Error listening for announcements: $e');
    }
  }

  Future<void> stopListening() async {
    _listenSocket?.close();
    _listenSocket = null;
  }

  /// Get local IP address (prefer non-loopback, non-link-local)
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 &&
              !address.isLoopback &&
              !address.address.startsWith('169.254')) {
            return address.address;
          }
        }
      }
    } catch (e) {
      print('Error getting IP: $e');
    }
    return null;
  }

  /// Calculate subnet broadcast address (assumes /24 subnet)
  String _calculateBroadcastAddress(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length == 4) {
        // For /24 networks, set last octet to 255
        return '${parts[0]}.${parts[1]}.${parts[2]}.255';
      }
    } catch (_) {}
    return '255.255.255.255';
  }
}
