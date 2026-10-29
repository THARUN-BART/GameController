import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Professional Game Rumble / Force Feedback Haptic Engine.
///
/// Converts Xbox 360 Dual-Motor (Large = low freq heavy rumble, Small = high freq light rumble)
/// into smooth, high-fidelity physical vibrations on Android devices.
/// Prevents motor interruption and OS channel spamming while maintaining responsive feedback.
class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  bool _initialized = false;
  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;
  bool _hasCustomVibrations = false;

  int _lastIntensity = 0;
  DateTime _lastTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _cutoffTimer;

  /// Eagerly checks hardware vibrator capabilities once.
  Future<void> init() async {
    if (_initialized) return;
    try {
      _hasVibrator = await Vibration.hasVibrator() ?? false;
      if (_hasVibrator) {
        _hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;
        _hasCustomVibrations = await Vibration.hasCustomVibrationsSupport() ?? false;
      }
      _initialized = true;
      debugPrint(
        '[HapticService] Initialized. Vibrator: $_hasVibrator, Amplitude: $_hasAmplitudeControl, Custom: $_hasCustomVibrations',
      );
    } catch (e) {
      debugPrint('[HapticService] Init exception: $e');
      _initialized = true;
    }
  }

  /// Triggers haptic rumble based on Xbox 360 controller motor speeds (0 - 255).
  ///
  /// [large]: Left motor (heavy low-frequency rumble, e.g. explosions, heavy impacts).
  /// [small]: Right motor (sharp high-frequency rumble, e.g. blade cuts, gunfire).
  void triggerRumble(int large, int small) {
    if (!_initialized) {
      init();
    }

    // Blend both motors into a unified perception intensity (0..255)
    // Large motor has heavier weight for physical kick, small adds high-frequency presence
    final weighted = (large * 0.85 + small * 0.65).round().clamp(0, 255);
    final intensity = max(max(large, small), weighted);

    // Motor stop signal from game (large == 0 && small == 0)
    if (intensity == 0) {
      _cutoffTimer?.cancel();
      _cutoffTimer = null;
      if (_lastIntensity > 0) {
        _lastIntensity = 0;
        try {
          Vibration.cancel();
        } catch (_) {}
      }
      return;
    }

    final now = DateTime.now();
    final elapsedMs = now.difference(_lastTriggerTime).inMilliseconds;

    // Smoothing & Throttling:
    // If the motor is already vibrating and intensity change is negligible (< 10%)
    // and last pulse was under 100ms ago, let the current vibration sustain
    // instead of resetting the motor coil.
    final diff = (intensity - _lastIntensity).abs();
    if (diff < 25 && elapsedMs < 100 && _lastIntensity > 0) {
      return;
    }

    _lastIntensity = intensity;
    _lastTriggerTime = now;

    // Sustained duration: keep spinning smoothly until next update or stop packet
    final duration = intensity > 180 ? 300 : (intensity > 90 ? 220 : 150);
    final amplitude = intensity.clamp(1, 255);

    try {
      if (_hasVibrator) {
        if (_hasAmplitudeControl) {
          Vibration.vibrate(duration: duration, amplitude: amplitude);
        } else {
          Vibration.vibrate(duration: duration);
        }
      } else {
        // Fallback for devices without standard Vibrator motor
        if (intensity > 160) {
          HapticFeedback.heavyImpact();
        } else if (intensity > 70) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      }
    } catch (e) {
      debugPrint('[HapticService] Vibration error: $e');
    }

    // Safety watchdog: automatically zero out after duration + 50ms if no new packets arrive
    _cutoffTimer?.cancel();
    _cutoffTimer = Timer(Duration(milliseconds: duration + 50), () {
      _lastIntensity = 0;
    });
  }

  /// One-touch test rumble (duration in ms, strength 0.0 to 1.0)
  void testBuzz({int durationMs = 150, double strength = 1.0}) {
    if (!_initialized) {
      init();
    }
    final amp = (strength * 255).round().clamp(1, 255);
    try {
      if (_hasVibrator && _hasAmplitudeControl) {
        Vibration.vibrate(duration: durationMs, amplitude: amp);
      } else if (_hasVibrator) {
        Vibration.vibrate(duration: durationMs);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Cancels any active vibration.
  void cancel() {
    _cutoffTimer?.cancel();
    _cutoffTimer = null;
    _lastIntensity = 0;
    try {
      Vibration.cancel();
    } catch (_) {}
  }
}
