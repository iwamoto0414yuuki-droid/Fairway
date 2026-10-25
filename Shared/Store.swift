import SwiftUI
import WatchConnectivity

final class Store: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var library = Library()
    @Published var error: String?
    @Published private(set) var syncStatus = "端末に保存"
    private let file: URL
    private let device: String
    private var healthy = true
    private var session: WCSession?

    init(fileURL: URL? = nil, connectivity: Bool = true) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = fileURL ?? directory.appendingPathComponent("rounds-v1.json")
        let defaults = UserDefaults.standard
        device = defaults.string(forKey: "deviceID") ?? UUID().uuidString
        defaults.set(device, forKey: "deviceID")
        super.init()
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) {
                let loaded = try JSONDecoder().decode(Library.self, from: Data(contentsOf: file))
                guard loaded.schema == 1, loaded.rounds.allSatisfy(\.isValid), Set(loaded.rounds.map(\.id)).count == loaded.rounds.count else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                library = loaded
            }
        } catch {
            healthy = false
            self.error = "保存データを読み込めません。元ファイルを保護するため書き込みを停止しました。\(error.localizedDescription)"
        }
        if connectivity && WCSession.isSupported() {
            session = .default; session?.delegate = self; session?.activate()
        }
    }

    func round(_ id: UUID) -> Round? { library.visibleRounds.first { $0.id == id } }
    private func revision() -> Revision {
        Revision(counter: (library.rounds.map(\.maxCounter).max() ?? 0) + 1, device: device)
    }
    @discardableResult func commit(_ round: Round, send: Bool = true) -> Bool {
        guard healthy, round.isValid else { error = "データを保存できません。入力または保存ファイルを確認してください。"; return false }
        var next = library; next.merge(round)
        if next == library { return true }
        do {
            try JSONEncoder().encode(next).write(to: file, options: .atomic)
            library = next
            if send, let merged = library.rounds.first(where: { $0.id == round.id }) { enqueue(merged) }
            return true
        } catch { self.error = "保存に失敗しました。画面を閉じずに再試行してください。\(error.localizedDescription)"; return false }
    }
    @discardableResult func create(course: String, count: Int, template: Round? = nil) -> UUID? {
        var round = Round(course: course.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "マイコース" : course, count: count)
        if let template {
            round.course = template.course
            round.holes = template.holes.map { old in
                var hole = Hole(id: old.id)
                hole.par = Value(value: old.par.value, revision: revision())
                hole.green = Value(value: old.green.value, revision: revision())
                return hole
            }
        }
        return commit(round) ? round.id : nil
    }
    @discardableResult func saveScore(_ id: UUID, hole: Int, score: Score?, expected: Revision, send: Bool = true) -> Bool {
        guard var round = round(id), round.holes.indices.contains(hole) else { return false }
        guard round.holes[hole].score.revision == expected else {
            error = "このホールは別の端末で更新されました。いったん戻り、最新の値を確認して入力し直してください。"; return false
        }
        round.holes[hole].score = Value(value: score, revision: revision())
        return commit(round, send: send)
    }
    @discardableResult func configure(_ id: UUID, hole: Int, par: Int, green: Coordinate?) -> Bool {
        guard var round = round(id), round.holes.indices.contains(hole) else { return false }
        let stamp = revision()
        round.holes[hole].par = Value(value: par, revision: stamp)
        round.holes[hole].green = Value(value: green, revision: stamp)
        return commit(round)
    }
    func finish(_ id: UUID, value: Bool) {
        guard var round = round(id) else { return }
        round.finished = Value(value: value, revision: revision()); commit(round)
    }
    @discardableResult func delete(_ id: UUID) -> Bool {
        guard var round = round(id) else { return false }
        round.deletion = Value(value: true, revision: revision())
        return commit(round)
    }
    func resend(_ id: UUID) { if let round = round(id) { enqueue(round) } }
    private func enqueue(_ round: Round) {
        guard let session, session.activationState == .activated else { syncStatus = "端末に保存・接続待ち"; return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { syncStatus = "端末に保存・Watch未接続"; return }
        #endif
        do {
            let data = try JSONEncoder().encode(round)
            // Only a committed round is sent. No timer, polling or per-tap messages.
            session.transferUserInfo(["roundV1": data])
            syncStatus = "端末に保存・転送予約済み"
        } catch { syncStatus = "端末に保存・転送失敗" }
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if error != nil { self.syncStatus = "端末に保存・接続失敗"; return }
            // Retry latest state after launch; queued transfers survive disconnection.
            // Persisted deletion markers must reach an offline peer even when
            // the deletion was not the most recent round. No polling or timer.
            for round in self.library.rounds where round.isDeleted { self.enqueue(round) }
            if let round = self.library.visibleRounds.first { self.enqueue(round) }
        }
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["roundV1"] as? Data, data.count < 100_000,
              let round = try? JSONDecoder().decode(Round.self, from: data), round.isValid else { return }
        DispatchQueue.main.async {
            if self.commit(round, send: false) { self.syncStatus = "相手のデータを受信済み" }
        }
    }
    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        DispatchQueue.main.async {
            self.syncStatus = error == nil ? "転送完了" : "端末に保存・再送が必要"
        }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
