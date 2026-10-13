import AppKit
import NotchCore
import SwiftUI

/// The Shelf tool: files parked on the notch. Click to open, drag out to
/// use, right-click for more, hold ⌥ to show remove buttons.
struct ShelfPanel: View {
    @ObservedObject var shelf: ShelfService
    @ObservedObject var model: NotchViewModel
    let retention: ShelfRetention

    var body: some View {
        ZStack {
            if shelf.items.isEmpty {
                emptyState
            } else {
                filledState
            }
            if model.isDropTargeted {
                RoundedRectangle(cornerRadius: NotchStyle.Shelf.dropRadius, style: .continuous)
                    .strokeBorder(NotchStyle.Palette.dropOutline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .allowsHitTesting(false)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: NotchStyle.Space.xs) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: NotchStyle.Controls.playSize))
                .foregroundStyle(NotchStyle.Palette.secondaryText)
            Text(model.isDropTargeted ? "Let go to add" : "Drop files here")
                .font(NotchStyle.Font.emptyTitle)
                .foregroundStyle(NotchStyle.Palette.primaryText)
            Text(retentionText)
                .font(NotchStyle.Font.emptyBody)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filledState: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            HStack(spacing: NotchStyle.Space.m) {
                Text(shelf.notice ?? countText)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                    .lineLimit(1)
                Spacer()
                if shelf.canAirDrop {
                    Button {
                        shelf.airDrop()
                    } label: {
                        Label("AirDrop", systemImage: "square.and.arrow.up")
                            .font(NotchStyle.Font.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .help("Send everything on the shelf with AirDrop")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: NotchStyle.Space.m) {
                    ForEach(shelf.items) { item in
                        ShelfTile(
                            item: item,
                            url: shelf.fileURL(for: item),
                            showsRemove: model.optionHeld,
                            onOpen: { shelf.open(item) },
                            onReveal: { shelf.revealInFinder(item) },
                            onAirDrop: { shelf.airDrop([item]) },
                            onRemove: { shelf.remove(item) }
                        )
                    }
                }
            }
        }
    }

    private var countText: String {
        shelf.items.count == 1 ? "1 item" : "\(shelf.items.count) items"
    }

    private var retentionText: String {
        guard retention != .forever else { return "They stay until you remove them." }
        return "They stay for \(retention.title)."
    }
}

private struct ShelfTile: View {
    let item: ShelfItem
    let url: URL
    let showsRemove: Bool
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onAirDrop: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: NotchStyle.Space.xs) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: NotchStyle.Shelf.iconSize, height: NotchStyle.Shelf.iconSize)
            Text(item.filename)
                .font(NotchStyle.Font.tileName)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
        }
        .frame(width: NotchStyle.Shelf.tileWidth)
        .overlay(alignment: .topTrailing) {
            if showsRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: NotchStyle.Shelf.removeSize))
                        .foregroundStyle(NotchStyle.Palette.primaryText, NotchStyle.Palette.removeBackground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.filename)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open", action: onOpen)
            Button("Show in Finder", action: onReveal)
            Button("AirDrop", action: onAirDrop)
            Divider()
            Button("Remove from Shelf", role: .destructive, action: onRemove)
        }
        .help(item.filename)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the file. Drag it out to use it elsewhere.")
    }
}
