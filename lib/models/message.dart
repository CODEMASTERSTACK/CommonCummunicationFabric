class Message {
  final String id;
  final String senderDeviceId;
  final String senderDeviceName;
  final String content;
  final DateTime timestamp;
  final String roomCode;

  Message({
    required this.id,
    required this.senderDeviceId,
    required this.senderDeviceName,
    required this.content,
    required this.timestamp,
    required this.roomCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderDeviceId': senderDeviceId,
      'senderDeviceName': senderDeviceName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'roomCode': roomCode,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderDeviceId: json['senderDeviceId'],
      senderDeviceName: json['senderDeviceName'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      roomCode: json['roomCode'],
    );
  }
}
