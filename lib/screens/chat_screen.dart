import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../models/message.dart';
import '../models/device.dart';
import '../models/file_transfer.dart';
import '../services/messaging_service.dart';
import '../services/room_service.dart';
import '../services/local_network_service.dart';
import '../services/file_service.dart';

class ChatScreen extends StatefulWidget {
  final String roomCode;
  final RoomService roomService;
  final MessagingService messagingService;
  final LocalNetworkService networkService;
  final Socket? remoteSocket; // Connection to remote server if joined remotely
  final Map<String, String> deviceNameMap; // deviceId -> deviceName mapping

  const ChatScreen({
    Key? key,
    required this.roomCode,
    required this.roomService,
    required this.messagingService,
    required this.networkService,
    this.remoteSocket,
    this.deviceNameMap = const {},
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int chunkSize = 256 * 1024; // 256KB chunks

  final TextEditingController _messageController = TextEditingController();
  late List<Message> _messages;
  bool _isConnected = true;
  Timer? _refreshTimer;
  late Set<String>
  _previousDeviceIds; // Track devices to detect disconnects on host
  final FileService _fileService = FileService();
  bool _isLoadingFile = false;

  // File transfer state
  StringBuffer _messageBuffer =
      StringBuffer(); // Buffer for incomplete messages
  final Map<String, FileTransfer> _incomingTransfers =
      {}; // fileId -> FileTransfer for receiving
  final Map<String, double> _outgoingProgress =
      {}; // fileId -> upload progress (0.0 to 1.0)

  @override
  void initState() {
    super.initState();
    _messages = widget.messagingService.getMessagesForRoom(widget.roomCode);
    _previousDeviceIds = {}; // Initialize to detect disconnects
    // If we're connected remotely, listen for incoming messages
    if (widget.remoteSocket != null) {
      _listenForRemoteMessages();
    } else {
      // For host mode, start a timer to refresh messages periodically
      // This ensures the UI updates when messages are received from clients
      _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) {
          final room = widget.roomService.getCurrentRoom();
          final currentDevices = room?.connectedDevices ?? [];
          final currentDeviceIds = currentDevices.map((d) => d.id).toSet();

          // Check for devices that were there before but aren't now
          final disconnectedIds = _previousDeviceIds.difference(
            currentDeviceIds,
          );
          for (final disconId in disconnectedIds) {
            final deviceName = widget.deviceNameMap[disconId] ?? disconId;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$deviceName left the room'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
          _previousDeviceIds = currentDeviceIds;

          setState(() {
            _messages = widget.messagingService.getMessagesForRoom(
              widget.roomCode,
            );
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _listenForRemoteMessages() {
    widget.remoteSocket!.listen(
      (List<int> data) async {
        try {
          // Append incoming data to buffer
          _messageBuffer.write(utf8.decode(data));

          // Process complete messages (lines ending with \n)
          String bufferContent = _messageBuffer.toString();
          List<String> lines = bufferContent.split('\n');

          // Keep the last incomplete line in the buffer
          _messageBuffer.clear();
          if (!bufferContent.endsWith('\n') && lines.isNotEmpty) {
            _messageBuffer.write(lines.last);
            lines = lines.sublist(0, lines.length - 1);
          }

          // Process all complete messages
          for (String message in lines) {
            if (message.trim().isEmpty) continue;

            await _processReceivedMessage(message);
          }
        } catch (e) {
          print('Error receiving message: $e');
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isConnected = false);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isConnected = false);
        }
      },
    );
  }

  Future<void> _processReceivedMessage(String message) async {
    try {
      // Protocol: roomCode|type|deviceId|content
      final parts = message.split('|');
      if (parts.length >= 4) {
        final roomCode = parts[0];
        final type = parts[1];
        final deviceId = parts[2];
        final content = parts.sublist(3).join('|');

        if (roomCode == widget.roomCode && type == 'message') {
          widget.messagingService.addMessage(
            senderDeviceId: deviceId,
            senderDeviceName: deviceId,
            content: content,
            roomCode: roomCode,
          );
          if (mounted) {
            setState(() {
              _messages = widget.messagingService.getMessagesForRoom(
                widget.roomCode,
              );
            });
          }
        } else if (roomCode == widget.roomCode && type == 'fileshare_start') {
          // Start of chunked file transfer
          try {
            final metadata = jsonDecode(content) as Map<String, dynamic>;
            final fileId = metadata['fileId'] as String;
            final fileName = metadata['fileName'] as String?;
            final mimeType = metadata['mimeType'] as String?;
            final fileSize = metadata['fileSize'] as int?;
            final totalChunks = metadata['totalChunks'] as int?;

            if (fileName != null && totalChunks != null) {
              final transfer = FileTransfer(
                fileId: fileId,
                fileName: fileName,
                totalSize: fileSize ?? 0,
                chunkSize: chunkSize,
                totalChunks: totalChunks,
                senderDeviceId: deviceId,
                senderDeviceName: widget.deviceNameMap[deviceId] ?? deviceId,
                mimeType: mimeType ?? '',
              );
              _incomingTransfers[fileId] = transfer;
              print('Started receiving file: $fileName ($totalChunks chunks)');
            }
          } catch (e) {
            print('Error processing fileshare_start: $e');
          }
        } else if (roomCode == widget.roomCode &&
            type == 'fileshare_chunk') {
          // Chunk of file data
          try {
            final metadata = jsonDecode(content) as Map<String, dynamic>;
            final fileId = metadata['fileId'] as String;
            final chunkIndex = metadata['chunkIndex'] as int;
            final totalChunks = metadata['totalChunks'] as int;
            final chunkDataBase64 = metadata['chunkData'] as String;

            final transfer = _incomingTransfers[fileId];
            if (transfer != null) {
              final chunkData = base64Decode(chunkDataBase64);
              transfer.chunks[chunkIndex] = chunkData;
              transfer.chunksReceived++;

              print(
                'Received chunk $chunkIndex/$totalChunks for ${transfer.fileName} (${(transfer.progress * 100).toStringAsFixed(1)}%)',
              );

              if (mounted) {
                setState(() {}); // Update progress indicator
              }
            }
          } catch (e) {
            print('Error processing fileshare_chunk: $e');
          }
        } else if (roomCode == widget.roomCode && type == 'fileshare_end') {
          // End of file transfer - reassemble and save
          try {
            final fileId = content;
            final transfer = _incomingTransfers[fileId];

            if (transfer != null && transfer.isComplete) {
              print('File transfer complete: ${transfer.fileName}');

              // Reassemble file
              final fileBytes = transfer.reassemble();

              // Save file to local storage
              final savedPath = await _fileService.saveReceivedFile(
                fileName: transfer.fileName,
                fileBytes: fileBytes,
              );

              // Add file message to storage
              widget.messagingService.addMessage(
                senderDeviceId: transfer.senderDeviceId,
                senderDeviceName: transfer.senderDeviceName,
                content: 'Sent a file: ${transfer.fileName}',
                roomCode: roomCode,
                type: 'file',
                fileName: transfer.fileName,
                fileMimeType: transfer.mimeType,
                fileSize: fileBytes.length,
                localFilePath: savedPath,
              );

              print('File saved to: $savedPath');

              // Clean up transfer
              _incomingTransfers.remove(fileId);

              if (mounted) {
                setState(() {
                  _messages = widget.messagingService.getMessagesForRoom(
                    widget.roomCode,
                  );
                });
              }
            }
          } catch (e) {
            print('Error finalizing file transfer: $e');
          }
        } else if (roomCode == widget.roomCode && type == 'fileshare') {
          // Legacy: Handle single-chunk file share (for backward compatibility)
          final isOwnFile = (deviceId == widget.roomService.currentDeviceId);

          if (!isOwnFile) {
            try {
              final fileMetadata = jsonDecode(content) as Map<String, dynamic>;
              final fileName = fileMetadata['fileName'] as String?;
              final mimeType = fileMetadata['mimeType'] as String?;
              final fileSize = fileMetadata['fileSize'] as int?;
              final base64Data = fileMetadata['base64Data'] as String?;

              if (fileName != null && base64Data != null) {
                print(
                  'Processing legacy fileshare: $fileName (${base64Data.length} chars of base64)',
                );
                // Decode base64 to binary
                final fileBytes = base64Decode(base64Data);

                // Save file to local storage
                final savedPath = await _fileService.saveReceivedFile(
                  fileName: fileName,
                  fileBytes: fileBytes,
                );

                // Get sender device name
                final senderName =
                    widget.deviceNameMap[deviceId] ?? deviceId;

                // Add file message to storage
                widget.messagingService.addMessage(
                  senderDeviceId: deviceId,
                  senderDeviceName: senderName,
                  content: 'Sent a file: $fileName',
                  roomCode: roomCode,
                  type: 'file',
                  fileName: fileName,
                  fileMimeType: mimeType,
                  fileSize: fileSize,
                  localFilePath: savedPath,
                );

                print('File saved to: $savedPath');

                if (mounted) {
                  setState(() {
                    _messages = widget.messagingService.getMessagesForRoom(
                      widget.roomCode,
                    );
                  });
                }
              }
            } catch (e) {
              print('Error processing legacy file message: $e');
            }
          }
        } else if (roomCode == widget.roomCode && type == 'device_joined') {
          // Another device joined, add it to the local room
          final room = widget.roomService.getCurrentRoom();
          if (room != null) {
            final alreadyExists = room.connectedDevices.any(
              (d) => d.id == deviceId,
            );
            if (!alreadyExists) {
              room.connectedDevices.add(
                Device(
                  id: deviceId,
                  name: content,
                  type: 'phone',
                  connectedAt: DateTime.now(),
                  isActive: true,
                ),
              );
              if (mounted) {
                setState(() {}); // Trigger rebuild to update device list
              }
            }
          }
        } else if (roomCode == widget.roomCode && type == 'device_left') {
          // A device left the room; remove from local list and show a popup
          final room = widget.roomService.getCurrentRoom();
          if (room != null) {
            room.connectedDevices.removeWhere((d) => d.id == deviceId);
            if (mounted) {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${content} left the room'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error processing received message: $e');
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // If connected remotely, send via socket; otherwise add locally
    if (widget.remoteSocket != null) {
      try {
        final msgData =
            '${widget.roomCode}|message|${widget.roomService.currentDeviceId}|$message\n';
        widget.remoteSocket!.write(msgData);
        widget.remoteSocket!.flush(); // Ensure message is sent immediately
        // Don't add locally - the server will broadcast it back to us
      } catch (e) {
        print('Error sending message: $e');
        return;
      }
    } else {
      widget.messagingService.addMessage(
        senderDeviceId: widget.roomService.currentDeviceId,
        senderDeviceName: widget.roomService.currentDeviceName,
        content: message,
        roomCode: widget.roomCode,
      );
      // Host broadcasts message to all connected clients
      widget.networkService.hostBroadcastMessage(
        widget.roomCode,
        widget.roomService.currentDeviceId,
        message,
      );
    }

    _messageController.clear();
    setState(() {
      _messages = widget.messagingService.getMessagesForRoom(widget.roomCode);
    });
  }

  Future<void> _pickAndSendFile() async {
    try {
      setState(() => _isLoadingFile = true);

      final result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final filePath = file.path;

        if (filePath == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to access file')),
            );
          }
          return;
        }

        final fileObj = File(filePath);
        final fileSize = await fileObj.length();

        // Validate file size (100MB limit)
        if (fileSize > maxFileSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'File too large. Maximum size is ${FileService.formatFileSize(maxFileSize)}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final fileBytes = await fileObj.readAsBytes();
        final fileName = file.name;
        final mimeType = _fileService.getMimeType(fileName);

        // Generate unique file ID for this transfer
        final fileId = '${DateTime.now().millisecondsSinceEpoch}_${fileName.hashCode}';

        // Create file message metadata
        final fileMessage = Message(
          id: fileId,
          senderDeviceId: widget.roomService.currentDeviceId,
          senderDeviceName: widget.roomService.currentDeviceName,
          content: 'Sent a file: $fileName',
          timestamp: DateTime.now(),
          roomCode: widget.roomCode,
          type: 'file',
          fileName: fileName,
          fileMimeType: mimeType,
          fileSize: fileBytes.length,
        );

        // Add message to local storage
        widget.messagingService.addMessage(
          senderDeviceId: fileMessage.senderDeviceId,
          senderDeviceName: fileMessage.senderDeviceName,
          content: fileMessage.content,
          roomCode: widget.roomCode,
          type: 'file',
          fileName: fileName,
          fileMimeType: mimeType,
          fileSize: fileBytes.length,
        );

        // Send file in chunks
        await _sendFileInChunks(fileId, fileMessage, fileBytes);

        if (mounted) {
          setState(() {
            _messages = widget.messagingService.getMessagesForRoom(
              widget.roomCode,
            );
            _outgoingProgress.remove(fileId);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File shared successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing file: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFile = false);
      }
    }
  }

  Future<void> _sendFileInChunks(
    String fileId,
    Message fileMessage,
    List<int> fileBytes,
  ) async {
    try {
      final int totalChunks =
          (fileBytes.length + chunkSize - 1) ~/ chunkSize;
      _outgoingProgress[fileId] = 0.0;

      // Send start message with file metadata
      final startMetadata = {
        'fileId': fileId,
        'fileName': fileMessage.fileName,
        'mimeType': fileMessage.fileMimeType,
        'fileSize': fileBytes.length,
        'chunkSize': chunkSize,
        'totalChunks': totalChunks,
      };

      final startMessage =
          '${fileMessage.roomCode}|fileshare_start|${fileMessage.senderDeviceId}|${jsonEncode(startMetadata)}';

      if (widget.remoteSocket != null) {
        widget.remoteSocket!.write('$startMessage\n');
        widget.remoteSocket!.flush();
      } else {
        widget.networkService.hostBroadcastFileShareStart(
          fileMessage.roomCode,
          fileMessage.senderDeviceId,
          jsonEncode(startMetadata),
        );
      }

      // Send chunks
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (i + 1) * chunkSize > fileBytes.length
            ? fileBytes.length
            : (i + 1) * chunkSize;
        final chunk = fileBytes.sublist(start, end);
        final base64Chunk = base64Encode(chunk);

        final chunkMetadata = {
          'fileId': fileId,
          'chunkIndex': i,
          'totalChunks': totalChunks,
          'chunkData': base64Chunk,
        };

        final chunkMessage =
            '${fileMessage.roomCode}|fileshare_chunk|${fileMessage.senderDeviceId}|${jsonEncode(chunkMetadata)}';

        if (widget.remoteSocket != null) {
          widget.remoteSocket!.write('$chunkMessage\n');
          widget.remoteSocket!.flush();
        } else {
          widget.networkService.hostBroadcastFileShareChunk(
            fileMessage.roomCode,
            fileMessage.senderDeviceId,
            jsonEncode(chunkMetadata),
          );
        }

        // Update progress
        setState(() {
          _outgoingProgress[fileId] = (i + 1) / totalChunks;
        });

        // Add small delay to prevent overwhelming the socket
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Send end message
      final endMessage =
          '${fileMessage.roomCode}|fileshare_end|${fileMessage.senderDeviceId}|$fileId';

      if (widget.remoteSocket != null) {
        widget.remoteSocket!.write('$endMessage\n');
        widget.remoteSocket!.flush();
      } else {
        widget.networkService.hostBroadcastFileShareEnd(
          fileMessage.roomCode,
          fileMessage.senderDeviceId,
          fileId,
        );
      }

      print('File $fileId sent in $totalChunks chunks');
    } catch (e) {
      print('Error sending file in chunks: $e');
      _outgoingProgress.remove(fileId);
    }
  }

  void _leaveRoom() {
    widget.roomService.leaveRoom();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.roomService.getCurrentRoom();
    final connectedDevices = widget.roomService.getConnectedDevices();

    return WillPopScope(
      onWillPop: () async {
        _leaveRoom();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Room'),
              Text(
                'Code: ${widget.roomCode}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  '${connectedDevices.length} device${connectedDevices.length != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Connected Devices Section
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Connected Devices',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: connectedDevices.length,
                      itemBuilder: (context, index) {
                        final device = connectedDevices[index];
                        final isCurrentDevice =
                            device.id == widget.roomService.currentDeviceId;

                        return Card(
                          color: isCurrentDevice
                              ? Colors.blue.shade50
                              : Colors.grey.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  device.type == 'phone'
                                      ? Icons.smartphone
                                      : Icons.desktop_mac,
                                  color: device.isActive
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  device.name,
                                  style: const TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isCurrentDevice)
                                  const Text(
                                    '(You)',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.blue,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Messages Section
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send the first message to get started',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        final isCurrentUser =
                            message.senderDeviceId ==
                            widget.roomService.currentDeviceId;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Align(
                            alignment: isCurrentUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: isCurrentUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isCurrentUser)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      message.senderDeviceName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrentUser
                                        ? Colors.blue
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Handle file messages differently
                        if (message.type == 'file')
                          _buildFileMessageContent(message)
                        else
                          Text(
                            message.content,
                            style: TextStyle(
                              color: isCurrentUser
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'HH:mm',
                          ).format(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isCurrentUser
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Message Input Section
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // File picker button
                    CircleAvatar(
                      backgroundColor: Colors.green,
                      child: IconButton(
                        icon: const Icon(
                          Icons.attach_file,
                          color: Colors.white,
                        ),
                        onPressed: _isLoadingFile ? null : _pickAndSendFile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        enabled: !_isLoadingFile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _isLoadingFile ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMessageContent(Message message) {
    final isCurrentUser =
        message.senderDeviceId == widget.roomService.currentDeviceId;
    final fileName = message.fileName ?? 'Unknown file';
    final fileSize = message.fileSize ?? 0;
    final fileSizeStr = FileService.formatFileSize(fileSize);

    // Check if this file is currently being transferred
    final fileId = message.id;
    final transferProgress = _incomingTransfers[fileId];
    final outgoingProgress = _outgoingProgress[fileId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: message.localFilePath != null
              ? () {
                  _openFile(message.localFilePath!);
                }
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(message.fileMimeType),
                color: isCurrentUser ? Colors.white : Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      fileSizeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrentUser
                            ? Colors.white70
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Show progress if transfer is in progress
        if (transferProgress != null && !transferProgress.isComplete)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: transferProgress.progress,
                  backgroundColor:
                      isCurrentUser ? Colors.white24 : Colors.grey.shade400,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCurrentUser ? Colors.white : Colors.blue,
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(transferProgress.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: isCurrentUser
                      ? Colors.white70
                      : Colors.grey.shade600,
                ),
              ),
            ],
          )
        else if (outgoingProgress != null && outgoingProgress < 1.0)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: outgoingProgress,
                  backgroundColor:
                      isCurrentUser ? Colors.white24 : Colors.grey.shade400,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCurrentUser ? Colors.white : Colors.blue,
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(outgoingProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: isCurrentUser
                      ? Colors.white70
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
      ],
    );
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) {
      return Icons.file_present;
    }
    if (mimeType.startsWith('image/')) {
      return Icons.image;
    }
    if (mimeType == 'application/pdf') {
      return Icons.picture_as_pdf;
    }
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    }
    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart;
    }
    return Icons.attach_file;
  }

  void _openFile(String filePath) {
    // For demonstration, show a dialog
    // In production, use plugins like 'open_file' to actually open files
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File saved at: $filePath'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
