import 'package:flutter/material.dart';

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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: downloading ? null : controller.openReleasePage,
              child: const Text('Ouvrir la page'),
            ),
            TextButton(
              onPressed:
                  downloading ? null : () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
            if (controller.canInstall && !failed)
              FilledButton(
                onPressed: downloading ? null : () => _install(context),
                child: const Text('Installer'),
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
