import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../models/message.dart';
import '../models/device.dart';
import '../models/file_transfer.dart';
import '../models/saved_message.dart';
import '../services/messaging_service.dart';
import '../services/room_service.dart';
import '../services/local_network_service.dart';
import '../services/file_service.dart';
import '../services/saved_messages_service.dart';

class ChatScreen extends StatefulWidget {
  final String roomCode;
  final RoomService roomService;
  final MessagingService messagingService;
  final LocalNetworkService networkService;
  final io.Socket?
  remoteSocket; // Connection to remote server if joined remotely
  final Map<String, String> deviceNameMap; // deviceId -> deviceName mapping
  final SavedMessagesService savedMessagesService;

  const ChatScreen({
    Key? key,
    required this.roomCode,
    required this.roomService,
    required this.messagingService,
    required this.networkService,
    this.remoteSocket,
    this.deviceNameMap = const {},
    required this.savedMessagesService,
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
  late Set<String> _savedMessageIds; // Track which messages are saved

  // File transfer state
  StringBuffer _messageBuffer =
      StringBuffer(); // Buffer for incomplete messages
  final Map<String, FileTransfer> _incomingTransfers =
      {}; // fileId -> FileTransfer for receiving
  final Map<String, double> _outgoingProgress =
      {}; // fileId -> upload progress (0.0 to 1.0)
  Future<void> _remoteWriteQueue = Future.value();

  Future<void> _enqueueRemoteWrite(String message) {
    final prev = _remoteWriteQueue;
    final next = prev.then((_) async {
      try {
        widget.remoteSocket!.write(message);
        await widget.remoteSocket!.flush();
      } catch (e) {
        print('Remote socket write error: $e');
      }
    });
    _remoteWriteQueue = next.catchError((_) {});
    return next;
  }

  @override
  void initState() {
    super.initState();
    _messages = widget.messagingService.getMessagesForRoom(widget.roomCode);
    _previousDeviceIds = {}; // Initialize to detect disconnects
    _savedMessageIds = {}; // Initialize saved message IDs
    _loadSavedMessageIds();
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
        } else if (roomCode == widget.roomCode && type == 'fileshare_chunk') {
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

              // Save file to local storage (ask user where to save)
              final savedPath = await _fileService.saveReceivedFileWithPicker(
                suggestedName: transfer.fileName,
                fileBytes: fileBytes,
                mimeType: transfer.mimeType,
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
                final savedPath = await _fileService.saveReceivedFileWithPicker(
                  suggestedName: fileName,
                  fileBytes: fileBytes,
                  mimeType: mimeType,
                );

                // Get sender device name
                final senderName = widget.deviceNameMap[deviceId] ?? deviceId;

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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // If connected remotely, send via socket; otherwise add locally
    if (widget.remoteSocket != null) {
      try {
        final msgData =
            '${widget.roomCode}|message|${widget.roomService.currentDeviceId}|$message\n';
        await _enqueueRemoteWrite(msgData);
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

        final fileObj = io.File(filePath);
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
        final fileId =
            '${DateTime.now().millisecondsSinceEpoch}_${fileName.hashCode}';

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
      final int totalChunks = (fileBytes.length + chunkSize - 1) ~/ chunkSize;
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
        await _enqueueRemoteWrite('$startMessage\n');
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
          await _enqueueRemoteWrite('$chunkMessage\n');
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
        await _enqueueRemoteWrite('$endMessage\n');
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

  void _loadSavedMessageIds() async {
    final savedMessages = widget.savedMessagesService.getSavedMessages();
    setState(() {
      _savedMessageIds = savedMessages.map((m) => m.id).toSet();
    });
  }

  Future<void> _saveMessage(Message message) async {
    try {
      String? savedFilePath = message.localFilePath;

      // If this is a file message and the file exists, copy it to saved files directory
      if (message.type == 'file' && savedFilePath != null) {
        final sourceFile = io.File(savedFilePath);

        // Check if source file exists
        if (await sourceFile.exists()) {
          // Get the saved files directory
          final appDocDir = await getApplicationDocumentsDirectory();
          final savedFilesDir = io.Directory('${appDocDir.path}/saved_files');

          // Create directory if it doesn't exist
          if (!await savedFilesDir.exists()) {
            await savedFilesDir.create(recursive: true);
          }

          // Create destination path with unique name
          final fileName = message.fileName ?? 'file';
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final uniqueFileName = '${timestamp}_$fileName';
          final destPath = '${savedFilesDir.path}/$uniqueFileName';

          // Copy file to saved files directory
          final destFile = await sourceFile.copy(destPath);
          savedFilePath = destFile.path;

          print('File copied to saved files: $savedFilePath');
        }
      }

      final savedMessage = SavedMessage(
        id: message.id,
        content: message.content,
        senderDeviceName: message.senderDeviceName,
        type: message.type,
        fileName: message.fileName,
        fileMimeType: message.fileMimeType,
        fileSize: message.fileSize,
        localFilePath: savedFilePath, // Use the copied path or original path
      );

      await widget.savedMessagesService.saveMessage(savedMessage);
      setState(() {
        _savedMessageIds.add(message.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving message: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _unsaveMessage(String messageId) async {
    await widget.savedMessagesService.unsaveMessage(messageId);
    setState(() {
      _savedMessageIds.remove(messageId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message removed from saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          elevation: 1,
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  widget.roomCode.isNotEmpty
                      ? widget.roomCode[0].toUpperCase()
                      : 'R',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Room • ${widget.roomCode}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${connectedDevices.length} device${connectedDevices.length != 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                // show room details
                showModalBottomSheet(
                  context: context,
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room Code',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(widget.roomCode),
                        const SizedBox(height: 12),
                        Text(
                          'Connected Devices',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: connectedDevices.length,
                            itemBuilder: (ctx, i) {
                              final d = connectedDevices[i];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Chip(
                                  avatar: Icon(
                                    d.type == 'phone'
                                        ? Icons.smartphone
                                        : Icons.desktop_mac,
                                    size: 18,
                                  ),
                                  label: Text(d.name),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.12),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No messages yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send the first message to get started',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        final isCurrentUser =
                            message.senderDeviceId ==
                            widget.roomService.currentDeviceId;

                        // Date separator logic: show a date header when the previous message is on a different day
                        final showDateSeparator =
                            index == 0 ||
                            !_isSameDay(
                              message.timestamp,
                              _messages[_messages.length - index].timestamp,
                            );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateSeparator)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      DateFormat.yMMMd().format(
                                        message.timestamp,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ),
                              ),
                            Align(
                              alignment: isCurrentUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.78,
                                ),
                                child: _buildMessageBubble(
                                  message,
                                  isCurrentUser,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
            ),

            // Composer
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(28),
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _isLoadingFile ? null : _pickAndSendFile,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 6,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.insert_emoticon_outlined),
                        onPressed: () {},
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: FloatingActionButton(
                          mini: true,
                          elevation: 2,
                          backgroundColor: const Color(
                            0xFF1E3A8A,
                          ), // Darker blue matching outgoing messages
                          onPressed: _isLoadingFile ? null : _sendMessage,
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMessageBubble(Message message, bool isCurrentUser) {
    final bg = isCurrentUser
        ? const Color(0xFF1E3A8A) // Darker blue for outgoing messages
        : const Color(
            0xFF2C3E50,
          ); // Dark slate background for incoming messages
    final textColor = isCurrentUser
        ? Colors
              .white // White text on darker blue
        : Colors.white; // White text for better visibility on dark background

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
          bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                message.senderDeviceName,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          if (message.type == 'file')
            _buildFileMessageContent(message)
          else
            Text(message.content, style: TextStyle(color: textColor)),
          const SizedBox(height: 8),
          // Message footer with timestamp and save buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ),
              // Save/Unsave buttons
              SizedBox(
                height: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _savedMessageIds.contains(message.id)
                          ? () => _unsaveMessage(message.id)
                          : () => _saveMessage(message),
                      child: Icon(
                        _savedMessageIds.contains(message.id)
                            ? Icons.bookmark
                            : Icons.bookmark_outline,
                        size: 16,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                color: isCurrentUser ? Colors.white : const Color(0xFF3498DB),
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
                        color: isCurrentUser ? Colors.white : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      fileSizeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrentUser
                            ? Colors.white70
                            : Colors.grey.shade300,
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
                  backgroundColor: isCurrentUser
                      ? Colors.white24
                      : Colors.grey.shade600,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCurrentUser ? Colors.white : const Color(0xFF3498DB),
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(transferProgress.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: isCurrentUser ? Colors.white70 : Colors.grey.shade300,
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
                  backgroundColor: isCurrentUser
                      ? Colors.white24
                      : Colors.grey.shade600,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCurrentUser ? Colors.white : const Color(0xFF3498DB),
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(outgoingProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: isCurrentUser ? Colors.white70 : Colors.grey.shade300,
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
