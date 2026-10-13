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
        ShelfContent(
            items: shelf.items,
            notice: shelf.notice,
            retention: retention,
            canAirDrop: shelf.canAirDrop,
            showsRemove: model.optionHeld,
            isDropTargeted: model.isDropTargeted,
            icon: { NSWorkspace.shared.icon(forFile: shelf.fileURL(for: $0).path) },
            dragURL: { shelf.fileURL(for: $0) },
            onAirDropAll: { shelf.airDrop() },
            onOpen: { shelf.open($0) },
            onReveal: { shelf.revealInFinder($0) },
            onAirDrop: { shelf.airDrop([$0]) },
            onRemove: { shelf.remove($0) }
        )
    }
}

/// The shelf from plain values, so it can also be drawn with sample data.
/// Empty, it is one large drop field; with files, a row of big tiles.
struct ShelfContent: View {
    let items: [ShelfItem]
    let notice: String?
    let retention: ShelfRetention
    let canAirDrop: Bool
    let showsRemove: Bool
    let isDropTargeted: Bool
    let icon: (ShelfItem) -> NSImage
    let dragURL: (ShelfItem) -> URL?
    let onAirDropAll: () -> Void
    let onOpen: (ShelfItem) -> Void
    let onReveal: (ShelfItem) -> Void
    let onAirDrop: (ShelfItem) -> Void
    let onRemove: (ShelfItem) -> Void

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                filledState
            }
        }
        .background(
            // Dragging files over the notch lights up the whole shelf.
            RoundedRectangle(cornerRadius: NotchStyle.Card.radius + 4, style: .continuous)
                .fill(isDropTargeted ? NotchStyle.Palette.selection : Color.clear)
        )
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
    }

    private var emptyState: some View {
        VStack(spacing: NotchStyle.Space.s) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: NotchStyle.Shelf.emptySymbol, weight: .light))
                .foregroundStyle(isDropTargeted ? NotchStyle.Palette.primaryText : NotchStyle.Palette.secondaryText)
            Text(isDropTargeted ? "Let go to add" : "Drop files here")
                .font(NotchStyle.Font.title)
                .foregroundStyle(NotchStyle.Palette.primaryText)
            Text(retentionText)
                .font(NotchStyle.Font.subtitle)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NotchCardBackground(radius: NotchStyle.Card.radius + 4).opacity(isDropTargeted ? 0 : 1))
    }

    private var filledState: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.m) {
            HStack(spacing: NotchStyle.Space.m) {
                Text(notice ?? summary)
                    .font(NotchStyle.Font.subtitle)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                    .lineLimit(1)
                Spacer()
                if canAirDrop {
                    Button(action: onAirDropAll) {
                        Label("AirDrop all", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ChipButtonStyle())
                    .help("Send everything on the shelf with AirDrop")
                }
            }
            ViewThatFits(in: .horizontal) {
                tiles
                ScrollView(.horizontal, showsIndicators: false) { tiles }
            }
            Spacer(minLength: 0)
        }
    }

    private var tiles: some View {
        HStack(alignment: .top, spacing: NotchStyle.Space.s) {
            ForEach(items) { item in
                ShelfTile(
                    item: item,
                    icon: icon(item),
                    dragURL: dragURL(item),
                    showsRemove: showsRemove,
                    onOpen: { onOpen(item) },
                    onReveal: { onReveal(item) },
                    onAirDrop: { onAirDrop(item) },
                    onRemove: { onRemove(item) }
                )
            }
        }
    }

    /// "3 files · kept for 1 day"
    private var summary: String {
        let count = items.count == 1 ? "1 file" : "\(items.count) files"
        guard retention != .forever else { return count + " · kept until you remove them" }
        return count + " · kept for \(retention.title)"
    }

    private var retentionText: String {
        guard retention != .forever else { return "They stay until you remove them." }
        return "They stay for \(retention.title)."
    }
}

private struct ShelfTile: View {
    let item: ShelfItem
    let icon: NSImage
    let dragURL: URL?
    let showsRemove: Bool
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onAirDrop: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: NotchStyle.Space.s) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: NotchStyle.Shelf.iconSize, height: NotchStyle.Shelf.iconSize)
            Text(item.filename)
                .font(NotchStyle.Font.tileName)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(height: NotchStyle.Shelf.nameHeight, alignment: .top)
        }
        .padding(.vertical, NotchStyle.Space.m)
        .padding(.horizontal, NotchStyle.Space.xs)
        .frame(width: NotchStyle.Shelf.tileWidth)
        .background(
            RoundedRectangle(cornerRadius: NotchStyle.Card.radius, style: .continuous)
                .fill(isHovered ? NotchStyle.Palette.selection : NotchStyle.Palette.rowBackground)
        )
        .overlay(alignment: .topTrailing) {
            if showsRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: NotchStyle.Shelf.removeSize))
                        .foregroundStyle(NotchStyle.Palette.primaryText, NotchStyle.Palette.removeBackground)
                }
                .buttonStyle(.plain)
                .offset(x: NotchStyle.Space.xs, y: -NotchStyle.Space.xs)
                .accessibilityLabel("Remove \(item.filename)")
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onOpen)
        .onDrag { dragURL.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider() }
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
