import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One shortcut and the window titles it may activate, ordered by priority.
@immutable
class NativeBinding {
  const NativeBinding({
    required this.id,
    required this.modifiers,
    required this.keyCode,
    required this.targets,
  });

  /// Shortcut signature, or an application command identifier.
  final String id;
  final int modifiers;
  final int keyCode;

  /// Window title fragments. Empty for application commands.
  final List<String> targets;

  Map<String, Object?> toMap() => {
        'id': id,
        'modifiers': modifiers,
        'keyCode': keyCode,
        'targets': targets,
      };
}

/// Dart facade over the native shortcut engine.
///
/// Only the configuration crosses the channel. The key press itself is handled
/// natively, so the activation latency does not depend on the Dart isolate.
class NativeBridge {
  NativeBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('dofus_organizer/native');

  final MethodChannel _channel;

  /// Fired after a shortcut activated a window. The index is the position of
  /// the matched target, or -1 when no window was found.
  void Function(String id, int targetIndex)? onHotkey;

  /// Fired when a second process tried to start.
  void Function()? onSecondInstance;

  void listen() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onHotkey':
          final arguments = call.arguments;
          if (arguments is Map) {
            final id = arguments['id'];
            final index = arguments['targetIndex'];
            if (id is String) {
              onHotkey?.call(id, index is int ? index : -1);
            }
          }
        case 'onSecondInstance':
          onSecondInstance?.call();
      }
      return null;
    });
  }

  /// Replaces the whole shortcut set. Returns the identifiers Windows refused,
  /// typically because the key is already owned by another application.
  Future<Set<String>> applyBindings(List<NativeBinding> bindings) async {
    final rejected = await _channel.invokeListMethod<String>(
      'hotkeys.apply',
      bindings.map((binding) => binding.toMap()).toList(),
    );
    return rejected?.toSet() ?? <String>{};
  }

  /// Releases the shortcuts so that the keys reach the focused application,
  /// which is required while the user records a new shortcut.
  Future<void> setSuspended({required bool suspended}) {
    return _channel.invokeMethod<void>('hotkeys.setSuspended', suspended);
  }

  /// Activates the first window whose title contains [title]. Used by the
  /// per character test button.
  Future<bool> focusWindow(String title) async {
    final found = await _channel.invokeMethod<bool>('window.focus', title);
    return found ?? false;
  }

  /// Resolves the virtual key producing [character] on the current keyboard
  /// layout. Returns 0 when the character needs more than one key. Used for
  /// the punctuation keys, whose codes are layout dependent.
  Future<int> virtualKeyForCharacter(String character) async {
    final keyCode = await _channel.invokeMethod<int>(
      'keys.virtualKeyForCharacter',
      character,
    );
    return keyCode ?? 0;
  }

  /// Tells the runner whether the window must stay hidden when the first
  /// frame is rendered. Must be called before `runApp`.
  Future<void> setStartHidden({required bool hidden}) {
    return _channel.invokeMethod<void>('window.setStartHidden', hidden);
  }

  /// Whether the process was launched with the minimized flag.
  Future<bool> startedHidden() async {
    final hidden = await _channel.invokeMethod<bool>('app.startedHidden');
    return hidden ?? false;
  }

  Future<bool> isLaunchAtStartupEnabled() async {
    final enabled = await _channel.invokeMethod<bool>('startup.isEnabled');
    return enabled ?? false;
  }

  Future<bool> setLaunchAtStartup({required bool enabled}) async {
    try {
      final applied =
          await _channel.invokeMethod<bool>('startup.setEnabled', enabled);
      return applied ?? false;
    } on PlatformException catch (error) {
      debugPrint('Démarrage automatique refusé: ${error.message}');
      // The registry write failed: report the state actually in place.
      return isLaunchAtStartupEnabled();
    }
  }
}
