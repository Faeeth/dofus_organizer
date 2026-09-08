import 'dart:io';

import 'package:dofus_organizer/src/services/config_store.dart';
import 'package:dofus_organizer/src/services/native_bridge.dart';
import 'package:dofus_organizer/src/state/organizer_controller.dart';
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

void main() {
  late Directory temporary;
  late OrganizerController controller;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('dofus_settings_test');
    controller = OrganizerController(
      store: ConfigStore(directory: temporary),
      native: _SilentBridge(),
    );
    await controller.initialize();
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
              onPressed: () =>
                  SettingsDialog.show(context, controller: controller),
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
}
