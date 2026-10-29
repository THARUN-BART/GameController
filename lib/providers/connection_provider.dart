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

  void applyQrPayload(QrPayload payload) {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      host: payload.host,
      port: payload.port,
      serverName: payload.serverName,
      pairingToken: payload.token,
      lastPayload: payload,
      errorMessage: null,
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
    );
  }

  void updateLatency(int ms) {
    state = state.copyWith(latencyMs: ms);
  }

  void disconnect() {
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      errorMessage: null,
    );
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionInfo>(ConnectionNotifier.new);
