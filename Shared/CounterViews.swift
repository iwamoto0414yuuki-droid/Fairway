import SwiftUI

let fairwayGreen = Color(red: 0.64, green: 0.91, blue: 0.39)

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var activeRound: UUID?
    var body: some View {
        NavigationStack {
            List {
                Section("ラウンドをはじめる") {
                    Button("18ホールで開始") { activeRound = store.create(course: "ラウンド", count: 18) }
                    Button("9ホールで開始") { activeRound = store.create(course: "ラウンド", count: 9) }
                }
                Section("保存したスコア") {
                    if store.library.visibleRounds.isEmpty { Text("まだ記録がありません").foregroundStyle(.secondary) }
                    ForEach(store.library.visibleRounds) { round in
                        NavigationLink { SavedRoundView(id: round.id) } label: {
                            VStack(alignment: .leading) {
                                Text(round.date, style: .date)
                                Text("\(round.total)打 · \(round.summary.putts)パット · \(round.played)/\(round.holes.count)H")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("見る・修正・削除").font(.caption2).foregroundStyle(fairwayGreen)
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
    @AppStorage private var selected: Int
    init(id: UUID) {
        self.id = id
        _selected = AppStorage(wrappedValue: 0, "FairwaySelectedHole-" + id.uuidString)
    }
    var body: some View {
        if let round = store.round(id) {
            #if os(watchOS)
            TabView(selection: $selected) {
                ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                    ScoreEntry(id: id, holeIndex: index, initial: hole, showsHoleHint: true).tag(index)
                }
                ScrollView { ScoreCard(id: id) }.tag(round.holes.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .navigationTitle(selected == round.holes.count ? "スコア集計" : "\(selected + 1)ホール")
            #else
            List {
                Section { ScoreCard(id: id) }
                Section("ホールごとの記録") {
                    ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                        NavigationLink { ScoreEntry(id: id, holeIndex: index, initial: hole).navigationTitle("\(index + 1)ホール") } label: {
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

struct SavedRoundView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var confirmDelete = false
    var body: some View {
        if let round = store.round(id) {
            List {
                Section {
                    Text(round.date, style: .date)
                    ScoreCard(id: id)
                    NavigationLink("続きから入力") { RoundView(id: id) }
                }
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("このラウンドを削除", systemImage: "trash").frame(minHeight: 44)
                    }
                }
                Section("ホールを選んで修正") {
                    ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                        NavigationLink { ScoreEntry(id: id, holeIndex: index, initial: hole).navigationTitle("\(index + 1)ホール") } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(index + 1)ホール")
                                Text(hole.score.value.map { "\($0.strokes)打・\($0.putts ?? 0)パット" } ?? "未入力")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.frame(minHeight: 44)
                        }
                    }
                }
            }
            .navigationTitle("保存したスコア")
            .alert("このラウンドを削除しますか？", isPresented: $confirmDelete) {
                Button("削除する", role: .destructive) { if store.delete(id) { dismiss() } }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("\(round.date.formatted(date: .numeric, time: .omitted))の全ホールの記録を削除します。接続後、もう一方の端末にも反映されます。")
            }
        } else {
            VStack { Text("この記録は削除されました"); Button("一覧に戻る") { dismiss() } }
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
    let showsHoleHint: Bool
    @State private var draft: CounterDraft
    @State private var expected: Revision
    @State private var pendingSync = false
    @State private var confirmReset = false
    init(id: UUID, holeIndex: Int, initial: Hole, showsHoleHint: Bool = false) {
        self.id = id; self.holeIndex = holeIndex; self.showsHoleHint = showsHoleHint
        _draft = State(initialValue: CounterDraft(score: initial.score.value))
        _expected = State(initialValue: initial.score.revision)
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                counterRow("打数", value: draft.strokes,
                    minusLabel: "打数を1減らす", plusLabel: "打数を1増やす",
                    minusDisabled: draft.strokes == 0, plusDisabled: draft.strokes >= 30,
                    minus: { edit { $0.changeStroke(-1) } }, plus: { edit { $0.changeStroke(1) } })
                counterRow("うちパット", value: draft.putts,
                    minusLabel: "パットを1減らす", plusLabel: "パットを1増やす。打数も1増えます",
                    minusDisabled: draft.putts == 0, plusDisabled: draft.strokes >= 30,
                    minus: { edit { $0.changePutt(-1) } }, plus: { edit { $0.changePutt(1) } })
                NavigationLink {
                    ClubEditor(clubs: Binding(get: { draft.clubs }, set: { clubs in edit { $0.clubs = clubs } }), strokes: draft.strokes)
                } label: {
                    HStack { Text("クラブを記録"); Text("任意").font(.caption2).foregroundStyle(.secondary) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .background(Color(white: 0.18), in: RoundedRectangle(cornerRadius: 10))
                .disabled(draft.strokes == 0).opacity(draft.strokes == 0 ? 0.45 : 1)
                Text(draft.strokes == 0 ? "まず打数の＋を押してください" : "パット＋で打数も＋1")
                    .font(.caption2).foregroundStyle(.secondary)
                if showsHoleHint { Text("左右にスワイプでホール移動").font(.caption2).foregroundStyle(.secondary) }
                if draft.strokes > 0 {
                    Button("このホールを未入力に戻す", role: .destructive) { confirmReset = true }
                        .font(.caption).frame(minHeight: 44)
                }
            }.padding(.horizontal, 2)
        }
        .confirmationDialog("このホールの記録を消しますか？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("未入力に戻す", role: .destructive) { edit { $0 = CounterDraft(score: nil) } }
            Button("キャンセル", role: .cancel) { }
        } message: { Text("このホールの打数・パット・クラブ記録を消します。") }
        #if os(iOS)
        .frame(minHeight: 360, maxHeight: 470).padding()
        .navigationTitle("\(holeIndex + 1)ホール")
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
    private func counterRow(_ title: String, value: Int, minusLabel: String, plusLabel: String,
                            minusDisabled: Bool, plusDisabled: Bool,
                            minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.8)
                Text("\(value)").font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
            }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
            counterButton("−", label: minusLabel, disabled: minusDisabled, action: minus)
            counterButton("＋", label: plusLabel, disabled: plusDisabled, action: plus)
        }.frame(minHeight: 50)
    }
    private func counterButton(_ text: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(text).font(.title3).bold().frame(width: 44, height: 44) }
            .buttonStyle(.plain).foregroundStyle(text == "＋" ? Color.black : Color.white)
            .background(text == "＋" ? fairwayGreen : Color(white: 0.18), in: RoundedRectangle(cornerRadius: 10))
            .disabled(disabled).opacity(disabled ? 0.35 : 1).accessibilityLabel(label)
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
