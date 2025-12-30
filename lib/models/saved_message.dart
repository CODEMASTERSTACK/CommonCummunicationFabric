import 'package:uuid/uuid.dart';

class SavedMessage {
  final String id;
  final String content;
  final String senderDeviceName;
  final DateTime savedAt;
  final String type; // 'text' or 'file'
  final String? fileName;
  final String? fileMimeType;
  final int? fileSize;
  final String? localFilePath;

  SavedMessage({
    String? id,
    required this.content,
    required this.senderDeviceName,
    DateTime? savedAt,
    required this.type,
    this.fileName,
    this.fileMimeType,
    this.fileSize,
    this.localFilePath,
  }) : id = id ?? const Uuid().v4(),
       savedAt = savedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'senderDeviceName': senderDeviceName,
      'savedAt': savedAt.toIso8601String(),
      'type': type,
      'fileName': fileName,
      'fileMimeType': fileMimeType,
      'fileSize': fileSize,
      'localFilePath': localFilePath,
    };
  }

  factory SavedMessage.fromJson(Map<String, dynamic> json) {
    return SavedMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      senderDeviceName: json['senderDeviceName'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      type: json['type'] as String,
      fileName: json['fileName'] as String?,
      fileMimeType: json['fileMimeType'] as String?,
      fileSize: json['fileSize'] as int?,
      localFilePath: json['localFilePath'] as String?,
    );
  }
}
