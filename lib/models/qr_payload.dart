import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Validation outcome for a scanned QR payload.
class QrValidationResult {
  final bool isValid;
  final QrPayload? payload;
  final String? errorMessage;

  const QrValidationResult.success(this.payload)
      : isValid = true,
        errorMessage = null;

  const QrValidationResult.failure(this.errorMessage)
      : isValid = false,
        payload = null;
}

/// Versioned QR code payload containing all network and pairing parameters.
@immutable
class QrPayload {
  /// Current payload format version
  static const int currentVersion = 1;
  static const String appIdentifier = 'lan_gamepad';

  final int version;
  final String app;
  final String host;
  final int port;
  final String token;
  final int expiresAt; // Unix timestamp in seconds
  final String serverName;
  final String protocol; // 'ws'

  const QrPayload({
    required this.version,
    required this.app,
    required this.host,
    required this.port,
    required this.token,
    required this.expiresAt,
    required this.serverName,
    this.protocol = 'ws',
  });

  /// True if the token has expired relative to device clock (with 15s grace margin)
  bool get isExpired {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Allow 15-second grace period for clock skew between PC and phone
    return nowSeconds > (expiresAt + 15);
  }

  /// Remaining seconds until token expiration
  int get remainingSeconds {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = expiresAt - nowSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Full WebSocket URL to connect to
  String get webSocketUrl => '$protocol://$host:$port';

  Map<String, dynamic> toJson() {
    return {
      'v': version,
      'app': app,
      'host': host,
      'port': port,
      'token': token,
      'exp': expiresAt,
      'name': serverName,
      'proto': protocol,
    };
  }

  String toRawString() => jsonEncode(toJson());

  factory QrPayload.fromJson(Map<String, dynamic> json) {
    return QrPayload(
      version: json['v'] as int? ?? 0,
      app: json['app'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 0,
      token: json['token'] as String? ?? '',
      expiresAt: json['exp'] as int? ?? 0,
      serverName: json['name'] as String? ?? 'PC Receiver',
      protocol: json['proto'] as String? ?? 'ws',
    );
  }

  /// Validates and parses raw scanned QR string content.
  static QrValidationResult tryParse(String raw) {
    if (raw.trim().isEmpty) {
      return const QrValidationResult.failure('QR code content is empty.');
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map<String, dynamic>) {
        return const QrValidationResult.failure('QR content is not a valid JSON object.');
      }
      json = decoded;
    } catch (_) {
      return const QrValidationResult.failure('QR code is not in JSON format.');
    }

    // 1. Verify app identifier
    final app = json['app'];
    if (app != appIdentifier) {
      return const QrValidationResult.failure(
        'Not a LAN Gamepad QR code (unrecognized app identifier).',
      );
    }

    // 2. Verify version
    final version = json['v'];
    if (version == null || version is! int) {
      return const QrValidationResult.failure('Missing or invalid protocol version.');
    }
    if (version != currentVersion) {
      return QrValidationResult.failure(
        'Unsupported QR version ($version). Please update both app and PC receiver.',
      );
    }

    // 3. Verify host
    final host = json['host'];
    if (host == null || host is! String || host.trim().isEmpty) {
      return const QrValidationResult.failure('Missing receiver IP address.');
    }
    if (!_isValidHost(host.trim())) {
      return QrValidationResult.failure('Invalid LAN IP address format: $host');
    }

    // 4. Verify port
    final port = json['port'];
    if (port == null || port is! int || port < 1024 || port > 65535) {
      return const QrValidationResult.failure(
        'Invalid port number (must be between 1024 and 65535).',
      );
    }

    // 5. Verify pairing token
    final token = json['token'];
    if (token == null || token is! String || token.trim().length < 8) {
      return const QrValidationResult.failure('Invalid or missing security pairing token.');
    }

    // 6. Verify expiration timestamp
    final exp = json['exp'];
    if (exp == null || exp is! int || exp <= 0) {
      return const QrValidationResult.failure('Missing token expiration timestamp.');
    }

    final payload = QrPayload.fromJson(json);

    // 7. Check expiration
    if (payload.isExpired) {
      return const QrValidationResult.failure(
        'Pairing QR code has expired. Please refresh the QR code on your PC.',
      );
    }

    return QrValidationResult.success(payload);
  }

  static bool _isValidHost(String host) {
    if (host == 'localhost') return true;

    // IPv4 pattern: 4 octets 0-255
    final parts = host.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
      if (part.length > 1 && part.startsWith('0')) return false; // No leading zeroes
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrPayload &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          host == other.host &&
          port == other.port &&
          token == other.token &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode =>
      version.hashCode ^
      host.hashCode ^
      port.hashCode ^
      token.hashCode ^
      expiresAt.hashCode;
}
