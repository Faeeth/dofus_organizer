import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/app_version.dart';
import 'src/services/config_store.dart';
import 'src/services/native_bridge.dart';
import 'src/state/organizer_controller.dart';
import 'src/state/update_controller.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final native = NativeBridge();
  final controller = OrganizerController(
    store: ConfigStore(),
    native: native,
  );
  await controller.initialize();

  // The installer relaunches the organizer with this flag. Coming out of an
  // installation the window shows itself even when "start minimized" is on:
  // that preference is about ordinary launches, and after an update one wants
  // to see the tool come back. The preference itself is left untouched.
  final justUpdated = arguments.contains(updatedFlag);

  // The runner already skipped the first show when the process was autostarted
  // with the minimized flag; the preference covers a manual launch.
  final startHidden = !justUpdated &&
      (await native.startedHidden() || controller.settings.startMinimized);

  // The runner owns the first show: hiding the window from here instead would
  // race the show it performs on the first frame.
  await native.setStartHidden(hidden: startHidden);

  // No WindowOptions: size, minimum size and centering are handled by the
  // runner too. The plugin would convert them with the view device pixel
  // ratio, which is not available yet at this point and collapses the window.
  await windowManager.waitUntilReadyToShow(null, () async {
    // Closing is always intercepted; whether it hides or quits is decided in
    // the app shell from the current preference.
    await windowManager.setPreventClose(true);
  });

  final updates = UpdateController(
    portable: isPortableBuild,
    snoozedUntil: controller.settings.updateSnoozeUntil,
    onSnoozeChanged: controller.setUpdateSnooze,
  );

  runApp(OrganizerApp(
    controller: controller,
    updates: updates,
    startsHidden: startHidden,
  ));
}
