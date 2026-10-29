import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/controller_state.dart';
import '../services/websocket_service.dart';

class ControllerNotifier extends Notifier<ControllerState> {
  int _sequenceNumber = 0;

  @override
  ControllerState build() {
    return ControllerState.neutral;
  }

  void _broadcast() {
    try {
      ref.read(webSocketServiceProvider).sendInput(state);
    } catch (_) {}
  }

  void updateLeftStick(double x, double y) {
    _sequenceNumber++;
    state = state.copyWith(
      leftStickX: x,
      leftStickY: y,
      sequenceNumber: _sequenceNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _broadcast();
  }

  void updateRightStick(double x, double y) {
    _sequenceNumber++;
    state = state.copyWith(
      rightStickX: x,
      rightStickY: y,
      sequenceNumber: _sequenceNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _broadcast();
  }

  void pressButton(String button) {
    if (state.isPressed(button)) return;
    _sequenceNumber++;
    final updated = Set<String>.from(state.pressedButtons)..add(button);
    state = state.copyWith(
      pressedButtons: updated,
      sequenceNumber: _sequenceNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _broadcast();
  }

  void releaseButton(String button) {
    if (!state.isPressed(button)) return;
    _sequenceNumber++;
    final updated = Set<String>.from(state.pressedButtons)..remove(button);
    state = state.copyWith(
      pressedButtons: updated,
      sequenceNumber: _sequenceNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _broadcast();
  }

  void resetButton(String button) {
    releaseButton(button);
  }

  void resetAll() {
    _sequenceNumber++;
    state = ControllerState.neutral.copyWith(
      sequenceNumber: _sequenceNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _broadcast();
  }
}

final controllerProvider =
    NotifierProvider<ControllerNotifier, ControllerState>(ControllerNotifier.new);
