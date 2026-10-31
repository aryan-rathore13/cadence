# Initial publication review

Destination: the private repository **aryan-rathore13/cadence**, branch **main**.

This initial commit contains the complete native application, local packaging and installation scripts, synthetic audio tests, live verification tooling, CI, documentation, and design fixtures. Build products, local preferences, diagnostic output, and approval markers are excluded.

| File | What it adds and why |
| --- | --- |
| `Package.swift` | A dependency-free Swift executable and C audio module, with a macOS 14.2 minimum and an audio test target. |
| `Sources/Cadence/main.swift` | Starts the native app; offers read-only process diagnostics and a controlled live gain-verification command. |
| `Sources/Cadence/AppDelegate.swift` | Owns the menu-bar item, mixer window, popover, single-instance behavior, termination cleanup, and sample-data screenshot rendering. |
| `Sources/Cadence/AudioHardware.swift` | Discovers the output device and audio processes, groups helpers under their applications, and reads Core Audio properties. |
| `Sources/Cadence/AudioRoute.swift` | Creates and destroys each application's private tap and aggregate output; validates sample format and disables physical inputs. |
| `Sources/Cadence/MixerModel.swift` | Coordinates discovery, route lifecycle, per-app and master levels, mute/solo, saved settings, login startup, and visible-only metering. |
| `Sources/Cadence/MixerView.swift` | Provides the native light/dark mixer, application rows, sliders, search, empty states, errors, and settings. |
| `Sources/AudioDSP/include/AudioDSP.h` | Declares the small C interface for gain state, metering, input configuration, and the real-time callback. |
| `Sources/AudioDSP/AudioDSP.c` | Applies bounded gain without real-time allocations or locks; clears unused buffers, excludes physical inputs, and publishes atomic signal measurements. |
| `Resources/Info.plist` | Defines the app identity, version, menu-bar behavior, deployment target, and explanation for macOS system-audio permission. |
| `Resources/AppIcon.icns` | Supplies the custom purple waveform icon used by Finder and the app bundle. |
| `Tests/CadenceTests/AudioDSPTests.swift` | Checks exact gain, mute transitions, gain bounds, unsafe samples and short buffers, microphone-input exclusion, settings serialization, and helper identity. |
| `scripts/build.sh` | Creates and locally signs the app bundle, verifies the signature, and packages a ZIP. |
| `scripts/install.sh` | Installs into the user's Applications directory and launches the app; refuses to overwrite a running copy. |
| `scripts/verify-audio.py` | Generates a short quiet tone in a temporary directory, plays it in a separate process, verifies live volume/mute ratios, and removes the tone. |
| `scripts/GenerateIcon.swift` | Recreates the icon artwork using native drawing, with no downloaded assets or image-generation dependency. |
| `.github/workflows/ci.yml` | Runs a scoped audio smoke test, the complete tests, and app packaging on macOS; uploads the ZIP as a workflow artifact. |
| `.gitignore` | Excludes builds, IDE state, Finder metadata, and ephemeral commit-specific push approval markers. |
| `README.md` | Explains installation, permissions, controls, local builds, diagnostics, and compatibility boundaries. |
| `docs/ARCHITECTURE.md` | Describes process grouping, per-app routing, callback constraints, persistence, and local signing. |
| `docs/VERIFICATION.md` | Records what the synthetic tests and real-device measurements establish, including their limits. |
| `docs/images/cadence-light.png` | Shows the real light-mode SwiftUI layout using an explicit sample-data fixture. |
| `docs/images/cadence-dark.png` | Shows the corresponding native dark appearance using the same fixture. |
| `docs/PUBLISH_REVIEW.md` | Records this file-by-file publication review for inspection. |
| `LICENSE` | Makes the project available under the MIT License. |

## Behavior to review

macOS system-audio capture permission is required to adjust other applications' audio. Cadence does not request microphone capture. While a route runs, its process tap suppresses the original playback and Cadence sends gain-adjusted audio to the output. Pausing or quitting destroys those routes, restoring original playback. Levels and app mute preferences stay in the user's local settings.

The route transition is the main operational consideration: restarting a route can briefly interrupt playback. Unsupported output formats report an error and release partial resources. Physical inputs are disabled and never selected by the renderer. Local ad-hoc signing is suitable for this installed copy; general distribution still needs Developer ID signing and notarization.

No secrets, credentials, `.env` files, authentication code, payment code, or database migrations are included. Git author identity is configured locally to the personal account's GitHub noreply address. No global Git configuration was changed.

Review question: **What happens to an application's original playback when Cadence is paused or quit, and which macOS permission is needed for its per-app controls?**
