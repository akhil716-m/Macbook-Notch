import NotchCore
import SwiftUI

/// Shown in the open notch instead of the tools when the app isn't
/// activated (only in builds where licensing is configured).
struct LicenseGate: View {
    @ObservedObject var license: LicenseService
    @State private var key = ""

    var body: some View {
        VStack(spacing: NotchStyle.Space.s) {
            Text(title)
                .font(NotchStyle.Font.emptyTitle)
                .foregroundStyle(NotchStyle.Palette.primaryText)
            Text(detail)
                .font(NotchStyle.Font.emptyBody)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .multilineTextAlignment(.center)
            HStack(spacing: NotchStyle.Space.s) {
                TextField("Licence key", text: $key)
                    .textFieldStyle(.plain)
                    .font(NotchStyle.Font.body)
                    .padding(.horizontal, NotchStyle.Space.m)
                    .frame(height: NotchStyle.Chip.height + NotchStyle.Space.xs)
                    .background(
                        RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                            .fill(NotchStyle.Palette.rowBackground)
                    )
                    .onSubmit { license.activate(key: key) }
                Button(license.isWorking ? "Activating…" : "Activate") { license.activate(key: key) }
                    .buttonStyle(ChipButtonStyle(isProminent: true))
                    .disabled(license.isWorking || key.trimmingCharacters(in: .whitespaces).isEmpty)
                if license.purchaseURL != nil {
                    Button("Buy") { license.buy() }
                        .buttonStyle(ChipButtonStyle())
                }
            }
            if let message = license.message {
                Text(message)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch license.standing {
        case .revoked: return "This licence is no longer active"
        case .graceExpired: return "Time to check your licence"
        default: return "Activate MacbookNotch"
        }
    }

    private var detail: String {
        switch license.standing {
        case .graceExpired:
            return "We couldn't confirm your licence for a month. Connect to the internet and it will check automatically."
        case .revoked:
            return "Enter a valid key to keep using MacbookNotch."
        default:
            return "Enter the key from your purchase email. One key works on up to 3 Macs."
        }
    }
}

/// The Licence tab in Settings.
struct LicenseSettings: View {
    @ObservedObject var license: LicenseService
    @State private var key = ""

    var body: some View {
        Form {
            if !license.isConfigured {
                Section {
                    Text("Licensing isn't set up in this build, so everything is unlocked.")
                    Text("Add your Lemon Squeezy store and product IDs to project.yml (MNLicenseStoreID, MNLicenseProductID) to turn it on.")
                        .foregroundStyle(.secondary)
                }
            } else if let record = license.record {
                Section("This Mac") {
                    LabeledContent("Status", value: statusText)
                    LabeledContent("Key", value: record.maskedKey)
                    LabeledContent("Activated", value: record.activatedAt.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Last checked", value: record.lastValidatedAt.formatted(.relative(presentation: .named)))
                }
                Section {
                    Button("Check Now") { license.validate() }
                        .disabled(license.isWorking)
                    Button("Deactivate This Mac…") { license.deactivate() }
                        .disabled(license.isWorking)
                } footer: {
                    Text("Deactivating frees this Mac's slot so you can use the key on another Mac.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    TextField("Licence key", text: $key)
                        .onSubmit { license.activate(key: key) }
                    HStack {
                        Button(license.isWorking ? "Activating…" : "Activate") { license.activate(key: key) }
                            .disabled(license.isWorking || key.trimmingCharacters(in: .whitespaces).isEmpty)
                        if license.purchaseURL != nil {
                            Button("Buy a Licence") { license.buy() }
                        }
                    }
                } footer: {
                    Text("One key works on up to 3 Macs, and keeps working offline.")
                        .foregroundStyle(.secondary)
                }
            }
            if let message = license.message {
                Section {
                    Text(message).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var statusText: String {
        switch license.standing {
        case .licensed: return "Active"
        case .needsCheck: return "Active (checking soon)"
        case .graceExpired: return "Needs a check: go online"
        case .revoked: return "No longer valid"
        case .unlicensed: return "Not activated"
        }
    }
}
