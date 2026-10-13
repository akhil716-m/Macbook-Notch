import AppKit
import Foundation
import NotchCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device chat with Apple's Foundation Models (Apple Intelligence).
/// Everything runs on the Mac; nothing is sent anywhere.
///
/// Needs macOS 26 on Apple silicon with Apple Intelligence on, and a build
/// made with Xcode 26. Everywhere else the tool explains why it's unavailable.
@MainActor
final class AskService: ObservableObject {
    @Published private(set) var transcript = ChatTranscript()
    @Published private(set) var availability: AskAvailability = .unknown
    @Published private(set) var isThinking = false

    /// Kept as `AnyObject` so this class doesn't need macOS 26 itself.
    private var engine: AnyObject?

    static let instructions = """
    You are a helpful assistant that lives in the MacBook's notch. \
    Keep answers short and direct: a few sentences or a brief list, unless the user asks for more. \
    Use plain text without Markdown headings.
    """

    func refreshAvailability() {
        availability = Self.currentAvailability()
    }

    func send(_ text: String) {
        guard !isThinking, transcript.append(.user, text) != nil else { return }
        refreshAvailability()
        guard availability == .available else {
            transcript.append(.notice, availability.message)
            return
        }
        isThinking = true
        Task {
            defer { self.isThinking = false }
            do {
                let reply = try await self.respond(to: text)
                self.transcript.append(.assistant, reply)
            } catch {
                self.transcript.append(.notice, Self.describe(error))
            }
        }
    }

    /// Starts a fresh conversation (the model forgets the old one).
    func newChat() {
        transcript.clear()
        engine = nil
    }

    func openAppleIntelligenceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Model

    private func respond(to prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let engine = (self.engine as? FoundationEngine) ?? FoundationEngine(instructions: Self.instructions)
            self.engine = engine
            return try await engine.respond(to: prompt)
        }
        #endif
        throw AskError.unavailable
    }

    private static func currentAvailability() -> AskAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceOff
            case .unavailable(.modelNotReady):
                return .modelNotReady
            default:
                return .unknown
            }
        }
        return .needsNewerMacOS
        #else
        return .notInThisBuild
        #endif
    }

    private static func describe(_ error: Error) -> String {
        if error is AskError { return AskAvailability.unknown.message }
        return "That didn't work: \(error.localizedDescription) Try rephrasing, or start a new chat."
    }
}

private enum AskError: Error {
    case unavailable
}

#if canImport(FoundationModels)
/// Holds one model session, which remembers the conversation so far.
@available(macOS 26.0, *)
@MainActor
private final class FoundationEngine {
    private let session: LanguageModelSession

    init(instructions: String) {
        session = LanguageModelSession(instructions: instructions)
    }

    func respond(to prompt: String) async throws -> String {
        try await session.respond(to: prompt).content
    }
}
#endif
