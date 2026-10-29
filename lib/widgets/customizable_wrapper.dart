import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/layout_config.dart';
import '../providers/layout_provider.dart';

class CustomizableWrapper extends ConsumerWidget {
  final String id;
  final String label;
  final ControlPosition position;
  final Widget child;
  final BoxConstraints parentConstraints;

  const CustomizableWrapper({
    super.key,
    required this.id,
    required this.label,
    required this.position,
    required this.child,
    required this.parentConstraints,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(editModeProvider);
    final width = parentConstraints.maxWidth;
    final height = parentConstraints.maxHeight;

    // Convert relative coordinates (0..1) to absolute pixels
    final left = (position.x * width).clamp(0.0, width - 40);
    final top = (position.y * height).clamp(0.0, height - 40);

    if (!isEditMode) {
      return Positioned(
        left: left,
        top: top,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: child,
        ),
      );
    }

    // In Edit Mode: allow dragging and show visual edit frame
    return Positioned(
      left: left,
      top: top,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onPanUpdate: (details) {
            final newRelX = position.x + (details.delta.dx / width);
            final newRelY = position.y + (details.delta.dy / height);
            ref.read(profileProvider.notifier).updatePosition(id, newRelX, newRelY);
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.8),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
              color: Colors.cyanAccent.withValues(alpha: 0.12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IgnorePointer(child: child),
                Positioned(
                  top: -12,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
