import 'package:flutter/foundation.dart';

enum ConnectionStatus {
  disconnected,
  scanning,
  connecting,
  pairing,
  connected,
  reconnecting,
  failed,
}

@immutable
class ConnectionInfo {
  final ConnectionStatus status;
  final String? host;
  final int? port;
  final String? serverName;
  final int latencyMs;
  final String? errorMessage;

  const ConnectionInfo({
    this.status = ConnectionStatus.disconnected,
    this.host,
    this.port,
    this.serverName,
    this.latencyMs = 0,
    this.errorMessage,
  });

  bool get isConnected => status == ConnectionStatus.connected;

  String get displayStatus {
    switch (status) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.scanning:
        return 'Scanning QR...';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.pairing:
        return 'Authenticating...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting...';
      case ConnectionStatus.failed:
        return 'Connection Failed';
    }
  }

  ConnectionInfo copyWith({
    ConnectionStatus? status,
    String? host,
    int? port,
    String? serverName,
    int? latencyMs,
    String? errorMessage,
  }) {
    return ConnectionInfo(
      status: status ?? this.status,
      host: host ?? this.host,
      port: port ?? this.port,
      serverName: serverName ?? this.serverName,
      latencyMs: latencyMs ?? this.latencyMs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
