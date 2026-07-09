import SwiftUI

enum Theme {
    static let accent = Color(red: 0.30, green: 0.80, blue: 0.55)
    static let background = Color(red: 0.06, green: 0.07, blue: 0.09)
    static let card = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let cardStroke = Color.white.opacity(0.06)

    static let danger = Color(red: 0.90, green: 0.32, blue: 0.34)
    static let warning = Color(red: 0.95, green: 0.68, blue: 0.25)
    static let good = Color(red: 0.30, green: 0.80, blue: 0.55)
}

extension View {
    /// Standard card container used throughout the app.
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
    }
}
