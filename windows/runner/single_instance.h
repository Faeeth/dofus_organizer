#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

namespace dofus {

// Broadcast message asking the running instance to bring its window back.
// RegisterWindowMessage returns the same identifier in every process, so the
// second instance can reach the first one without knowing its handle.
UINT ShowWindowMessageId();

// Process wide lock making sure a single organizer owns the global shortcuts.
class SingleInstanceGuard {
 public:
  SingleInstanceGuard() = default;
  ~SingleInstanceGuard();

  SingleInstanceGuard(const SingleInstanceGuard&) = delete;
  SingleInstanceGuard& operator=(const SingleInstanceGuard&) = delete;

  // Returns false when another instance already holds the lock.
  bool Acquire();

  // Asks the instance already running to show its window.
  static void SignalRunningInstance();

 private:
  HANDLE mutex_ = nullptr;
};

}  // namespace dofus

#endif  // RUNNER_SINGLE_INSTANCE_H_
