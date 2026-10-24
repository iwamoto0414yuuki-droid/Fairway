import SwiftUI

struct ClubEditor: View {
    @Binding var clubs: [Club?]
    let strokes: Int
    @State private var confirmClear = false
    var body: some View {
        List {
            Section {
                Text("記録したい打だけ選択できます。戻ったあと、スコア画面で保存してください。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("罰打は「罰打（クラブなし）」を選べます。パット数はスコア画面で別に入力します。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("使用クラブ") {
                ForEach(0..<strokes, id: \.self) { index in
                    Picker("\(index + 1)打目", selection: Binding<Club?>(get: { clubs[index] }, set: { clubs[index] = $0 })) {
                        Text("未記録").tag(Optional<Club>.none)
                        ForEach(Club.allCases) { club in Text(club.title).tag(Optional(club)) }
                    }
                }
            }
            Section {
                Button("クラブ記録をすべて解除", role: .destructive) { confirmClear = true }
            }
        }
        .navigationTitle("クラブ（任意）")
        .confirmationDialog("クラブ記録を解除しますか？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("解除する", role: .destructive) { clubs = Array(repeating: nil, count: 30) }
        }
    }
}
