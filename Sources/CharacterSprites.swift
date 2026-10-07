import AppKit
import Foundation

enum CharacterSprites {
    static var frames = load(from: AvatarFiles.directory.appendingPathComponent("animation-sheet.png"))
    static var idleImage = NSImage(contentsOf: AvatarFiles.directory.appendingPathComponent("idle.png"))
    static func reload() {
        frames = load(from: AvatarFiles.directory.appendingPathComponent("animation-sheet.png"))
        idleImage = NSImage(contentsOf: AvatarFiles.directory.appendingPathComponent("idle.png"))
    }

    static func load(from url: URL?) -> [NSImage] {
        // Decode the PNG directly; do not depend on an NSImage drawing context.
        guard let url, let data = try? Data(contentsOf: url),
              let bitmap = NSBitmapImageRep(data: data), let image = bitmap.cgImage,
              image.width % 4 == 0, image.height % 2 == 0 else { return [] }
        let width = image.width / 4
        let height = image.height / 2
        return (0..<8).compactMap { index in
            let cell = CGRect(x: (index % 4) * width, y: (index / 4) * height, width: width, height: height)
            guard let cropped = image.cropping(to: cell) else { return nil }
            return NSImage(cgImage: cropped, size: NSSize(width: width, height: height))
        }
    }
}
