import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/room_service.dart';
import '../services/local_network_service.dart';
import '../services/recent_connections_service.dart';

class HomeScreen extends StatefulWidget {
  final RoomService roomService;
  final LocalNetworkService networkService;
  final RecentConnectionsService recentConnectionsService;

  const HomeScreen({
    Key? key,
    required this.roomService,
    required this.networkService,
    required this.recentConnectionsService,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _announceSub;
  Socket? _connectedSocket; // Store connection to remote server

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
      await widget.networkService.startServer(
        widget.roomService.currentDeviceName,
      );
      await widget.networkService.advertiseRoom(room.code);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(
          context,
        ).pushNamed('/chat', arguments: {'roomCode': room.code});
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

    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _errorMessage = 'Room code must be 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool connected = false;
    try {
      await widget.networkService.listenForAnnouncements(
        onAnnouncement: (room, host, port) async {
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
              _connectedSocket = socket; // Store socket for ChatScreen
              // Create a local room instance so ChatScreen can read from RoomService
              widget.roomService.joinRemoteRoom(
                code,
                deviceName: widget.roomService.currentDeviceName,
              );
              await widget.networkService.stopListening();
              if (mounted) {
                setState(() => _isLoading = false);
                _navigateToChatScreen(code, remoteSocket: socket);
              }
            }
          }
        },
      );

      // Wait up to 5 seconds for discovery
      await Future.delayed(const Duration(seconds: 5));
      if (!connected) {
        await widget.networkService.stopListening();
        // Only attempt local join if network discovery failed
        final success = widget.roomService.joinRoom(
          code,
          deviceName: widget.roomService.currentDeviceName,
        );
        if (success && mounted) {
          connected = true;
          // Track this as a "travel" connection
          widget.recentConnectionsService.addTravel('Room $code');
          setState(() => _isLoading = false);
          Navigator.of(
            context,
          ).pushNamed('/chat', arguments: {'roomCode': code});
        }
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

  void _navigateToChatScreen(String code, {Socket? remoteSocket}) {
    // Track as "travel" when joining a room
    widget.recentConnectionsService.addTravel('Room $code');
    
    Navigator.of(context).pushNamed(
      '/chat',
      arguments: {
        'roomCode': code,
        if (remoteSocket != null) 'remoteSocket': remoteSocket,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Connect'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Section
              Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.share_arrival_time,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Seamless Connection',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Share and communicate across devices on your network',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 56),

              // Device Info Card (Minimal)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.devices,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.roomService.currentDeviceName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your device',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDarkMode
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Create Room Section
              _buildActionSection(
                context,
                icon: Icons.add_circle_outline,
                title: 'Create New Room',
                subtitle: 'Start hosting and share the code',
                onPressed: _isLoading ? null : () => _createRoom(),
                isPrimary: true,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 24),

              // Divider with OR
              Row(
                children: [
                  const Expanded(child: Divider(height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'OR',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(height: 1)),
                ],
              ),
              const SizedBox(height: 24),

              // Join Room Section
              _buildActionSection(
                context,
                icon: Icons.login,
                title: 'Join Existing Room',
                subtitle: 'Enter the 6-digit code',
                onPressed: _isLoading ? null : () => _joinRoom(),
                isPrimary: false,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 16),

              // Join Room Input
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(
                    letterSpacing: 4,
                    color: isDarkMode
                        ? Colors.grey.shade600
                        : Colors.grey.shade300,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue.shade500,
                      width: 2,
                    ),
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  filled: true,
                  fillColor: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade50,
                ),
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // Join Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _joinRoom(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade500,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Join Room',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Error Message
              if (_errorMessage != null)
                _buildErrorMessage(_errorMessage!, isDarkMode),

              // Loading Indicator
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkMode
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),

              // Recent Connections Section
              _buildRecentConnectionsSection(context, isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onPressed,
    required bool isPrimary,
    required bool isDarkMode,
  }) {
    final primaryColor = isPrimary ? Colors.blue : Colors.green;

    return SizedBox(
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkMode
                              ? Colors.grey.shade500
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDarkMode
                      ? Colors.grey.shade600
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentConnectionsSection(BuildContext context, bool isDarkMode) {
    final connections = widget.recentConnectionsService.getConnections();

    if (connections.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Connections',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Text(
                'No recent connections yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDarkMode
                      ? Colors.grey.shade500
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Connections',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final connection = connections[index];
              final isVisitor = connection.type == 'visit';
              final badgeColor = isVisitor ? Colors.green : Colors.orange;
              final badgeLabel = isVisitor ? 'VISIT' : 'TRAVEL';

              return Padding(
                padding: EdgeInsets.only(right: index == connections.length - 1 ? 0 : 12.0),
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connection.deviceName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
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
    );
  }
}
