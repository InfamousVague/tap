import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared data model (must match what the app writes)

struct WidgetOverview: Codable {
    let serverId: String
    let serverName: String
    let status: String
    let diskPercent: Int?
    let memPercent: Int?
    let load1: Double?
    let uptime: String?
    let dockerRunning: Int?
    let dockerTotal: Int?

    var isUp: Bool { status == "up" }
}

// MARK: - Configuration Intent

struct FleetMetricsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Fleet Metrics"
    static var description = IntentDescription("View disk, memory, or CPU metrics for a server or your whole fleet.")

    @Parameter(title: "Server")
    var server: ServerAppEntity?

    @Parameter(title: "Metric", default: .disk)
    var metric: MetricType
}

// MARK: - Fleet Metrics Widget

struct FleetMetricsProvider: AppIntentTimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.mattssoftware.tap.watchkitapp")

    func placeholder(in context: Context) -> FleetMetricsEntry {
        FleetMetricsEntry(date: .now, metric: .disk, serverName: nil, value: 45, overviews: [
            WidgetOverview(serverId: "1", serverName: "prod", status: "up", diskPercent: 45, memPercent: 62, load1: 0.8, uptime: "45 days", dockerRunning: 5, dockerTotal: 5),
        ])
    }

    func snapshot(for configuration: FleetMetricsIntent, in context: Context) async -> FleetMetricsEntry {
        readEntry(for: configuration)
    }

    func timeline(for configuration: FleetMetricsIntent, in context: Context) async -> Timeline<FleetMetricsEntry> {
        let entry = readEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    func recommendations() -> [AppIntentRecommendation<FleetMetricsIntent>] {
        var recs: [AppIntentRecommendation<FleetMetricsIntent>] = []

        for metric in [MetricType.disk, .memory, .cpu] {
            let intent = FleetMetricsIntent()
            intent.metric = metric
            recs.append(AppIntentRecommendation(intent: intent, description: "Fleet \(metric.rawValue.capitalized)"))
        }

        if let defaults,
           let data = defaults.data(forKey: "widget_overviews"),
           let overviews = try? JSONDecoder().decode([WidgetOverview].self, from: data) {
            for o in overviews {
                let intent = FleetMetricsIntent()
                intent.server = ServerAppEntity(id: o.serverId, name: o.serverName)
                intent.metric = .disk
                recs.append(AppIntentRecommendation(intent: intent, description: "\(o.serverName) Disk"))
            }
        }

        return recs
    }

    private func readEntry(for config: FleetMetricsIntent) -> FleetMetricsEntry {
        guard let defaults,
              let data = defaults.data(forKey: "widget_overviews"),
              let overviews = try? JSONDecoder().decode([WidgetOverview].self, from: data) else {
            return FleetMetricsEntry(date: .now, metric: config.metric, serverName: nil, value: nil, overviews: [])
        }

        let metric = config.metric
        let selectedServer = config.server
        let isAll = selectedServer == nil || selectedServer?.id == "__all__"
        let filtered = isAll ? overviews : overviews.filter { $0.serverId == selectedServer?.id }
        let serverName: String? = isAll ? nil : selectedServer?.name

        let value: Double? = {
            switch metric {
            case .disk:
                let vals = filtered.compactMap(\.diskPercent)
                guard !vals.isEmpty else { return nil }
                return isAll ? Double(vals.max()!) : Double(vals[0])
            case .memory:
                let vals = filtered.compactMap(\.memPercent)
                guard !vals.isEmpty else { return nil }
                return isAll ? Double(vals.max()!) : Double(vals[0])
            case .cpu:
                let vals = filtered.compactMap(\.load1)
                guard !vals.isEmpty else { return nil }
                return isAll ? vals.max()! : vals[0]
            }
        }()

        return FleetMetricsEntry(date: .now, metric: metric, serverName: serverName, value: value, overviews: filtered)
    }
}

struct FleetMetricsEntry: TimelineEntry {
    let date: Date
    let metric: MetricType
    let serverName: String?  // nil = all servers
    let value: Double?
    let overviews: [WidgetOverview]

    var worstDisk: Int? { overviews.compactMap(\.diskPercent).max() }
    var worstMem: Int? { overviews.compactMap(\.memPercent).max() }
    var worstLoad: Double? { overviews.compactMap(\.load1).max() }
    var avgDisk: Int? {
        let vals = overviews.compactMap(\.diskPercent)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / vals.count
    }
    var avgMem: Int? {
        let vals = overviews.compactMap(\.memPercent)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / vals.count
    }
}

struct FleetMetricsWidget: Widget {
    let kind = "FleetMetricsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FleetMetricsIntent.self, provider: FleetMetricsProvider()) { entry in
            FleetMetricsWidgetView(entry: entry)
        }
        .configurationDisplayName("Fleet Metrics")
        .description("Disk, memory & CPU for a server or your fleet.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
        ])
    }
}

struct FleetMetricsWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: FleetMetricsEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .accessoryCorner:
                cornerView
            default:
                circularView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Circular: gauge for selected metric

    private var circularView: some View {
        Gauge(value: gaugeValue, in: 0...gaugeMax) {
            Image(systemName: metricIcon)
                .font(.system(size: 8))
        } currentValueLabel: {
            Text(gaugeLabel)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(gaugeGradient)
    }

    // MARK: - Rectangular: metric bars or single server detail

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: metricIcon)
                    .font(.system(size: 9))
                Text(headerLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }

            if entry.overviews.isEmpty {
                Text("Open Tap to sync")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                switch entry.metric {
                case .disk:
                    MetricBarRow(icon: "internaldrive", label: "Disk", value: entry.serverName != nil ? Int(entry.value ?? 0) : (entry.avgDisk ?? 0))
                    MetricBarRow(icon: "memorychip", label: "Mem", value: entry.avgMem ?? 0)
                    if let load = entry.worstLoad {
                        loadRow(load)
                    }
                case .memory:
                    MetricBarRow(icon: "memorychip", label: "Mem", value: entry.serverName != nil ? Int(entry.value ?? 0) : (entry.avgMem ?? 0))
                    MetricBarRow(icon: "internaldrive", label: "Disk", value: entry.avgDisk ?? 0)
                    if let load = entry.worstLoad {
                        loadRow(load)
                    }
                case .cpu:
                    if let load = entry.value {
                        loadRow(load)
                    }
                    MetricBarRow(icon: "internaldrive", label: "Disk", value: entry.avgDisk ?? 0)
                    MetricBarRow(icon: "memorychip", label: "Mem", value: entry.avgMem ?? 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadRow(_ load: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.system(size: 8))
                .frame(width: 12)
            Text(String(format: "%.1f", load))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(load < 1 ? .green : load < 2 ? .orange : .red)
        }
    }

    // MARK: - Corner: metric gauge

    private var cornerView: some View {
        Image(systemName: metricIcon)
            .font(.system(size: 20))
            .foregroundStyle(cornerColor)
            .widgetLabel {
                Gauge(value: gaugeValue, in: 0...gaugeMax) {
                    Text(metricShortLabel)
                } currentValueLabel: {
                    Text(gaugeLabel)
                }
                .tint(gaugeGradient)
            }
    }

    // MARK: - Helpers

    private var metricIcon: String {
        switch entry.metric {
        case .disk: return "internaldrive"
        case .memory: return "memorychip"
        case .cpu: return "cpu"
        }
    }

    private var metricShortLabel: String {
        switch entry.metric {
        case .disk: return "Disk"
        case .memory: return "Mem"
        case .cpu: return "CPU"
        }
    }

    private var headerLabel: String {
        if let name = entry.serverName {
            return "\(name) \(metricShortLabel)"
        }
        return "Fleet \(metricShortLabel)"
    }

    private var gaugeValue: Double {
        switch entry.metric {
        case .disk, .memory:
            return entry.value ?? 0
        case .cpu:
            return min((entry.value ?? 0) / 4.0, 1.0) * 100
        }
    }

    private var gaugeMax: Double {
        return 100
    }

    private var gaugeLabel: String {
        switch entry.metric {
        case .disk, .memory:
            return "\(Int(entry.value ?? 0))%"
        case .cpu:
            return String(format: "%.1f", entry.value ?? 0)
        }
    }

    private var gaugeGradient: Gradient {
        switch entry.metric {
        case .disk, .memory:
            return Gradient(colors: [.green, .orange, .red])
        case .cpu:
            return Gradient(colors: [.green, .orange, .red])
        }
    }

    private var cornerColor: Color {
        let v = Int(entry.value ?? 0)
        switch entry.metric {
        case .disk, .memory:
            if v < 70 { return .green }
            if v < 85 { return .orange }
            return .red
        case .cpu:
            let load = entry.value ?? 0
            if load < 1 { return .green }
            if load < 2 { return .orange }
            return .red
        }
    }
}

// MARK: - Metric bar row for rectangular

struct MetricBarRow: View {
    let icon: String
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .frame(width: 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)

                    Capsule()
                        .fill(colorForPercent(value))
                        .frame(width: max(geo.size.width * CGFloat(value) / 100.0, 2), height: 6)
                }
            }
            .frame(height: 6)

            Text("\(value)%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(colorForPercent(value))
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func colorForPercent(_ p: Int) -> Color {
        if p < 70 { return .green }
        if p < 85 { return .orange }
        return .red
    }
}
