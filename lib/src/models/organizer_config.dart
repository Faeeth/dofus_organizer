import 'package:flutter/foundation.dart';

import 'character_group.dart';

/// Application level preferences, stored next to the groups.
@immutable
class AppSettings {
  const AppSettings({
    this.closeToTray = true,
    this.startMinimized = false,
    this.launchAtStartup = false,
    this.updateSnoozeUntil,
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

  /// Until when the update check stays quiet, set by "ignore for 30 days".
  /// Null when nothing was postponed.
  final DateTime? updateSnoozeUntil;

  AppSettings copyWith({
    bool? closeToTray,
    bool? startMinimized,
    bool? launchAtStartup,
    DateTime? updateSnoozeUntil,
    bool clearUpdateSnooze = false,
  }) {
    return AppSettings(
      closeToTray: closeToTray ?? this.closeToTray,
      startMinimized: startMinimized ?? this.startMinimized,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      updateSnoozeUntil: clearUpdateSnooze
          ? null
          : (updateSnoozeUntil ?? this.updateSnoozeUntil),
    );
  }

  Map<String, Object?> toJson() => {
        'closeToTray': closeToTray,
        'startMinimized': startMinimized,
        if (updateSnoozeUntil != null)
          'updateSnoozeUntil': updateSnoozeUntil!.millisecondsSinceEpoch,
      };

  static AppSettings fromJson(Object? json) {
    if (json is! Map) return const AppSettings();
    final snooze = json['updateSnoozeUntil'];
    return AppSettings(
      closeToTray:
          json['closeToTray'] is bool ? json['closeToTray'] as bool : true,
      startMinimized: json['startMinimized'] is bool
          ? json['startMinimized'] as bool
          : false,
      updateSnoozeUntil: snooze is int
          ? DateTime.fromMillisecondsSinceEpoch(snooze)
          : null,
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
