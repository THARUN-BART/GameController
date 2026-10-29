import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_provider.dart';
import '../providers/controller_provider.dart';
import '../widgets/action_buttons.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/joystick.dart';
import '../widgets/system_buttons.dart';

class ControllerScreen extends ConsumerStatefulWidget {
  const ControllerScreen({super.key});

  @override
  ConsumerState<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends ConsumerState<ControllerScreen> {
  bool _showDebugHud = true;

  @override
  void initState() {
    super.initState();
    // Lock into landscape mode and enable immersive full-screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Reset inputs immediately when leaving the controller screen
    ref.read(controllerProvider.notifier).resetAll();

    // Restore standard device orientations and system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onButtonDown(String button) {
    ref.read(controllerProvider.notifier).pressButton(button);
  }

  void _onButtonUp(String button) {
    ref.read(controllerProvider.notifier).releaseButton(button);
  }

  void _onJoystickChanged(Offset norm) {
    ref.read(controllerProvider.notifier).updateStick(norm.dx, norm.dy);
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);
    final controller = ref.watch(controllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive scaling for different screen dimensions
            final availableHeight = constraints.maxHeight;
            final joystickSize = (availableHeight * 0.65).clamp(160.0, 240.0);
            final clusterSize = (availableHeight * 0.68).clamp(170.0, 250.0);

            return Stack(
              children: [
                // Background subtle mesh/grid pattern
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.04,
                    child: GridPaper(
                      color: Colors.cyanAccent,
                      divisions: 2,
                      subdivisions: 2,
                    ),
                  ),
                ),

                // Top Header Bar
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Exit / Back Button
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white70,
                        ),
                        tooltip: 'Exit Controller',
                      ),

                      // Connection Status & Latency
                      ConnectionIndicator(
                        connection: connection,
                        compact: true,
                      ),

                      // Actions: Toggle HUD & Emergency Input Reset
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showDebugHud = !_showDebugHud;
                              });
                            },
                            icon: Icon(
                              _showDebugHud
                                  ? Icons.data_object_rounded
                                  : Icons.data_object_outlined,
                              size: 20,
                              color: _showDebugHud
                                  ? Colors.cyanAccent
                                  : Colors.white54,
                            ),
                            tooltip: 'Toggle Input Telemetry',
                          ),
                          IconButton(
                            onPressed: () {
                              ref.read(controllerProvider.notifier).resetAll();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Controls reset to neutral'),
                                  duration: Duration(milliseconds: 600),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 20,
                              color: Colors.white54,
                            ),
                            tooltip: 'Reset Controls',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Shoulder Bumpers (L1 and R1)
                Positioned(
                  top: 56,
                  left: 28,
                  child: ShoulderBumper(
                    label: 'L1',
                    isPressed: controller.isPressed('L1'),
                    onDown: () => _onButtonDown('L1'),
                    onUp: () => _onButtonUp('L1'),
                  ),
                ),
                Positioned(
                  top: 56,
                  right: 28,
                  child: ShoulderBumper(
                    label: 'R1',
                    isPressed: controller.isPressed('R1'),
                    onDown: () => _onButtonDown('R1'),
                    onUp: () => _onButtonUp('R1'),
                  ),
                ),

                // Main Controls Area: Left Stick, Center Hub, Right Buttons
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left: Analog Joystick
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: VirtualJoystick(
                          size: joystickSize,
                          knobSize: joystickSize * 0.38,
                          onChanged: _onJoystickChanged,
                        ),
                      ),

                      // Center: Telemetry HUD + Select/Start Buttons
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showDebugHud) ...[
                              _TelemetryHud(controller: controller),
                              const SizedBox(height: 14),
                            ],
                            SystemCenterButtons(
                              onButtonDown: _onButtonDown,
                              onButtonUp: _onButtonUp,
                              activeButtons: controller.pressedButtons,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),

                      // Right: A/B/X/Y Action Diamond
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ActionButtonsCluster(
                          size: clusterSize,
                          activeButtons: controller.pressedButtons,
                          onButtonDown: _onButtonDown,
                          onButtonUp: _onButtonUp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TelemetryHud extends StatelessWidget {
  final dynamic controller;

  const _TelemetryHud({required this.controller});

  @override
  Widget build(BuildContext context) {
    final stickX = controller.leftStickX.toStringAsFixed(2);
    final stickY = controller.leftStickY.toStringAsFixed(2);
    final buttons = controller.pressedButtons.isEmpty
        ? 'None'
        : controller.pressedButtons.join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gamepad, size: 14, color: Colors.cyanAccent),
              const SizedBox(width: 6),
              Text(
                'X: $stickX   Y: $stickY',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Active: $buttons',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.white70,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
