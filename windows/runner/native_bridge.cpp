#include "native_bridge.h"

#include <flutter/standard_method_codec.h>

#include "startup_registration.h"
#include "utils.h"

namespace dofus {

namespace {

constexpr char kChannelName[] = "dofus_organizer/native";
constexpr char kMethodApply[] = "hotkeys.apply";
constexpr char kMethodSetSuspended[] = "hotkeys.setSuspended";
constexpr char kMethodFocus[] = "window.focus";
constexpr char kMethodStartedHidden[] = "app.startedHidden";
constexpr char kMethodStartHidden[] = "window.setStartHidden";
constexpr char kMethodStartupGet[] = "startup.isEnabled";
constexpr char kMethodStartupSet[] = "startup.setEnabled";
constexpr char kEventHotkey[] = "onHotkey";
constexpr char kEventSecondInstance[] = "onSecondInstance";

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

// Reads |key| from |map| when it holds a value of type T, otherwise returns
// |fallback|.
template <typename T>
T ValueOr(const EncodableMap& map, const char* key, T fallback) {
  auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return fallback;
  }
  const auto* value = std::get_if<T>(&it->second);
  return value ? *value : fallback;
}

// Converts one Dart binding descriptor. Returns false when the payload is not
// usable, so that a malformed entry cannot silently register a wrong shortcut.
bool ParseBinding(const EncodableValue& value, HotkeyBinding* binding) {
  const auto* map = std::get_if<EncodableMap>(&value);
  if (map == nullptr) {
    return false;
  }
  binding->id = ValueOr<std::string>(*map, "id", "");
  binding->modifiers =
      static_cast<UINT>(ValueOr<int32_t>(*map, "modifiers", 0));
  binding->key_code = static_cast<UINT>(ValueOr<int32_t>(*map, "keyCode", 0));
  if (binding->id.empty() || binding->key_code == 0) {
    return false;
  }

  auto targets = map->find(EncodableValue("targets"));
  if (targets == map->end()) {
    return false;
  }
  const auto* list = std::get_if<EncodableList>(&targets->second);
  if (list == nullptr) {
    return false;
  }
  for (const EncodableValue& entry : *list) {
    const auto* title = std::get_if<std::string>(&entry);
    if (title == nullptr || title->empty()) {
      continue;
    }
    binding->needles.push_back(NormalizeTitleNeedle(Utf16FromUtf8(*title)));
  }
  // An empty target list is valid: application commands (quit, show window)
  // are registered the same way and only reported back to Dart.
  return true;
}

}  // namespace

NativeBridge::NativeBridge(bool started_hidden)
    : started_hidden_(started_hidden) {}

NativeBridge::~NativeBridge() = default;

void NativeBridge::Initialize(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());

  hotkeys_ = std::make_unique<HotkeyService>(
      [this](const std::string& id, int target_index) {
        if (!channel_) {
          return;
        }
        channel_->InvokeMethod(
            kEventHotkey,
            std::make_unique<EncodableValue>(EncodableMap{
                {EncodableValue("id"), EncodableValue(id)},
                {EncodableValue("targetIndex"), EncodableValue(target_index)},
            }));
      });
  hotkeys_->Start();

  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

void NativeBridge::NotifySecondInstance() {
  if (channel_) {
    channel_->InvokeMethod(kEventSecondInstance,
                           std::make_unique<EncodableValue>());
  }
}

void NativeBridge::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (!hotkeys_) {
    result->Error("unavailable", "Native hotkey service is not initialized");
    return;
  }

  if (call.method_name() == kMethodApply) {
    const auto* list = std::get_if<EncodableList>(call.arguments());
    if (list == nullptr) {
      result->Error("bad_arguments", "Expected a list of bindings");
      return;
    }
    std::vector<HotkeyBinding> bindings;
    bindings.reserve(list->size());
    for (const EncodableValue& entry : *list) {
      HotkeyBinding binding;
      if (ParseBinding(entry, &binding)) {
        bindings.push_back(std::move(binding));
      }
    }
    EncodableList rejected;
    for (const std::string& id : hotkeys_->Apply(std::move(bindings))) {
      rejected.push_back(EncodableValue(id));
    }
    result->Success(EncodableValue(rejected));
    return;
  }

  if (call.method_name() == kMethodSetSuspended) {
    const auto* suspended = std::get_if<bool>(call.arguments());
    if (suspended == nullptr) {
      result->Error("bad_arguments", "Expected a boolean");
      return;
    }
    hotkeys_->SetSuspended(*suspended);
    result->Success();
    return;
  }

  if (call.method_name() == kMethodFocus) {
    const auto* title = std::get_if<std::string>(call.arguments());
    if (title == nullptr) {
      result->Error("bad_arguments", "Expected a window title");
      return;
    }
    WindowFocus focus;
    int index = focus.ActivateFirstMatch(
        {NormalizeTitleNeedle(Utf16FromUtf8(*title))});
    result->Success(EncodableValue(index >= 0));
    return;
  }

  if (call.method_name() == kMethodStartHidden) {
    const auto* hidden = std::get_if<bool>(call.arguments());
    if (hidden == nullptr) {
      result->Error("bad_arguments", "Expected a boolean");
      return;
    }
    if (initial_visibility_handler_) {
      initial_visibility_handler_(!*hidden);
    }
    result->Success();
    return;
  }

  if (call.method_name() == kMethodStartedHidden) {
    result->Success(EncodableValue(started_hidden_));
    return;
  }

  if (call.method_name() == kMethodStartupGet) {
    result->Success(EncodableValue(IsStartupEnabled()));
    return;
  }

  if (call.method_name() == kMethodStartupSet) {
    const auto* enabled = std::get_if<bool>(call.arguments());
    if (enabled == nullptr) {
      result->Error("bad_arguments", "Expected a boolean");
      return;
    }
    if (!SetStartupEnabled(*enabled)) {
      result->Error("registry_error", "Could not update the autostart entry");
      return;
    }
    result->Success(EncodableValue(*enabled));
    return;
  }

  result->NotImplemented();
}

}  // namespace dofus
