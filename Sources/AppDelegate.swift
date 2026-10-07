import AppKit
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = BuddyModel()
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let panel = BuddyPanel(contentRect: NSRect(x: 0, y: 0, width: 144, height: 174), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: CompanionView(model: model))
        panel.setFrameAutosaveName("DeskBuddyPosition")
        if !panel.setFrameUsingName("DeskBuddyPosition"), let frame = NSScreen.main?.visibleFrame { panel.setFrameOrigin(NSPoint(x: frame.maxX - 174, y: frame.minY + 35)) }
        model.panel = panel; model.resizePanel(); panel.orderFrontRegardless()
        settingsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 530, height: 740), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        settingsWindow.title = "DeskBuddy — Settings"; settingsWindow.isReleasedWhenClosed = false
        settingsWindow.contentView = NSHostingView(rootView: SettingsView(model: model)); settingsWindow.center()
        model.showSettings = { [weak self] in self?.settings() }
        model.showPreview = { [weak self] in self?.preview() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "DeskBuddy")
        let menu = NSMenu()
        for (title, selector) in [("Show / hide buddy", #selector(toggle)), ("Settings…", #selector(settings)), ("Preview animation (\(AppInfo.version))", #selector(preview)), ("I had water", #selector(water)), ("Quiet for 1 hour", #selector(pause)), ("Resume reminders", #selector(resume)), ("Quit DeskBuddy", #selector(quit))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu
        model.start()
        if !UserDefaults.standard.bool(forKey: "onboarded") { settings(); UserDefaults.standard.set(true, forKey: "onboarded") }
    }
    @objc func settings() { NSApp.activate(ignoringOtherApps: true); settingsWindow.makeKeyAndOrderFront(nil) }
    @objc func preview() {
        guard !model.responding else { return }
        settingsWindow.orderOut(nil)
        // Let menu tracking finish before the character starts walking.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.model.present(.water, preview: true) }
    }
    @objc func toggle() { model.toggleBuddy() }
    @objc func water() { model.done(.water) }
    @objc func pause() { model.pause() }
    @objc func resume() { model.resume() }
    @objc func quit() { model.save(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { model.cancelScene(); model.save(); model.panel?.saveFrame(usingName: "DeskBuddyPosition") }
}

