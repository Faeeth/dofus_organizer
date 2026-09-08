import 'package:flutter/material.dart';

import '../models/game_character.dart';
import '../state/organizer_controller.dart';
import '../state/update_controller.dart';
import 'theme.dart';
import 'widgets/group_card.dart';
import 'widgets/settings_dialog.dart';
import 'widgets/update_dialog.dart';

/// Main screen: the teams, their characters and the global status.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.updates,
    required this.onQuit,
  });

  final OrganizerController controller;
  final UpdateController updates;

  /// Closes the organizer, used once an update installer took over.
  final Future<void> Function() onQuit;

  Future<void> _addGroup(BuildContext context) async {
    final name = await promptForName(context, 'Nouvelle équipe');
    if (name != null) {
      controller.addGroup(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Column(
            children: [
              _Header(
                controller: controller,
                updates: updates,
                onQuit: onQuit,
                onAddGroup: () => _addGroup(context),
              ),
              const Divider(height: 1),
              Expanded(
                child: controller.groups.isEmpty
                    ? _EmptyState(onAddGroup: () => _addGroup(context))
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        itemCount: controller.groups.length,
                        onReorderItem: controller.reorderGroups,
                        itemBuilder: (context, index) {
                          final group = controller.groups[index];
                          return GroupCard(
                            key: ValueKey(group.id),
                            controller: controller,
                            group: group,
                            dragIndex: index,
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              _StatusBar(controller: controller),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.updates,
    required this.onQuit,
    required this.onAddGroup,
  });

  final OrganizerController controller;
  final UpdateController updates;
  final Future<void> Function() onQuit;
  final VoidCallback onAddGroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          Image.asset(
            'assets/icon.png',
            width: 40,
            height: 40,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dofus Organizer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 2),
              Text(
                'Un raccourci par personnage, une équipe active à la fois',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          UpdateBadge(controller: updates, onQuit: onQuit),
          OutlinedButton.icon(
            onPressed: onAddGroup,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Équipe'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.outline),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Paramètres',
            child: IconButton(
              onPressed: () =>
                  SettingsDialog.show(context, controller: controller),
              icon: const Icon(Icons.settings_outlined, size: 19),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});

  final OrganizerController controller;

  GameCharacter? get _lastCharacter {
    final id = controller.lastTrigger?.characterId;
    if (id == null) return null;
    for (final group in controller.groups) {
      for (final character in group.characters) {
        if (character.id == id) return character;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final trigger = controller.lastTrigger;
    final character = _lastCharacter;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: controller.isRecording
                  ? AppColors.accent
                  : (controller.activeShortcutCount > 0
                      ? AppColors.live
                      : AppColors.textDisabled),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            controller.isRecording
                ? 'Capture en cours, raccourcis suspendus'
                : '${controller.activeShortcutCount} raccourci(s) enregistré(s)',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (controller.hasConflicts) ...[
            const SizedBox(width: 16),
            const Icon(Icons.warning_amber_rounded,
                size: 14, color: AppColors.danger),
            const SizedBox(width: 6),
            Text(
              '${controller.rejectedShortcutCount} raccourci(s) refusé(s) '
              'par Windows, ajoutez un modificateur',
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const Spacer(),
          if (trigger != null)
            Text(
              trigger.matched && character != null
                  ? 'Dernière activation : ${character.name}'
                  : 'Dernier appel : aucune fenêtre trouvée',
              style: TextStyle(
                color: trigger.matched
                    ? AppColors.textSecondary
                    : AppColors.danger,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddGroup});

  final VoidCallback onAddGroup;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/logo.png',
            height: 132,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Aucune équipe',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const SizedBox(
            width: 380,
            child: Text(
              'Créez une équipe par configuration de jeu, puis ajoutez ses '
              'personnages. Deux équipes peuvent partager les mêmes touches : '
              'seule l\'équipe activée répond.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAddGroup,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Créer une équipe'),
          ),
        ],
      ),
    );
  }
}
