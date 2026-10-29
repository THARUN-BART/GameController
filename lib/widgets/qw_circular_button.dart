import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QwCircularButton extends StatefulWidget {
  final String? label;
  final Widget? icon;
  final double size;
  final Color baseColor;
  final bool isPressed;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final double fontSize;

  const QwCircularButton({
    super.key,
    this.label,
    this.icon,
    required this.size,
    required this.baseColor,
    required this.isPressed,
    required this.onDown,
    required this.onUp,
    this.fontSize = 15,
  });

  @override
  State<QwCircularButton> createState() => _QwCircularButtonState();
}

class _QwCircularButtonState extends State<QwCircularButton> {
  bool _isLocallyDown = false;

  void _triggerDown() {
    if (!_isLocallyDown) {
      setState(() => _isLocallyDown = true);
      HapticFeedback.lightImpact();
      widget.onDown();
    }
  }

  void _triggerUp() {
    if (_isLocallyDown) {
      setState(() => _isLocallyDown = false);
      widget.onUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isPressed || _isLocallyDown;
    final color = widget.baseColor;

    return Listener(
      onPointerDown: (_) => _triggerDown(),
      onPointerUp: (_) => _triggerUp(),
      onPointerCancel: (_) => _triggerUp(),
      child: AnimatedScale(
        scale: active ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 50),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: active
                  ? [
                      color.withValues(alpha: 0.95),
                      const Color(0xFF550000),
                    ]
                  : [
                      color,
                      const Color(0xFF6A040F),
                    ],
              center: const Alignment(-0.25, -0.3),
            ),
            border: Border.all(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.15),
              width: 1.8,
            ),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 16,
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
          child: widget.icon ??
              Text(
                widget.label ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.fontSize,
                  letterSpacing: 0.5,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
