import 'package:flutter/foundation.dart';

import 'character_group.dart';
import 'shortcut.dart';

/// Application level preferences, stored next to the groups.
@immutable
class AppSettings {
  const AppSettings({
    this.closeToTray = true,
    this.startMinimized = false,
    this.launchAtStartup = false,
    this.quitShortcut,
    this.showWindowShortcut,
  });

  /// Closing the window sends the organizer to the notification area instead
  /// of quitting.
  final bool closeToTray;

  /// Hide the window right after startup when the process was not autostarted
  /// with the minimized flag.
  final bool startMinimized;

  /// Mirrors the HKCU Run entry; the value is owned by the registry and only
  /// cached here for display.
  final bool launchAtStartup;

  /// Global shortcut terminating the organizer, equivalent to the F12 binding
  /// of the original script.
  final Shortcut? quitShortcut;

  /// Global shortcut bringing the window back from the notification area.
  final Shortcut? showWindowShortcut;

  AppSettings copyWith({
    bool? closeToTray,
    bool? startMinimized,
    bool? launchAtStartup,
    Shortcut? quitShortcut,
    bool clearQuitShortcut = false,
    Shortcut? showWindowShortcut,
    bool clearShowWindowShortcut = false,
  }) {
    return AppSettings(
      closeToTray: closeToTray ?? this.closeToTray,
      startMinimized: startMinimized ?? this.startMinimized,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      quitShortcut:
          clearQuitShortcut ? null : (quitShortcut ?? this.quitShortcut),
      showWindowShortcut: clearShowWindowShortcut
          ? null
          : (showWindowShortcut ?? this.showWindowShortcut),
    );
  }

  Map<String, Object?> toJson() => {
        'closeToTray': closeToTray,
        'startMinimized': startMinimized,
        if (quitShortcut != null) 'quitShortcut': quitShortcut!.toJson(),
        if (showWindowShortcut != null)
          'showWindowShortcut': showWindowShortcut!.toJson(),
      };

  static AppSettings fromJson(Object? json) {
    if (json is! Map) return const AppSettings();
    return AppSettings(
      closeToTray:
          json['closeToTray'] is bool ? json['closeToTray'] as bool : true,
      startMinimized: json['startMinimized'] is bool
          ? json['startMinimized'] as bool
          : false,
      quitShortcut: Shortcut.fromJson(json['quitShortcut']),
      showWindowShortcut: Shortcut.fromJson(json['showWindowShortcut']),
    );
  }
}

/// Full persisted state of the organizer.
@immutable
class OrganizerConfig {
  const OrganizerConfig({
    this.groups = const <CharacterGroup>[],
    this.settings = const AppSettings(),
  });

  /// Schema version, bumped whenever a migration becomes necessary.
  static const int schemaVersion = 1;

  final List<CharacterGroup> groups;
  final AppSettings settings;

  OrganizerConfig copyWith({
    List<CharacterGroup>? groups,
    AppSettings? settings,
  }) {
    return OrganizerConfig(
      groups: groups ?? this.groups,
      settings: settings ?? this.settings,
    );
  }

  Map<String, Object?> toJson() => {
        'version': schemaVersion,
        'settings': settings.toJson(),
        'groups': groups.map((g) => g.toJson()).toList(),
      };

  static OrganizerConfig fromJson(Object? json) {
    if (json is! Map) return const OrganizerConfig();
    final rawGroups = json['groups'];
    final groups = <CharacterGroup>[];
    if (rawGroups is List) {
      for (final entry in rawGroups) {
        final group = CharacterGroup.fromJson(entry);
        if (group != null) {
          groups.add(group);
        }
      }
    }
    return OrganizerConfig(
      groups: groups,
      settings: AppSettings.fromJson(json['settings']),
    );
  }
}
