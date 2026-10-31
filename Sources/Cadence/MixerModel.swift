import AppKit
import Combine
import CoreAudio
import ServiceManagement

struct ChannelSettings: Codable, Equatable {
    var volume: Double = 1
    var muted = false
    var gain: Float { muted ? 0 : Float(min(1, max(0, volume))) }
}

struct MixerChannel: Identifiable, Equatable {
    let id: String
    var name: String
    var icon: NSImage
    var processIDs: [AudioObjectID]
    var running: Bool
    var settings: ChannelSettings
    var peak: Float = 0
    var error: String?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.processIDs == rhs.processIDs
            && lhs.running == rhs.running && lhs.settings == rhs.settings
            && lhs.peak == rhs.peak && lhs.error == rhs.error
    }
}

@MainActor
final class MixerModel: ObservableObject {
    @Published var channels: [MixerChannel] = []
    @Published var outputName = "Finding output…"
    @Published var enabled = false
    @Published var master: Double = 1
    @Published var masterMuted = false
    @Published var error: String?
    @Published var soloID: String?
    @Published var showInactive = false
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?

    private var saved: [String: ChannelSettings] = [:]
    private var routes: [String: AudioRoute] = [:]
    private var failed: [String: [AudioObjectID]] = [:]
    private var output: OutputDevice?
    private var discoveryTimer: Timer?
    private var meterTimer: Timer?
    private let defaults: UserDefaults
    private var wakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard, startMonitoring: Bool = true) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "channels"),
           let settings = try? JSONDecoder().decode([String: ChannelSettings].self, from: data) {
            saved = settings
        }
        master = defaults.object(forKey: "master") as? Double ?? 1
        master = min(1, max(0, master))
        // Do not restore global mute or solo across launches.
        enabled = defaults.bool(forKey: "enabled")
        guard startMonitoring else { return }
        refresh()
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        discoveryTimer?.tolerance = 0.4
        let center = NSWorkspace.shared.notificationCenter
        wakeObserver = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.retry() }
        }
        sleepObserver = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.routes.removeAll() }
        }
    }

    var visibleChannels: [MixerChannel] { channels.filter { showInactive || $0.running } }
    var activeCount: Int { channels.filter(\.running).count }
    var controlledCount: Int { routes.count }

    func setEnabled(_ value: Bool) {
        enabled = value
        defaults.set(value, forKey: "enabled")
        if !value { routes.removeAll(); soloID = nil }
        failed.removeAll()
        refresh()
    }

    func setVolume(_ id: String, _ value: Double) {
        update(id) { $0.volume = min(1, max(0, value)) }
    }

    func toggleMute(_ id: String) { update(id) { $0.muted.toggle() } }

    private func update(_ id: String, _ change: (inout ChannelSettings) -> Void) {
        guard let index = channels.firstIndex(where: { $0.id == id }) else { return }
        change(&channels[index].settings)
        saved[id] = channels[index].settings
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: "channels") }
        applyGains()
    }

    func setMaster(_ value: Double) {
        master = min(1, max(0, value))
        defaults.set(master, forKey: "master")
        applyGains()
    }

    func toggleMasterMute() { masterMuted.toggle(); applyGains() }
    func toggleSolo(_ id: String) { soloID = soloID == id ? nil : id; applyGains() }

    private func gain(for channel: MixerChannel) -> Float {
        if masterMuted || (soloID != nil && soloID != channel.id) { return 0 }
        return channel.settings.gain * Float(master)
    }

    private func applyGains() {
        for channel in channels { routes[channel.id]?.setGain(gain(for: channel)) }
    }

    func refresh() {
        do {
            let newOutput = try Hardware.output()
            if output != newOutput {
                routes.removeAll()
                failed.removeAll()
                output = newOutput
            }
            if outputName != newOutput.name { outputName = newOutput.name }
            let grouped = Dictionary(grouping: try Hardware.processes(), by: \.appID)
            let old = Dictionary(uniqueKeysWithValues: channels.map { ($0.id, $0) })
            let updatedChannels = grouped.compactMap { id, processes -> MixerChannel? in
                guard let first = processes.first else { return nil }
                let running = processes.contains(where: \.running)
                // Keep paused channels while their process exists; never show input-only apps.
                guard running || old[id] != nil else { return nil }
                let url = first.bundleURL
                let icon = old[id]?.icon ?? url.map { NSWorkspace.shared.icon(forFile: $0.path) }
                    ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)!
                return MixerChannel(id: id, name: first.name, icon: icon,
                    processIDs: processes.map(\.id).sorted(), running: running,
                    settings: saved[id] ?? ChannelSettings(), peak: old[id]?.peak ?? 0,
                    error: old[id]?.error)
            }.sorted {
                if $0.running != $1.running { return $0.running }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            if updatedChannels != channels { channels = updatedChannels }
            if let soloID, !channels.contains(where: { $0.id == soloID && $0.running }) { self.soloID = nil }
            let activeIDs = Set(channels.filter(\.running).map(\.id))
            for id in Array(routes.keys) where !activeIDs.contains(id) { routes.removeValue(forKey: id) }
            failed = failed.filter { activeIDs.contains($0.key) }
            if enabled {
                for index in channels.indices where channels[index].running {
                    let channel = channels[index]
                    if let route = routes[channel.id], route.processIDs != channel.processIDs {
                        routes.removeValue(forKey: channel.id)
                        failed.removeValue(forKey: channel.id)
                    }
                    guard routes[channel.id] == nil, failed[channel.id] != channel.processIDs else { continue }
                    do {
                        routes[channel.id] = try AudioRoute(processIDs: channel.processIDs, output: newOutput, gain: gain(for: channel))
                        channels[index].error = nil
                    } catch {
                        channels[index].error = error.localizedDescription
                        failed[channel.id] = channel.processIDs
                    }
                }
                applyGains()
            }
            if error != nil { error = nil }
        } catch {
            routes.removeAll()
            self.error = error.localizedDescription
        }
    }

    func retry() {
        routes.removeAll()
        failed.removeAll()
        refresh()
    }

    func reset() {
        saved.removeAll()
        defaults.removeObject(forKey: "channels")
        for index in channels.indices { channels[index].settings = ChannelSettings() }
        soloID = nil
        masterMuted = false
        setMaster(1)
    }

    func setMetering(_ visible: Bool) {
        meterTimer?.invalidate()
        meterTimer = nil
        guard visible else { return }
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.readMeters() }
        }
        meterTimer?.tolerance = 0.02
    }

    private func readMeters() {
        for index in channels.indices {
            let peak = routes[channels[index].id]?.takePeak() ?? 0
            let decayed = max(peak, channels[index].peak * 0.72)
            let next: Float = decayed < 0.0001 ? 0 : decayed
            if abs(next - channels[index].peak) > 0.0001 || (next == 0 && channels[index].peak != 0) {
                channels[index].peak = next
            }
        }
    }

    func setLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginError = SMAppService.mainApp.status == .requiresApproval
                ? "Allow Cadence in System Settings → General → Login Items." : nil
        } catch { loginError = error.localizedDescription }
    }

    func shutdown() {
        discoveryTimer?.invalidate()
        setMetering(false)
        routes.removeAll()
        let center = NSWorkspace.shared.notificationCenter
        if let wakeObserver { center.removeObserver(wakeObserver) }
        if let sleepObserver { center.removeObserver(sleepObserver) }
    }
}
