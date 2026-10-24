import SwiftUI

@main
struct FairwayApp: App {
    @StateObject private var store = Store()
    var body: some Scene { WindowGroup { HomeView().environmentObject(store) } }
}

struct NewRoundView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var course = ""
    @State private var count = 18
    var body: some View {
        NavigationStack {
            Form {
                Section("コース") { TextField("ゴルフ場・コース名", text: $course) }
                Section("ホール数") { Picker("ホール数", selection: $count) { Text("9ホール").tag(9); Text("18ホール").tag(18) }.pickerStyle(.segmented) }
                Section {
                    Text("作成後、各ホールでPARとグリーン中央の位置を設定できます。登録したコースは履歴から再利用できます。")
                    Text("初期PARはすべて4です。実際のスコアカードに合わせて変更してください。")
                }.font(.subheadline).foregroundStyle(.secondary)
                Button("ラウンドを作成") { if store.create(course: course, count: count) != nil { dismiss() } }
            }
            .navigationTitle("新しいラウンド")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } } }
        }
    }
}
