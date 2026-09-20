---
title: Reuse the existing macOS instance for duplicate launches
module: macOS application lifecycle
problem_type: duplicate-launch-handling
component: Sources/SpotiBind/ApplicationDelegate.swift
tags:
  - macos
  - appkit
  - launch-services
  - single-instance
  - window-lifecycle
status: active
related_specs:
  - docs/specs/spotibind/SPEC.md
---

# Reuse the existing macOS instance for duplicate launches

## Context

A menu-bar application can be launched again from Finder, Dock, Spotlight, or
another Launch Services entry while its first instance is still running. The
second launch should feel like a handoff to the running application: it must
bring the application's primary user-facing window forward instead of looking
like a failed launch.

In SpotiBind, the application has no separate desktop `main-window` surface.
The retained Advanced Settings window is the primary window for this handoff;
the menu-bar popover remains a separate transient surface.

## Symptoms

- A second launch appears to do nothing when the app is resident in the menu
  bar or its window is hidden.
- A minimized settings window remains minimized or is not key/front after the
  second launch.
- Recreating the window on every launch produces duplicate windows and loses
  geometry, scroll position, or unsaved SwiftUI edits.
- Switching to a regular activation policy to show the window leaves the app
  permanently visible in the Dock or menu bar after the window closes.

## Root cause

`LSMultipleInstancesProhibited` makes a second Launch Services request target the
existing process. It does not automatically decide which window the existing
application should show. AppKit delivers the request through
`applicationShouldHandleReopen(_:hasVisibleWindows:)`; ignoring that callback
leaves a menu-bar application with no visible response.

The callback's `hasVisibleWindows` value describes the current window state, not
whether the user wants the application foregrounded. Treating `false` as a
reason to ignore the request is therefore incorrect. A second common mistake
is to create a new controller instead of reusing the retained controller, which
breaks state and window identity.

## Resolution

1. Keep the native single-instance contract in the application bundle:
   `LSMultipleInstancesProhibited=true` and `LSUIElement=true`.
2. Implement `applicationShouldHandleReopen` and route both `true` and `false`
   `hasVisibleWindows` cases to the same `showSettingsWindow()` path. Return
   `true` after accepting the request.
3. Make `showSettingsWindow()` the single presenter for menu actions, duplicate
   launches, and UI-demo entry points. Lazily create one presenter and retain it
   for the process lifetime. A small presenter factory seam makes this routing
   testable without starting another process.
4. On presentation, preserve the existing window and SwiftUI state. The
   controller should show the window, deminiaturize it, activate the application
   while ignoring the current foreground app, and then call
   `makeKeyAndOrderFront`.
5. When the settings window closes, restore the shipped application's
   `accessory` activation policy. Opening the window temporarily uses
   `regular`, so it can become key/front without changing the normal menu-bar
   behavior.
6. If a Launch Services reopen arrives while the application is still launching,
   record the request and present the retained window after launch finishes.

The essential AppKit shape is:

```swift
func applicationShouldHandleReopen(
    _ application: NSApplication,
    hasVisibleWindows: Bool
) -> Bool {
    showPrimaryWindow()
    return true
}

func showAndActivate() {
    showWindow(nil)
    window?.deminiaturize(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
}
```

The actual app keeps activation-policy transitions in a separate presentation
controller and keeps window ownership in `ApplicationDelegate` and
`SettingsWindowController`.

## Guardrails / Reuse notes

- Do not add a custom process lock, socket, distributed notification, or private
  API when Launch Services single-instance behavior already covers the product
  boundary.
- Do not use `applicationDidBecomeActive` as a global fallback; ordinary focus
  changes would unexpectedly open settings.
- Do not re-center, resize, replace the hosting controller, or recreate the
  SwiftUI state during a duplicate launch.
- Make the reopen operation idempotent. Repeated requests must reuse the same
  process, event tap, window controller, and window.
- Test a hidden and a minimized window separately. A successful
  `makeKeyAndOrderFront` call also requires the application to use a compatible
  activation policy.
- Verify the behavior with a packaged application through normal Launch
  Services startup. Do not use `open -n`, because that intentionally requests a
  second instance and bypasses the product contract.

## Verification

Unit tests should prove that both `hasVisibleWindows` values route once through
the presenter, repeated calls create only one presenter, and closing the
window restores the accessory policy. Window tests should prove visibility,
restoration from minimization, frame preservation, and key/front behavior.

The packaged-app check should record one PID and one event tap before and after
a second normal launch request. It should also verify one settings window,
preserved frame and unsaved state, regular activation while open, and accessory
activation after close. Starting the app again after terminating the original
process must create a normal fresh instance.

## References

- `Sources/SpotiBind/ApplicationDelegate.swift`
- `Sources/SpotiBind/ApplicationPresentationController.swift`
- `Sources/SpotiBind/SettingsWindowController.swift`
- `Tests/SpotiBindAppTests/ApplicationDelegateTests.swift`
- `Tests/SpotiBindAppTests/ApplicationPresentationTests.swift`
- `packaging/macos/Info.plist`
- `docs/specs/spotibind/SPEC.md`
