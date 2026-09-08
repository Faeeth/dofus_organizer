#ifndef RUNNER_HOTKEY_SERVICE_H_
#define RUNNER_HOTKEY_SERVICE_H_

#include <windows.h>

#include <functional>
#include <string>
#include <vector>

#include "window_focus.h"

namespace dofus {

// A shortcut bound to an ordered list of window title needles. Several
// characters may share the same shortcut: the first one whose window exists
// wins, which is how alternate teams are handled.
struct HotkeyBinding {
  std::string id;
  UINT modifiers = 0;  // MOD_ALT | MOD_CONTROL | MOD_SHIFT | MOD_WIN
  UINT key_code = 0;   // Virtual key code
  std::vector<std::wstring> needles;
};

// Owns the global shortcuts and performs the whole hotkey to foreground path
// natively: WM_HOTKEY is handled on the message loop, the window is resolved
// and activated, and only then is the Dart side notified.
class HotkeyService {
 public:
  // Invoked after a shortcut fired. |target_index| is the index of the
  // activated needle, or -1 when no window matched.
  using TriggerCallback =
      std::function<void(const std::string& id, int target_index)>;

  explicit HotkeyService(TriggerCallback on_trigger);
  ~HotkeyService();

  HotkeyService(const HotkeyService&) = delete;
  HotkeyService& operator=(const HotkeyService&) = delete;

  // Creates the message-only window hosting the shortcuts. Must be called from
  // the thread running the application message loop.
  bool Start();

  // Replaces the whole binding set. Returns the ids Windows refused to
  // register, typically because the shortcut is already owned by another
  // process.
  std::vector<std::string> Apply(std::vector<HotkeyBinding> bindings);

  // Unregisters the shortcuts without dropping the configuration, so that the
  // keys reach the focused application again (shortcut capture in the UI).
  void SetSuspended(bool suspended);

  bool suspended() const { return suspended_; }

 private:
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam);

  // Registers/unregisters every binding against the host window.
  std::vector<std::string> RegisterAll();
  void UnregisterAll();

  void OnHotkey(int index);

  TriggerCallback on_trigger_;
  WindowFocus focus_;
  std::vector<HotkeyBinding> bindings_;
  // Ids currently registered in Windows, kept to unregister exactly what was
  // registered even if |bindings_| changed meanwhile.
  std::vector<int> registered_;
  HWND host_ = nullptr;
  bool suspended_ = false;
};

}  // namespace dofus

#endif  // RUNNER_HOTKEY_SERVICE_H_
