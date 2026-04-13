import AppIntents
import WidgetKit

// MARK: - Server entity for widget configuration

struct ServerAppEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Server")
    static var defaultQuery = ServerEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    /// Special "All Servers" entity for fleet-wide view
    static let allServers = ServerAppEntity(id: "__all__", name: "All Servers")
}

// MARK: - Query that reads available servers from shared UserDefaults

struct ServerEntityQuery: EntityQuery {
    private let defaults = UserDefaults(suiteName: "group.com.mattssoftware.tap.watchkitapp")

    func entities(for identifiers: [String]) async throws -> [ServerAppEntity] {
        let all = loadServers()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ServerAppEntity] {
        return loadServers()
    }

    func defaultResult() async -> ServerAppEntity? {
        return ServerAppEntity.allServers
    }

    private func loadServers() -> [ServerAppEntity] {
        var results = [ServerAppEntity.allServers]

        guard let defaults,
              let data = defaults.data(forKey: "widget_overviews"),
              let overviews = try? JSONDecoder().decode([WidgetOverview].self, from: data) else {
            return results
        }

        for o in overviews {
            results.append(ServerAppEntity(id: o.serverId, name: o.serverName))
        }

        return results
    }
}

// MARK: - Metric type for Fleet Metrics widget

enum MetricType: String, AppEnum {
    case disk = "disk"
    case memory = "memory"
    case cpu = "cpu"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Metric")

    static var caseDisplayRepresentations: [MetricType: DisplayRepresentation] = [
        .disk: "Disk Usage",
        .memory: "Memory Usage",
        .cpu: "CPU Load",
    ]
}
