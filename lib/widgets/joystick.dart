import 'dart:math' as math;
import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  final double size;
  final double knobSize;
  final double deadzone;
  final Color baseColor;
  final Color knobColor;
  final ValueChanged<Offset> onChanged;

  const VirtualJoystick({
    super.key,
    this.size = 170,
    this.knobSize = 82,
    this.deadzone = 0.08,
    this.baseColor = const Color(0xFF990000), // Crimson red from qw12.jpg
    this.knobColor = const Color(0xFFFDE8E8), // Cream knob from qw12.jpg
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
    double normY = offset.dy / maxDistance;

    final mag = math.sqrt(normX * normX + normY * normY);
    if (mag < widget.deadzone) {
      normX = 0.0;
      normY = 0.0;
    } else {
      final scaledMag = (mag - widget.deadzone) / (1.0 - widget.deadzone);
      final factor = scaledMag / mag;
      normX = (normX * factor).clamp(-1.0, 1.0);
      normY = (normY * factor).clamp(-1.0, 1.0);
    }

    widget.onChanged(Offset(normX, normY));
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
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
            // Outer Ring / Base (Crimson)
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.baseColor,
                    const Color(0xFF550000),
                  ],
                  center: const Alignment(-0.25, -0.3),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 2.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _CrosshairPainter(),
              ),
            ),

            // Draggable Knob (Soft off-white / cream from qw12.jpg)
            Transform.translate(
              offset: _dragOffset,
              child: Container(
                width: widget.knobSize,
                height: widget.knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.knobColor,
                      const Color(0xFFE2C8C8),
                    ],
                    center: const Alignment(-0.2, -0.2),
                  ),
                  border: Border.all(
                    color: Colors.white,
                    width: 2.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      offset: Offset(2, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.baseColor.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    const tickLen = 10.0;

    canvas.drawLine(
      Offset(center.dx, 8),
      Offset(center.dx, 8 + tickLen),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, size.height - 8 - tickLen),
      Offset(center.dx, size.height - 8),
      paint,
    );
    canvas.drawLine(
      Offset(8, center.dy),
      Offset(8 + tickLen, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 8 - tickLen, center.dy),
      Offset(size.width - 8, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
