import 'package:flutter/material.dart';

import '../../services/update_service.dart';
import '../../state/organizer_controller.dart';
import '../theme.dart';

/// Application preferences.
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
              ],
            ),
          ),
          // Le lien vers le projet tient a gauche, loin du bouton qui
          // ferme : ce n'est pas une action de sortie.
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            const _GithubLink(),
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

/// Opens the project page. The mark is white, so it takes the tint given
/// here and follows the interface rather than punching a hole in it.
class _GithubLink extends StatefulWidget {
  const _GithubLink();

  @override
  State<_GithubLink> createState() => _GithubLinkState();
}

class _GithubLinkState extends State<_GithubLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Voir le projet sur GitHub',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => openInBrowser(projectPage),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/github.png',
              width: 22,
              height: 22,
              color: _hovered ? AppColors.textPrimary : AppColors.textSecondary,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
