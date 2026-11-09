import SwiftUI

let fairwayGreen = Color(red: 0.64, green: 0.91, blue: 0.39)

#if os(watchOS)
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
            TabView(selection: $selected) {
                ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                    ScoreEntry(id: id, holeIndex: index, initial: hole, showsHoleHint: true).tag(index)
                }
                ScrollView { ScoreCard(id: id) }.tag(round.holes.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .navigationTitle(selected == round.holes.count ? "スコア集計" : round.holeTitle(selected))
        }
    }
}
#endif

struct SavedRoundView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var confirmDelete = false
    var body: some View {
        if let round = store.round(id) {
            List {
                Section {
                    Text(round.courseTitle).font(.headline)
                    Text(round.date, style: .date)
                    ScoreCard(id: id)
                    #if os(iOS)
                    if !round.finished.value {
                        NavigationLink("続きから入力") { RoundView(id: id) }
                    }
                    #else
                    NavigationLink("続きから入力") { RoundView(id: id) }
                    #endif
                }
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("このラウンドを削除", systemImage: "trash").frame(minHeight: 44)
                    }
                }
                Section("ホールを選んで修正") {
                    ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                        NavigationLink { ScoreEntry(id: id, holeIndex: index, initial: hole).navigationTitle(round.holeTitle(index)) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(round.holeTitle(index))
                                Text(hole.score.value.map { "\($0.strokes)打・" + ($0.putts.map { "\($0)パット" } ?? "パット未記録") } ?? "未入力")
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

struct HoleHistoryDetail: View {
    @EnvironmentObject private var store: Store
    let id: UUID
    let holeIndex: Int

    var body: some View {
        if let round = store.round(id), round.holes.indices.contains(holeIndex) {
            List {
                if let score = round.holes[holeIndex].score.value {
                    Section("スコア") {
                        LabeledContent("打数", value: "\(score.strokes)")
                        LabeledContent("パット", value: score.putts.map(String.init) ?? "未記録")
                        LabeledContent("罰打", value: "\(score.penaltyStrokes)")
                    }
                    Section("打順・クラブ") {
                        if let clubs = score.clubs, clubs.contains(where: { $0 != nil }) {
                            ForEach(Array(clubs.enumerated()), id: \.offset) { index, club in
                                LabeledContent("\(index + 1)打目", value: clubLabel(club))
                            }
                        } else {
                            Text("クラブ未記録").foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("このホールは未入力です。").foregroundStyle(.secondary)
                }
            }
            .navigationTitle(round.holeTitle(holeIndex))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } else {
            Text("この記録は見つかりません。").foregroundStyle(.secondary)
        }
    }

    private func clubLabel(_ club: Club?) -> String {
        guard let club else { return "未記録" }
        #if os(watchOS)
        return club.shortName
        #else
        return club.title
        #endif
    }
}

struct ScoreCard: View {
    @EnvironmentObject var store: Store
    let id: UUID
    var body: some View {
        if let round = store.round(id) {
            VStack(alignment: .leading, spacing: 10) {
                if round.holes.count == 18 {
                    let frontTitle = round.courses.map { "前半 \($0.value.front.rawValue)" } ?? "前半 1〜9H"
                    let backTitle = round.courses.map { "後半 \($0.value.back.rawValue)" } ?? "後半 10〜18H"
                    SummaryRow(title: frontTitle, summary: round.frontSummary)
                    if let back = round.backSummary { SummaryRow(title: backTitle, summary: back) }
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
            Text("\(summary.strokesText) · \(summary.puttsLabel)").monospacedDigit()
            if summary.penalties > 0 {
                Text("うち罰打 \(summary.penalties)").font(.caption2).foregroundStyle(.secondary)
            }
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
            VStack(spacing: entrySpacing) {
                #if os(iOS)
                if let round = store.round(id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(round.courseTitle).font(.headline)
                        Text("\(holeIndex + 1) / \(round.holes.count)ホール")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                #endif
                counterRow("打数", value: draft.strokes,
                    minusLabel: "打数を1減らす", plusLabel: "打数を1増やす",
                    minusDisabled: draft.regularStrokes == 0, plusDisabled: draft.strokes >= 30,
                    minus: { edit { $0.changeStroke(-1) } }, plus: { edit { $0.changeStroke(1) } })
                counterRow("うちパット", value: draft.putts,
                    minusLabel: "パットを1減らす", plusLabel: "パットを1増やす。打数も1増えます",
                    minusDisabled: draft.putts == 0, plusDisabled: draft.strokes >= 30,
                    minus: { edit { $0.changePutt(-1) } }, plus: { edit { $0.changePutt(1, markClub: true) } })
                counterRow("うち罰打", value: draft.penalties,
                    minusLabel: "罰打を1減らす", plusLabel: "罰打を1増やす。打数も1増えます",
                    minusDisabled: draft.penalties == 0, plusDisabled: draft.strokes >= 30,
                    minus: { edit { $0.changePenalty(-1) } }, plus: { edit { $0.changePenalty(1) } })
                NavigationLink {
                    ClubEditor(clubs: Binding(get: { draft.clubs }, set: { clubs in edit { $0.clubs = clubs } }), strokes: draft.strokes)
                } label: {
                    HStack { Text("クラブを記録"); Text("任意").font(.caption2).foregroundStyle(.secondary) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .background(Color(white: 0.18), in: RoundedRectangle(cornerRadius: 10))
                .disabled(draft.strokes == 0).opacity(draft.strokes == 0 ? 0.45 : 1)
                Text("パットと罰打は打数にも反映されます")
                    .font(.caption2).foregroundStyle(.secondary)
                if showsHoleHint { Text("左右にスワイプでホール移動").font(.caption2).foregroundStyle(.secondary) }
                if draft.strokes > 0 {
                    Button("このホールを未入力に戻す", role: .destructive) { confirmReset = true }
                        .font(.caption).frame(minHeight: 44)
                }
            }.padding(.horizontal, entryPadding).padding(.vertical, 8)
        }
        .confirmationDialog("このホールの記録を消しますか？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("未入力に戻す", role: .destructive) { edit { $0 = CounterDraft(score: nil) } }
            Button("キャンセル", role: .cancel) { }
        } message: { Text("このホールの打数・パット・罰打・クラブ記録を消します。") }
        #if os(iOS)
        .navigationTitle(store.round(id)?.holeTitle(holeIndex) ?? "\(holeIndex + 1)ホール")
        #endif
        .onDisappear { sync() }
        .onChange(of: scenePhase) { phase in if phase == .background { sync() } }
        .onChange(of: store.round(id)?.holes[holeIndex].score.revision) { revision in
            if let round = store.round(id), revision != expected {
                draft = CounterDraft(score: round.holes[holeIndex].score.value)
                expected = round.holes[holeIndex].score.revision
            }
        }
    }
    private var entrySpacing: CGFloat {
        #if os(iOS)
        return 12
        #else
        return 4
        #endif
    }
    private var entryPadding: CGFloat {
        #if os(iOS)
        return 16
        #else
        return 2
        #endif
    }
    private func counterRow(_ title: String, value: Int, minusLabel: String, plusLabel: String,
                            minusDisabled: Bool, plusDisabled: Bool,
                            minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption).lineLimit(1).minimumScaleFactor(0.8)
                Text("\(value)").font(.system(size: counterNumberSize, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
            }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
            counterButton("−", label: minusLabel, disabled: minusDisabled, action: minus)
            counterButton("＋", label: plusLabel, disabled: plusDisabled, action: plus)
        }
        #if os(iOS)
        .padding(12)
        .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 14))
        #else
        .frame(minHeight: 44)
        #endif
    }
    private var counterNumberSize: CGFloat {
        #if os(watchOS)
        return 28
        #else
        return 48
        #endif
    }
    private var buttonSize: CGFloat {
        #if os(iOS)
        return 54
        #else
        return 44
        #endif
    }
    private func counterButton(_ text: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(text).font(.title3).bold().frame(width: buttonSize, height: buttonSize) }
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
