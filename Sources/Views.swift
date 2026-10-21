import AppKit
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import ServiceManagement

struct RobotCharacter: View {
    var blinking: Bool
    let blue = Color(red: 0.29, green: 0.46, blue: 0.98)
    let outline = Color(red: 0.09, green: 0.15, blue: 0.40)
    var body: some View {
        ZStack {
            // A tiny desktop character, drawn locally with native shapes.
            Capsule().fill(.black.opacity(0.16)).frame(width: 43, height: 7).offset(y: 65)
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5).fill(blue).frame(width: 17, height: 26)
                RoundedRectangle(cornerRadius: 5).fill(blue).frame(width: 17, height: 26)
            }.offset(y: 48)
            HStack(spacing: 51) {
                Capsule().fill(blue).frame(width: 16, height: 36).rotationEffect(.degrees(20))
                Capsule().fill(blue).frame(width: 16, height: 36).rotationEffect(.degrees(-20))
            }.offset(y: 26)
            RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Color(red: 0.51, green: 0.64, blue: 1), blue], startPoint: .top, endPoint: .bottom)).frame(width: 57, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(outline, lineWidth: 2))
                .overlay(Text("> _").font(.system(size: 19, weight: .heavy, design: .monospaced)).foregroundStyle(.white)).offset(y: 27)
            HStack(spacing: 68) {
                RoundedRectangle(cornerRadius: 11).fill(blue).frame(width: 19, height: 39)
                RoundedRectangle(cornerRadius: 11).fill(blue).frame(width: 19, height: 39)
            }.offset(y: -16)
            RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(red: 0.52, green: 0.66, blue: 1), blue], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 100, height: 84)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(outline, lineWidth: 2)).offset(y: -20)
            HStack(spacing: -3) {
                Circle().fill(Color(red: 0.52, green: 0.66, blue: 1)).frame(width: 42, height: 33)
                Circle().fill(Color(red: 0.47, green: 0.61, blue: 1)).frame(width: 42, height: 33)
            }.offset(y: -57)
            RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.11, green: 0.16, blue: 0.36)).frame(width: 77, height: 48)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(outline, lineWidth: 3))
                .overlay(Text(blinking ? "– _" : "> _").font(.system(size: 30, weight: .heavy, design: .monospaced)).foregroundStyle(Color(red: 0.50, green: 0.96, blue: 1)))
                .offset(y: -19)
        }.frame(width: 124, height: 148)
    }
}

struct Avatar: View {
    @ObservedObject var model: BuddyModel
    var size: CGFloat = 124
    var animated = false
    @State private var floating = false
    @State private var blinking = false

    private let blink = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack {
            if animated, let index = model.spriteIndex, CharacterSprites.frames.indices.contains(index) {
                ZStack {
                    Image(nsImage: CharacterSprites.frames[index]).resizable().interpolation(.high).scaledToFit().frame(width: size, height: size * 1.2)
                        .id(index)
                        .transition(.opacity)
                }
                    .animation(.linear(duration: 0.055), value: index)
                    .scaleEffect(x: model.phase == .leavingLeft ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(model.phase == .runningRight ? 8 : model.phase == .reacting ? sin(model.sceneProgress * .pi * 4) * 5 : 0), anchor: .bottom)
            } else if model.preferences.photo == nil, let image = CharacterSprites.idleImage {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit().frame(width: size, height: size * 1.2)
            } else {
                RobotCharacter(blinking: blinking).scaleEffect(size / 124)
                    .rotationEffect(.degrees(animated && model.phase.moving ? sin(model.sceneProgress * .pi * 18) * 4 : 0))
                    .scaleEffect(x: animated && model.phase == .leavingLeft ? -1 : 1, y: 1)
                if animated, let pose = model.spriteIndex {
                    Image(systemName: pose == 4 || pose == 5 ? "mug.fill" : pose == 6 ? "hand.thumbsup.fill" : pose == 7 ? "questionmark.bubble.fill" : "figure.walk")
                        .font(.system(size: size * 0.22)).foregroundStyle(.cyan)
                        .offset(x: size * 0.34, y: pose == 5 ? -size * 0.22 : size * 0.13)
                        .animation(.easeInOut(duration: 0.2), value: pose)
                }
                if let data = model.preferences.photo, let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().scaledToFill().frame(width: size * 0.56, height: size * 0.35).clipShape(RoundedRectangle(cornerRadius: size * 0.08)).offset(y: -19 * size / 124)
                }
            }
        }.frame(width: size, height: size * 1.2)
            .offset(y: animated && model.phase.moving ? sin(model.sceneProgress * .pi * 18) * 1 : floating ? -2 : 1)
            .animation(.easeInOut(duration: 0.16), value: model.phase)
            .onAppear { if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { floating = true } } }
            .onReceive(blink) { _ in
                guard model.preferences.photo != nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
                blinking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { blinking = false }
            }
    }
}

struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 8, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + 8, y: 0))
        path.closeSubpath()
        return path
    }
}

struct CompanionView: View {
    @ObservedObject var model: BuddyModel
    var body: some View {
        VStack(spacing: 0) {
            if let reminder = model.reminder, model.phase != .entering, !model.phase.departing {
                VStack(spacing: 8) {
                    Label(model.phase == .celebrating ? (model.scheduledReminderID == nil ? "Nice! Take care of yourself." : "All set.") : model.phase == .reacting ? "Okay, I'll check in later!" : model.alertTitle, systemImage: model.phase == .celebrating ? "checkmark.circle.fill" : reminder.symbol).font(.headline).lineLimit(2)
                    if model.phase.interactive {
                        Text(model.alertMessage).lineLimit(3).font(.callout).multilineTextAlignment(.center)
                        HStack {
                            Button(reminder == .meeting ? "Dismiss" : reminder == .quick ? "Done" : "Yes, I did") { model.done(reminder) }.buttonStyle(.borderedProminent).tint(.teal)
                            Button("Not yet") { model.snooze() }.buttonStyle(.bordered).help("Snooze for 10 minutes")
                        }
                        if let item = model.scheduledReminder, item.joinURL != nil {
                            Button("Open meeting") { model.workspace.open(item.joinURL) }
                        }
                        Text(reminder == .meeting ? "Not yet → remind me in 1 min" : "Not yet → remind me in 10 min").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.padding(14).frame(width: 280).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                BubbleTail().fill(.regularMaterial).frame(width: 280, height: 10)
            }
            Spacer(minLength: 0)
            Avatar(model: model, animated: true)
                .help("Drag to move · double-click for settings · right-click for actions")
                .onTapGesture(count: 2) { model.showSettings?() }
                .contextMenu {
                    Button("Notes, reminders & calendar…") { model.showWorkspace?() }
                    Button("Settings…") { model.showSettings?() }
                    Button("I had water") { model.done(.water) }
                    Button("Quiet for 1 hour") { model.pause() }
                    Button("Hide buddy") { model.toggleBuddy() }
                }
        }.padding(10).frame(width: model.reminder == nil ? 144 : 300, height: model.reminder == nil ? 174 : 360)
    }
}

struct SettingsView: View {
    @ObservedObject var model: BuddyModel
    func timeBinding(_ key: WritableKeyPath<Preferences, Int>) -> Binding<Date> {
        Binding(get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(model.preferences[keyPath: key] * 60)) }, set: { date in let c = Calendar.current.dateComponents([.hour, .minute], from: date); model.preferences[keyPath: key] = c.hour! * 60 + c.minute!; model.save() })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 18) {
                Avatar(model: model, size: 64)
                VStack(alignment: .leading, spacing: 5) { Text("A little care, while you work.").font(.title2.bold()); Text("DeskBuddy \(AppInfo.version) · local desktop companion").foregroundStyle(.secondary) }
            }
            Form {
                Section("Your workspace") {
                    Button("Notes, reminders & calendar…") { model.showWorkspace?() }
                }
                Section("Your avatar") {
                    TextField("Name", text: $model.preferences.name)
                    HStack { Button("Import custom avatar…") { model.importAvatar() }; Button("Reset to robot") { model.resetAvatar() } }
                    Button("Use local photo in robot…") { model.pickPhoto() }
                    if !model.avatarError.isEmpty { Text(model.avatarError).font(.caption).foregroundStyle(.orange) }
                }
                Section("Water & activity") {
                    Stepper("Remind after \(model.preferences.waterMinutes) active minutes", value: $model.preferences.waterMinutes, in: 5...180, step: 5)
                    Stepper("Pause after \(model.preferences.idleMinutes) minutes away", value: $model.preferences.idleMinutes, in: 1...30)
                    Text("Sleep and screen lock pause the timer. Reading without input counts as away after this threshold.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Meals · local Mac time") {
                    Toggle("Meal reminders", isOn: $model.preferences.mealsEnabled)
                    DatePicker("Breakfast", selection: timeBinding(\.breakfast), displayedComponents: .hourAndMinute)
                    DatePicker("Lunch", selection: timeBinding(\.lunch), displayedComponents: .hourAndMinute)
                    DatePicker("Dinner", selection: timeBinding(\.dinner), displayedComponents: .hourAndMinute)
                    Text("Each meal has a two-hour reminder window. Mark it done to stop reminders for today.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Desktop") {
                    Toggle("Play a gentle reminder sound", isOn: $model.preferences.sound)
                    Toggle("Open at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                    if !model.loginError.isEmpty { Text(model.loginError).font(.caption).foregroundStyle(.orange) }
                    Text(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? "macOS Reduce Motion is ON: real reminders skip travel. Preview animation plays the full sequence." : "Full animation is enabled.").font(.caption).foregroundStyle(.secondary)
                    Text(model.animationNotice.isEmpty ? "Animation poses: \(CharacterSprites.frames.count)/8" : model.animationNotice).font(.caption).foregroundStyle(CharacterSprites.frames.count == 8 ? Color.secondary : Color.secondary)
                    Text("Walks in for reminders. Yes → happy run to the right. Not yet → playful shrug to the left, then a 10-minute snooze. Reduce Motion skips travel.").font(.caption).foregroundStyle(.secondary)
                    HStack { Button("Quiet for 1 hour") { model.pause() }; Button("Resume") { model.resume() }; Button("Preview animation") { model.showPreview?() }.disabled(model.responding) }
                }
                Section("Today") {
                    Text("\(model.engine.waterCount) water breaks recorded")
                    HStack { ForEach([ReminderKind.breakfast, .lunch, .dinner], id: \.self) { kind in Button(model.engine.completed.contains(kind) ? "✓ \(kind.title)" : "Had \(kind.title)") { model.done(kind) }.disabled(model.engine.completed.contains(kind)) } }
                }
            }.formStyle(.grouped)
            Text("Drag the character to place it. Double-click for settings or right-click to hide; use the menu-bar drop to bring it back. Your photo and history stay on this Mac.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 530, height: 740)
            .onChange(of: model.preferences.name) { _ in model.save() }
            .onChange(of: model.preferences.waterMinutes) { _ in model.save() }
            .onChange(of: model.preferences.idleMinutes) { _ in model.save() }
            .onChange(of: model.preferences.mealsEnabled) { _ in model.save() }
            .onChange(of: model.preferences.sound) { _ in model.save() }
    }
}

