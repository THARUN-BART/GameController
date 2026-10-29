import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/qr_scanner_service.dart';

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

  final QrScannerService _scannerService = const QrScannerService();

  bool _isDisposed = false;
  bool _isSuccess = false;
  String? _validationError;
  bool _torchActive = false;

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isSuccess || _isDisposed) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final result = _scannerService.processBarcode(raw);

      if (result.isValid && result.payload != null) {
        setState(() {
          _isSuccess = true;
          _validationError = null;
        });

        // Small delay to let user see successful visual confirmation
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.of(context).pop(result.payload);
          }
        });
        break;
      } else {
        // Show validation error banner without closing screen
        if (mounted && _validationError != result.errorMessage) {
          setState(() {
            _validationError = result.errorMessage;
          });
        }
      }
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() {
      _torchActive = !_torchActive;
    });
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
            icon: Icon(
              _torchActive ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchActive ? Colors.yellowAccent : Colors.white70,
            ),
            tooltip: 'Toggle Flashlight',
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white70),
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

          // Custom Reticle Overlay with active status color
          _ScannerOverlay(
            isSuccess: _isSuccess,
            hasError: _validationError != null,
          ),

          // Real-time Validation Error Banner
          if (_validationError != null && !_isSuccess)
            Positioned(
              top: 24,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Success Banner
          if (_isSuccess)
            Positioned(
              top: 24,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'QR Code Validated! Connecting...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Instructions at bottom
          Positioned(
            bottom: 36,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'Point camera at the pairing QR code displayed in the LAN Gamepad Windows receiver.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
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
  final bool isSuccess;
  final bool hasError;

  const _ScannerOverlay({
    required this.isSuccess,
    required this.hasError,
  });

  Color get _borderColor {
    if (isSuccess) return const Color(0xFF22C55E);
    if (hasError) return const Color(0xFFEF4444);
    return Colors.cyanAccent;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanBoxSize = size.width * 0.72;
    final color = _borderColor;

    return Container(
      width: scanBoxSize,
      height: scanBoxSize,
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isSuccess ? 0.35 : 0.1),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, child: _CornerAccent(isTop: true, isLeft: true, color: color)),
          Positioned(top: 0, right: 0, child: _CornerAccent(isTop: true, isLeft: false, color: color)),
          Positioned(bottom: 0, left: 0, child: _CornerAccent(isTop: false, isLeft: true, color: color)),
          Positioned(bottom: 0, right: 0, child: _CornerAccent(isTop: false, isLeft: false, color: color)),
        ],
      ),
    );
  }
}

class _CornerAccent extends StatelessWidget {
  final bool isTop;
  final bool isLeft;
  final Color color;

  const _CornerAccent({
    required this.isTop,
    required this.isLeft,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const length = 26.0;
    const thickness = 4.5;

    return Container(
      width: length,
      height: length,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: color, width: thickness) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: color, width: thickness) : BorderSide.none,
          left: isLeft ? BorderSide(color: color, width: thickness) : BorderSide.none,
          right: !isLeft ? BorderSide(color: color, width: thickness) : BorderSide.none,
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
