import AppKit
import Foundation

enum AvatarFiles {
    static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DeskBuddy/Avatar", isDirectory: true)
    enum Invalid: LocalizedError {
        case image(String)
        var errorDescription: String? {
            switch self { case .image(let name): return "Invalid \(name). Use a transparent PNG under 20 MB; the animation sheet must contain 4 columns × 2 rows." }
        }
    }
    static func validate(folder: URL) throws {
        for name in ["idle.png", "animation-sheet.png"] {
            let url = folder.appendingPathComponent(name)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attributes[.size] as? NSNumber, size.intValue <= 20_000_000,
                  let data = try? Data(contentsOf: url),
                  let bitmap = NSBitmapImageRep(data: data), bitmap.hasAlpha,
                  bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else { throw Invalid.image(name) }
            var transparent = false
            for point in [(0,0), (bitmap.pixelsWide-1,0), (0,bitmap.pixelsHigh-1), (bitmap.pixelsWide-1,bitmap.pixelsHigh-1)] {
                if (bitmap.colorAt(x: point.0, y: point.1)?.alphaComponent ?? 1) < 0.01 { transparent = true }
            }
            guard transparent else { throw Invalid.image(name) }
        }
        guard CharacterSprites.load(from: folder.appendingPathComponent("animation-sheet.png")).count == 8 else { throw Invalid.image("animation-sheet.png") }
    }
    static func install(from source: URL, destination: URL = directory) throws {
        try validate(folder: source)
        let manager = FileManager.default
        let parent = destination.deletingLastPathComponent()
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent("avatar-staging-\(UUID().uuidString)")
        let backup = parent.appendingPathComponent("avatar-backup-\(UUID().uuidString)")
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: staging) }
        for name in ["idle.png", "animation-sheet.png"] { try manager.copyItem(at: source.appendingPathComponent(name), to: staging.appendingPathComponent(name)) }
        let existing = manager.fileExists(atPath: destination.path)
        if existing { try manager.moveItem(at: destination, to: backup) }
        do { try manager.moveItem(at: staging, to: destination) }
        catch { if existing { try? manager.moveItem(at: backup, to: destination) }; throw error }
        if existing { try? manager.removeItem(at: backup) }
    }
    static func reset() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
}
