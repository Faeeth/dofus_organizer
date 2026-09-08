import 'package:flutter/foundation.dart';

import 'shortcut.dart';

/// A Dofus client identified by a fragment of its window title, bound to a
/// global shortcut.
@immutable
class GameCharacter {
  const GameCharacter({
    required this.id,
    required this.name,
    required this.windowTitle,
    this.shortcut,
    this.classIcon,
    this.enabled = true,
  });

  final String id;

  /// Display name, free form.
  final String name;

  /// Substring searched in the window titles. Matching is case insensitive,
  /// mirroring the AutoHotkey `SetTitleMatchMode(2)` behaviour.
  final String windowTitle;

  final Shortcut? shortcut;

  /// Key of the class portrait, such as `iop_m`. Null when the character has
  /// no portrait.
  final String? classIcon;

  /// Whether the character takes part in the shortcut resolution. A character
  /// is only live when its group is enabled too.
  final bool enabled;

  bool get isBound => shortcut?.isValid ?? false;

  GameCharacter copyWith({
    String? name,
    String? windowTitle,
    Shortcut? shortcut,
    bool clearShortcut = false,
    String? classIcon,
    bool clearClassIcon = false,
    bool? enabled,
  }) {
    return GameCharacter(
      id: id,
      name: name ?? this.name,
      windowTitle: windowTitle ?? this.windowTitle,
      shortcut: clearShortcut ? null : (shortcut ?? this.shortcut),
      classIcon: clearClassIcon ? null : (classIcon ?? this.classIcon),
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'windowTitle': windowTitle,
        'enabled': enabled,
        if (classIcon != null) 'classIcon': classIcon,
        if (shortcut != null) 'shortcut': shortcut!.toJson(),
      };

  static GameCharacter? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    final windowTitle = json['windowTitle'];
    final classIcon = json['classIcon'];
    return GameCharacter(
      id: id,
      name: name,
      windowTitle: windowTitle is String ? windowTitle : name,
      classIcon: classIcon is String && classIcon.isNotEmpty ? classIcon : null,
      shortcut: Shortcut.fromJson(json['shortcut']),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }
}
