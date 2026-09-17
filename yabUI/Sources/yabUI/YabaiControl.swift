import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
            model.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { break }
                model.refresh()
            }
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
                    Text(model.isRunning ? "Yabai is running" : "Yabai is stopped")
                        .font(.caption.weight(.semibold))
                    Text(model.version.isEmpty ? "Not detected" : model.version)
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
                    Text(model.isRunning ? "Yabai is running" : "Yabai is stopped")
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
                Label(model.isRunning ? "Pause Yabai" : "Start Yabai", systemImage: model.isRunning ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 8) {
                Button { model.restartService() } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!model.isRunning)
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
        .task {
            model.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { break }
                model.refresh()
            }
        }
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
            .allowsHitTesting(false)
    }
}

struct StatusSurfaceWindowTile: View {
    @EnvironmentObject private var model: YabaiModel
    @EnvironmentObject private var dropCoordinator: WorkspaceDropCoordinator
    let window: YabaiWindow
    let rect: CGRect

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
        .onTapGesture { model.focusWindow(window.id) }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in
                    dropCoordinator.updatePreview(for: WorkspaceDragItem(kind: "window", id: window.id), at: value.location, model: model)
                }
                .onEnded { value in
                    dropCoordinator.handleDrop(WorkspaceDragItem(kind: "window", id: window.id), at: value.location, model: model)
                }
        )
        .help("Click to focus · drag to move or split · \(window.app.isEmpty ? "Window" : window.app)")
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
                    Text(model.isRunning ? "Yabai is active" : "Yabai is not running")
                        .font(.title2.weight(.bold))
                    Text(model.isRunning ? "Your window manager is ready for commands." : "Start the service to manage your windows.")
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
            HStack(spacing: 10) {
                Button { model.restartService() } label: { Label("Restart", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                    .disabled(!model.isRunning)
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
                if let dataError = model.dataError {
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
    @EnvironmentObject private var model: YabaiModel
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
            .onTapGesture { model.focusWindow(window.id) }
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
            if let dataError = model.dataError {
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
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { value in
                        dragOffset = value.translation
                        dropCoordinator.updatePreview(for: WorkspaceDragItem(kind: "window", id: window.id), at: value.location, model: model)
                    }
                    .onEnded { value in
                        dropCoordinator.handleDrop(WorkspaceDragItem(kind: "window", id: window.id), at: value.location, model: model)
                        dragOffset = .zero
                    }
            )
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
            if let dataError = model.dataError {
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
            if let dataError = model.dataError {
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
                Toggle("Mouse follows focus", isOn: Binding(get: { model.settings.mouseFollowsFocus }, set: { model.setConfig("mouse_follows_focus", $0 ? "on" : "off"); model.settings.mouseFollowsFocus = $0 }))
                Picker("Focus follows mouse", selection: Binding(get: { model.settings.focusFollowsMouse }, set: { model.setConfig("focus_follows_mouse", $0); model.settings.focusFollowsMouse = $0 })) {
                    Text("Off").tag("off")
                    Text("Autofocus").tag("autofocus")
                    Text("Autorise").tag("autoraise")
                }
                Toggle("Window opacity", isOn: Binding(get: { model.settings.windowOpacity }, set: { model.setConfig("window_opacity", $0 ? "on" : "off"); model.settings.windowOpacity = $0 }))
                Toggle("Keep zoom state", isOn: Binding(get: { model.settings.zoomPersist }, set: { model.setConfig("window_zoom_persist", $0 ? "on" : "off"); model.settings.zoomPersist = $0 }))
            }
            Section("Current space") {
                Picker("Layout", selection: Binding(get: { model.settings.layout }, set: { model.setSpaceConfig("layout", $0); model.settings.layout = $0 })) {
                    Text("BSP").tag("bsp")
                    Text("Stack").tag("stack")
                    Text("Float").tag("float")
                }
                Picker("Split type", selection: Binding(get: { model.settings.splitType }, set: { model.setSpaceConfig("split_type", $0); model.settings.splitType = $0 })) {
                    Text("Auto").tag("auto")
                    Text("Vertical").tag("vertical")
                    Text("Horizontal").tag("horizontal")
                }
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
            Section {
                Button("Refresh settings") { model.refreshSettings() }
                Text("Settings are written through Yabai's live message interface. Persist them in your yabairc if you want them to survive a restart.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
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

struct YabaiSettings {
    var mouseFollowsFocus = false
    var focusFollowsMouse = "off"
    var windowOpacity = false
    var zoomPersist = false
    var layout = "bsp"
    var splitType = "auto"
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
    enum CodingKeys: String, CodingKey { case index, label, display, windows, layout, hasFocus = "has-focus", focused }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        index = try values.decodeIfPresent(Int.self, forKey: .index) ?? 0
        label = try values.decodeIfPresent(String.self, forKey: .label) ?? ""
        display = try values.decodeIfPresent(Int.self, forKey: .display) ?? 0
        windows = try values.decodeIfPresent([Int].self, forKey: .windows) ?? []
        layout = try values.decodeIfPresent(String.self, forKey: .layout) ?? "bsp"
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

@MainActor
final class YabaiModel: ObservableObject {
    @Published var isRunning = false
    @Published var version = ""
    @Published var windows: [YabaiWindow] = []
    @Published var spaces: [YabaiSpace] = []
    @Published var displays: [YabaiDisplay] = []
    @Published var logs: [ActivityLog] = []
    @Published var settings = YabaiSettings()
    @Published var dataError: String?
    @Published var spaceReorderUnavailable = false

    private let decoder = JSONDecoder()
    private let systemYabaiCandidates = ["/opt/homebrew/bin/yabai", "/usr/local/bin/yabai", "/usr/bin/yabai"]
    private var yabaiCandidates: [String] {
        let bundled = Bundle.main.path(forResource: "yabai", ofType: nil)
        return ([bundled].compactMap { $0 } + systemYabaiCandidates)
    }
    private var yabaiPath: String { yabaiCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) ?? "/opt/homebrew/bin/yabai" }

    func refresh() {
        dataError = nil
        version = command(["--version"], record: false).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = command(["-m", "query", "--windows"], record: false)
        isRunning = status.success
        if isRunning {
            windows = decode(["-m", "query", "--windows"], label: "windows", as: [YabaiWindow].self) ?? []
            spaces = decode(["-m", "query", "--spaces"], label: "spaces", as: [YabaiSpace].self) ?? []
            displays = decode(["-m", "query", "--displays"], label: "displays", as: [YabaiDisplay].self) ?? []
            refreshSettings()
        } else {
            windows = []; spaces = []; displays = []
            let message = status.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty { dataError = message }
        }
    }

    func toggleService() { isRunning ? stopService() : startService() }
    func startService() { _ = command(["--start-service"]); refresh() }
    func stopService() { _ = command(["--stop-service"]); refresh() }
    func restartService() { _ = command(["--restart-service"]); refresh() }
    func focusWindow(_ id: Int) { _ = command(["-m", "window", "--focus", "\(id)"]); refresh() }
    func focusSpace(_ index: Int) { _ = command(["-m", "space", "--focus", "\(index)"]); refresh() }
    func focusDisplay(_ index: Int) { _ = command(["-m", "display", "\(index)", "--focus"]); refresh() }
    func moveWindow(_ id: Int, toSpace space: Int) {
        let movedWindow = windows.first(where: { $0.id == id })
        let focusedWindowID = windows.first(where: { $0.isFocused })?.id
        let sourceSpace = windows.first(where: { $0.id == id })?.space
        let result = command(["-m", "window", "\(id)", "--space", "\(space)"])
        if result.success {
            reflowAfterWindowMove(
                windowID: id,
                sourceSpaces: Set([sourceSpace, space].compactMap { $0 }),
                movedWindow: movedWindow,
                focusedWindowID: focusedWindowID
            )
        }
        refresh()
    }

    func moveWindow(_ id: Int, toDisplay display: Int) {
        let movedWindow = windows.first(where: { $0.id == id })
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
            movedWindow: movedWindow,
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
        let movedWindow = windows.first(where: { $0.id == source })
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
                movedWindow: movedWindow,
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
        let movedWindow = windows.first(where: { $0.id == id })
        let focusedWindowID = windows.first(where: { $0.isFocused })?.id
        let sourceSpace = windows.first(where: { $0.id == id })?.space
        let result = command(["-m", "window", "\(id)"] + arguments)
        if result.success, arguments.contains("--space"), let sourceSpace {
            refresh()
            let destinationSpace = windows.first(where: { $0.id == id })?.space
            reflowAfterWindowMove(
                windowID: id,
                sourceSpaces: Set([sourceSpace, destinationSpace].compactMap { $0 }),
                movedWindow: movedWindow,
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
    private func reflowAfterWindowMove(windowID: Int, sourceSpaces: Set<Int>, movedWindow: YabaiWindow?, focusedWindowID: Int?) {
        rebalanceSpaces(sourceSpaces)

        // Yabai can leave an unfocused window with its old frame after a
        // cross-space move. A focus round-trip forces WindowServer to apply
        // the new geometry, then restores the user's original focus.
        if let movedWindow, movedWindow.isRenderable,
           let focusedWindowID, focusedWindowID != windowID {
            _ = command(["-m", "window", "\(windowID)", "--focus"])
            _ = command(["-m", "window", "\(focusedWindowID)", "--focus"])
            rebalanceSpaces(sourceSpaces)
        }
    }
    func spaceCommand(_ index: Int, _ arguments: [String]) {
        _ = command(["-m", "space", "\(index)"] + arguments)
        refresh()
    }
    func windowAction(_ action: String) { _ = command(["-m", "window"] + action.split(separator: " ").map(String.init)); refresh() }
    func spaceAction(_ action: String) { _ = command(["-m", "space"] + action.split(separator: " ").map(String.init)); refresh() }
    func setConfig(_ key: String, _ value: String) { _ = command(["-m", "config", key, value]) }
    func setSpaceConfig(_ key: String, _ value: String) { _ = command(["-m", "config", "--space", "\(focusedSpaceIndex)", key, value]) }
    func refreshSettings() {
        guard isRunning else { return }
        settings.mouseFollowsFocus = readConfigBool("mouse_follows_focus")
        settings.windowOpacity = readConfigBool("window_opacity")
        settings.zoomPersist = readConfigBool("window_zoom_persist")
        settings.focusFollowsMouse = readConfig("focus_follows_mouse") ?? "off"
        settings.layout = readConfig("layout", space: true) ?? "bsp"
        settings.splitType = readConfig("split_type", space: true) ?? "auto"
    }

    private func readConfigBool(_ key: String) -> Bool { readConfig(key) == "on" }
    private func readConfig(_ key: String, space: Bool = false) -> String? {
        var args = ["-m", "config"]
        if space { args += ["--space", "\(focusedSpaceIndex)"] }
        args.append(key)
        let result = command(args, record: false)
        return result.success ? result.output.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    private var focusedSpaceIndex: Int { spaces.first(where: { $0.isFocused })?.index ?? 1 }
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
