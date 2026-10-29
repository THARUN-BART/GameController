import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/connection_info.dart';
import '../models/controller_state.dart';
import '../providers/connection_provider.dart';

/// Service responsible for the low-latency WebSocket link, token authentication handshake,
/// heartbeat ping/pong latency measurement, and controller input streaming.
class WebSocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;

  bool _isDisposed = false;
  Completer<bool>? _handshakeCompleter;

  WebSocketService(this._ref);

  bool get isConnected =>
      _ref.read(connectionProvider).status == ConnectionStatus.connected;

  /// Connects to the receiver at [host]:[port], executes token authentication handshake,
  /// and establishes the heartbeat monitor. Returns true if pairing succeeds.
  Future<bool> connect({
    required String host,
    required int port,
    required String token,
    String clientName = 'Android Gamepad',
  }) async {
    // Clean up any existing connection
    await disconnect(reason: 'reconnecting');

    final notifier = _ref.read(connectionProvider.notifier);
    notifier.setStatus(ConnectionStatus.connecting);

    final wsUri = Uri.parse('ws://$host:$port');
    _handshakeCompleter = Completer<bool>();

    try {
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;

      // Transition to pairing / authenticating state
      notifier.setStatus(ConnectionStatus.pairing);

      // Listen for server messages (PairAck, Pong, Error)
      _subscription = _channel!.stream.listen(
        (data) => _handleIncomingMessage(data, host, port, token),
        onError: (err) {
          debugPrint('[WebSocket] Error: $err');
          _onConnectionLost(errorMessage: 'Connection error: $err');
        },
        onDone: () {
          debugPrint('[WebSocket] Stream closed by remote peer.');
          _onConnectionLost();
        },
        cancelOnError: true,
      );

      // Send authenticated Pair handshake packet
      final pairPayload = jsonEncode({
        'type': 'pair',
        'token': token,
        'client_name': clientName,
        'client_version': 1,
      });

      _channel!.sink.add(pairPayload);

      // Wait for server PairAck with an 8-second timeout
      final success = await _handshakeCompleter!.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          notifier.setStatus(
            ConnectionStatus.failed,
            errorMessage: 'Pairing handshake timed out. Check PC receiver.',
          );
          disconnect(reason: 'timeout');
          return false;
        },
      );

      return success;
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e');
      notifier.setStatus(
        ConnectionStatus.failed,
        errorMessage: 'Could not connect to $host:$port ($e)',
      );
      await disconnect(reason: 'connect_error');
      return false;
    }
  }

  void _handleIncomingMessage(
    dynamic data,
    String host,
    int port,
    String token,
  ) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'pair_ack':
          final success = json['success'] as bool? ?? false;
          final serverName = json['server_name'] as String? ?? 'Windows PC';
          final message = json['message'] as String? ?? '';

          if (success) {
            _ref.read(connectionProvider.notifier).setConnected(
                  host: host,
                  port: port,
                  serverName: serverName,
                  pairingToken: token,
                );
            _startHeartbeat();
            if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
              _handshakeCompleter!.complete(true);
            }
          } else {
            _ref.read(connectionProvider.notifier).setStatus(
                  ConnectionStatus.failed,
                  errorMessage: message.isNotEmpty ? message : 'Pairing token rejected.',
                );
            if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
              _handshakeCompleter!.complete(false);
            }
            disconnect(reason: 'pair_rejected');
          }
          break;

        case 'pong':
          final clientTs = json['client_ts'] as int? ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          final latency = (now - clientTs).clamp(0, 9999);
          _ref.read(connectionProvider.notifier).updateLatency(latency);
          break;

        case 'error':
          final errMsg = json['message'] as String? ?? 'Server error';
          _ref.read(connectionProvider.notifier).setStatus(
                ConnectionStatus.failed,
                errorMessage: errMsg,
              );
          break;
      }
    } catch (e) {
      debugPrint('[WebSocket] Failed to parse message: $e');
    }
  }

  /// Sends a periodic heartbeat ping to measure round-trip latency.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      sendPing();
    });
    // Send immediate ping upon connection
    sendPing();
  }

  /// Transmits a lightweight ping frame with client epoch timestamp.
  void sendPing() {
    if (_channel != null && isConnected) {
      try {
        final pingMsg = jsonEncode({
          'type': 'ping',
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
        _channel!.sink.add(pingMsg);
      } catch (e) {
        debugPrint('[WebSocket] Error sending ping: $e');
      }
    }
  }

  /// Sends controller input frame (twin sticks and button states) to the receiver.
  void sendInput(ControllerState state) {
    if (_channel != null && isConnected) {
      try {
        final payload = jsonEncode({
          'type': 'input',
          ...state.toJson(),
        });
        _channel!.sink.add(payload);
      } catch (e) {
        debugPrint('[WebSocket] Error sending input: $e');
      }
    }
  }

  void _onConnectionLost({String? errorMessage}) {
    _heartbeatTimer?.cancel();
    if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
      _handshakeCompleter!.complete(false);
    }

    final currentStatus = _ref.read(connectionProvider).status;
    if (currentStatus == ConnectionStatus.connected ||
        currentStatus == ConnectionStatus.pairing ||
        currentStatus == ConnectionStatus.connecting) {
      _ref.read(connectionProvider.notifier).setStatus(
            errorMessage != null ? ConnectionStatus.failed : ConnectionStatus.disconnected,
            errorMessage: errorMessage,
          );
    }
  }

  /// Gracefully terminates the WebSocket session.
  Future<void> disconnect({String reason = 'user_exit'}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_channel != null) {
      try {
        final discMsg = jsonEncode({
          'type': 'disconnect',
          'reason': reason,
        });
        _channel!.sink.add(discMsg);
      } catch (_) {}

      await _subscription?.cancel();
      _subscription = null;
      await _channel?.sink.close();
      _channel = null;
    }

    if (!_isDisposed) {
      final current = _ref.read(connectionProvider).status;
      if (current != ConnectionStatus.failed) {
        _ref.read(connectionProvider.notifier).disconnect();
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    disconnect(reason: 'service_disposed');
  }
}

/// Riverpod provider for the singleton WebSocket connection service.
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
