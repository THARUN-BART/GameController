import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemCenterButtons extends StatelessWidget {
  final Function(String) onButtonDown;
  final Function(String) onButtonUp;
  final Set<String> activeButtons;

  const SystemCenterButtons({
    super.key,
    required this.onButtonDown,
    required this.onButtonUp,
    required this.activeButtons,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PillButton(
          label: 'SELECT',
          icon: Icons.view_headline_rounded,
          isPressed: activeButtons.contains('SELECT'),
          onDown: () => onButtonDown('SELECT'),
          onUp: () => onButtonUp('SELECT'),
        ),
        const SizedBox(width: 24),
        _PillButton(
          label: 'START',
          icon: Icons.menu_rounded,
          isPressed: activeButtons.contains('START'),
          onDown: () => onButtonDown('START'),
          onUp: () => onButtonUp('START'),
        ),
      ],
    );
  }
}

class ShoulderBumper extends StatefulWidget {
  final String label;
  final bool isPressed;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final double width;
  final double height;

  const ShoulderBumper({
    super.key,
    required this.label,
    required this.isPressed,
    required this.onDown,
    required this.onUp,
    this.width = 110,
    this.height = 44,
  });

  @override
  State<ShoulderBumper> createState() => _ShoulderBumperState();
}

class _ShoulderBumperState extends State<ShoulderBumper> {
  bool _isLocallyDown = false;

  void _triggerDown() {
    if (!_isLocallyDown) {
      setState(() => _isLocallyDown = true);
      HapticFeedback.selectionClick();
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
        scale: active ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 50),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: active
                  ? [const Color(0xFF0284C7), const Color(0xFF0369A1)]
                  : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: active ? Colors.cyanAccent : Colors.white12,
              width: 1.5,
            ),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.4),
                  blurRadius: 10,
                )
              else
                const BoxShadow(
                  color: Colors.black45,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPressed;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.isPressed,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _isLocallyDown = false;

  void _triggerDown() {
    if (!_isLocallyDown) {
      setState(() => _isLocallyDown = true);
      HapticFeedback.selectionClick();
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
        duration: const Duration(milliseconds: 50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: active ? const Color(0xFF334155) : const Color(0xFF1E293B),
            border: Border.all(
              color: active ? Colors.cyanAccent : Colors.white24,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: active ? Colors.cyanAccent : Colors.white60,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: active ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
