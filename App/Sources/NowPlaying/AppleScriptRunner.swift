import AppKit
import NotchCore

enum AppleScriptError: Error, Equatable, Sendable {
    /// The user said no (or hasn't been asked yet) under Privacy & Security › Automation.
    case notPermitted
    case failed(code: Int, message: String)
}

/// Runs AppleScript on one background queue, so a slow or hung player never
/// blocks the UI, and converts results to Sendable values before they leave it.
final class AppleScriptRunner: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.macbooknotch.applescript", qos: .userInitiated)

    /// errAEEventNotPermitted
    private static let notPermittedCode = -1743

    func fields(_ source: String) async -> Result<[ScriptField], AppleScriptError> {
        await perform(source) { Self.fields(from: $0) }
    }

    func data(_ source: String) async -> Result<Data?, AppleScriptError> {
        await perform(source) { descriptor in
            descriptor.descriptorType == Self.fourCC("msng") ? nil : descriptor.data
        }
    }

    func run(_ source: String) async -> Result<Void, AppleScriptError> {
        await perform(source) { _ in () }
    }

    private func perform<T: Sendable>(
        _ source: String,
        convert: @escaping @Sendable (NSAppleEventDescriptor) -> T
    ) async -> Result<T, AppleScriptError> {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: Self.execute(source).map(convert))
            }
        }
    }

    private static func execute(_ source: String) -> Result<NSAppleEventDescriptor, AppleScriptError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.failed(code: 0, message: "Could not create the script"))
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
            return .failure(code == notPermittedCode ? .notPermitted : .failed(code: code, message: message))
        }
        return .success(result)
    }

    // MARK: Descriptor conversion

    private static func fields(from descriptor: NSAppleEventDescriptor) -> [ScriptField] {
        guard descriptor.descriptorType == fourCC("list") else {
            return [field(from: descriptor)]
        }
        let count = descriptor.numberOfItems
        guard count > 0 else { return [] }
        return (1...count).map { index in
            descriptor.atIndex(index).map(field(from:)) ?? .missing
        }
    }

    private static func field(from descriptor: NSAppleEventDescriptor) -> ScriptField {
        let type = descriptor.descriptorType
        if type == fourCC("msng") || type == fourCC("null") {
            return .missing
        }
        if numericTypes.contains(type) {
            return .number(descriptor.doubleValue)
        }
        return descriptor.stringValue.map(ScriptField.text) ?? .missing
    }

    private static let numericTypes: Set<UInt32> = Set(
        ["doub", "long", "sing", "shor", "comp", "magn", "exte", "ldbl"].map(AppleScriptRunner.fourCC)
    )

    private static func fourCC(_ code: String) -> UInt32 {
        code.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
