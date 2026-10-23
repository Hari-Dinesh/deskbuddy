import Foundation

/// Stages recovery without touching live preferences or the currently selected avatar.
@main struct PrepareRecovery {
    static func main() throws {
        let defaults = UserDefaults.standard
        let current = defaults.persistentDomain(forName: ProfileUpgrade.currentDomain) ?? [:]
        let legacy = defaults.persistentDomain(forName: ProfileUpgrade.legacyDomain) ?? [:]
        let folder = try ProfileUpgrade.backup(current: current, legacy: legacy)
        if CommandLine.arguments.count > 1 {
            let source = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            let destination = ProfileUpgrade.support.appendingPathComponent("LegacyAvatar", isDirectory: true)
            if !FileManager.default.fileExists(atPath: destination.path) {
                _ = try ProfileUpgrade.recoverAvatar(from: source, destination: destination)
            }
        }
        print("Backup prepared at: \(folder.path)")
        print("Live preferences were not changed. DeskBuddy will recover the previous setup on its next launch.")
    }
}
