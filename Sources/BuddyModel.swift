import AppKit
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import ServiceManagement

final class BuddyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class BuddyModel: ObservableObject {
    @Published var preferences: Preferences
    @Published var engine: ReminderEngine
    @Published var reminder: ReminderKind? { didSet { resizePanel() } }
    @Published var phase: CompanionPhase = .idle
    @Published var spriteIndex: Int? = nil
    @Published var sceneProgress: Double = 0
    @Published var previewing = false
    @Published var animationNotice = ""
    var reducedMotion: Bool { !previewing && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var animationTimer: Timer?
    var phaseStart = Date()
    var motionStart: CGFloat = 0
    var motionEnd: CGFloat = 0
    var homeFrame: NSRect?
    var sceneScreen: NSRect?
    var sceneID = UUID()
    @Published var pausedUntil: Date?
    @Published var status = "Ready to keep you company"
    @Published var hidden = false
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginError = ""
    var sleeping = false
    var lastTick = Date()
    var timer: Timer?
    var showSettings: (() -> Void)?
    var showPreview: (() -> Void)?
    var panel: BuddyPanel?
    private let defaults = UserDefaults.standard
    init() {
        preferences = defaults.data(forKey: "preferences").flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        engine = defaults.data(forKey: "engine").flatMap { try? JSONDecoder().decode(ReminderEngine.self, from: $0) } ?? ReminderEngine()
        engine.rollDay(Date())
    }
    func resizePanel() {
        guard let panel else { return }
        let old = panel.frame
        let size = reminder == nil ? NSSize(width: 144, height: 174) : NSSize(width: 260, height: 306)
        panel.setFrame(NSRect(x: old.maxX - size.width, y: old.minY, width: size.width, height: size.height), display: true)
    }
    var responding: Bool { phase == .celebrating || phase == .reacting || phase.departing }
    func present(_ kind: ReminderKind, preview: Bool = false) {
        guard !sleeping, !responding else { return }
        cancelScene()
        previewing = preview
        animationNotice = CharacterSprites.frames.count == 8 ? "Custom animation: 8 poses loaded" : "Built-in robot · import a custom avatar in Settings"
        homeFrame = panel?.frame
        reminder = kind
        hidden = false
        if let panel {
            let screen = panel.screen ?? NSScreen.main
            let bounds = screen?.visibleFrame ?? panel.frame
            sceneScreen = bounds
            var frame = panel.frame
            frame.origin.x = min(max(frame.minX, bounds.minX), bounds.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, bounds.minY), bounds.maxY - frame.height)
            panel.setFrame(frame, display: true)
            motionEnd = frame.minX
            motionStart = bounds.minX - frame.width
            if !reducedMotion {
                panel.setFrameOrigin(NSPoint(x: motionStart, y: frame.minY))
            }
            panel.orderFrontRegardless()
        }
        startPhase(.entering)
    }
    func startPhase(_ next: CompanionPhase) {
        sceneID = UUID()
        animationTimer?.invalidate(); animationTimer = nil
        phase = next
        phaseStart = Date(); sceneProgress = 0
        let water = reminder == .water
        spriteIndex = next.sprite(elapsed: 0, water: water)
        panel?.ignoresMouseEvents = next.moving
        guard next.duration > 0 else { return }
        if next.departing, let panel, let bounds = sceneScreen {
            motionStart = panel.frame.minX
            motionEnd = next == .runningRight ? bounds.maxX + 10 : bounds.minX - panel.frame.width - 10
        }
        if reducedMotion {
            let token = sceneID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, self.sceneID == token else { return }
                self.advancePhase()
            }
            return
        }
        let displayFPS = (panel?.screen ?? NSScreen.main)?.maximumFramesPerSecond ?? 60
        let targetFPS = max(30, min(120, displayFPS))
        let animation = Timer(timeInterval: 1.0 / Double(targetFPS), repeats: true) { [weak self] _ in self?.animateFrame() }
        animationTimer = animation
        RunLoop.main.add(animation, forMode: .common)
    }
    func animateFrame() {
        let elapsed = Date().timeIntervalSince(phaseStart)
        let progress = min(1, elapsed / max(phase.duration, 0.01))
        sceneProgress = progress
        let nextSprite = phase.sprite(elapsed: elapsed, water: reminder == .water)
        if spriteIndex != nextSprite { spriteIndex = nextSprite }
        if phase.moving, let panel {
            let eased = CompanionPhase.easedProgress(progress)
            panel.setFrameOrigin(NSPoint(x: motionStart + (motionEnd - motionStart) * eased, y: panel.frame.minY))
        }
        if progress >= 1 { advancePhase() }
    }
    func advancePhase() {
        if phase.departing { cancelScene(hide: true); return }
        startPhase(phase.next(water: reminder == .water))
    }
    func cancelScene(hide: Bool = false) {
        sceneID = UUID()
        animationTimer?.invalidate(); animationTimer = nil
        panel?.ignoresMouseEvents = false
        if let homeFrame { panel?.setFrame(homeFrame, display: true) }
        self.homeFrame = nil; sceneScreen = nil
        phase = .idle; spriteIndex = nil; sceneProgress = 0
        previewing = false
        reminder = nil
        if hide { hidden = true; panel?.orderOut(nil) }
    }
    func save() {
        defaults.set(try? JSONEncoder().encode(preferences), forKey: "preferences")
        defaults.set(try? JSONEncoder().encode(engine), forKey: "engine")
    }
    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            center.addObserver(self, selector: #selector(sleep), name: name, object: nil)
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(self, selector: #selector(wake), name: name, object: nil)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }
    @objc func sleep() { sleeping = true; lastTick = Date(); cancelScene(hide: true); status = "Resting with your Mac"; save() }
    @objc func wake() { sleeping = false; lastTick = Date(); tick() }
    func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        let paused = (pausedUntil ?? .distantPast) > now
        let active = !sleeping && !paused && idle < Double(preferences.idleMinutes * 60)
        status = sleeping ? "Resting with your Mac" : paused ? "Quiet until \(pausedUntil!.formatted(date: .omitted, time: .shortened))" : active ? "Counting active work time" : "Away · water timer paused"
        if reminder == nil {
            if let next = engine.tick(now: now, elapsed: elapsed, active: active, preferences: preferences) {
                present(next)
                if preferences.sound { NSSound(named: "Glass")?.play() }
            }
        } else {
            // Count active water time without selecting another reminder during a scene.
            engine.rollDay(now)
            if active { engine.activeSeconds += max(0, min(elapsed, 15)) }
        }
        save()
    }
    func done(_ kind: ReminderKind) {
        guard !responding else { return }
        if !previewing { engine.done(kind, now: Date()); save() }
        if reminder == kind { startPhase(.celebrating) }
    }
    func snooze() {
        guard !responding, let reminder else { return }
        if !previewing { engine.snooze(reminder, now: Date()); save() }
        startPhase(.reacting)
    }
    func pause() { pausedUntil = Date().addingTimeInterval(3600); cancelScene(); tick() }
    func resume() { pausedUntil = nil; tick() }
    func toggleBuddy() {
        if hidden { hidden = false; panel?.orderFrontRegardless() }
        else {
            if let reminder, !responding, !previewing { engine.snooze(reminder, now: Date()); save() }
            cancelScene(hide: true)
        }
    }
    @Published var avatarRevision = 0
    @Published var avatarError = ""
    func importAvatar() {
        NSApp.activate(ignoringOtherApps: true)
        let chooser = NSOpenPanel()
        chooser.canChooseDirectories = true; chooser.canChooseFiles = false
        chooser.message = "Choose a folder containing idle.png and animation-sheet.png"
        if chooser.runModal() == .OK, let url = chooser.url {
            do {
                try AvatarFiles.install(from: url)
                CharacterSprites.reload()
                preferences.photo = nil; avatarRevision += 1; avatarError = ""; save()
            } catch { avatarError = error.localizedDescription }
        }
    }
    func resetAvatar() {
        do { try AvatarFiles.reset(); CharacterSprites.reload(); preferences.photo = nil; avatarRevision += 1; avatarError = ""; save() }
        catch { avatarError = error.localizedDescription }
    }
    func pickPhoto() {
        NSApp.activate(ignoringOtherApps: true)
        let chooser = NSOpenPanel()
        chooser.allowedContentTypes = [.image]; chooser.allowsMultipleSelection = false
        if chooser.runModal() == .OK, let url = chooser.url, let photo = NSImage(contentsOf: url) {
            let size = NSSize(width: 512, height: 512)
            let resized = NSImage(size: size)
            resized.lockFocus()
            let ratio = min(512 / photo.size.width, 512 / photo.size.height)
            let fitted = NSSize(width: photo.size.width * ratio, height: photo.size.height * ratio)
            photo.draw(in: NSRect(x: (512-fitted.width)/2, y: (512-fitted.height)/2, width: fitted.width, height: fitted.height))
            resized.unlockFocus()
            preferences.photo = resized.tiffRepresentation
            save()
        }
    }
    func setLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginEnabled = SMAppService.mainApp.status == .enabled; loginError = loginEnabled || !enabled ? "" : "Approve DeskBuddy in System Settings → Login Items." }
        catch { loginError = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
    }
}

