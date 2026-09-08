import 'package:flutter/material.dart';

import '../../models/shortcut.dart';
import '../../state/organizer_controller.dart';
import '../theme.dart';
import 'shortcut_badge.dart';
import 'shortcut_recorder_dialog.dart';

/// Application preferences and the two global shortcuts driving the organizer
/// itself.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.controller});

  final OrganizerController controller;

  static Future<void> show(
    BuildContext context, {
    required OrganizerController controller,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SettingsDialog(controller: controller),
    );
  }

  Future<void> _pick(
    BuildContext context, {
    required String title,
    required Shortcut? current,
    required void Function(Shortcut?) apply,
  }) async {
    final result = await ShortcutRecorderDialog.show(
      context,
      controller: controller,
      title: title,
      initial: current,
    );
    if (result == null) return;
    apply(result.shortcut);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return AlertDialog(
          title: const Text('Paramètres', style: TextStyle(fontSize: 17)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SwitchRow(
                  label: 'Réduire dans la zone de notification à la fermeture',
                  description:
                      'La croix masque la fenêtre au lieu de fermer le tool.',
                  value: settings.closeToTray,
                  onChanged: controller.setCloseToTray,
                ),
                _SwitchRow(
                  label: 'Démarrer réduit',
                  description:
                      'La fenêtre reste masquée au lancement, les raccourcis '
                      'sont actifs immédiatement.',
                  value: settings.startMinimized,
                  onChanged: controller.setStartMinimized,
                ),
                _SwitchRow(
                  label: 'Lancer au démarrage de Windows',
                  description:
                      'Enregistre le tool dans la clé Run de l\'utilisateur '
                      'courant, en mode réduit.',
                  value: settings.launchAtStartup,
                  onChanged: (value) => controller.setLaunchAtStartup(value),
                ),
                const Divider(height: 28),
                _ShortcutRow(
                  label: 'Afficher la fenêtre',
                  shortcut: settings.showWindowShortcut,
                  conflicting: controller.isShowWindowShortcutRejected,
                  onTap: () => _pick(
                    context,
                    title: 'Raccourci d\'affichage de la fenêtre',
                    current: settings.showWindowShortcut,
                    apply: controller.setShowWindowShortcut,
                  ),
                ),
                const SizedBox(height: 10),
                _ShortcutRow(
                  label: 'Quitter le tool',
                  shortcut: settings.quitShortcut,
                  conflicting: controller.isQuitShortcutRejected,
                  onTap: () => _pick(
                    context,
                    title: 'Raccourci de fermeture',
                    current: settings.quitShortcut,
                    apply: controller.setQuitShortcut,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.label,
    required this.shortcut,
    required this.conflicting,
    required this.onTap,
  });

  final String label;
  final Shortcut? shortcut;
  final bool conflicting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              if (conflicting) ...[
                const SizedBox(height: 2),
                const Text(
                  'Refusé par Windows : la touche est déjà réservée. '
                  'Ajoutez Ctrl, Alt ou Maj, ou changez de touche.',
                  style: TextStyle(color: AppColors.danger, fontSize: 11.5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        ShortcutBadge(
          shortcut: shortcut,
          conflicting: conflicting,
          onTap: onTap,
        ),
      ],
    );
  }
}
