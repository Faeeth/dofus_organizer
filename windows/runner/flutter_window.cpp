#include "flutter_window.h"

#include <optional>

namespace {

// Smallest usable size, in logical pixels, scaled to the window DPI.
constexpr LONG kMinimumWidth = 720;
constexpr LONG kMinimumHeight = 520;

}  // namespace

#include "flutter/generated_plugin_registrant.h"
#include "single_instance.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             bool start_hidden)
    : project_(project), start_hidden_(start_hidden) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  bridge_ = std::make_unique<dofus::NativeBridge>(start_hidden_);
  bridge_->set_initial_visibility_handler(
      [this](bool visible) { start_hidden_ = !visible; });
  bridge_->Initialize(flutter_controller_->engine()->messenger());

  // The first frame only happens after Dart applied its preference, so the
  // decision is settled by the time this runs.
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (!start_hidden_) {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  bridge_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // A second process asked this instance to come back to the foreground.
  // Handled before Flutter so that no plugin can swallow the broadcast.
  if (message == dofus::ShowWindowMessageId() && bridge_) {
    bridge_->NotifySecondInstance();
    return 0;
  }

  if (message == WM_GETMINMAXINFO) {
    const double scale = ::GetDpiForWindow(hwnd) / 96.0;
    auto* bounds = reinterpret_cast<MINMAXINFO*>(lparam);
    bounds->ptMinTrackSize.x = static_cast<LONG>(kMinimumWidth * scale);
    bounds->ptMinTrackSize.y = static_cast<LONG>(kMinimumHeight * scale);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
