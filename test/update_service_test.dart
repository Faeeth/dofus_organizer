import 'dart:convert';
import 'dart:io';

import 'package:dofus_organizer/src/services/update_service.dart';
import 'package:dofus_organizer/src/state/update_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves one canned release payload, so the tests never touch the real API.
Future<HttpServer> serve(Object payload, {int status = 200}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  });
  return server;
}

Map<String, Object?> release({
  String tag = 'v2.0.0',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, Object?>> assets = const [],
}) {
  return {
    'tag_name': tag,
    'draft': draft,
    'prerelease': prerelease,
    'html_url': 'https://example.invalid/releases/$tag',
    'assets': assets,
  };
}

void main() {
  group('version comparison', () {
    test('compares numerically, not alphabetically', () {
      expect(isNewerVersion('1.0.10', '1.0.9'), isTrue);
      expect(isNewerVersion('1.0.9', '1.0.10'), isFalse);
      expect(isNewerVersion('1.2.0', '1.1.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('an identical version is not newer', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    });

    test('a suffix does not make a version newer', () {
      expect(isNewerVersion('1.0.0-beta', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.1-beta', '1.0.0'), isTrue);
    });

    test('missing parts count as zero', () {
      expect(isNewerVersion('1.1', '1.0.9'), isTrue);
      expect(isNewerVersion('1', '1.0.0'), isFalse);
    });
  });

  group('release lookup', () {
    late HttpServer server;

    tearDown(() async => server.close(force: true));

    String endpointOf(HttpServer server) =>
        'http://${server.address.host}:${server.port}/';

    test('a newer release is reported with its installer', () async {
      server = await serve(release(assets: [
        {
          'name': 'DofusOrganizer-2.0.0-installateur.exe',
          'browser_download_url': 'https://example.invalid/installer.exe',
          'size': 4242,
        },
      ]));

      final update = await fetchLatestRelease(
        currentVersion: '1.0.0',
        endpoint: endpointOf(server),
      );

      expect(update, isNotNull);
      expect(update!.version, '2.0.0');
      expect(update.hasInstaller, isTrue);
      expect(update.installerSize, 4242);
    });

    test('an older or identical release is ignored', () async {
      server = await serve(release(tag: 'v1.0.0'));
      final update = await fetchLatestRelease(
        currentVersion: '1.0.0',
        endpoint: endpointOf(server),
      );
      expect(update, isNull);
    });

    test('drafts and pre-releases are ignored', () async {
      server = await serve(release(draft: true));
      expect(
        await fetchLatestRelease(
          currentVersion: '1.0.0',
          endpoint: endpointOf(server),
        ),
        isNull,
      );
      await server.close(force: true);

      server = await serve(release(prerelease: true));
      expect(
        await fetchLatestRelease(
          currentVersion: '1.0.0',
          endpoint: endpointOf(server),
        ),
        isNull,
      );
    });

    test('a release without installer is still reported', () async {
      server = await serve(release());
      final update = await fetchLatestRelease(
        currentVersion: '1.0.0',
        endpoint: endpointOf(server),
      );
      expect(update, isNotNull);
      expect(update!.hasInstaller, isFalse);
    });

    test('an error status says nothing', () async {
      server = await serve(release(), status: 500);
      expect(
        await fetchLatestRelease(
          currentVersion: '1.0.0',
          endpoint: endpointOf(server),
        ),
        isNull,
      );
    });

    test('an unreachable endpoint says nothing', () async {
      // Port 1 is not listening; the failure must stay silent.
      expect(
        await fetchLatestRelease(
          currentVersion: '1.0.0',
          endpoint: 'http://127.0.0.1:1/',
        ),
        isNull,
      );
    });

    test('a development build never looks behind', () async {
      server = await serve(release());
      expect(
        await fetchLatestRelease(
          currentVersion: 'dev',
          endpoint: endpointOf(server),
        ),
        isNull,
      );
    });
  });

  group('update controller', () {
    Future<AppUpdate?> found({required String currentVersion}) async {
      return const AppUpdate(
        version: '2.0.0',
        pageUrl: 'https://example.invalid/releases',
        installerUrl: 'https://example.invalid/installer.exe',
        installerSize: 10,
      );
    }

    Future<AppUpdate?> nothing({required String currentVersion}) async => null;

    /// Stands in for the real download: reports progress, then hands back a
    /// path as if the installer had been written.
    Stream<double> fakeDownload(
      AppUpdate update,
      void Function(String?) done,
    ) async* {
      yield 0.5;
      yield 1;
      done('/tmp/installateur.exe');
    }

    test('nothing published leaves the badge hidden', () async {
      final controller = UpdateController(
        currentVersion: '1.0.0',
        fetch: nothing,
      );
      await controller.check();
      expect(controller.isAvailable, isFalse);
      expect(controller.stage, UpdateStage.idle);
    });

    test('a newer release can be installed on a regular build', () async {
      final controller = UpdateController(
        currentVersion: '1.0.0',
        fetch: found,
      );
      await controller.check();
      expect(controller.isAvailable, isTrue);
      expect(controller.canInstall, isTrue);
      expect(controller.stage, UpdateStage.available);
    });

    test('a portable build is offered the page, not the installer', () async {
      final controller = UpdateController(
        currentVersion: '1.0.0',
        portable: true,
        fetch: found,
      );
      await controller.check();
      expect(controller.isAvailable, isTrue);
      expect(controller.canInstall, isFalse);
      expect(await controller.download(), isFalse);
    });

    test('the announcement waits until it is shown', () async {
      final controller = UpdateController(
        currentVersion: '1.0.0',
        fetch: found,
      );
      await controller.check();
      expect(controller.isPopupPending, isTrue);

      controller.markPopupShown();
      expect(controller.isPopupPending, isFalse);
      // The badge stays: only the announcement was spent.
      expect(controller.isAvailable, isTrue);
    });

    test('ignoring silences the automatic check and clears what was found',
        () async {
      DateTime? persisted;
      final controller = UpdateController(
        currentVersion: '1.0.0',
        fetch: found,
        onSnoozeChanged: (until) => persisted = until,
      );
      await controller.check();
      controller.snooze();

      expect(controller.isAvailable, isFalse);
      expect(controller.isPopupPending, isFalse);
      expect(controller.isSnoozed, isTrue);
      expect(persisted, isNotNull);
      // Thirty days, give or take the time the test took to run.
      final days = persisted!.difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(29, 30));

      await controller.check();
      expect(controller.isAvailable, isFalse,
          reason: 'the automatic check must stay quiet while snoozed');
    });

    test('asking by hand answers even while snoozed', () async {
      final controller = UpdateController(
        currentVersion: '1.0.0',
        snoozedUntil: DateTime.now().add(const Duration(days: 10)),
        fetch: found,
      );
      await controller.check();
      expect(controller.isAvailable, isFalse);

      await controller.check(force: true);
      expect(controller.isAvailable, isTrue);
    });

    test('updating by hand lifts a delay that was still running', () async {
      DateTime? persisted;
      final controller = UpdateController(
        currentVersion: '1.0.0',
        fetch: found,
        downloader: fakeDownload,
        onSnoozeChanged: (until) => persisted = until,
      );
      await controller.check();
      controller.snooze();
      expect(controller.isSnoozed, isTrue);

      // Coming back through the settings and asking for the update.
      await controller.check(force: true);
      expect(await controller.download(), isTrue);

      expect(controller.isSnoozed, isFalse);
      expect(persisted, isNull, reason: 'the delay is cleared, not moved');
    });

    test('the download reports progress and ends ready', () async {
      final controller = UpdateController(
        currentVersion: '1.0.0',
        fetch: found,
        downloader: fakeDownload,
      );
      await controller.check();

      expect(await controller.download(), isTrue);
      expect(controller.stage, UpdateStage.ready);
      expect(controller.progress, 1);
      expect(controller.installerPath, isNotNull);
    });

    test('an expired delay lets the automatic check run again', () async {
      final controller = UpdateController(
        currentVersion: '1.0.0',
        snoozedUntil: DateTime.now().subtract(const Duration(days: 1)),
        fetch: found,
      );
      expect(controller.isSnoozed, isFalse);
      await controller.check();
      expect(controller.isAvailable, isTrue);
    });
  });
}
