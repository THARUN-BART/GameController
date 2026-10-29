import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_controller/main.dart';

void main() {
  testWidgets('LAN Gamepad App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: LANGamepadApp()));

    // Verify app title and primary buttons render
    expect(find.text('LAN Gamepad'), findsOneWidget);
    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.text('Manual IP Connection Fallback'), findsOneWidget);
  });
}
