class Message {
  final String id;
  final String senderDeviceId;
  final String senderDeviceName;
  final String content;
  final DateTime timestamp;
  final String roomCode;
  final String type; // 'text' or 'file'
  final String? fileName; // For file messages
  final String? fileMimeType; // For file messages
  final int? fileSize; // For file messages
  final String? localFilePath; // For file messages

  Message({
    required this.id,
    required this.senderDeviceId,
    required this.senderDeviceName,
    required this.content,
    required this.timestamp,
    required this.roomCode,
    this.type = 'text',
    this.fileName,
    this.fileMimeType,
    this.fileSize,
    this.localFilePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderDeviceId': senderDeviceId,
      'senderDeviceName': senderDeviceName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'roomCode': roomCode,
      'type': type,
      'fileName': fileName,
      'fileMimeType': fileMimeType,
      'fileSize': fileSize,
      'localFilePath': localFilePath,
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
      type: json['type'] ?? 'text',
      fileName: json['fileName'],
      fileMimeType: json['fileMimeType'],
      fileSize: json['fileSize'],
      localFilePath: json['localFilePath'],
    );
  }
}
