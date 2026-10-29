import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_info.dart';

class ConnectionNotifier extends Notifier<ConnectionInfo> {
  @override
  ConnectionInfo build() {
    return const ConnectionInfo(status: ConnectionStatus.disconnected);
  }

  void setStatus(ConnectionStatus status, {String? errorMessage}) {
    state = state.copyWith(status: status, errorMessage: errorMessage);
  }

  void setConnected({
    required String host,
    required int port,
    String? serverName,
  }) {
    state = state.copyWith(
      status: ConnectionStatus.connected,
      host: host,
      port: port,
      serverName: serverName ?? 'Windows Gamepad Receiver',
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

  void simulateConnect() {
    state = state.copyWith(
      status: ConnectionStatus.connected,
      host: '192.168.1.100',
      port: 8080,
      serverName: 'Gaming-PC (Simulated)',
      latencyMs: 14,
    );
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionInfo>(ConnectionNotifier.new);
