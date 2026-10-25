import SwiftUI

struct ClubEditor: View {
    @Binding var clubs: [Club?]
    let strokes: Int
    @State private var confirmClear = false
    var body: some View {
        List {
            Section("何打目のクラブを記録しますか？") {
                ForEach(0..<strokes, id: \.self) { index in
                    NavigationLink {
                        ClubChoiceGrid(stroke: index + 1, selected: index < clubs.count ? clubs[index] : nil) { club in
                            guard index < strokes, index < clubs.count else { return false }
                            var next = clubs; next[index] = club; clubs = next
                            return index < clubs.count && clubs[index] == club
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(index + 1)打目").font(.headline)
                            Text(index < clubs.count ? (clubs[index]?.title ?? "未記録") : "未記録")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: 44)
                    }
                }
            }
            Section {
                Button("このホールのクラブ記録を解除", role: .destructive) { confirmClear = true }
            }
            Section {
                Text("打目を選び、クラブを押すと自動保存して戻ります。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("パターを選んでもパット数は変わりません。パット数はスコア画面で入力します。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("使用クラブ")
        .confirmationDialog("このホールのクラブ記録を解除しますか？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("解除する", role: .destructive) { clubs = Array(repeating: nil, count: 30) }
            Button("キャンセル", role: .cancel) { }
        }
    }
}

struct ClubChoiceGrid: View {
    @Environment(\.dismiss) private var dismiss
    let stroke: Int
    let selected: Club?
    let onSelect: (Club?) -> Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 3)
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(Club.bag) { club in
                        if club == .putter { Color.clear.frame(height: 50).accessibilityHidden(true) }
                        Button { choose(club) } label: {
                            VStack(spacing: 1) {
                                HStack(spacing: 1) {
                                    Text(club.shortName).font(.system(size: 20, weight: .bold, design: .rounded))
                                    if selected == club { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
                                }.lineLimit(1).minimumScaleFactor(0.75)
                                Text(club.kindName).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.75)
                            }.frame(maxWidth: .infinity, minHeight: 50)
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(selected == club ? Color.black : Color.white)
                        .background(selected == club ? fairwayGreen : Color(white: 0.18), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel(club.title)
                    }
                }
                Button("未記録に戻す") { choose(nil) }.frame(minHeight: 44)
                Button("罰打（クラブなし）") { choose(.penalty) }.frame(minHeight: 44)
                Text("パット数はスコア画面で入力します。")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 2)
        }
        .navigationTitle("\(stroke)打目のクラブ")
    }
    private func choose(_ club: Club?) {
        if onSelect(club) { dismiss() }
    }
}
