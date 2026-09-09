import 'package:flutter/material.dart';

import '../../services/update_service.dart';
import '../../state/update_controller.dart';
import '../theme.dart';

/// Offers the newer release: install it, or open its page.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.controller,
    required this.onQuit,
  });

  final UpdateController controller;

  /// Closes the organizer once the installer took over.
  final Future<void> Function() onQuit;

  static Future<void> show(
    BuildContext context, {
    required UpdateController controller,
    required Future<void> Function() onQuit,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => UpdateDialog(controller: controller, onQuit: onQuit),
    );
  }

  Future<void> _install(BuildContext context) async {
    final downloaded = await controller.download();
    if (!context.mounted) return;
    if (!downloaded) return;
    if (await controller.install()) {
      await onQuit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final update = controller.update;
        final downloading = controller.stage == UpdateStage.downloading;
        final failed = controller.stage == UpdateStage.failed;
        return AlertDialog(
          title: const Text('Mise à jour disponible',
              style: TextStyle(fontSize: 17)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${update?.version ?? ''} publiée. '
                  'Vous utilisez la ${controller.currentVersion}.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  controller.canInstall
                      ? 'L\'installation conserve vos équipes et vos '
                          'raccourcis. Le tool se ferme pendant la mise à jour '
                          'puis se relance.'
                      : 'Cette copie est portable : remplacez son dossier par '
                          'la nouvelle archive. Votre configuration est '
                          'conservée, elle vit en dehors du dossier.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                if (downloading) ...[
                  const SizedBox(height: 18),
                  LinearProgressIndicator(
                    value: controller.progress,
                    backgroundColor: AppColors.surfaceHigh,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Téléchargement ${(controller.progress * 100).round()} %',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (failed) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Le téléchargement a échoué. La page de la release reste '
                    'accessible.',
                    style: TextStyle(color: AppColors.danger, fontSize: 12.5),
                  ),
                ],
                if (!downloading) ...[
                  const SizedBox(height: 14),
                  _LinkText(
                    label: 'Voir les notes de version',
                    onTap: controller.openReleasePage,
                  ),
                ],
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            // Ecarte des deux autres : celui-ci fait taire la verification,
            // pas seulement cette fenetre.
            TextButton(
              onPressed: downloading
                  ? null
                  : () {
                      controller.snooze();
                      Navigator.of(context).pop();
                    },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Ignorer pendant 30 jours'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed:
                      downloading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Plus tard'),
                ),
                const SizedBox(width: 8),
                if (controller.canInstall && !failed)
                  FilledButton(
                    onPressed: downloading ? null : () => _install(context),
                    child: const Text('Installer'),
                  )
                else
                  FilledButton(
                    onPressed: downloading ? null : controller.openReleasePage,
                    child: const Text('Ouvrir la page'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Discreet header button, shown only when a newer release exists.
class UpdateBadge extends StatelessWidget {
  const UpdateBadge({
    super.key,
    required this.controller,
    required this.onQuit,
  });

  final UpdateController controller;
  final Future<void> Function() onQuit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isAvailable) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: 'Version ${controller.update!.version} disponible',
            child: OutlinedButton.icon(
              onPressed: () => UpdateDialog.show(
                context,
                controller: controller,
                onQuit: onQuit,
              ),
              icon: const Icon(Icons.system_update_alt, size: 16),
              label: Text('Mise à jour ${controller.update!.version}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Discreet textual link, for what is worth offering without a button.
class _LinkText extends StatefulWidget {
  const _LinkText({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: TextStyle(
            color: _hovered ? AppColors.accent : AppColors.textSecondary,
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor:
                _hovered ? AppColors.accent : AppColors.textDisabled,
          ),
        ),
      ),
    );
  }
}

/// Version line of the settings: the mark, the running version, and what is
/// published when it is newer.
class UpdateFooter extends StatelessWidget {
  const UpdateFooter({
    super.key,
    required this.controller,
    required this.onQuit,
  });

  final UpdateController controller;
  final Future<void> Function() onQuit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final update = controller.update;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _GithubMark(),
                const SizedBox(width: 10),
                Text(
                  controller.currentVersion,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            // A jour : la version seule suffit, il n'y a rien a proposer.
            // La seconde ligne evite d'entasser le libelle et le bouton a
            // cote de la version, qui deborde des que le numero s'allonge.
            if (update != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Version ${update.version} disponible',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => UpdateDialog.show(
                      context,
                      controller: controller,
                      onQuit: onQuit,
                    ),
                    child: const Text('Mettre à jour'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Opens the project page. The mark is white, so it takes the tint given here
/// and follows the interface rather than punching a hole in it.
class _GithubMark extends StatefulWidget {
  const _GithubMark();

  @override
  State<_GithubMark> createState() => _GithubMarkState();
}

class _GithubMarkState extends State<_GithubMark> {
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
          child: Image.asset(
            'assets/github.png',
            width: 22,
            height: 22,
            color: _hovered ? AppColors.textPrimary : AppColors.textSecondary,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
