import Foundation

public struct EmojiItem: Hashable, Identifiable, Sendable {
    public let character: String
    /// Unicode name in lower case, e.g. "grinning face".
    public let name: String

    public var id: String { character }

    public init(character: String, name: String) {
        self.character = character
        self.name = name
    }
}

/// Every single-character emoji, named from the Unicode data built into
/// Swift, so there's no emoji list to ship or keep up to date. Flags,
/// skin-tone variants and multi-person sequences aren't included.
public enum EmojiCatalog {
    private static let ranges: [ClosedRange<UInt32>] = [
        0x231A...0x2B55,
        0x1F004...0x1F0CF,
        0x1F18E...0x1F251,
        0x1F300...0x1F3FA,
        0x1F400...0x1F64F,
        0x1F680...0x1F6FF,
        0x1F7E0...0x1F7EB,
        0x1F90C...0x1F9FF,
        0x1FA70...0x1FAFF,
    ]

    public static let all: [EmojiItem] = ranges.flatMap { range in
        range.compactMap { value -> EmojiItem? in
            guard let scalar = Unicode.Scalar(value),
                  scalar.properties.isEmojiPresentation,
                  !scalar.properties.isEmojiModifier,
                  let name = scalar.properties.name
            else { return nil }
            return EmojiItem(character: String(Character(scalar)), name: name.lowercased())
        }
    }

    /// Every word of the query must appear in the name.
    public static func search(_ query: String, in items: [EmojiItem] = all) -> [EmojiItem] {
        let words = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return items }
        return items.filter { item in words.allSatisfy { item.name.contains($0) } }
    }

    /// Most recent first, no duplicates, at most `limit`.
    public static func recordingUse(of character: String, in recents: [String], limit: Int = 16) -> [String] {
        Array(([character] + recents.filter { $0 != character }).prefix(limit))
    }
}
