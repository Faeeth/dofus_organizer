#include "startup_registration.h"

#include <windows.h>

#include <string>

namespace dofus {

namespace {

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kValueName[] = L"DofusOrganizer";

// Returns the quoted executable path followed by the minimized flag.
std::wstring StartupCommand() {
  wchar_t path[MAX_PATH];
  DWORD length = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return std::wstring();
  }
  std::wstring command = L"\"";
  command.append(path, length);
  command.append(L"\" ");
  command.append(kMinimizedFlag);
  return command;
}

}  // namespace

const wchar_t kMinimizedFlag[] = L"--minimized";

bool IsStartupEnabled() {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_QUERY_VALUE, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  DWORD type = 0;
  DWORD size = 0;
  LSTATUS status =
      ::RegQueryValueExW(key, kValueName, nullptr, &type, nullptr, &size);
  ::RegCloseKey(key);
  return status == ERROR_SUCCESS && type == REG_SZ;
}

bool SetStartupEnabled(bool enabled) {
  if (!enabled) {
    HKEY key = nullptr;
    if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_SET_VALUE, &key) !=
        ERROR_SUCCESS) {
      return false;
    }
    LSTATUS status = ::RegDeleteValueW(key, kValueName);
    ::RegCloseKey(key);
    return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND;
  }

  std::wstring command = StartupCommand();
  if (command.empty()) {
    return false;
  }
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0, KEY_SET_VALUE,
                        nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  LSTATUS status = ::RegSetValueExW(
      key, kValueName, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

}  // namespace dofus
