import 'package:flutter/material.dart';

import '../../models/dofus_class.dart';
import '../theme.dart';

/// Outcome of the picker: [iconKey] is null when the user cleared the
/// portrait. A null result from the dialog itself means the user cancelled.
class ClassPickerResult {
  const ClassPickerResult(this.iconKey);

  final String? iconKey;
}

/// Grid of the class portraits, with a gender toggle.
class ClassPickerDialog extends StatefulWidget {
  const ClassPickerDialog({super.key, this.initial});

  final String? initial;

  static Future<ClassPickerResult?> show(
    BuildContext context, {
    String? initial,
  }) {
    return showDialog<ClassPickerResult>(
      context: context,
      builder: (context) => ClassPickerDialog(initial: initial),
    );
  }

  @override
  State<ClassPickerDialog> createState() => _ClassPickerDialogState();
}

class _ClassPickerDialogState extends State<ClassPickerDialog> {
  late bool _female = widget.initial?.endsWith('_f') ?? false;
  late String? _selectedSlug = _slugOf(widget.initial);

  static String? _slugOf(String? key) {
    if (classIconAsset(key) == null) return null;
    return key!.substring(0, key.lastIndexOf('_'));
  }

  void _submit(String slug) {
    Navigator.of(context).pop(
      ClassPickerResult('${slug}_${_female ? 'f' : 'm'}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('Classe', style: TextStyle(fontSize: 17)),
          const Spacer(),
          _GenderToggle(
            female: _female,
            onChanged: (value) => setState(() => _female = value),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in kDofusClasses)
                _ClassTile(
                  entry: entry,
                  female: _female,
                  selected: entry.slug == _selectedSlug,
                  onTap: () {
                    setState(() => _selectedSlug = entry.slug);
                    _submit(entry.slug);
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const ClassPickerResult(null)),
          child: const Text('Aucune'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.entry,
    required this.female,
    required this.selected,
    required this.onTap,
  });

  final DofusClass entry;
  final bool female;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: entry.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : AppColors.background,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.outline,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Image.asset(
                entry.assetFor(female: female),
                width: 48,
                height: 48,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 4),
              Text(
                entry.name,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderToggle extends StatelessWidget {
  const _GenderToggle({required this.female, required this.onChanged});

  final bool female;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GenderButton(
            label: 'Masculin',
            selected: !female,
            onTap: () => onChanged(false),
          ),
          _GenderButton(
            label: 'Féminin',
            selected: female,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  const _GenderButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Portrait of a character, or a neutral placeholder when it has none.
class ClassAvatar extends StatelessWidget {
  const ClassAvatar({super.key, required this.iconKey, this.size = 34});

  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = classIconAsset(iconKey);
    if (asset == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.person_outline,
          size: size * 0.6,
          color: AppColors.textDisabled,
        ),
      );
    }
    return Tooltip(
      message: classNameForIcon(iconKey) ?? '',
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
