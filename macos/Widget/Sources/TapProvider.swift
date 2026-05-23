import WidgetKit
import TapShared

/// Single timeline entry shared by both widgets. Both read the same
/// `SharedTapState` snapshot — they just render different subsets.
struct TapEntry: TimelineEntry {
    let date: Date
    let state: SharedTapState

    /// True when the host hasn't written a snapshot in >5 minutes —
    /// drives the "stale" tag in the widget chrome.
    var isStale: Bool {
        guard let lastSync = state.lastSyncedAt else { return false }
        return Date().timeIntervalSince(lastSync) > 300
    }
}

/// Provider shared between both widgets. Reads the App-Group
/// snapshot, returns one entry, asks WidgetKit to refresh on a 5-min
/// heartbeat. Host writes trigger `WidgetCenter.reloadAllTimelines()`
/// in `TapStateStore.write`, so the heartbeat is just a safety net.
struct TapProvider: TimelineProvider {
    func placeholder(in context: Context) -> TapEntry {
        TapEntry(date: .now, state: .placeholder)
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (TapEntry) -> Void) {
        let state = TapStateStore.read() ?? .placeholder
        completion(TapEntry(date: .now, state: state))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<TapEntry>) -> Void)
    {
        let state = TapStateStore.read() ?? .placeholder
        let entry = TapEntry(date: .now, state: state)
        let next = Date().addingTimeInterval(300)  // 5 min heartbeat
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
