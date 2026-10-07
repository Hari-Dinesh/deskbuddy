import AppKit
import Foundation

@main struct AvatarIntegrationTests {
    static func png(width: Int, height: Int, at url: URL) throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<height { for x in 0..<width { bitmap.setColor(NSColor(deviceRed: 0, green: 0, blue: 1, alpha: x % 8 > 1 && y % 8 > 1 ? 1 : 0), atX: x, y: y) } }
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
    static func main() throws {
        let manager = FileManager.default
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        try png(width: 32, height: 48, at: root.appendingPathComponent("idle.png"))
        try png(width: 64, height: 32, at: root.appendingPathComponent("animation-sheet.png"))
        try AvatarFiles.validate(folder: root)
        let installed = root.appendingPathComponent("installed")
        try AvatarFiles.install(from: root, destination: installed)
        try AvatarFiles.install(from: root, destination: installed)
        precondition(CharacterSprites.load(from: installed.appendingPathComponent("animation-sheet.png")).count == 8)
        let original = try Data(contentsOf: installed.appendingPathComponent("idle.png"))
        let invalid = root.appendingPathComponent("invalid")
        try manager.createDirectory(at: invalid, withIntermediateDirectories: true)
        do { try AvatarFiles.install(from: invalid, destination: installed); preconditionFailure("Invalid import must fail") } catch { }
        let retained = try Data(contentsOf: installed.appendingPathComponent("idle.png"))
        precondition(original == retained, "Invalid imports must preserve existing avatar")
        print("PASS avatar validation, replacement and invalid-import preservation")
        let now = Date()
        let active = IntegrationEvent(providerID: "test", externalID: "1", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(300))
        let later = IntegrationEvent(providerID: "test", externalID: "2", start: now.addingTimeInterval(-30), end: now.addingTimeInterval(600))
        let future = IntegrationEvent(providerID: "test", externalID: "3", start: now.addingTimeInterval(60), end: now.addingTimeInterval(900))
        precondition(IntegrationPolicy.quietUntil(now: now, events: [active, later, future], enabledProviders: []) == nil)
        precondition(IntegrationPolicy.quietUntil(now: now, events: [active, later, future], enabledProviders: ["test"]) == later.end)
        print("PASS integrations are opt-in and only active meetings produce quiet time")
    }
}
