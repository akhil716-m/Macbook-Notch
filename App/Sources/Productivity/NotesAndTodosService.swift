import Foundation
import NotchCore

/// The quick-notes scratchpad. Saves a moment after you stop typing.
@MainActor
final class NotesService: ObservableObject {
    @Published var text: String = "" {
        didSet { scheduleSave() }
    }

    private let file: LocalFile<Scratchpad>
    private var saveTask: Task<Void, Never>?
    private var loading = false

    init(fileURL: URL) {
        file = LocalFile(url: fileURL)
    }

    func start() {
        loading = true
        text = file.load()?.text ?? ""
        loading = false
    }

    var wordCount: Int { Scratchpad(text: text).wordCount }

    /// Writes any pending change now (e.g. when the notch closes).
    func flush() {
        guard saveTask != nil else { return }
        saveTask?.cancel()
        saveTask = nil
        file.save(Scratchpad(text: text, updatedAt: Date()))
    }

    private func scheduleSave() {
        guard !loading else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self.saveTask = nil
            self.file.save(Scratchpad(text: self.text, updatedAt: Date()))
        }
    }
}

@MainActor
final class TodoService: ObservableObject {
    @Published private(set) var list = TodoList()

    private let file: LocalFile<TodoList>

    init(fileURL: URL) {
        file = LocalFile(url: fileURL)
    }

    func start() {
        list = file.load() ?? TodoList()
    }

    func add(_ title: String) {
        guard list.add(title, at: Date()) != nil else { return }
        file.save(list)
    }

    func toggle(_ item: TodoItem) {
        list.toggle(item.id, at: Date())
        file.save(list)
    }

    func remove(_ item: TodoItem) {
        list.remove(item.id)
        file.save(list)
    }

    func clearCompleted() {
        list.clearCompleted()
        file.save(list)
    }
}
