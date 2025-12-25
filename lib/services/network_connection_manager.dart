import 'dart:async';
import 'dart:io';

/// Connection states for network connectivity
enum ConnectionState { disconnected, connecting, connected, failed }

/// Enhanced networking service with state management and better error handling
class NetworkConnectionManager {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  late Stream<ConnectionState> connectionStateStream;
  late StreamController<ConnectionState> _connectionStateController;

  ConnectionState _currentState = ConnectionState.disconnected;
  Socket? _socket;
  Timer? _heartbeatTimer;
  int _retryCount = 0;

  NetworkConnectionManager() {
    _connectionStateController = StreamController<ConnectionState>.broadcast();
    connectionStateStream = _connectionStateController.stream;
  }

  ConnectionState get currentState => _currentState;

  /// Connect to a remote server
  Future<Socket?> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      _updateState(ConnectionState.connecting);

      _socket = await Socket.connect(host, port).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      _retryCount = 0;
      _updateState(ConnectionState.connected);
      _startHeartbeat();

      return _socket;
    } catch (e) {
      await _handleConnectionError(e);
      return null;
    }
  }

  /// Reconnect with exponential backoff
  Future<Socket?> connectWithRetry(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    while (_retryCount < maxRetries) {
      try {
        final socket = await connect(host, port, timeout: timeout);
        if (socket != null) {
          return socket;
        }
      } catch (e) {
        _retryCount++;
        if (_retryCount < maxRetries) {
          await Future.delayed(
            retryDelay * (_retryCount), // Exponential backoff
          );
        }
      }
    }

    _updateState(ConnectionState.failed);
    return null;
  }

  /// Handle connection errors
  Future<void> _handleConnectionError(dynamic error) async {
    print('Connection error: $error');
    _updateState(ConnectionState.failed);
    await disconnect();
  }

  /// Start heartbeat to detect disconnections
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_socket == null || !_isConnected()) {
        timer.cancel();
        _updateState(ConnectionState.disconnected);
      }
    });
  }

  /// Check if socket is still connected
  bool _isConnected() {
    return _socket != null;
  }

  /// Update connection state
  void _updateState(ConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(newState);
      print('Connection state: $newState');
    }
  }

  /// Send data
  bool send(String data) {
    if (_socket == null) {
      return false;
    }

    try {
      _socket!.write('$data\n');
      return true;
    } catch (e) {
      print('Error sending data: $e');
      return false;
    }
  }

  /// Listen to incoming data
  void listen(
    Function(String) onData,
    Function(dynamic)? onError,
    Function()? onDone,
  ) {
    if (_socket == null) return;

    _socket!.listen(
      (data) {
        String message = String.fromCharCodes(data).trim();
        if (message.isNotEmpty) {
          onData(message);
        }
      },
      onError: onError,
      onDone: onDone,
    );
  }

  /// Disconnect
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
    _updateState(ConnectionState.disconnected);
  }

  /// Cleanup
  void dispose() {
    _heartbeatTimer?.cancel();
    _connectionStateController.close();
  }
}
