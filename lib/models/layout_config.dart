import 'dart:convert';
import 'package:flutter/material.dart';

@immutable
class ControlPosition {
  final double x; // Relative X coordinate (0.0 to 1.0)
  final double y; // Relative Y coordinate (0.0 to 1.0)

  const ControlPosition(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory ControlPosition.fromJson(Map<String, dynamic> json) =>
      ControlPosition((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

  ControlPosition copyWith({double? x, double? y}) =>
      ControlPosition(x ?? this.x, y ?? this.y);
}

@immutable
class ControllerLayoutConfig {
  final ControlPosition lt;
  final ControlPosition lb;
  final ControlPosition dpad;
  final ControlPosition leftStick;
  final ControlPosition rt;
  final ControlPosition rb;
  final ControlPosition abxy;
  final ControlPosition rightStick;
  final ControlPosition centerTop; // Exit 'X'
  final ControlPosition centerMid; // View, '2' / PS, Menu
  final ControlPosition centerLow; // Left Stick, Right Stick (L3/R3)
  final double scale;
  final String theme; // 'playstation_midnight', 'crimson', 'classic_gray', 'cyan'
  final String controllerStyle; // 'playstation' (△○✕□, L1/L2, R1/R2) or 'xbox' (ABXY, LB/LT, RB/RT)
  final double opacity;

  const ControllerLayoutConfig({
    required this.lt,
    required this.lb,
    required this.dpad,
    required this.leftStick,
    required this.rt,
    required this.rb,
    required this.abxy,
    required this.rightStick,
    required this.centerTop,
    required this.centerMid,
    required this.centerLow,
    this.scale = 1.0,
    this.theme = 'playstation_midnight',
    this.controllerStyle = 'playstation',
    this.opacity = 1.0,
  });

  /// Default PlayStation-inspired layout matching qw12.jpg
  static const ControllerLayoutConfig defaultLayout = ControllerLayoutConfig(
    lt: ControlPosition(0.06, 0.12),
    lb: ControlPosition(0.16, 0.28),
    dpad: ControlPosition(0.12, 0.65),
    leftStick: ControlPosition(0.33, 0.72),
    rt: ControlPosition(0.94, 0.12),
    rb: ControlPosition(0.84, 0.28),
    abxy: ControlPosition(0.88, 0.65),
    rightStick: ControlPosition(0.67, 0.72),
    centerTop: ControlPosition(0.50, 0.08),
    centerMid: ControlPosition(0.50, 0.24),
    centerLow: ControlPosition(0.50, 0.54),
    scale: 1.0,
    theme: 'playstation_midnight',
    controllerStyle: 'playstation',
    opacity: 1.0,
  );

  bool get isPlayStation => controllerStyle == 'playstation';

  Color get primaryColor {
    switch (theme) {
      case 'playstation_midnight':
        return const Color(0xFF1E2333); // DualSense Midnight Blue-Black
      case 'classic_gray':
        return const Color(0xFF474C5A); // Retro PS1 Gray
      case 'crimson':
        return const Color(0xFF990000); // qw12.jpg Crimson Red
      case 'cyan':
        return const Color(0xFF0F3B5F);
      default:
        return const Color(0xFF1E2333);
    }
  }

  Color get knobColor {
    switch (theme) {
      case 'playstation_midnight':
        return const Color(0xFFE8EEF5); // Crisp DualSense off-white
      case 'classic_gray':
        return const Color(0xFFD1D5DB);
      case 'crimson':
        return const Color(0xFFFDE8E8); // Cream-white knob from qw12.jpg
      case 'cyan':
        return const Color(0xFFE0F2FE);
      default:
        return const Color(0xFFE8EEF5);
    }
  }

  ControllerLayoutConfig copyWith({
    ControlPosition? lt,
    ControlPosition? lb,
    ControlPosition? dpad,
    ControlPosition? leftStick,
    ControlPosition? rt,
    ControlPosition? rb,
    ControlPosition? abxy,
    ControlPosition? rightStick,
    ControlPosition? centerTop,
    ControlPosition? centerMid,
    ControlPosition? centerLow,
    double? scale,
    String? theme,
    String? controllerStyle,
    double? opacity,
  }) {
    return ControllerLayoutConfig(
      lt: lt ?? this.lt,
      lb: lb ?? this.lb,
      dpad: dpad ?? this.dpad,
      leftStick: leftStick ?? this.leftStick,
      rt: rt ?? this.rt,
      rb: rb ?? this.rb,
      abxy: abxy ?? this.abxy,
      rightStick: rightStick ?? this.rightStick,
      centerTop: centerTop ?? this.centerTop,
      centerMid: centerMid ?? this.centerMid,
      centerLow: centerLow ?? this.centerLow,
      scale: scale ?? this.scale,
      theme: theme ?? this.theme,
      controllerStyle: controllerStyle ?? this.controllerStyle,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'lt': lt.toJson(),
        'lb': lb.toJson(),
        'dpad': dpad.toJson(),
        'leftStick': leftStick.toJson(),
        'rt': rt.toJson(),
        'rb': rb.toJson(),
        'abxy': abxy.toJson(),
        'rightStick': rightStick.toJson(),
        'centerTop': centerTop.toJson(),
        'centerMid': centerMid.toJson(),
        'centerLow': centerLow.toJson(),
        'scale': scale,
        'theme': theme,
        'controllerStyle': controllerStyle,
        'opacity': opacity,
      };

  factory ControllerLayoutConfig.fromJson(Map<String, dynamic> json) {
    return ControllerLayoutConfig(
      lt: ControlPosition.fromJson(json['lt']),
      lb: ControlPosition.fromJson(json['lb']),
      dpad: ControlPosition.fromJson(json['dpad']),
      leftStick: ControlPosition.fromJson(json['leftStick']),
      rt: ControlPosition.fromJson(json['rt']),
      rb: ControlPosition.fromJson(json['rb']),
      abxy: ControlPosition.fromJson(json['abxy']),
      rightStick: ControlPosition.fromJson(json['rightStick']),
      centerTop: ControlPosition.fromJson(json['centerTop']),
      centerMid: ControlPosition.fromJson(json['centerMid']),
      centerLow: ControlPosition.fromJson(json['centerLow']),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      theme: json['theme'] as String? ?? 'playstation_midnight',
      controllerStyle: json['controllerStyle'] as String? ?? 'playstation',
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  String toRawJson() => jsonEncode(toJson());
}
