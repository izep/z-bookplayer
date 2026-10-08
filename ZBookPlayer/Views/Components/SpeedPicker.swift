import SwiftUI

public struct SpeedPicker: View {
    @Binding public var currentSpeed: Float
    public let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    public let onChange: (Float) -> Void
    
    public init(currentSpeed: Binding<Float>, onChange: @escaping (Float) -> Void) {
        self._currentSpeed = currentSpeed
        self.onChange = onChange
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(speeds, id: \.self) { speed in
                let isSelected = abs(currentSpeed - speed) < 0.05
                Button {
                    currentSpeed = speed
                    onChange(speed)
                } label: {
                    Text(formatSpeed(speed))
                        .font(.caption.weight(isSelected ? .bold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.green : Color(white: 0.2))
                        .foregroundColor(isSelected ? .black : .white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func formatSpeed(_ speed: Float) -> String {
        if speed == floor(speed) {
            return String(format: "%.0fx", speed)
        } else {
            return String(format: "%.2gx", speed)
        }
    }
}
