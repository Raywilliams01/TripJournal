import SwiftUI

@main
struct TripJournalApp: App {
    let journalServiceLive = JournalServiceLive()
    var body: some Scene {
        WindowGroup {
            RootView(service: journalServiceLive)
        }
    }
}
