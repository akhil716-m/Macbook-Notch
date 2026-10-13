import Foundation
import NotchCore

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var layout: NotchLayout
    @Published var isOpen = false
    /// Something worth showing while closed (music playing).
    @Published var liveActivityActive = false

    init(layout: NotchLayout) {
        self.layout = layout
    }

    var presentation: NotchPresentation {
        if isOpen { return .open }
        return liveActivityActive ? .compact : .closed
    }
}
