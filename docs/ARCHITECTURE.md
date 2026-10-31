# Architecture

Cadence is a Swift Package producing a native macOS accessory application. It has no package dependencies, daemon, login helper, kernel extension, or virtual audio driver. Minimum deployment target is macOS 14.2, when public process-tap creation became available.

## Discovery and identity

`Hardware` reads the Core Audio process-object list, PID, bundle identifier, and output-running properties. NSRunningApplication and process executable paths map helpers to their outermost `.app`. Bundle identifiers provide stable preference keys; unbundled executables use PID-scoped identities. Discovery runs every two seconds with timer tolerance. Only output-active applications enter the list; recently active applications remain available under the inactive filter until their process exits.

## Audio route

Each output-active application owns one `AudioRoute`, combining its process objects in a private device-specific process tap. The tap targets stream zero of the default output device. A private aggregate device combines that tap as input with the physical device as output. Physical input channels are requested as zero: Cadence does not use the microphone. The tap uses `mutedWhenTapped`, so its original output is suppressed only while the aggregate consumes the tap.

The aggregate's IOProc is the C function in `AudioDSP`. It clears output buffers, multiplies valid floating-point samples by gain, smooths gain changes across the current buffer, and collects peak and callback counters with atomics. There are no allocations, locks, dispatches, Swift objects, logging, or file access in the callback. Gains are clamped to 0–1; the engine never boosts above the application's original volume. Effective gain combines per-app volume, app mute, master volume, global mute, and solo.

Route creation is transactional: any failure tears down already-created resources. Shutdown stops and destroys the IOProc before freeing callback state, then destroys the aggregate and tap. Default-output changes, process membership changes, sleep/wake, pause, and quit trigger cleanup or reconstruction. Failed routes are not retried repeatedly until the process membership/output changes or the user requests a retry.

## Interface and persistence

`MixerModel` owns the main-thread lifecycle, app preferences, route dictionary, and published presentation state. SwiftUI renders both the window and menu-bar popover; AppKit owns their lifecycle. Fifteen-Hz meter updates run only while the mixer is visible. The default SF system font, semantic colors, native controls, system materials, and SF Symbols follow macOS appearance and accessibility settings.

`UserDefaults` stores bundle-keyed app volumes/mutes, master attenuation, and whether the mixer is enabled. Audio buffers are never persisted. Login startup uses `SMAppService.mainApp`, with errors and pending system approval shown in Settings.

The default surface is a 320-point-wide menu-bar popover. Its height follows the visible application count, search, solo, and error states, with a 466-point cap. Longer lists scroll between a persistent header and footer. A SwiftUI size-change callback updates AppKit's popover or optional window; the window keeps its top edge fixed while resizing. Settings replaces the mixer inside the same panel instead of opening a larger sheet.

Both surfaces dismiss on outside mouse clicks and application focus loss. Mouse-only local/global NSEvent monitors are installed while the mixer is visible and removed on dismissal or termination. Local clicks inside the mixer and its status-bar button continue to their controls. The optional window also dismisses when it loses key status. Dismissal hides the UI and stops metering; it does not disable audio routes, alter levels, or quit the app.

## Distribution

The build script bundles the Swift executable, usage-description plist, and icon, signs locally, verifies the signature, and creates a ZIP. A stable local designated requirement preserves bundle identity across local builds. Public distribution requires a Developer ID identity, hardened runtime validation, and notarization; no such identity is assumed or generated here. CI compiles and runs synthetic tests on macOS without requesting audio access.
