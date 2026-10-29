import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/layout_config.dart';
import '../models/layout_profile.dart';
import '../services/profile_storage_service.dart';

@immutable
class ProfileState {
  final List<ControllerProfile> profiles;
  final String activeProfileId;

  const ProfileState({
    required this.profiles,
    required this.activeProfileId,
  });

  ControllerProfile get activeProfile {
    return profiles.firstWhere(
      (p) => p.id == activeProfileId,
      orElse: () => profiles.isNotEmpty ? profiles.first : ControllerProfile.defaultProfile,
    );
  }

  ControllerLayoutConfig get activeConfig => activeProfile.config;

  ProfileState copyWith({
    List<ControllerProfile>? profiles,
    String? activeProfileId,
  }) {
    return ProfileState(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  final ProfileStorageService _storage = const ProfileStorageService();

  @override
  ProfileState build() {
    // Initial in-memory state
    _loadFromDisk();
    return const ProfileState(
      profiles: [ControllerProfile.defaultProfile],
      activeProfileId: ControllerProfile.defaultId,
    );
  }

  Future<void> _loadFromDisk() async {
    final list = await _storage.loadProfiles();
    final activeId = await _storage.loadActiveProfileId();

    final validId = list.any((p) => p.id == activeId)
        ? activeId
        : ControllerProfile.defaultId;

    state = ProfileState(
      profiles: list,
      activeProfileId: validId,
    );
  }

  Future<void> _persist() async {
    await _storage.saveProfiles(state.profiles);
    await _storage.saveActiveProfileId(state.activeProfileId);
  }

  /// Switch the currently active controller profile
  void selectProfile(String id) {
    if (state.profiles.any((p) => p.id == id)) {
      state = state.copyWith(activeProfileId: id);
      _persist();
    }
  }

  /// Create a brand new custom controller profile
  String createProfile(String name, {ControllerLayoutConfig? baseConfig}) {
    final trimmed = name.trim().isEmpty ? 'Custom Controller' : name.trim();
    final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';

    final newProfile = ControllerProfile(
      id: newId,
      name: trimmed,
      isDefault: false,
      config: baseConfig ?? state.activeConfig,
    );

    final updatedList = List<ControllerProfile>.from(state.profiles)..add(newProfile);

    state = ProfileState(
      profiles: updatedList,
      activeProfileId: newId,
    );

    _persist();
    return newId;
  }

  /// Rename an existing profile (except default)
  void renameProfile(String id, String newName) {
    if (id == ControllerProfile.defaultId) return;
    final updated = state.profiles.map((p) {
      if (p.id == id) {
        return p.copyWith(name: newName.trim());
      }
      return p;
    }).toList();

    state = state.copyWith(profiles: updated);
    _persist();
  }

  /// Delete a custom profile (Default Controller cannot be deleted)
  void deleteProfile(String id) {
    if (id == ControllerProfile.defaultId) return;

    final updated = state.profiles.where((p) => p.id != id).toList();
    final newActive = state.activeProfileId == id
        ? ControllerProfile.defaultId
        : state.activeProfileId;

    state = ProfileState(
      profiles: updated,
      activeProfileId: newActive,
    );

    _persist();
  }

  /// Update active configuration
  void updateActiveConfig(ControllerLayoutConfig Function(ControllerLayoutConfig) transform) {
    final active = state.activeProfile;
    final newConfig = transform(active.config);

    final updated = state.profiles.map((p) {
      if (p.id == active.id) {
        return p.copyWith(config: newConfig);
      }
      return p;
    }).toList();

    state = state.copyWith(profiles: updated);
    _persist();
  }

  void updatePosition(String controlId, double x, double y) {
    final pos = ControlPosition(x.clamp(0.02, 0.98), y.clamp(0.04, 0.96));
    updateActiveConfig((cfg) {
      switch (controlId) {
        case 'lt':
          return cfg.copyWith(lt: pos);
        case 'lb':
          return cfg.copyWith(lb: pos);
        case 'dpad':
          return cfg.copyWith(dpad: pos);
        case 'leftStick':
          return cfg.copyWith(leftStick: pos);
        case 'rt':
          return cfg.copyWith(rt: pos);
        case 'rb':
          return cfg.copyWith(rb: pos);
        case 'abxy':
          return cfg.copyWith(abxy: pos);
        case 'rightStick':
          return cfg.copyWith(rightStick: pos);
        case 'centerTop':
          return cfg.copyWith(centerTop: pos);
        case 'centerMid':
          return cfg.copyWith(centerMid: pos);
        case 'centerLow':
          return cfg.copyWith(centerLow: pos);
        default:
          return cfg;
      }
    });
  }

  void setScale(double scale) {
    updateActiveConfig((cfg) => cfg.copyWith(scale: scale.clamp(0.7, 1.4)));
  }

  void setTheme(String theme) {
    updateActiveConfig((cfg) => cfg.copyWith(theme: theme));
  }

  void setControllerStyle(String style) {
    updateActiveConfig((cfg) => cfg.copyWith(controllerStyle: style));
  }

  void setOpacity(double opacity) {
    updateActiveConfig((cfg) => cfg.copyWith(opacity: opacity.clamp(0.4, 1.0)));
  }

  void resetActiveToDefault() {
    updateActiveConfig((_) => ControllerLayoutConfig.defaultLayout);
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);

/// Convenience provider returning the active layout config
final layoutProvider = Provider<ControllerLayoutConfig>((ref) {
  return ref.watch(profileProvider.select((s) => s.activeConfig));
});

class EditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setEditMode(bool active) => state = active;
}

final editModeProvider =
    NotifierProvider<EditModeNotifier, bool>(EditModeNotifier.new);
