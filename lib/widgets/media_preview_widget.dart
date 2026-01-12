import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as video_player;
import 'package:just_audio/just_audio.dart';
import '../services/file_service.dart';

/// Widget to display image preview
class ImagePreviewWidget extends StatelessWidget {
  final String filePath;
  final String fileName;
  final VoidCallback? onTap;

  const ImagePreviewWidget({
    Key? key,
    required this.filePath,
    required this.fileName,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: 300,
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade800,
          ),
          child: _buildImageContent(),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return _buildErrorWidget('File not found');
      }

      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Image load error: $error');
          return _buildErrorWidget('Unable to load image');
        },
      );
    } catch (e) {
      print('Image widget error: $e');
      return _buildErrorWidget('Error loading image');
    }
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      color: Colors.grey.shade800,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.grey.shade400, size: 40),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display video preview with player
class VideoPreviewWidget extends StatefulWidget {
  final String filePath;
  final String fileName;
  final bool isCurrentUser;

  const VideoPreviewWidget({
    Key? key,
    required this.filePath,
    required this.fileName,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  late video_player.VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'File not found at: ${widget.filePath}';
          });
        }
        return;
      }

      try {
        _videoController = video_player.VideoPlayerController.file(file);
        
        // Initialize with better error handling
        await _videoController.initialize();
        
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      } on UnsupportedError catch (e) {
        print('Video format not supported: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Video format not supported on this platform';
          });
        }
      } on Exception catch (e) {
        print('Video initialization error: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Cannot initialize video player: ${e.toString()}';
          });
        }
      }
    } catch (e) {
      print('Error preparing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading video: $e';
        });
      }
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
        _isPlaying = false;
      } else {
        _videoController.play();
        _isPlaying = true;
      }
    });
  }

  @override
  void dispose() {
    try {
      _videoController.dispose();
    } catch (e) {
      print('Error disposing video controller: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade800,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 40),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade800,
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: widget.isCurrentUser ? Colors.white : Colors.blue.shade300,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 300,
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _videoController.value.aspectRatio,
              child: video_player.VideoPlayer(_videoController),
            ),
            // Play/Pause overlay
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            // Duration text at bottom
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(_videoController.value.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}

/// Widget to display audio player
class AudioPreviewWidget extends StatefulWidget {
  final String filePath;
  final String fileName;
  final bool isCurrentUser;

  const AudioPreviewWidget({
    Key? key,
    required this.filePath,
    required this.fileName,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  State<AudioPreviewWidget> createState() => _AudioPreviewWidgetState();
}

class _AudioPreviewWidgetState extends State<AudioPreviewWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) {
        setState(() {
          _hasError = true;
          _errorMessage = 'File not found';
        });
        return;
      }

      await _audioPlayer.setFilePath(widget.filePath);

      _audioPlayer.durationStream.listen((d) {
        if (mounted) {
          setState(() => _duration = d ?? Duration.zero);
        }
      });

      _audioPlayer.positionStream.listen((p) {
        if (mounted) {
          setState(() => _position = p);
        }
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });
    } catch (e) {
      print('Audio initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Cannot play this audio format';
        });
      }
    }
  }

  void _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      print('Playback error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Playback error';
      });
    }
  }

  void _seekTo(Duration duration) async {
    try {
      await _audioPlayer.seek(duration);
    } catch (e) {
      print('Seek error: $e');
    }
  }

  @override
  void dispose() {
    try {
      _audioPlayer.dispose();
    } catch (e) {
      print('Error disposing audio player: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade800,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade800,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File name
          Row(
            children: [
              Icon(
                Icons.audio_file,
                color: widget.isCurrentUser ? Colors.white : Colors.blue.shade300,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isCurrentUser ? Colors.white : Colors.blue.shade100,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Play/Pause button and duration
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade500,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress slider
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blue.shade400,
                        inactiveTrackColor: Colors.grey.shade600,
                        thumbColor: Colors.blue.shade300,
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: Slider(
                        value: _position.inMilliseconds.toDouble(),
                        max: _duration.inMilliseconds.toDouble() > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1,
                        onChanged: (value) {
                          _seekTo(Duration(milliseconds: value.toInt()));
                        },
                      ),
                    ),
                    // Time display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                            ),
                          ),
                        ],
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}

/// Widget for fullscreen image viewer
class FullscreenImageViewer extends StatelessWidget {
  final String filePath;
  final String fileName;

  const FullscreenImageViewer({
    Key? key,
    required this.filePath,
    required this.fileName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    final fileExists = file.existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(fileName),
      ),
      body: Center(
        child: !fileExists
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported,
                      color: Colors.red.shade400, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Image file not found',
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filePath,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : InteractiveViewer(
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image,
                              color: Colors.red.shade400, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load image',
                            style: TextStyle(color: Colors.red.shade400),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error: $error',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// Helper function to check media type
bool isImageFile(String? mimeType) {
  return mimeType?.startsWith('image/') ?? false;
}

bool isVideoFile(String? mimeType) {
  if (mimeType == null) return false;
  return mimeType.startsWith('video/') ||
      mimeType.contains('mp4') ||
      mimeType.contains('quicktime') ||
      mimeType.contains('x-msvideo');
}

bool isAudioFile(String? mimeType) {
  if (mimeType == null) return false;
  return mimeType.startsWith('audio/') ||
      mimeType.contains('mp3') ||
      mimeType.contains('wav') ||
      mimeType.contains('aac') ||
      mimeType.contains('ogg');
}
