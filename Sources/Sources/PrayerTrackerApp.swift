import SwiftUI

@main
struct PrayerTrackerApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
        }
    }
}
