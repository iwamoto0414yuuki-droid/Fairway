import SwiftUI

@main
struct FairwayWatchApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let mode = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--preview-") }) { WatchPreview(mode: mode) }
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
    let mode: String
    init(mode: String) {
        self.mode = mode
        let sample = Store(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("preview.json"), connectivity: false)
        var round = Round(course: "サンプルコース", count: 18)
        round.holes[0].green.value = Coordinate(latitude: 35.6, longitude: 140.1)
        round.holes[0].score.value = Score(strokes: 5, putts: 2, clubs: [.driver, .iron7, .sw, .putter, .putter])
        round.holes[9].score.value = Score(strokes: 4, putts: nil)
        sample.commit(round)
        self.round = round; _store = StateObject(wrappedValue: sample)
    }
    var body: some View {
        NavigationStack {
            if mode == "--preview-clubs" {
                ClubEditor(clubs: .constant([.driver, .iron7, .sw, .putter, .putter] + Array<Club?>(repeating: nil, count: 25)), strokes: 5)
            } else if mode == "--preview-summary" {
                List {
                    SummaryRow(title: "前半（1〜9H）", summary: round.frontSummary)
                    if let back = round.backSummary { SummaryRow(title: "後半（10〜18H）", summary: back) }
                    SummaryRow(title: "全体", summary: round.summary)
                }.navigationTitle("スコア集計")
            } else { ScoreEntry(id: round.id, holeIndex: 0, initial: round.holes[0]) }
        }
            .environmentObject(store).tint(fairwayGreen).preferredColorScheme(.dark)
    }
}
#endif
