import Foundation

// MARK: Volume

public enum VolumeStep {
    /// macOS moves volume in 16 steps, or 64 with ⌥⇧ held.
    public static let normalSteps: Float = 16
    public static let fineSteps: Float = 64

    /// The next level after pressing volume up or down, snapped to the
    /// step grid and kept within 0...1.
    public static func next(from current: Float, up: Bool, fine: Bool) -> Float {
        let steps = fine ? fineSteps : normalSteps
        let position = (current * steps).rounded()
        let moved = up ? position + 1 : position - 1
        return min(max(moved / steps, 0), 1)
    }

    /// Number of lit segments out of `segments` for a level.
    public static func segments(for level: Float, of segments: Int) -> Int {
        Int((min(max(level, 0), 1) * Float(segments)).rounded())
    }
}

public enum MediaKey: Int, Sendable {
    // Values from IOKit's ev_keymap.h (NX_KEYTYPE_*).
    case soundUp = 0
    case soundDown = 1
    case mute = 7
}

/// A volume key press, decoded from a system-defined event (subtype 8).
public struct MediaKeyEvent: Equatable, Sendable {
    public var key: MediaKey
    public var isDown: Bool
    public var isRepeat: Bool

    /// `data1` packs the key code in the high 16 bits and flags in the low
    /// 16: bits 8–15 are 0x0A for key down, 0x0B for key up; bit 0 is repeat.
    public static func decode(data1: Int) -> MediaKeyEvent? {
        let code = (data1 & 0xFFFF_0000) >> 16
        let flags = data1 & 0xFFFF
        let state = (flags & 0xFF00) >> 8
        guard let key = MediaKey(rawValue: code), state == 0x0A || state == 0x0B else { return nil }
        return MediaKeyEvent(key: key, isDown: state == 0x0A, isRepeat: flags & 0x1 == 1)
    }
}

// MARK: Chat

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public enum Role: Equatable, Sendable {
        case user
        case assistant
        /// Something went wrong; shown, but not part of the conversation.
        case notice
    }

    public let id: UUID
    public var role: Role
    public var text: String

    public init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

/// Why on-device AI chat can or can't run, in words a person can act on.
public enum AskAvailability: Equatable, Sendable {
    case available
    /// Needs macOS 26 or later.
    case needsNewerMacOS
    /// This build was made with an Xcode that doesn't include Apple's model framework.
    case notInThisBuild
    /// An Intel Mac, or one Apple Intelligence doesn't support.
    case deviceNotEligible
    case appleIntelligenceOff
    /// The model is still downloading or preparing.
    case modelNotReady
    case unknown

    public var title: String {
        switch self {
        case .available: return "Ask anything"
        case .needsNewerMacOS: return "Needs macOS 26"
        case .notInThisBuild: return "Not in this build"
        case .deviceNotEligible: return "Not available on this Mac"
        case .appleIntelligenceOff: return "Apple Intelligence is off"
        case .modelNotReady: return "Getting ready"
        case .unknown: return "Not available right now"
        }
    }

    public var message: String {
        switch self {
        case .available:
            return "Answers come from Apple's on-device model. Nothing you type leaves your Mac."
        case .needsNewerMacOS:
            return "On-device chat uses Apple Intelligence, which arrived in macOS 26."
        case .notInThisBuild:
            return "This copy was built without Apple's on-device model. Build with Xcode 26 to include it."
        case .deviceNotEligible:
            return "Apple Intelligence needs a Mac with Apple silicon."
        case .appleIntelligenceOff:
            return "Turn it on in System Settings › Apple Intelligence & Siri."
        case .modelNotReady:
            return "Apple Intelligence is still downloading. Try again in a few minutes."
        case .unknown:
            return "Apple Intelligence didn't respond. Try again later."
        }
    }

    /// Whether System Settings can fix it.
    public var canOpenSettings: Bool { self == .appleIntelligenceOff }
}

public struct ChatTranscript: Equatable, Sendable {
    public private(set) var messages: [ChatMessage] = []
    /// Older messages are dropped from view beyond this.
    public var limit: Int

    public init(limit: Int = 100) {
        self.limit = limit
    }

    /// Adds a message; blank user messages are ignored. Returns it.
    @discardableResult
    public mutating func append(_ role: ChatMessage.Role, _ text: String) -> ChatMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let message = ChatMessage(role: role, text: trimmed)
        messages.append(message)
        if messages.count > limit {
            messages.removeFirst(messages.count - limit)
        }
        return message
    }

    public mutating func clear() {
        messages.removeAll()
    }

    public var isEmpty: Bool { messages.isEmpty }
}
