import 'package:uuid/uuid.dart';

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
  })  : id = id ?? const Uuid().v4(),
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
  final List<RecentConnection> _connections = [];

  /// Add a device that joined one of my rooms (type: "visit")
  void addVisitor(String deviceName) {
    _connections.insert(
      0,
      RecentConnection(
        deviceName: deviceName,
        type: 'visit',
      ),
    );
    // Keep only last 20 connections
    if (_connections.length > 20) {
      _connections.removeAt(_connections.length - 1);
    }
  }

  /// Add a room I joined (type: "travel")
  void addTravel(String deviceName) {
    _connections.insert(
      0,
      RecentConnection(
        deviceName: deviceName,
        type: 'travel',
      ),
    );
    // Keep only last 20 connections
    if (_connections.length > 20) {
      _connections.removeAt(_connections.length - 1);
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
  void clear() {
    _connections.clear();
  }
}
