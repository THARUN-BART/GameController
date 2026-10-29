import 'package:flutter/foundation.dart';
import 'qr_payload.dart';

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
  final String? pairingToken;
  final int latencyMs;
  final String? errorMessage;
  final QrPayload? lastPayload;

  const ConnectionInfo({
    this.status = ConnectionStatus.disconnected,
    this.host,
    this.port,
    this.serverName,
    this.pairingToken,
    this.latencyMs = 0,
    this.errorMessage,
    this.lastPayload,
  });

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting =>
      status == ConnectionStatus.connecting || status == ConnectionStatus.pairing;

  String get displayStatus {
    switch (status) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.scanning:
        return 'Scanning QR...';
      case ConnectionStatus.connecting:
        return 'Connecting to PC...';
      case ConnectionStatus.pairing:
        return 'Authenticating Token...';
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
    String? pairingToken,
    int? latencyMs,
    String? errorMessage,
    QrPayload? lastPayload,
  }) {
    return ConnectionInfo(
      status: status ?? this.status,
      host: host ?? this.host,
      port: port ?? this.port,
      serverName: serverName ?? this.serverName,
      pairingToken: pairingToken ?? this.pairingToken,
      latencyMs: latencyMs ?? this.latencyMs,
      errorMessage: errorMessage ?? this.errorMessage,
      lastPayload: lastPayload ?? this.lastPayload,
    );
  }
}
