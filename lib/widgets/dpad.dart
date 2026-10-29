import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CircularDpad extends StatefulWidget {
  final double size;
  final Color baseColor;
  final Function(String) onButtonDown;
  final Function(String) onButtonUp;
  final Set<String> activeButtons;

  const CircularDpad({
    super.key,
    required this.size,
    required this.baseColor,
    required this.onButtonDown,
    required this.onButtonUp,
    required this.activeButtons,
  });

  @override
  State<CircularDpad> createState() => _CircularDpadState();
}

class _CircularDpadState extends State<CircularDpad> {
  String? _currentDirection;

  void _handleTouch(Offset localPos) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPos - center;
    final dist = delta.distance;

    // Center deadzone
    if (dist < widget.size * 0.15) {
      _releaseCurrent();
      return;
    }

    // Determine direction angle
    final angle = delta.direction; // -pi to +pi
    String dir;
    if (angle >= -0.785 && angle <= 0.785) {
      dir = 'DPAD_RIGHT';
    } else if (angle > 0.785 && angle < 2.356) {
      dir = 'DPAD_DOWN';
    } else if (angle < -0.785 && angle > -2.356) {
      dir = 'DPAD_UP';
    } else {
      dir = 'DPAD_LEFT';
    }

    if (_currentDirection != dir) {
      _releaseCurrent();
      _currentDirection = dir;
      HapticFeedback.lightImpact();
      widget.onButtonDown(dir);
      setState(() {});
    }
  }

  void _releaseCurrent() {
    if (_currentDirection != null) {
      widget.onButtonUp(_currentDirection!);
      _currentDirection = null;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.baseColor;
    final arrowSize = widget.size * 0.22;

    return RepaintBoundary(
      child: Listener(
      onPointerDown: (e) => _handleTouch(e.localPosition),
      onPointerMove: (e) => _handleTouch(e.localPosition),
      onPointerUp: (_) => _releaseCurrent(),
      onPointerCancel: (_) => _releaseCurrent(),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              const Color(0xFF5A040D),
            ],
            center: const Alignment(-0.2, -0.2),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center subtle indentation
            Container(
              width: widget.size * 0.32,
              height: widget.size * 0.32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A0005).withValues(alpha: 0.6),
                border: Border.all(color: Colors.white10),
              ),
            ),

            // UP
            Positioned(
              top: 10,
              child: _ArrowIndicator(
                icon: Icons.keyboard_arrow_up_rounded,
                size: arrowSize,
                isActive: widget.activeButtons.contains('DPAD_UP') ||
                    _currentDirection == 'DPAD_UP',
              ),
            ),

            // DOWN
            Positioned(
              bottom: 10,
              child: _ArrowIndicator(
                icon: Icons.keyboard_arrow_down_rounded,
                size: arrowSize,
                isActive: widget.activeButtons.contains('DPAD_DOWN') ||
                    _currentDirection == 'DPAD_DOWN',
              ),
            ),

            // LEFT
            Positioned(
              left: 10,
              child: _ArrowIndicator(
                icon: Icons.keyboard_arrow_left_rounded,
                size: arrowSize,
                isActive: widget.activeButtons.contains('DPAD_LEFT') ||
                    _currentDirection == 'DPAD_LEFT',
              ),
            ),

            // RIGHT
            Positioned(
              right: 10,
              child: _ArrowIndicator(
                icon: Icons.keyboard_arrow_right_rounded,
                size: arrowSize,
                isActive: widget.activeButtons.contains('DPAD_RIGHT') ||
                    _currentDirection == 'DPAD_RIGHT',
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _ArrowIndicator extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isActive;

  const _ArrowIndicator({
    required this.icon,
    required this.size,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isActive ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 50),
      child: Icon(
        icon,
        size: size,
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.85),
        shadows: isActive
            ? [
                const Shadow(
                  color: Colors.white,
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
    );
  }
}
