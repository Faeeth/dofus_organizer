import 'package:flutter/material.dart';

import '../../models/shortcut.dart';
import '../theme.dart';

/// Compact representation of a shortcut, used in lists and dialogs.
class ShortcutBadge extends StatelessWidget {
  const ShortcutBadge({
    super.key,
    required this.shortcut,
    this.onTap,
    this.dimmed = false,
    this.conflicting = false,
    this.highlighted = false,
  });

  final Shortcut? shortcut;
  final VoidCallback? onTap;

  /// The binding exists but is not live (character or group disabled).
  final bool dimmed;

  /// Windows refused to register the shortcut.
  final bool conflicting;

  /// The shortcut fired recently.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color foreground;
    final Color border;
    final Color background;
    if (conflicting) {
      foreground = AppColors.danger;
      border = AppColors.danger.withValues(alpha: 0.5);
      background = AppColors.danger.withValues(alpha: 0.12);
    } else if (shortcut == null) {
      foreground = AppColors.textDisabled;
      border = AppColors.outline;
      background = Colors.transparent;
    } else if (highlighted) {
      foreground = AppColors.live;
      border = AppColors.live;
      background = AppColors.live.withValues(alpha: 0.18);
    } else if (dimmed) {
      foreground = AppColors.textDisabled;
      border = AppColors.outline;
      background = AppColors.surfaceHigh;
    } else {
      foreground = AppColors.accent;
      border = AppColors.accent.withValues(alpha: 0.45);
      background = AppColors.accentSoft;
    }

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: Text(
        shortcut?.label ?? 'Aucun',
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }
    return Tooltip(
      message: conflicting
          ? 'Refusé par Windows : touche réservée ou déjà prise par une autre '
              'application. Ajoutez Ctrl, Alt ou Maj, ou changez de touche.'
          : 'Modifier le raccourci',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: content,
      ),
    );
  }
}
