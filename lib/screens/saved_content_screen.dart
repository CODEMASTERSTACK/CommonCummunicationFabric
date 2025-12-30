import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../models/saved_message.dart';
import '../services/saved_messages_service.dart';
import '../services/file_service.dart';

class SavedContentScreen extends StatefulWidget {
  final SavedMessagesService savedMessagesService;

  const SavedContentScreen({Key? key, required this.savedMessagesService})
    : super(key: key);

  @override
  State<SavedContentScreen> createState() => _SavedContentScreenState();
}

class _SavedContentScreenState extends State<SavedContentScreen> {
  late List<SavedMessage> _savedMessages;
  String _selectedFilter = 'all'; // all, text, file

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    setState(() {
      if (_selectedFilter == 'text') {
        _savedMessages = widget.savedMessagesService.getSavedMessagesByType(
          'text',
        );
      } else if (_selectedFilter == 'file') {
        _savedMessages = widget.savedMessagesService.getSavedMessagesByType(
          'file',
        );
      } else {
        _savedMessages = widget.savedMessagesService.getSavedMessages();
      }
    });
  }

  Future<void> _unsaveMessage(String messageId) async {
    await widget.savedMessagesService.unsaveMessage(messageId);
    _loadMessages();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message removed from saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openFile(String filePath) async {
    try {
      // Check if file exists first
      final file = io.File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File no longer exists on this device'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text(
          'Saved Content',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_savedMessages.isNotEmpty)
            PopupMenuButton(
              onSelected: (value) async {
                if (value == 'clear_all') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear All Saved Messages?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.savedMessagesService.clearAll();
                            _loadMessages();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All saved messages cleared'),
                              ),
                            );
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear All'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Text', 'text'),
                const SizedBox(width: 8),
                _buildFilterChip('Files', 'file'),
              ],
            ),
          ),
          // Messages list
          Expanded(
            child: _savedMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_outline,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.12),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'No saved content',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Save messages and files to see them here',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: _savedMessages.length,
                    itemBuilder: (context, index) {
                      final message = _savedMessages[index];
                      return _buildSavedMessageCard(message);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          _loadMessages();
        });
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
    );
  }

  Widget _buildSavedMessageCard(SavedMessage message) {
    final isBright = Theme.of(context).brightness == Brightness.light;
    final cardColor = isBright
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.surfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with sender name and time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.senderDeviceName,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'MMM d, yyyy • HH:mm',
                        ).format(message.savedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Unsave button
                IconButton(
                  icon: const Icon(Icons.bookmark, color: Colors.amber),
                  iconSize: 20,
                  onPressed: () => _unsaveMessage(message.id),
                  tooltip: 'Remove from saved',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Message content
            if (message.type == 'file')
              _buildSavedFileContent(message)
            else
              Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedFileContent(SavedMessage message) {
    final fileName = message.fileName ?? 'Unknown file';
    final fileSize = message.fileSize ?? 0;
    final fileSizeStr = FileService.formatFileSize(fileSize);
    final hasPath =
        message.localFilePath != null && message.localFilePath!.isNotEmpty;

    return FutureBuilder<bool>(
      future: hasPath
          ? io.File(message.localFilePath!).exists()
          : Future.value(false),
      builder: (context, snapshot) {
        final fileExists = snapshot.data ?? false;

        return InkWell(
          onTap: fileExists ? () => _openFile(message.localFilePath!) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getFileIcon(message.fileMimeType),
                      color: fileExists
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fileSizeStr,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (fileExists)
                      Icon(
                        Icons.open_in_new,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      )
                    else
                      Icon(
                        Icons.error_outline,
                        color: Colors.orange.shade700,
                        size: 18,
                      ),
                  ],
                ),
                if (!fileExists) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'File not found on device',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
