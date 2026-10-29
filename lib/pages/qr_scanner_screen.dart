import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isDisposed = false;
  bool _scanned = false;

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned || _isDisposed) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawVal = barcode.rawValue;
      if (rawVal != null && rawVal.isNotEmpty) {
        setState(() => _scanned = true);
        Navigator.of(context).pop(rawVal);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan PC QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.yellowAccent),
            tooltip: 'Toggle Flashlight',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white70),
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Custom Scanner Overlay with Viewport Frame
          const _ScannerOverlay(),

          // Instructions at bottom
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'Point camera at the QR code displayed on your Windows PC receiver screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanBoxSize = size.width * 0.72;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Reticle box
        Container(
          width: scanBoxSize,
          height: scanBoxSize,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.8), width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              // 4 Corner accents
              Positioned(top: 0, left: 0, child: _CornerAccent(isTop: true, isLeft: true)),
              Positioned(top: 0, right: 0, child: _CornerAccent(isTop: true, isLeft: false)),
              Positioned(bottom: 0, left: 0, child: _CornerAccent(isTop: false, isLeft: true)),
              Positioned(bottom: 0, right: 0, child: _CornerAccent(isTop: false, isLeft: false)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CornerAccent extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _CornerAccent({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    const length = 24.0;
    const thickness = 4.0;
    const color = Colors.cyanAccent;

    return Container(
      width: length,
      height: length,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          left: isLeft ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: color, width: thickness) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? const Radius.circular(16) : Radius.zero,
          topRight: isTop && !isLeft ? const Radius.circular(16) : Radius.zero,
          bottomLeft: !isTop && isLeft ? const Radius.circular(16) : Radius.zero,
          bottomRight: !isTop && !isLeft ? const Radius.circular(16) : Radius.zero,
        ),
      ),
    );
  }
}
