import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActionButtonsCluster extends StatelessWidget {
  final Function(String) onButtonDown;
  final Function(String) onButtonUp;
  final Set<String> activeButtons;
  final double size;

  const ActionButtonsCluster({
    super.key,
    required this.onButtonDown,
    required this.onButtonUp,
    required this.activeButtons,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final btnSize = size * 0.32;
    final offsetDistance = size * 0.34;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background subtle cluster plate
          Container(
            width: size * 0.95,
            height: size * 0.95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF131824).withValues(alpha: 0.5),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1.5,
              ),
            ),
          ),

          // Y - Top (Yellow)
          Positioned(
            top: (size / 2) - offsetDistance - (btnSize / 2),
            child: _GamepadButton(
              label: 'Y',
              size: btnSize,
              color: const Color(0xFFFACC15),
              isPressed: activeButtons.contains('Y'),
              onDown: () => onButtonDown('Y'),
              onUp: () => onButtonUp('Y'),
            ),
          ),

          // A - Bottom (Green)
          Positioned(
            bottom: (size / 2) - offsetDistance - (btnSize / 2),
            child: _GamepadButton(
              label: 'A',
              size: btnSize,
              color: const Color(0xFF22C55E),
              isPressed: activeButtons.contains('A'),
              onDown: () => onButtonDown('A'),
              onUp: () => onButtonUp('A'),
            ),
          ),

          // X - Left (Blue)
          Positioned(
            left: (size / 2) - offsetDistance - (btnSize / 2),
            child: _GamepadButton(
              label: 'X',
              size: btnSize,
              color: const Color(0xFF38BDF8),
              isPressed: activeButtons.contains('X'),
              onDown: () => onButtonDown('X'),
              onUp: () => onButtonUp('X'),
            ),
          ),

          // B - Right (Red)
          Positioned(
            right: (size / 2) - offsetDistance - (btnSize / 2),
            child: _GamepadButton(
              label: 'B',
              size: btnSize,
              color: const Color(0xFFEF4444),
              isPressed: activeButtons.contains('B'),
              onDown: () => onButtonDown('B'),
              onUp: () => onButtonUp('B'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GamepadButton extends StatefulWidget {
  final String label;
  final double size;
  final Color color;
  final bool isPressed;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _GamepadButton({
    required this.label,
    required this.size,
    required this.color,
    required this.isPressed,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<_GamepadButton> createState() => _GamepadButtonState();
}

class _GamepadButtonState extends State<_GamepadButton> {
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

    return Listener(
      onPointerDown: (_) => _triggerDown(),
      onPointerUp: (_) => _triggerUp(),
      onPointerCancel: (_) => _triggerUp(),
      child: AnimatedScale(
        scale: active ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 60),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: active
                  ? [
                      widget.color.withValues(alpha: 0.8),
                      widget.color.withValues(alpha: 0.4),
                    ]
                  : [
                      const Color(0xFF283248),
                      const Color(0xFF181F2E),
                    ],
              center: const Alignment(-0.2, -0.3),
            ),
            border: Border.all(
              color: active ? widget.color : widget.color.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: active ? Colors.white : widget.color,
                fontWeight: FontWeight.w900,
                fontSize: widget.size * 0.42,
                shadows: [
                  if (active)
                    Shadow(
                      color: widget.color,
                      blurRadius: 8,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
