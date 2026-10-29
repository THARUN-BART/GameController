import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_info.dart';
import '../models/qr_payload.dart';

class ConnectionNotifier extends Notifier<ConnectionInfo> {
  @override
  ConnectionInfo build() {
    return const ConnectionInfo(status: ConnectionStatus.disconnected);
  }

  void setStatus(ConnectionStatus status, {String? errorMessage}) {
    state = state.copyWith(status: status, errorMessage: errorMessage);
  }

  void setReconnecting(int attempt, int maxAttempts) {
    state = state.copyWith(
      status: ConnectionStatus.reconnecting,
      reconnectAttempt: attempt,
      maxReconnectAttempts: maxAttempts,
      errorMessage: null,
    );
  }

  void applyQrPayload(QrPayload payload) {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      host: payload.host,
      port: payload.port,
      serverName: payload.serverName,
      pairingToken: payload.token,
      lastPayload: payload,
      errorMessage: null,
      reconnectAttempt: 0,
    );
  }

  void setConnected({
    required String host,
    required int port,
    String? serverName,
    String? pairingToken,
  }) {
    state = state.copyWith(
      status: ConnectionStatus.connected,
      host: host,
      port: port,
      serverName: serverName ?? 'Windows Gamepad Receiver',
      pairingToken: pairingToken,
      errorMessage: null,
      reconnectAttempt: 0,
    );
  }

  void updateLatency(int ms) {
    // Smooth latency jitter via exponential moving average (EMA alpha = 0.3)
    final smoothed = state.latencyMs == 0
        ? ms
        : ((0.3 * ms) + (0.7 * state.latencyMs)).round();
    state = state.copyWith(latencyMs: smoothed);
  }

  void disconnect() {
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      errorMessage: null,
      reconnectAttempt: 0,
    );
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionInfo>(ConnectionNotifier.new);
