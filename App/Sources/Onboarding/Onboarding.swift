import AppKit
import EventKit
import NotchCore
import SwiftUI
import UserNotifications

/// The welcome window shown on first launch (and from the menu bar item
/// later): how to use the notch, which permissions do what, and setup.
@MainActor
final class OnboardingWindowController {
    private let services: AppServices
    private var window: NSWindow?

    init(services: AppServices) {
        self.services = services
    }

    func show() {
        if window == nil {
            let view = OnboardingView(services: services, settings: services.settings, launchAtLogin: services.launchAtLogin) { [weak self] in
                self?.finish()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Welcome to MacbookNotch"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        services.settings.onboardingCompleted = true
        window?.close()
    }
}

private struct OnboardingView: View {
    let services: AppServices
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLogin
    let onDone: () -> Void

    @State private var page = 0
    @State private var notifications: AccessState = .notAsked

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: welcome
                case 1: permissions
                default: finish
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)

            Divider()
            HStack {
                if page > 0 {
                    Button("Back") { page -= 1 }
                }
                Spacer()
                Text("\(page + 1) of 3").foregroundStyle(.secondary)
                Spacer()
                if page < 2 {
                    Button("Continue") { page += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Start Using MacbookNotch", action: onDone)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .frame(width: 520, height: 460)
        .task { await refreshNotificationState() }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your notch, put to work")
                .font(.largeTitle.bold())
            Text("MacbookNotch turns the black notch at the top of your screen into a small panel of tools.")
                .foregroundStyle(.secondary)
            tip("cursorarrow.motionlines", "Hover the notch to open it", "Move away and it closes. Clicking it opens it straight away.")
            tip("square.grid.2x2", "Switch tools with the tabs", "They sit either side of the notch. Turn tools on or off in Settings.")
            tip("tray.and.arrow.down", "Drag files onto the notch", "They wait on the Shelf until you need them, or AirDrop them on.")
            tip("option", "Hold ⌥ to delete", "Shelf files, clipboard items and to-dos show a remove button.")
            tip("escape", "Press Esc to close", "Handy after typing a note or a question.")
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.title.bold())
            Text("Each tool asks only when you first use it. You can also allow them here. Everything stays on this Mac.")
                .foregroundStyle(.secondary)
            permissionRow(
                "bell.badge", "Notifications", "So timers can tell you when they're done.",
                state: notifications,
                action: {
                    Task {
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                        await refreshNotificationState()
                    }
                }
            )
            CalendarPermissionRow(calendar: services.calendar)
            RemindersPermissionRow(reminders: services.reminders)
            infoRow("music.note", "Music and Spotify", "macOS asks the first time a song plays while MacbookNotch is running.")
            infoRow("location", "Location (optional)", "Only if you choose \"Use My Location\" in Weather.")
            infoRow("accessibility", "Accessibility (optional)", "Only to hide the macOS volume popup. Settings › General › Volume.")
        }
    }

    private var finish: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Almost done")
                .font(.title.bold())
            Toggle("Open MacbookNotch when you log in", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            if services.license.isConfigured {
                Divider()
                LicenseSettings(license: services.license)
                    .frame(height: 200)
            }
            Text("You can change all of this later from the menu bar icon › Settings.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Pieces

    private func tip(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }

    private func permissionRow(_ symbol: String, _ title: String, _ detail: String, state: AccessState, action: @escaping () -> Void) -> some View {
        OnboardingPermissionRow(symbol: symbol, title: title, detail: detail, state: state, action: action)
    }

    private func infoRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func refreshNotificationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: notifications = .granted
        case .notDetermined: notifications = .notAsked
        default: notifications = .denied
        }
    }
}

private struct OnboardingPermissionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let state: AccessState
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            switch state {
            case .granted:
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            case .notAsked:
                Button("Allow", action: action)
            case .denied:
                Text("Off in System Settings").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

private struct CalendarPermissionRow: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        OnboardingPermissionRow(
            symbol: "calendar",
            title: "Calendar",
            detail: "Shows today's and tomorrow's events.",
            state: calendar.access,
            action: { calendar.requestAccess() }
        )
    }
}

private struct RemindersPermissionRow: View {
    @ObservedObject var reminders: RemindersService

    var body: some View {
        OnboardingPermissionRow(
            symbol: "list.bullet.circle",
            title: "Reminders",
            detail: "Lists what's due and lets you tick it off.",
            state: reminders.access,
            action: { reminders.requestAccess() }
        )
    }
}
