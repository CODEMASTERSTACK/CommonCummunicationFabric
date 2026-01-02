import 'package:uuid/uuid.dart';
import '../models/message.dart';

class MessagingService {
  final List<Message> _messages = [];
  final Function(Message)? onMessageAdded;

  MessagingService({this.onMessageAdded});

  /// Add a message to the list
  void addMessage({
    String? id,
    required String senderDeviceId,
    required String senderDeviceName,
    required String content,
    required String roomCode,
    String type = 'text',
    String? fileName,
    String? fileMimeType,
    int? fileSize,
    String? localFilePath,
    DateTime? timestamp,
  }) {
    Message message = Message(
      id: id ?? const Uuid().v4(),
      senderDeviceId: senderDeviceId,
      senderDeviceName: senderDeviceName,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      roomCode: roomCode,
      type: type,
      fileName: fileName,
      fileMimeType: fileMimeType,
      fileSize: fileSize,
      localFilePath: localFilePath,
    );

    _messages.add(message);
    onMessageAdded?.call(message);
  }

  /// Get messages for a specific room
  List<Message> getMessagesForRoom(String roomCode) {
    return _messages.where((m) => m.roomCode == roomCode).toList();
  }

  /// Get all messages
  List<Message> getAllMessages() {
    return List.unmodifiable(_messages);
  }

  /// Update an existing message by id. Only provided fields will be changed.
  void updateMessage(
    String id, {
    String? content,
    String? type,
    String? fileName,
    String? fileMimeType,
    int? fileSize,
    String? localFilePath,
  }) {
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].id == id) {
        final old = _messages[i];
        final updated = Message(
          id: old.id,
          senderDeviceId: old.senderDeviceId,
          senderDeviceName: old.senderDeviceName,
          content: content ?? old.content,
          timestamp: old.timestamp,
          roomCode: old.roomCode,
          type: type ?? old.type,
          fileName: fileName ?? old.fileName,
          fileMimeType: fileMimeType ?? old.fileMimeType,
          fileSize: fileSize ?? old.fileSize,
          localFilePath: localFilePath ?? old.localFilePath,
        );
        _messages[i] = updated;
        return;
      }
    }
  }

  /// Clear messages for a specific room
  void clearRoomMessages(String roomCode) {
    _messages.removeWhere((m) => m.roomCode == roomCode);
  }

  /// Clear all messages
  void clearAllMessages() {
    _messages.clear();
  }
}
