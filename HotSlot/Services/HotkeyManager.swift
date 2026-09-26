import Foundation
import KeyboardShortcuts

/// Escucha atajos globales. Los listeners viven todo el proceso (`events`, no `onKeyUp`).
@MainActor
final class HotkeyManager {
    var onTogglePanel: (() -> Void)?
    var onPasteSlot: ((Int) -> Void)?
    var onCopyToSlot: ((Int) -> Void)?

    private var listenTask: Task<Void, Never>?

    func registerAll() {
        listenTask?.cancel()
        listenTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    await Self.listenKeyUp(for: .togglePanel) {
                        self?.onTogglePanel?()
                    }
                }

                for (offset, name) in KeyboardShortcuts.Name.pasteSlotNames.enumerated() {
                    let index = offset + 1
                    group.addTask { [weak self] in
                        await Self.listenKeyUp(for: name) {
                            self?.onPasteSlot?(index)
                        }
                    }
                }

                for (offset, name) in KeyboardShortcuts.Name.copyToSlotNames.enumerated() {
                    let index = offset + 1
                    group.addTask { [weak self] in
                        await Self.listenKeyUp(for: name) {
                            self?.onCopyToSlot?(index)
                        }
                    }
                }
            }
        }
    }

    /// Carbon vuelve a leer UserDefaults. No recrea los listeners.
    func applyStoredShortcuts() {
        KeyboardShortcuts.enable(KeyboardShortcuts.Name.allShortcutNames)
    }

    private static func listenKeyUp(
        for name: KeyboardShortcuts.Name,
        handle: @escaping @MainActor () -> Void
    ) async {
        for await event in KeyboardShortcuts.events(for: name) {
            guard !Task.isCancelled else { return }
            guard event == .keyUp else { continue }
            await MainActor.run {
                handle()
            }
        }
    }
}
