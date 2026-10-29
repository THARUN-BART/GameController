import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_controller/models/qr_payload.dart';

void main() {
  group('QR Payload Format & Validation Tests', () {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final validPayloadMap = {
      'v': 1,
      'app': 'lan_gamepad',
      'host': '192.168.1.150',
      'port': 8080,
      'token': 'a1b2c3d4e5f6',
      'exp': nowSeconds + 300,
      'name': 'GAMING-DESKTOP',
      'proto': 'ws',
    };

    test('Parses valid QR payload successfully', () {
      final jsonStr = jsonEncode(validPayloadMap);
      final result = QrPayload.tryParse(jsonStr);

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.payload, isNotNull);

      final payload = result.payload!;
      expect(payload.version, equals(1));
      expect(payload.app, equals('lan_gamepad'));
      expect(payload.host, equals('192.168.1.150'));
      expect(payload.port, equals(8080));
      expect(payload.token, equals('a1b2c3d4e5f6'));
      expect(payload.serverName, equals('GAMING-DESKTOP'));
      expect(payload.isExpired, isFalse);
      expect(payload.webSocketUrl, equals('ws://192.168.1.150:8080'));
    });

    test('Rejects non-JSON string', () {
      final result = QrPayload.tryParse('https://google.com/test');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('JSON'));
    });

    test('Rejects unrecognized app identifier', () {
      final badApp = Map<String, dynamic>.from(validPayloadMap)..['app'] = 'other_app';
      final result = QrPayload.tryParse(jsonEncode(badApp));

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Not a LAN Gamepad QR code'));
    });

    test('Rejects incompatible version', () {
      final badVersion = Map<String, dynamic>.from(validPayloadMap)..['v'] = 99;
      final result = QrPayload.tryParse(jsonEncode(badVersion));

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Unsupported QR version'));
    });

    test('Rejects invalid IP addresses', () {
      final invalidHosts = ['999.1.1.1', '192.168.1', 'abc.def.ghi.jkl', ''];
      for (final badHost in invalidHosts) {
        final map = Map<String, dynamic>.from(validPayloadMap)..['host'] = badHost;
        final result = QrPayload.tryParse(jsonEncode(map));
        expect(result.isValid, isFalse, reason: 'Host $badHost should fail validation');
      }
    });

    test('Rejects out-of-range ports', () {
      final invalidPorts = [80, 500, 70000, -1];
      for (final badPort in invalidPorts) {
        final map = Map<String, dynamic>.from(validPayloadMap)..['port'] = badPort;
        final result = QrPayload.tryParse(jsonEncode(map));
        expect(result.isValid, isFalse, reason: 'Port $badPort should fail validation');
      }
    });

    test('Rejects expired pairing token', () {
      // Expired 60 seconds ago
      final expired = Map<String, dynamic>.from(validPayloadMap)
        ..['exp'] = nowSeconds - 60;
      final result = QrPayload.tryParse(jsonEncode(expired));

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('expired'));
    });

    test('Round-trip serialization to JSON string', () {
      final payload = QrPayload.fromJson(validPayloadMap);
      final jsonStr = payload.toRawString();

      final parsedResult = QrPayload.tryParse(jsonStr);
      expect(parsedResult.isValid, isTrue);
      expect(parsedResult.payload, equals(payload));
    });
  });
}
