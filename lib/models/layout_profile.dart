import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'layout_config.dart';

@immutable
class ControllerProfile {
  final String id;
  final String name;
  final bool isDefault;
  final ControllerLayoutConfig config;

  const ControllerProfile({
    required this.id,
    required this.name,
    this.isDefault = false,
    required this.config,
  });

  static const String defaultId = 'default_controller';

  /// The pristine, permanent default controller matching qw12.jpg
  static const ControllerProfile defaultProfile = ControllerProfile(
    id: defaultId,
    name: 'Default Controller',
    isDefault: true,
    config: ControllerLayoutConfig.defaultLayout,
  );

  ControllerProfile copyWith({
    String? id,
    String? name,
    bool? isDefault,
    ControllerLayoutConfig? config,
  }) {
    return ControllerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isDefault': isDefault,
        'config': config.toJson(),
      };

  factory ControllerProfile.fromJson(Map<String, dynamic> json) {
    return ControllerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      config: ControllerLayoutConfig.fromJson(json['config'] as Map<String, dynamic>),
    );
  }

  static List<ControllerProfile> listFromJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => ControllerProfile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [defaultProfile];
    }
  }

  static String listToJson(List<ControllerProfile> profiles) {
    return jsonEncode(profiles.map((p) => p.toJson()).toList());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControllerProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          config == other.config;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ config.hashCode;
}
