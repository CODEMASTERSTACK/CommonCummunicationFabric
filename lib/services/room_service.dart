import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../models/room.dart';

class RoomService {
  final Map<String, Room> _rooms = {};
  late String _currentDeviceId;
  late String _currentDeviceName;
  String? _currentRoomCode;
  late Device _currentDevice;

  RoomService({required String deviceName}) {
    _currentDeviceId = const Uuid().v4();
    _currentDeviceName = deviceName;
    _currentDevice = Device(
      id: _currentDeviceId,
      name: deviceName,
      type: _getDeviceType(),
      connectedAt: DateTime.now(),
    );
  }

  String get currentDeviceId => _currentDeviceId;
  String get currentDeviceName => _currentDeviceName;
  String? get currentRoomCode => _currentRoomCode;
  Device get currentDevice => _currentDevice;

  /// Generate a 6-digit code for room
  String _generateRoomCode() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Create a new room
  Room createRoom() {
    String code = _generateRoomCode();

    Room room = Room(
      code: code,
      creatorDeviceId: _currentDeviceId,
      creatorDeviceName: _currentDeviceName,
      createdAt: DateTime.now(),
      connectedDevices: [_currentDevice],
    );

    _rooms[code] = room;
    _currentRoomCode = code;
    return room;
  }

  /// Join existing room
  bool joinRoom(String code, {required String deviceName}) {
    if (_rooms.containsKey(code)) {
      Room room = _rooms[code]!;

      Device newDevice = Device(
        id: _currentDeviceId,
        name: deviceName,
        type: _getDeviceType(),
        connectedAt: DateTime.now(),
      );

      // Check if device already exists
      bool exists = room.connectedDevices.any((d) => d.id == _currentDeviceId);
      if (!exists) {
        room.connectedDevices.add(newDevice);
      }

      _currentRoomCode = code;
      return true;
    }
    return false;
  }

  /// Join a remote room (creates local room instance for UI purposes)
  void joinRemoteRoom(String code, {required String deviceName}) {
    if (!_rooms.containsKey(code)) {
      Room room = Room(
        code: code,
        creatorDeviceId: '', // Remote room, no local creator
        creatorDeviceName: 'Remote Host',
        createdAt: DateTime.now(),
        connectedDevices: [],
      );
      _rooms[code] = room;
    }

    Room room = _rooms[code]!;
    Device newDevice = Device(
      id: _currentDeviceId,
      name: deviceName,
      type: _getDeviceType(),
      connectedAt: DateTime.now(),
    );

    bool exists = room.connectedDevices.any((d) => d.id == _currentDeviceId);
    if (!exists) {
      room.connectedDevices.add(newDevice);
    }

    _currentRoomCode = code;
  }

  /// Leave current room
  void leaveRoom() {
    if (_currentRoomCode != null && _rooms.containsKey(_currentRoomCode)) {
      Room room = _rooms[_currentRoomCode]!;
      room.connectedDevices.removeWhere((d) => d.id == _currentDeviceId);

      // Delete room if empty
      if (room.connectedDevices.isEmpty) {
        _rooms.remove(_currentRoomCode);
      }
    }
    _currentRoomCode = null;
  }

  /// Get current room
  Room? getCurrentRoom() {
    if (_currentRoomCode != null) {
      return _rooms[_currentRoomCode];
    }
    return null;
  }

  /// Get all connected devices in current room
  List<Device> getConnectedDevices() {
    Room? room = getCurrentRoom();
    return room?.connectedDevices ?? [];
  }

  /// Verify room code exists
  bool verifyRoomCode(String code) {
    return _rooms.containsKey(code) && _rooms[code]!.isActive;
  }

  /// Get device type based on platform
  String _getDeviceType() {
    // This will be overridden based on the actual platform
    return 'unknown';
  }

  /// Update device status
  void updateDeviceStatus(bool isActive) {
    _currentDevice.isActive = isActive;
    if (_currentRoomCode != null && _rooms.containsKey(_currentRoomCode)) {
      Room room = _rooms[_currentRoomCode]!;
      Device? device = room.connectedDevices.firstWhere(
        (d) => d.id == _currentDeviceId,
        orElse: () => _currentDevice,
      );
      device.isActive = isActive;
    }
  }
}
