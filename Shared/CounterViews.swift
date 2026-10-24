import SwiftUI

let fairwayGreen = Color(red: 0.64, green: 0.91, blue: 0.39)

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var activeRound: UUID?
    var body: some View {
        NavigationStack {
            List {
                Section("ラウンドをはじめる") {
                    Button("18ホール") { activeRound = store.create(course: "ラウンド", count: 18) }
                    Button("9ホール") { activeRound = store.create(course: "ラウンド", count: 9) }
                }
                Section("保存したスコア") {
                    ForEach(store.library.rounds) { round in
                        NavigationLink { RoundView(id: round.id) } label: {
                            VStack(alignment: .leading) {
                                Text(round.date, style: .date)
                                Text("\(round.total)打 · \(round.summary.putts)パット · \(round.played)/\(round.holes.count)H")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fairway")
            .navigationDestination(isPresented: Binding(get: { activeRound != nil }, set: { if !$0 { activeRound = nil } })) {
                if let id = activeRound { RoundView(id: id) }
            }
        }
        .tint(fairwayGreen).preferredColorScheme(.dark)
        .alert("保存を確認してください", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

struct RoundView: View {
    @EnvironmentObject var store: Store
    let id: UUID
    @State private var selected = 0
    var body: some View {
        if let round = store.round(id) {
            #if os(watchOS)
            TabView(selection: $selected) {
                ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                    ScoreEntry(id: id, holeIndex: index, initial: hole).tag(index)
                }
                ScrollView { ScoreCard(id: id) }.tag(round.holes.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .navigationTitle(selected == round.holes.count ? "スコア集計" : "\(selected < 9 ? "OUT" : "IN") \(selected % 9 + 1) / Total \(round.total)")
            #else
            List {
                Section { ScoreCard(id: id) }
                Section("ホールごとの記録") {
                    ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                        NavigationLink { ScoreEntry(id: id, holeIndex: index, initial: hole) } label: {
                            HStack {
                                Text("\(hole.id)H")
                                Spacer()
                                Text(hole.score.value.map { "\($0.strokes)打 · \($0.putts ?? 0)パット" } ?? "未記録")
                            }
                        }
                    }
                }
            }.navigationTitle("スコアカード")
            #endif
        }
    }
}

struct ScoreCard: View {
    @EnvironmentObject var store: Store
    let id: UUID
    var body: some View {
        if let round = store.round(id) {
            VStack(alignment: .leading, spacing: 10) {
                if round.holes.count == 18 {
                    SummaryRow(title: "前半 1〜9H", summary: round.frontSummary)
                    if let back = round.backSummary { SummaryRow(title: "後半 10〜18H", summary: back) }
                }
                SummaryRow(title: "合計", summary: round.summary)
                Text("\(round.played)/\(round.holes.count)H 入力済み").font(.caption2).foregroundStyle(.secondary)
            }.padding(.vertical, 6)
        }
    }
}

struct SummaryRow: View {
    let title: String
    let summary: ScoreSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(summary.strokesText) · \(summary.puttsText)パット").monospacedDigit()
        }
    }
}

struct ScoreEntry: View {
    @EnvironmentObject var store: Store
    @Environment(\.scenePhase) private var scenePhase
    let id: UUID
    let holeIndex: Int
    @State private var draft: CounterDraft
    @State private var expected: Revision
    @State private var pendingSync = false
    init(id: UUID, holeIndex: Int, initial: Hole) {
        self.id = id; self.holeIndex = holeIndex
        _draft = State(initialValue: CounterDraft(score: initial.score.value))
        _expected = State(initialValue: initial.score.revision)
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    counterButton("−", label: "打数を1減らす", disabled: draft.strokes == 0) { edit { $0.changeStroke(-1) } }
                    counterButton("−", label: "パットを1減らす", disabled: draft.putts == 0) { edit { $0.changePutt(-1) } }
                        .frame(width: geometry.size.width * 0.29)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(draft.strokes)").font(.system(size: min(geometry.size.height * 0.44, 100), weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity).accessibilityLabel("打数 \(draft.strokes)")
                    Text("\(draft.putts)").font(.system(size: min(geometry.size.height * 0.28, 62), weight: .medium, design: .rounded))
                        .frame(width: geometry.size.width * 0.29).accessibilityLabel("パット数 \(draft.putts)")
                }.monospacedDigit().minimumScaleFactor(0.6).frame(maxHeight: .infinity)
                HStack(spacing: 5) {
                    counterButton("＋", label: "打数を1増やす", disabled: draft.strokes >= 30) { edit { $0.changeStroke(1) } }
                    counterButton("＋", label: "パットを1増やす（打数も増えます）", disabled: draft.strokes >= 30) { edit { $0.changePutt(1) } }
                        .frame(width: geometry.size.width * 0.29)
                }
                NavigationLink {
                    ClubEditor(clubs: Binding(get: { draft.clubs }, set: { clubs in edit { $0.clubs = clubs } }), strokes: draft.strokes)
                } label: { Text("クラブ（任意）").font(.caption2) }
                .disabled(draft.strokes == 0)
            }
            .padding(.bottom, 15)
        }
        #if os(iOS)
        .frame(minHeight: 360, maxHeight: 470).padding()
        .navigationTitle("\(holeIndex + 1)H")
        #endif
        .onDisappear { sync() }
        .onChange(of: scenePhase) { phase in if phase != .active { sync() } }
        .onChange(of: store.round(id)?.holes[holeIndex].score.revision) { revision in
            if let round = store.round(id), revision != expected {
                draft = CounterDraft(score: round.holes[holeIndex].score.value)
                expected = round.holes[holeIndex].score.revision
            }
        }
    }
    private func counterButton(_ text: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(text).font(.title2).bold().frame(maxWidth: .infinity, minHeight: 36) }
            .buttonStyle(.plain).background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 9))
            .disabled(disabled).opacity(disabled ? 0.4 : 1).accessibilityLabel(label)
    }
    private func edit(_ change: (inout CounterDraft) -> Void) {
        var next = draft; change(&next)
        guard next != draft else { return }
        // Every tap is saved locally; radio transfers are batched when leaving the hole/app.
        if store.saveScore(id, hole: holeIndex, score: next.score, expected: expected, send: false), let round = store.round(id) {
            draft = next; expected = round.holes[holeIndex].score.revision
            pendingSync = true
        }
    }
    private func sync() {
        if pendingSync { store.resend(id); pendingSync = false }
    }
}
