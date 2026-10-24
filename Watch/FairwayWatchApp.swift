import SwiftUI

@main
struct FairwayWatchApp: App {
    @StateObject private var store = Store()
    var body: some Scene { WindowGroup { HomeView().environmentObject(store) } }
}
