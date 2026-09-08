import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/organizer_config.dart';

/// Reads and writes the configuration file under `%APPDATA%`.
///
/// Writes go through a temporary file and a rename so that a crash during a
/// save cannot leave a truncated configuration behind, and are debounced so
/// that a burst of UI toggles produces a single disk write.
class ConfigStore {
  ConfigStore({Directory? directory}) : _directory = directory;


  static const Duration _writeDelay = Duration(milliseconds: 400);

  Directory? _directory;
  Timer? _pendingWrite;
  OrganizerConfig? _pendingConfig;

  Directory get directory {
    final resolved = _directory;
    if (resolved != null) return resolved;
    final appData = Platform.environment['APPDATA'];
    final base = appData != null && appData.isNotEmpty
        ? appData
        : Directory.current.path;
    return _directory = Directory('$base${Platform.pathSeparator}DofusOrganizer');
  }

  File get file =>
      File('${directory.path}${Platform.pathSeparator}config.json');

  Future<OrganizerConfig> load() async {
    try {
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
