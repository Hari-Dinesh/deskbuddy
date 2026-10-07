import AppKit

@main struct AssetTests {
    static func main() {
        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        let poses = CharacterSprites.load(from: source)
        precondition(poses.count == 8, "All eight animation poses must load")
        for (index, pose) in poses.enumerated() {
            let image = pose.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            precondition(image.width > 0 && image.height > 0)
            let bitmap = NSBitmapImageRep(cgImage: image)
            precondition(bitmap.hasAlpha, "Pose must preserve transparency")
            precondition(bitmap.colorAt(x: 0, y: 0)!.alphaComponent < 0.01, "Cell corner should be transparent")
            print("PASS pose \(index) decodes at \(image.width)×\(image.height) with transparency")
        }
        precondition(CharacterSprites.load(from: nil).isEmpty)
        precondition(CharacterSprites.load(from: URL(fileURLWithPath: "/missing-avatar-sheet.png")).isEmpty)
        print("PASS missing artwork handled without crash")
    }
}
