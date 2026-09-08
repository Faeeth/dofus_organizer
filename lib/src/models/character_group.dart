import 'package:flutter/foundation.dart';

import 'game_character.dart';

/// A team of characters that are played together. Disabling the group removes
/// every one of its characters from the shortcut resolution at once, which is
/// how two teams can share the same keys without colliding.
@immutable
class CharacterGroup {
  const CharacterGroup({
    required this.id,
    required this.name,
    this.characters = const <GameCharacter>[],
    this.enabled = true,
  });

  final String id;
  final String name;
  final List<GameCharacter> characters;
  final bool enabled;

  /// Characters that actually take part in the shortcut resolution.
  Iterable<GameCharacter> get liveCharacters =>
      enabled ? characters.where((c) => c.enabled && c.isBound) : const [];

  int get enabledCount => characters.where((c) => c.enabled).length;

  CharacterGroup copyWith({
    String? name,
    List<GameCharacter>? characters,
    bool? enabled,
  }) {
    return CharacterGroup(
      id: id,
      name: name ?? this.name,
      characters: characters ?? this.characters,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'characters': characters.map((c) => c.toJson()).toList(),
      };

  static CharacterGroup? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    final rawCharacters = json['characters'];
    final characters = <GameCharacter>[];
    if (rawCharacters is List) {
      for (final entry in rawCharacters) {
        final character = GameCharacter.fromJson(entry);
        if (character != null) {
          characters.add(character);
        }
      }
    }
    return CharacterGroup(
      id: id,
      name: name,
      characters: characters,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }
}
