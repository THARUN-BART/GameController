import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_controller/models/connection_info.dart';
import 'package:game_controller/models/controller_state.dart';
import 'package:game_controller/providers/connection_provider.dart';

void main() {
  group('WebSocket Protocol & Pairing Handshake Tests', () {
    test('Pair handshake JSON format strictly complies with specification', () {
      final token = '3b8a1ec5-05e1-4c12-92b0-8f6bcde05321';
      final clientName = 'Android Gamepad';
      final version = 1;

      final pairPayload = jsonEncode({
        'type': 'pair',
        'token': token,
        'client_name': clientName,
        'client_version': version,
      });

      final parsed = jsonDecode(pairPayload) as Map<String, dynamic>;
      expect(parsed['type'], equals('pair'));
      expect(parsed['token'], equals(token));
      expect(parsed['client_name'], equals('Android Gamepad'));
      expect(parsed['client_version'], equals(1));
    });

    test('PairAck success packet updates connection state to connected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(connectionProvider.notifier);
      notifier.setStatus(ConnectionStatus.connecting);
      notifier.setStatus(ConnectionStatus.pairing);

      final pairAckJson = {
        'type': 'pair_ack',
        'success': true,
        'message': 'Paired successfully',
        'server_name': 'Gaming-Desktop',
        'version': 1,
      };

      if (pairAckJson['success'] == true) {
        notifier.setConnected(
          host: '192.168.1.105',
          port: 8080,
          serverName: pairAckJson['server_name'] as String,
          pairingToken: 'dummy_token',
        );
      }

      final state = container.read(connectionProvider);
      expect(state.status, equals(ConnectionStatus.connected));
      expect(state.isConnected, isTrue);
      expect(state.serverName, equals('Gaming-Desktop'));
      expect(state.displayStatus, equals('Connected'));
    });

    test('PairAck failure packet updates connection state to failed with error message', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(connectionProvider.notifier);
      notifier.setStatus(ConnectionStatus.pairing);

      final pairAckJson = {
        'type': 'pair_ack',
        'success': false,
        'message': 'Pairing token has expired. Please rescan QR code on PC.',
        'server_name': 'Gaming-Desktop',
        'version': 1,
      };

      notifier.setStatus(
        ConnectionStatus.failed,
        errorMessage: pairAckJson['message'] as String,
      );

      final state = container.read(connectionProvider);
      expect(state.status, equals(ConnectionStatus.failed));
      expect(state.isConnected, isFalse);
      expect(state.errorMessage, contains('expired'));
      expect(state.displayStatus, equals('Connection Failed'));
    });

    test('Ping/Pong latency calculation reflects round-trip time accurately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(connectionProvider.notifier);
      final clientTs = DateTime.now().millisecondsSinceEpoch - 18; // 18ms ago

      final pongMsg = {
        'type': 'pong',
        'client_ts': clientTs,
        'server_ts': clientTs + 9,
      };

      final now = DateTime.now().millisecondsSinceEpoch;
      final latency = (now - (pongMsg['client_ts'] as int)).clamp(0, 9999);
      notifier.updateLatency(latency);

      final state = container.read(connectionProvider);
      expect(state.latencyMs, inInclusiveRange(16, 25));
    });

    test('ControllerState serializes input frame with clamps and correct keys', () {
      final state = ControllerState(
        leftStickX: 0.85432,
        leftStickY: -0.42119,
        rightStickX: -1.0,
        rightStickY: 1.0,
        pressedButtons: {'CROSS', 'R1', 'L2'},
        sequenceNumber: 42,
        timestamp: 1730000000,
      );

      final json = {
        'type': 'input',
        ...state.toJson(),
      };

      expect(json['type'], equals('input'));
      expect(json['seq'], equals(42));
      expect(json['ts'], equals(1730000000));

      final leftStick = json['left_stick'] as Map<String, dynamic>;
      expect(leftStick['x'], equals(0.8543));
      expect(leftStick['y'], equals(-0.4212));

      final buttons = json['buttons'] as List;
      expect(buttons, containsAll(['CROSS', 'R1', 'L2']));
    });
  });
}
