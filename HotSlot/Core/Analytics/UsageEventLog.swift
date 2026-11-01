import Foundation

/// Registro local de eventos para la prueba de usabilidad (`prueba-de-usabilidad.md`).
@MainActor
final class UsageEventLog {
    static let shared = UsageEventLog()

    struct Event: Codable, Sendable {
        var timestamp: Date
        var name: String
        var screen: String?
        var detail: String?
    }

    private(set) var events: [Event] = []
    private let maxEvents = 5_000

    private init() {
        load()
    }

    func record(_ name: String, screen: String? = nil, detail: String? = nil) {
        events.append(Event(timestamp: Date(), name: name, screen: screen, detail: detail))
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        save()
    }

    func exportCSV() -> URL? {
        let url = AppSupportDirectory.root.appendingPathComponent("usage-events-export.csv")
        var lines = ["timestamp,event,screen,detail"]
        let formatter = ISO8601DateFormatter()
        for event in events {
            let fields = [
                formatter.string(from: event.timestamp),
                csvEscape(event.name),
                csvEscape(event.screen ?? ""),
                csvEscape(event.detail ?? ""),
            ]
            lines.append(fields.joined(separator: ","))
        }
        guard let data = lines.joined(separator: "\n").data(using: .utf8) else { return nil }
        try? data.write(to: url, options: .atomic)
        return url
    }

    func clear() {
        events = []
        save()
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private var fileURL: URL { AppSupportDirectory.usageEventsFile }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Event].self, from: data) else { return }
        events = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
