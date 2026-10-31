import AppKit
import CoreAudio
import SwiftUI

if CommandLine.arguments.contains("--diagnose") { do {
    let output = try Hardware.output()
    print("Output: \(output.name) [\(output.id)]")
    for process in try Hardware.processes() {
        print("\(process.running ? "PLAYING" : "idle") \(process.name) pid=\(process.pid) audio=\(process.id) bundle=\(process.appID)")
    }
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
exit(0)
}

let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--verify-pid"), arguments.count > index + 1,
   let pid = pid_t(arguments[index + 1]) {
    do {
        let processes = try Hardware.processes().filter { $0.pid == pid }
        guard !processes.isEmpty else { throw AudioFailure(operation: "Find playing process", status: -1) }
        let route = try AudioRoute(processIDs: processes.map(\.id), output: Hardware.output(), gain: 0.25)
        var success = true
        for gain: Float in [0.25, 0, 0.75, 1] {
            route.setGain(gain)
            Thread.sleep(forTimeInterval: 0.15)
            _ = route.takePeak()
            _ = route.takeOutputPeak()
            var peak: Float = 0
            var outputPeak: Float = 0
            for _ in 0..<10 {
                Thread.sleep(forTimeInterval: 0.1)
                peak = max(peak, route.takePeak())
                outputPeak = max(outputPeak, route.takeOutputPeak())
            }
            let ratio = peak > 0 ? outputPeak / peak : 0
            print("Gain \(Int(gain * 100))%: input peak=\(peak), rendered peak=\(outputPeak), ratio=\(ratio)")
            success = success && peak > 0.00001 && abs(ratio - gain) < 0.01
        }
        success = success && route.callbackCount > 0
        print("Audio callbacks: \(route.callbackCount)")
        route.stop()
        print(success ? "PASS: live attenuation, mute, volume change, and unity gain verified; route released." : "FAIL: expected audio levels were not observed. Allow system audio access and retry while audio plays.")
        exit(success ? 0 : 2)
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
