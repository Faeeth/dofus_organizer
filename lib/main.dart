import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/services/config_store.dart';
import 'src/services/native_bridge.dart';
import 'src/state/organizer_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final native = NativeBridge();
  final controller = OrganizerController(
    store: ConfigStore(),
    native: native,
  );
  await controller.initialize();

  // The runner already skipped the first show when the process was autostarted
  // with the minimized flag; the preference covers a manual launch.
  final startHidden =
      await native.startedHidden() || controller.settings.startMinimized;

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(720, 520),
      center: true,
      title: 'Dofus Organizer',
      backgroundColor: Color(0xFF0E1014),
    ),
    () async {
      // Closing is always intercepted; whether it hides or quits is decided in
      // the app shell from the current preference.
      await windowManager.setPreventClose(true);
      if (startHidden) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    },
  );

  runApp(OrganizerApp(controller: controller));
}
