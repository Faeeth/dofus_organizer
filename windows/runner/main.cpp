#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "single_instance.h"
#include "startup_registration.h"
#include "utils.h"

namespace {

// Centers |window| on the work area of the monitor hosting it, so the window
// does not open under the taskbar or across two screens.
void CenterOnWorkArea(HWND window) {
  RECT frame;
  if (window == nullptr || !::GetWindowRect(window, &frame)) {
    return;
  }
  MONITORINFO monitor = {};
  monitor.cbSize = sizeof(monitor);
  if (!::GetMonitorInfoW(::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                         &monitor)) {
    return;
  }
  const LONG width = frame.right - frame.left;
  const LONG height = frame.bottom - frame.top;
  const LONG x =
      monitor.rcWork.left + (monitor.rcWork.right - monitor.rcWork.left - width) / 2;
  const LONG y =
      monitor.rcWork.top + (monitor.rcWork.bottom - monitor.rcWork.top - height) / 2;
  ::SetWindowPos(window, nullptr, x, y, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Only one organizer may own the global shortcuts: hand the focus back to
  // the instance already running and exit.
  dofus::SingleInstanceGuard guard;
  if (!guard.Acquire()) {
    dofus::SingleInstanceGuard::SignalRunningInstance();
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  const std::string minimized_flag = Utf8FromUtf16(dofus::kMinimizedFlag);
  bool start_hidden =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                minimized_flag) != command_line_arguments.end();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // The window geometry is owned by the runner: the Dart side would have to
  // convert it through a device pixel ratio that is not available yet before
  // the first frame.
  FlutterWindow window(project, start_hidden);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1100, 720);
  if (!window.Create(L"Dofus Organizer", origin, size)) {
    return EXIT_FAILURE;
  }
  CenterOnWorkArea(window.GetHandle());
  // Dart intercepts the close request to hide the window instead; reaching
  // WM_DESTROY therefore means an explicit quit.
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
