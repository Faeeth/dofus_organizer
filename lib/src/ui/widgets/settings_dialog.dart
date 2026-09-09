import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/organizer_controller.dart';
import '../../state/update_controller.dart';
import '../theme.dart';
import 'update_dialog.dart';

/// Application preferences.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.controller,
    required this.updates,
    required this.onQuit,
  });

  final OrganizerController controller;
  final UpdateController updates;
  final Future<void> Function() onQuit;

  static Future<void> show(
    BuildContext context, {
    required OrganizerController controller,
    required UpdateController updates,
    required Future<void> Function() onQuit,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SettingsDialog(
        controller: controller,
        updates: updates,
        onQuit: onQuit,
      ),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  void initState() {
    super.initState();
    // Asking by hand must answer even while the automatic check is postponed:
    // that is the way back for someone who ignored an update and changed
    // their mind.
    unawaited(widget.updates.check(force: true));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return AlertDialog(
          title: const Text('Paramètres', style: TextStyle(fontSize: 17)),
          content: SizedBox(
            width: 480,
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
                UpdateFooter(
                  controller: widget.updates,
                  onQuit: widget.onQuit,
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
