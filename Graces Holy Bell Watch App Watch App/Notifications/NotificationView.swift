import SwiftUI

/// Full-screen notification interface shown on Apple Watch when the prayer
/// interval elapses and "Notify on Apple Watch" is selected.
///
/// Displayed via WKNotificationScene when a "PRAY_REMINDER" notification fires.
/// Flashes between red and black to draw attention.
struct NotificationView: View {

    @State private var isFlashing = false

    var body: some View {
        ZStack {
            (isFlashing ? Color.red : Color.black)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)

                Text("Time to Pray")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
            ) {
                isFlashing = true
            }
        }
    }
}
