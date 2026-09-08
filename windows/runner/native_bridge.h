#ifndef RUNNER_NATIVE_BRIDGE_H_
#define RUNNER_NATIVE_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

#include "hotkey_service.h"

namespace dofus {

// Exposes the native shortcut engine to the Dart side over a method channel.
//
// Dart owns the configuration and pushes it down; the activation path itself
// never goes through Dart, so a key press costs a window resolution and a
// foreground call, nothing more.
class NativeBridge {
 public:
  // |started_hidden| reports whether the process was launched with the
  // minimized flag, so that Dart can keep the window in the notification area.
  explicit NativeBridge(bool started_hidden);
  ~NativeBridge();

  NativeBridge(const NativeBridge&) = delete;
  NativeBridge& operator=(const NativeBridge&) = delete;

  // Binds the channel and starts the shortcut host window.
  void Initialize(flutter::BinaryMessenger* messenger);

  // Notifies Dart that a second instance tried to start, so that the window
  // can be restored from the notification area.
  void NotifySecondInstance();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<HotkeyService> hotkeys_;
  bool started_hidden_ = false;
};

}  // namespace dofus

#endif  // RUNNER_NATIVE_BRIDGE_H_
