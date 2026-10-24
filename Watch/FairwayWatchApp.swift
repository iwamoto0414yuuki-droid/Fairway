import SwiftUI

@main
struct FairwayWatchApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-score") { WatchPreview() }
            else { HomeView().environmentObject(store) }
            #else
            HomeView().environmentObject(store)
            #endif
        }
    }
}

#if DEBUG
private struct WatchPreview: View {
    @StateObject private var store: Store
    let round: Round
    init() {
        let sample = Store(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("preview.json"), connectivity: false)
        var round = Round(course: "サンプルコース", count: 18)
        round.holes[0].green.value = Coordinate(latitude: 35.6, longitude: 140.1)
        sample.commit(round)
        self.round = round; _store = StateObject(wrappedValue: sample)
    }
    var body: some View {
        NavigationStack { ScoreEntry(id: round.id, holeIndex: 0, initial: round.holes[0]) }
            .environmentObject(store).tint(fairwayGreen).preferredColorScheme(.dark)
    }
}
#endif
