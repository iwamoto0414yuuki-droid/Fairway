import Foundation

extension Round {
    var csv: String {
        let rows = holes.map { hole -> String in
            let score = hole.score.value
            let clubs = score?.clubs?.map { $0?.shortName ?? "—" }.joined(separator: " / ") ?? ""
            return "\(hole.id),\(hole.par.value),\(score.map { String($0.strokes) } ?? ""),\(score?.putts.map(String.init) ?? ""),\(clubs)"
        }
        let ranges: [(String, ScoreSummary)] = holes.count == 18
            ? [("Front9", frontSummary), ("Back9", backSummary!), ("Total", summary)] : [("Total", summary)]
        let totals = ranges.map { name, value in
            "\(name),\(value.played),\(value.played == 0 ? "" : String(value.strokes)),\(value.puttsRecorded == 0 ? "" : String(value.putts)),\(value.puttsRecorded)"
        }
        return "Hole,Par,Strokes,Putts,ClubsByStroke\n" + rows.joined(separator: "\n")
            + "\n\nSummary,ScoredHoles,Strokes,Putts,PuttsRecordedHoles\n" + totals.joined(separator: "\n")
    }
}
