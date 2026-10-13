import Foundation
import NotchCore

/// Per-window state. Each screen's notch has its own.
@MainActor
final class NotchViewModel: ObservableObject {
    @Published var layout: NotchLayout
    @Published var isOpen = false
    /// Something worth showing while closed (music playing).
    @Published var liveActivityActive = false
    /// A file drag is over the open notch.
    @Published var isDropTargeted = false
    /// ⌥ is held: show delete buttons on shelf and clipboard items.
    @Published var optionHeld = false

    init(layout: NotchLayout) {
        self.layout = layout
    }

    var presentation: NotchPresentation {
        if isOpen { return .open }
        return liveActivityActive ? .compact : .closed
    }
}
