import SwiftUI
import MapKit

struct GreenEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    let holeIndex: Int
    @State private var par: Int
    @State private var pin: Coordinate?
    @State private var position: MapCameraPosition
    @State private var query = ""
    @State private var searching = false
    @State private var message: String?
    @State private var search: MKLocalSearch?
    @State private var results: [MKMapItem] = []
    init(id: UUID, holeIndex: Int, hole: Hole) {
        self.id = id; self.holeIndex = holeIndex
        _par = State(initialValue: hole.par.value); _pin = State(initialValue: hole.green.value)
        let coordinate = hole.green.value ?? Coordinate(latitude: 35.6, longitude: 140.1)
        _position = State(initialValue: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: hole.green.value == nil ? 0.4 : 0.003, longitudeDelta: hole.green.value == nil ? 0.4 : 0.003))))
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Stepper("HOLE \(holeIndex + 1)  ·  PAR \(par)", value: $par, in: 3...6).padding(.horizontal)
                HStack {
                    TextField("ゴルフ場を検索", text: $query).textFieldStyle(.roundedBorder).onSubmit { lookup() }
                    Button(searching ? "検索中" : "検索") { lookup() }.disabled(searching || query.trimmingCharacters(in: .whitespaces).isEmpty)
                }.padding(.horizontal)
                if !results.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                                Button(item.name ?? "検索結果") {
                                    position = .region(MKCoordinateRegion(center: item.placemark.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)))
                                    results = []
                                }.padding(8)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 130)
                }
                MapReader { proxy in
                    Map(position: $position) {
                        if let pin {
                            Marker("グリーン中央", systemImage: "flag.fill", coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)).tint(.green)
                        }
                    }.mapStyle(.imagery)
                        .onTapGesture { point in
                            if let coordinate = proxy.convert(point, from: .local) { pin = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude) }
                        }
                }
                Text("地図を拡大して、グリーン中央をタップしてください。検索結果はゴルフ場の所在地で、グリーン位置ではありません。")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                if let pin { Text(String(format: "%.6f, %.6f", pin.latitude, pin.longitude)).font(.caption).monospacedDigit() }
                if let message { Text(message).font(.caption).foregroundStyle(.orange) }
                HStack {
                    Button("位置を解除", role: .destructive) { pin = nil }
                    Spacer()
                    Button("設定を保存") { if store.configure(id, hole: holeIndex, par: par, green: pin) { dismiss() } }
                        .buttonStyle(.borderedProminent).foregroundStyle(.black)
                }.padding()
            }
            .navigationTitle("PAR・グリーン位置")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } } }
            .onDisappear { search?.cancel() }
        }.tint(fairwayGreen)
    }
    private func lookup() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searching, !text.isEmpty else { return }
        searching = true; message = nil
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = text
        let operation = MKLocalSearch(request: request); search = operation
        operation.start { response, error in
            DispatchQueue.main.async {
                searching = false
                results = Array((response?.mapItems ?? []).prefix(8))
                if results.isEmpty { message = "見つかりませんでした。別の名前で検索するか、地図を移動してください。" }
            }
        }
    }
}
