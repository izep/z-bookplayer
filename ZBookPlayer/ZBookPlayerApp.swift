import SwiftUI

@main
struct ZBookPlayerApp: App {
    @StateObject private var library = LibraryManager.shared
    @StateObject private var player = AudioPlayer.shared
    
    var body: some Scene {
        WindowGroup {
            BookshelfView()
                .preferredColorScheme(.dark)
                .environmentObject(library)
                .environmentObject(player)
        }
    }
}
