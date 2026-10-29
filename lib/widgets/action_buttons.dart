import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActionButtonsCluster extends StatelessWidget {
  final Function(String) onButtonDown;
  final Function(String) onButtonUp;
  final double size;
  final Color baseColor;
  final bool isPlayStation;

  const ActionButtonsCluster({
    super.key,
    required this.onButtonDown,
    required this.onButtonUp,
    this.size = 190,
    required this.baseColor,
    this.isPlayStation = true,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = size * 0.38;
    final offsetDistance = size * 0.32;

    // Top: Triangle (PS) or Y (Xbox)
    final topLabel = isPlayStation ? '△' : 'Y';
    final topCode = isPlayStation ? 'TRIANGLE' : 'Y';
    final topColor = isPlayStation ? const Color(0xFF00F076) : const Color(0xFFFACC15);

    // Bottom: Cross (PS) or A (Xbox)
    final bottomLabel = isPlayStation ? '✕' : 'A';
    final bottomCode = isPlayStation ? 'CROSS' : 'A';
    final bottomColor = isPlayStation ? const Color(0xFF38BDF8) : const Color(0xFF22C55E);

    // Left: Square (PS) or X (Xbox)
    final leftLabel = isPlayStation ? '□' : 'X';
    final leftCode = isPlayStation ? 'SQUARE' : 'X';
    final leftColor = isPlayStation ? const Color(0xFFFF5EA7) : const Color(0xFF60A5FA);

    // Right: Circle (PS) or B (Xbox)
    final rightLabel = isPlayStation ? '○' : 'B';
    final rightCode = isPlayStation ? 'CIRCLE' : 'B';
    final rightColor = isPlayStation ? const Color(0xFFFF4D4D) : const Color(0xFFEF4444);

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top Button
            Positioned(
              top: (size / 2) - offsetDistance - (btnSize / 2),
              child: _ActionBtn(
                label: topLabel,
                size: btnSize,
                baseColor: baseColor,
                glyphColor: topColor,
                onDown: () => onButtonDown(topCode),
                onUp: () => onButtonUp(topCode),
              ),
            ),

            // Bottom Button
            Positioned(
              bottom: (size / 2) - offsetDistance - (btnSize / 2),
              child: _ActionBtn(
                label: bottomLabel,
                size: btnSize,
                baseColor: baseColor,
                glyphColor: bottomColor,
                onDown: () => onButtonDown(bottomCode),
                onUp: () => onButtonUp(bottomCode),
              ),
            ),

            // Left Button
            Positioned(
              left: (size / 2) - offsetDistance - (btnSize / 2),
              child: _ActionBtn(
                label: leftLabel,
                size: btnSize,
                baseColor: baseColor,
                glyphColor: leftColor,
                onDown: () => onButtonDown(leftCode),
                onUp: () => onButtonUp(leftCode),
              ),
            ),

            // Right Button
            Positioned(
              right: (size / 2) - offsetDistance - (btnSize / 2),
              child: _ActionBtn(
                label: rightLabel,
                size: btnSize,
                baseColor: baseColor,
                glyphColor: rightColor,
                onDown: () => onButtonDown(rightCode),
                onUp: () => onButtonUp(rightCode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final double size;
  final Color baseColor;
  final Color glyphColor;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _ActionBtn({
    required this.label,
    required this.size,
    required this.baseColor,
    required this.glyphColor,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _isPressed = false;

  void _triggerDown() {
    if (!_isPressed) {
      setState(() => _isPressed = true);
      HapticFeedback.lightImpact();
      widget.onDown();
    }
  }

  void _triggerUp() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      widget.onUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _isPressed;
    final color = widget.baseColor;
    final glyph = widget.glyphColor;

    return Listener(
      onPointerDown: (_) => _triggerDown(),
      onPointerUp: (_) => _triggerUp(),
      onPointerCancel: (_) => _triggerUp(),
      child: AnimatedScale(
        scale: active ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 40),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: active
                  ? [
                      color.withValues(alpha: 0.95),
                      const Color(0xFF0F172A),
                    ]
                  : [
                      color,
                      const Color(0xFF131927),
                    ],
              center: const Alignment(-0.25, -0.3),
            ),
            border: Border.all(
              color: active ? glyph : Colors.white.withValues(alpha: 0.18),
              width: active ? 2.2 : 1.6,
            ),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: glyph.withValues(alpha: 0.65),
                  blurRadius: 14,
                  spreadRadius: 2,
                )
              else
                const BoxShadow(
                  color: Colors.black87,
                  offset: Offset(0, 3),
                  blurRadius: 6,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: active ? Colors.white : glyph,
              fontWeight: FontWeight.w900,
              fontSize: widget.size * 0.54,
              shadows: [
                Shadow(
                  color: active ? glyph : Colors.black87,
                  offset: const Offset(1, 1),
                  blurRadius: active ? 8 : 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
