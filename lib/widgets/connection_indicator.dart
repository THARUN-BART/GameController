import 'package:flutter/material.dart';
import '../models/connection_info.dart';

class ConnectionIndicator extends StatelessWidget {
  final ConnectionInfo connection;
  final bool compact;

  const ConnectionIndicator({
    super.key,
    required this.connection,
    this.compact = false,
  });

  Color _getStatusColor() {
    switch (connection.status) {
      case ConnectionStatus.connected:
        return const Color(0xFF22C55E);
      case ConnectionStatus.connecting:
      case ConnectionStatus.pairing:
        return const Color(0xFF38BDF8);
      case ConnectionStatus.scanning:
      case ConnectionStatus.reconnecting:
        return const Color(0xFFF59E0B);
      case ConnectionStatus.failed:
        return const Color(0xFFEF4444);
      case ConnectionStatus.disconnected:
        return const Color(0xFF94A3B8);
    }
  }

  Color _getLatencyColor(int ms) {
    if (ms <= 0) return Colors.white54;
    if (ms < 20) return const Color(0xFF22C55E);
    if (ms < 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0F172A).withValues(alpha: 0.8),
          border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              connection.displayStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            if (connection.isConnected) ...[
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 12,
                color: Colors.white24,
              ),
              const SizedBox(width: 8),
              Text(
                '${connection.latencyMs} ms',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _getLatencyColor(connection.latencyMs),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.15),
            ),
            child: Icon(
              connection.isConnected
                  ? Icons.wifi_rounded
                  : Icons.wifi_off_rounded,
              color: statusColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.displayStatus,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  connection.isConnected
                      ? '${connection.serverName ?? "PC"} (${connection.host}:${connection.port})'
                      : (connection.errorMessage ??
                          'Not connected to any Windows receiver'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (connection.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF0F172A),
                border: Border.all(
                  color: _getLatencyColor(connection.latencyMs)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.speed_rounded,
                    size: 14,
                    color: _getLatencyColor(connection.latencyMs),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${connection.latencyMs} ms',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getLatencyColor(connection.latencyMs),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
