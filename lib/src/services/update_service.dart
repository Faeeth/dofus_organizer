/// Is there a release newer than the one running?
///
/// The repository is queried once at startup, and stays silent in every case
/// but one: a published version newer than ours. No network, unreachable
/// repository, unreadable answer, nothing new — nothing is said. A warning at
/// the launch of a tool opened to play has to earn itself.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Where releases are asked for.
const String _releasesApi =
    'https://api.github.com/repos/Faeeth/dofus_organizer/releases/latest';

/// Page opened when the installer cannot be used, portable builds included.
const String releasesPage =
    'https://github.com/Faeeth/dofus_organizer/releases/latest';

/// Past this, give up: startup must not wait on GitHub.
const Duration _timeout = Duration(seconds: 4);

/// A published version, newer than ours.
@immutable
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.pageUrl,
    this.installerUrl = '',
    this.installerSize = 0,
  });

  /// The number, without the `v` of the tag.
  final String version;

  /// The release page, where the archive can be taken by hand.
  final String pageUrl;

  /// The installer itself, when the release carries one.
  final String installerUrl;

  /// What the installer weighs, so progress can show something that moves.
  final int installerSize;

  bool get hasInstaller => installerUrl.isNotEmpty;
}

/// Asks GitHub whether there is better. Returns null if not, or on any hitch.
Future<AppUpdate?> fetchLatestRelease({
  required String currentVersion,
  HttpClient? client,
  // Injectable for tests: without it they would query the real API and pass
  // for the wrong reason.
  String endpoint = _releasesApi,
}) async {
  // A development build is behind nothing: it is ahead of everything, and
  // being told otherwise at every launch would grow old.
  if (currentVersion.isEmpty || currentVersion == 'dev') return null;

  final http = client ?? HttpClient();
  http.connectionTimeout = _timeout;
  try {
    final request = await http.getUrl(Uri.parse(endpoint)).timeout(_timeout);
    // GitHub wants an agent; without one it answers 403.
    request.headers
        .set(HttpHeaders.userAgentHeader, 'DofusOrganizer/$currentVersion');
    request.headers
        .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response = await request.close().timeout(_timeout);
    if (response.statusCode != 200) return null;

    final body = await response.transform(utf8.decoder).join().timeout(_timeout);
    final payload = jsonDecode(body);
    if (payload is! Map) return null;
    // A draft or pre-release is not offered: it is not meant to be installed
    // yet.
    if (payload['draft'] == true || payload['prerelease'] == true) return null;

    final tag = '${payload['tag_name'] ?? ''}';
    final published = tag.startsWith('v') ? tag.substring(1) : tag;
    if (published.isEmpty || !isNewerVersion(published, currentVersion)) {
      return null;
    }

    // The installer among the attached files. A release without one is still
    // offered: the user is then sent to its page.
    var installerUrl = '';
    var installerSize = 0;
    for (final asset in payload['assets'] as List? ?? const []) {
      if (asset is! Map) continue;
      final name = '${asset['name'] ?? ''}';
      if (name.endsWith('.exe') && name.contains('installateur')) {
        installerUrl = '${asset['browser_download_url'] ?? ''}';
        installerSize = (asset['size'] as num?)?.toInt() ?? 0;
        break;
      }
    }
    return AppUpdate(
      version: published,
      pageUrl: '${payload['html_url'] ?? releasesPage}',
      installerUrl: installerUrl,
      installerSize: installerSize,
    );
  } on Object {
    return null;
  } finally {
    if (client == null) http.close(force: true);
  }
}

/// Is `a` newer than `b`?
///
/// Number by number rather than alphabetically: `1.0.10` comes after `1.0.9`,
/// which a string comparison gets exactly backwards. A suffix — `1.1.0-beta` —
/// is dropped before comparing: it only names, and `beta` compares to nothing.
bool isNewerVersion(String a, String b) {
  List<int> parts(String version) => version
      .split('-')
      .first
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
  final left = parts(a);
  final right = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < left.length ? left[i] : 0;
    final y = i < right.length ? right[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Downloads the installer, reporting progress from 0 to 1.
///
/// The file goes to the system temporary folder: Windows cleans it up on its
/// own, and nobody has to remember to erase it. Calls [done] with the path of
/// the file, or null when something failed — the caller then falls back on the
/// release page, which always works.
Stream<double> downloadInstaller(
  AppUpdate update,
  void Function(String? path) done,
) async* {
  final http = HttpClient();
  File? written;
  try {
    final target = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'DofusOrganizer-${update.version}-installateur.exe',
    );
    var request = await http.getUrl(Uri.parse(update.installerUrl));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'DofusOrganizer/${update.version}',
    );
    var response = await request.close();

    // GitHub serves its files from another domain: the redirect is followed
    // by hand, HttpClient does not cross it alone when the host changes.
    var hops = 0;
    while (response.isRedirect && hops < 5) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null) break;
      await response.drain<void>();
      request = await http.getUrl(Uri.parse(location));
      request.headers.set(HttpHeaders.userAgentHeader, 'DofusOrganizer');
      response = await request.close();
      hops++;
    }
    if (response.statusCode != 200) {
      done(null);
      return;
    }

    final total =
        response.contentLength > 0 ? response.contentLength : update.installerSize;
    final sink = target.openWrite();
    var received = 0;
    var lastReported = 0.0;
    await for (final chunk in response) {
      sink.add(chunk);
      received += chunk.length;
      final ratio = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
      // One percent at a time: yielding on every packet would repaint the
      // window hundreds of times for nothing.
      if (ratio - lastReported >= 0.01 || ratio >= 1) {
        lastReported = ratio;
        yield ratio;
      }
    }
    await sink.close();
    written = target;
  } on Object {
    written = null;
  } finally {
    http.close(force: true);
    done(written?.path);
  }
}

/// Starts the installer and returns immediately.
///
/// `/SILENT` shows progress without the wizard pages: an update has nothing
/// to ask that was not already asked. `/CLOSEAPPLICATIONS` lets the installer
/// close whatever still holds the files — the caller quits right after, but
/// the exact order of the two cannot be controlled.
///
/// Detached, otherwise it would die with the application that just started it.
Future<bool> runInstaller(String path) async {
  try {
    await Process.start(
      path,
      const ['/SILENT', '/CLOSEAPPLICATIONS', '/NORESTART'],
      mode: ProcessStartMode.detached,
    );
    return true;
  } on Object {
    return false;
  }
}

/// Opens [url] in the default browser.
Future<void> openInBrowser(String url) async {
  try {
    await Process.start(
      'cmd',
      ['/c', 'start', '', url],
      mode: ProcessStartMode.detached,
    );
  } on Object catch (error) {
    debugPrint('Ouverture du navigateur impossible: $error');
  }
}
