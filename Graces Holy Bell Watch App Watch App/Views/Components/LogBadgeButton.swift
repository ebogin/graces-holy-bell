import SwiftUI

/// The LOG button on the Active screen — shows entry count and opens the log.
struct LogBadgeButton: View {

    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                // Three horizontal "log row" bars
                VStack(spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.lcdDark)
                            .frame(width: 8, height: 1.5)
                    }
                }

                Text("\(count)")
                    .font(.pixelFont(8))
                    .foregroundStyle(Color.lcdDark)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.lcdBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.lcdDark, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }
}
