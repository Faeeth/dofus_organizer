import 'dart:io';

import 'package:dofus_organizer/src/models/shortcut.dart';
import 'package:dofus_organizer/src/services/config_store.dart';
import 'package:dofus_organizer/src/services/native_bridge.dart';
import 'package:dofus_organizer/src/state/organizer_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures what the controller pushes down to the native shortcut engine.
class _RecordingBridge extends NativeBridge {
  _RecordingBridge() : super(channel: const MethodChannel('test/native'));

  List<NativeBinding> lastBindings = const <NativeBinding>[];
  Set<String> rejected = <String>{};

  @override
  void listen() {}

  @override
  Future<Set<String>> applyBindings(List<NativeBinding> bindings) async {
    lastBindings = bindings;
    return rejected;
  }

  @override
  Future<bool> isLaunchAtStartupEnabled() async => false;

  @override
  Future<void> setSuspended({required bool suspended}) async {}

  @override
  Future<int> virtualKeyForCharacter(String character) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporary;
  late _RecordingBridge bridge;
  late OrganizerController controller;

  const f1 = Shortcut(keyCode: 0x70);
  const f2 = Shortcut(keyCode: 0x71);

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('dofus_organizer_test');
    bridge = _RecordingBridge();
    controller = OrganizerController(
      store: ConfigStore(directory: temporary),
      native: bridge,
    );
    await controller.initialize();
  });

  tearDown(() async {
    // Drain the debounced write before the directory disappears.
    await controller.flush();
    controller.dispose();
    if (temporary.existsSync()) {
      await temporary.delete(recursive: true);
    }
  });

  /// Waits for the asynchronous binding synchronisation triggered by mutations.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('only characters of an enabled group are pushed natively', () async {
    final team = controller.addGroup('Team');
    controller.addCharacter(team.id, name: 'A', windowTitle: 'A', shortcut: f1);
    await settle();
    expect(bridge.lastBindings, hasLength(1));

    controller.setGroupEnabled(team.id, false);
    await settle();
    expect(bridge.lastBindings, isEmpty);
  });

  test('a disabled character leaves the binding set', () async {
    final team = controller.addGroup('Team');
    final character =
        controller.addCharacter(team.id, name: 'A', windowTitle: 'A', shortcut: f1);
    controller.addCharacter(team.id, name: 'B', windowTitle: 'B', shortcut: f2);
    await settle();
    expect(bridge.lastBindings, hasLength(2));

    controller.setCharacterEnabled(team.id, character.id, false);
    await settle();
    expect(bridge.lastBindings, hasLength(1));
    expect(bridge.lastBindings.single.targets, ['B']);
  });

  test('characters sharing a shortcut are merged into one ordered binding',
      () async {
    final first = controller.addGroup('Team 1');
    final second = controller.addGroup('Team 2');
    controller.addCharacter(first.id,
        name: 'Kaska', windowTitle: 'Kaska', shortcut: f1);
    controller.addCharacter(second.id,
        name: 'Alt', windowTitle: 'Alt', shortcut: f1);
    await settle();

    expect(bridge.lastBindings, hasLength(1));
    // Group order drives the resolution priority.
    expect(bridge.lastBindings.single.targets, ['Kaska', 'Alt']);
    expect(bridge.lastBindings.single.keyCode, f1.keyCode);
  });

  test('solo keeps a single team live', () async {
    final first = controller.addGroup('Team 1');
    final second = controller.addGroup('Team 2');
    controller.addCharacter(first.id, name: 'A', windowTitle: 'A', shortcut: f1);
    controller.addCharacter(second.id, name: 'B', windowTitle: 'B', shortcut: f1);

    controller.soloGroup(second.id);
    await settle();
    expect(bridge.lastBindings.single.targets, ['B']);
  });

  test('unbound characters are not registered', () async {
    final team = controller.addGroup('Team');
    controller.addCharacter(team.id, name: 'A', windowTitle: 'A');
    await settle();
    expect(bridge.lastBindings, isEmpty);
  });

  test('a rejected signature marks its characters as conflicting', () async {
    final team = controller.addGroup('Team');
    final character =
        controller.addCharacter(team.id, name: 'A', windowTitle: 'A', shortcut: f1);
    bridge.rejected = {f1.signature};
    controller.setCharacterEnabled(team.id, character.id, true);
    await settle();

    final stored = controller.groups.single.characters.single;
    expect(controller.isConflicting(stored), isTrue);
    expect(controller.activeShortcutCount, 0);
  });

  test('the class portrait survives a reload', () async {
    final team = controller.addGroup('Team');
    controller.addCharacter(team.id,
        name: 'A', windowTitle: 'A', shortcut: f1, classIcon: 'iop_m');
    await controller.flush();

    final reloaded = OrganizerController(
      store: ConfigStore(directory: temporary),
      native: _RecordingBridge(),
    );
    await reloaded.initialize();

    expect(reloaded.groups.single.characters.single.classIcon, 'iop_m');
    await reloaded.flush();
    reloaded.dispose();
  });

  test('a recorded key label survives a reload', () async {
    // VK_OEM_1 produces different characters depending on the layout.
    const layoutDependent = Shortcut(keyCode: 0xBA, modifiers: 0, keyName: '\$');
    final team = controller.addGroup('Team');
    controller.addCharacter(team.id,
        name: 'A', windowTitle: 'A', shortcut: layoutDependent);
    await controller.flush();

    final reloaded = OrganizerController(
      store: ConfigStore(directory: temporary),
      native: _RecordingBridge(),
    );
    await reloaded.initialize();

    final stored = reloaded.groups.single.characters.single.shortcut!;
    expect(stored.keyCode, 0xBA);
    expect(stored.keyLabel, '\$');
    await reloaded.flush();
    reloaded.dispose();
  });

  test('a configuration saved with a byte order mark still loads', () async {
    final store = ConfigStore(directory: temporary);
    await store.file.writeAsString(
      '﻿{"version":1,"groups":[{"id":"g","name":"Kaska",'
      '"enabled":true,"characters":[]}]}',
    );

    final loaded = OrganizerController(
      store: store,
      native: _RecordingBridge(),
    );
    await loaded.initialize();

    expect(loaded.groups.single.name, 'Kaska');
    await loaded.flush();
    loaded.dispose();
  });

  test('configuration survives a reload', () async {
    final team = controller.addGroup('Kaska');
    controller.addCharacter(team.id,
        name: 'Kaska-yopette', windowTitle: 'Kaska-yopette', shortcut: f1);
    controller.setGroupEnabled(team.id, false);
    await controller.flush();

    final reloaded = OrganizerController(
      store: ConfigStore(directory: temporary),
      native: _RecordingBridge(),
    );
    await reloaded.initialize();

    expect(reloaded.groups, hasLength(1));
    expect(reloaded.groups.single.name, 'Kaska');
    expect(reloaded.groups.single.enabled, isFalse);
    expect(reloaded.groups.single.characters.single.shortcut, f1);
    await reloaded.flush();
    reloaded.dispose();
  });
}
