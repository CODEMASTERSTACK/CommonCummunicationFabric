import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';

class FileService {
  static const String _fileDirectoryName = 'shared_files';

  /// Get or create the shared files directory
  Future<Directory> getSharedFilesDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final sharedFilesDir = Directory('${appDocDir.path}/$_fileDirectoryName');

    if (!await sharedFilesDir.exists()) {
      await sharedFilesDir.create(recursive: true);
    }

    return sharedFilesDir;
  }

  /// Save received file data to local storage
  Future<String> saveReceivedFile({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      final dir = await getSharedFilesDirectory();
      final filePath = '${dir.path}/$fileName';

      // If file exists, add timestamp to make it unique
      File targetFile = File(filePath);
      if (await targetFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = fileName.split('.').first;
        final ext = fileName.split('.').last;
        final newFileName = '${nameWithoutExt}_$timestamp.$ext';
        targetFile = File('${dir.path}/$newFileName');
      }

      await targetFile.writeAsBytes(fileBytes);
      return targetFile.path;
    } catch (e) {
      print('Error saving file: $e');
      rethrow;
    }
  }

  /// Save file by asking user where to store it (uses platform dialog on Android)
  /// Returns the saved file path or null if cancelled.
  Future<String?> saveReceivedFileWithPicker({
    required String suggestedName,
    required List<int> fileBytes,
    String? mimeType,
  }) async {
    try {
      // On Android, use the native save dialog implemented in MainActivity
      if (Platform.isAndroid) {
        try {
          const channel = MethodChannel('common_com/file_saver');
          final encoded = base64Encode(fileBytes);
          final result = await channel.invokeMethod<String?>('saveFile', {
            'fileName': suggestedName,
            'bytes': encoded,
            'mimeType': mimeType ?? getMimeType(suggestedName),
          });
          return result; // platform returns a uri or file path string or null
        } on PlatformException catch (e) {
          print('Platform error saving file with picker: $e');
          // fall through to saving to downloads
        }
      }

      // Fallback for non-Android (desktop/ios): save to user's Downloads or Documents folder
      String? downloadsPath;
      final env = Platform.environment;
      if (Platform.isWindows) {
        final userProfile = env['USERPROFILE'];
        if (userProfile != null) downloadsPath = '$userProfile\\Downloads';
      } else {
        final home = env['HOME'];
        if (home != null) downloadsPath = '$home/Downloads';
      }

      Directory targetDir;
      if (downloadsPath != null) {
        targetDir = Directory(downloadsPath);
        if (!await targetDir.exists()) {
          targetDir = await getApplicationDocumentsDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      String targetPath = '${targetDir.path}${Platform.pathSeparator}$suggestedName';
      File targetFile = File(targetPath);
      if (await targetFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = suggestedName.split('.').first;
        final ext = (suggestedName.contains('.') ? '.${suggestedName.split('.').last}' : '');
        targetFile = File('${targetDir.path}${Platform.pathSeparator}${nameWithoutExt}_$timestamp$ext');
      }

      await targetFile.writeAsBytes(fileBytes);
      return targetFile.path;
    } catch (e) {
      print('Error saving file with picker/fallback: $e');
      rethrow;
    }
  }

  /// Get MIME type for a file
  String getMimeType(String fileName) {
    final mimeType = lookupMimeType(fileName);
    return mimeType ?? 'application/octet-stream';
  }

  /// Get file extension from MIME type
  String getFileExtension(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'application/pdf':
        return '.pdf';
      case 'application/msword':
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return '.doc';
      case 'application/vnd.ms-excel':
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return '.xls';
      default:
        return '.bin';
    }
  }

  /// Check if a file is an image
  bool isImage(String mimeType) {
    return mimeType.startsWith('image/');
  }

  /// Check if a file is a PDF
  bool isPdf(String mimeType) {
    return mimeType == 'application/pdf';
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get files from shared files directory
  Future<List<File>> getSharedFiles() async {
    try {
      final dir = await getSharedFilesDirectory();
      final files = dir.listSync();
      return files.whereType<File>().toList();
    } catch (e) {
      print('Error getting shared files: $e');
      return [];
    }
  }

  /// Open a file with default app
  Future<void> openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }
      // For now, just return path - Flutter doesn't have built-in file open
      // Apps can integrate plugins like 'open_file' for this functionality
      print('File ready to open: $filePath');
    } catch (e) {
      print('Error opening file: $e');
      rethrow;
    }
  }
}
