import 'package:flutter/foundation.dart';

/// Represents the momentary state of the virtual gamepad.
@immutable
class ControllerState {
  final double leftStickX;
  final double leftStickY;
  final Set<String> pressedButtons;
  final int sequenceNumber;
  final int timestamp;

  const ControllerState({
    this.leftStickX = 0.0,
    this.leftStickY = 0.0,
    this.pressedButtons = const <String>{},
    this.sequenceNumber = 0,
    this.timestamp = 0,
  });

  /// Neutral / reset state with zero deflection and no active buttons.
  static const ControllerState neutral = ControllerState();

  bool isPressed(String button) => pressedButtons.contains(button);

  ControllerState copyWith({
    double? leftStickX,
    double? leftStickY,
    Set<String>? pressedButtons,
    int? sequenceNumber,
    int? timestamp,
  }) {
    return ControllerState(
      leftStickX: leftStickX ?? this.leftStickX,
      leftStickY: leftStickY ?? this.leftStickY,
      pressedButtons: pressedButtons ?? this.pressedButtons,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Clamps and formats to JSON suitable for protocol messages.
  Map<String, dynamic> toJson() {
    return {
      'seq': sequenceNumber,
      'ts': timestamp,
      'stick': {
        'x': double.parse(leftStickX.clamp(-1.0, 1.0).toStringAsFixed(4)),
        'y': double.parse(leftStickY.clamp(-1.0, 1.0).toStringAsFixed(4)),
      },
      'buttons': pressedButtons.toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControllerState &&
          runtimeType == other.runtimeType &&
          leftStickX == other.leftStickX &&
          leftStickY == other.leftStickY &&
          setEquals(pressedButtons, other.pressedButtons);

  @override
  int get hashCode =>
      leftStickX.hashCode ^
      leftStickY.hashCode ^
      Object.hashAll(pressedButtons);
}
