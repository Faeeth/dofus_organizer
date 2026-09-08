import 'package:flutter/foundation.dart';

/// A playable class and the two portraits shipped for it.
///
/// Portraits come from the game files; `tool/extract_class_icons.py` writes
/// them as `assets/classes/<slug>_<m|f>.png`.
@immutable
class DofusClass {
  const DofusClass(this.slug, this.name);

  /// Identifier used in the asset names and in the saved configuration.
  final String slug;

  final String name;

  String assetFor({required bool female}) =>
      classIconAsset(iconKey(female: female))!;

  String iconKey({required bool female}) => '${slug}_${female ? 'f' : 'm'}';
}

/// Every class, in the order the game lists them.
const List<DofusClass> kDofusClasses = <DofusClass>[
  DofusClass('feca', 'Féca'),
  DofusClass('osamodas', 'Osamodas'),
  DofusClass('enutrof', 'Enutrof'),
  DofusClass('sram', 'Sram'),
  DofusClass('xelor', 'Xélor'),
  DofusClass('ecaflip', 'Ecaflip'),
  DofusClass('eniripsa', 'Eniripsa'),
  DofusClass('iop', 'Iop'),
  DofusClass('cra', 'Crâ'),
  DofusClass('sadida', 'Sadida'),
  DofusClass('sacrieur', 'Sacrieur'),
  DofusClass('pandawa', 'Pandawa'),
  DofusClass('roublard', 'Roublard'),
  DofusClass('zobal', 'Zobal'),
  DofusClass('steamer', 'Steamer'),
  DofusClass('eliotrope', 'Eliotrope'),
  DofusClass('huppermage', 'Huppermage'),
  DofusClass('ouginak', 'Ouginak'),
  DofusClass('forgelance', 'Forgelance'),
];

/// Resolves the asset path of an icon key such as `iop_m`.
///
/// Returns null for an unknown key, so a configuration edited by hand or
/// written by an older version cannot make the interface throw on a missing
/// asset.
String? classIconAsset(String? key) {
  if (key == null || key.isEmpty) return null;
  final separator = key.lastIndexOf('_');
  if (separator <= 0 || separator == key.length - 1) return null;
  final slug = key.substring(0, separator);
  final gender = key.substring(separator + 1);
  if (gender != 'm' && gender != 'f') return null;
  if (!kDofusClasses.any((entry) => entry.slug == slug)) return null;
  return 'assets/classes/$key.png';
}

/// Human readable name behind an icon key, for tooltips.
String? classNameForIcon(String? key) {
  if (classIconAsset(key) == null) return null;
  final slug = key!.substring(0, key.lastIndexOf('_'));
  for (final entry in kDofusClasses) {
    if (entry.slug == slug) return entry.name;
  }
  return null;
}
