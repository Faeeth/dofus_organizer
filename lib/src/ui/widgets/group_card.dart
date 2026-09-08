import 'package:flutter/material.dart';

import '../../models/character_group.dart';
import '../../models/game_character.dart';
import '../../state/organizer_controller.dart';
import '../theme.dart';
import 'character_editor_dialog.dart';
import 'shortcut_badge.dart';
import 'shortcut_recorder_dialog.dart';

/// One team: a header driving the whole group and the list of its characters.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.controller,
    required this.group,
    required this.dragIndex,
  });

  final OrganizerController controller;
  final CharacterGroup group;
  final int dragIndex;

  @override
  Widget build(BuildContext context) {
    final enabled = group.enabled;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: enabled ? AppColors.outline : AppColors.outline.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GroupHeader(
            controller: controller,
            group: group,
            dragIndex: dragIndex,
          ),
          if (group.characters.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Text(
                'Aucun personnage dans cette équipe.',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: group.characters.length,
              onReorderItem: (oldIndex, newIndex) =>
                  controller.reorderCharacters(group.id, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final character = group.characters[index];
                return CharacterRow(
                  key: ValueKey(character.id),
                  controller: controller,
                  group: group,
                  character: character,
                  dragIndex: index,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.controller,
    required this.group,
    required this.dragIndex,
  });

  final OrganizerController controller;
  final CharacterGroup group;
  final int dragIndex;

  Future<void> _rename(BuildContext context) async {
    final name = await promptForName(context, 'Renommer l\'équipe', group.name);
    if (name != null) {
      controller.renameGroup(group.id, name);
    }
  }

  Future<void> _addCharacter(BuildContext context) async {
    final draft = await CharacterEditorDialog.show(
      context,
      controller: controller,
    );
    if (draft == null) return;
    controller.addCharacter(
      group.id,
      name: draft.name,
      windowTitle: draft.windowTitle,
      shortcut: draft.shortcut,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'équipe', style: TextStyle(fontSize: 17)),
        content: Text(
          '« ${group.name} » et ses ${group.characters.length} personnage(s) '
          'seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      controller.removeGroup(group.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveCount = group.liveCharacters.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: dragIndex,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.drag_indicator,
                  size: 18, color: AppColors.textDisabled),
            ),
          ),
          Switch(
            value: group.enabled,
            onChanged: (value) => controller.setGroupEnabled(group.id, value),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: group.enabled
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  group.enabled
                      ? '$liveCount raccourci(s) actif(s) sur '
                          '${group.characters.length} personnage(s)'
                      : 'Équipe désactivée',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Activer uniquement cette équipe',
            child: IconButton(
              onPressed: () => controller.soloGroup(group.id),
              icon: const Icon(Icons.bolt, size: 18),
              color: AppColors.textSecondary,
            ),
          ),
          Tooltip(
            message: 'Ajouter un personnage',
            child: IconButton(
              onPressed: () => _addCharacter(context),
              icon: const Icon(Icons.person_add_alt, size: 18),
              color: AppColors.textSecondary,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                size: 18, color: AppColors.textSecondary),
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  _rename(context);
                case 'delete':
                  _confirmDelete(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Renommer')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    );
  }
}

/// One character line: activation, identity, shortcut and actions.
class CharacterRow extends StatelessWidget {
  const CharacterRow({
    super.key,
    required this.controller,
    required this.group,
    required this.character,
    required this.dragIndex,
  });

  final OrganizerController controller;
  final CharacterGroup group;
  final GameCharacter character;
  final int dragIndex;

  bool get _live => group.enabled && character.enabled;

  Future<void> _edit(BuildContext context) async {
    final draft = await CharacterEditorDialog.show(
      context,
      controller: controller,
      character: character,
    );
    if (draft == null) return;
    controller.updateCharacter(
      group.id,
      character.id,
      name: draft.name,
      windowTitle: draft.windowTitle,
      shortcut: draft.shortcut,
      clearShortcut: draft.shortcut == null,
    );
  }

  Future<void> _pickShortcut(BuildContext context) async {
    final result = await ShortcutRecorderDialog.show(
      context,
      controller: controller,
      title: 'Raccourci de ${character.name}',
      initial: character.shortcut,
    );
    if (result == null) return;
    controller.updateCharacter(
      group.id,
      character.id,
      shortcut: result.shortcut,
      clearShortcut: result.shortcut == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trigger = controller.lastTrigger;
    final highlighted = trigger != null &&
        trigger.characterId == character.id &&
        DateTime.now().difference(trigger.at) < const Duration(seconds: 2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => controller.setCharacterEnabled(
            group.id,
            character.id,
            !character.enabled,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: dragIndex,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.drag_handle,
                        size: 16, color: AppColors.textDisabled),
                  ),
                ),
                _ActiveDot(
                  active: character.enabled,
                  live: _live,
                  onTap: () => controller.setCharacterEnabled(
                    group.id,
                    character.id,
                    !character.enabled,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: _live
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '« ${character.windowTitle} »',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ShortcutBadge(
                  shortcut: character.shortcut,
                  dimmed: !_live,
                  conflicting: controller.isConflicting(character),
                  highlighted: highlighted,
                  onTap: () => _pickShortcut(context),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz,
                      size: 18, color: AppColors.textSecondary),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _edit(context);
                      case 'delete':
                        controller.removeCharacter(group.id, character.id);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot({
    required this.active,
    required this.live,
    required this.onTap,
  });

  final bool active;

  /// The character is enabled and its group too.
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = live
        ? AppColors.live
        : (active ? AppColors.textSecondary : AppColors.textDisabled);
    return Tooltip(
      message: active ? 'Désactiver le personnage' : 'Activer le personnage',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small prompt reused for group creation and renaming.
Future<String?> promptForName(
  BuildContext context,
  String title, [
  String initial = '',
]) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) {
      void submit() {
        final value = controller.text.trim();
        if (value.isNotEmpty) {
          Navigator.of(context).pop(value);
        }
      }

      return AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 17)),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom'),
            onSubmitted: (_) => submit(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(onPressed: submit, child: const Text('Valider')),
        ],
      );
    },
  );
}
