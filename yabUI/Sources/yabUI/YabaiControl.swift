import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

enum ServicePhase: Equatable {
    case unknown
    case stopped
    case starting
    case running
    case stopping
    case restarting
    case unavailable

    var title: String {
        switch self {
        case .unknown: return "Checking service"
        case .stopped: return "Yabai is stopped"
        case .starting: return "Starting Yabai"
        case .running: return "Yabai is running"
        case .stopping: return "Stopping Yabai"
        case .restarting: return "Restarting Yabai"
        case .unavailable: return "Yabai unavailable"
        }
    }

    var detail: String {
        switch self {
        case .unknown: return "Checking the bundled runtime."
        case .stopped: return "Start the service to manage your windows."
        case .starting: return "Waiting for the service to become ready…"
        case .running: return "Your window manager is ready for commands."
        case .stopping: return "Finishing the current service operation…"
        case .restarting: return "Reconnecting to the workspace…"
        case .unavailable: return "Check Accessibility permission, then try again."
        }
    }

    var isTransitioning: Bool {
        switch self {
        case .starting, .stopping, .restarting: return true
        default: return false
        }
    }
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available(UpdateInfo)
    case downloading
    case downloaded(URL)
    case failed(String)
}

struct UpdateInfo: Equatable {
    let version: String
    let releaseURL: URL
    let downloadURL: URL?
    let publishedAt: Date?
}

@main
struct YabUIApp: App {
    @StateObject private var model = YabaiModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 860, idealWidth: 900, maxWidth: 1100, minHeight: 560, idealHeight: 620, maxHeight: 780)
        }
        .defaultSize(width: 900, height: 620)
        .windowResizability(.contentSize)
        MenuBarExtra("yabUI", systemImage: "rectangle.3.group.fill") {
            StatusSurfaceView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About yabUI") { NSApp.orderFrontStandardAboutPanel(nil) }
            }
            CommandMenu("Yabai") {
                Button(model.isRunning ? "Stop Service" : "Start Service") { model.toggleService() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Refresh") { model.refresh() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case workspace = "Workspace"
    case settings = "Settings"
    case activity = "Activity"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .workspace: return "rectangle.3.group"
        case .settings: return "slider.horizontal.3"
        case .activity: return "terminal"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: YabaiModel
    @State private var selection: AppSection = .overview

    var body: some View {
        VStack(spacing: 0) {
            HorizontalTabBar(selection: $selection)
            Divider()
            ZStack {
                LinearGradient(colors: [Color.blue.opacity(0.075), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                switch selection {
                case .overview: OverviewView()
                case .workspace: WorkspaceView()
                case .settings: SettingsView()
                case .activity: ActivityView()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Yabai state")
            }
        }
        .task {
            model.startPolling()
        }
        .sheet(isPresented: $model.showOnboarding) {
            OnboardingView()
                .environmentObject(model)
        }
    }
}

struct HorizontalTabBar: View {
    @EnvironmentObject private var model: YabaiModel
    @Binding var selection: AppSection

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.3.group.fill")
                    .foregroundStyle(.blue)
                Text("yabUI")
                    .font(.headline.weight(.semibold))
            }
            .padding(.leading, 4)
            Spacer(minLength: 10)
            ForEach(AppSection.allCases) { section in
                HorizontalTabButton(section: section, selection: $selection)
            }
            Spacer(minLength: 10)
            HStack(spacing: 10) {
                Circle()
                    .fill(model.isRunning ? Color.green : Color.secondary)
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.servicePhase.title)
                        .font(.caption.weight(.semibold))
                    Text(model.version.isEmpty ? model.servicePhase.detail : model.version)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

struct HorizontalTabButton: View {
    let section: AppSection
    @Binding var selection: AppSection

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selection = section }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: section.icon)
                Text(section.rawValue)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(selection == section ? .primary : .secondary)
            .background {
                if selection == section {
                    Capsule().fill(.ultraThinMaterial)
                } else {
                    Capsule().fill(Color.clear)
                }
            }
            .overlay(Capsule().strokeBorder(selection == section ? Color.blue.opacity(0.32) : .clear))
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var model: YabaiModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let steps = ["Welcome", "Permission", "Setup", "Ready"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.3.group.fill")
                        .foregroundStyle(.blue)
                    Text("yabUI setup")
                        .font(.headline.weight(.semibold))
                }
                Spacer()
                Text("Step \(step + 1) of \(steps.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                switch step {
                case 0:
                    OnboardingPage(
                        icon: "sparkles",
                        title: "Welcome to yabUI",
                        message: "A small native control surface for your spaces, windows, and layout commands. This quick setup takes less than a minute."
                    ) {
                        Label("See your desktop as a live map", systemImage: "square.grid.2x2.fill")
                        Label("Move and split windows with drag and drop", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                        Label("Control the service from the app or menu bar", systemImage: "menubar.rectangle")
                    }
                case 1:
                    OnboardingPage(
                        icon: "lock.shield",
                        title: "Allow window control",
                        message: "The window manager runs as a small bundled helper inside yabUI. macOS requires that helper to be approved in Accessibility before it can read or arrange windows."
                    ) {
                        HStack(spacing: 10) {
                            Button("Reveal bundled runtime") {
                                model.revealBundledRuntime()
                            }
                            .buttonStyle(.bordered)

                            Button("Open Accessibility settings") {
                                model.openAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Text("Add the revealed “yabUI Runtime” helper to System Settings → Privacy & Security → Accessibility. Approving only yabUI or an older yabai entry is not sufficient because macOS checks each executable separately.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(model.runtimeStatusText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(model.runtimeIsUsable ? .green : .orange)
                    }
                case 2:
                    OnboardingPage(
                        icon: "slider.horizontal.3",
                        title: "Choose a safe starting setup",
                        message: "yabUI uses the bundled runtime and a private launch service. It does not install a separate command-line copy or recreate the legacy service entry."
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("BSP layout with automatic split direction", systemImage: "rectangle.split.3x1")
                            Label("No focus changes while you drag a tile", systemImage: "cursorarrow.motionlines")
                            Label("Service state is verified before the UI shows it as ready", systemImage: "checkmark.shield")
                        }
                        Button {
                            model.applyRecommendedConfiguration()
                        } label: {
                            Label(model.servicePhase.isTransitioning ? "Starting…" : "Start yabUI service", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.servicePhase.isTransitioning)
                    }
                default:
                    OnboardingPage(
                        icon: "checkmark.circle.fill",
                        title: "You’re ready",
                        message: "Use Overview for a quick read, Workspace for direct manipulation, and the menu-bar surface for fast controls. You can reopen this guide from Settings."
                    ) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(model.isRunning ? Color.green : Color.secondary)
                                .frame(width: 8, height: 8)
                            Text(model.servicePhase.title)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(28)

            Divider()

            HStack {
                Button("Back") { step = max(0, step - 1) }
                    .disabled(step == 0)
                Spacer()
                Button(step == steps.count - 1 ? "Finish" : "Continue") {
                    if step == steps.count - 1 {
                        model.completeOnboarding()
                        dismiss()
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 560, height: 430)
    }
}

struct OnboardingPage<Content: View>: View {
    let icon: String
    let title: String
    let message: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
                .padding(.top, 4)
        }
    }
}

struct StatusSurfaceView: View {
    @EnvironmentObject private var model: YabaiModel
    @StateObject private var dropCoordinator = WorkspaceDropCoordinator()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(model.isRunning ? Color.green.opacity(0.18) : Color.white.opacity(0.10))
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(model.isRunning ? .green : .primary)
                }
                .frame(width: 42, height: 42)
                .overlay(Circle().strokeBorder(model.isRunning ? Color.green.opacity(0.45) : Color.white.opacity(0.16)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("yabUI")
                        .font(.headline.weight(.bold))
                    Text(model.servicePhase.title)
                        .font(.caption)
                        .foregroundStyle(model.isRunning ? .green : .secondary)
                }
                Spacer()
                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh workspace")
            }

            Button {
                model.toggleService()
            } label: {
                Label(model.isRunning ? "Stop Yabai" : "Start Yabai", systemImage: model.isRunning ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.servicePhase.isTransitioning)

            HStack(spacing: 8) {
                Button { model.restartService() } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.servicePhase.isTransitioning)
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first(where: { $0.title == "yabUI" })?.makeKeyAndOrderFront(nil)
                } label: {
                    Label("Open app", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Divider()
            HStack {
                Text("Live workspace")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Drag tiles to move or split")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            StatusSurfaceMapView()
                .environmentObject(dropCoordinator)

            HStack(spacing: 8) {
                StatusQuickAction(title: "Balance", icon: "circle.lefthalf.filled") { model.spaceAction("--balance") }
                StatusQuickAction(title: "Float", icon: "rectangle.on.rectangle") { model.windowAction("--toggle float") }
                StatusQuickAction(title: "Zoom", icon: "arrow.up.left.and.arrow.down.right") { model.windowAction("--toggle zoom-fullscreen") }
                StatusQuickAction(title: "Rotate", icon: "rotate.right") { model.spaceAction("--rotate 90") }
            }

            Divider()
            HStack {
                Text("Space controls")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let currentSpace = model.currentSpaceIndex {
                    Text("Space \(currentSpace)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                StatusQuickAction(title: "New space", icon: "plus.rectangle.on.rectangle") {
                    model.createSpace()
                }
                StatusQuickAction(title: "Close space", icon: "minus.rectangle") {
                    if let currentSpace = model.currentSpaceIndex { model.closeSpace(currentSpace) }
                }
                StatusQuickAction(title: "Tile prev", icon: "arrow.left.to.line") {
                    model.moveFocusedWindowToAdjacentSpace(.previous)
                }
                StatusQuickAction(title: "Tile next", icon: "arrow.right.to.line") {
                    model.moveFocusedWindowToAdjacentSpace(.next)
                }
            }
            HStack(spacing: 8) {
                StatusQuickAction(title: "Min all", icon: "minus.square") {
                    model.minimizeAllWindows(in: model.currentSpaceIndex)
                }
                StatusQuickAction(title: "Max all", icon: "arrow.up.left.and.arrow.down.right.square") {
                    model.maximizeAllWindows(in: model.currentSpaceIndex)
                }
            }

            if !model.logs.isEmpty, let log = model.logs.first {
                HStack(spacing: 6) {
                    Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(log.success ? .green : .red)
                    Text(log.command)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 430)
        .onPreferenceChange(WorkspaceSpaceFrameKey.self) { frames in
            dropCoordinator.spaceFrames = frames
        }
        .onPreferenceChange(WorkspaceWindowFrameKey.self) { frames in
            dropCoordinator.windowFrames = frames
        }
    }
}

struct StatusQuickAction: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(title).font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct StatusSurfaceMapView: View {
    @EnvironmentObject private var model: YabaiModel
    @EnvironmentObject private var dropCoordinator: WorkspaceDropCoordinator

    private var visibleWindows: [YabaiWindow] {
        model.windows.filter { $0.isRenderable }
    }

    var body: some View {
        if visibleWindows.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.dashed")
                Text(model.isRunning ? "No visible windows" : "Start Yabai to inspect windows")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 118)
            .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        } else {
            GeometryReader { geometry in
                let mapGeometry = UnifiedWindowMapLayout.geometry(windows: visibleWindows, canvasSize: geometry.size)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.16))
                        .allowsHitTesting(false)
                    UnifiedMapGridBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    ForEach(mapGeometry.spaceRects.keys.sorted(), id: \.self) { space in
                        if let rect = mapGeometry.spaceRects[space] {
                            StatusMapSpaceDropZone(space: space, rect: rect)
                        }
                    }

                    ForEach(visibleWindows) { window in
                        if let rect = mapGeometry.windowRects[window.id] {
                            StatusSurfaceWindowTile(window: window, rect: rect)
                        }
                    }

                    ForEach(mapGeometry.spaceLabels.keys.sorted(), id: \.self) { space in
                        if let labelRect = mapGeometry.spaceLabels[space] {
                            Text("S\(space)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.black.opacity(0.25), in: Capsule())
                                .position(x: labelRect.midX, y: labelRect.midY)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 210)
        }
    }
}

struct StatusMapSpaceDropZone: View {
    @EnvironmentObject private var model: YabaiModel
    @EnvironmentObject private var dropCoordinator: WorkspaceDropCoordinator
    let space: Int
    let rect: CGRect

    var body: some View {
        Color.clear
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: WorkspaceSpaceFrameKey.self, value: [space: proxy.frame(in: .global)])
            })
            .overlay {
                if case .space(let targetID, _) = dropCoordinator.activePreview, targetID == space {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.orange.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .padding(2)
                        .allowsHitTesting(false)
                }
            }
            // Empty space areas are controls too. Keep them below window
            // tiles so a tile click wins, while the surrounding space
            // background focuses that space deterministically.
            .contentShape(Rectangle())
            .onTapGesture { model.focusSpace(space) }
            .zIndex(1)
    }
}

struct StatusSurfaceWindowTile: View {
    @EnvironmentObject private var model: YabaiModel
    @EnvironmentObject private var dropCoordinator: WorkspaceDropCoordinator
    let window: YabaiWindow
    let rect: CGRect
    @State private var didDrag = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(window.isFocused ? Color.blue.opacity(0.60) : Color.white.opacity(0.17))
            AppIconView(
                appName: window.app.isEmpty ? "Unknown app" : window.app,
                size: min(30, max(14, min(rect.width, rect.height) * 0.38))
            )
        }
        .frame(width: rect.width, height: rect.height)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(window.isFocused ? Color.blue : Color.white.opacity(0.24), lineWidth: window.isFocused ? 2 : 1)
            if case .window(let targetID, let intent) = dropCoordinator.activePreview, targetID == window.id {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(intent == .center ? 0.22 : 0.14))
                    .overlay(Text(intent.label).font(.caption2.weight(.bold)).foregroundStyle(.white))
                    .allowsHitTesting(false)
            }
        }
        .background(GeometryReader { proxy in
            Color.clear.preference(key: WorkspaceWindowFrameKey.self, value: [window.id: proxy.frame(in: .global)])
        })
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .zIndex(10)
        .onTapGesture {
            guard !didDrag else { return }
            model.focusWindow(window.id)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in
                    didDrag = true
                    dropCoordinator.updatePreview(for: WorkspaceDragItem(kind: "window", id: window.id), at: value.location, model: model)
                }
                .onEnded { value in
                    dropCoordinator.handleDrop(WorkspaceDragItem(kind: "window", id: window.id), at: value.location, model: model)
                    resetDragGuard()
                }
        )
        .help("Click to focus · drag to move or split · \(window.app.isEmpty ? "Window" : window.app)")
        .contextMenu {
            Text(window.app.isEmpty ? "Window" : window.app)
            Divider()
            Button("Move to previous space") {
                model.moveWindowToAdjacentSpace(window.id, direction: .previous)
            }
            .disabled(model.adjacentSpaceIndex(from: window.space, direction: .previous) == nil)
            Button("Move to next space") {
                model.moveWindowToAdjacentSpace(window.id, direction: .next)
            }
            .disabled(model.adjacentSpaceIndex(from: window.space, direction: .next) == nil)
        }
    }

    private func resetDragGuard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            didDrag = false
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusCard: View {
    @EnvironmentObject private var model: YabaiModel
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.servicePhase.title)
                        .font(.title2.weight(.bold))
                    Text(model.servicePhase.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(model.isRunning ? .green : .secondary).frame(width: 8, height: 8)
                    Text(model.version.isEmpty ? "Yabai" : model.version).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            Button {
                model.toggleService()
            } label: {
                Label(model.isRunning ? "Stop Yabai" : "Start Yabai", systemImage: model.isRunning ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.servicePhase.isTransitioning)
            HStack(spacing: 10) {
                Button { model.restartService() } label: { Label("Restart", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                    .disabled(model.servicePhase.isTransitioning)
                Button { model.refresh() } label: { Label("Refresh", systemImage: "arrow.triangle.2.circlepath") }
                    .buttonStyle(.bordered)
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
    }
}

struct DataStatusBanner: View {
    let title: String
    let message: String

    init(title: String = "Yabai data is unavailable", message: String) {
        self.title = title
        self.message = message
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.24)))
    }
}

struct OverviewView: View {
    @EnvironmentObject private var model: YabaiModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(title: "Overview", subtitle: "A calmer way to control your macOS tiling setup.")
                StatusCard()
                if model.shouldShowWarning, let dataError = model.dataError {
                    DataStatusBanner(message: dataError)
                }
                HStack(spacing: 14) {
                    MetricCard(title: "Windows", value: "\(model.windows.count)", icon: "macwindow.on.rectangle")
                    MetricCard(title: "Spaces", value: "\(model.spaces.count)", icon: "rectangle.3.group")
                    MetricCard(title: "Displays", value: "\(model.displays.count)", icon: "display.2")
                }
                HStack(alignment: .top, spacing: 18) {
                    QuickActionsCard()
                    RecentActivityCard()
                }
                WindowMapCard()
                OpenAppsCard()
            }
            .padding(20)
        }
    }
}

struct MetricCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.weight(.bold))
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(13)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionsCard: View {
    @EnvironmentObject private var model: YabaiModel
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        Card(title: "Quick actions", subtitle: "Common commands at your fingertips.") {
            LazyVGrid(columns: columns, spacing: 10) {
                ActionButton("Balance", icon: "circle.lefthalf.filled", action: { model.spaceAction("--balance") })
                ActionButton("Float / tile", icon: "rectangle.dashed", action: { model.windowAction("--toggle float") })
                ActionButton("Zoom", icon: "arrow.up.left.and.arrow.down.right", action: { model.windowAction("--toggle zoom-fullscreen") })
                ActionButton("Rotate", icon: "rotate.right", action: { model.spaceAction("--rotate 90") })
                ActionButton("Move space", icon: "rectangle.portrait.and.arrow.right", action: { model.windowAction("--space next") })
                ActionButton("Toggle sticky", icon: "pin", action: { model.windowAction("--toggle sticky") })
                ActionButton("Toggle topmost", icon: "rectangle.topthird.inset.filled", action: { model.windowAction("--toggle topmost") })
                ActionButton("Toggle split", icon: "rectangle.split.3x1", action: { model.windowAction("--toggle split") })
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecentActivityCard: View {
    @EnvironmentObject private var model: YabaiModel
    var body: some View {
        Card(title: "Recent activity", subtitle: "The last few commands sent to Yabai.") {
            if model.logs.isEmpty {
                ContentUnavailableView("No activity yet", systemImage: "text.bubble", description: Text("Actions you take in the app will appear here."))
                    .frame(maxWidth: .infinity, minHeight: 170)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.logs.prefix(5)) { log in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(log.success ? .green : .red)
                            Text(log.command).font(.system(.caption, design: .monospaced)).lineLimit(1)
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct WindowMapCard: View {
    @EnvironmentObject private var model: YabaiModel

    private var visibleWindows: [YabaiWindow] {
        model.windows.filter { $0.isRenderable }
    }

    private var spaceCount: Int {
        Set(visibleWindows.map(\.space)).count
    }

    private var mapHeight: CGFloat {
        let rows = max(1, (spaceCount + 2) / 3)
        return max(240, min(390, CGFloat(rows) * 112 + 24))
    }

    var body: some View {
        Card(title: "Window map", subtitle: "All visible windows in one live map. Click a tile to focus that window.") {
            if visibleWindows.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: model.windows.isEmpty ? "square.grid.2x2" : "eye.slash")
                        .font(.title2).foregroundStyle(.secondary)
                    Text(model.windows.isEmpty
                         ? (model.isRunning ? "No managed windows to visualize yet." : "Start Yabai to see your live window layout.")
                         : "All managed windows are minimized or hidden.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                GeometryReader { geometry in
                    let mapGeometry = UnifiedWindowMapLayout.geometry(windows: visibleWindows, canvasSize: geometry.size)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(Color.black.opacity(0.16))
                        UnifiedMapGridBackground()
                            .clipShape(RoundedRectangle(cornerRadius: 13))

                        ForEach(mapGeometry.spaceLabels.keys.sorted(), id: \.self) { space in
                            if let labelRect = mapGeometry.spaceLabels[space] {
                                Text("S\(space)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.24), in: Capsule())
                                    .position(x: labelRect.midX, y: labelRect.midY)
                            }
                        }

                        ForEach(visibleWindows) { window in
                            if let rect = mapGeometry.windowRects[window.id] {
                                UnifiedOverviewWindowTile(window: window, rect: rect)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .frame(height: mapHeight)

                let minimized = model.windows.filter { $0.isMinimized || $0.isHidden }.count
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3.fill")
                        .foregroundStyle(.blue)
                    Text("\(visibleWindows.count) visible windows across \(spaceCount) spaces")
                    if minimized > 0 {
                        Text("· \(minimized) minimized or hidden")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct UnifiedMapGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 28
            var path = Path()
            stride(from: step, to: size.width, by: step).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: step, to: size.height, by: step).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.035)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

struct UnifiedOverviewWindowTile: View {
    @EnvironmentObject private var model: YabaiModel
    let window: YabaiWindow
    let rect: CGRect

    var body: some View {
        Button { model.focusWindow(window.id) } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(window.isFocused ? Color.blue.opacity(0.58) : Color.white.opacity(0.16))
                AppIconView(
                    appName: window.app.isEmpty ? "Unknown app" : window.app,
                    size: min(38, max(16, min(rect.width, rect.height) * 0.34))
                )
            }
            .frame(width: rect.width, height: rect.height)
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(window.isFocused ? Color.blue : Color.white.opacity(0.22), lineWidth: window.isFocused ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .position(x: rect.midX, y: rect.midY)
        .help("Focus \(window.app.isEmpty ? "window" : window.app): \(window.title.isEmpty ? "Untitled" : window.title)")
    }
}

struct UnifiedWindowMapGeometry {
    let windowRects: [Int: CGRect]
    let spaceLabels: [Int: CGRect]
    let spaceRects: [Int: CGRect]
}

enum UnifiedWindowMapLayout {
    static func geometry(windows: [YabaiWindow], canvasSize: CGSize) -> UnifiedWindowMapGeometry {
        let inset: CGFloat = 12
        let gap: CGFloat = 10
        let groups = Dictionary(grouping: windows, by: { $0.space })
            .sorted { $0.key < $1.key }
        let columns = max(1, min(3, groups.count <= 2 ? groups.count : 3))
        let rows = max(1, Int(ceil(Double(groups.count) / Double(columns))))
        let availableWidth = max(canvasSize.width - inset * 2, 1)
        let availableHeight = max(canvasSize.height - inset * 2, 1)
        let slotWidth = max((availableWidth - CGFloat(columns - 1) * gap) / CGFloat(columns), 1)
        let slotHeight = max((availableHeight - CGFloat(rows - 1) * gap) / CGFloat(rows), 1)

        var windowRects: [Int: CGRect] = [:]
        var spaceLabels: [Int: CGRect] = [:]
        var spaceRects: [Int: CGRect] = [:]

        for (index, group) in groups.enumerated() {
            let column = index % columns
            let row = index / columns
            let slot = CGRect(
                x: inset + CGFloat(column) * (slotWidth + gap),
                y: inset + CGFloat(row) * (slotHeight + gap),
                width: slotWidth,
                height: slotHeight
            )
            spaceRects[group.key] = slot
            let labelHeight: CGFloat = 18
            spaceLabels[group.key] = CGRect(x: slot.minX + 8, y: slot.minY + 5, width: 36, height: 16)
            let content = CGRect(
                x: slot.minX + 5,
                y: slot.minY + labelHeight + 5,
                width: max(slot.width - 10, 1),
                height: max(slot.height - labelHeight - 10, 1)
            )
            windowRects.merge(packedRects(group.value, in: content)) { _, new in new }
        }
        return UnifiedWindowMapGeometry(windowRects: windowRects, spaceLabels: spaceLabels, spaceRects: spaceRects)
    }

    private static func packedRects(_ windows: [YabaiWindow], in rect: CGRect) -> [Int: CGRect] {
        guard !windows.isEmpty else { return [:] }
        let sorted = windows.sorted {
            let left = $0.frame
            let right = $1.frame
            if left?.y != right?.y { return (left?.y ?? 0) < (right?.y ?? 0) }
            return (left?.x ?? 0) < (right?.x ?? 0)
        }

        var rows: [[YabaiWindow]] = []
        for window in sorted {
            let y = window.frame?.y ?? 0
            if let last = rows.indices.last,
               let anchor = rows[last].compactMap(\.frame).map(\.y).min(),
               abs(y - anchor) <= 28 {
                rows[last].append(window)
            } else {
                rows.append([window])
            }
        }

        let rowHeights = rows.map { row in max(row.compactMap(\.frame).map(\.h).max() ?? 1, 1) }
        let rowWidths = rows.map { row in row.reduce(CGFloat.zero) { $0 + max($1.frame?.w ?? 1, 1) } }
        let sourceHeight = rowHeights.reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * 8
        let sourceWidth = rowWidths.max() ?? 1
        let scale = min(
            rect.width / max(sourceWidth + 8, 1),
            rect.height / max(sourceHeight + 8, 1)
        )

        var result: [Int: CGRect] = [:]
        var y = rect.minY + max((rect.height - sourceHeight * scale) / 2, 0)
        for (rowIndex, row) in rows.enumerated() {
            let widths = row.map { max($0.frame?.w ?? 1, 1) * scale }
            let rowGap = CGFloat(max(row.count - 1, 0)) * 6
            let rowWidth = widths.reduce(0, +) + rowGap
            var x = rect.minX + max((rect.width - rowWidth) / 2, 0)
            let rowHeight = rowHeights[rowIndex] * scale
            for (windowIndex, window) in row.enumerated() {
                let width = widths[windowIndex]
                result[window.id] = CGRect(x: x, y: y, width: max(width, 18), height: max(rowHeight, 18))
                x += width + 6
            }
            y += rowHeight + 8
        }
        return result
    }
}

struct OpenAppsCard: View {
    @EnvironmentObject private var model: YabaiModel

    var body: some View {
        let apps = Dictionary(grouping: model.windows, by: { $0.app.isEmpty ? "Unknown app" : $0.app })
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        Card(title: "Open apps", subtitle: "Applications currently represented in Yabai.") {
            if apps.isEmpty {
                Text(model.isRunning ? "No managed applications found." : "Start Yabai to see the applications it manages.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(apps, id: \.key) { app, windows in
                            HStack(spacing: 8) {
                                AppIconView(appName: app, size: 26)
                                Text("\(windows.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                            .help("\(app) — \(windows.count) \(windows.count == 1 ? "window" : "windows")")
                        }
                    }
                }
            }
        }
    }
}

struct WindowMapBounds {
    let minX: CGFloat
    let minY: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(windows: [YabaiWindow], displayFrame: YabaiFrame? = nil) {
        if let displayFrame {
            minX = displayFrame.x
            minY = displayFrame.y
            width = max(displayFrame.w, 1)
            height = max(displayFrame.h, 1)
            return
        }
        let frames = windows.compactMap(\.frame)
        let lowX = frames.map(\.x).min() ?? 0
        let lowY = frames.map(\.y).min() ?? 0
        let highX = frames.map { $0.x + $0.w }.max() ?? 1920
        let highY = frames.map { $0.y + $0.h }.max() ?? 1080
        minX = lowX
        minY = lowY
        width = max(highX - lowX, 1)
        height = max(highY - lowY, 1)
    }
}

struct AppIconView: View {
    let appName: String
    var size: CGFloat = 20

    var body: some View {
        Image(nsImage: Self.icon(for: appName))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .help(appName)
    }

    private static func icon(for appName: String) -> NSImage {
        if let application = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }),
           let icon = application.icon {
            return icon
        }
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: appName) ?? NSImage()
    }
}

struct FloatingWindowStrip: View {
    let windows: [YabaiWindow]

    var body: some View {
        if !windows.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    ForEach(windows) { window in
                        AppIconView(appName: window.app.isEmpty ? "Unknown app" : window.app, size: 20)
                            .help("Utility or floating: \(window.app.isEmpty ? "Window" : window.app) — \(window.title.isEmpty ? "Untitled" : window.title)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.25)))
        }
    }
}

struct WindowTile: View {
    let window: YabaiWindow
    let bounds: WindowMapBounds
    let canvasSize: CGSize

    var body: some View {
        if let tileRect = WindowTileLayout.rect(window: window, bounds: bounds, canvasSize: canvasSize) {
            let iconSize = min(24, max(9, min(tileRect.width, tileRect.height) - 4))
            AppIconView(appName: window.app.isEmpty ? "Unknown app" : window.app, size: iconSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            .frame(width: tileRect.width, height: tileRect.height, alignment: .center)
            .background(window.isFocused ? Color.blue.opacity(0.52) : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(window.isFocused ? Color.blue : Color.white.opacity(0.16), lineWidth: window.isFocused ? 2 : 1))
            .position(x: tileRect.midX, y: tileRect.midY)
            .help("\(window.app.isEmpty ? "Window" : window.app) — \(window.title.isEmpty ? "Untitled" : window.title)")
        }
    }
}

struct WindowTileLayout {
    static func rect(window: YabaiWindow, bounds: WindowMapBounds, canvasSize: CGSize) -> CGRect? {
        guard let frame = window.frame else { return nil }
        let inset: CGFloat = 8
        let availableWidth = max(canvasSize.width - inset * 2, 1)
        let availableHeight = max(canvasSize.height - inset * 2, 1)
        let scale = min(availableWidth / bounds.width, availableHeight / bounds.height)
        let contentWidth = bounds.width * scale
        let contentHeight = bounds.height * scale
        let originX = (canvasSize.width - contentWidth) / 2
        let originY = (canvasSize.height - contentHeight) / 2
        let width = max(frame.w * scale, 10)
        let height = max(frame.h * scale, 10)
        let x = originX + ((frame.x - bounds.minX) + frame.w / 2) * scale
        let y = originY + ((frame.y - bounds.minY) + frame.h / 2) * scale
        return CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
    }
}

struct Card<Content: View>: View {
    let title: String; let subtitle: String; @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(0.07)))
    }
}

struct ActionButton: View {
    let title: String; let icon: String; let action: () -> Void
    init(_ title: String, icon: String, action: @escaping () -> Void) { self.title = title; self.icon = icon; self.action = action }
    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.weight(.medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.bordered)
    }
}

struct WorkspaceView: View {
    @EnvironmentObject private var model: YabaiModel
    @StateObject private var dropCoordinator = WorkspaceDropCoordinator()

    private var spaceReorderNeedsScriptingAddition: Bool {
        model.spaceReorderUnavailable || model.logs.contains {
            !$0.success && $0.command.contains("yabai -m space") && ($0.command.contains("--move") || $0.command.contains("--swap"))
        }
    }

    private var displayIndices: [Int] {
        Array(Set(model.displays.map(\.index) + model.spaces.map(\.display))).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "Workspace", subtitle: "Displays, spaces, and windows in one actionable hierarchy.")
            if model.shouldShowWarning, let dataError = model.dataError {
                DataStatusBanner(message: dataError)
            }
            if spaceReorderNeedsScriptingAddition {
                DataStatusBanner(title: "Space reordering needs setup", message: "Yabai's scripting addition is not loaded. Window moves still work; enable it and retry the drop.")
            }
            if displayIndices.isEmpty {
                ContentUnavailableView("No workspace data", systemImage: "rectangle.3.group", description: Text(model.isRunning ? "Yabai returned no display or space records." : "Start Yabai to inspect your workspace."))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(displayIndices, id: \.self) { displayIndex in
                            WorkspaceDisplayBoard(displayIndex: displayIndex)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(20)
        .environmentObject(dropCoordinator)
        .onPreferenceChange(WorkspaceSpaceFrameKey.self) { frames in
            dropCoordinator.spaceFrames = frames
        }
        .onPreferenceChange(WorkspaceWindowFrameKey.self) { frames in
            dropCoordinator.windowFrames = frames
        }
    }
}

struct WorkspaceDisplayBoard: View {
    @EnvironmentObject private var model: YabaiModel
    let displayIndex: Int
    @State private var isDropTargeted = false

    private var spaces: [YabaiSpace] {
        model.spaces.filter { $0.display == displayIndex }.sorted { $0.index < $1.index }
    }

    private var displayFrame: YabaiFrame? {
        model.displays.first(where: { $0.index == displayIndex })?.frame
    }

    private var spaceTileHeight: CGFloat { 248 }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                Image(systemName: "display.2").foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Display \(displayIndex)").font(.headline)
                    Text("Drag spaces between displays or windows onto a space")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.createSpace(onDisplay: displayIndex)
                } label: {
                    Label("New space", systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Focus") { model.focusDisplay(displayIndex) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(spaces) { space in
                        WorkspaceSpaceTile(space: space, displayIndex: displayIndex, displayFrame: displayFrame, tileHeight: spaceTileHeight)
                    }
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(isDropTargeted ? Color.blue : Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .frame(width: 118, height: spaceTileHeight)
                        .overlay {
                            VStack(spacing: 7) {
                                Image(systemName: "rectangle.3.group.badge.plus")
                                    .font(.title2)
                                Text("Drop a space here")
                                    .font(.caption.weight(.semibold))
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(.secondary)
                            .padding(12)
                        }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isDropTargeted ? Color.blue.opacity(0.7) : Color.white.opacity(0.08), lineWidth: isDropTargeted ? 2 : 1))
        .onDrop(of: WorkspaceDragItem.acceptedTypes, isTargeted: $isDropTargeted) { providers, _ in
            handleDrop(providers, targetSpace: nil)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], targetSpace: Int?) -> Bool {
        guard let provider = providers.first else { return false }
        WorkspaceDragItem.decode(provider) { item in
            guard let item else { return }
            Task { @MainActor in
                model.handleWorkspaceDrop(item, targetSpace: targetSpace, targetDisplay: displayIndex)
            }
        }
        return true
    }
}

struct WorkspaceSpaceTile: View {
    @EnvironmentObject private var model: YabaiModel
    @EnvironmentObject private var dropCoordinator: WorkspaceDropCoordinator
    let space: YabaiSpace
    let displayIndex: Int
    let displayFrame: YabaiFrame?
    let tileHeight: CGFloat
    @State private var isDropTargeted = false
    @State private var spaceDragOffset = CGSize.zero

    private var allWindows: [YabaiWindow] {
        model.windows.filter { $0.space == space.index }
    }

    private var windows: [YabaiWindow] {
        allWindows.filter { $0.isRenderable }
    }

    private var tiledWindows: [YabaiWindow] {
        windows.filter { !$0.isOverlayWindow }
    }

    private var floatingWindows: [YabaiWindow] {
        windows.filter { $0.isOverlayWindow }
    }

    private var minimizedCount: Int {
        allWindows.filter { $0.isMinimized || $0.isHidden }.count
    }

    private var windowSummary: String {
        let countLabel = "\(allWindows.count) \(allWindows.count == 1 ? "window" : "windows")"
        var details: [String] = []
        if minimizedCount > 0 { details.append("\(minimizedCount) minimized") }
        if !floatingWindows.isEmpty { details.append("\(floatingWindows.count) floating") }
        return details.isEmpty ? countLabel : "\(countLabel) · " + details.joined(separator: " · ")
    }

    private var mapHeight: CGFloat {
        guard let displayFrame else { return 112 }
        let aspect = max(displayFrame.w / max(displayFrame.h, 1), 1)
        return max(104, min(138, 200 / aspect))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: space.isFocused ? "circle.inset.filled" : "circle")
                    .foregroundStyle(space.isFocused ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(space.label.isEmpty ? "Space \(space.index)" : space.label)
                        .font(.subheadline.weight(.bold))
                    Text("\(windowSummary) · \(space.layout)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if space.isFocused { Text("●").font(.caption2).foregroundStyle(.blue) }
            }
            .contentShape(Rectangle())
            .onTapGesture { model.focusSpace(space.index) }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { value in
                        spaceDragOffset = value.translation
                        dropCoordinator.updatePreview(for: WorkspaceDragItem(kind: "space", id: space.index), at: value.location, model: model)
                    }
                    .onEnded { value in
                        dropCoordinator.handleDrop(WorkspaceDragItem(kind: "space", id: space.index), at: value.location, model: model)
                        spaceDragOffset = .zero
                    }
            )
            .offset(spaceDragOffset)

            Group {
                if !floatingWindows.isEmpty {
                    FloatingWindowStrip(windows: floatingWindows)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)

            GeometryReader { geometry in
                let bounds = WindowMapBounds(windows: tiledWindows, displayFrame: displayFrame)
                let mapFrame = geometry.frame(in: .global)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.15))
                    if tiledWindows.isEmpty {
                        VStack(spacing: 4) {
                            Image(systemName: windows.isEmpty ? (minimizedCount > 0 ? "eye.slash" : "rectangle.dashed") : "rectangle.on.rectangle")
                            if windows.isEmpty && minimizedCount > 0 {
                                Text("\(minimizedCount) minimized")
                                    .font(.caption2)
                            } else if !floatingWindows.isEmpty {
                                Text("Floating windows shown above")
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(.secondary.opacity(0.65))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    } else {
                        ForEach(tiledWindows) { window in
                            ZStack {
                                WorkspaceWindowTile(window: window, bounds: bounds, canvasSize: geometry.size)
                                if let localRect = WindowTileLayout.rect(window: window, bounds: bounds, canvasSize: geometry.size) {
                                    WindowFrameReporter(windowID: window.id, rect: CGRect(
                                        x: mapFrame.minX + localRect.minX,
                                        y: mapFrame.minY + localRect.minY,
                                        width: localRect.width,
                                        height: localRect.height
                                    ))
                                }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(height: mapHeight)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isDropTargeted ? Color.blue : Color.white.opacity(0.10), lineWidth: isDropTargeted ? 2 : 1))

            HStack(spacing: 6) {
                Button { model.spaceCommand(space.index, ["--balance"]) } label: { Image(systemName: "circle.lefthalf.filled") }
                    .help("Rebalance space")
                Button { model.spaceCommand(space.index, ["--rotate", "90"]) } label: { Image(systemName: "rotate.right") }
                    .help("Rotate layout")
                Menu {
                    Button("New space on Display \(displayIndex)") {
                        model.createSpace(onDisplay: displayIndex)
                    }
                    Divider()
                    Button("Move focused tile to previous space") {
                        model.moveFocusedWindowToAdjacentSpace(.previous)
                    }
                    .disabled(model.adjacentSpaceIndex(from: space.index, direction: .previous) == nil)
                    Button("Move focused tile to next space") {
                        model.moveFocusedWindowToAdjacentSpace(.next)
                    }
                    .disabled(model.adjacentSpaceIndex(from: space.index, direction: .next) == nil)
                    Divider()
                    Button("Minimize all windows") {
                        model.minimizeAllWindows(in: space.index)
                    }
                    Button("Maximize all windows") {
                        model.maximizeAllWindows(in: space.index)
                    }
                    Divider()
                    Button("Close Space \(space.index)", role: .destructive) {
                        model.closeSpace(space.index)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("Space actions")
                Spacer()
                Button("Focus") { model.focusSpace(space.index) }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .frame(width: 220, height: tileHeight)
        .background(space.isFocused ? Color.blue.opacity(0.13) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(space.isFocused ? Color.blue.opacity(0.55) : Color.white.opacity(0.10), lineWidth: space.isFocused ? 1.5 : 1))
        .overlay {
            if case .space(let targetID, let after) = dropCoordinator.activePreview, targetID == space.index {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(Color.orange, lineWidth: 2)
                    .overlay(alignment: after ? .trailing : .leading) {
                        Capsule()
                            .fill(Color.orange)
                            .frame(width: 3)
                            .padding(.vertical, 8)
                    }
            }
        }
        .background(GeometryReader { proxy in
            Color.clear.preference(key: WorkspaceSpaceFrameKey.self, value: [space.index: proxy.frame(in: .global)])
        })
        .onDrop(of: WorkspaceDragItem.acceptedTypes, isTargeted: $isDropTargeted) { providers, _ in
            guard let provider = providers.first else { return false }
            WorkspaceDragItem.decode(provider) { item in
                guard let item else { return }
                Task { @MainActor in
                    model.handleWorkspaceDrop(item, targetSpace: space.index, targetDisplay: displayIndex)
                }
            }
            return true
        }
    }
}

struct WorkspaceWindowTile: View {
    @EnvironmentObject private var model: YabaiModel
    @EnvironmentObject private var dropCoordinator: WorkspaceDropCoordinator
    let window: YabaiWindow
    let bounds: WindowMapBounds
    let canvasSize: CGSize
    @State private var dragOffset = CGSize.zero
    @State private var didDrag = false

    var body: some View {
        WindowTile(window: window, bounds: bounds, canvasSize: canvasSize)
            .offset(dragOffset)
            .zIndex(dragOffset == .zero ? 0 : 20)
            .overlay {
                if case .window(let targetID, let intent) = dropCoordinator.activePreview, targetID == window.id {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(intent == .center ? 0.22 : 0.12))
                        .overlay {
                            Text(intent.label)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .allowsHitTesting(false)
                }
            }
            .onTapGesture {
                guard !didDrag else { return }
                model.focusWindow(window.id)
            }
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { value in
                        didDrag = true
                        dragOffset = value.translation
                        dropCoordinator.updatePreview(for: WorkspaceDragItem(kind: "window", id: window.id), at: value.location, model: model)
                    }
                    .onEnded { value in
                        dropCoordinator.handleDrop(WorkspaceDragItem(kind: "window", id: window.id), at: value.location, model: model)
                        dragOffset = .zero
                        resetDragGuard()
                    }
            )
            .contextMenu {
                Text(window.app.isEmpty ? "Window" : window.app)
                Divider()
                Button("Move to previous space") {
                    model.moveWindowToAdjacentSpace(window.id, direction: .previous)
                }
                .disabled(model.adjacentSpaceIndex(from: window.space, direction: .previous) == nil)
                Button("Move to next space") {
                    model.moveWindowToAdjacentSpace(window.id, direction: .next)
                }
                .disabled(model.adjacentSpaceIndex(from: window.space, direction: .next) == nil)
            }
    }

    private func resetDragGuard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            didDrag = false
        }
    }
}

struct WorkspaceDisplaySection: View {
    @EnvironmentObject private var model: YabaiModel
    let displayIndex: Int
    @State private var isExpanded = true

    private var spaces: [YabaiSpace] {
        model.spaces.filter { $0.display == displayIndex }.sorted { $0.index < $1.index }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                ForEach(spaces) { space in
                    WorkspaceSpaceSection(space: space)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "display.2")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Display \(displayIndex)").font(.headline)
                    Text("\(spaces.count) \(spaces.count == 1 ? "space" : "spaces")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Focus") { model.focusDisplay(displayIndex) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08)))
    }
}

struct WorkspaceSpaceSection: View {
    @EnvironmentObject private var model: YabaiModel
    let space: YabaiSpace
    @State private var isExpanded = true

    private var windows: [YabaiWindow] {
        model.windows.filter { $0.space == space.index && $0.isRenderable }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 5) {
                if windows.isEmpty {
                    Text("No managed windows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(windows) { window in
                        WorkspaceWindowRow(window: window)
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: space.isFocused ? "circle.inset.filled" : "circle")
                    .foregroundStyle(space.isFocused ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(space.label.isEmpty ? "Space \(space.index)" : space.label)
                        .font(.subheadline.weight(.semibold))
                    Text("\(windows.count) \(windows.count == 1 ? "window" : "windows") · \(space.layout)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if space.isFocused {
                    Text("Focused").font(.caption2.weight(.semibold)).foregroundStyle(.blue)
                }
                Button("Focus") { model.focusSpace(space.index) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Menu {
                    Button("Rebalance") { model.spaceCommand(space.index, ["--balance"]) }
                    Button("Rotate 90°") { model.spaceCommand(space.index, ["--rotate", "90"]) }
                    Button("Mirror horizontally") { model.spaceCommand(space.index, ["--mirror", "x-axis"]) }
                    Button("Mirror vertically") { model.spaceCommand(space.index, ["--mirror", "y-axis"]) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(11)
        .background(space.isFocused ? Color.blue.opacity(0.10) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
    }
}

struct WorkspaceWindowRow: View {
    @EnvironmentObject private var model: YabaiModel
    let window: YabaiWindow

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: window.isFocused ? "macwindow.on.rectangle.fill" : "macwindow.on.rectangle")
                .foregroundStyle(window.isFocused ? .blue : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(window.app.isEmpty ? "Unknown application" : window.app)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(window.title.isEmpty ? "Untitled window" : window.title)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if window.isFloating {
                Image(systemName: "rectangle.dashed").foregroundStyle(.orange).help("Floating")
            }
            Button("Focus") { model.focusWindow(window.id) }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            Menu {
                Section("Move") {
                    ForEach(model.spaces.filter { $0.index != window.space }.sorted { $0.index < $1.index }) { target in
                        Button("Move to Space \(target.index)") { model.moveWindow(window.id, toSpace: target.index) }
                    }
                    Button("Move to previous space") {
                        model.moveWindowToAdjacentSpace(window.id, direction: .previous)
                    }
                    .disabled(model.adjacentSpaceIndex(from: window.space, direction: .previous) == nil)
                    Button("Move to next space") {
                        model.moveWindowToAdjacentSpace(window.id, direction: .next)
                    }
                    .disabled(model.adjacentSpaceIndex(from: window.space, direction: .next) == nil)
                    ForEach(model.displays.filter { $0.index != (model.spaces.first(where: { $0.index == window.space })?.display ?? 0) }.sorted { $0.index < $1.index }) { target in
                        Button("Move to Display \(target.index)") { model.moveWindow(window.id, toDisplay: target.index) }
                    }
                }
                Section("Reorder") {
                    Button("Swap with previous") { model.reorderWindow(window.id, command: ["--swap", "prev"]) }
                    Button("Swap with next") { model.reorderWindow(window.id, command: ["--swap", "next"]) }
                    Button("Warp into previous") { model.reorderWindow(window.id, command: ["--warp", "prev"]) }
                    Button("Warp into next") { model.reorderWindow(window.id, command: ["--warp", "next"]) }
                    Button("Stack on previous") { model.reorderWindow(window.id, command: ["--stack", "prev"]) }
                }
                Section("Window") {
                    Button("Toggle float / tile") { model.reorderWindow(window.id, command: ["--toggle", "float"]) }
                    Button("Toggle zoom") { model.reorderWindow(window.id, command: ["--toggle", "zoom-fullscreen"]) }
                    Button("Minimize") { model.reorderWindow(window.id, command: ["--minimize"]) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct WindowsView: View {
    @EnvironmentObject private var model: YabaiModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Windows", subtitle: "Inspect and focus every managed window.")
            if model.shouldShowWarning, let dataError = model.dataError {
                DataStatusBanner(message: dataError)
            }
            if model.windows.isEmpty {
                ContentUnavailableView("No windows found", systemImage: "macwindow.on.rectangle", description: Text(model.isRunning ? "Yabai has not reported any managed windows." : "Start Yabai to query managed windows."))
                Spacer()
            } else {
                List(model.windows) { window in
                    HStack(spacing: 13) {
                        Image(systemName: window.isFocused ? "macwindow.on.rectangle.fill" : "macwindow.on.rectangle")
                            .foregroundStyle(window.isFocused ? .blue : .secondary)
                            .frame(width: 25)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(window.app.isEmpty ? "Unknown application" : window.app).font(.headline)
                            Text(window.title.isEmpty ? "Untitled window" : window.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text("Space \(window.space)").font(.caption).foregroundStyle(.secondary)
                        if window.isFloating { Label("Floating", systemImage: "rectangle.dashed").font(.caption2).foregroundStyle(.orange) }
                        Button("Focus") { model.focusWindow(window.id) }.buttonStyle(.bordered).controlSize(.small)
                    }
                    .padding(.vertical, 5)
                }
                .listStyle(.inset)
            }
        }
        .padding(30)
    }
}

struct SpacesView: View {
    @EnvironmentObject private var model: YabaiModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Spaces & displays", subtitle: "See your desktops and jump between them.")
            if model.shouldShowWarning, let dataError = model.dataError {
                DataStatusBanner(message: dataError)
            }
            if model.spaces.isEmpty {
                ContentUnavailableView("No spaces found", systemImage: "rectangle.3.group", description: Text(model.isRunning ? "Yabai has not reported any spaces." : "Start Yabai to query spaces."))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.spaces) { space in
                            HStack(spacing: 16) {
                                Text("\(space.index)").font(.title2.weight(.bold)).foregroundStyle(space.isFocused ? .blue : .secondary).frame(width: 36)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(space.label.isEmpty ? "Space \(space.index)" : space.label).font(.headline)
                                    Text("Display \(space.display)  ·  \(space.windowCount) windows  ·  \(space.layout)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if space.isFocused { Text("Focused").font(.caption.weight(.semibold)).foregroundStyle(.blue) }
                                if space.isFocused {
                                    Button("Focused") { }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(true)
                                } else {
                                    Button("Focus") { model.focusSpace(space.index) }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                }
                            }
                            .padding(16)
                            .background(space.isFocused ? Color.blue.opacity(0.10) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .padding(30)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: YabaiModel
    var body: some View {
        Form {
            PageHeader(title: "Settings", subtitle: "Tune the Yabai behavior you use most.")
            Section("Global behavior") {
                Toggle("Mouse follows focus", isOn: boolBinding("mouse_follows_focus", get: { model.settings.mouseFollowsFocus }))
                Picker("Focus follows mouse", selection: stringBinding("focus_follows_mouse", get: { model.settings.focusFollowsMouse })) {
                    Text("Off").tag("off")
                    Text("Autofocus").tag("autofocus")
                    Text("Autorise").tag("autoraise")
                }
                Toggle("Window opacity", isOn: boolBinding("window_opacity", get: { model.settings.windowOpacity }))
                Toggle("Keep zoom state", isOn: boolBinding("window_zoom_persist", get: { model.settings.zoomPersist }))
                Toggle("Window shadow", isOn: boolBinding("window_shadow", get: { model.settings.windowShadow }))
                Toggle("Auto-balance spaces", isOn: boolBinding("auto_balance", get: { model.settings.autoBalance }))
                TextField("External bar", text: stringBinding("external_bar", get: { model.settings.externalBar }))
                TextField("Menu bar opacity", text: stringBinding("menubar_opacity", get: { model.settings.menubarOpacity }))
            }
            Section("Layout and geometry") {
                Picker("Layout", selection: spaceStringBinding("layout", get: { model.settings.layout })) {
                    Text("BSP").tag("bsp")
                    Text("Stack").tag("stack")
                    Text("Float").tag("float")
                }
                Picker("Split type", selection: spaceStringBinding("split_type", get: { model.settings.splitType })) {
                    Text("Auto").tag("auto")
                    Text("Vertical").tag("vertical")
                    Text("Horizontal").tag("horizontal")
                }
                TextField("Split ratio", text: stringBinding("split_ratio", get: { model.settings.splitRatio }))
                Stepper("Window gap: \(model.settings.windowGap)", value: intBinding("window_gap", get: { model.settings.windowGap }), in: 0...100)
                Stepper("Top padding: \(model.settings.topPadding)", value: intBinding("top_padding", get: { model.settings.topPadding }), in: 0...200)
                Stepper("Bottom padding: \(model.settings.bottomPadding)", value: intBinding("bottom_padding", get: { model.settings.bottomPadding }), in: 0...200)
                Stepper("Left padding: \(model.settings.leftPadding)", value: intBinding("left_padding", get: { model.settings.leftPadding }), in: 0...200)
                Stepper("Right padding: \(model.settings.rightPadding)", value: intBinding("right_padding", get: { model.settings.rightPadding }), in: 0...200)
                TextField("Insert feedback color", text: stringBinding("insert_feedback_color", get: { model.settings.insertFeedbackColor }))
            }
            Section("Placement and interaction") {
                TextField("Display arrangement", text: stringBinding("display_arrangement_order", get: { model.settings.displayArrangementOrder }))
                TextField("Window origin display", text: stringBinding("window_origin_display", get: { model.settings.windowOriginDisplay }))
                Picker("Window placement", selection: stringBinding("window_placement", get: { model.settings.windowPlacement })) {
                    Text("First child").tag("first_child")
                    Text("Second child").tag("second_child")
                }
                Picker("Insertion point", selection: stringBinding("window_insertion_point", get: { model.settings.windowInsertionPoint })) {
                    Text("Focused").tag("focused")
                    Text("First child").tag("first_child")
                    Text("Last child").tag("last_child")
                }
                Picker("Mouse modifier", selection: stringBinding("mouse_modifier", get: { model.settings.mouseModifier })) {
                    Text("Fn").tag("fn")
                    Text("Option").tag("alt")
                    Text("Shift").tag("shift")
                    Text("Command").tag("cmd")
                    Text("Control").tag("ctrl")
                }
                Picker("Mouse action 1", selection: stringBinding("mouse_action1", get: { model.settings.mouseAction1 })) {
                    Text("Move").tag("move")
                    Text("Resize").tag("resize")
                }
                Picker("Mouse action 2", selection: stringBinding("mouse_action2", get: { model.settings.mouseAction2 })) {
                    Text("Resize").tag("resize")
                    Text("Move").tag("move")
                }
                Picker("Drop action", selection: stringBinding("mouse_drop_action", get: { model.settings.mouseDropAction })) {
                    Text("Swap").tag("swap")
                    Text("Stack").tag("stack")
                    Text("Float").tag("float")
                }
            }
            Section("Animation and appearance") {
                Toggle("Skip focus animation", isOn: boolBinding("skip_window_focus_animation", get: { model.settings.skipWindowFocusAnimation }))
                TextField("Window animation duration", text: stringBinding("window_animation_duration", get: { model.settings.windowAnimationDuration }))
                TextField("Window animation easing", text: stringBinding("window_animation_easing", get: { model.settings.windowAnimationEasing }))
                TextField("Opacity transition duration", text: stringBinding("window_opacity_duration", get: { model.settings.windowOpacityDuration }))
                TextField("Active window opacity", text: stringBinding("active_window_opacity", get: { model.settings.activeWindowOpacity }))
                TextField("Normal window opacity", text: stringBinding("normal_window_opacity", get: { model.settings.normalWindowOpacity }))
            }
            Section("Keyboard shortcuts") {
                Text("yabUI can install a managed shortcut block in ~/.config/skhd/skhdrc. Existing user bindings are preserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    model.installKeyboardShortcuts()
                } label: {
                    Label("Install / update keyboard shortcuts", systemImage: "keyboard")
                }
                if let shortcutStatus = model.shortcutStatus {
                    Text(shortcutStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Focus: ⌥H/J/K/L · Move: ⇧⌥H/J/K/L · Warp: ⇧⌘H/J/K/L · Spaces: ⌘⌥1–9")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Section("Space reordering") {
                Label("Dragging spaces uses Yabai's scripting addition. It must be loaded for macOS Mission Control spaces to move or swap.", systemImage: "rectangle.3.group")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open setup documentation") {
                    if let url = URL(string: "https://github.com/asmvik/yabai/blob/master/doc/yabai.asciidoc") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Section("Updates") {
                HStack {
                    Text("Installed version")
                    Spacer()
                    Text(model.currentVersion)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Button {
                    model.checkForUpdates()
                } label: {
                    Label(model.updateStatus == .checking ? "Checking…" : "Check for updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(model.updateStatus == .checking)
                switch model.updateStatus {
                case .available(let update):
                    VStack(alignment: .leading, spacing: 8) {
                        Text("yabUI \(update.version) is available")
                            .font(.subheadline.weight(.semibold))
                        Button("Download update") { model.downloadUpdate(update) }
                            .buttonStyle(.borderedProminent)
                    }
                case .downloading:
                    Label("Downloading installer…", systemImage: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                case .downloaded(let url):
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Installer downloaded")
                            .font(.subheadline.weight(.semibold))
                        Button("Open installer") { NSWorkspace.shared.open(url) }
                            .buttonStyle(.borderedProminent)
                    }
                case .upToDate:
                    Label("You’re running the latest release.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failed(let message):
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                default:
                    EmptyView()
                }
            }
            Section("Setup") {
                Button("Show onboarding guide") { model.showOnboarding = true }
                Text("The guide explains Accessibility permission and the bundled service setup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Save Yabai configuration") { model.persistYabaiConfiguration() }
                Button("Refresh settings") { model.refreshSettings() }
                Text("Changes are applied live and saved to ~/.config/yabai/yabairc. The bundled service launches with this configuration on the next start or restart.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private func stringBinding(_ key: String, get: @escaping () -> String) -> Binding<String> {
        Binding(get: get, set: { model.setConfig(key, $0) })
    }

    private func spaceStringBinding(_ key: String, get: @escaping () -> String) -> Binding<String> {
        Binding(get: get, set: { model.setSpaceConfig(key, $0) })
    }

    private func boolBinding(_ key: String, get: @escaping () -> Bool) -> Binding<Bool> {
        Binding(get: get, set: { model.setConfig(key, $0 ? "on" : "off") })
    }

    private func intBinding(_ key: String, get: @escaping () -> Int) -> Binding<Int> {
        Binding(get: get, set: { model.setConfig(key, "\($0)") })
    }
}

struct ActivityView: View {
    @EnvironmentObject private var model: YabaiModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                PageHeader(title: "Activity", subtitle: "A transparent record of actions from this app.")
                Spacer()
                Button("Clear") { model.logs.removeAll() }.buttonStyle(.bordered)
            }
            if model.logs.isEmpty {
                ContentUnavailableView("No commands yet", systemImage: "terminal", description: Text("Use a control in the app to see its command and result here."))
                Spacer()
            } else {
                List(model.logs) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(log.success ? .green : .red)
                            Text(log.command).font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(log.date, style: .time).font(.caption).foregroundStyle(.secondary)
                        }
                        if !log.output.isEmpty { Text(log.output).font(.caption).foregroundStyle(.secondary).lineLimit(3).textSelection(.enabled) }
                    }
                    .padding(.vertical, 5)
                }
                .listStyle(.inset)
            }
        }
        .padding(30)
    }
}

struct WorkspaceDragItem: Codable, Hashable {
    let kind: String
    let id: Int

    static let type = UTType(exportedAs: "com.yabui.app.workspace-item")
    static let acceptedTypes = [type.identifier, UTType.json.identifier, UTType.text.identifier]

    var provider: NSItemProvider {
        let provider = NSItemProvider(object: NSString(string: "\(kind):\(id)"))
        let data = (try? JSONEncoder().encode(self)) ?? Data()
        provider.registerDataRepresentation(forTypeIdentifier: Self.type.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        provider.registerDataRepresentation(forTypeIdentifier: UTType.json.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func decode(_ provider: NSItemProvider, completion: @escaping (WorkspaceDragItem?) -> Void) {
        if provider.registeredTypeIdentifiers.contains(type.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                completion(data.flatMap { try? JSONDecoder().decode(WorkspaceDragItem.self, from: $0) })
            }
        } else if provider.registeredTypeIdentifiers.contains(UTType.json.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.json.identifier) { data, _ in
                completion(data.flatMap { try? JSONDecoder().decode(WorkspaceDragItem.self, from: $0) })
            }
        } else {
            provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let payload = object?.description else {
                    completion(nil)
                    return
                }
                let parts = payload.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2, let id = Int(parts[1]) else {
                    completion(nil)
                    return
                }
                completion(WorkspaceDragItem(kind: parts[0], id: id))
            }
        }
    }
}

struct WorkspaceSpaceFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

struct WorkspaceWindowFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

struct WindowFrameReporter: View {
    let windowID: Int
    let rect: CGRect

    var body: some View {
        Color.clear
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
            .preference(key: WorkspaceWindowFrameKey.self, value: [windowID: rect])
    }
}

@MainActor
final class WorkspaceDropCoordinator: ObservableObject {
    @Published var spaceFrames: [Int: CGRect] = [:]
    @Published var windowFrames: [Int: CGRect] = [:]
    @Published var activePreview: WorkspaceDropPreview?

    func updatePreview(for item: WorkspaceDragItem, at location: CGPoint, model: YabaiModel) {
        if item.kind == "window" {
            if let target = windowFrames.first(where: { $0.key != item.id && $0.value.contains(location) }) {
                activePreview = .window(targetID: target.key, intent: WindowDropIntent(location: location, in: target.value))
                return
            }
            if let targetSpace = spaceFrames.first(where: { $0.value.contains(location) })?.key {
                activePreview = .space(targetID: targetSpace, after: location.x > spaceFrames[targetSpace, default: .zero].midX)
                return
            }
        } else if item.kind == "space",
                  let targetSpace = spaceFrames.first(where: { $0.key != item.id && $0.value.contains(location) })?.key {
            activePreview = .space(targetID: targetSpace, after: location.x > spaceFrames[targetSpace, default: .zero].midX)
            return
        }
        activePreview = nil
    }

    func handleDrop(_ item: WorkspaceDragItem, at location: CGPoint, model: YabaiModel) {
        defer { activePreview = nil }
        if item.kind == "window" {
            if let target = windowFrames.first(where: { $0.key != item.id && $0.value.contains(location) }) {
                model.dropWindow(item.id, onto: target.key, intent: WindowDropIntent(location: location, in: target.value))
                return
            }
            if let targetSpace = spaceFrames.first(where: { $0.value.contains(location) })?.key {
                model.moveWindow(item.id, toSpace: targetSpace)
            }
        } else if item.kind == "space",
                  let targetSpace = spaceFrames.first(where: { $0.key != item.id && $0.value.contains(location) })?.key,
                  let targetDisplay = model.spaces.first(where: { $0.index == targetSpace })?.display {
            let after = location.x > spaceFrames[targetSpace, default: .zero].midX
            model.dropSpace(item.id, on: targetSpace, display: targetDisplay, after: after)
        }
    }
}

enum WindowDropIntent: String, Equatable {
    case center, west, east, north, south

    init(location: CGPoint, in rect: CGRect) {
        let x = rect.width > 0 ? (location.x - rect.minX) / rect.width : 0.5
        let y = rect.height > 0 ? (location.y - rect.minY) / rect.height : 0.5
        if x < 0.25 { self = .west }
        else if x > 0.75 { self = .east }
        else if y < 0.25 { self = .north }
        else if y > 0.75 { self = .south }
        else { self = .center }
    }

    var label: String {
        switch self {
        case .center: return "Swap"
        case .west: return "Split left"
        case .east: return "Split right"
        case .north: return "Split top"
        case .south: return "Split bottom"
        }
    }
}

enum WorkspaceDropPreview: Equatable {
    case window(targetID: Int, intent: WindowDropIntent)
    case space(targetID: Int, after: Bool)
}

enum AdjacentSpaceDirection {
    case previous
    case next

    var title: String {
        switch self {
        case .previous: return "previous"
        case .next: return "next"
        }
    }
}

struct YabaiSettings {
    var externalBar = "off:40:0"
    var menubarOpacity = "1.0"
    var mouseFollowsFocus = false
    var focusFollowsMouse = "off"
    var displayArrangementOrder = "default"
    var windowOriginDisplay = "default"
    var windowPlacement = "second_child"
    var windowInsertionPoint = "focused"
    var zoomPersist = true
    var windowShadow = true
    var skipWindowFocusAnimation = false
    var windowAnimationDuration = "0.0"
    var windowAnimationEasing = "ease_out_circ"
    var windowOpacityDuration = "0.0"
    var activeWindowOpacity = "1.0"
    var normalWindowOpacity = "0.90"
    var windowOpacity = false
    var insertFeedbackColor = "0xffd75f5f"
    var splitRatio = "0.50"
    var autoBalance = false
    var topPadding = 12
    var bottomPadding = 12
    var leftPadding = 12
    var rightPadding = 12
    var windowGap = 6
    var layout = "bsp"
    var splitType = "auto"
    var mouseModifier = "fn"
    var mouseAction1 = "move"
    var mouseAction2 = "resize"
    var mouseDropAction = "swap"
}

struct YabaiWindow: Identifiable, Decodable {
    let id: Int
    let app: String
    let title: String
    let space: Int
    let isFocused: Bool
    let isFloating: Bool
    let isMinimized: Bool
    let isHidden: Bool
    let splitType: String
    let layer: String
    let isSticky: Bool
    let isNativeFullscreen: Bool
    let canMove: Bool
    let canResize: Bool
    let frame: YabaiFrame?
    var isRenderable: Bool { !isMinimized && !isHidden && frame != nil }
    var isOverlayWindow: Bool {
        if isNativeFullscreen { return false }
        if isFloating || isSticky || (layer != "" && layer != "normal") { return true }
        return splitType == "none" && (!canMove || !canResize || Self.systemUtilityNames.contains(app))
    }
    enum CodingKeys: String, CodingKey {
        case id, app, title, space, hasFocus = "has-focus", focused
        case isFloating = "is-floating", isMinimized = "is-minimized", isHidden = "is-hidden"
        case splitType = "split-type", layer, isSticky = "is-sticky"
        case isNativeFullscreen = "is-native-fullscreen", canMove = "can-move", canResize = "can-resize", frame
    }

    private static let systemUtilityNames: Set<String> = [
        "Activity Monitor", "Notes", "Preview", "Calculator", "TextEdit", "Console",
        "System Settings", "Disk Utility", "Archive Utility", "Screenshot", "Finder"
    ]

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(Int.self, forKey: .id) ?? 0
        app = try values.decodeIfPresent(String.self, forKey: .app) ?? ""
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
        space = try values.decodeIfPresent(Int.self, forKey: .space) ?? 0
        isFocused = try values.decodeIfPresent(Bool.self, forKey: .hasFocus) ?? values.decodeIfPresent(Bool.self, forKey: .focused) ?? false
        isFloating = try values.decodeIfPresent(Bool.self, forKey: .isFloating) ?? false
        isMinimized = try values.decodeIfPresent(Bool.self, forKey: .isMinimized) ?? false
        isHidden = try values.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        splitType = try values.decodeIfPresent(String.self, forKey: .splitType) ?? ""
        layer = try values.decodeIfPresent(String.self, forKey: .layer) ?? "normal"
        isSticky = try values.decodeIfPresent(Bool.self, forKey: .isSticky) ?? false
        isNativeFullscreen = try values.decodeIfPresent(Bool.self, forKey: .isNativeFullscreen) ?? false
        canMove = try values.decodeIfPresent(Bool.self, forKey: .canMove) ?? true
        canResize = try values.decodeIfPresent(Bool.self, forKey: .canResize) ?? true
        frame = try values.decodeIfPresent(YabaiFrame.self, forKey: .frame)
    }
}

struct YabaiFrame: Decodable {
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
}

struct YabaiSpace: Identifiable, Decodable {
    let index: Int
    let label: String
    let display: Int
    let windows: [Int]
    let layout: String
    let isFocused: Bool
    var id: Int { index }
    var windowCount: Int { windows.count }
    enum CodingKeys: String, CodingKey { case index, label, display, windows, layout, type, hasFocus = "has-focus", focused }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        index = try values.decodeIfPresent(Int.self, forKey: .index) ?? 0
        label = try values.decodeIfPresent(String.self, forKey: .label) ?? ""
        display = try values.decodeIfPresent(Int.self, forKey: .display) ?? 0
        windows = try values.decodeIfPresent([Int].self, forKey: .windows) ?? []
        // `query --spaces` calls this field `type` (bsp/stack/float). Keep
        // accepting `layout` for compatibility with older snapshots.
        layout = try values.decodeIfPresent(String.self, forKey: .layout)
            ?? values.decodeIfPresent(String.self, forKey: .type)
            ?? "bsp"
        isFocused = try values.decodeIfPresent(Bool.self, forKey: .hasFocus) ?? values.decodeIfPresent(Bool.self, forKey: .focused) ?? false
    }
}

struct YabaiDisplay: Identifiable, Decodable {
    let id: Int
    let index: Int
    let spaces: [Int]
    let frame: YabaiFrame?

    enum CodingKeys: String, CodingKey { case id, index, spaces, frame }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        index = try values.decodeIfPresent(Int.self, forKey: .index) ?? 0
        id = try values.decodeIfPresent(Int.self, forKey: .id) ?? index
        spaces = try values.decodeIfPresent([Int].self, forKey: .spaces) ?? []
        frame = try values.decodeIfPresent(YabaiFrame.self, forKey: .frame)
    }
}

struct ActivityLog: Identifiable {
    let id = UUID(); let date = Date(); let command: String; let output: String; let success: Bool
}

struct CommandResult {
    let success: Bool
    let output: String
}

struct RuntimeSnapshot {
    let runtimeAvailable: Bool
    let version: String
    let isRunning: Bool
    let windows: [YabaiWindow]
    let spaces: [YabaiSpace]
    let displays: [YabaiDisplay]
    let error: String?
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let htmlURL: URL
    let publishedAt: Date?
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

private enum ServiceOperation {
    case start, stop, restart
}

@MainActor
final class YabaiModel: ObservableObject {
    @Published var isRunning = false
    @Published var servicePhase: ServicePhase = .unknown
    @Published var serviceError: String?
    @Published var isRefreshing = false
    @Published var version = ""
    @Published var windows: [YabaiWindow] = []
    @Published var spaces: [YabaiSpace] = []
    @Published var displays: [YabaiDisplay] = []
    @Published var logs: [ActivityLog] = []
    @Published var settings = YabaiSettings()
    @Published var dataError: String?
    @Published var spaceReorderUnavailable = false
    @Published var showOnboarding: Bool
    @Published var updateStatus: UpdateStatus = .idle
    @Published var shortcutStatus: String?

    private let decoder = JSONDecoder()
    private let systemYabaiCandidates = ["/opt/homebrew/bin/yabai", "/usr/local/bin/yabai", "/usr/bin/yabai"]
    private let serviceLabel = "com.yabui.runtime"
    let currentVersion: String
    private var refreshTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var serviceTask: Task<Void, Never>?
    private let preferredLayoutKey = "yabUI.preferredLayout"
    private let preferredSplitTypeKey = "yabUI.preferredSplitType"
    private let managedConfigStart = "# BEGIN yabUI managed settings"
    private let managedConfigEnd = "# END yabUI managed settings"
    private let managedShortcutStart = "# BEGIN yabUI managed shortcuts"
    private let managedShortcutEnd = "# END yabUI managed shortcuts"

    init() {
        currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        settings = Self.readSettings(from: Self.yabaiConfigFileURL)
        showOnboarding = !UserDefaults.standard.bool(forKey: "yabUI.onboarding.complete")
    }

    private var yabaiCandidates: [String] {
        ([bundledYabaiPath].compactMap { $0 } + systemYabaiCandidates)
    }
    private var bundledRuntimeAppPath: String? {
        Bundle.main.path(forResource: "yabUI Runtime", ofType: "app")
    }
    private var bundledYabaiPath: String? {
        if let appPath = bundledRuntimeAppPath {
            return URL(fileURLWithPath: appPath).appendingPathComponent("Contents/MacOS/yabai").path
        }
        return Bundle.main.path(forResource: "yabai", ofType: nil)
    }
    private var yabaiPath: String { yabaiCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) ?? "" }
    private var servicePlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(serviceLabel).plist")
    }
    private static var yabaiConfigFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/yabai/yabairc")
    }
    private var yabaiConfigFileURL: URL { Self.yabaiConfigFileURL }
    private var skhdConfigFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/skhd/skhdrc")
    }
    private var skhdPath: String? {
        ["/opt/homebrew/bin/skhd", "/usr/local/bin/skhd", "/usr/bin/skhd"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }
    private var userID: String { String(getuid()) }
    var shouldShowWarning: Bool { isRunning && dataError != nil }
    var runtimeIsUsable: Bool {
        !yabaiPath.isEmpty && isRunning && servicePhase == .running && dataError == nil
    }
    var runtimeStatusText: String {
        guard let bundledRuntimeAppPath else { return "This build does not contain its bundled runtime." }
        if servicePhase == .running && dataError == nil {
            return "Bundled runtime is connected and responding."
        }
        return "Bundled runtime is not connected yet: \(bundledRuntimeAppPath)"
    }

    func startPolling() {
        guard pollingTask == nil else { return }
        refresh()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { break }
                self?.refresh()
            }
        }
    }

    func refresh() {
        guard refreshTask == nil else { return }
        let path = yabaiPath
        isRefreshing = true
        refreshTask = Task.detached(priority: .userInitiated) { [weak self] in
            let snapshot = Self.readSnapshot(path: path)
            await self?.apply(snapshot)
        }
    }

    func toggleService() { isRunning ? stopService() : startService() }
    func startService() { runServiceOperation(.start) }
    func stopService() { runServiceOperation(.stop) }
    func restartService() { runServiceOperation(.restart) }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "yabUI.onboarding.complete")
        showOnboarding = false
    }

    func checkForUpdates() {
        updateStatus = .checking
        guard let url = URL(string: "https://api.github.com/repos/4hmedk/yabUI/releases/latest") else { return }
        let installedVersion = currentVersion
        Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: url)
                request.setValue("yabUI/\(installedVersion)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let release = try decoder.decode(GitHubRelease.self, from: data)
                let version = Self.normalizedVersion(release.tagName)
                let asset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
                let info = UpdateInfo(version: version, releaseURL: release.htmlURL, downloadURL: asset?.browserDownloadURL, publishedAt: release.publishedAt)
                self.updateStatus = Self.isNewer(version, than: installedVersion) ? .available(info) : .upToDate
            } catch {
                self.updateStatus = .failed("Could not check for updates right now. You can open the release page to try manually.")
            }
        }
    }

    func downloadUpdate(_ update: UpdateInfo) {
        guard let url = update.downloadURL else {
            NSWorkspace.shared.open(update.releaseURL)
            return
        }
        updateStatus = .downloading
        Task { [weak self] in
            do {
                let (temporaryURL, response) = try await URLSession.shared.download(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
                let destination = downloads.appendingPathComponent("yabUI-\(update.version).dmg")
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                self?.updateStatus = .downloaded(destination)
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            } catch {
                self?.updateStatus = .failed("The update download could not be completed.")
            }
        }
    }

    func openReleasePage() {
        if case .available(let update) = updateStatus {
            NSWorkspace.shared.open(update.releaseURL)
        } else if let url = URL(string: "https://github.com/4hmedk/yabUI/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func normalizedVersion(_ value: String) -> String {
        value.replacingOccurrences(of: "yabUI-v", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "v", with: "", options: [.caseInsensitive])
    }

    private static func isNewer(_ candidate: String, than installed: String) -> Bool {
        let lhs = normalizedVersion(candidate).split(separator: ".").compactMap { Int($0) }
        let rhs = normalizedVersion(installed).split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func revealBundledRuntime() {
        guard let bundledRuntimeAppPath else { return }
        NSWorkspace.shared.selectFile(bundledRuntimeAppPath, inFileViewerRootedAtPath: "/")
    }

    func persistYabaiConfiguration() {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: yabaiConfigFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let existing = (try? String(contentsOf: yabaiConfigFileURL, encoding: .utf8)) ?? "# yabUI-managed Yabai configuration\n"
            let base = Self.removeManagedSection(from: existing, start: managedConfigStart, end: managedConfigEnd)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let content = [base, yabaiConfigurationBlock].filter { !$0.isEmpty }.joined(separator: "\n\n") + "\n"
            try content.write(to: yabaiConfigFileURL, atomically: true, encoding: .utf8)
        } catch {
            serviceError = "Could not save Yabai configuration: \(error.localizedDescription)"
        }
    }

    func installKeyboardShortcuts() {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: skhdConfigFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let existing = (try? String(contentsOf: skhdConfigFileURL, encoding: .utf8)) ?? "# skhd configuration\n"
            let base = Self.removeManagedSection(from: existing, start: managedShortcutStart, end: managedShortcutEnd)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let content = [base, keyboardShortcutBlock].filter { !$0.isEmpty }.joined(separator: "\n\n") + "\n"
            try content.write(to: skhdConfigFileURL, atomically: true, encoding: .utf8)

            if let skhdPath {
                let result = Self.executeSystem(skhdPath, ["--reload"])
                shortcutStatus = result.success
                    ? "Shortcuts installed and skhd reloaded."
                    : "Shortcuts saved, but skhd could not reload: \(result.output)"
            } else {
                shortcutStatus = "Shortcuts saved to \(skhdConfigFileURL.path). Install skhd to activate them."
            }
        } catch {
            shortcutStatus = "Could not save keyboard shortcuts: \(error.localizedDescription)"
        }
    }

    private var yabaiConfigurationBlock: String {
        let yabai = Self.shellQuote(bundledYabaiPath ?? "yabai")
        let values: [(String, String)] = [
            ("external_bar", settings.externalBar),
            ("menubar_opacity", settings.menubarOpacity),
            ("mouse_follows_focus", settings.mouseFollowsFocus ? "on" : "off"),
            ("focus_follows_mouse", settings.focusFollowsMouse),
            ("display_arrangement_order", settings.displayArrangementOrder),
            ("window_origin_display", settings.windowOriginDisplay),
            ("window_placement", settings.windowPlacement),
            ("window_insertion_point", settings.windowInsertionPoint),
            ("window_zoom_persist", settings.zoomPersist ? "on" : "off"),
            ("window_shadow", settings.windowShadow ? "on" : "off"),
            ("skip_window_focus_animation", settings.skipWindowFocusAnimation ? "on" : "off"),
            ("window_animation_duration", settings.windowAnimationDuration),
            ("window_animation_easing", settings.windowAnimationEasing),
            ("window_opacity_duration", settings.windowOpacityDuration),
            ("active_window_opacity", settings.activeWindowOpacity),
            ("normal_window_opacity", settings.normalWindowOpacity),
            ("window_opacity", settings.windowOpacity ? "on" : "off"),
            ("insert_feedback_color", settings.insertFeedbackColor),
            ("split_ratio", settings.splitRatio),
            ("split_type", settings.splitType),
            ("auto_balance", settings.autoBalance ? "on" : "off"),
            ("top_padding", "\(settings.topPadding)"),
            ("bottom_padding", "\(settings.bottomPadding)"),
            ("left_padding", "\(settings.leftPadding)"),
            ("right_padding", "\(settings.rightPadding)"),
            ("window_gap", "\(settings.windowGap)"),
            ("layout", settings.layout),
            ("mouse_modifier", settings.mouseModifier),
            ("mouse_action1", settings.mouseAction1),
            ("mouse_action2", settings.mouseAction2),
            ("mouse_drop_action", settings.mouseDropAction)
        ]
        let lines = values.map { "\(yabai) -m config \($0.0) \(Self.shellQuote($0.1))" }
        return ([managedConfigStart] + lines + [managedConfigEnd]).joined(separator: "\n")
    }

    private var keyboardShortcutBlock: String {
        let yabai = Self.shellQuote(bundledYabaiPath ?? "yabai")
        let prefix = "USER=\"${USER:-$(id -un)}\"; \(yabai) -m"
        let lines = [
            "# Window focus",
            "alt - h : \(prefix) window --focus west",
            "alt - j : \(prefix) window --focus south",
            "alt - k : \(prefix) window --focus north",
            "alt - l : \(prefix) window --focus east",
            "",
            "# Window movement and layout",
            "shift + alt - h : \(prefix) window --swap west",
            "shift + alt - j : \(prefix) window --swap south",
            "shift + alt - k : \(prefix) window --swap north",
            "shift + alt - l : \(prefix) window --swap east",
            "shift + cmd - h : \(prefix) window --warp west",
            "shift + cmd - j : \(prefix) window --warp south",
            "shift + cmd - k : \(prefix) window --warp north",
            "shift + cmd - l : \(prefix) window --warp east",
            "alt - d : \(prefix) window --toggle zoom-parent",
            "alt - f : \(prefix) window --toggle zoom-fullscreen",
            "alt - e : \(prefix) window --toggle split",
            "alt - t : \(prefix) window --toggle float",
            "",
            "# Spaces",
            "shift + alt - 0 : \(prefix) space --balance",
            "cmd + alt - 1 : \(prefix) space --focus 1",
            "cmd + alt - 2 : \(prefix) space --focus 2",
            "cmd + alt - 3 : \(prefix) space --focus 3",
            "cmd + alt - 4 : \(prefix) space --focus 4",
            "cmd + alt - 5 : \(prefix) space --focus 5",
            "cmd + alt - 6 : \(prefix) space --focus 6",
            "cmd + alt - 7 : \(prefix) space --focus 7",
            "cmd + alt - 8 : \(prefix) space --focus 8",
            "cmd + alt - 9 : \(prefix) space --focus 9"
        ]
        return ([managedShortcutStart] + lines + [managedShortcutEnd]).joined(separator: "\n")
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func removeManagedSection(from content: String, start: String, end: String) -> String {
        guard let startRange = content.range(of: start),
              let endRange = content.range(of: end, range: startRange.upperBound..<content.endIndex) else { return content }
        return content.replacingCharacters(in: startRange.lowerBound..<endRange.upperBound, with: "")
    }

    private static func readSettings(from url: URL) -> YabaiSettings {
        var settings = YabaiSettings()
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return settings }
        let keys: Set<String> = [
            "external_bar", "menubar_opacity", "mouse_follows_focus", "focus_follows_mouse",
            "display_arrangement_order", "window_origin_display", "window_placement", "window_insertion_point",
            "window_zoom_persist", "window_shadow", "skip_window_focus_animation", "window_animation_duration",
            "window_animation_easing", "window_opacity_duration", "active_window_opacity", "normal_window_opacity",
            "window_opacity", "insert_feedback_color", "split_ratio", "split_type", "auto_balance",
            "top_padding", "bottom_padding", "left_padding", "right_padding", "window_gap", "layout",
            "mouse_modifier", "mouse_action1", "mouse_action2", "mouse_drop_action"
        ]
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#") else { continue }
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\\" }).map(String.init)
            guard let keyIndex = parts.firstIndex(where: { keys.contains($0) }), keyIndex + 1 < parts.count else { continue }
            let key = parts[keyIndex]
            let value = parts[keyIndex + 1].trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            switch key {
            case "external_bar": settings.externalBar = value
            case "menubar_opacity": settings.menubarOpacity = value
            case "mouse_follows_focus": settings.mouseFollowsFocus = value == "on"
            case "focus_follows_mouse": settings.focusFollowsMouse = value
            case "display_arrangement_order": settings.displayArrangementOrder = value
            case "window_origin_display": settings.windowOriginDisplay = value
            case "window_placement": settings.windowPlacement = value
            case "window_insertion_point": settings.windowInsertionPoint = value
            case "window_zoom_persist": settings.zoomPersist = value == "on"
            case "window_shadow": settings.windowShadow = value == "on"
            case "skip_window_focus_animation": settings.skipWindowFocusAnimation = value == "on"
            case "window_animation_duration": settings.windowAnimationDuration = value
            case "window_animation_easing": settings.windowAnimationEasing = value
            case "window_opacity_duration": settings.windowOpacityDuration = value
            case "active_window_opacity": settings.activeWindowOpacity = value
            case "normal_window_opacity": settings.normalWindowOpacity = value
            case "window_opacity": settings.windowOpacity = value == "on"
            case "insert_feedback_color": settings.insertFeedbackColor = value
            case "split_ratio": settings.splitRatio = value
            case "split_type": settings.splitType = value
            case "auto_balance": settings.autoBalance = value == "on"
            case "top_padding": settings.topPadding = Int(value) ?? settings.topPadding
            case "bottom_padding": settings.bottomPadding = Int(value) ?? settings.bottomPadding
            case "left_padding": settings.leftPadding = Int(value) ?? settings.leftPadding
            case "right_padding": settings.rightPadding = Int(value) ?? settings.rightPadding
            case "window_gap": settings.windowGap = Int(value) ?? settings.windowGap
            case "layout": settings.layout = value
            case "mouse_modifier": settings.mouseModifier = value
            case "mouse_action1": settings.mouseAction1 = value
            case "mouse_action2": settings.mouseAction2 = value
            case "mouse_drop_action": settings.mouseDropAction = value
            default: break
            }
        }
        return settings
    }

    func applyRecommendedConfiguration() {
        UserDefaults.standard.set("bsp", forKey: preferredLayoutKey)
        UserDefaults.standard.set("auto", forKey: preferredSplitTypeKey)
        if !isRunning {
            startService()
            return
        }
        configureManagedLayout(force: true)
        refresh()
    }

    private func configureManagedLayout(force: Bool) {
        let layout = force ? "bsp" : (UserDefaults.standard.string(forKey: preferredLayoutKey) ?? "bsp")
        let splitType = force ? "auto" : (UserDefaults.standard.string(forKey: preferredSplitTypeKey) ?? "auto")

        setConfig("mouse_follows_focus", "off")
        setConfig("focus_follows_mouse", "off")
        setConfig("layout", layout)
        setConfig("split_type", splitType)

        for index in spaces.map(\.index) {
            _ = command(["-m", "config", "--space", "\(index)", "layout", layout])
            _ = command(["-m", "config", "--space", "\(index)", "split_type", splitType])
        }

        if layout == "bsp" {
            rebalanceSpaces(Set(spaces.map(\.index)))
        }
    }

    private func runServiceOperation(_ operation: ServiceOperation) {
        guard serviceTask == nil, !servicePhase.isTransitioning else { return }
        switch operation {
        case .start: servicePhase = .starting
        case .stop: servicePhase = .stopping
        case .restart: servicePhase = .restarting
        }
        serviceError = nil
        if operation != .stop {
            persistYabaiConfiguration()
        }
        let path = yabaiPath
        let config = yabaiConfigFileURL
        let plist = servicePlistURL
        let label = serviceLabel
        let uid = userID
        serviceTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.performServiceOperation(operation, path: path, config: config, plist: plist, label: label, uid: uid)
            }.value

            guard let self else { return }
            if result.success {
                self.refresh()
                try? await Task.sleep(nanoseconds: 900_000_000)
                self.refresh()
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                if operation == .stop {
                    self.isRunning = false
                    self.servicePhase = .stopped
                    self.windows = []
                    self.spaces = []
                    self.displays = []
                } else if !self.isRunning {
                    self.servicePhase = .unavailable
                    let log = Self.readRuntimeError(uid: uid)
                    self.serviceError = log ?? "The service did not become ready. Add the bundled runtime to Accessibility and try again."
                } else if operation != .stop {
                    self.configureManagedLayout(force: false)
                    self.refresh()
                }
            } else {
                self.servicePhase = .unavailable
                self.serviceError = result.output.isEmpty ? "The service could not be started." : result.output
                self.refresh()
            }
            self.serviceTask = nil
        }
    }

    private nonisolated static func performServiceOperation(_ operation: ServiceOperation, path: String, config: URL, plist: URL, label: String, uid: String) -> CommandResult {
        guard !path.isEmpty else { return CommandResult(success: false, output: "The bundled runtime is missing from this app.") }
        switch operation {
        case .stop:
            let result = executeSystem("/bin/launchctl", ["bootout", "gui/\(uid)/\(label)"])
            try? FileManager.default.removeItem(at: plist)
            if result.success || result.output.localizedCaseInsensitiveContains("could not find service") {
                return CommandResult(success: true, output: result.output)
            }
            return result
        case .start, .restart:
            _ = executeSystem("/bin/launchctl", ["bootout", "gui/\(uid)/\(label)"])
            try? FileManager.default.removeItem(at: plist)
            do {
                try FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
                let logPrefix = "/tmp/yabui_runtime_\(uid)"
                try? FileManager.default.removeItem(atPath: "\(logPrefix).out.log")
                try? FileManager.default.removeItem(atPath: "\(logPrefix).err.log")
                let payload: [String: Any] = [
                    "Label": label,
                    "ProgramArguments": [path, "--config", config.path],
                    "RunAtLoad": true,
                    "KeepAlive": false,
                    "ThrottleInterval": 5,
                    "ProcessType": "Interactive",
                    "EnvironmentVariables": [
                        "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                        "USER": NSUserName(),
                        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
                    ],
                    "StandardOutPath": "\(logPrefix).out.log",
                    "StandardErrorPath": "\(logPrefix).err.log"
                ]
                let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .xml, options: 0)
                try data.write(to: plist, options: .atomic)
            } catch {
                return CommandResult(success: false, output: "Could not prepare the yabUI service: \(error.localizedDescription)")
            }
            let bootstrap = executeSystem("/bin/launchctl", ["bootstrap", "gui/\(uid)", plist.path])
            guard bootstrap.success else { return bootstrap }
            return executeSystem("/bin/launchctl", ["kickstart", "-k", "gui/\(uid)/\(label)"])
        }
    }

    private nonisolated static func executeSystem(_ executable: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return CommandResult(success: process.terminationStatus == 0, output: output.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return CommandResult(success: false, output: error.localizedDescription)
        }
    }

    private nonisolated static func readRuntimeError(uid: String) -> String? {
        let url = URL(fileURLWithPath: "/tmp/yabui_runtime_\(uid).err.log")
        guard let data = try? Data(contentsOf: url),
              let output = String(data: data, encoding: .utf8) else { return nil }
        let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return nil }
        return message
    }

    private nonisolated static func readSnapshot(path: String) -> RuntimeSnapshot {
        guard !path.isEmpty else {
            return RuntimeSnapshot(runtimeAvailable: false, version: "", isRunning: false, windows: [], spaces: [], displays: [], error: "The bundled runtime is missing from this app.")
        }
        let versionResult = execute(path, ["--version"])
        let version = versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard versionResult.success else {
            return RuntimeSnapshot(runtimeAvailable: false, version: version, isRunning: false, windows: [], spaces: [], displays: [], error: cleanServiceMessage(version))
        }
        let windowsResult = execute(path, ["-m", "query", "--windows"])
        guard windowsResult.success else {
            return RuntimeSnapshot(runtimeAvailable: true, version: version, isRunning: false, windows: [], spaces: [], displays: [], error: cleanServiceMessage(windowsResult.output))
        }
        let spacesResult = execute(path, ["-m", "query", "--spaces"])
        let displaysResult = execute(path, ["-m", "query", "--displays"])
        let decoder = JSONDecoder()
        do {
            let windows = try decoder.decode([YabaiWindow].self, from: Data(windowsResult.output.utf8))
            let spaces = try decoder.decode([YabaiSpace].self, from: Data(spacesResult.output.utf8))
            let displays = try decoder.decode([YabaiDisplay].self, from: Data(displaysResult.output.utf8))
            return RuntimeSnapshot(runtimeAvailable: true, version: version, isRunning: true, windows: windows, spaces: spaces, displays: displays, error: nil)
        } catch {
            return RuntimeSnapshot(runtimeAvailable: true, version: version, isRunning: true, windows: [], spaces: [], displays: [], error: "Yabai returned data that yabUI could not read yet.")
        }
    }

    private nonisolated static func execute(_ path: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return CommandResult(success: process.terminationStatus == 0, output: output)
        } catch {
            return CommandResult(success: false, output: error.localizedDescription)
        }
    }

    private nonisolated static func cleanServiceMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "The service is not responding yet." : trimmed
    }

    private func apply(_ snapshot: RuntimeSnapshot) {
        refreshTask = nil
        isRefreshing = false
        version = snapshot.version
        if snapshot.isRunning {
            isRunning = true
            servicePhase = .running
            serviceError = nil
            windows = snapshot.windows
            spaces = snapshot.spaces
            displays = snapshot.displays
            dataError = snapshot.error

            // Yabai keeps layout configuration in the daemon's memory. An
            // external restart can therefore bring it back with its default
            // layout while the app still sees a healthy socket. Reconcile
            // only when the live space type disagrees with the user's saved
            // preference, so ordinary polling stays side-effect free.
            let preferredLayout = UserDefaults.standard.string(forKey: preferredLayoutKey) ?? "bsp"
            if !snapshot.spaces.isEmpty,
               snapshot.spaces.contains(where: { $0.layout != preferredLayout }) {
                configureManagedLayout(force: false)
            }
        } else {
            isRunning = false
            windows = []
            spaces = []
            displays = []
            dataError = nil
            if !snapshot.runtimeAvailable {
                servicePhase = .unavailable
                serviceError = snapshot.error
            } else if !servicePhase.isTransitioning {
                let accessFailure = snapshot.error?.localizedCaseInsensitiveContains("accessibility") == true
                servicePhase = accessFailure ? .unavailable : .stopped
                serviceError = accessFailure ? snapshot.error : nil
            }
        }
    }
    func focusWindow(_ id: Int) { _ = command(["-m", "window", "--focus", "\(id)"]); refresh() }
    func focusSpace(_ index: Int) { _ = command(["-m", "space", "--focus", "\(index)"]); refresh() }
    func focusDisplay(_ index: Int) { _ = command(["-m", "display", "\(index)", "--focus"]); refresh() }

    var currentSpaceIndex: Int? { spaces.first(where: { $0.isFocused })?.index }

    func adjacentSpaceIndex(from spaceIndex: Int, direction: AdjacentSpaceDirection) -> Int? {
        guard let source = spaces.first(where: { $0.index == spaceIndex }) else { return nil }
        let ordered = spaces.filter { $0.display == source.display }.sorted { $0.index < $1.index }
        guard let position = ordered.firstIndex(where: { $0.index == spaceIndex }) else { return nil }
        switch direction {
        case .previous:
            guard position > ordered.startIndex else { return nil }
            return ordered[ordered.index(before: position)].index
        case .next:
            let next = ordered.index(after: position)
            guard next < ordered.endIndex else { return nil }
            return ordered[next].index
        }
    }

    func createSpace(onDisplay display: Int? = nil) {
        var arguments = ["-m", "space", "--create"]
        if let display { arguments.append("\(display)") }
        let result = command(arguments)
        if result.success { refresh() }
    }

    func closeSpace(_ index: Int) {
        let result = command(["-m", "space", "\(index)", "--destroy"])
        if result.success { refresh() }
    }

    func moveWindowToAdjacentSpace(_ id: Int, direction: AdjacentSpaceDirection) {
        guard let source = windows.first(where: { $0.id == id }),
              let destination = adjacentSpaceIndex(from: source.space, direction: direction) else { return }
        moveWindow(id, toSpace: destination)
    }

    func moveFocusedWindowToAdjacentSpace(_ direction: AdjacentSpaceDirection) {
        guard let window = windows.first(where: { $0.isFocused }) else { return }
        moveWindowToAdjacentSpace(window.id, direction: direction)
    }

    func minimizeAllWindows(in spaceIndex: Int?) {
        guard let spaceIndex else { return }
        let candidates = windows.filter {
            $0.space == spaceIndex && !$0.isMinimized && !$0.isHidden && !$0.isNativeFullscreen
        }
        for window in candidates {
            _ = command(["-m", "window", "\(window.id)", "--minimize"])
        }
        refresh()
    }

    // Yabai calls the inverse of minimize "deminimize". Expose it as
    // maximize/restore in the UI so the paired controls are easy to find.
    func maximizeAllWindows(in spaceIndex: Int?) {
        guard let spaceIndex else { return }
        let candidates = windows.filter { $0.space == spaceIndex && $0.isMinimized }
        for window in candidates {
            _ = command(["-m", "window", "\(window.id)", "--deminimize"])
        }
        refresh()
    }

    func moveWindow(_ id: Int, toSpace space: Int) {
        let focusedWindowID = windows.first(where: { $0.isFocused })?.id
        let sourceSpace = windows.first(where: { $0.id == id })?.space
        let result = command(["-m", "window", "\(id)", "--space", "\(space)"])
        if result.success {
            reflowAfterWindowMove(
                windowID: id,
                sourceSpaces: Set([sourceSpace, space].compactMap { $0 }),
                focusedWindowID: focusedWindowID
            )
        }
        refresh()
    }

    func moveWindow(_ id: Int, toDisplay display: Int) {
        let focusedWindowID = windows.first(where: { $0.isFocused })?.id
        let sourceSpace = windows.first(where: { $0.id == id })?.space
        let result = command(["-m", "window", "\(id)", "--display", "\(display)"])
        guard result.success else {
            refresh()
            return
        }

        // A display move can also change the destination space. Refresh once
        // to discover it, then rebalance both sides of the move.
        refresh()
        let destinationSpace = windows.first(where: { $0.id == id })?.space
        reflowAfterWindowMove(
            windowID: id,
            sourceSpaces: Set([sourceSpace, destinationSpace].compactMap { $0 }),
            focusedWindowID: focusedWindowID
        )
        refresh()
    }
    @discardableResult
    func moveSpace(_ index: Int, before target: Int) -> Bool {
        // --move is the most direct operation when the scripting-addition is
        // available. Some installations reject it, though, while still
        // allowing --swap. Keep space dragging useful in both configurations.
        let direct = command(["-m", "space", "\(index)", "--move", "\(target)"])
        if direct.success {
            refresh()
            return true
        }

        let destination = index < target ? target - 1 : target
        guard destination != index else {
            refresh()
            return true
        }

        let step = destination > index ? 1 : -1
        var current = index
        var didSwap = false
        while current != destination {
            let neighbor = current + step
            let swapped = command(["-m", "space", "\(current)", "--swap", "\(neighbor)"])
            guard swapped.success else {
                refresh()
                return didSwap
            }
            didSwap = true
            current = neighbor
        }
        refresh()
        return didSwap
    }

    @discardableResult
    private func moveSpaceToEnd(_ index: Int, display: Int) -> Bool {
        let direct = command(["-m", "space", "\(index)", "--move", "last"])
        if direct.success {
            refresh()
            return true
        }

        let last = spaces.filter { $0.display == display }.map(\.index).max() ?? index
        var current = index
        var didSwap = false
        guard current < last else {
            refresh()
            return true
        }
        while current < last {
            let swapped = command(["-m", "space", "\(current)", "--swap", "\(current + 1)"])
            guard swapped.success else {
                refresh()
                return didSwap
            }
            didSwap = true
            current += 1
        }
        refresh()
        return didSwap
    }
    func moveSpace(_ index: Int, toDisplay display: Int) { spaceCommand(index, ["--display", "\(display)"]) }
    func dropWindow(_ source: Int, onto target: Int, intent: WindowDropIntent) {
        guard source != target,
              let sourceSpace = windows.first(where: { $0.id == source })?.space,
              let targetSpace = windows.first(where: { $0.id == target })?.space else { return }
        let focusedWindowID = windows.first(where: { $0.isFocused })?.id

        var didMove = true
        if sourceSpace != targetSpace {
            didMove = command(["-m", "window", "\(source)", "--space", "\(targetSpace)"]).success
        }

        switch intent {
        case .center:
            _ = command(["-m", "window", "\(source)", "--swap", "\(target)"])
        case .west, .east, .north, .south:
            // Yabai's insert direction determines which side of the target
            // receives the warped window. The explicit target selector keeps
            // this deterministic even when the source is not focused.
            _ = command(["-m", "window", "\(target)", "--insert", intent.rawValue])
            _ = command(["-m", "window", "\(source)", "--warp", "\(target)"])
        }
        if didMove {
            reflowAfterWindowMove(
                windowID: source,
                sourceSpaces: Set([sourceSpace, targetSpace]),
                focusedWindowID: focusedWindowID
            )
        }
        refresh()
    }

    func dropSpace(_ source: Int, on target: Int, display: Int, after: Bool) {
        guard source != target else { return }
        let sourceDisplay = spaces.first(where: { $0.index == source })?.display
        if sourceDisplay != display {
            let result = command(["-m", "space", "\(source)", "--display", "\(display)"])
            guard result.success else {
                spaceReorderUnavailable = true
                refresh()
                return
            }
            refresh()
        }

        let didReorder: Bool
        if after {
            let ordered = spaces
                .filter { $0.display == display && $0.index != source }
                .sorted { $0.index < $1.index }
            if let next = ordered.first(where: { $0.index > target }) {
                didReorder = moveSpace(source, before: next.index)
            } else {
                didReorder = moveSpaceToEnd(source, display: display)
            }
        } else {
            didReorder = moveSpace(source, before: target)
        }
        spaceReorderUnavailable = !didReorder
    }

    func handleWorkspaceDrop(_ item: WorkspaceDragItem, targetSpace: Int?, targetDisplay: Int) {
        if item.kind == "window", let targetSpace {
            moveWindow(item.id, toSpace: targetSpace)
        } else if item.kind == "space" {
            if let targetSpace, item.id != targetSpace {
                dropSpace(item.id, on: targetSpace, display: targetDisplay, after: false)
            } else {
                moveSpace(item.id, toDisplay: targetDisplay)
            }
        }
    }
    func handleWorkspaceDrop(_ payload: String, targetSpace: Int?, targetDisplay: Int) {
        let parts = payload.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = Int(parts[1]) else { return }
        if parts[0] == "window", let targetSpace {
            moveWindow(id, toSpace: targetSpace)
        } else if parts[0] == "space" {
            if let targetSpace, id != targetSpace {
                dropSpace(id, on: targetSpace, display: targetDisplay, after: false)
            } else {
                moveSpace(id, toDisplay: targetDisplay)
            }
        }
    }
    func reorderWindow(_ id: Int, command arguments: [String]) {
        let focusedWindowID = windows.first(where: { $0.isFocused })?.id
        let sourceSpace = windows.first(where: { $0.id == id })?.space
        let result = command(["-m", "window", "\(id)"] + arguments)
        if result.success, arguments.contains("--space"), let sourceSpace {
            refresh()
            let destinationSpace = windows.first(where: { $0.id == id })?.space
            reflowAfterWindowMove(
                windowID: id,
                sourceSpaces: Set([sourceSpace, destinationSpace].compactMap { $0 }),
                focusedWindowID: focusedWindowID
            )
        }
        refresh()
    }
    private func rebalanceSpaces(_ indices: Set<Int>) {
        for index in indices.sorted() {
            _ = command(["-m", "space", "\(index)", "--balance"])
        }
    }
    private func reflowAfterWindowMove(windowID: Int, sourceSpaces: Set<Int>, focusedWindowID: Int?) {
        rebalanceSpaces(sourceSpaces)

        // Rebalancing is enough to update the source and destination frames.
        // If Yabai changed focus as a side effect of the move, restore the
        // original window directly; never focus the moved window transiently.
        if let focusedWindowID, focusedWindowID != windowID {
            _ = command(["-m", "window", "\(focusedWindowID)", "--focus"])
        }
    }
    func spaceCommand(_ index: Int, _ arguments: [String]) {
        _ = command(["-m", "space", "\(index)"] + arguments)
        refresh()
    }
    func windowAction(_ action: String) { _ = command(["-m", "window"] + action.split(separator: " ").map(String.init)); refresh() }
    func spaceAction(_ action: String) { _ = command(["-m", "space"] + action.split(separator: " ").map(String.init)); refresh() }
    func setConfig(_ key: String, _ value: String) {
        _ = command(["-m", "config", key, value])
        updateSetting(key, value)
        persistYabaiConfiguration()
    }
    func setSpaceConfig(_ key: String, _ value: String) {
        if key == "layout" {
            UserDefaults.standard.set(value, forKey: preferredLayoutKey)
        } else if key == "split_type" {
            UserDefaults.standard.set(value, forKey: preferredSplitTypeKey)
        }
        _ = command(["-m", "config", "--space", "\(focusedSpaceIndex)", key, value])
        updateSetting(key, value)
        persistYabaiConfiguration()
    }
    func refreshSettings() {
        guard isRunning else {
            settings = Self.readSettings(from: yabaiConfigFileURL)
            return
        }
        func read(_ key: String) -> String? { readConfig(key) }
        settings.externalBar = read("external_bar") ?? settings.externalBar
        settings.menubarOpacity = read("menubar_opacity") ?? settings.menubarOpacity
        settings.mouseFollowsFocus = readConfigBool("mouse_follows_focus")
        settings.focusFollowsMouse = read("focus_follows_mouse") ?? settings.focusFollowsMouse
        settings.displayArrangementOrder = read("display_arrangement_order") ?? settings.displayArrangementOrder
        settings.windowOriginDisplay = read("window_origin_display") ?? settings.windowOriginDisplay
        settings.windowPlacement = read("window_placement") ?? settings.windowPlacement
        settings.windowInsertionPoint = read("window_insertion_point") ?? settings.windowInsertionPoint
        settings.zoomPersist = readConfigBool("window_zoom_persist")
        settings.windowShadow = readConfigBool("window_shadow")
        settings.skipWindowFocusAnimation = readConfigBool("skip_window_focus_animation")
        settings.windowAnimationDuration = read("window_animation_duration") ?? settings.windowAnimationDuration
        settings.windowAnimationEasing = read("window_animation_easing") ?? settings.windowAnimationEasing
        settings.windowOpacityDuration = read("window_opacity_duration") ?? settings.windowOpacityDuration
        settings.activeWindowOpacity = read("active_window_opacity") ?? settings.activeWindowOpacity
        settings.normalWindowOpacity = read("normal_window_opacity") ?? settings.normalWindowOpacity
        settings.windowOpacity = readConfigBool("window_opacity")
        settings.insertFeedbackColor = read("insert_feedback_color") ?? settings.insertFeedbackColor
        settings.splitRatio = read("split_ratio") ?? settings.splitRatio
        settings.autoBalance = readConfigBool("auto_balance")
        settings.topPadding = Int(read("top_padding") ?? "") ?? settings.topPadding
        settings.bottomPadding = Int(read("bottom_padding") ?? "") ?? settings.bottomPadding
        settings.leftPadding = Int(read("left_padding") ?? "") ?? settings.leftPadding
        settings.rightPadding = Int(read("right_padding") ?? "") ?? settings.rightPadding
        settings.windowGap = Int(read("window_gap") ?? "") ?? settings.windowGap
        settings.layout = readConfig("layout", space: true) ?? settings.layout
        settings.splitType = readConfig("split_type", space: true) ?? settings.splitType
        settings.mouseModifier = read("mouse_modifier") ?? settings.mouseModifier
        settings.mouseAction1 = read("mouse_action1") ?? settings.mouseAction1
        settings.mouseAction2 = read("mouse_action2") ?? settings.mouseAction2
        settings.mouseDropAction = read("mouse_drop_action") ?? settings.mouseDropAction
    }

    private func updateSetting(_ key: String, _ value: String) {
        switch key {
        case "external_bar": settings.externalBar = value
        case "menubar_opacity": settings.menubarOpacity = value
        case "mouse_follows_focus": settings.mouseFollowsFocus = value == "on"
        case "focus_follows_mouse": settings.focusFollowsMouse = value
        case "display_arrangement_order": settings.displayArrangementOrder = value
        case "window_origin_display": settings.windowOriginDisplay = value
        case "window_placement": settings.windowPlacement = value
        case "window_insertion_point": settings.windowInsertionPoint = value
        case "window_zoom_persist": settings.zoomPersist = value == "on"
        case "window_shadow": settings.windowShadow = value == "on"
        case "skip_window_focus_animation": settings.skipWindowFocusAnimation = value == "on"
        case "window_animation_duration": settings.windowAnimationDuration = value
        case "window_animation_easing": settings.windowAnimationEasing = value
        case "window_opacity_duration": settings.windowOpacityDuration = value
        case "active_window_opacity": settings.activeWindowOpacity = value
        case "normal_window_opacity": settings.normalWindowOpacity = value
        case "window_opacity": settings.windowOpacity = value == "on"
        case "insert_feedback_color": settings.insertFeedbackColor = value
        case "split_ratio": settings.splitRatio = value
        case "auto_balance": settings.autoBalance = value == "on"
        case "top_padding": settings.topPadding = Int(value) ?? settings.topPadding
        case "bottom_padding": settings.bottomPadding = Int(value) ?? settings.bottomPadding
        case "left_padding": settings.leftPadding = Int(value) ?? settings.leftPadding
        case "right_padding": settings.rightPadding = Int(value) ?? settings.rightPadding
        case "window_gap": settings.windowGap = Int(value) ?? settings.windowGap
        case "layout": settings.layout = value
        case "split_type": settings.splitType = value
        case "mouse_modifier": settings.mouseModifier = value
        case "mouse_action1": settings.mouseAction1 = value
        case "mouse_action2": settings.mouseAction2 = value
        case "mouse_drop_action": settings.mouseDropAction = value
        default: break
        }
    }

    private func readConfigBool(_ key: String) -> Bool { readConfig(key) == "on" }
    private func readConfig(_ key: String, space: Bool = false) -> String? {
        var args = ["-m", "config"]
        if space { args += ["--space", "\(focusedSpaceIndex)"] }
        args.append(key)
        let result = command(args, record: false)
        return result.success ? result.output.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    private var focusedSpaceIndex: Int { currentSpaceIndex ?? 1 }
    private func decode<T: Decodable>(_ args: [String], label: String, as type: T.Type) -> T? {
        let result = command(args, record: false)
        guard result.success, let data = result.output.data(using: .utf8) else {
            dataError = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return nil
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            dataError = "Could not read Yabai (label) data: \(error.localizedDescription)"
            return nil
        }
    }
    @discardableResult
    private func command(_ arguments: [String], record: Bool = true) -> (success: Bool, output: String) {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: yabaiPath)
        process.arguments = arguments; process.standardOutput = pipe; process.standardError = pipe
        do {
            try process.run(); process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let success = process.terminationStatus == 0
            if record { logs.insert(ActivityLog(command: "yabai " + arguments.joined(separator: " "), output: output.trimmingCharacters(in: .whitespacesAndNewlines), success: success), at: 0) }
            return (success, output)
        } catch {
            let message = error.localizedDescription
            if record { logs.insert(ActivityLog(command: "yabai " + arguments.joined(separator: " "), output: message, success: false), at: 0) }
            return (false, message)
        }
    }
}
