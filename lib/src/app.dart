import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'state/organizer_controller.dart';
import 'state/update_controller.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

/// Root widget wiring the notification area, the window lifecycle and the
/// organizer state together.
class OrganizerApp extends StatefulWidget {
  const OrganizerApp({
    super.key,
    required this.controller,
    required this.updates,
  });

  final OrganizerController controller;
  final UpdateController updates;

  @override
  State<OrganizerApp> createState() => _OrganizerAppState();
}

class _OrganizerAppState extends State<OrganizerApp>
    with WindowListener, TrayListener {
  static const String _menuItemShow = 'show_window';
  static const String _menuItemQuit = 'quit_app';

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    widget.controller.onShowRequested = _showWindow;
    _initTray();
    // Silent unless something newer exists, so it can run without asking.
    unawaited(widget.updates.checkOnce());
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('Dofus Organizer');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: _menuItemShow, label: 'Ouvrir le menu'),
      MenuItem.separator(),
      MenuItem(key: _menuItemQuit, label: 'Fermer'),
    ]));
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _hideWindow() => windowManager.hide();

  /// Terminates the organizer: the pending configuration is written first,
  /// then the tray icon is removed so it cannot survive the process.
  Future<void> _quit() async {
    await widget.controller.flush();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    exit(0);
  }

  @override
  void onWindowClose() {
    if (widget.controller.settings.closeToTray) {
      _hideWindow();
    } else {
      _quit();
    }
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _menuItemShow:
        _showWindow();
      case _menuItemQuit:
        _quit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dofus Organizer',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(
        controller: widget.controller,
        updates: widget.updates,
        onQuit: _quit,
      ),
    );
  }
}
