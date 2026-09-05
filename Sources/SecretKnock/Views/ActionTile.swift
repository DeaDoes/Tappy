import SwiftUI

/// The gradient card every action screen is built from. Same tile in three
/// sizes: the knock slots, the picker grid, and the library grid.
struct ActionTile: View {
    let card: ActionCard
    var eyebrow: String? = nil
    var badge: Badge? = nil
    var height: CGFloat = 150
    var showsSubtitle = true
    var trailing: AnyView? = nil
    let onTap: () -> Void

    struct Badge: Equatable {
        var text: String
        var symbol: String? = "checkmark"
    }

    @State private var isHovering = false

    // The tile is one button, and `trailing` is a sibling laid over it — never
    // a child. A Button inside another Button's label never sees the click on
    // macOS; the outer one swallows it, which left the "Test" pill dead.
    var body: some View {
        ZStack(alignment: .topTrailing) {
            tile
            if let trailing { trailing.padding(12) }
        }
        .frame(height: height)
    }

    private var tile: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: card.symbol)
                        .font(.system(size: iconSize, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer(minLength: 12)

                    if let eyebrow {
                        Text(eyebrow)
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.bottom, 2)
                    }
                    Text(card.title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(.white)
                    if showsSubtitle {
                        Text(card.subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 3)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(18)

                // Reserve the pill's width so a long title never runs under it.
                HStack(spacing: 6) {
                    if let badge { badgeView(badge) }
                    if trailing != nil { Color.clear.frame(width: 46, height: 22) }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(card.tint.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(isHovering ? 0.35 : 0), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isHovering ? 0.28 : 0.16), radius: isHovering ? 14 : 7, y: 4)
            .scaleEffect(isHovering ? 1.012 : 1)
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(card.title)
        .accessibilityHint(card.subtitle)
    }

    private var iconSize: CGFloat { height >= 190 ? 40 : 30 }
    private var titleSize: CGFloat { height >= 190 ? 22 : 16 }

    private func badgeView(_ badge: Badge) -> some View {
        HStack(spacing: 3) {
            if let symbol = badge.symbol { Image(systemName: symbol).font(.caption2.bold()) }
            Text(badge.text).font(.caption).fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(.white.opacity(0.22), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
    }
}

/// A small pill button that sits on a tile without swallowing the tile's own
/// tap — used for "Test" on the knock slots.
struct TilePillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(.white.opacity(0.22), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
