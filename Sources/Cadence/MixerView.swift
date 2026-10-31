import SwiftUI

private let accent = Color(red: 0.57, green: 0.46, blue: 0.95)

struct MixerView: View {
    @ObservedObject var model: MixerModel
    @State private var search = ""
    @State private var settings = false
    @Environment(\.colorScheme) private var colorScheme

    private var filtered: [MixerChannel] {
        model.visibleChannels.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !model.enabled { welcome }
                    outputCard
                    if let error = model.error { errorCard(error) }
                    applicationSection
                }
                .padding(24)
            }
            footer
        }
        .font(.system(size: 13))
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .background {
            ZStack(alignment: .topTrailing) {
                Rectangle().fill(.regularMaterial)
                Ellipse().fill(accent.opacity(colorScheme == .dark ? 0.10 : 0.06))
                    .frame(width: 330, height: 220).blur(radius: 70).offset(x: 120, y: -110)
            }
        }
        .tint(accent)
        .sheet(isPresented: $settings) { settingsView }
        .onAppear { model.setMetering(true) }
        .onDisappear { model.setMetering(false) }
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(accent.gradient)
                Image(systemName: "waveform").font(.system(size: 21, weight: .medium)).foregroundStyle(.white)
            }.frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cadence").font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("A little more harmony.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.setEnabled(!model.enabled) } label: {
                Image(systemName: "power").font(.system(size: 15, weight: .medium))
                    .foregroundStyle(model.enabled ? accent : Color.secondary)
                    .frame(width: 32, height: 32)
                    .background(model.enabled ? accent.opacity(0.12) : Color.primary.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
            .help(model.enabled ? "Pause mixer and restore original audio" : "Enable mixer")
            .accessibilityLabel(model.enabled ? "Pause mixer" : "Enable mixer")
        }
        .padding(.horizontal, 24).padding(.vertical, 20)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Your sound. In balance.").font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("Give every app its own volume. Enable Cadence, then allow system audio access when macOS asks.")
                .foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            Button("Enable audio control", systemImage: "waveform") { model.setEnabled(true) }
                .buttonStyle(.borderedProminent).controlSize(.large)
            Text("Audio stays on your Mac. Nothing is recorded or uploaded.")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }.padding(.vertical, 4)
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 12) {
                Image(systemName: model.outputName.localizedCaseInsensitiveContains("airpod") ? "airpodspro" : "hifispeaker.fill")
                    .font(.system(size: 21)).foregroundStyle(accent)
                    .frame(width: 38, height: 38).background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text("OUTPUT").font(.system(size: 9, weight: .bold)).tracking(1.6).foregroundStyle(.tertiary)
                    Text(model.outputName).font(.system(size: 13, weight: .medium)).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.triangle.branch").foregroundStyle(.tertiary)
                    .help("Follows the output selected in macOS Sound settings")
            }
            Divider().opacity(0.5)
            HStack {
                Text("Mixer volume").font(.system(size: 12, weight: .medium))
                Spacer()
                Text(model.masterMuted ? "Muted" : "\(Int(model.master * 100))%")
                    .monospacedDigit().font(.system(size: 12)).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button { model.toggleMasterMute() } label: {
                    Image(systemName: model.masterMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 20).foregroundStyle(model.masterMuted ? accent : Color.secondary)
                }.buttonStyle(.plain).help("Mute all controlled apps")
                    .accessibilityLabel(model.masterMuted ? "Unmute mixer" : "Mute mixer")
                Slider(value: Binding(get: { model.master }, set: model.setMaster), in: 0...1)
                    .accessibilityLabel("Mixer volume")
            }.disabled(!model.enabled)
        }
        .padding(18)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.025), in: RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.primary.opacity(0.06)) }
    }

    private var applicationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("APPLICATIONS").font(.system(size: 10, weight: .semibold)).tracking(1.7).foregroundStyle(.secondary)
                Spacer()
                Text("\(model.activeCount) active").font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05), in: Capsule())
            }
            if model.channels.count > 4 || !search.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                    TextField("Find an application", text: $search).textFieldStyle(.plain)
                }.padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
            }
            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: search.isEmpty ? "waveform.path" : "magnifyingglass")
                        .font(.system(size: 30, weight: .ultraLight)).foregroundStyle(accent.opacity(0.6))
                    Text(search.isEmpty ? "Room for your sound" : "No matching applications")
                        .font(.system(size: 13, weight: .medium))
                    Text(search.isEmpty ? "Play something in any app.\nIt will appear here automatically." : "Try a different application name.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(3)
                }.frame(maxWidth: .infinity).padding(.vertical, 35)
            } else {
                VStack(spacing: 0) {
                    ForEach(filtered) { channel in
                        channelRow(channel)
                        if channel.id != filtered.last?.id { Divider().opacity(0.35).padding(.leading, 50) }
                    }
                }
            }
            if model.soloID != nil {
                Button("Clear solo", systemImage: "headphones") {
                    if let id = model.soloID { model.toggleSolo(id) }
                }.buttonStyle(.borderless).font(.system(size: 11))
            }
        }
    }

    private func channelRow(_ channel: MixerChannel) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                Image(nsImage: channel.icon).resizable().interpolation(.high).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    HStack(spacing: 5) {
                        Circle().fill(channel.error != nil ? Color.orange : (channel.peak > 0.001 ? Color.green : Color.secondary.opacity(0.35)))
                            .frame(width: 4, height: 4)
                        Text(channel.error != nil ? "Needs attention" : (!channel.running ? "Idle" : (channel.peak > 0.001 ? "Playing" : "Audio session active")))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                Button { model.toggleSolo(channel.id) } label: {
                    Image(systemName: "headphones").font(.system(size: 12))
                        .foregroundStyle(model.soloID == channel.id ? accent : Color.secondary.opacity(0.6))
                }.buttonStyle(.plain).help("Listen only to \(channel.name)")
                    .accessibilityLabel("Solo \(channel.name)")
                Text(channel.settings.muted ? "—" : "\(Int(channel.settings.volume * 100))%")
                    .font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 39, alignment: .trailing)
            }
            HStack(spacing: 12) {
                Button { model.toggleMute(channel.id) } label: {
                    Image(systemName: channel.settings.muted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                        .font(.system(size: 12)).foregroundStyle(channel.settings.muted ? accent : Color.secondary)
                        .frame(width: 36, height: 20)
                }.buttonStyle(.plain).help("Mute \(channel.name)")
                    .accessibilityLabel("Mute \(channel.name)")
                Slider(value: Binding(get: {
                    model.channels.first(where: { $0.id == channel.id })?.settings.volume ?? 1
                }, set: { model.setVolume(channel.id, $0) }), in: 0...1)
                    .accessibilityLabel("\(channel.name) volume")
            }.disabled(!model.enabled || channel.error != nil)
            if let error = channel.error {
                Text(error).font(.system(size: 10)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
        .opacity(model.soloID != nil && model.soloID != channel.id ? 0.45 : 1)
    }

    private func errorCard(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle").font(.system(size: 11))
            .foregroundStyle(.orange).padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle().fill(!model.enabled ? Color.secondary : (model.error != nil || model.channels.contains(where: { $0.error != nil }) ? Color.orange : Color.green))
                .frame(width: 5, height: 5)
            Text(!model.enabled ? "Mixer paused" : (model.controlledCount == 0 ? "Listening for applications" : "\(model.controlledCount) apps connected"))
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            Button { model.retry() } label: { Image(systemName: "arrow.clockwise") }
                .help("Refresh applications and retry audio access")
            Button { settings = true } label: { Image(systemName: "gearshape") }
                .help("Settings").padding(.leading, 8)
        }
        .buttonStyle(.plain).foregroundStyle(.secondary)
        .padding(.horizontal, 24).padding(.vertical, 14)
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Make yourself at home.").font(.system(size: 21, weight: .semibold, design: .rounded))
                Spacer()
                Button("Done") { settings = false }.keyboardShortcut(.defaultAction)
            }
            Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLogin))
            if let error = model.loginError { Text(error).font(.caption).foregroundStyle(.orange) }
            Toggle("Show inactive audio applications", isOn: $model.showInactive)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("System audio access").fontWeight(.medium)
                Text("macOS requires audio capture access to adjust application sound. If controls have no effect, allow Cadence in Privacy & Security, then retry.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Open Privacy Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                    }
                    Button("Retry audio") { model.retry() }
                }
            }
            Divider()
            HStack {
                Button("Reset all volumes") { model.reset() }
                Spacer()
                Button("Quit Cadence") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            Text("Cadence 1.0 · Native to your Mac.\nNo drivers. No accounts. No audio leaves your device.")
                .font(.system(size: 10)).foregroundStyle(.tertiary).lineSpacing(4)
        }.padding(26).frame(width: 430).tint(accent)
    }
}
