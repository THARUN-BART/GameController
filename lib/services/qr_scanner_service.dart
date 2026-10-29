import 'package:flutter/services.dart';
import '../models/qr_payload.dart';

class QrScannerService {
  const QrScannerService();

  /// Validates raw barcode text and executes haptic confirmation if successful.
  QrValidationResult processBarcode(String? rawContent) {
    if (rawContent == null || rawContent.trim().isEmpty) {
      return const QrValidationResult.failure('No barcode data detected.');
    }

    final result = QrPayload.tryParse(rawContent);

    if (result.isValid) {
      // Haptic confirmation of successful scan
      HapticFeedback.mediumImpact();
    } else {
      // Gentle warning feedback on invalid QR format
      HapticFeedback.lightImpact();
    }

    return result;
  }
}
