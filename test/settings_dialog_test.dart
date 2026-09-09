import 'dart:io';

import 'package:dofus_organizer/src/services/config_store.dart';
import 'package:dofus_organizer/src/services/native_bridge.dart';
import 'package:dofus_organizer/src/services/update_service.dart';
import 'package:dofus_organizer/src/state/organizer_controller.dart';
import 'package:dofus_organizer/src/state/update_controller.dart';
import 'package:dofus_organizer/src/ui/widgets/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps the dialog away from the real channel and the real registry.
class _SilentBridge extends NativeBridge {
  _SilentBridge() : super(channel: const MethodChannel('test/native'));

  @override
  void listen() {}

  @override
  Future<Set<String>> applyBindings(List<NativeBinding> bindings) async => {};

  @override
  Future<bool> isLaunchAtStartupEnabled() async => false;
}

/// Answers whatever the test asked for, without touching the network.
UpdateController updatesReturning(AppUpdate? found, {bool portable = false}) {
  return UpdateController(
    currentVersion: '1.0.0',
    portable: portable,
    fetch: ({required String currentVersion}) async => found,
  );
}

void main() {
  late Directory temporary;
  late OrganizerController controller;
  late UpdateController updates;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('dofus_settings_test');
    controller = OrganizerController(
      store: ConfigStore(directory: temporary),
      native: _SilentBridge(),
    );
    await controller.initialize();
    updates = updatesReturning(null);
  });

  tearDown(() async {
    await controller.flush();
    controller.dispose();
    if (temporary.existsSync()) await temporary.delete(recursive: true);
  });

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => SettingsDialog.show(
                context,
                controller: controller,
                updates: updates,
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
  }

  testWidgets('the settings carry a link to the project', (tester) async {
    await openSettings(tester);

    final mark = tester.widgetList<Image>(find.byType(Image)).where(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName == 'assets/github.png',
        );
    expect(mark, hasLength(1), reason: 'the GitHub mark must be shown');
    expect(find.byTooltip('Voir le projet sur GitHub'), findsOneWidget);
  });

  testWidgets('the removed shortcuts are gone from the settings',
      (tester) async {
    await openSettings(tester);

    expect(find.text('Afficher la fenêtre'), findsNothing);
    expect(find.text('Quitter le tool'), findsNothing);
  });

  testWidgets('an up to date build shows its version and nothing else',
      (tester) async {
    await openSettings(tester);

    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.textContaining('disponible'), findsNothing);
    expect(find.text('Mettre à jour'), findsNothing);
  });

  testWidgets('a published newer version is offered from the settings',
      (tester) async {
    updates = updatesReturning(const AppUpdate(
      version: '1.1.0',
      pageUrl: 'https://example.invalid/releases',
      installerUrl: 'https://example.invalid/installateur.exe',
    ));
    await openSettings(tester);

    expect(find.text('Version 1.1.0 disponible'), findsOneWidget);
    expect(find.text('Mettre à jour'), findsOneWidget);
  });
}
