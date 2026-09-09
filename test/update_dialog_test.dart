import 'package:dofus_organizer/src/services/update_service.dart';
import 'package:dofus_organizer/src/state/update_controller.dart';
import 'package:dofus_organizer/src/ui/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _release = AppUpdate(
  version: '1.1.0',
  pageUrl: 'https://example.invalid/releases',
  installerUrl: 'https://example.invalid/installateur.exe',
  installerSize: 10,
);

void main() {
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

  Future<UpdateController> openDialog(
    WidgetTester tester, {
    bool portable = false,
    void Function(DateTime?)? onSnoozeChanged,
  }) async {
    final controller = UpdateController(
      currentVersion: '1.0.0',
      portable: portable,
      onSnoozeChanged: onSnoozeChanged,
      fetch: ({required String currentVersion}) async => _release,
      downloader: fakeDownload,
    );
    await controller.check();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => UpdateDialog.show(
                context,
                controller: controller,
                onQuit: () async {},
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('the dialog states both versions', (tester) async {
    await openDialog(tester);
    expect(
      find.text('Version 1.1.0 publiée. Vous utilisez la 1.0.0.'),
      findsOneWidget,
    );
  });

  testWidgets('ignoring for 30 days silences the check and closes',
      (tester) async {
    DateTime? persisted;
    final controller =
        await openDialog(tester, onSnoozeChanged: (until) => persisted = until);

    await tester.tap(find.text('Ignorer pendant 30 jours'));
    await tester.pumpAndSettle();

    expect(find.text('Mise à jour disponible'), findsNothing);
    expect(controller.isSnoozed, isTrue);
    expect(controller.isAvailable, isFalse);
    expect(persisted, isNotNull);
  });

  testWidgets('later closes without silencing anything', (tester) async {
    final controller = await openDialog(tester);

    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(find.text('Mise à jour disponible'), findsNothing);
    expect(controller.isSnoozed, isFalse);
    expect(controller.isAvailable, isTrue,
        reason: 'the badge must stay for later');
  });

  testWidgets('an installable build offers to install', (tester) async {
    await openDialog(tester);
    expect(find.text('Installer'), findsOneWidget);
    expect(find.text('Ouvrir la page'), findsNothing);
  });

  testWidgets('a portable build is pointed at the page instead',
      (tester) async {
    await openDialog(tester, portable: true);
    expect(find.text('Installer'), findsNothing);
    expect(find.text('Ouvrir la page'), findsOneWidget);
    expect(find.textContaining('portable'), findsOneWidget);
  });

  testWidgets('the badge only shows when something newer exists',
      (tester) async {
    final silent = UpdateController(
      currentVersion: '1.0.0',
      fetch: ({required String currentVersion}) async => null,
    );
    await silent.check();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UpdateBadge(controller: silent, onQuit: () async {}),
      ),
    ));
    expect(find.textContaining('Mise à jour'), findsNothing);
  });
}
