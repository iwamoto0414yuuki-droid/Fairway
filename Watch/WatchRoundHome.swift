import SwiftUI

struct WatchRoundHome: View {
    @EnvironmentObject private var store: Store
    @AppStorage("FairwayWatchActiveRound") private var activeRoundID = ""
    @AppStorage("FairwayWatchActiveHole") private var activeHole = 0
    @AppStorage("FairwayWatchAutomaticClubChoice") private var automaticClubChoice = true
    @State private var showMenu = false
    @State private var choosingCourse = false

    private var activeRound: Round? {
        guard let id = UUID(uuidString: activeRoundID), let round = store.round(id),
              !round.finished.value, round.holes.count == 18 else { return nil }
        return round
    }

    var body: some View {
        NavigationStack {
            if let round = activeRound, !showMenu {
                if activeHole == -1 {
                    WatchCoursePicker(initial: round.courses?.value, atBreak: true, automaticClubChoice: $automaticClubChoice) { selection in
                        if store.setCourses(round.id, selection: selection) { activeHole = 9 }
                    }
                } else {
                    let index = min(max(0, activeHole), 17)
                    WatchPlayHole(round: round, index: index, move: { activeHole = $0 },
                                  finishNine: { finish(round, at: index) },
                                  showMenu: { showMenu = true }, automaticClubChoice: automaticClubChoice)
                        .id(round.holes[index].id)
                }
            } else {
                List {
                    if activeRound != nil {
                        Button("ラウンドを再開") { showMenu = false }
                    } else {
                        Button("ラウンド開始") { choosingCourse = true }
                    }
                    NavigationLink("スコア修正") { WatchRoundList(editing: true) }
                    NavigationLink("ラウンド履歴") { WatchRoundList(editing: false) }
                }.navigationTitle("Fairway")
            }
        }
        .sheet(isPresented: $choosingCourse) {
            NavigationStack {
                WatchCoursePicker(initial: store.library.visibleRounds.compactMap { $0.courses?.value }.first,
                                  atBreak: false, automaticClubChoice: $automaticClubChoice) { selection in
                    if let id = store.create(course: selection.title, count: 18, courses: selection) {
                        activeHole = 0
                        activeRoundID = id.uuidString
                        choosingCourse = false
                        showMenu = false
                    }
                }
            }
        }
        .tint(fairwayGreen)
        .preferredColorScheme(.dark)
        .alert("保存を確認してください", isPresented: Binding(
            get: { store.error != nil }, set: { if !$0 { store.error = nil } }
        )) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
    }

    private func finish(_ round: Round, at index: Int) {
        if index == 8 {
            activeHole = -1
        } else if index == 17, store.finish(round.id, value: true) {
            activeRoundID = ""
            activeHole = 0
        }
    }
}

struct WatchCoursePicker: View {
    @State private var selection: CourseSelection
    let atBreak: Bool
    @Binding var automaticClubChoice: Bool
    let start: (CourseSelection) -> Void

    init(initial: CourseSelection?, atBreak: Bool, automaticClubChoice: Binding<Bool>, start: @escaping (CourseSelection) -> Void) {
        _selection = State(initialValue: initial ?? CourseSelection(front: .out, back: .inCourse))
        self.atBreak = atBreak
        _automaticClubChoice = automaticClubChoice
        self.start = start
    }

    var body: some View {
        List {
            if atBreak {
                LabeledContent("前半", value: selection.front.rawValue)
            } else {
                coursePicker("前半", selection: $selection.front)
            }
            coursePicker("後半", selection: $selection.back)
            Button(atBreak ? "後半を開始" : "前半を開始") { start(selection) }
                .tint(fairwayGreen)
            Toggle("クラブ選択を自動表示", isOn: $automaticClubChoice).font(.caption)
        }.navigationTitle(atBreak ? "前半終了" : "コース選択")
    }

    private func coursePicker(_ title: String, selection: Binding<CourseNine>) -> some View {
        Picker(title, selection: selection) {
            ForEach(CourseNine.allCases) { course in Text(course.rawValue).tag(course) }
        }
    }
}

private struct WatchRoundList: View {
    @EnvironmentObject private var store: Store
    let editing: Bool

    var body: some View {
        List {
            if store.library.visibleRounds.isEmpty {
                Text("まだ記録がありません").foregroundStyle(.secondary)
            }
            ForEach(store.library.visibleRounds) { round in
                NavigationLink {
                    if editing {
                        SavedRoundView(id: round.id)
                    } else {
                        List {
                            ScoreCard(id: round.id)
                            ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                                LabeledContent(round.holeTitle(index),
                                    value: hole.score.value.map { "\($0.strokes)打" } ?? "未入力")
                            }
                        }.navigationTitle(round.courseTitle)
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(round.courseTitle)
                        Text(round.date, style: .date).font(.caption2)
                        Text("\(round.total)打 · \(round.played)/\(round.holes.count)H")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle(editing ? "スコア修正" : "ラウンド履歴")
    }
}

struct WatchPlayHole: View {
    @EnvironmentObject private var store: Store
    @Environment(\.scenePhase) private var scenePhase
    let round: Round
    let index: Int
    let move: (Int) -> Void
    let finishNine: () -> Void
    let showMenu: () -> Void
    var automaticClubChoice = true
    private struct ClubTarget {
        let index: Int
        let revision: Revision
    }
    @State private var clubTarget: ClubTarget?
    @State private var pendingSync = false
    @State private var confirmFinish = false
    @State private var showCard = false

    private var hole: Hole { round.holes[index] }
    private var draft: CounterDraft { CounterDraft(score: hole.score.value) }
    private var lastHoleOfHalf: Bool { index == 8 || index == 17 }
    private var missingHoles: [Int] { round.unscoredHoles(through: index == 8 ? 8 : 17) }
    private var finishTitle: String { index == 8 ? "前半を終了" : "ラウンドを終了" }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 3) {
                    counter("打数", value: draft.strokes, size: 31,
                            canSubtract: draft.regularStrokes > 0,
                            minus: { edit { $0.changeStroke(-1) } },
                            plus: {
                                if edit({ $0.changeStroke(1) }), automaticClubChoice,
                                   let saved = store.round(round.id)?.holes[index].score,
                                   let score = saved.value {
                                    clubTarget = ClubTarget(index: score.strokes - 1, revision: saved.revision)
                                }
                            })
                    counter("パット", value: draft.putts, size: 24,
                            canSubtract: draft.putts > 0,
                            minus: { edit { $0.changePutt(-1) } },
                            plus: { edit { $0.changePutt(1, markClub: true) } })
                    counter("罰打", value: draft.penalties, size: 24,
                            canSubtract: draft.penalties > 0,
                            minus: { edit { $0.changePenalty(-1) } },
                            plus: { edit { $0.changePenalty(1) } })
                }
                HStack(spacing: 5) {
                    Button("前のホール") { move(index - 1) }.disabled(index % 9 == 0)
                    if lastHoleOfHalf {
                        Button(index == 8 ? "前半終了" : "終了") { confirmFinish = true }
                    } else {
                        Button("次のホール") { move(index + 1) }
                    }
                }.font(.caption2)
                Text("左右にスワイプでホール移動").font(.caption2).foregroundStyle(.secondary)
                Button("スコアカード") { showCard = true }.font(.caption)
                Button("メニュー", action: showMenu).font(.caption2)
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 28).onEnded { gesture in
            let horizontal = gesture.translation.width
            guard abs(horizontal) > abs(gesture.translation.height) * 2 else { return }
            if horizontal < 0 {
                if lastHoleOfHalf { confirmFinish = true }
                else { move(index + 1) }
            } else if index % 9 > 0 {
                move(index - 1)
            }
        })
        .navigationTitle(round.holeTitle(index))
        .sheet(isPresented: Binding(get: { clubTarget != nil }, set: { if !$0 { clubTarget = nil } })) {
            if let target = clubTarget {
                NavigationStack {
                    ClubChoiceGrid(stroke: target.index + 1, selected: nil, onSelect: { club in
                        guard let club else { return true }
                        return edit(expected: target.revision) { $0.clubs[target.index] = club }
                    }, playingShot: true)
                }
            }
        }
        .sheet(isPresented: $showCard) {
            NavigationStack {
                List {
                    ScoreCard(id: round.id)
                    if let current = store.round(round.id) {
                        ForEach(Array(current.holes.enumerated()), id: \.element.id) { offset, recordedHole in
                            let score = recordedHole.score.value.map { "\($0.strokes)打" } ?? "未入力"
                            if offset / 9 == index / 9 {
                                Button {
                                    showCard = false
                                    move(offset)
                                } label: {
                                    LabeledContent(current.holeTitle(offset), value: score)
                                }
                            } else {
                                NavigationLink {
                                    ScoreEntry(id: current.id, holeIndex: offset, initial: recordedHole)
                                        .navigationTitle(current.holeTitle(offset))
                                } label: {
                                    LabeledContent(current.holeTitle(offset), value: score)
                                }
                            }
                        }
                    }
                }.navigationTitle("ホール一覧")
            }
        }
        .confirmationDialog(finishTitle + "しますか？", isPresented: $confirmFinish, titleVisibility: .visible) {
            if let missing = missingHoles.first {
                if missing / 9 == index / 9 {
                    Button("最初の未入力ホールへ") { move(missing) }
                } else {
                    Button("スコアカードを開く") { showCard = true }
                }
                Button("未入力のまま" + finishTitle, role: .destructive) { finishNine() }
            } else {
                Button(finishTitle) { finishNine() }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            if !missingHoles.isEmpty {
                Text("未入力が\(missingHoles.count)ホールあります。")
            } else {
                let summary = index == 8 ? round.frontSummary : round.summary
                Text("\(summary.strokesText) · \(summary.puttsLabel)")
            }
        }
        .onDisappear { sync() }
        .onChange(of: scenePhase) { phase in if phase == .background { sync() } }
    }

    private func counter(_ title: String, value: Int, size: CGFloat, canSubtract: Bool,
                         minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
            counterButton("−", label: "\(title)を減らす", enabled: canSubtract, action: minus)
            Text("\(value)").font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit().frame(height: 33).accessibilityLabel("\(title) \(value)")
            counterButton("＋", label: "\(title)を増やす", enabled: draft.strokes < 30, action: plus)
        }.frame(maxWidth: .infinity)
    }

    private func counterButton(_ symbol: String, label: String, enabled: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol).font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(symbol == "＋" ? Color.black : Color.white)
        .background(symbol == "＋" ? fairwayGreen : Color(white: 0.18), in: RoundedRectangle(cornerRadius: 9))
        .disabled(!enabled).opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    @discardableResult
    private func edit(expected: Revision? = nil, _ change: (inout CounterDraft) -> Void) -> Bool {
        guard let current = store.round(round.id), !current.finished.value else { return false }
        let score = current.holes[index].score
        if let expected, expected != score.revision {
            store.error = "別の端末でこのホールが更新されました。クラブ選択を閉じて確認してください。"
            return false
        }
        let previous = CounterDraft(score: score.value)
        var next = previous
        change(&next)
        guard next != previous,
              store.saveScore(round.id, hole: index, score: next.score, expected: score.revision, send: false)
        else { return false }
        pendingSync = true
        return true
    }

    private func sync() {
        if pendingSync {
            if store.round(round.id)?.finished.value == false { store.resend(round.id) }
            pendingSync = false
        }
    }
}
