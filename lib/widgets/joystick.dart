import 'dart:math' as math;
import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  final double size;
  final double knobSize;
  final double deadzone;
  final ValueChanged<Offset> onChanged;

  const VirtualJoystick({
    super.key,
    this.size = 200,
    this.knobSize = 80,
    this.deadzone = 0.08,
    required this.onChanged,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  late AnimationController _springController;
  late Animation<Offset> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..addListener(() {
        setState(() {
          _dragOffset = _springAnimation.value;
        });
        _emitPosition(_dragOffset);
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _springController.stop();
    _updateOffset(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _updateOffset(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    _releaseToCenter();
  }

  void _onPanCancel() {
    _releaseToCenter();
  }

  void _updateOffset(Offset localPos) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPos - center;
    final maxDistance = (widget.size - widget.knobSize) / 2;
    final distance = delta.distance;

    Offset clampedOffset;
    if (distance <= maxDistance) {
      clampedOffset = delta;
    } else {
      clampedOffset = Offset.fromDirection(delta.direction, maxDistance);
    }

    setState(() {
      _dragOffset = clampedOffset;
    });

    _emitPosition(_dragOffset);
  }

  void _releaseToCenter() {
    _springAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
    );
    _springController.forward(from: 0.0);
  }

  void _emitPosition(Offset offset) {
    final maxDistance = (widget.size - widget.knobSize) / 2;
    if (maxDistance <= 0) return;

    double normX = offset.dx / maxDistance;
    // Gamepad convention: Y is negative when pushed UP, positive when pulled DOWN
    // (or vice-versa; here standard Cartesian math: dy up is negative in screen coordinates)
    double normY = offset.dy / maxDistance;

    final mag = math.sqrt(normX * normX + normY * normY);
    if (mag < widget.deadzone) {
      normX = 0.0;
      normY = 0.0;
    } else {
      // Re-scale from deadzone to 1.0 for smooth ramp
      final scaledMag = (mag - widget.deadzone) / (1.0 - widget.deadzone);
      final factor = scaledMag / mag;
      normX = (normX * factor).clamp(-1.0, 1.0);
      normY = (normY * factor).clamp(-1.0, 1.0);
    }

    widget.onChanged(Offset(normX, normY));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Ring / Base
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E2433).withValues(alpha: 0.8),
                    const Color(0xFF0F131D).withValues(alpha: 0.95),
                  ],
                ),
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.25),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.1),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _CrosshairPainter(),
              ),
            ),

            // Draggable Knob
            Transform.translate(
              offset: _dragOffset,
              child: Container(
                width: widget.knobSize,
                height: widget.knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF3B4863),
                      Color(0xFF181F2F),
                    ],
                    center: Alignment(-0.2, -0.2),
                  ),
                  border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.8),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Colors.black54,
                      offset: Offset(2, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    const tickLen = 14.0;
    const ringRadius = 40.0;

    // Subtle inner reference circle
    canvas.drawCircle(center, ringRadius, paint);

    // Cardinal tick lines
    canvas.drawLine(
      Offset(center.dx, 12),
      Offset(center.dx, 12 + tickLen),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, size.height - 12 - tickLen),
      Offset(center.dx, size.height - 12),
      paint,
    );
    canvas.drawLine(
      Offset(12, center.dy),
      Offset(12 + tickLen, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 12 - tickLen, center.dy),
      Offset(size.width - 12, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
