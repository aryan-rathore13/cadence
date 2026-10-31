# Verification

The synthetic tests cover exact 25% sample gain, peak reporting and reset, gain bounds, mute ramping and sustained silence, nonfinite samples, short source buffers, settings serialization, and parent-application resolution for helpers.

The packaged app also provides a five-second process-tap check (`--verify-pid`). This validates tap and aggregate creation, active IO callbacks, and arrival of a nonzero source signal. It does not by itself measure physical speaker output or establish compatibility with every device or protected-media application.

Light and dark screenshot fixtures exercise the real native SwiftUI layout with representative sample data. They do not prove audio functionality.

## Local checks, 2026-10-31

- Native debug build compiled on Apple Silicon with macOS 27 and Swift 6.4.
- Six synthetic tests passed with zero failures.
- A quiet 440 Hz stereo signal played by a separate `afplay` process reached the packaged app's process tap on a Bluetooth stereo output: 437 IO callbacks in five seconds and input peak 0.030517563 at 25% gain. The route was destroyed after the check.
- Both native light and dark UI fixtures were rendered and visually inspected. Mixer contents scroll independently of the persistent header and footer.
- The final release build compiled without warnings; its ad-hoc signature passed strict verification. The app bundle is approximately 2 MB including its icon.
- The physical-input isolation test passed, followed by all seven synthetic tests with zero failures.
- The release app passed a second live check with 410 callbacks. Measured rendered/input peak ratios were exactly **0.25, 0, 0.75, and 1** for 25%, mute, 75%, and 100% gain respectively. This checks the live renderer's output buffers, not an acoustic measurement of the speakers.
- Installed successfully into `~/Applications/Cadence.app`; its signature passed strict verification. The installed binary passed the same four-stage live test with 411 callbacks and matching ratios.
- A sample of the open, active mixer reported approximately 28 MB physical footprint. CPU measurements included interaction and audio processing and should not be read as idle benchmarks. Meter polling stops when the mixer window or popover is closed.
- The final preference-refresh optimization passed all seven tests, and the updated release was installed successfully. The audio callback was unchanged by that optimization.
