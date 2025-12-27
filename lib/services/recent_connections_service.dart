import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentConnection {
  final String id;
  final String deviceName;
  final String type; // "visit" = joined my room, "travel" = room I joined
  final DateTime connectedAt;

  RecentConnection({
    String? id,
    required this.deviceName,
    required this.type,
    DateTime? connectedAt,
  }) : id = id ?? const Uuid().v4(),
       connectedAt = connectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceName': deviceName,
      'type': type,
      'connectedAt': connectedAt.toIso8601String(),
    };
  }

  factory RecentConnection.fromJson(Map<String, dynamic> json) {
    return RecentConnection(
      id: json['id'] as String,
      deviceName: json['deviceName'] as String,
      type: json['type'] as String,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
    );
  }
}

class RecentConnectionsService {
  static const String _storageKey = 'recent_connections';
  final List<RecentConnection> _connections = [];
  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize the service and load saved connections
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadConnections();
    _initialized = true;
  }

  /// Load connections from persistent storage
  Future<void> _loadConnections() async {
    try {
      final jsonString = _prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _connections.clear();
        for (final item in jsonList) {
          _connections.add(
            RecentConnection.fromJson(item as Map<String, dynamic>),
          );
        }
      }
    } catch (e) {
      print('Error loading connections: $e');
    }
  }

  /// Save connections to persistent storage
  Future<void> _saveConnections() async {
    try {
      final jsonList = _connections.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error saving connections: $e');
    }
  }

  /// Add a device that joined one of my rooms (type: "visit")
  Future<void> addVisitor(String deviceName) async {
    await _ensureInitialized();
    _connections.insert(
      0,
      RecentConnection(deviceName: deviceName, type: 'visit'),
    );
    // Keep only last 20 connections
    if (_connections.length > 20) {
      _connections.removeAt(_connections.length - 1);
    }
    await _saveConnections();
  }

  /// Add a room I joined (type: "travel")
  Future<void> addTravel(String deviceName) async {
    await _ensureInitialized();
    _connections.insert(
      0,
      RecentConnection(deviceName: deviceName, type: 'travel'),
    );
    // Keep only last 20 connections
    if (_connections.length > 20) {
      _connections.removeAt(_connections.length - 1);
    }
    await _saveConnections();
  }

  /// Ensure service is initialized before operations
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Get all recent connections
  List<RecentConnection> getConnections() {
    return List.unmodifiable(_connections);
  }

  /// Get recent connections of a specific type
  List<RecentConnection> getConnectionsByType(String type) {
    return _connections.where((c) => c.type == type).toList();
  }

  /// Get unique device names (latest occurrence)
  List<(String deviceName, String type)> getUniqueDevices() {
    final seen = <String>{};
    final result = <(String, String)>[];

    for (final conn in _connections) {
      if (!seen.contains(conn.deviceName)) {
        seen.add(conn.deviceName);
        result.add((conn.deviceName, conn.type));
      }
    }

    return result;
  }

  /// Clear all connections
  Future<void> clear() async {
    await _ensureInitialized();
    _connections.clear();
    await _saveConnections();
  }
}
