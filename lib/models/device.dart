class Device {
  final String id;
  final String name;
  final String type; // 'phone', 'pc', 'laptop'
  final DateTime connectedAt;
  bool isActive;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.connectedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'connectedAt': connectedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      connectedAt: DateTime.parse(json['connectedAt']),
      isActive: json['isActive'] ?? true,
    );
  }
}
