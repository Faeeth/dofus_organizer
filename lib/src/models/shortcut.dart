import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Windows `MOD_*` flags accepted by `RegisterHotKey`.
abstract final class HotkeyModifier {
  static const int alt = 0x0001;
  static const int control = 0x0002;
  static const int shift = 0x0004;
  static const int win = 0x0008;
}

/// A global shortcut expressed with the Win32 vocabulary, so that it can be
/// handed to `RegisterHotKey` without any further translation.
@immutable
class Shortcut {
  const Shortcut({required this.keyCode, this.modifiers = 0, this.keyName});

  /// Virtual key code (`VK_*`).
  final int keyCode;

  /// Bitmask of [HotkeyModifier] values.
  final int modifiers;

  /// Label captured while recording. Virtual key codes of punctuation keys
  /// depend on the keyboard layout, so the key as the user saw it is stored
  /// rather than guessed back from the code.
  final String? keyName;

  /// Identifier shared by every character bound to the same keys. The native
  /// side registers one shortcut per signature, not one per character.
  String get signature => '$modifiers:$keyCode';

  bool get isValid => keyCode != 0;

  String get label {
    final parts = <String>[
      if (modifiers & HotkeyModifier.control != 0) 'Ctrl',
      if (modifiers & HotkeyModifier.alt != 0) 'Alt',
      if (modifiers & HotkeyModifier.shift != 0) 'Maj',
      if (modifiers & HotkeyModifier.win != 0) 'Win',
      keyLabel,
    ];
    return parts.join(' + ');
  }

  String get keyLabel {
    final captured = keyName;
    if (captured != null && captured.isNotEmpty) return captured;
    return virtualKeyLabel(keyCode);
  }

  Map<String, Object?> toJson() => {
        'keyCode': keyCode,
        'modifiers': modifiers,
        if (keyName != null) 'keyName': keyName,
      };

  static Shortcut? fromJson(Object? json) {
    if (json is! Map) return null;
    final keyCode = json['keyCode'];
    if (keyCode is! int || keyCode == 0) return null;
    final modifiers = json['modifiers'];
    final keyName = json['keyName'];
    return Shortcut(
      keyCode: keyCode,
      modifiers: modifiers is int ? modifiers : 0,
      keyName: keyName is String && keyName.isNotEmpty ? keyName : null,
    );
  }

  /// Equality ignores [keyName]: what identifies a shortcut is what gets
  /// registered in Windows.
  @override
  bool operator ==(Object other) =>
      other is Shortcut &&
      other.keyCode == keyCode &&
      other.modifiers == modifiers;

  @override
  int get hashCode => Object.hash(keyCode, modifiers);

  @override
  String toString() => label;
}

/// Virtual key codes for the non printable keys the recorder accepts.
/// Not a `const` map: `LogicalKeyboardKey` overrides `==`.
final Map<LogicalKeyboardKey, int> _explicitVirtualKeys =
    <LogicalKeyboardKey, int>{
  LogicalKeyboardKey.backspace: 0x08,
  LogicalKeyboardKey.tab: 0x09,
  LogicalKeyboardKey.enter: 0x0D,
  LogicalKeyboardKey.escape: 0x1B,
  LogicalKeyboardKey.space: 0x20,
  LogicalKeyboardKey.pageUp: 0x21,
  LogicalKeyboardKey.pageDown: 0x22,
  LogicalKeyboardKey.end: 0x23,
  LogicalKeyboardKey.home: 0x24,
  LogicalKeyboardKey.arrowLeft: 0x25,
  LogicalKeyboardKey.arrowUp: 0x26,
  LogicalKeyboardKey.arrowRight: 0x27,
  LogicalKeyboardKey.arrowDown: 0x28,
  LogicalKeyboardKey.insert: 0x2D,
  LogicalKeyboardKey.delete: 0x2E,
  LogicalKeyboardKey.pause: 0x13,
  LogicalKeyboardKey.capsLock: 0x14,
  LogicalKeyboardKey.printScreen: 0x2C,
  LogicalKeyboardKey.contextMenu: 0x5D,
  LogicalKeyboardKey.numLock: 0x90,
  LogicalKeyboardKey.scrollLock: 0x91,
  // The numeric keypad Enter shares VK_RETURN: Windows does not expose a
  // distinct virtual key for it.
  LogicalKeyboardKey.numpadEnter: 0x0D,
  LogicalKeyboardKey.browserBack: 0xA6,
  LogicalKeyboardKey.browserForward: 0xA7,
  LogicalKeyboardKey.browserRefresh: 0xA8,
  LogicalKeyboardKey.browserStop: 0xA9,
  LogicalKeyboardKey.browserSearch: 0xAA,
  LogicalKeyboardKey.browserFavorites: 0xAB,
  LogicalKeyboardKey.browserHome: 0xAC,
  LogicalKeyboardKey.audioVolumeMute: 0xAD,
  LogicalKeyboardKey.audioVolumeDown: 0xAE,
  LogicalKeyboardKey.audioVolumeUp: 0xAF,
  LogicalKeyboardKey.mediaTrackNext: 0xB0,
  LogicalKeyboardKey.mediaTrackPrevious: 0xB1,
  LogicalKeyboardKey.mediaStop: 0xB2,
  LogicalKeyboardKey.mediaPlayPause: 0xB3,
  LogicalKeyboardKey.numpadMultiply: 0x6A,
  LogicalKeyboardKey.numpadAdd: 0x6B,
  LogicalKeyboardKey.numpadSubtract: 0x6D,
  LogicalKeyboardKey.numpadDecimal: 0x6E,
  LogicalKeyboardKey.numpadDivide: 0x6F,
};

/// Labels of the virtual keys the recorder can produce.
const Map<int, String> _virtualKeyLabels = <int, String>{
  0x08: 'Retour',
  0x09: 'Tab',
  0x0D: 'Entrée',
  0x1B: 'Échap',
  0x20: 'Espace',
  0x21: 'Page haut',
  0x22: 'Page bas',
  0x23: 'Fin',
  0x24: 'Début',
  0x25: 'Gauche',
  0x26: 'Haut',
  0x27: 'Droite',
  0x28: 'Bas',
  0x2D: 'Inser',
  0x2E: 'Suppr',
  0x13: 'Pause',
  0x14: 'Verr maj',
  0x2C: 'Impr écran',
  0x5D: 'Menu',
  0x90: 'Verr num',
  0x91: 'Arrêt défil',
  0x6A: 'Num *',
  0x6B: 'Num +',
  0x6D: 'Num -',
  0x6E: 'Num .',
  0x6F: 'Num /',
};

/// Maps a Flutter logical key to its Win32 virtual key code, or null when the
/// key cannot be used as a global shortcut.
int? virtualKeyForLogicalKey(LogicalKeyboardKey key) {
  // Function keys: F1 is VK 0x70 and the range is contiguous on both sides.
  final functionIndex = _functionKeys.indexOf(key);
  if (functionIndex >= 0) {
    return 0x70 + functionIndex;
  }
  final numpadIndex = _numpadDigits.indexOf(key);
  if (numpadIndex >= 0) {
    return 0x60 + numpadIndex;
  }
  final explicit = _explicitVirtualKeys[key];
  if (explicit != null) {
    return explicit;
  }
  // Letters and digits: the virtual key code is the ASCII value of the
  // uppercase character the key produces on the current layout.
  final label = key.keyLabel;
  if (label.length == 1) {
    final code = label.codeUnitAt(0);
    final isLetter = code >= 0x41 && code <= 0x5A;
    final isDigit = code >= 0x30 && code <= 0x39;
    if (isLetter || isDigit) {
      return code;
    }
  }
  return null;
}

String virtualKeyLabel(int keyCode) {
  if (keyCode >= 0x70 && keyCode <= 0x87) {
    return 'F${keyCode - 0x6F}';
  }
  if (keyCode >= 0x60 && keyCode <= 0x69) {
    return 'Num ${keyCode - 0x60}';
  }
  if ((keyCode >= 0x41 && keyCode <= 0x5A) ||
      (keyCode >= 0x30 && keyCode <= 0x39)) {
    return String.fromCharCode(keyCode);
  }
  return _virtualKeyLabels[keyCode] ?? 'Touche $keyCode';
}

/// True when [key] only modifies another key and cannot be recorded alone.
bool isModifierKey(LogicalKeyboardKey key) => _modifierKeys.contains(key);

const List<LogicalKeyboardKey> _functionKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
  LogicalKeyboardKey.f13,
  LogicalKeyboardKey.f14,
  LogicalKeyboardKey.f15,
  LogicalKeyboardKey.f16,
  LogicalKeyboardKey.f17,
  LogicalKeyboardKey.f18,
  LogicalKeyboardKey.f19,
  LogicalKeyboardKey.f20,
  LogicalKeyboardKey.f21,
  LogicalKeyboardKey.f22,
  LogicalKeyboardKey.f23,
  LogicalKeyboardKey.f24,
];

const List<LogicalKeyboardKey> _numpadDigits = <LogicalKeyboardKey>[
  LogicalKeyboardKey.numpad0,
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

/// Not a `const` set: `LogicalKeyboardKey` overrides `==`.
final Set<LogicalKeyboardKey> _modifierKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
};
