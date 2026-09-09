import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'state/organizer_controller.dart';
import 'state/update_controller.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/update_dialog.dart';

/// Root widget wiring the notification area, the window lifecycle and the
/// organizer state together.
class OrganizerApp extends StatefulWidget {
  const OrganizerApp({
    super.key,
    required this.controller,
    required this.updates,
    this.startsHidden = false,
  });

  final OrganizerController controller;
  final UpdateController updates;

  /// Whether the window stays in the notification area at launch.
  final bool startsHidden;

  @override
  State<OrganizerApp> createState() => _OrganizerAppState();
}

class _OrganizerAppState extends State<OrganizerApp>
    with WindowListener, TrayListener {
  static const String _menuItemShow = 'show_window';
  static const String _menuItemQuit = 'quit_app';

  /// Lets the announcement be opened from outside the widget tree, since the
  /// window may come back from the notification area at any time.
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// True once the window has been on screen at least once.
  late bool _windowVisible = !widget.startsHidden;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    widget.controller.onShowRequested = _showWindow;
    widget.updates.addListener(_onUpdateState);
    _initTray();
    // Silent unless something newer exists, so it can run without asking.
    unawaited(widget.updates.check());
  }

  @override
  void dispose() {
    widget.updates.removeListener(_onUpdateState);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  void _onUpdateState() => _announceUpdate();

  /// Shows the announcement, but only once the window is actually on screen:
  /// a dialog opened behind a hidden window would be spent on nobody.
  void _announceUpdate() {
    if (!_windowVisible || !widget.updates.isPopupPending) return;
    final navigator = _navigator.currentState;
    if (navigator == null || !navigator.mounted) return;
    widget.updates.markPopupShown();
    UpdateDialog.show(
      navigator.context,
      controller: widget.updates,
      onQuit: _quit,
    );
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
    _windowVisible = true;
    // The announcement may have been waiting for the window to come back.
    _announceUpdate();
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
      navigatorKey: _navigator,
      home: HomeScreen(
        controller: widget.controller,
        updates: widget.updates,
        onQuit: _quit,
      ),
    );
  }
}
