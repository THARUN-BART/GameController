import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/connection_info.dart';
import '../providers/connection_provider.dart';
import '../widgets/connection_indicator.dart';
import 'controller_screen.dart';
import 'qr_scanner_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Recent devices history for convenience
  final List<Map<String, dynamic>> _recentDevices = [
    {
      'name': 'Desktop-Rig (Primary)',
      'ip': '192.168.1.105',
      'port': 8080,
      'lastConnected': 'Yesterday',
    },
    {
      'name': 'Gaming-Laptop',
      'ip': '192.168.1.120',
      'port': 8080,
      'lastConnected': '3 days ago',
    },
  ];

  Future<void> _handleScanQr() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      ref
          .read(connectionProvider.notifier)
          .setStatus(ConnectionStatus.scanning);

      final qrResult = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (context) => const QrScannerScreen()),
      );

      if (!mounted) return;

      if (qrResult != null && qrResult.isNotEmpty) {
        // In Phase 2 this will parse the JSON payload and execute the handshake
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned QR Payload: $qrResult'),
            backgroundColor: const Color(0xFF0284C7),
          ),
        );
        ref
            .read(connectionProvider.notifier)
            .setStatus(ConnectionStatus.disconnected);
      } else {
        ref
            .read(connectionProvider.notifier)
            .setStatus(ConnectionStatus.disconnected);
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
    final ipController = TextEditingController(text: '192.168.1.');
    final portController = TextEditingController(text: '8080');
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
                Navigator.pop(context);

                // Set simulated connected info for testing Phase 1
                ref.read(connectionProvider.notifier).setConnected(
                      host: ip,
                      port: port,
                      serverName: 'PC ($ip)',
                    );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Target set to $ip:$port'),
                    backgroundColor: Colors.teal,
                  ),
                );
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

  void _openGamepad() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ControllerScreen(),
      ),
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
          IconButton(
            tooltip: 'Simulate Connect/Disconnect',
            icon: Icon(
              connection.isConnected
                  ? Icons.link_off_rounded
                  : Icons.bolt_rounded,
              color: connection.isConnected ? Colors.redAccent : Colors.cyanAccent,
            ),
            onPressed: () {
              if (connection.isConnected) {
                ref.read(connectionProvider.notifier).disconnect();
              } else {
                ref.read(connectionProvider.notifier).simulateConnect();
              }
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
                          ref.read(connectionProvider.notifier).setConnected(
                                host: dev['ip'],
                                port: dev['port'],
                                serverName: dev['name'],
                              );
                          _openGamepad();
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
