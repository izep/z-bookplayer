import SwiftUI

public struct SpeedPicker: View {
    @Binding public var currentSpeed: Float
    public struct SpeedOption: Identifiable {
        public let rate: Float
        public let label: String
        public var id: Float { rate }
    }
    
    public let options: [SpeedOption] = [
        SpeedOption(rate: 0.9, label: "-10%"),
        SpeedOption(rate: 1.0, label: "Normal"),
        SpeedOption(rate: 1.1, label: "+10%")
    ]
    public let onChange: (Float) -> Void
    
    public init(currentSpeed: Binding<Float>, onChange: @escaping (Float) -> Void) {
        self._currentSpeed = currentSpeed
        self.onChange = onChange
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(options) { option in
                let isSelected = abs(currentSpeed - option.rate) < 0.05
                Button {
                    currentSpeed = option.rate
                    onChange(option.rate)
                } label: {
                    Text(option.label)
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
}
