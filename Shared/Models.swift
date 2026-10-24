import Foundation

struct Revision: Codable, Equatable, Comparable {
    var counter: Int
    var device: String
    static let zero = Revision(counter: 0, device: "")
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.counter == rhs.counter ? lhs.device < rhs.device : lhs.counter < rhs.counter
    }
}

struct Value<ValueType: Codable & Equatable>: Codable, Equatable {
    var value: ValueType
    var revision: Revision = .zero
    mutating func merge(_ other: Self) {
        if revision < other.revision { self = other }
    }
}

struct Coordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
    func meters(to other: Coordinate) -> Double {
        let r = Double.pi / 180
        let dLat = (other.latitude - latitude) * r
        let dLon = (other.longitude - longitude) * r
        let a = pow(sin(dLat / 2), 2) + cos(latitude * r) * cos(other.latitude * r) * pow(sin(dLon / 2), 2)
        return 6_371_000 * 2 * asin(sqrt(min(1, max(0, a))))
    }
}

struct Score: Codable, Equatable {
    var strokes: Int
    var putts: Int?
    var isValid: Bool { (1...30).contains(strokes) && (putts.map { (0...strokes).contains($0) } ?? true) }
}

struct Hole: Codable, Equatable, Identifiable {
    var id: Int
    var par = Value(value: 4)
    var green = Value<Coordinate?>(value: nil)
    var score = Value<Score?>(value: nil)
    mutating func merge(_ other: Hole) {
        par.merge(other.par); green.merge(other.green); score.merge(other.score)
    }
    var revisions: [Revision] { [par.revision, green.revision, score.revision] }
}

struct Round: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var course: String
    var holes: [Hole]
    var finished = Value(value: false)
    init(course: String, count: Int) {
        self.course = String(course.prefix(80))
        holes = (1...(count == 9 ? 9 : 18)).map { Hole(id: $0) }
    }
    var total: Int { holes.compactMap { $0.score.value?.strokes }.reduce(0, +) }
    var played: Int { holes.filter { $0.score.value != nil }.count }
    var relative: Int {
        holes.reduce(0) { total, hole in total + (hole.score.value.map { score in score.strokes - hole.par.value } ?? 0) }
    }
    var relativeText: String { relative == 0 ? "E" : String(format: "%+d", relative) }
    var maxCounter: Int { (holes.flatMap(\.revisions) + [finished.revision]).map(\.counter).max() ?? 0 }
    var isValid: Bool {
        [9, 18].contains(holes.count) && holes.map(\.id) == Array(1...holes.count)
        && course.count <= 80 && date.timeIntervalSince1970.isFinite
        && holes.allSatisfy { (3...6).contains($0.par.value) && ($0.green.value?.isValid ?? true) && ($0.score.value?.isValid ?? true) }
        && (holes.flatMap(\.revisions) + [finished.revision]).allSatisfy { $0.counter >= 0 && $0.counter < Int.max - 1 && $0.device.count <= 80 }
    }
    mutating func merge(_ other: Round) {
        guard id == other.id, holes.count == other.holes.count, other.isValid else { return }
        for index in holes.indices { holes[index].merge(other.holes[index]) }
        finished.merge(other.finished)
    }
}

struct Library: Codable, Equatable {
    var schema = 1
    var rounds: [Round] = []
    mutating func merge(_ round: Round) {
        guard round.isValid else { return }
        if let index = rounds.firstIndex(where: { $0.id == round.id }) { rounds[index].merge(round) }
        else { rounds.append(round) }
        rounds.sort { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
    }
}
