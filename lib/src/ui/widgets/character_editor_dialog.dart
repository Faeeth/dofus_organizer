import 'package:flutter/material.dart';

import '../../models/game_character.dart';
import '../../models/shortcut.dart';
import '../../state/organizer_controller.dart';
import '../theme.dart';
import 'shortcut_badge.dart';
import 'shortcut_recorder_dialog.dart';

/// Values produced by the character editor.
class CharacterDraft {
  const CharacterDraft({
    required this.name,
    required this.windowTitle,
    required this.shortcut,
  });

  final String name;
  final String windowTitle;
  final Shortcut? shortcut;
}

/// Creates or edits a character: display name, window title fragment and
/// shortcut.
class CharacterEditorDialog extends StatefulWidget {
  const CharacterEditorDialog({
    super.key,
    required this.controller,
    this.character,
  });

  final OrganizerController controller;
  final GameCharacter? character;

  static Future<CharacterDraft?> show(
    BuildContext context, {
    required OrganizerController controller,
    GameCharacter? character,
  }) {
    return showDialog<CharacterDraft>(
      context: context,
      builder: (context) => CharacterEditorDialog(
        controller: controller,
        character: character,
      ),
    );
  }

  @override
  State<CharacterEditorDialog> createState() => _CharacterEditorDialogState();
}

class _CharacterEditorDialogState extends State<CharacterEditorDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.character?.name ?? '');
  late final TextEditingController _windowTitle =
      TextEditingController(text: widget.character?.windowTitle ?? '');
  late Shortcut? _shortcut = widget.character?.shortcut;

  /// True while the user has not typed a window title: it then mirrors the
  /// name, which is what the client shows in most setups.
  late bool _titleFollowsName = widget.character == null;

  String? _testResult;

  @override
  void dispose() {
    _name.dispose();
    _windowTitle.dispose();
    super.dispose();
  }

  String get _effectiveTitle {
    final title = _windowTitle.text.trim();
    return title.isEmpty ? _name.text.trim() : title;
  }

  Future<void> _pickShortcut() async {
    final result = await ShortcutRecorderDialog.show(
      context,
      controller: widget.controller,
      title: 'Raccourci de ${_name.text.trim().isEmpty ? "ce personnage" : _name.text.trim()}',
      initial: _shortcut,
    );
    if (result == null || !mounted) return;
    setState(() => _shortcut = result.shortcut);
  }

  Future<void> _test() async {
    final title = _effectiveTitle;
    if (title.isEmpty) return;
    final found = await widget.controller.testCharacter(
      GameCharacter(id: 'test', name: title, windowTitle: title),
    );
    if (!mounted) return;
    setState(() {
      _testResult = found
          ? 'Fenêtre trouvée et activée.'
          : 'Aucune fenêtre ne contient « $title ».';
    });
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(CharacterDraft(
      name: name,
      windowTitle: _effectiveTitle,
      shortcut: _shortcut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.character == null;
    return AlertDialog(
      title: Text(
        isNew ? 'Nouveau personnage' : 'Modifier le personnage',
        style: const TextStyle(fontSize: 17),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nom'),
              onChanged: (value) {
                if (_titleFollowsName) {
                  _windowTitle.text = value;
                }
                setState(() {});
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _windowTitle,
              decoration: const InputDecoration(
                labelText: 'Fragment du titre de la fenêtre',
                helperText:
                    'Recherché sans tenir compte de la casse, comme dans le script AutoHotkey.',
                helperMaxLines: 2,
              ),
              onChanged: (value) {
                _titleFollowsName = value.trim().isEmpty;
                setState(() {});
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'Raccourci',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(width: 14),
                ShortcutBadge(shortcut: _shortcut, onTap: _pickShortcut),
                const Spacer(),
                TextButton.icon(
                  onPressed: _effectiveTitle.isEmpty ? null : _test,
                  icon: const Icon(Icons.center_focus_strong, size: 16),
                  label: const Text('Tester'),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 8),
              Text(
                _testResult!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: Text(isNew ? 'Ajouter' : 'Enregistrer'),
        ),
      ],
    );
  }
}
