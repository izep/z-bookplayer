import SwiftUI

public struct SleepTimerPicker: View {
    @ObservedObject var player = AudioPlayer.shared
    @State private var showingOptions = false
    
    public init() {}
    
    public var body: some View {
        Menu {
            Button("Off") {
                player.setSleepTimer(.off)
            }
            Button("15 minutes") {
                player.setSleepTimer(.minutes(15))
            }
            Button("30 minutes") {
                player.setSleepTimer(.minutes(30))
            }
            Button("45 minutes") {
                player.setSleepTimer(.minutes(45))
            }
            Button("60 minutes") {
                player.setSleepTimer(.minutes(60))
            }
            Divider()
            Button("End of Chapter") {
                player.setSleepTimer(.endOfChapter)
            }
            Button("End of Next Chapter") {
                player.setSleepTimer(.endOfNextChapter)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "moon.fill")
                    .font(.caption)
                if let remaining = player.sleepTimerRemaining {
                    Text(ScrubberBar.formatTimeString(remaining))
                        .font(.caption.monospacedDigit().weight(.semibold))
                } else if player.activeSleepTimer == .endOfChapter {
                    Text("End Ch")
                        .font(.caption.weight(.semibold))
                } else if player.activeSleepTimer == .endOfNextChapter {
                    Text("+1 Ch")
                        .font(.caption.weight(.semibold))
                } else {
                    Text("Timer")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(player.activeSleepTimer != .off ? Color.orange.opacity(0.8) : Color(white: 0.2))
            .foregroundColor(player.activeSleepTimer != .off ? .black : .white)
            .clipShape(Capsule())
        }
    }
}
