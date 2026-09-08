import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/organizer_config.dart';

/// Reads and writes the configuration file under `%LOCALAPPDATA%`.
///
/// Local rather than roaming: the configuration names windows of clients
/// installed on this machine, and following the user onto another one would
/// carry shortcuts pointing at characters that are not there.
///
/// Writes go through a temporary file and a rename so that a crash during a
/// save cannot leave a truncated configuration behind, and are debounced so
/// that a burst of UI toggles produces a single disk write.
class ConfigStore {
  ConfigStore({Directory? directory, Directory? legacyDirectory})
      : _directory = directory,
        _legacyDirectory = legacyDirectory,
        _usesSystemLocation = directory == null;

  static const String _folderName = 'DofusOrganizer';
  static const Duration _writeDelay = Duration(milliseconds: 400);

  Directory? _directory;
  final Directory? _legacyDirectory;

  /// Whether this store lives where the installed organizer keeps its data.
  /// A store pointed at an explicit directory must never reach for the system
  /// location: doing so would let a test, or a second instance, move the real
  /// configuration out from under the installation.
  final bool _usesSystemLocation;
  Timer? _pendingWrite;
  OrganizerConfig? _pendingConfig;

  Directory get directory {
    final resolved = _directory;
    if (resolved != null) return resolved;
    return _directory = Directory(_join(_baseDirectory(), _folderName));
  }

  File get file => File(_join(directory.path, 'config.json'));

  /// Where earlier versions stored the configuration, kept to migrate it.
  /// Null when there is nothing this store may legitimately migrate from.
  File? get _legacyFile {
    final override = _legacyDirectory;
    if (override != null) return File(_join(override.path, 'config.json'));
    if (!_usesSystemLocation) return null;
    final roaming = Platform.environment['APPDATA'];
    if (roaming == null || roaming.isEmpty) return null;
    return File(_join(_join(roaming, _folderName), 'config.json'));
  }

  static String _baseDirectory() {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) return local;
    // Nothing sensible to fall back on but the working directory; better a
    // configuration next to the executable than none at all.
    return Directory.current.path;
  }

  static String _join(String a, String b) => '$a${Platform.pathSeparator}$b';

  /// Moves a configuration left by a version that stored it in the roaming
  /// profile. Runs once: afterwards the local file exists and wins.
  Future<void> _migrateFromRoaming() async {
    try {
      final source = _legacyFile;
      if (source == null ||
          source.path == file.path ||
          !await source.exists()) {
        return;
      }
      await directory.create(recursive: true);
      await source.copy(file.path);
      await source.delete();
      final previous = source.parent;
      // Only remove the old folder when nothing else lived in it.
      if (await previous.exists() && await previous.list().isEmpty) {
        await previous.delete();
      }
    } on Object catch (error) {
      // The configuration is not worth failing a startup for: the organizer
      // simply starts empty, as it would on a new machine.
      debugPrint('Migration de la configuration impossible: $error');
    }
  }

  Future<OrganizerConfig> load() async {
    try {
      if (!await file.exists()) {
        await _migrateFromRoaming();
      }
      if (!await file.exists()) {
        return const OrganizerConfig();
      }
      var content = await file.readAsString();
      // A Windows editor saving the file usually prepends a byte order mark,
      // which jsonDecode rejects.
      if (content.startsWith('﻿')) {
        content = content.substring(1);
      }
      if (content.trim().isEmpty) {
        return const OrganizerConfig();
      }
      return OrganizerConfig.fromJson(jsonDecode(content));
    } on Object catch (error, stack) {
      // A corrupted file must not prevent the organizer from starting: fall
      // back to an empty configuration, the next save will overwrite it.
      debugPrint('Configuration illisible: $error\n$stack');
      return const OrganizerConfig();
    }
  }

  /// Schedules a debounced save of [config].
  void save(OrganizerConfig config) {
    _pendingConfig = config;
    _pendingWrite?.cancel();
    _pendingWrite = Timer(_writeDelay, () => unawaited(flush()));
  }

  /// Writes any pending configuration immediately.
  Future<void> flush() async {
    _pendingWrite?.cancel();
    _pendingWrite = null;
    final config = _pendingConfig;
    if (config == null) return;
    _pendingConfig = null;
    await _write(config);
  }

  Future<void> _write(OrganizerConfig config) async {
    try {
      await directory.create(recursive: true);
      final payload =
          const JsonEncoder.withIndent('  ').convert(config.toJson());
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(payload, flush: true);
      await temporary.rename(file.path);
    } on Object catch (error, stack) {
      debugPrint('Sauvegarde impossible: $error\n$stack');
    }
  }
}
