import 'dart:io';

/// Version of the running build, as displayed and as compared to the latest
/// release.
///
/// Set at build time with `--dart-define=DOFUS_ORGANIZER_VERSION=1.0.0`, which
/// the release workflow derives from the tag. Built from sources it stays
/// `dev`, which is also what keeps a development build from believing it is
/// behind the last published one.
const String appVersion = String.fromEnvironment(
  'DOFUS_ORGANIZER_VERSION',
  defaultValue: 'dev',
);

/// Marker file shipped next to the executable in the portable archive.
const String _portableMarker = 'portable.txt';

/// Whether this build was extracted from the portable archive rather than
/// installed.
///
/// A portable copy must not be updated by running the installer: that would
/// install a second, separate copy elsewhere and leave this folder stale. The
/// updater sends portable users to the release page instead.
bool get isPortableBuild {
  try {
    final folder = File(Platform.resolvedExecutable).parent;
    return File('${folder.path}${Platform.pathSeparator}$_portableMarker')
        .existsSync();
  } on Object {
    return false;
  }
}
