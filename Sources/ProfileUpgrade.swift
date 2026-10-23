import Foundation

enum ProfileUpgrade {
    static let currentDomain = "io.github.hari-dinesh.deskbuddy"
    static let legacyDomain = "local.dinesh.DeskBuddy"
    static let marker = "legacyProfileMigrationVersion"
    static let avatarMarker = "legacyAvatarMigrationVersion"
    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DeskBuddy", isDirectory: true)

    struct Plan {
        var values: [String: Any]
        var recoveredPreferences = false
        var preservedCurrentProfile = false
    }
    static func plan(current: [String: Any], legacy: [String: Any], force: Bool = false) throws -> Plan {
        var result = Plan(values: current)
        guard force || (current[marker] as? Int ?? 0) < 1 else { return result }
        if current["preferences"] != nil && !(current["preferences"] is Data) { throw CocoaError(.coderReadCorrupt) }
        if let legacyData = legacy["preferences"] as? Data {
            let previous = try JSONDecoder().decode(Preferences.self, from: legacyData)
            let previousObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(previous)) as! NSDictionary
            let defaultObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Preferences())) as! NSDictionary
            let currentData = current["preferences"] as? Data
            var isDefault = currentData == nil
            if let currentData {
                let preferences = try JSONDecoder().decode(Preferences.self, from: currentData)
                let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as! NSDictionary
                isDefault = object.isEqual(defaultObject)
            }
            if isDefault && !previousObject.isEqual(defaultObject) {
                result.values["preferences"] = legacyData
                result.recoveredPreferences = true
            } else if !isDefault { result.preservedCurrentProfile = true }
        }
        // Never overwrite the newer app's reminders/counters or current window placement.
        for key in ["engine", "onboarded", "NSWindow Frame DeskBuddyPosition"] where current[key] == nil {
            if let value = legacy[key] { result.values[key] = value }
        }
        result.values[marker] = 1
        return result
    }

    /// Snapshot first; no old preference domain or workspace is ever deleted.
    static func backup(current: [String: Any], legacy: [String: Any], root: URL = support) throws -> URL {
        let manager = FileManager.default
        let directory = root.appendingPathComponent("Backups/profile-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        for (name, values) in [("current-preferences.plist", current), ("legacy-preferences.plist", legacy)] {
            let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
            let path = directory.appendingPathComponent(name)
            try data.write(to: path, options: .atomic)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
        }
        for name in ["workspace.json", "Avatar"] {
            let source = root.appendingPathComponent(name)
            if manager.fileExists(atPath: source.path) { try manager.copyItem(at: source, to: directory.appendingPathComponent(name)) }
        }
        return directory
    }

    static func recoverAvatar(from source: URL, destination: URL) throws -> Bool {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else { return false }
        let idle = source.appendingPathComponent("idle.png")
        let original = source.appendingPathComponent("personal-avatar.png")
        let picture = manager.fileExists(atPath: idle.path) ? idle : original
        let sheet = source.appendingPathComponent("animation-sheet.png")
        guard manager.fileExists(atPath: picture.path), manager.fileExists(atPath: sheet.path) else { return false }
        let staging = manager.temporaryDirectory.appendingPathComponent("deskbuddy-avatar-recovery-\(UUID().uuidString)")
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        try manager.copyItem(at: picture, to: staging.appendingPathComponent("idle.png"))
        try manager.copyItem(at: sheet, to: staging.appendingPathComponent("animation-sheet.png"))
        try AvatarFiles.install(from: staging, destination: destination)
        return true
    }

    @discardableResult static func run(avatarSource: URL? = nil, force: Bool = false, defaults: UserDefaults = .standard) -> String {
        let current = defaults.persistentDomain(forName: currentDomain) ?? [:]
        let legacy = defaults.persistentDomain(forName: legacyDomain) ?? [:]
        let needsProfile = force || (current[marker] as? Int ?? 0) < 1
        let needsAvatar = force || (current[avatarMarker] as? Int ?? 0) < 1
        guard needsProfile || needsAvatar else { return current["profileRecoveryNotice"] as? String ?? "" }
        do {
            var result = try plan(current: current, legacy: legacy, force: force)
            let hasLegacy = !legacy.isEmpty
            let source = avatarSource ?? support.appendingPathComponent("LegacyAvatar")
            let canRecoverAvatar = needsAvatar && FileManager.default.fileExists(atPath: source.path) && !FileManager.default.fileExists(atPath: AvatarFiles.directory.path)
            guard needsProfile || canRecoverAvatar else { return current["profileRecoveryNotice"] as? String ?? "" }
            let backupURL = try backup(current: current, legacy: legacy)
            var restoredAvatar = false
            if canRecoverAvatar { restoredAvatar = try recoverAvatar(from: source, destination: AvatarFiles.directory) }
            if restoredAvatar || FileManager.default.fileExists(atPath: AvatarFiles.directory.path) { result.values[avatarMarker] = 1 }
            let message: String
            if result.recoveredPreferences || restoredAvatar {
                message = "Previous setup recovered. " + (result.recoveredPreferences ? "Your earlier preferences were restored. " : "") + (restoredAvatar ? "Your custom avatar was restored. " : "") + "Backup: " + backupURL.lastPathComponent
            } else if result.preservedCurrentProfile && hasLegacy {
                message = "Your current settings were kept. The earlier profile is backed up; use Export settings backup before making manual changes."
            } else { message = "Settings are stored separately from the app and preserved during updates." }
            result.values["profileRecoveryNotice"] = message
            defaults.setPersistentDomain(result.values, forName: currentDomain)
            guard defaults.synchronize() else { throw CocoaError(.fileWriteUnknown) }
            return message
        } catch {
            return "Could not migrate the previous setup; saved data was left in place. " + error.localizedDescription
        }
    }
}
