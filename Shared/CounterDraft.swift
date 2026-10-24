import Foundation

struct CounterDraft: Equatable {
    var strokes: Int
    var putts: Int
    var clubs: [Club?]
    init(score: Score?) {
        strokes = score?.strokes ?? 0
        putts = score?.putts ?? 0
        clubs = Array((score?.clubs ?? []).prefix(30))
        clubs += Array(repeating: nil, count: 30 - clubs.count)
    }
    var score: Score? {
        guard strokes > 0 else { return nil }
        let recorded = Array(clubs.prefix(strokes))
        return Score(strokes: strokes, putts: putts, clubs: recorded.contains(where: { $0 != nil }) ? recorded : nil)
    }
    mutating func changeStroke(_ delta: Int) {
        strokes = min(30, max(0, strokes + delta))
        putts = min(putts, strokes)
        for index in strokes..<30 { clubs[index] = nil }
    }
    mutating func changePutt(_ delta: Int) {
        guard delta > 0 ? strokes < 30 : putts > 0 else { return }
        let newPutts = putts + delta
        changeStroke(delta)
        putts = min(strokes, max(0, newPutts))
    }
}
