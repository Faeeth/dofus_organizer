import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_version.dart';
import '../services/update_service.dart';

/// Where the update sits, from the interface point of view.
enum UpdateStage { idle, available, downloading, ready, failed }

/// Checks for a newer release, then drives the download.
class UpdateController extends ChangeNotifier {
  UpdateController({
    this.currentVersion = appVersion,
    this.portable = false,
    DateTime? snoozedUntil,
    this.onSnoozeChanged,
    Future<AppUpdate?> Function({required String currentVersion})? fetch,
    Stream<double> Function(AppUpdate, void Function(String?))? downloader,
  })  : _snoozedUntil = snoozedUntil,
        _fetch = fetch ?? _defaultFetch,
        _downloader = downloader ?? downloadInstaller;

  /// How long "ignore" keeps the check quiet.
  static const Duration snoozeDuration = Duration(days: 30);

  static Future<AppUpdate?> _defaultFetch({required String currentVersion}) =>
      fetchLatestRelease(currentVersion: currentVersion);

  final String currentVersion;

  /// A portable copy cannot be updated by the installer, which would install
  /// a separate copy elsewhere: it is sent to the release page instead.
  final bool portable;

  /// Persists the delay, so it survives a restart.
  final void Function(DateTime? until)? onSnoozeChanged;

  final Future<AppUpdate?> Function({required String currentVersion}) _fetch;

  /// Injectable for tests: the real one opens an HttpClient, which the test
  /// framework refuses.
  final Stream<double> Function(AppUpdate, void Function(String?)) _downloader;

  UpdateStage _stage = UpdateStage.idle;
  AppUpdate? _update;
  double _progress = 0;
  String? _installerPath;
  DateTime? _snoozedUntil;
  bool _popupPending = false;
  bool _checking = false;

  UpdateStage get stage => _stage;
  AppUpdate? get update => _update;
  double get progress => _progress;
  String? get installerPath => _installerPath;
  DateTime? get snoozedUntil => _snoozedUntil;

  bool get isAvailable => _update != null;

  /// True while the automatic check must stay quiet.
  bool get isSnoozed =>
      _snoozedUntil != null && DateTime.now().isBefore(_snoozedUntil!);

  /// A newer release was found and the announcement has not been shown yet.
  ///
  /// The window may well be hidden in the notification area when the check
  /// lands: the announcement waits there until the window is actually on
  /// screen, rather than being spent on nobody.
  bool get isPopupPending => _popupPending;

  /// Whether the update can be applied in place, or only pointed at.
  bool get canInstall => !portable && (_update?.hasInstaller ?? false);

  /// Queries the repository. Stays silent unless something newer exists.
  ///
  /// [force] is what the settings use: asking by hand must answer even while
  /// the automatic check is postponed.
  Future<void> check({bool force = false}) async {
    if (_checking || _update != null) return;
    if (!force && isSnoozed) return;
    _checking = true;
    try {
      final found = await _fetch(currentVersion: currentVersion);
      if (found == null) return;
      _update = found;
      _stage = UpdateStage.available;
      _popupPending = true;
      notifyListeners();
    } finally {
      _checking = false;
    }
  }

  /// Marks the announcement as shown, so it does not come back on every
  /// return to the window.
  void markPopupShown() {
    if (!_popupPending) return;
    _popupPending = false;
    notifyListeners();
  }

  /// Lifts the delay. Updating by hand says the delay is over: it meant
  /// "leave me alone unless I ask", not "stay quiet for thirty days whatever
  /// I do".
  void clearSnooze() {
    if (_snoozedUntil == null) return;
    _snoozedUntil = null;
    onSnoozeChanged?.call(null);
    notifyListeners();
  }

  /// Keeps the check quiet for [snoozeDuration], and drops what was found so
  /// the interface stops offering it.
  void snooze() {
    final until = DateTime.now().add(snoozeDuration);
    _snoozedUntil = until;
    _update = null;
    _stage = UpdateStage.idle;
    _popupPending = false;
    onSnoozeChanged?.call(until);
    notifyListeners();
  }

  /// Downloads the installer, then reports whether it is ready to run.
  Future<bool> download() async {
    final target = _update;
    if (target == null || !canInstall || _stage == UpdateStage.downloading) {
      return false;
    }
    // Asking for the update ends any delay that was still running.
    clearSnooze();
    _stage = UpdateStage.downloading;
    _progress = 0;
    notifyListeners();

    final completer = Completer<String?>();
    final subscription = _downloader(target, completer.complete).listen(
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
