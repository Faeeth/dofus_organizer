import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/shortcut.dart';
import '../../state/organizer_controller.dart';
import '../theme.dart';
import 'shortcut_badge.dart';

/// Outcome of the recorder: [shortcut] is null when the user cleared the
/// binding. A null result from the dialog itself means the user cancelled.
class ShortcutRecorderResult {
  const ShortcutRecorderResult(this.shortcut);

  final Shortcut? shortcut;
}

/// Captures a key combination for a global shortcut.
///
/// The global shortcuts are released while the dialog is open, otherwise
/// Windows would swallow the keys already registered instead of delivering
/// them to the recorder.
class ShortcutRecorderDialog extends StatefulWidget {
  const ShortcutRecorderDialog({
    super.key,
    required this.controller,
    required this.title,
    this.initial,
  });

  final OrganizerController controller;
  final String title;
  final Shortcut? initial;

  static Future<ShortcutRecorderResult?> show(
    BuildContext context, {
    required OrganizerController controller,
    required String title,
    Shortcut? initial,
  }) {
    return showDialog<ShortcutRecorderResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShortcutRecorderDialog(
        controller: controller,
        title: title,
        initial: initial,
      ),
    );
  }

  @override
  State<ShortcutRecorderDialog> createState() => _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<ShortcutRecorderDialog> {
  final FocusNode _focusNode = FocusNode();
  Shortcut? _captured;
  String? _error;

  @override
  void initState() {
    super.initState();
    _captured = widget.initial;
    widget.controller.beginRecording();
  }

  @override
  void dispose() {
    widget.controller.endRecording();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (isModifierKey(key)) {
      return KeyEventResult.handled;
    }
    final keyCode = virtualKeyForLogicalKey(key);
    if (keyCode == null) {
      setState(() => _error = 'Cette touche ne peut pas servir de raccourci.');
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    var modifiers = 0;
    if (keyboard.isControlPressed) modifiers |= HotkeyModifier.control;
    if (keyboard.isAltPressed) modifiers |= HotkeyModifier.alt;
    if (keyboard.isShiftPressed) modifiers |= HotkeyModifier.shift;
    if (keyboard.isMetaPressed) modifiers |= HotkeyModifier.win;
    setState(() {
      _captured = Shortcut(keyCode: keyCode, modifiers: modifiers);
      _error = null;
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 17)),
      content: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Appuyez sur la combinaison à assigner.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: ShortcutBadge(shortcut: _captured),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Échap pour annuler. Les raccourcis globaux sont suspendus '
                'pendant la capture.',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(const ShortcutRecorderResult(null)),
          child: const Text('Effacer'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _captured == null
              ? null
              : () => Navigator.of(context)
                  .pop(ShortcutRecorderResult(_captured)),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
