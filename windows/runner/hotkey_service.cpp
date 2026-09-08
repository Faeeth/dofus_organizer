#include "hotkey_service.h"

namespace dofus {

namespace {

constexpr wchar_t kHostClassName[] = L"DofusOrganizerHotkeyHost";

// Hotkey identifiers are the binding indices shifted by one, since 0 is a
// valid but ambiguous RegisterHotKey identifier.
int IdForIndex(size_t index) {
  return static_cast<int>(index) + 1;
}

}  // namespace

HotkeyService::HotkeyService(TriggerCallback on_trigger)
    : on_trigger_(std::move(on_trigger)) {}

HotkeyService::~HotkeyService() {
  UnregisterAll();
  if (host_) {
    ::DestroyWindow(host_);
    host_ = nullptr;
  }
}

bool HotkeyService::Start() {
  if (host_) {
    return true;
  }

  HINSTANCE instance = ::GetModuleHandle(nullptr);
  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = HotkeyService::WndProc;
  window_class.hInstance = instance;
  window_class.lpszClassName = kHostClassName;
  // The class may already be registered when the service is restarted.
  ::RegisterClassExW(&window_class);

  // A message-only window keeps WM_HOTKEY out of the Flutter window procedure
  // while still being pumped by the application message loop.
  host_ = ::CreateWindowExW(0, kHostClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                            nullptr, instance, this);
  return host_ != nullptr;
}

std::vector<std::string> HotkeyService::Apply(
    std::vector<HotkeyBinding> bindings) {
  UnregisterAll();
  bindings_ = std::move(bindings);
  // Handles resolved for the previous configuration must not leak into the new
  // one.
  focus_.ClearCache();
  if (suspended_) {
    return {};
  }
  return RegisterAll();
}

void HotkeyService::SetSuspended(bool suspended) {
  if (suspended_ == suspended) {
    return;
  }
  suspended_ = suspended;
  if (suspended_) {
    UnregisterAll();
  } else {
    RegisterAll();
  }
}

std::vector<std::string> HotkeyService::RegisterAll() {
  std::vector<std::string> rejected;
  if (!host_) {
    return rejected;
  }
  for (size_t i = 0; i < bindings_.size(); ++i) {
    const HotkeyBinding& binding = bindings_[i];
    if (binding.key_code == 0) {
      continue;
    }
    // MOD_NOREPEAT keeps a held key from flooding the message loop with
    // redundant activations.
    if (::RegisterHotKey(host_, IdForIndex(i),
                         binding.modifiers | MOD_NOREPEAT, binding.key_code)) {
      registered_.push_back(IdForIndex(i));
    } else {
      rejected.push_back(binding.id);
    }
  }
  return rejected;
}

void HotkeyService::UnregisterAll() {
  if (host_) {
    for (int id : registered_) {
      ::UnregisterHotKey(host_, id);
    }
  }
  registered_.clear();
}

void HotkeyService::OnHotkey(int index) {
  if (index < 0 || static_cast<size_t>(index) >= bindings_.size()) {
    return;
  }
  const HotkeyBinding& binding = bindings_[static_cast<size_t>(index)];
  int target_index = focus_.ActivateFirstMatch(binding.needles);
  if (on_trigger_) {
    on_trigger_(binding.id, target_index);
  }
}

LRESULT CALLBACK HotkeyService::WndProc(HWND window, UINT message,
                                        WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCT*>(lparam);
    ::SetWindowLongPtr(window, GWLP_USERDATA,
                       reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (message == WM_HOTKEY) {
    auto* self = reinterpret_cast<HotkeyService*>(
        ::GetWindowLongPtr(window, GWLP_USERDATA));
    if (self) {
      self->OnHotkey(static_cast<int>(wparam) - 1);
      return 0;
    }
  }
  return ::DefWindowProc(window, message, wparam, lparam);
}

}  // namespace dofus
