import SwiftUI

public struct ScrubberBar: View {
    @Binding public var currentTime: TimeInterval
    public let duration: TimeInterval
    public let onScrubEnd: (TimeInterval) -> Void
    
    @State private var isDragging: Bool = false
    @State private var dragPosition: TimeInterval = 0
    
    public init(
        currentTime: Binding<TimeInterval>,
        duration: TimeInterval,
        onScrubEnd: @escaping (TimeInterval) -> Void
    ) {
        self._currentTime = currentTime
        self.duration = duration
        self.onScrubEnd = onScrubEnd
    }
    
    private var displayedTime: TimeInterval {
        isDragging ? dragPosition : currentTime
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = duration > 0 ? min(max(displayedTime / duration, 0), 1.0) : 0
                
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color(white: 0.25))
                        .frame(height: 6)
                    
                    // Progress fill
                    Capsule()
                        .fill(Color.green)
                        .frame(width: max(0, width * CGFloat(progress)), height: 6)
                    
                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .shadow(radius: 2)
                        .offset(x: max(0, min(width * CGFloat(progress) - (isDragging ? 8 : 6), width - (isDragging ? 16 : 12))))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let fraction = min(max(value.location.x / width, 0), 1.0)
                            dragPosition = TimeInterval(fraction) * max(duration, 1)
                        }
                        .onEnded { _ in
                            isDragging = false
                            currentTime = dragPosition
                            onScrubEnd(dragPosition)
                        }
                )
            }
            .frame(height: 24)
            
            HStack {
                Text(formatTime(displayedTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(duration))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
    }
    
    public static func formatTimeString(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN && time >= 0 else { return "00:00" }
        let total = Int(time)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        Self.formatTimeString(time)
    }
}
