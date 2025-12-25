import 'dart:async';
import 'package:flutter/material.dart';
import '../services/room_service.dart';
import '../services/local_network_service.dart';

class HomeScreen extends StatefulWidget {
  final RoomService roomService;
  final LocalNetworkService networkService;

  const HomeScreen({Key? key, required this.roomService, required this.networkService}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _announceSub;

  @override
  void dispose() {
    _codeController.dispose();
    _announceSub?.cancel();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = widget.roomService.createRoom();

      // Start server and advertise room
      await widget.networkService.startServer(widget.roomService.currentDeviceName);
      await widget.networkService.advertiseRoom(room.code);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushNamed('/chat', arguments: {'roomCode': room.code});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to create room: $e';
        });
      }
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a room code');
      return;
    }

    if (code.length != 6 || !RegExp(r'^\d{6}').hasMatch(code)) {
      setState(() => _errorMessage = 'Room code must be 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool connected = false;
    try {
      await widget.networkService.listenForAnnouncements(onAnnouncement: (room, host, port) async {
        if (room == code && !connected) {
          final socket = await widget.networkService.connectToServer(
            host,
            widget.roomService.currentDeviceId,
            widget.roomService.currentDeviceName,
            port: port,
            roomCode: code,
          );
          if (socket != null) {
            connected = true;
            await widget.networkService.stopListening();
            if (mounted) {
              setState(() => _isLoading = false);
              Navigator.of(context).pushNamed('/chat', arguments: {'roomCode': code});
            }
          }
        }
      });

      // Wait up to 5 seconds for discovery
      await Future.delayed(const Duration(seconds: 5));
      if (!connected) {
        await widget.networkService.stopListening();
        // Fallback: attempt local join (if roomService has it locally)
        final success = widget.roomService.joinRoom(
          code,
          deviceName: widget.roomService.currentDeviceName,
        );
        if (success) connected = true;
      }
    } catch (e) {
      // ignore and show error below
    }

    if (mounted && !connected) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Room code not found or expired';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Common Communication'), elevation: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Header
              Icon(Icons.groups, size: 80, color: Colors.blue.shade300),
              const SizedBox(height: 24),
              Text(
                'Connect Devices',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a room or join using 6-digit code',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Device Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Current Device',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.roomService.currentDeviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ID: ${widget.roomService.currentDeviceId.substring(0, 8)}...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Create Room Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _createRoom(),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create New Room'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'OR',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // Join Room Section
              Text(
                'Join Existing Room',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: const TextStyle(letterSpacing: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _joinRoom(),
                icon: const Icon(Icons.login),
                label: const Text('Join Room'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),

              // Loading Indicator
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
