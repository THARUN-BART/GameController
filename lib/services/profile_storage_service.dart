import 'dart:io';
import '../models/layout_profile.dart';

class ProfileStorageService {
  const ProfileStorageService();

  File get _profilesFile {
    final tempDir = Directory.systemTemp.path;
    return File('$tempDir/lan_gamepad_profiles.json');
  }

  File get _selectedProfileFile {
    final tempDir = Directory.systemTemp.path;
    return File('$tempDir/lan_gamepad_active_profile.txt');
  }

  Future<List<ControllerProfile>> loadProfiles() async {
    try {
      final file = _profilesFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = ControllerProfile.listFromJson(content);
        // Ensure default profile is always present
        if (!list.any((p) => p.id == ControllerProfile.defaultId)) {
          list.insert(0, ControllerProfile.defaultProfile);
        }
        return list;
      }
    } catch (_) {}

    return [ControllerProfile.defaultProfile];
  }

  Future<void> saveProfiles(List<ControllerProfile> profiles) async {
    try {
      final file = _profilesFile;
      await file.writeAsString(ControllerProfile.listToJson(profiles));
    } catch (_) {}
  }

  Future<String> loadActiveProfileId() async {
    try {
      final file = _selectedProfileFile;
      if (await file.exists()) {
        final id = (await file.readAsString()).trim();
        if (id.isNotEmpty) return id;
      }
    } catch (_) {}
    return ControllerProfile.defaultId;
  }

  Future<void> saveActiveProfileId(String id) async {
    try {
      final file = _selectedProfileFile;
      await file.writeAsString(id);
    } catch (_) {}
  }
}
