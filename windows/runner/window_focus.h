#ifndef RUNNER_WINDOW_FOCUS_H_
#define RUNNER_WINDOW_FOCUS_H_

#include <windows.h>

#include <string>
#include <unordered_map>
#include <vector>

namespace dofus {

// Lowercases |title| so that it can be used as a needle by WindowFocus.
// Matching is case insensitive, so both the needles and the window titles are
// normalized through this function before comparison.
std::wstring NormalizeTitleNeedle(const std::wstring& title);

// Resolves top level windows by title substring and brings them to the
// foreground.
//
// Resolved handles are cached: as long as the highest priority target still
// points at a live window, a hotkey press costs a handle validation instead of
// a full window enumeration.
class WindowFocus {
 public:
  // Activates the first target owning a matching window. |needles| is ordered
  // by priority and must contain values produced by NormalizeTitleNeedle().
  // Returns the index of the activated target, or -1 when none matched.
  int ActivateFirstMatch(const std::vector<std::wstring>& needles);

  // Drops every cached handle. Must be called whenever the binding set
  // changes, so that stale entries cannot outlive their configuration.
  void ClearCache();

 private:
  // Returns the cached handle for |needle| when it is still valid, nullptr
  // otherwise. Invalid entries are evicted.
  HWND CachedLookup(const std::wstring& needle);

  std::unordered_map<std::wstring, HWND> cache_;
};

}  // namespace dofus

#endif  // RUNNER_WINDOW_FOCUS_H_
