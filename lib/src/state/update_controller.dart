import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_version.dart';
import '../services/update_service.dart';

/// Where the update sits, from the interface point of view.
enum UpdateStage { idle, available, downloading, ready, failed }

/// Checks for a newer release once at startup, then drives the download.
class UpdateController extends ChangeNotifier {
  UpdateController({
    this.currentVersion = appVersion,
    this.portable = false,
    Future<AppUpdate?> Function({required String currentVersion})? fetch,
  }) : _fetch = fetch ?? _defaultFetch;

  static Future<AppUpdate?> _defaultFetch({required String currentVersion}) =>
      fetchLatestRelease(currentVersion: currentVersion);

  final String currentVersion;

  /// A portable copy cannot be updated by the installer, which would install
  /// a separate copy elsewhere: it is sent to the release page instead.
  final bool portable;

  final Future<AppUpdate?> Function({required String currentVersion}) _fetch;

  UpdateStage _stage = UpdateStage.idle;
  AppUpdate? _update;
  double _progress = 0;
  String? _installerPath;

  UpdateStage get stage => _stage;
  AppUpdate? get update => _update;
  double get progress => _progress;
  String? get installerPath => _installerPath;

  bool get isAvailable => _update != null;

  /// Whether the update can be applied in place, or only pointed at.
  bool get canInstall =>
      !portable && (_update?.hasInstaller ?? false);

  /// Queries the repository. Stays silent unless something newer exists.
  Future<void> checkOnce() async {
    if (_stage != UpdateStage.idle || _update != null) return;
    final found = await _fetch(currentVersion: currentVersion);
    if (found == null) return;
    _update = found;
    _stage = UpdateStage.available;
    notifyListeners();
  }

  /// Downloads the installer, then reports whether it is ready to run.
  Future<bool> download() async {
    final target = _update;
    if (target == null || !canInstall || _stage == UpdateStage.downloading) {
      return false;
    }
    _stage = UpdateStage.downloading;
    _progress = 0;
    notifyListeners();

    final completer = Completer<String?>();
    final subscription = downloadInstaller(target, completer.complete).listen(
      (ratio) {
        _progress = ratio;
        notifyListeners();
      },
    );
    final path = await completer.future;
    await subscription.cancel();

    _installerPath = path;
    _stage = path == null ? UpdateStage.failed : UpdateStage.ready;
    notifyListeners();
    return path != null;
  }

  /// Starts the downloaded installer. The caller quits right after.
  Future<bool> install() async {
    final path = _installerPath;
    if (path == null) return false;
    return runInstaller(path);
  }

  Future<void> openReleasePage() =>
      openInBrowser(_update?.pageUrl ?? releasesPage);
}
