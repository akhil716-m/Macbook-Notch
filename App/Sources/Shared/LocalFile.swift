import Foundation
import NotchCore

/// One small Codable value stored as JSON in Application Support.
struct LocalFile<Value: Codable> {
    let url: URL

    func load() -> Value? {
        JSONFileStore.load(Value.self, from: url)
    }

    func save(_ value: Value) {
        do {
            try JSONFileStore.save(value, to: url)
        } catch {
            NSLog("MacbookNotch: could not save \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
