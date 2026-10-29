import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_info.dart';
import '../providers/connection_provider.dart';
import '../providers/controller_provider.dart';
import '../providers/layout_provider.dart';
import '../services/websocket_service.dart';
import '../widgets/action_buttons.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/customizable_wrapper.dart';
import '../widgets/dpad.dart';
import '../widgets/joystick.dart';
import '../widgets/qw_circular_button.dart';

class ControllerScreen extends ConsumerStatefulWidget {
  const ControllerScreen({super.key});

  @override
  ConsumerState<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends ConsumerState<ControllerScreen> {
  // Cache notifiers and services to safely access inside dispose() without using ref
  late final ControllerNotifier _controllerNotifier;
  late final EditModeNotifier _editModeNotifier;
  late final WebSocketService _webSocketService;
  bool _isFailureDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _controllerNotifier = ref.read(controllerProvider.notifier);
    _editModeNotifier = ref.read(editModeProvider.notifier);
    _webSocketService = ref.read(webSocketServiceProvider);

    // Lock into landscape and immersive full-screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Safely reset states and disconnect WebSocket using cached references
    _controllerNotifier.resetAll();
    _editModeNotifier.setEditMode(false);
    _webSocketService.disconnect(reason: 'exit_gamepad');

    // Strictly restore mandatory portrait mode when leaving the controller screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onButtonDown(String btn) {
    if (ref.read(editModeProvider)) return;
    _controllerNotifier.pressButton(btn);
  }

  void _onButtonUp(String btn) {
    if (ref.read(editModeProvider)) return;
    _controllerNotifier.releaseButton(btn);
  }

  void _showConnectionFailedDialog(BuildContext context, String? errorMessage) {
    if (_isFailureDialogShowing) return;
    _isFailureDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('Connection Lost', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          errorMessage ?? 'Lost communication with the PC receiver.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _isFailureDialogShowing = false;
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Home', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            onPressed: () {
              _isFailureDialogShowing = false;
              Navigator.of(ctx).pop();
              _webSocketService.retryReconnect();
            },
          ),
        ],
      ),
    ).then((_) => _isFailureDialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for connection failures to surface action dialog
    ref.listen<ConnectionInfo>(connectionProvider, (previous, next) {
      if (next.status == ConnectionStatus.failed && mounted) {
        _showConnectionFailedDialog(context, next.errorMessage);
      }
    });

    // NOTE: We deliberately DO NOT watch controllerProvider here!
    // Watching controllerProvider at root caused 120 FPS rebuilds on every thumb move.
    final layout = ref.watch(layoutProvider);
    final isEditMode = ref.watch(editModeProvider);
    final isConnected = ref.watch(connectionProvider.select((c)=> c.isConnected));

    final baseColor = layout.primaryColor;
    final knobColor = layout.knobColor;
    final s = layout.scale;
    final isPS = layout.isPlayStation;

    // PlayStation vs Xbox nomenclature
    final triggerLeftLabel = isPS ? 'L2' : 'LT';
    final bumperLeftLabel = isPS ? 'L1' : 'LB';
    final triggerRightLabel = isPS ? 'R2' : 'RT';
    final bumperRightLabel = isPS ? 'R1' : 'RB';

    return Scaffold(
      backgroundColor: const Color(0xFF0C0F17), // Sleek PlayStation Dark
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Opacity(
              opacity: layout.opacity,
              child: Stack(
                children: [
                  // 1. L2 / LT (Left Trigger - Large circle top-left)
                  CustomizableWrapper(
                    id: 'lt',
                    label: triggerLeftLabel,
                    position: layout.lt,
                    parentConstraints: constraints,
                    child: QwCircularButton(
                      label: triggerLeftLabel,
                      size: 78 * s,
                      fontSize: 18 * s,
                      baseColor: baseColor,
                      isPressed: false,
                      onDown: () => _onButtonDown(triggerLeftLabel),
                      onUp: () => _onButtonUp(triggerLeftLabel),
                    ),
                  ),

                  // 2. L1 / LB (Left Bumper - Circle slightly inward from trigger)
                  CustomizableWrapper(
                    id: 'lb',
                    label: bumperLeftLabel,
                    position: layout.lb,
                    parentConstraints: constraints,
                    child: QwCircularButton(
                      label: bumperLeftLabel,
                      size: 60 * s,
                      fontSize: 15 * s,
                      baseColor: baseColor,
                      isPressed: false,
                      onDown: () => _onButtonDown(bumperLeftLabel),
                      onUp: () => _onButtonUp(bumperLeftLabel),
                    ),
                  ),

                  // 3. D-PAD (Directional Disc bottom-left)
                  CustomizableWrapper(
                    id: 'dpad',
                    label: 'D-PAD',
                    position: layout.dpad,
                    parentConstraints: constraints,
                    child: CircularDpad(
                      size: 130 * s,
                      baseColor: baseColor,
                      onButtonDown: _onButtonDown,
                      onButtonUp: _onButtonUp,
                      activeButtons: const {},
                    ),
                  ),

                  // 4. LEFT STICK (Analog thumbstick bottom left-center)
                  CustomizableWrapper(
                    id: 'leftStick',
                    label: 'STICK L',
                    position: layout.leftStick,
                    parentConstraints: constraints,
                    child: VirtualJoystick(
                      size: 138 * s,
                      knobSize: 68 * s,
                      baseColor: baseColor,
                      knobColor: knobColor,
                      onChanged: (offset) {
                        if (!isEditMode) {
                          _controllerNotifier.updateLeftStick(offset.dx, -offset.dy);
                        }
                      },
                    ),
                  ),

                  // 5. R2 / RT (Right Trigger - Large circle top-right)
                  CustomizableWrapper(
                    id: 'rt',
                    label: triggerRightLabel,
                    position: layout.rt,
                    parentConstraints: constraints,
                    child: QwCircularButton(
                      label: triggerRightLabel,
                      size: 78 * s,
                      fontSize: 18 * s,
                      baseColor: baseColor,
                      isPressed: false,
                      onDown: () => _onButtonDown(triggerRightLabel),
                      onUp: () => _onButtonUp(triggerRightLabel),
                    ),
                  ),

                  // 6. R1 / RB (Right Bumper - Circle slightly inward from trigger)
                  CustomizableWrapper(
                    id: 'rb',
                    label: bumperRightLabel,
                    position: layout.rb,
                    parentConstraints: constraints,
                    child: QwCircularButton(
                      label: bumperRightLabel,
                      size: 60 * s,
                      fontSize: 15 * s,
                      baseColor: baseColor,
                      isPressed: false,
                      onDown: () => _onButtonDown(bumperRightLabel),
                      onUp: () => _onButtonUp(bumperRightLabel),
                    ),
                  ),

                  // 7. RIGHT STICK (Analog thumbstick bottom right-center)
                  CustomizableWrapper(
                    id: 'rightStick',
                    label: 'STICK R',
                    position: layout.rightStick,
                    parentConstraints: constraints,
                    child: VirtualJoystick(
                      size: 138 * s,
                      knobSize: 68 * s,
                      baseColor: baseColor,
                      knobColor: knobColor,
                      onChanged: (offset) {
                        if (!isEditMode) {
                          _controllerNotifier.updateRightStick(offset.dx, -offset.dy);
                        }
                      },
                    ),
                  ),

                  // 8. ACTION BUTTONS (PlayStation △○✕□ or Xbox ABXY Diamond)
                  CustomizableWrapper(
                    id: 'abxy',
                    label: isPS ? '△○✕□' : 'ABXY',
                    position: layout.abxy,
                    parentConstraints: constraints,
                    child: ActionButtonsCluster(
                      size: 182 * s,
                      baseColor: baseColor,
                      isPlayStation: isPS,
                      onButtonDown: _onButtonDown,
                      onButtonUp: _onButtonUp,
                    ),
                  ),

                  // 9. CENTER TOP: Exit Button '✕'
                  CustomizableWrapper(
                    id: 'centerTop',
                    label: 'EXIT',
                    position: layout.centerTop,
                    parentConstraints: constraints,
                    child: QwCircularButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      size: 38 * s,
                      baseColor: baseColor,
                      isPressed: false,
                      onDown: () {},
                      onUp: () {
                        if (!isEditMode) Navigator.of(context).pop();
                      },
                    ),
                  ),

                  // 10. CENTER MID ROW: Share/View, PS/Home, Options/Menu
                  CustomizableWrapper(
                    id: 'centerMid',
                    label: 'SYSTEM',
                    position: layout.centerMid,
                    parentConstraints: constraints,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Share (PS) or View (Xbox)
                        QwCircularButton(
                          icon: Icon(
                            isPS ? Icons.share_rounded : Icons.filter_none_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          size: 44 * s,
                          baseColor: baseColor,
                          isPressed: false,
                          onDown: () => _onButtonDown(isPS ? 'SHARE' : 'VIEW'),
                          onUp: () => _onButtonUp(isPS ? 'SHARE' : 'VIEW'),
                        ),
                        SizedBox(width: 14 * s),

                        // PS Button or Guide '2'
                        QwCircularButton(
                          label: isPS ? 'PS' : '2',
                          size: 46 * s,
                          fontSize: 15 * s,
                          baseColor: baseColor,
                          isPressed: false,
                          onDown: () => _onButtonDown('GUIDE'),
                          onUp: () => _onButtonUp('GUIDE'),
                        ),
                        SizedBox(width: 14 * s),

                        // Options (PS) or Menu (Xbox)
                        QwCircularButton(
                          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 19),
                          size: 44 * s,
                          baseColor: baseColor,
                          isPressed: false,
                          onDown: () => _onButtonDown(isPS ? 'OPTIONS' : 'MENU'),
                          onUp: () => _onButtonUp(isPS ? 'OPTIONS' : 'MENU'),
                        ),
                      ],
                    ),
                  ),

                  // 11. CENTER LOWER ROW: L3 & R3 Thumbstick Buttons
                  CustomizableWrapper(
                    id: 'centerLow',
                    label: 'L3 / R3',
                    position: layout.centerLow,
                    parentConstraints: constraints,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QwCircularButton(
                          label: isPS ? 'L3' : 'Left\nStick',
                          size: 50 * s,
                          fontSize: isPS ? 13 * s : 10 * s,
                          baseColor: baseColor,
                          isPressed: false,
                          onDown: () => _onButtonDown('L3'),
                          onUp: () => _onButtonUp('L3'),
                        ),
                        SizedBox(width: 16 * s),
                        QwCircularButton(
                          label: isPS ? 'R3' : 'Right\nStick',
                          size: 50 * s,
                          fontSize: isPS ? 13 * s : 10 * s,
                          baseColor: baseColor,
                          isPressed: false,
                          onDown: () => _onButtonDown('R3'),
                          onUp: () => _onButtonUp('R3'),
                        ),
                      ],
                    ),
                  ),

                  // Live Connection Status HUD Pill
                  if (!isEditMode)
                    Positioned(
                      top: 10,
                      left: 14,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final conn = ref.watch(connectionProvider);
                          return ConnectionIndicator(connection: conn, compact: true);
                        },
                      ),
                    ),

                  // Floating Reconnecting Top Alert Banner
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final conn = ref.watch(connectionProvider);
                        if (conn.status != ConnectionStatus.reconnecting) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF78350F).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFDE68A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Reconnecting to PC... (${conn.reconnectAttempt}/${conn.maxReconnectAttempts})',
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Edit Mode Floating Button (when not in edit mode)
                  if (!isEditMode && !isConnected)
                    Positioned(
                      top: 10,
                      right: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
                          tooltip: 'Customize Layout',
                          onPressed: () {
                            _editModeNotifier.setEditMode(true);
                          },
                        ),
                      ),
                    ),

                  // Edit Mode Top Toolbar Banner
                  if (isEditMode)
                    Positioned(
                      top: 10,
                      left: 20,
                      right: 20,
                      child: _EditModeToolbar(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditModeToolbar extends ConsumerWidget {
  void _showCreateProfileDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: 'My Custom Controller');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Create New Controller'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a name for your new controller layout:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Racing Pro / FPS Setup',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () {
              final name = controller.text.trim();
              Navigator.pop(ctx);
              ref.read(profileProvider.notifier).createProfile(name);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Created and switched to "$name"'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
            child: const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final layout = profileState.activeConfig;
    final activeProfile = profileState.activeProfile;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.8), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 12),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active Profile Selector Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
              ),
              child: DropdownButton<String>(
                value: activeProfile.id,
                dropdownColor: const Color(0xFF1E293B),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                items: profileState.profiles.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          p.isDefault ? Icons.lock_outline_rounded : Icons.sports_esports_rounded,
                          size: 14,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: p.id == activeProfile.id ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    ref.read(profileProvider.notifier).selectProfile(id);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),

            // + New Controller Button
            IconButton.filledTonal(
              tooltip: 'Create New Controller',
              style: IconButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withValues(alpha: 0.18),
                foregroundColor: Colors.cyanAccent,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              onPressed: () => _showCreateProfileDialog(context, ref),
            ),

            const SizedBox(width: 12),

            // PlayStation vs Xbox Style Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF0F172A),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => ref.read(profileProvider.notifier).setControllerStyle('playstation'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'PS (△○✕□)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: layout.isPlayStation ? Colors.cyanAccent : Colors.white54,
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 14, color: Colors.white24),
                  InkWell(
                    onTap: () => ref.read(profileProvider.notifier).setControllerStyle('xbox'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'Xbox (ABXY)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: !layout.isPlayStation ? Colors.cyanAccent : Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Theme Selector
            DropdownButton<String>(
              value: layout.theme,
              dropdownColor: const Color(0xFF1E293B),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'playstation_midnight', child: Text('PS Midnight')),
                DropdownMenuItem(value: 'crimson', child: Text('Crimson (qw12)')),
                DropdownMenuItem(value: 'classic_gray', child: Text('Retro PS Gray')),
                DropdownMenuItem(value: 'cyan', child: Text('Cyber Cyan')),
              ],
              onChanged: (val) {
                if (val != null) ref.read(profileProvider.notifier).setTheme(val);
              },
            ),
            const SizedBox(width: 8),

            // Scale -
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 20),
              tooltip: 'Scale Down',
              onPressed: () {
                ref.read(profileProvider.notifier).setScale(layout.scale - 0.08);
              },
            ),
            Text(
              '${(layout.scale * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            // Scale +
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20),
              tooltip: 'Scale Up',
              onPressed: () {
                ref.read(profileProvider.notifier).setScale(layout.scale + 0.08);
              },
            ),

            const SizedBox(width: 10),

            // Reset Button
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset', style: TextStyle(fontSize: 12)),
              onPressed: () {
                ref.read(profileProvider.notifier).resetActiveToDefault();
              },
            ),

            const SizedBox(width: 10),

            // Done Button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save & Done', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                ref.read(editModeProvider.notifier).setEditMode(false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Layout saved to "${activeProfile.name}"!'),
                    duration: const Duration(milliseconds: 900),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
