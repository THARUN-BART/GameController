import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/connection_info.dart';
import '../models/qr_payload.dart';
import '../providers/connection_provider.dart';
import '../providers/layout_provider.dart';
import '../services/websocket_service.dart';
import '../widgets/connection_indicator.dart';
import 'controller_screen.dart';
import 'qr_scanner_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _lockPortrait();
  }

  void _lockPortrait() {
    // Mandate strictly portrait orientation for the Home Screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  final List<Map<String, dynamic>> _recentDevices = [];

  Future<void> _handleScanQr() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      ref.read(connectionProvider.notifier).setStatus(ConnectionStatus.scanning);

      final result = await Navigator.of(context).push<QrPayload>(
        MaterialPageRoute(builder: (context) => const QrScannerScreen()),
      );

      if (!mounted) return;

      if (result != null) {
        _showPairingConfirmationSheet(result);
      } else {
        ref.read(connectionProvider.notifier).setStatus(ConnectionStatus.disconnected);
      }
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to scan QR codes'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showPairingConfirmationSheet(QrPayload payload) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.cyanAccent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payload.serverName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Valid Pairing QR Code Verified',
                          style: TextStyle(fontSize: 12, color: Colors.greenAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'Target Host', value: payload.host),
                    const Divider(color: Colors.white12, height: 16),
                    _InfoRow(label: 'WebSocket Port', value: '${payload.port}'),
                    const Divider(color: Colors.white12, height: 16),
                    _InfoRow(
                      label: 'Protocol Version',
                      value: 'v${payload.version}',
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    _InfoRow(
                      label: 'Pairing Token',
                      value: '${payload.token.substring(0, 4)}...${payload.token.substring(payload.token.length - 4)}',
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    _InfoRow(
                      label: 'Expires In',
                      value: '${payload.remainingSeconds}s',
                      valueColor: Colors.amberAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _connectAndLaunchGamepad(payload);
                },
                icon: const Icon(Icons.link_rounded),
                label: const Text(
                  'Accept & Connect Gamepad',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Camera Permission Needed'),
        content: const Text(
          'Camera access is required to scan pairing QR codes. Please enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showManualConnectDialog() {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '8080');
    final tokenController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.lan_rounded, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text('Manual Connection'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'Receiver IP Address',
                  hintText: 'e.g. 192.168.1.100',
                  prefixIcon: Icon(Icons.computer_rounded),
                ),
                keyboardType: TextInputType.datetime,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter IP';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: 'WebSocket Port',
                  hintText: '8080',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || int.tryParse(val.trim()) == null) {
                    return 'Enter valid port';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: 'Pairing Token',
                  hintText: 'UUID token shown on PC receiver',
                  prefixIcon: Icon(Icons.key_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Enter pairing token';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final ip = ipController.text.trim();
                final port = int.parse(portController.text.trim());
                final token = tokenController.text.trim();
                Navigator.pop(context);

                final manualPayload = QrPayload(
                  version: QrPayload.currentVersion,
                  app: QrPayload.appIdentifier,
                  host: ip,
                  port: port,
                  token: token,
                  expiresAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
                  serverName: 'PC ($ip)',
                );

                _connectAndLaunchGamepad(manualPayload);
              }
            },
            child: const Text(
              'Connect',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectAndLaunchGamepad(QrPayload payload) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                Text(
                  'Connecting to ${payload.serverName}...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'ws://${payload.host}:${payload.port}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Authenticating security handshake with PC receiver...',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final wsService = ref.read(webSocketServiceProvider);
    final success = await wsService.connect(
      host: payload.host,
      port: payload.port,
      token: payload.token,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Dismiss connecting modal

    if (success) {
      _updateRecentDevice(payload);
      _openGamepad();
    } else {
      final errorMsg = ref.read(connectionProvider).errorMessage ??
          'Pairing handshake failed. Ensure PC receiver is running on the same Wi-Fi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _connectAndLaunchGamepad(payload),
          ),
        ),
      );
    }
  }

  void _updateRecentDevice(QrPayload payload) {
    setState(() {
      _recentDevices.removeWhere(
        (d) => d['ip'] == payload.host && d['port'] == payload.port,
      );
      _recentDevices.insert(0, {
        'name': payload.serverName,
        'ip': payload.host,
        'port': payload.port,
        'token': payload.token,
        'lastConnected': 'Just now',
      });
      if (_recentDevices.length > 5) {
        _recentDevices.removeLast();
      }
    });
  }

  Future<void> _openGamepad() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ControllerScreen(),
      ),
    );
    // When returning from controller screen, strictly re-enforce portrait orientation
    _lockPortrait();
  }

  void _showCreateProfileDialog() {
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
              'Enter a name for your custom controller layout:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Pro Racing / DualSense Mod',
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
                  content: Text('Created and selected "$name"!'),
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

  void _showProfileManagerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final profileState = ref.watch(profileProvider);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Controller Layouts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Layout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCreateProfileDialog();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...profileState.profiles.map((p) {
                final isSelected = p.id == profileState.activeProfileId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.cyanAccent.withValues(alpha: 0.12)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Colors.cyanAccent : Colors.white12,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      p.isDefault ? Icons.lock_outline_rounded : Icons.sports_esports_rounded,
                      color: isSelected ? Colors.cyanAccent : Colors.white60,
                    ),
                    title: Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.cyanAccent : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      p.isDefault
                          ? 'Permanent Default • ${p.config.isPlayStation ? "PlayStation (△○✕□)" : "Xbox (ABXY)"}'
                          : 'Custom Layout • ${p.config.isPlayStation ? "PlayStation" : "Xbox"}',
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Colors.cyanAccent, size: 20),
                        if (!p.isDefault)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Delete Layout',
                            onPressed: () {
                              ref.read(profileProvider.notifier).deleteProfile(p.id);
                            },
                          ),
                      ],
                    ),
                    onTap: () {
                      ref.read(profileProvider.notifier).selectProfile(p.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Switched to "${p.name}"'),
                          backgroundColor: Colors.teal,
                          duration: const Duration(milliseconds: 700),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                color: Colors.cyanAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'LAN Gamepad',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (connection.isConnected)
            IconButton(
              tooltip: 'Disconnect',
              icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
              onPressed: () {
                ref.read(webSocketServiceProvider).disconnect(reason: 'user_action');
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            ConnectionIndicator(connection: connection),

            const SizedBox(height: 24),

            // Main Hero Action Card: Scan QR
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 48,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Instant PC Pairing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Scan the QR code displayed on the Windows PC receiver to pair instantly over Wi-Fi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _handleScanQr,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Active Controller Layout Card with Selector / Create
            Builder(builder: (context) {
              final activeProfile = ref.watch(profileProvider.select((s) => s.activeProfile));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF131B2E),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sports_esports_rounded, color: Colors.cyanAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeProfile.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeProfile.isDefault
                                ? 'Permanent Default • ${activeProfile.config.isPlayStation ? "PlayStation (△○✕□)" : "Xbox (ABXY)"}'
                                : 'Custom • ${activeProfile.config.isPlayStation ? "PlayStation" : "Xbox"}',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Colors.cyanAccent, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 14, color: Colors.cyanAccent),
                      label: const Text('Layouts', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                      onPressed: _showProfileManagerSheet,
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 14),

            // Open Controller Button
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: connection.isConnected
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _openGamepad,
                icon: const Icon(Icons.sports_esports_rounded),
                label: Text(
                  connection.isConnected
                      ? 'Launch Game Controller'
                      : 'Open Controller UI (Preview / Test)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Fallback manual connection button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _showManualConnectDialog,
              icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.white70),
              label: const Text(
                'Manual IP Connection Fallback',
                style: TextStyle(color: Colors.white70),
              ),
            ),

            const SizedBox(height: 24),

            // Recent Devices Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Paired PCs',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _recentDevices.clear());
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_recentDevices.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF131826),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'No recent paired devices',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              )
            else
              ..._recentDevices.map(
                (dev) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF131B2E),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.desktop_windows_rounded,
                          color: Colors.cyanAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dev['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dev['ip']}:${dev['port']} • ${dev['lastConnected']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quick Connect',
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.cyanAccent,
                        ),
                        onPressed: () {
                          final payload = QrPayload(
                            version: QrPayload.currentVersion,
                            app: QrPayload.appIdentifier,
                            host: dev['ip'] as String,
                            port: dev['port'] as int,
                            token: (dev['token'] as String?) ?? '',
                            expiresAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
                            serverName: dev['name'] as String,
                          );
                          _connectAndLaunchGamepad(payload);
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white60)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.white,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
