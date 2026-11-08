import Foundation

struct CounterDraft: Equatable {
    var strokes: Int
    var putts: Int
    var penalties: Int
    var clubs: [Club?]

    init(score: Score?) {
        strokes = score?.strokes ?? 0
        putts = score?.putts ?? 0
        penalties = score?.penaltyStrokes ?? 0
        clubs = Array((score?.clubs ?? []).prefix(30))
        clubs += Array(repeating: nil, count: 30 - clubs.count)
    }

    var regularStrokes: Int { strokes - putts - penalties }

    var score: Score? {
        guard strokes > 0 else { return nil }
        let recorded = Array(clubs.prefix(strokes))
        return Score(strokes: strokes, putts: putts,
                     clubs: recorded.contains(where: { $0 != nil }) ? recorded : nil,
                     penalties: penalties > 0 ? penalties : nil)
    }

    mutating func changeStroke(_ delta: Int) {
        if delta > 0 { append(nil) }
        else if delta < 0 && regularStrokes > 0 { remove(nil) }
    }

    mutating func changePutt(_ delta: Int, markClub: Bool = false) {
        if delta > 0 && strokes < 30 {
            append(markClub ? .putter : nil)
            putts += 1
        } else if delta < 0 && putts > 0 {
            remove(.putter)
            putts -= 1
        }
    }

    mutating func changePenalty(_ delta: Int) {
        if delta > 0 && strokes < 30 {
            append(.penalty)
            penalties += 1
        } else if delta < 0 && penalties > 0 {
            remove(.penalty)
            penalties -= 1
        }
    }

    private mutating func append(_ club: Club?) {
        guard strokes < 30 else { return }
        clubs[strokes] = club
        strokes += 1
    }

    private mutating func remove(_ category: Club?) {
        let played = clubs.prefix(strokes)
        let regular = played.lastIndex { $0 != .putter && $0 != .penalty }
        let index = category.flatMap { marker in played.lastIndex(of: marker) }
            ?? (category == nil ? regular : played.lastIndex(of: nil) ?? regular)
            ?? (strokes - 1)
        clubs.remove(at: index)
        clubs.append(nil)
        strokes -= 1
    }
}
