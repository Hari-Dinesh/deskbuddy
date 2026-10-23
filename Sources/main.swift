import AppKit
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import ServiceManagement

let app = NSApplication.shared
let migrationNotice = ProfileUpgrade.run()
let delegate = AppDelegate()
if migrationNotice.hasPrefix("Could not") { delegate.model.storageNotice = migrationNotice }
app.delegate = delegate
app.run()
