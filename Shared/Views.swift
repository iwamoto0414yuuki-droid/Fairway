import SwiftUI

let fairwayGreen = Color(red: 0.64, green: 0.91, blue: 0.39)

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var newRound = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("一打ずつ、シンプルに。")
                        .font(.headline).foregroundStyle(fairwayGreen)
                    #if os(iOS)
                    Button { newRound = true } label: { Label("ラウンドをはじめる", systemImage: "plus.circle.fill") }
                        .frame(minHeight: 44)
                    #else
                    if store.library.rounds.isEmpty {
                        Text("iPhoneでラウンドを作成し、Watchへ送ってください。")
                    }
                    #endif
                }
                Section("プレー中") {
                    ForEach(store.library.rounds.filter { !$0.finished.value }) { round in
                        NavigationLink { RoundView(id: round.id) } label: { RoundLabel(round: round) }
                    }
                }
                Section("履歴") {
                    ForEach(store.library.rounds.filter { $0.finished.value }) { round in
                        NavigationLink { RoundView(id: round.id) } label: { RoundLabel(round: round) }
                    }
                }
                Section {
                    Text(store.syncStatus).font(.caption).foregroundStyle(.secondary)
                    Text("距離は手動更新・グリーン中央までの直線距離です。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Fairway")
            #if os(iOS)
            .sheet(isPresented: $newRound) { NewRoundView() }
            #endif
        }
        .tint(fairwayGreen)
        .preferredColorScheme(.dark)
        .alert("確認してください", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

struct RoundLabel: View {
    let round: Round
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(round.course).font(.headline)
            Text(round.date, style: .date).font(.caption).foregroundStyle(.secondary)
            Text("\(round.played)/\(round.holes.count)H  ·  \(round.total)打  (\(round.relativeText))")
                .font(.subheadline).monospacedDigit()
        }.padding(.vertical, 4)
    }
}

struct RoundView: View {
    @EnvironmentObject var store: Store
    let id: UUID
    @State private var selectedHole: HoleSelection?
    @State private var confirmFinish = false
    struct HoleSelection: Identifiable { let id: Int }
    var body: some View {
        if let round = store.round(id) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(round.total)").font(.system(size: 46, weight: .semibold, design: .rounded))
                        Text("\(round.relativeText)  /  \(round.played)ホール入力済み")
                            .foregroundStyle(fairwayGreen)
                    }
                    if !round.finished.value {
                        Button("スコアを入力") {
                            selectedHole = HoleSelection(id: round.holes.firstIndex { $0.score.value == nil } ?? 0)
                        }.frame(minHeight: 44)
                    }
                }
                Section("スコアカード・修正") {
                    ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                        Button { selectedHole = HoleSelection(id: index) } label: {
                            HStack {
                                Text(String(format: "%02d", hole.id)).bold()
                                Text("PAR \(hole.par.value)").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(hole.score.value.map { "\($0.strokes)" } ?? "—").bold().monospacedDigit()
                            }.frame(minHeight: 36)
                        }
                    }
                }
                Section {
                    Text("未入力ホールは合計・対パーに含めません。罰打は打数に含めて入力してください。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("このラウンドを再送") { store.resend(id) }
                    Text(store.syncStatus).font(.caption).foregroundStyle(.secondary)
                    if round.finished.value {
                        Button("ラウンドを再開") { store.finish(id, value: false) }
                        #if os(iOS)
                        Button("同じコースで新規ラウンド") { store.create(course: round.course, count: round.holes.count, template: round) }
                        ShareLink(item: csv(round)) { Label("スコアを書き出す", systemImage: "square.and.arrow.up") }
                        #endif
                    } else {
                        Button("ラウンドを終了") { confirmFinish = true }
                    }
                }
            }
            .navigationTitle(round.course)
            .sheet(item: $selectedHole) { item in
                NavigationStack { ScoreEntry(id: id, holeIndex: item.id, initial: round.holes[item.id]) }
            }
            .confirmationDialog("\(round.played)/\(round.holes.count)ホール入力済み。ラウンドを終了しますか？", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("終了して履歴に保存") { store.finish(id, value: true) }
            }
        } else { Text("ラウンドが見つかりません") }
    }
    private func csv(_ round: Round) -> String {
        "Hole,Par,Strokes,Putts\n" + round.holes.map { hole in
            "\(hole.id),\(hole.par.value),\(hole.score.value.map { String($0.strokes) } ?? ""),\(hole.score.value?.putts.map(String.init) ?? "")"
        }.joined(separator: "\n")
    }
}

struct ScoreEntry: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State var holeIndex: Int
    @State private var strokes: Int
    @State private var putts: Int
    @State private var includePutts: Bool
    @State private var expected: Revision
    @State private var showMap = false
    @State private var clearConfirmation = false
    init(id: UUID, holeIndex: Int, initial: Hole) {
        self.id = id; _holeIndex = State(initialValue: holeIndex)
        _strokes = State(initialValue: initial.score.value?.strokes ?? initial.par.value)
        _putts = State(initialValue: initial.score.value?.putts ?? 2)
        _includePutts = State(initialValue: initial.score.value?.putts != nil)
        _expected = State(initialValue: initial.score.revision)
    }
    var body: some View {
        if let round = store.round(id), round.holes.indices.contains(holeIndex) {
            let hole = round.holes[holeIndex]
            ScrollView {
                VStack(spacing: entrySpacing) {
                    #if os(iOS)
                    Text("HOLE \(hole.id)  ·  PAR \(hole.par.value)").font(.headline).foregroundStyle(fairwayGreen)
                    #endif
                    if let error = store.error { Text(error).font(.caption).foregroundStyle(.orange) }
                    #if os(iOS)
                    DistanceView(target: hole.green.value).id("\(id)-\(holeIndex)")
                    #endif
                    VStack(spacing: 8) {
                        Text("打数（罰打込み）").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            countButton("minus", label: "打数を減らす", disabled: strokes <= 1) { strokes -= 1; putts = min(putts, strokes) }
                            Spacer(minLength: 4)
                            Text("\(strokes)").font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                            Spacer(minLength: 4)
                            countButton("plus", label: "打数を増やす", disabled: strokes >= 30) { strokes += 1 }
                        }
                    }
                    #if os(iOS)
                    puttControls
                    #endif
                    Button(holeIndex + 1 < round.holes.count ? "保存して次へ" : "保存してカードへ") {
                        guard store.saveScore(id, hole: holeIndex, score: Score(strokes: strokes, putts: includePutts ? putts : nil), expected: expected) else { return }
                        if holeIndex + 1 < round.holes.count, let latest = store.round(id) {
                            holeIndex += 1; load(latest.holes[holeIndex])
                        } else { dismiss() }
                    }.buttonStyle(.borderedProminent).foregroundStyle(.black).frame(minHeight: 44)
                    #if os(watchOS)
                    NavigationLink {
                        ScrollView { DistanceView(target: hole.green.value).padding(8) }.navigationTitle("GPS距離")
                    } label: { Label("GPS距離", systemImage: "location") }
                    puttControls
                    #endif
                    Button("保存して閉じる") {
                        if store.saveScore(id, hole: holeIndex, score: Score(strokes: strokes, putts: includePutts ? putts : nil), expected: expected) { dismiss() }
                    }.frame(minHeight: 44)
                    #if os(iOS)
                    Button("PAR・グリーン位置を設定") { showMap = true }
                        .sheet(isPresented: $showMap) { GreenEditor(id: id, holeIndex: holeIndex, hole: hole) }
                    #endif
                    if hole.score.value != nil {
                        Button("このホールを未入力に戻す", role: .destructive) { clearConfirmation = true }
                    }
                    Text("保存するまでは変更は確定しません。")
                        .font(.caption2).foregroundStyle(.secondary)
                    Button("変更せず閉じる") { dismiss() }
                }.padding(.vertical, 8).padding(.horizontal, 8)
            }
            #if os(iOS)
            .navigationTitle("スコア")
            #else
            .navigationTitle("\(hole.id)H · PAR\(hole.par.value)")
            #endif
            .confirmationDialog("このホールの記録を取り消しますか？", isPresented: $clearConfirmation, titleVisibility: .visible) {
                Button("未入力に戻す", role: .destructive) {
                    if store.saveScore(id, hole: holeIndex, score: nil, expected: expected) { dismiss() }
                }
            }
        }
    }
    private var entrySpacing: CGFloat {
        #if os(watchOS)
        return 8
        #else
        return 16
        #endif
    }
    private var puttControls: some View {
        VStack(spacing: 8) {
            Toggle("パット数も記録", isOn: $includePutts).font(.caption)
                .onChange(of: includePutts) { _, _ in putts = min(putts, strokes) }
            if includePutts { Stepper("パット \(putts)", value: $putts, in: 0...strokes) }
        }
    }
    private func load(_ hole: Hole) {
        strokes = hole.score.value?.strokes ?? hole.par.value
        putts = hole.score.value?.putts ?? min(2, strokes)
        includePutts = hole.score.value?.putts != nil
        expected = hole.score.revision
    }
    private func countButton(_ icon: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.title3.bold()).frame(width: 44, height: 44).background(Color.white.opacity(0.12), in: Circle()) }
            .buttonStyle(.plain).disabled(disabled).accessibilityLabel(label)
    }
}

struct DistanceView: View {
    let target: Coordinate?
    @StateObject private var gps = Rangefinder()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(spacing: 6) {
            if let target {
                Text("グリーン中央").font(.caption).foregroundStyle(.secondary)
                if let yards = gps.yards(to: target), let fix = gps.location {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(yards)").font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text("yd").foregroundStyle(.secondary)
                    }
                    Text("測定 \(fix.timestamp.formatted(date: .omitted, time: .shortened)) / 精度 ±\(Int(fix.horizontalAccuracy.rounded()))m")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("測定時点の距離です").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("— yd").font(.title)
                    if gps.location != nil { Text("グリーン位置が2km以上離れています。登録位置・ホールを確認してください。").font(.caption) }
                }
                Button { gps.request() } label: {
                    Label(gps.busy ? "測位中…" : "距離を更新", systemImage: "location")
                }.disabled(gps.busy).frame(minHeight: 44)
                if gps.busy { Button("測位を中止") { gps.cancel() }.font(.caption) }
                if let message = gps.message { Text(message).font(.caption).foregroundStyle(.orange) }
            } else {
                Text("グリーン位置が未登録").font(.caption)
                Text("iPhoneでこのホールの位置を設定してください。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .onDisappear { gps.cancel() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { gps.cancel() } }
        .onChange(of: target) { _, _ in gps.cancel() }
    }
}
