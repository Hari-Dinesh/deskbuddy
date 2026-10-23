import Foundation
import AppKit

@main struct ProfileUpgradeTests {
    static func main() throws {
        var oldPreferences = Preferences(); oldPreferences.name = "Earlier name"; oldPreferences.sound = true; oldPreferences.waterMinutes = 70
        let previous: [String: Any] = ["preferences": try JSONEncoder().encode(oldPreferences), "onboarded": true, "NSWindow Frame DeskBuddyPosition": "old", "engine": Data("old-state".utf8)]
        let reset: [String: Any] = ["preferences": try JSONEncoder().encode(Preferences()), "NSWindow Frame DeskBuddyPosition": "new", "engine": Data("new-state".utf8)]
        let migrated = try ProfileUpgrade.plan(current: reset, legacy: previous)
        let restored = try JSONDecoder().decode(Preferences.self, from: migrated.values["preferences"] as! Data)
        precondition(migrated.recoveredPreferences && restored.name == "Earlier name" && restored.sound && restored.waterMinutes == 70)
        precondition(migrated.values["NSWindow Frame DeskBuddyPosition"] as? String == "new")
        precondition(migrated.values["engine"] as? Data == Data("new-state".utf8))
        let again = try ProfileUpgrade.plan(current: migrated.values, legacy: previous)
        precondition(!again.recoveredPreferences, "Automatic migration runs once")
        var custom = Preferences(); custom.name = "Current name"
        let kept = try ProfileUpgrade.plan(current: ["preferences": try JSONEncoder().encode(custom)], legacy: previous)
        precondition(kept.preservedCurrentProfile && !kept.recoveredPreferences)
        let protected = try JSONDecoder().decode(Preferences.self, from: kept.values["preferences"] as! Data)
        precondition(protected.name == "Current name")
        print("PASS default-profile recovery, idempotence and preservation of newer settings/state")

        let partial = try JSONDecoder().decode(Preferences.self, from: Data(#"{"name":"Kept name","sound":true}"#.utf8))
        precondition(partial.name == "Kept name" && partial.sound && partial.waterMinutes == 45)
        let oldEngine = try JSONDecoder().decode(ReminderEngine.self, from: Data(#"{"waterCount":3}"#.utf8))
        precondition(oldEngine.waterCount == 3 && oldEngine.snoozes.isEmpty)
        do { _ = try ProfileUpgrade.plan(current: ["preferences": Data("corrupt".utf8)], legacy: previous); preconditionFailure("Corrupt current data must not be replaced") } catch { }
        do { _ = try ProfileUpgrade.plan(current: ["preferences": "wrong type"], legacy: previous); preconditionFailure("Wrong-type settings must be preserved") } catch { }
        print("PASS partial-schema compatibility and corrupt-data protection")

        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("deskbuddy-upgrade-tests-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: root) }
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("notes must survive".utf8).write(to: root.appendingPathComponent("workspace.json"))
        let archive = try ProfileUpgrade.backup(current: reset, legacy: previous, root: root)
        let savedNotes = try Data(contentsOf: archive.appendingPathComponent("workspace.json"))
        precondition(savedNotes == Data("notes must survive".utf8))
        let properties = try PropertyListSerialization.propertyList(from: Data(contentsOf: archive.appendingPathComponent("legacy-preferences.plist")), options: [], format: nil) as! [String: Any]
        precondition(properties["preferences"] as? Data == previous["preferences"] as? Data)
        print("PASS lossless preference/workspace backup before migration")

        let source = root.appendingPathComponent("old-resources")
        try manager.createDirectory(at: source, withIntermediateDirectories: true)
        func png(_ width: Int, _ height: Int, _ url: URL) throws {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.bitmapData!.initialize(repeating: 0, count: bitmap.bytesPerRow * height)
            try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        }
        try png(32, 48, source.appendingPathComponent("personal-avatar.png"))
        try png(64, 32, source.appendingPathComponent("animation-sheet.png"))
        let destination = root.appendingPathComponent("Avatar")
        let recovered = try ProfileUpgrade.recoverAvatar(from: source, destination: destination)
        precondition(recovered)
        let idle = try Data(contentsOf: destination.appendingPathComponent("idle.png"))
        let second = try ProfileUpgrade.recoverAvatar(from: source, destination: destination)
        precondition(!second)
        let retained = try Data(contentsOf: destination.appendingPathComponent("idle.png"))
        precondition(idle == retained)
        print("PASS legacy bundled-avatar recovery without replacing a current avatar")
    }
}
