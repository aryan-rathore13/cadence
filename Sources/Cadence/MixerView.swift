import SwiftUI

private let accent = Color(red: 0.59, green: 0.48, blue: 0.96)

struct MixerView: View {
    static let width: CGFloat = 320
    @ObservedObject var model: MixerModel
    @State private var search = ""
    @State private var settings: Bool
    let onResize: ((CGFloat) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    init(model: MixerModel, initiallyShowingSettings: Bool = false, onResize: ((CGFloat) -> Void)? = nil) {
        self.model = model
        _settings = State(initialValue: initiallyShowingSettings)
        self.onResize = onResize
    }

    private var filtered: [MixerChannel] {
        model.visibleChannels.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var showsSearch: Bool { model.visibleChannels.count > 4 || !search.isEmpty }

    var preferredHeight: CGFloat {
        if settings { return model.loginError == nil ? 294 : 334 }
        let rows = filtered.isEmpty ? 70 : CGFloat(min(filtered.count, 4)) * 53
        let errors = CGFloat(filtered.filter { $0.error != nil }.count) * 22
        return min(466, 210 + rows + errors + (model.enabled ? 0 : 76)
            + (showsSearch ? 36 : 0) + (model.error == nil ? 0 : 62)
            + (model.soloID == nil ? 0 : 26))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if settings {
                settingsContent
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !model.enabled { welcome }
                        outputCard
                        if let error = model.error { errorCard(error) }
                        applicationSection
                    }
                    .padding(14)
                }
                footer
            }
        }
        .font(.system(size: 12))
        .controlSize(.small)
        .frame(width: Self.width, height: preferredHeight)
        .background(.regularMaterial)
        .tint(accent)
        .onChange(of: preferredHeight, initial: true) { _, height in onResize?(height) }
        .onAppear { model.setMetering(true) }
        .onDisappear { model.setMetering(false) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if settings {
                Button { settings = false } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 26)
                }
                .buttonStyle(.plain).help("Back to mixer").accessibilityLabel("Back to mixer")
                Text("Settings").font(.system(size: 13, weight: .semibold))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(accent.gradient)
                    Image(systemName: "waveform").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                }.frame(width: 26, height: 26)
                Text("Cadence").font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            Spacer()
            Button { model.setEnabled(!model.enabled) } label: {
                Image(systemName: "power").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(model.enabled ? accent : Color.secondary)
                    .frame(width: 26, height: 26)
                    .background(model.enabled ? accent.opacity(0.12) : Color.primary.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
            .help(model.enabled ? "Pause mixer and restore original audio" : "Enable mixer")
            .accessibilityLabel(model.enabled ? "Pause mixer" : "Enable mixer")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().opacity(0.45) }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(model.channels.isEmpty ? "Your sound, in balance." : "Audio control is paused.")")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Button("Enable") { model.setEnabled(true) }.buttonStyle(.borderedProminent)
            }
            Text("Allow system audio access when macOS asks. Your audio stays on this Mac.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var outputSymbol: String {
        let name = model.outputName.lowercased()
        if name.contains("airpod") { return "airpodspro" }
        if ["buds", "headphone", "headset", "beats"].contains(where: name.contains) { return "headphones" }
        return "hifispeaker.fill"
    }

    private var outputCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: outputSymbol).font(.system(size: 12)).foregroundStyle(accent)
                    .frame(width: 18)
                Text(model.outputName).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: "arrow.triangle.branch").font(.system(size: 10)).foregroundStyle(.tertiary)
                    .help("Follows your macOS sound output")
            }.frame(height: 16)
            HStack(spacing: 8) {
                Button { model.toggleMasterMute() } label: {
                    Image(systemName: model.masterMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11)).frame(width: 18, height: 20)
                        .foregroundStyle(model.masterMuted ? accent : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(model.masterMuted ? "Unmute all apps" : "Mute all apps")
                .accessibilityLabel(model.masterMuted ? "Unmute mixer" : "Mute mixer")
                Slider(value: Binding(get: { model.master }, set: model.setMaster), in: 0...1)
                    .accessibilityLabel("Mixer volume")
                Text(model.masterMuted ? "—" : "\(Int(model.master * 100))%")
                    .font(.system(size: 10)).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }.frame(height: 20).disabled(!model.enabled)
        }
        .padding(10)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.025), in: RoundedRectangle(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Color.primary.opacity(0.06)) }
    }

    private var applicationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Applications").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text("\(model.activeCount) active").font(.system(size: 10)).foregroundStyle(.tertiary)
            }.frame(height: 12)
            if showsSearch {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(.tertiary)
                    TextField("Find an app", text: $search).textFieldStyle(.plain).font(.system(size: 11))
                }
                .padding(.horizontal, 8).frame(height: 28)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
            }
            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: search.isEmpty ? "waveform.path" : "magnifyingglass")
                        .font(.system(size: 20, weight: .light)).foregroundStyle(accent.opacity(0.7))
                    Text(search.isEmpty ? "Play something. It will appear here." : "No matching applications")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).frame(height: 70)
            } else {
                VStack(spacing: 0) {
                    ForEach(filtered) { channel in
                        channelRow(channel)
                        if channel.id != filtered.last?.id { Divider().opacity(0.3).padding(.leading, 34) }
                    }
                }
            }
            if let id = model.soloID {
                Button("Clear solo", systemImage: "headphones") { model.toggleSolo(id) }
                    .buttonStyle(.borderless).font(.system(size: 10))
            }
        }
    }

    private func channelRow(_ channel: MixerChannel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: channel.icon).resizable().interpolation(.high).frame(width: 26, height: 26)
                Text(channel.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Circle().fill(channel.error != nil ? Color.orange : (channel.peak > 0.001 ? Color.green : Color.secondary.opacity(0.25)))
                    .frame(width: 4, height: 4)
                    .help(channel.error != nil ? "Needs attention" : (channel.peak > 0.001 ? "Playing" : "Audio session open"))
                Spacer(minLength: 0)
                Button { model.toggleSolo(channel.id) } label: {
                    Image(systemName: "headphones").font(.system(size: 11))
                        .foregroundStyle(model.soloID == channel.id ? accent : Color.secondary)
                        .frame(width: 22, height: 24)
                        .background(model.soloID == channel.id ? accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain).help("Listen only to \(channel.name)").accessibilityLabel("Solo \(channel.name)")
                Button { model.toggleMute(channel.id) } label: {
                    Image(systemName: channel.settings.muted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                        .font(.system(size: 11)).frame(width: 22, height: 24)
                        .foregroundStyle(channel.settings.muted ? accent : Color.secondary)
                        .background(channel.settings.muted ? accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain).help(channel.settings.muted ? "Unmute \(channel.name)" : "Mute \(channel.name)")
                .accessibilityLabel(channel.settings.muted ? "Unmute \(channel.name)" : "Mute \(channel.name)")
            }.frame(height: 26)
            HStack(spacing: 8) {
                Slider(value: Binding(get: {
                    model.channels.first(where: { $0.id == channel.id })?.settings.volume ?? 1
                }, set: { model.setVolume(channel.id, $0) }), in: 0...1)
                    .accessibilityLabel("\(channel.name) volume")
                Text(channel.settings.muted ? "Muted" : "\(Int(channel.settings.volume * 100))%")
                    .font(.system(size: 10)).monospacedDigit()
                    .foregroundStyle(channel.settings.muted ? accent : Color.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.leading, 34).frame(height: 18)
            .disabled(!model.enabled || channel.error != nil)
            if let error = channel.error {
                Label("Audio unavailable · open Settings to retry", systemImage: "exclamationmark.circle")
                    .font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1)
                    .padding(.leading, 34).frame(height: 22).help(error)
            }
        }
        .padding(.vertical, 4)
        .opacity(model.soloID != nil && model.soloID != channel.id ? 0.4 : 1)
    }

    private func errorCard(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle").font(.system(size: 10))
            .foregroundStyle(.orange).lineLimit(3).help(text).padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var connectionLabel: String {
        if !model.enabled { return "Paused" }
        let count = model.controlledCount
        return count == 0 ? "Waiting for audio" : "\(count) \(count == 1 ? "app" : "apps") connected"
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle().fill(!model.enabled ? Color.secondary : (model.error != nil || model.channels.contains(where: { $0.error != nil }) ? Color.orange : Color.green))
                .frame(width: 4, height: 4)
            Text(connectionLabel).font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            Button { model.retry() } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 11)).frame(width: 24, height: 22)
            }.help("Refresh applications and retry audio access").accessibilityLabel("Refresh audio")
            Button { settings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 12)).frame(width: 24, height: 22)
            }.help("Settings").accessibilityLabel("Settings")
        }
        .buttonStyle(.plain).foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 6)
        .overlay(alignment: .top) { Divider().opacity(0.45) }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLogin))
                if let error = model.loginError { Text(error).font(.system(size: 10)).foregroundStyle(.orange) }
                Toggle("Show inactive apps", isOn: $model.showInactive)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("System audio access").font(.system(size: 11, weight: .medium))
                    Text("Allow Cadence in Privacy & Security if volume controls have no effect.")
                        .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Privacy Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                        }
                        Button("Retry audio") { model.retry() }
                    }
                }
                Divider()
                HStack {
                    Button("Reset volumes") { model.reset() }
                    Spacer()
                    Button("Quit Cadence") { NSApp.terminate(nil) }.keyboardShortcut("q")
                }
                Text("Cadence 1.0.1 · Audio stays on your Mac.")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }.padding(14)
        }.scrollIndicators(.hidden)
    }
}
