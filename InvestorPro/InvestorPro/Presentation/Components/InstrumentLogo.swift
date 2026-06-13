import SwiftUI

/// Round instrument logo from the T-Invest brand CDN, with a coloured-initials
/// fallback (e.g. for crypto or instruments without a brand logo).
struct InstrumentLogo: View {
    let url: URL?
    let fallbackText: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallback: some View {
        Circle()
            .fill(color)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let trimmed = fallbackText.trimmingCharacters(in: .whitespaces)
        return String(trimmed.prefix(2)).uppercased()
    }

    private var color: Color {
        let hash = abs(fallbackText.hashValue)
        return Palette.color(at: hash % Palette.sequence.count)
    }
}
