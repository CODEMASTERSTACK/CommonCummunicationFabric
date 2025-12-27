import 'package:uuid/uuid.dart';
import '../models/message.dart';

class MessagingService {
  final List<Message> _messages = [];
  final Function(Message)? onMessageAdded;

  MessagingService({this.onMessageAdded});

  /// Add a message to the list
  void addMessage({
    required String senderDeviceId,
    required String senderDeviceName,
    required String content,
    required String roomCode,
    String type = 'text',
    String? fileName,
    String? fileMimeType,
    int? fileSize,
    String? localFilePath,
  }) {
    Message message = Message(
      id: const Uuid().v4(),
      senderDeviceId: senderDeviceId,
      senderDeviceName: senderDeviceName,
      content: content,
      timestamp: DateTime.now(),
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

  /// Clear messages for a specific room
  void clearRoomMessages(String roomCode) {
    _messages.removeWhere((m) => m.roomCode == roomCode);
  }

  /// Clear all messages
  void clearAllMessages() {
    _messages.clear();
  }
}
