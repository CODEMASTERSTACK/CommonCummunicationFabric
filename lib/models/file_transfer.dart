class FileTransfer {
  final String fileId;
  final String fileName;
  final int totalSize;
  final int chunkSize;
  final int totalChunks;
  final String senderDeviceId;
  final String senderDeviceName;
  final String mimeType;

  int chunksReceived = 0;
  final Map<int, List<int>> chunks = {}; // chunkIndex -> data

  FileTransfer({
    required this.fileId,
    required this.fileName,
    required this.totalSize,
    required this.chunkSize,
    required this.totalChunks,
    required this.senderDeviceId,
    required this.senderDeviceName,
    required this.mimeType,
  });

  double get progress => totalChunks == 0 ? 0 : chunksReceived / totalChunks;

  bool get isComplete => chunksReceived == totalChunks;

  // Reassemble chunks into complete file
  List<int> reassemble() {
    final result = <int>[];
    for (int i = 0; i < totalChunks; i++) {
      if (chunks.containsKey(i)) {
        result.addAll(chunks[i]!);
      }
    }
    return result;
  }
}
