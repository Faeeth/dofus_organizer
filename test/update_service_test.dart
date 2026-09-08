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

    test('nothing published leaves the badge hidden', () async {
      final controller = UpdateController(
        currentVersion: '1.0.0',
        fetch: nothing,
      );
      await controller.checkOnce();
      expect(controller.isAvailable, isFalse);
      expect(controller.stage, UpdateStage.idle);
    });

    test('a newer release can be installed on a regular build', () async {
      final controller = UpdateController(
        currentVersion: '1.0.0',
        fetch: found,
      );
      await controller.checkOnce();
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
      await controller.checkOnce();
      expect(controller.isAvailable, isTrue);
      expect(controller.canInstall, isFalse);
      expect(await controller.download(), isFalse);
    });
  });
}
