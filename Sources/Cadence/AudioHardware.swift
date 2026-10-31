import AppKit
import CoreAudio

struct AudioFailure: LocalizedError {
    let operation: String
    let status: OSStatus
    var errorDescription: String? {
        "\(operation) failed (Core Audio \(status)). Check System Settings → Privacy & Security → Screen & System Audio Recording, then retry."
    }
}

enum Hardware {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func check(_ status: OSStatus, _ operation: String) throws {
        if status != noErr { throw AudioFailure(operation: operation, status: status) }
    }

    static func number<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, initial: T) throws -> T {
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        var key = address(selector)
        try withUnsafeMutablePointer(to: &value) { pointer in
            try check(AudioObjectGetPropertyData(object, &key, 0, nil, &size, pointer), "Read audio property")
        }
        return value
    }

    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var key = address(selector)
        try check(AudioObjectGetPropertyData(object, &key, 0, nil, &size, &value), "Read audio name")
        return value?.takeRetainedValue() as String? ?? ""
    }

    static func objects(_ object: AudioObjectID = system, _ selector: AudioObjectPropertySelector) throws -> [AudioObjectID] {
        var key = address(selector)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(object, &key, 0, nil, &size), "List audio objects")
        var values = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard !values.isEmpty else { return [] }
        try values.withUnsafeMutableBytes { bytes in
            try check(AudioObjectGetPropertyData(object, &key, 0, nil, &size, bytes.baseAddress!), "Read audio objects")
        }
        return values
    }

    static func output() throws -> OutputDevice {
        let id = try number(system, kAudioHardwarePropertyDefaultOutputDevice, initial: AudioObjectID(0))
        return OutputDevice(id: id, uid: try string(id, kAudioDevicePropertyDeviceUID), name: try string(id, kAudioObjectPropertyName),
            sampleRate: try number(id, kAudioDevicePropertyNominalSampleRate, initial: Float64(0)))
    }

    static func processes() throws -> [AudioProcess] {
        try objects(system, kAudioHardwarePropertyProcessObjectList).compactMap { id in
            guard let pid = try? number(id, kAudioProcessPropertyPID, initial: pid_t(0)), pid != getpid() else { return nil }
            let running = (try? number(id, kAudioProcessPropertyIsRunningOutput, initial: UInt32(0))) == 1
            let app = NSRunningApplication(processIdentifier: pid)
            let rawBundle = (try? string(id, kAudioProcessPropertyBundleID)) ?? ""
            // Browser renderers and Electron audio services live inside the parent .app.
            let url = app?.bundleURL ?? processBundleURL(pid)
            let parentURL = url.flatMap(outerApplication)
            let parent = parentURL.flatMap(Bundle.init(url:))
            var bundle = parent?.bundleIdentifier ?? app?.bundleIdentifier ?? rawBundle
            var name = (parent?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (parent?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? app?.localizedName ?? (bundle.isEmpty ? "Process \(pid)" : bundle)
            // WebKit's system-hosted XPC helpers are outside the owning app's bundle.
            if bundle.hasPrefix("com.apple.WebKit."), let host = NSWorkspace.shared.runningApplications.first(where: {
                $0.activationPolicy == .regular && $0.localizedName.map { name.hasPrefix($0 + " ") } == true
            }) {
                bundle = host.bundleIdentifier ?? bundle
                name = host.localizedName ?? name
                return AudioProcess(id: id, pid: pid, appID: bundle, name: name, bundleURL: host.bundleURL, running: running)
            }
            let key = bundle.isEmpty ? "process:\(pid)" : bundle
            return AudioProcess(id: id, pid: pid, appID: key, name: name, bundleURL: parentURL ?? url, running: running)
        }
    }

    private static func processBundleURL(_ pid: pid_t) -> URL? {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buffer))
    }

    static func outerApplication(_ url: URL) -> URL? {
        var current = url
        var result: URL?
        while current.path != "/" {
            if current.pathExtension == "app" { result = current }
            current.deleteLastPathComponent()
        }
        return result
    }
}

struct OutputDevice: Equatable {
    let id: AudioObjectID
    let uid: String
    let name: String
    let sampleRate: Float64
}

struct AudioProcess {
    let id: AudioObjectID
    let pid: pid_t
    let appID: String
    let name: String
    let bundleURL: URL?
    let running: Bool
}
