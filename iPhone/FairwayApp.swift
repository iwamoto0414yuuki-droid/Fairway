import SwiftUI

@main
struct FairwayApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup { HomeView().environmentObject(store) }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: Store
    @AppStorage("FairwayPhoneActiveRound") private var activeRoundID = ""
    @State private var path: [UUID] = []
    @State private var showingSetup = false
    @State private var createdRound: UUID?

    private var currentRound: Round? {
        if let id = UUID(uuidString: activeRoundID), let round = store.round(id), !round.finished.value {
            return round
        }
        return store.library.visibleRounds.first { !$0.finished.value }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let round = currentRound {
                    Section("プレー中") {
                        NavigationLink(value: round.id) {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("ラウンドを再開", systemImage: "play.circle.fill")
                                    .font(.headline).foregroundStyle(fairwayGreen)
                                PhoneRoundLabel(round: round)
                            }.padding(.vertical, 4)
                        }
                    }
                }
                Section {
                    Button {
                        showingSetup = true
                    } label: {
                        Label("ラウンド開始", systemImage: "plus.circle.fill")
                            .font(.headline).frame(minHeight: 44)
                    }
                    NavigationLink {
                        PhoneRoundList(editing: true)
                    } label: {
                        Label("スコア修正", systemImage: "square.and.pencil").frame(minHeight: 44)
                    }
                    NavigationLink {
                        PhoneRoundList(editing: false)
                    } label: {
                        Label("ラウンド履歴", systemImage: "list.bullet.rectangle").frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Fairway")
            .navigationDestination(for: UUID.self) { id in
                RoundView(id: id)
            }
        }
        .sheet(isPresented: $showingSetup, onDismiss: openCreatedRound) {
            NewRoundView(recent: store.library.visibleRounds.first) { id in
                createdRound = id
                showingSetup = false
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

    private func openCreatedRound() {
        guard let id = createdRound else { return }
        createdRound = nil
        path.append(id)
    }
}

struct NewRoundView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var count: Int
    @State private var selection: CourseSelection
    let onStart: (UUID) -> Void

    init(recent: Round?, onStart: @escaping (UUID) -> Void) {
        _count = State(initialValue: recent?.holes.count ?? 18)
        _selection = State(initialValue: recent?.courses?.value ?? CourseSelection(front: .out, back: .inCourse))
        self.onStart = onStart
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ホール数") {
                    Picker("ホール数", selection: $count) {
                        Text("9ホール").tag(9)
                        Text("18ホール").tag(18)
                    }.pickerStyle(.segmented)
                }
                Section("コース") {
                    TextField("ゴルフ場名（任意）", text: $name)
                    coursePicker(count == 9 ? "プレーするコース" : "前半", selection: $selection.front)
                    if count == 18 { coursePicker("後半", selection: $selection.back) }
                }
                Section {
                    Button {
                        let customName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let course = customName.isEmpty ? "マイコース" : customName
                        if let id = store.create(course: course, count: count, courses: selection) {
                            onStart(id)
                        }
                    } label: {
                        Label("入力を開始", systemImage: "flag.fill")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
            .navigationTitle("ラウンド開始")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func coursePicker(_ title: String, selection: Binding<CourseNine>) -> some View {
        Picker(title, selection: selection) {
            ForEach(CourseNine.allCases) { course in Text(course.rawValue).tag(course) }
        }
    }
}

private struct PhoneRoundList: View {
    @EnvironmentObject private var store: Store
    let editing: Bool

    var body: some View {
        List {
            ForEach(store.library.visibleRounds) { round in
                NavigationLink {
                    if editing {
                        SavedRoundView(id: round.id)
                    } else {
                        PhoneScoreCard(round: round)
                    }
                } label: {
                    PhoneRoundLabel(round: round)
                }
            }
        }
        .overlay {
            if store.library.visibleRounds.isEmpty {
                ContentUnavailableView("ラウンドの記録がありません", systemImage: "flag")
            }
        }
        .navigationTitle(editing ? "スコア修正" : "ラウンド履歴")
    }
}

private struct PhoneRoundLabel: View {
    let round: Round

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(round.courseTitle).font(.headline)
            Text(round.date, style: .date).font(.caption).foregroundStyle(.secondary)
            Text("\(round.summary.strokesText) · \(round.summary.puttsLabel) · \(round.played)/\(round.holes.count)H")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct RoundView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @AppStorage("FairwayPhoneActiveRound") private var activeRoundID = ""
    @AppStorage private var selected: Int
    @State private var showingCard = false
    @State private var confirmingFinish = false

    init(id: UUID) {
        self.id = id
        _selected = AppStorage(wrappedValue: -1, "FairwayPhoneSelectedHole-" + id.uuidString)
    }

    var body: some View {
        if let round = store.round(id) {
            let index = currentHole(in: round)
            let missing = round.unscoredHoles(through: round.holes.count - 1)
            ScoreEntry(id: id, holeIndex: index, initial: round.holes[index])
                .id(index)
                .onAppear {
                    if !round.holes.indices.contains(selected) { selected = index }
                    if !round.finished.value { activeRoundID = id.uuidString }
                }
                .navigationTitle(round.holeTitle(index))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCard = true
                        } label: {
                            Label("スコアカード", systemImage: "list.bullet.rectangle")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 12) {
                        Button {
                            selected = index - 1
                        } label: {
                            Label("前のホール", systemImage: "chevron.left")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(index == 0)
                        Button {
                            if index + 1 < round.holes.count {
                                selected = index + 1
                            } else if round.finished.value {
                                showingCard = true
                            } else {
                                confirmingFinish = true
                            }
                        } label: {
                            Text(index + 1 < round.holes.count ? "次のホール" : (round.finished.value ? "スコアカード" : "ラウンド終了"))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(.black)
                    }.padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.bar)
                }
                .sheet(isPresented: $showingCard) {
                    NavigationStack {
                        PhoneScoreCard(round: round) { hole in
                            selected = hole
                            showingCard = false
                        }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("閉じる") { showingCard = false }
                            }
                        }
                    }
                }
                .confirmationDialog("ラウンドを終了しますか？", isPresented: $confirmingFinish, titleVisibility: .visible) {
                    if let firstMissing = missing.first {
                        Button("最初の未入力ホールへ") { selected = firstMissing }
                        Button("未入力のまま終了", role: .destructive) { finish() }
                    } else {
                        Button("ラウンドを終了") { finish() }
                    }
                    Button("キャンセル", role: .cancel) { }
                } message: {
                    if missing.isEmpty {
                        Text("\(round.summary.strokesText) · \(round.summary.puttsLabel)")
                    } else {
                        Text("未入力が\(missing.count)ホールあります。")
                    }
                }
        } else {
            ContentUnavailableView("このラウンドは削除されました", systemImage: "flag.slash")
        }
    }

    private func currentHole(in round: Round) -> Int {
        if round.holes.indices.contains(selected) { return selected }
        return round.unscoredHoles(through: round.holes.count - 1).first ?? round.holes.count - 1
    }

    private func finish() {
        if store.finish(id, value: true) {
            if activeRoundID == id.uuidString { activeRoundID = "" }
            dismiss()
        }
    }
}

private struct PhoneScoreCard: View {
    @EnvironmentObject private var store: Store
    let round: Round
    var onSelect: ((Int) -> Void)? = nil

    var body: some View {
        if let current = store.round(round.id) {
            List {
                Section {
                    PhoneRoundLabel(round: current)
                    ScoreCard(id: current.id)
                }
                Section("ホール別の記録") {
                    ForEach(Array(current.holes.enumerated()), id: \.element.id) { index, hole in
                        if let onSelect {
                            Button { onSelect(index) } label: {
                                holeRow(title: current.holeTitle(index), score: hole.score.value)
                            }.foregroundStyle(.primary)
                        } else {
                            holeRow(title: current.holeTitle(index), score: hole.score.value)
                        }
                    }
                }
            }
            .navigationTitle("スコアカード")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("このラウンドは削除されました", systemImage: "flag.slash")
        }
    }

    private func holeRow(title: String, score: Score?) -> some View {
        LabeledContent {
            if let score {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(score.strokes)打")
                    let putts = score.putts.map { "\($0)パット" } ?? "パット未記録"
                    let penalties = score.penaltyStrokes
                    Text(penalties > 0 ? "\(putts) · 罰打\(penalties)" : putts)
                        .font(.caption)
                }.monospacedDigit()
            } else {
                Text("未入力")
            }
        } label: {
            Text(title)
        }.frame(minHeight: 44)
    }
}
