import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private var model: MixerModel!
    private var item: NSStatusItem!
    private var popover: NSPopover!
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > index + 1 {
            renderSnapshot(path: CommandLine.arguments[index + 1])
            NSApp.terminate(nil)
            return
        }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.aryanrathore.cadence")
            .filter { $0.processIdentifier != getpid() }
        if let other = others.first { other.activate(); NSApp.terminate(nil); return }
        model = MixerModel()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Cadence audio mixer")
            button.image?.isTemplate = true
            button.toolTip = "Cadence · Application volume"
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: MixerView.width, height: MixerView(model: model).preferredHeight)
        let popoverController = NSHostingController(rootView: MixerView(model: model, onResize: { [weak self] height in
            self?.popover.contentSize = NSSize(width: MixerView.width, height: height)
        }))
        popoverController.sizingOptions = []
        popover.contentViewController = popoverController
        setupMenu()
        if !CommandLine.arguments.contains("--background") {
            DispatchQueue.main.async { [weak self] in self?.showPopover() }
        }
    }

    private func setupMenu() {
        let main = NSMenu()
        let submenu = NSMenu()
        submenu.addItem(withTitle: "About Cadence", action: #selector(showAbout), keyEquivalent: "")
        submenu.addItem(.separator())
        submenu.addItem(withTitle: "Open Mixer", action: #selector(showWindow), keyEquivalent: "o")
        submenu.addItem(withTitle: "Hide Cadence", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        submenu.addItem(.separator())
        submenu.addItem(withTitle: "Quit Cadence", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let root = NSMenuItem()
        root.submenu = submenu
        main.addItem(root)
        NSApp.mainMenu = main
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Open Mixer Window", action: #selector(showWindow), keyEquivalent: "")
            menu.addItem(withTitle: model.enabled ? "Pause Audio Control" : "Enable Audio Control", action: #selector(toggleEnabled), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit Cadence", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            for entry in menu.items where entry.action != #selector(NSApplication.terminate(_:)) { entry.target = self }
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
            return
        }
        if popover.isShown { popover.performClose(nil); return }
        if let window, window.isVisible { window.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        showPopover()
    }

    private func showPopover() {
        guard let button = item.button else { return }
        model.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
    }

    @objc private func toggleEnabled() { model.setEnabled(!model.enabled) }

    @objc private func showWindow() {
        popover?.performClose(nil)
        if window == nil {
            let height = MixerView(model: model).preferredHeight
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: MixerView.width, height: height),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Cadence"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .windowBackgroundColor
            let controller = NSHostingController(rootView: MixerView(model: model, onResize: { [weak self] height in
                self?.resizeWindow(height: height)
            }))
            controller.sizingOptions = []
            window.contentViewController = controller
            window.setContentSize(NSSize(width: MixerView.width, height: height))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        model.refresh()
        window?.makeKeyAndOrderFront(nil)
        model.setMetering(true)
        NSApp.activate()
    }

    private func resizeWindow(height: CGFloat) {
        guard let window else { return }
        let previous = window.frame
        var frame = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: MixerView.width, height: height))
        frame.origin = NSPoint(x: previous.minX, y: previous.maxY - frame.height)
        window.setFrame(frame, display: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window, window.isVisible { window.makeKeyAndOrderFront(nil); NSApp.activate() }
        else { showPopover() }
        return true
    }
    func windowWillClose(_ notification: Notification) { model.setMetering(false) }
    func popoverDidShow(_ notification: Notification) { model.setMetering(true) }
    func popoverDidClose(_ notification: Notification) { model.setMetering(window?.isVisible == true) }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Cadence", .applicationVersion: "1.0.1",
            .credits: NSAttributedString(string: "A little more harmony.\nNative application audio control for macOS.")
        ])
    }

    /// Reproducible UI fixture for design review; never creates audio taps.
    private func renderSnapshot(path: String) {
        NSApp.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
        let fixture = MixerModel(defaults: UserDefaults(suiteName: "com.aryanrathore.cadence.preview")!, startMonitoring: false)
        fixture.enabled = true
        fixture.outputName = "MacBook Pro Speakers"
        fixture.channels = ["Safari", "Music", "Spotify", "Discord"].enumerated().map { index, name in
            let urls = ["/Applications/\(name).app", "/System/Applications/\(name).app"]
            let icon = urls.first(where: { FileManager.default.fileExists(atPath: $0) })
                .map { NSWorkspace.shared.icon(forFile: $0) }
                ?? NSImage(systemSymbolName: ["safari", "music.note", "waveform", "bubble.left.and.bubble.right.fill"][index], accessibilityDescription: nil)!
            return MixerChannel(id: name, name: name, icon: icon, processIDs: [], running: true,
                settings: ChannelSettings(volume: [0.7, 0.45, 1.0, 0.3][index], muted: index == 3), peak: 0.2)
        }
        if CommandLine.arguments.contains("--single-app") { fixture.channels = Array(fixture.channels.prefix(1)) }
        if CommandLine.arguments.contains("--empty") { fixture.channels = [] }
        if CommandLine.arguments.contains("--many-apps") {
            let original = fixture.channels
            fixture.channels += original.map { channel in
                MixerChannel(id: channel.id + ".extra", name: channel.name + " Extra", icon: channel.icon,
                    processIDs: [], running: true, settings: channel.settings, peak: 0.2)
            }
        }
        if CommandLine.arguments.contains("--paused") { fixture.enabled = false }
        let root = MixerView(model: fixture, initiallyShowingSettings: CommandLine.arguments.contains("--settings"))
        let controller = NSHostingController(rootView: root)
        controller.sizingOptions = []
        let size = NSSize(width: MixerView.width, height: root.preferredHeight)
        let panel = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.contentViewController = controller
        panel.setContentSize(size)
        panel.display()
        let view = controller.view
        view.layoutSubtreeIfNeeded()
        if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: path)) }
        }
        fixture.shutdown()
    }
}
