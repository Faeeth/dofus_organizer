#include "single_instance.h"

namespace dofus {

namespace {

// Session local: two different users may run their own organizer.
constexpr wchar_t kMutexName[] = L"Local\\DofusOrganizerSingleInstance";
constexpr wchar_t kShowMessageName[] = L"DofusOrganizerShowWindow";

}  // namespace

UINT ShowWindowMessageId() {
  static const UINT id = ::RegisterWindowMessageW(kShowMessageName);
  return id;
}

SingleInstanceGuard::~SingleInstanceGuard() {
  if (mutex_) {
    ::ReleaseMutex(mutex_);
    ::CloseHandle(mutex_);
    mutex_ = nullptr;
  }
}

bool SingleInstanceGuard::Acquire() {
  mutex_ = ::CreateMutexW(nullptr, TRUE, kMutexName);
  if (mutex_ == nullptr) {
    // Without the lock the shortcuts cannot be arbitrated; fail closed.
    return false;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(mutex_);
    mutex_ = nullptr;
    return false;
  }
  return true;
}

void SingleInstanceGuard::SignalRunningInstance() {
  // The running instance may be hidden in the notification area, which still
  // receives broadcast messages as a top level window.
  ::PostMessageW(HWND_BROADCAST, ShowWindowMessageId(), 0, 0);
}

}  // namespace dofus
