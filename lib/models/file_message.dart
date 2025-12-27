import 'package:uuid/uuid.dart';

class FileMessage {
  final String id;
  final String senderDeviceId;
  final String senderDeviceName;
  final String fileName;
  final String fileMimeType; // e.g., image/png, application/pdf
  final int fileSize;
  final DateTime timestamp;
  final String roomCode;
  final String? localPath; // Path where file was saved locally

  FileMessage({
    String? id,
    required this.senderDeviceId,
    required this.senderDeviceName,
    required this.fileName,
    required this.fileMimeType,
    required this.fileSize,
    DateTime? timestamp,
    required this.roomCode,
    this.localPath,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderDeviceId': senderDeviceId,
      'senderDeviceName': senderDeviceName,
      'fileName': fileName,
      'fileMimeType': fileMimeType,
      'fileSize': fileSize,
      'timestamp': timestamp.toIso8601String(),
      'roomCode': roomCode,
      'localPath': localPath,
    };
  }

  factory FileMessage.fromJson(Map<String, dynamic> json) {
    return FileMessage(
      id: json['id'] as String,
      senderDeviceId: json['senderDeviceId'] as String,
      senderDeviceName: json['senderDeviceName'] as String,
      fileName: json['fileName'] as String,
      fileMimeType: json['fileMimeType'] as String,
      fileSize: json['fileSize'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      roomCode: json['roomCode'] as String,
      localPath: json['localPath'] as String?,
    );
  }
}
