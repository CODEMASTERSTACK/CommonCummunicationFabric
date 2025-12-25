import 'package:flutter/foundation.dart';
import '../models/room.dart';
import '../models/device.dart';
import '../models/message.dart';
import '../services/room_service.dart';
import '../services/messaging_service.dart';
import '../services/local_network_service.dart';

/// State notifier for room management
class RoomNotifier extends ChangeNotifier {
  final RoomService _roomService;
  late Room? _currentRoom;

  RoomNotifier(this._roomService) {
    _currentRoom = _roomService.getCurrentRoom();
  }

  Room? get currentRoom => _currentRoom;
  List<Device> get connectedDevices => _roomService.getConnectedDevices();
  String? get currentRoomCode => _roomService.currentRoomCode;

  /// Create a new room and notify listeners
  Future<void> createRoom() async {
    final room = _roomService.createRoom();
    _currentRoom = room;
    notifyListeners();
  }

  /// Join an existing room
  Future<bool> joinRoom(String code) async {
    final success = _roomService.joinRoom(
      code,
      deviceName: _roomService.currentDeviceName,
    );
    if (success) {
      _currentRoom = _roomService.getCurrentRoom();
      notifyListeners();
    }
    return success;
  }

  /// Leave current room
  void leaveRoom() {
    _roomService.leaveRoom();
    _currentRoom = null;
    notifyListeners();
  }

  /// Update connected devices list
  void updateDevices() {
    notifyListeners();
  }
}

/// State notifier for messaging
class MessagingNotifier extends ChangeNotifier {
  final MessagingService _messagingService;
  late List<Message> _messages;
  String? _currentRoomCode;

  MessagingNotifier(this._messagingService) {
    _messages = [];
  }

  List<Message> get messages => List.unmodifiable(_messages);

  /// Set the current room and load messages
  void setCurrentRoom(String roomCode) {
    _currentRoomCode = roomCode;
    _loadMessages();
  }

  /// Load messages for current room
  void _loadMessages() {
    if (_currentRoomCode != null) {
      _messages = _messagingService.getMessagesForRoom(_currentRoomCode!);
      notifyListeners();
    }
  }

  /// Add a new message
  void addMessage({
    required String senderDeviceId,
    required String senderDeviceName,
    required String content,
  }) {
    if (_currentRoomCode != null) {
      _messagingService.addMessage(
        senderDeviceId: senderDeviceId,
        senderDeviceName: senderDeviceName,
        content: content,
        roomCode: _currentRoomCode!,
      );
      _loadMessages();
    }
  }

  /// Clear messages for current room
  void clearMessages() {
    if (_currentRoomCode != null) {
      _messagingService.clearRoomMessages(_currentRoomCode!);
      _messages = [];
      notifyListeners();
    }
  }

  /// Clear all messages
  void clearAllMessages() {
    _messagingService.clearAllMessages();
    _messages = [];
    notifyListeners();
  }
}

/// State notifier for network connectivity
class NetworkNotifier extends ChangeNotifier {
  final LocalNetworkService _networkService;
  bool _isConnected = false;
  String? _connectedDeviceId;
  String? _errorMessage;

  NetworkNotifier(this._networkService);

  bool get isConnected => _isConnected;
  String? get connectedDeviceId => _connectedDeviceId;
  String? get errorMessage => _errorMessage;

  /// Update connection status
  void updateConnectionStatus(bool connected, String? deviceId) {
    _isConnected = connected;
    _connectedDeviceId = deviceId;
    _errorMessage = null;
    notifyListeners();
  }

  /// Set error message
  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
