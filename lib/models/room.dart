import 'device.dart';

class Room {
  final String code;
  final String creatorDeviceId;
  final String creatorDeviceName;
  final DateTime createdAt;
  final List<Device> connectedDevices;

  Room({
    required this.code,
    required this.creatorDeviceId,
    required this.creatorDeviceName,
    required this.createdAt,
    required this.connectedDevices,
  });

  bool get isActive => DateTime.now().difference(createdAt).inHours < 24;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'creatorDeviceId': creatorDeviceId,
      'creatorDeviceName': creatorDeviceName,
      'createdAt': createdAt.toIso8601String(),
      'connectedDevices': connectedDevices.map((d) => d.toJson()).toList(),
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      code: json['code'],
      creatorDeviceId: json['creatorDeviceId'],
      creatorDeviceName: json['creatorDeviceName'],
      createdAt: DateTime.parse(json['createdAt']),
      connectedDevices: (json['connectedDevices'] as List)
          .map((d) => Device.fromJson(d))
          .toList(),
    );
  }
}
