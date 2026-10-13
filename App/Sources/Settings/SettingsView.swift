import AppKit
import NotchCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLogin
    let shelf: ShelfService
    let clipboard: ClipboardService
    let license: LicenseService
    let updates: UpdateService
    let stocks: StocksService
    let revenue: RevenueService

    var body: some View {
        TabView {
            GeneralSettings(settings: settings, launchAtLogin: launchAtLogin, updates: updates)
                .tabItem { Label("General", systemImage: "gearshape") }
            ToolsSettings(settings: settings)
                .tabItem { Label("Tools", systemImage: "square.grid.2x2") }
            ShelfSettings(settings: settings, shelf: shelf)
                .tabItem { Label("Shelf", systemImage: "tray.full") }
            ClipboardSettings(settings: settings, clipboard: clipboard)
                .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
            IntegrationsSettings(settings: settings, stocks: stocks, revenue: revenue)
                .tabItem { Label("Integrations", systemImage: "link") }
            LicenseSettings(license: license)
                .tabItem { Label("Licence", systemImage: "key") }
        }
        .frame(width: 560, height: 460)
    }
}

// MARK: General

private struct GeneralSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLogin
    @ObservedObject var updates: UpdateService

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                Picker("Show the notch on", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } footer: {
                Text("Screens without a notch get a floating one at the top centre.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show volume changes in the notch", isOn: $settings.showVolumeInNotch)
                Toggle("Hide the macOS volume popup", isOn: $settings.replaceSystemVolumeHUD)
                    .disabled(!settings.showVolumeInNotch)
            } header: {
                Text("Volume")
            } footer: {
                Text("Hiding the macOS popup needs Accessibility permission, so the notch can catch the volume keys. Turn MacbookNotch on in Privacy & Security › Accessibility, then switch this off and on again.")
                    .foregroundStyle(.secondary)
            }

            Section("Weather") {
                Picker("Temperature", selection: $settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text("\(unit.title) (\(unit.symbol))").tag(unit)
                    }
                }
                LabeledContent("Place", value: settings.weatherLocation?.fullName ?? "Not set")
                if settings.weatherLocation != nil {
                    Button("Forget Place") { settings.weatherLocation = nil }
                }
            }

            Section {
                ScreenInfo()
            } header: {
                Text("This screen")
            } footer: {
                Text("If the notch looks misplaced, send a screenshot of this section.")
                    .foregroundStyle(.secondary)
            }

            Section("Updates") {
                LabeledContent("Version", value: UpdateService.versionDescription)
                if updates.isConfigured {
                    Toggle("Check for updates automatically", isOn: Binding(
                        get: { updates.automaticallyChecks },
                        set: { updates.automaticallyChecks = $0 }
                    ))
                    Button("Check Now") { updates.checkForUpdates() }
                        .disabled(!updates.canCheck)
                } else {
                    Text("Updates aren't set up in this build.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Hover") {
                LabeledContent("Open after") {
                    HStack {
                        Slider(value: $settings.openDelay, in: AppSettings.openDelayRange, step: 0.02)
                        Text(seconds(settings.openDelay)).monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
                LabeledContent("Close after") {
                    HStack {
                        Slider(value: $settings.closeDelay, in: AppSettings.closeDelayRange, step: 0.05)
                        Text(seconds(settings.closeDelay)).monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func seconds(_ value: Double) -> String {
        String(format: "%.2f s", value)
    }
}

// MARK: Tools

private struct ToolsSettings: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose which tools appear in the notch. Drag to change their order.")
                .foregroundStyle(.secondary)
            List {
                ForEach(settings.tools.order) { tool in
                    Toggle(isOn: Binding(
                        get: { settings.tools.isEnabled(tool) },
                        set: { settings.setTool(tool, enabled: $0) }
                    )) {
                        Label(tool.title, systemImage: tool.symbolName)
                    }
                    .disabled(settings.tools.isEnabled(tool) && settings.tools.enabled.count == 1)
                }
                .onMove { source, destination in
                    settings.moveTools(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            Text("At least one tool stays on.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: Shelf

private struct ShelfSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shelf: ShelfService
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section {
                Picker("Keep files for", selection: $settings.shelfRetention) {
                    ForEach(ShelfRetention.allCases) { retention in
                        Text(retention.title).tag(retention)
                    }
                }
            } footer: {
                Text("The shelf keeps its own copy, so moving or deleting the original won't affect it.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("On the shelf now", value: shelf.items.count == 1 ? "1 item" : "\(shelf.items.count) items")
                Button("Remove Everything from the Shelf…", role: .destructive) {
                    confirmingClear = true
                }
                .disabled(shelf.items.isEmpty)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Remove everything from the shelf?", isPresented: $confirmingClear) {
            Button("Remove All", role: .destructive) { shelf.removeAll() }
        } message: {
            Text("This deletes the shelf's copies. Your original files aren't touched.")
        }
    }
}

// MARK: Clipboard

private struct ClipboardSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var clipboard: ClipboardService
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section {
                Picker("Keep the last", selection: $settings.clipboardLimit) {
                    ForEach(ClipboardHistory.limitOptions, id: \.self) { limit in
                        Text("\(limit) items").tag(limit)
                    }
                }
            } footer: {
                Text("History is stored only on this Mac. Passwords copied from password managers are never saved.")
                    .foregroundStyle(.secondary)
            }

            Section("Never record copies from") {
                if settings.ignoredApps.isEmpty {
                    Text("No apps").foregroundStyle(.secondary)
                }
                ForEach(settings.ignoredApps, id: \.self) { bundleID in
                    HStack {
                        AppLabel(bundleID: bundleID)
                        Spacer()
                        Button {
                            settings.ignoredApps.removeAll { $0 == bundleID }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Stop ignoring")
                    }
                }
                Button("Add App…", action: addApp)
            }

            Section {
                Button("Clear Clipboard History…", role: .destructive) {
                    confirmingClear = true
                }
                .disabled(clipboard.clips.isEmpty)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmingClear) {
            Button("Clear History", role: .destructive) { clipboard.removeAll() }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Ignore"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier, !settings.ignoredApps.contains(bundleID) {
                settings.ignoredApps.append(bundleID)
            }
        }
    }
}

/// An app's icon and name from its bundle identifier, or the identifier
/// itself if the app isn't installed.
private struct AppLabel: View {
    let bundleID: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Label {
                Text(FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
            } icon: {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 16, height: 16)
            }
        } else {
            Text(bundleID).foregroundStyle(.secondary)
        }
    }
}

/// The measurements the notch layout is based on, for troubleshooting.
private struct ScreenInfo: View {
    var body: some View {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        if let screen {
            let left = screen.auxiliaryTopLeftArea?.width
            let right = screen.auxiliaryTopRightArea?.width
            let notchWidth = left.flatMap { l in right.map { r in screen.frame.width - l - r } }
            LabeledContent("Screen", value: "\(Int(screen.frame.width)) × \(Int(screen.frame.height)) pt")
            LabeledContent("Notch", value: notchWidth.map { "\(Int($0)) × \(Int(screen.safeAreaInsets.top)) pt" } ?? "None (floating notch)")
            LabeledContent("Menu bar", value: "\(Int(screen.frame.maxY - screen.visibleFrame.maxY)) pt")
            LabeledContent("macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
        } else {
            Text("No screen found").foregroundStyle(.secondary)
        }
    }
}
