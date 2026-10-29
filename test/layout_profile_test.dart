import 'package:flutter_test/flutter_test.dart';
import 'package:game_controller/models/layout_config.dart';
import 'package:game_controller/models/layout_profile.dart';

void main() {
  group('Controller Profile Management Tests', () {
    test('Default profile is initialized with permanent default flag', () {
      final defaultP = ControllerProfile.defaultProfile;
      expect(defaultP.id, equals(ControllerProfile.defaultId));
      expect(defaultP.name, equals('Default Controller'));
      expect(defaultP.isDefault, isTrue);
      expect(defaultP.config.isPlayStation, isTrue);
    });

    test('Can create new custom controller profiles', () {
      const customConfig = ControllerLayoutConfig.defaultLayout;
      final customP = ControllerProfile(
        id: 'custom_123',
        name: 'FPS Pro Setup',
        isDefault: false,
        config: customConfig,
      );

      expect(customP.id, equals('custom_123'));
      expect(customP.name, equals('FPS Pro Setup'));
      expect(customP.isDefault, isFalse);
    });

    test('JSON serialization round-trip for profiles list', () {
      final list = [
        ControllerProfile.defaultProfile,
        ControllerProfile(
          id: 'custom_999',
          name: 'Racing Setup',
          isDefault: false,
          config: ControllerLayoutConfig.defaultLayout.copyWith(
            theme: 'crimson',
            scale: 1.2,
          ),
        ),
      ];

      final rawJson = ControllerProfile.listToJson(list);
      final decodedList = ControllerProfile.listFromJson(rawJson);

      expect(decodedList.length, equals(2));
      expect(decodedList[0].id, equals(ControllerProfile.defaultId));
      expect(decodedList[1].name, equals('Racing Setup'));
      expect(decodedList[1].config.theme, equals('crimson'));
      expect(decodedList[1].config.scale, equals(1.2));
    });
  });
}
