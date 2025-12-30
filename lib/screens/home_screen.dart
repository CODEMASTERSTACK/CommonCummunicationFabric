import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/room_service.dart';
import '../services/local_network_service.dart';
import '../services/recent_connections_service.dart';
import '../services/saved_messages_service.dart';
import 'settings_screen.dart';
import 'saved_content_screen.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  final RoomService roomService;
  final LocalNetworkService networkService;
  final RecentConnectionsService recentConnectionsService;
  final SavedMessagesService savedMessagesService;
  final ThemeProvider? themeProvider;

  const HomeScreen({
    Key? key,
    required this.roomService,
    required this.networkService,
    required this.recentConnectionsService,
    required this.savedMessagesService,
    this.themeProvider,
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
                await _navigateToChatScreen(code, remoteSocket: socket);
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
          await widget.recentConnectionsService.addTravel('Room $code');
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.of(
              context,
            ).pushNamed('/chat', arguments: {'roomCode': code});
          }
        }
      }
    } catch (e) {
      // ignore and show error below
    }

    if (mounted && !connected) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No room available with this room code';
      });
    }
  }

  Future<void> _navigateToChatScreen(
    String code, {
    Socket? remoteSocket,
  }) async {
    // Track as "travel" when joining a room
    await widget.recentConnectionsService.addTravel('Room $code');

    if (mounted) {
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {
          'roomCode': code,
          if (remoteSocket != null) 'remoteSocket': remoteSocket,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final timeGreeting = _timeGreeting();
    final deviceName = widget.roomService.currentDeviceName ?? 'Device';
    final greetingText = timeGreeting == 'Batman Mode'
        ? 'Batman Mode, $deviceName'
        : 'Good $timeGreeting, $deviceName';

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20.0,
              24.0,
              20.0,
              24.0 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Greeting + status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        greetingText,
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 32,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.shade600,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Online',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<String?>(
                            future: LocalNetworkService.getLocalIpAddress(),
                            builder: (context, snapshot) {
                              final ip =
                                  (snapshot.connectionState ==
                                      ConnectionState.done)
                                  ? (snapshot.data ?? '—')
                                  : '...';
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '($ip)',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey.shade500),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      Icons.settings,
                                      size: 18,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SettingsScreen(
                                            themeProvider: widget.themeProvider,
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: 'Settings',
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Action cards: Start a Room & Join Room & Saved Content
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 700;
                    return isNarrow
                        ? Column(
                            children: [
                              _buildStartCard(context, isDarkMode),
                              const SizedBox(height: 12),
                              _buildJoinCard(context, isDarkMode),
                              const SizedBox(height: 12),
                              _buildSavedContentCard(context, isDarkMode),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStartCard(context, isDarkMode),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildJoinCard(context, isDarkMode),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSavedContentCard(
                                      context,
                                      isDarkMode,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: SizedBox()),
                                ],
                              ),
                            ],
                          );
                  },
                ),

                const SizedBox(height: 20),

                // Recent Connections (bigger, with clear separation)
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade900
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: _buildRecentConnectionsSection(
                          context,
                          isDarkMode,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Know About The Working (moved below Recent Connections)
                Divider(
                  color: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'Know About The Working',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Understand how the message and file transfer system operates in this application.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDarkMode
                        ? Colors.grey.shade500
                        : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHowItWorksItem(
                      context,
                      icon: Icons.wifi,
                      title: 'Connect',
                      subtitle:
                          'Ensure all devices on the same Wi‑Fi or Ethernet network.',
                      isDarkMode: isDarkMode,
                    ),
                    _buildHowItWorksItem(
                      context,
                      icon: Icons.share,
                      title: 'Host or Join',
                      subtitle:
                          "One person creates room; other enter host's IP address.",
                      isDarkMode: isDarkMode,
                    ),
                    _buildHowItWorksItem(
                      context,
                      icon: Icons.chat_bubble_outline,
                      title: 'Chat',
                      subtitle:
                          'Enjoy zero‑latency messaging without using internet.',
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
                const SizedBox(height: 200),
                Center(
                  child: Text(
                    'Made for ease - by Krish',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 21) {
      return 'Batman Mode';
    } else if (hour >= 17) {
      return 'Evening';
    } else if (hour >= 12) {
      return 'Afternoon';
    } else {
      return 'Morning';
    }
  }

  Widget _buildStartCard(BuildContext context, bool isDarkMode) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : () => _createRoom(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.meeting_room,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start a Room',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Host a secure server on this machine',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinCard(BuildContext context, bool isDarkMode) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.login,
                  size: 26,
                  color: isDarkMode ? Colors.white : Colors.black54,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Join Room',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Enter the Room Code displayed on host screen',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.grey.shade600
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.grey.shade600
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.blue.shade500,
                          width: 2,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                    ),
                    enabled: !_isLoading,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _joinRoom(),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Join'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedContentCard(BuildContext context, bool isDarkMode) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SavedContentScreen(
              savedMessagesService: widget.savedMessagesService,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.bookmark,
                size: 20,
                color: Colors.amber.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved Content',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bookmarked messages & files',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 28,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
            ),
          ),
        ],
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
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final connection = connections[index];
              final isVisitor = connection.type == 'visit';
              final badgeColor = isVisitor ? Colors.green : Colors.orange;
              final badgeLabel = isVisitor ? 'VISIT' : 'TRAVEL';

              return Padding(
                padding: EdgeInsets.only(
                  right: index == connections.length - 1 ? 0 : 12.0,
                ),
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(12.0),
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
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
