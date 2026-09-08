#ifndef RUNNER_STARTUP_REGISTRATION_H_
#define RUNNER_STARTUP_REGISTRATION_H_

namespace dofus {

// Command line flag telling the runner to start without showing the window,
// so that an autostarted organizer goes straight to the notification area.
extern const wchar_t kMinimizedFlag[];

// Reads/writes the per user autostart entry (HKCU Run key). The registered
// command always carries kMinimizedFlag.
bool IsStartupEnabled();
bool SetStartupEnabled(bool enabled);

}  // namespace dofus

#endif  // RUNNER_STARTUP_REGISTRATION_H_
