import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/character_group.dart';
import '../models/game_character.dart';
import '../models/organizer_config.dart';
import '../models/shortcut.dart';
import '../services/config_store.dart';
import '../services/native_bridge.dart';

/// Identifiers of the shortcuts that drive the application itself instead of
/// activating a game window.
abstract final class AppCommand {
  static const String quit = 'app:quit';
  static const String showWindow = 'app:show';
}

/// Result of the last activation, used to give feedback in the interface.
@immutable
class TriggerFeedback {
  const TriggerFeedback({
    required this.characterId,
    required this.matched,
    required this.at,
  });

  final String? characterId;
  final bool matched;
  final DateTime at;
}

/// Owns the configuration and keeps the native shortcut set in sync with it.
class OrganizerController extends ChangeNotifier {
  OrganizerController({
    required ConfigStore store,
    required NativeBridge native,
  })  : _store = store,
        _native = native;

  final ConfigStore _store;
  final NativeBridge _native;
  final Random _random = Random();

  OrganizerConfig _config = const OrganizerConfig();
  Set<String> _rejectedSignatures = <String>{};
  TriggerFeedback? _lastTrigger;
  bool _recording = false;

  /// Invoked when the quit shortcut fires or the tray asks for a shutdown.
  Future<void> Function()? onQuitRequested;

  /// Invoked when the window must come back to the foreground.
  Future<void> Function()? onShowRequested;

  List<CharacterGroup> get groups => _config.groups;
  AppSettings get settings => _config.settings;
  TriggerFeedback? get lastTrigger => _lastTrigger;

  /// True while the user is recording a shortcut: the global shortcuts are
  /// released so that the keys reach the recorder.
  bool get isRecording => _recording;

  /// Number of shortcuts currently registered in Windows.
  int get activeShortcutCount => _buildBindings()
      .where((binding) => !_rejectedSignatures.contains(binding.id))
      .length;

  /// Whether Windows refused the shortcut of [character], typically because
  /// another application already owns it.
  bool isConflicting(GameCharacter character) {
    final shortcut = character.shortcut;
    return shortcut != null &&
        _rejectedSignatures.contains(shortcut.signature);
  }

  /// Application commands are registered under their own identifier, not under
  /// a shortcut signature.
  bool get isQuitShortcutRejected =>
      _rejectedSignatures.contains(AppCommand.quit);

  bool get isShowWindowShortcutRejected =>
      _rejectedSignatures.contains(AppCommand.showWindow);

  int get rejectedShortcutCount => _rejectedSignatures.length;

  bool get hasConflicts => _rejectedSignatures.isNotEmpty;

  Future<void> initialize() async {
    _config = await _store.load();
    _native
      ..onHotkey = _handleHotkey
      ..onSecondInstance = () => unawaited(_requestShow());
    _native.listen();
    _config = _config.copyWith(
      settings: _config.settings.copyWith(
        launchAtStartup: await _native.isLaunchAtStartupEnabled(),
      ),
    );
    notifyListeners();
    await _syncBindings();
  }

  // --- Groups ------------------------------------------------------------

  CharacterGroup addGroup(String name) {
    final group = CharacterGroup(id: _newId(), name: name);
    _update(_config.copyWith(groups: [..._config.groups, group]));
    return group;
  }

  void renameGroup(String groupId, String name) {
    _mapGroup(groupId, (group) => group.copyWith(name: name));
  }

  void setGroupEnabled(String groupId, bool enabled) {
    _mapGroup(groupId, (group) => group.copyWith(enabled: enabled));
  }

  void removeGroup(String groupId) {
    _update(_config.copyWith(
      groups: _config.groups.where((group) => group.id != groupId).toList(),
    ));
  }

  /// Enables [groupId] and disables every other group. Switching team is the
  /// most frequent operation, so it gets a single call.
  void soloGroup(String groupId) {
    _update(_config.copyWith(
      groups: _config.groups
          .map((group) => group.copyWith(enabled: group.id == groupId))
          .toList(),
    ));
  }

  /// [newIndex] is the final position, already adjusted for the removal.
  void reorderGroups(int oldIndex, int newIndex) {
    final groups = [..._config.groups];
    if (oldIndex < 0 || oldIndex >= groups.length) return;
    groups.insert(newIndex.clamp(0, groups.length - 1), groups.removeAt(oldIndex));
    _update(_config.copyWith(groups: groups));
  }

  // --- Characters --------------------------------------------------------

  GameCharacter addCharacter(
    String groupId, {
    required String name,
    required String windowTitle,
    Shortcut? shortcut,
  }) {
    final character = GameCharacter(
      id: _newId(),
      name: name,
      windowTitle: windowTitle,
      shortcut: shortcut,
    );
    _mapGroup(
      groupId,
      (group) => group.copyWith(characters: [...group.characters, character]),
    );
    return character;
  }

  void updateCharacter(
    String groupId,
    String characterId, {
    String? name,
    String? windowTitle,
    Shortcut? shortcut,
    bool clearShortcut = false,
    bool? enabled,
  }) {
    _mapCharacter(
      groupId,
      characterId,
      (character) => character.copyWith(
        name: name,
        windowTitle: windowTitle,
        shortcut: shortcut,
        clearShortcut: clearShortcut,
        enabled: enabled,
      ),
    );
  }

  void setCharacterEnabled(String groupId, String characterId, bool enabled) {
    _mapCharacter(
      groupId,
      characterId,
      (character) => character.copyWith(enabled: enabled),
    );
  }

  void removeCharacter(String groupId, String characterId) {
    _mapGroup(
      groupId,
      (group) => group.copyWith(
        characters:
            group.characters.where((c) => c.id != characterId).toList(),
      ),
    );
  }

  /// Character order is the resolution priority when several of them share a
  /// shortcut. [newIndex] is the final position, already adjusted.
  void reorderCharacters(String groupId, int oldIndex, int newIndex) {
    _mapGroup(groupId, (group) {
      final characters = [...group.characters];
      if (oldIndex < 0 || oldIndex >= characters.length) return group;
      characters.insert(
        newIndex.clamp(0, characters.length - 1),
        characters.removeAt(oldIndex),
      );
      return group.copyWith(characters: characters);
    });
  }

  // --- Settings ----------------------------------------------------------

  void setCloseToTray(bool value) {
    _update(_config.copyWith(
      settings: _config.settings.copyWith(closeToTray: value),
    ));
  }

  void setStartMinimized(bool value) {
    _update(_config.copyWith(
      settings: _config.settings.copyWith(startMinimized: value),
    ));
  }

  Future<void> setLaunchAtStartup(bool value) async {
    final applied = await _native.setLaunchAtStartup(enabled: value);
    _update(_config.copyWith(
      settings: _config.settings.copyWith(launchAtStartup: applied),
    ));
  }

  void setQuitShortcut(Shortcut? shortcut) {
    _update(_config.copyWith(
      settings: _config.settings.copyWith(
        quitShortcut: shortcut,
        clearQuitShortcut: shortcut == null,
      ),
    ));
  }

  void setShowWindowShortcut(Shortcut? shortcut) {
    _update(_config.copyWith(
      settings: _config.settings.copyWith(
        showWindowShortcut: shortcut,
        clearShowWindowShortcut: shortcut == null,
      ),
    ));
  }

  // --- Shortcut recording ------------------------------------------------

  /// Releases the global shortcuts while the user presses the keys to record.
  Future<void> beginRecording() async {
    if (_recording) return;
    _recording = true;
    notifyListeners();
    await _native.setSuspended(suspended: true);
  }

  Future<void> endRecording() async {
    if (!_recording) return;
    _recording = false;
    notifyListeners();
    await _native.setSuspended(suspended: false);
  }

  /// Resolves a virtual key from the character a key produces, for the keys
  /// whose code depends on the keyboard layout.
  Future<int> virtualKeyForCharacter(String character) =>
      _native.virtualKeyForCharacter(character);

  /// Activates the window of [character] without going through its shortcut.
  Future<bool> testCharacter(GameCharacter character) {
    return _native.focusWindow(character.windowTitle);
  }

  /// Writes any pending configuration to disk, before quitting.
  Future<void> flush() => _store.flush();

  @override
  void dispose() {
    unawaited(_store.flush());
    super.dispose();
  }

  // --- Internals ---------------------------------------------------------

  void _handleHotkey(String id, int targetIndex) {
    switch (id) {
      case AppCommand.quit:
        unawaited(onQuitRequested?.call() ?? Future<void>.value());
        return;
      case AppCommand.showWindow:
        unawaited(_requestShow());
        return;
    }
    final characters = _liveCharactersBySignature()[id] ?? const [];
    final matched = targetIndex >= 0 && targetIndex < characters.length;
    _lastTrigger = TriggerFeedback(
      characterId: matched ? characters[targetIndex].id : null,
      matched: matched,
      at: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> _requestShow() async {
    await onShowRequested?.call();
  }

  /// Groups the live characters by shortcut signature, keeping the group then
  /// character declaration order as the resolution priority.
  Map<String, List<GameCharacter>> _liveCharactersBySignature() {
    final bySignature = <String, List<GameCharacter>>{};
    for (final group in _config.groups) {
      for (final character in group.liveCharacters) {
        bySignature
            .putIfAbsent(character.shortcut!.signature, () => <GameCharacter>[])
            .add(character);
      }
    }
    return bySignature;
  }

  List<NativeBinding> _buildBindings() {
    final bindings = <NativeBinding>[];
    _liveCharactersBySignature().forEach((signature, characters) {
      final shortcut = characters.first.shortcut!;
      bindings.add(NativeBinding(
        id: signature,
        modifiers: shortcut.modifiers,
        keyCode: shortcut.keyCode,
        targets: characters.map((c) => c.windowTitle).toList(),
      ));
    });

    final quit = _config.settings.quitShortcut;
    if (quit != null && quit.isValid) {
      bindings.add(NativeBinding(
        id: AppCommand.quit,
        modifiers: quit.modifiers,
        keyCode: quit.keyCode,
        targets: const <String>[],
      ));
    }
    final show = _config.settings.showWindowShortcut;
    if (show != null && show.isValid) {
      bindings.add(NativeBinding(
        id: AppCommand.showWindow,
        modifiers: show.modifiers,
        keyCode: show.keyCode,
        targets: const <String>[],
      ));
    }
    return bindings;
  }

  Future<void> _syncBindings() async {
    if (_recording) return;
    final rejected = await _native.applyBindings(_buildBindings());
    if (!setEquals(rejected, _rejectedSignatures)) {
      _rejectedSignatures = rejected;
      notifyListeners();
    }
  }

  void _update(OrganizerConfig config) {
    _config = config;
    notifyListeners();
    _store.save(config);
    unawaited(_syncBindings());
  }

  void _mapGroup(String groupId, CharacterGroup Function(CharacterGroup) map) {
    _update(_config.copyWith(
      groups: _config.groups
          .map((group) => group.id == groupId ? map(group) : group)
          .toList(),
    ));
  }

  void _mapCharacter(
    String groupId,
    String characterId,
    GameCharacter Function(GameCharacter) map,
  ) {
    _mapGroup(
      groupId,
      (group) => group.copyWith(
        characters: group.characters
            .map((c) => c.id == characterId ? map(c) : c)
            .toList(),
      ),
    );
  }

  String _newId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${timestamp.toRadixString(36)}${_random.nextInt(0xFFFF).toRadixString(36)}';
  }
}

