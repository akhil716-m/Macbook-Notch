import AppKit
import NotchCore
import SwiftUI

/// The Clipboard tool: everything you copied, newest first. Click a row to
/// copy it again; hold ⌥ to show delete buttons.
struct ClipboardPanel: View {
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var model: NotchViewModel

    var body: some View {
        ClipboardContent(
            clips: clipboard.clips,
            thumbnail: { $0.kind == .image ? clipboard.thumbnail(for: $0) : nil },
            recentlyCopiedID: clipboard.recentlyCopiedID,
            showsRemove: model.optionHeld,
            onCopy: { clipboard.copy($0) },
            onRemove: { clipboard.remove($0) }
        )
    }
}

/// The history from plain values, so it can also be drawn with sample data.
/// Rows sit straight on the panel and light up under the pointer.
struct ClipboardContent: View {
    let clips: [Clip]
    let thumbnail: (Clip) -> NSImage?
    let recentlyCopiedID: UUID?
    let showsRemove: Bool
    let onCopy: (Clip) -> Void
    let onRemove: (Clip) -> Void

    var body: some View {
        if clips.isEmpty {
            EmptyToolState(
                symbol: "doc.on.clipboard",
                title: "Nothing copied yet",
                message: "Copy text, links, images or files and they'll collect here."
            )
        } else {
            // A short history needs no scroller (and measuring a long one to
            // find out would lay out every row).
            Group {
                if clips.count <= NotchStyle.Clipboard.rowsWithoutScrolling {
                    VStack(spacing: 0) { rows }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) { rows }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var rows: some View {
        ForEach(clips) { clip in
            ClipRow(
                clip: clip,
                thumbnail: thumbnail(clip),
                justCopied: recentlyCopiedID == clip.id,
                showsRemove: showsRemove,
                onCopy: { onCopy(clip) },
                onRemove: { onRemove(clip) }
            )
        }
    }
}

private struct ClipRow: View {
    let clip: Clip
    let thumbnail: NSImage?
    let justCopied: Bool
    let showsRemove: Bool
    let onCopy: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: NotchStyle.Space.m) {
            leading
                .frame(width: NotchStyle.Clipboard.leadingSize, height: NotchStyle.Clipboard.leadingSize)
                .clipShape(RoundedRectangle(cornerRadius: NotchStyle.Clipboard.leadingRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(NotchStyle.Font.rowTitle)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.tertiaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: NotchStyle.Space.xs)

            if justCopied {
                Label("Copied", systemImage: "checkmark")
                    .font(NotchStyle.Font.chip)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .transition(.opacity)
            } else if showsRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: NotchStyle.Shelf.removeSize))
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            }
        }
        .padding(.horizontal, NotchStyle.Space.s)
        .padding(.vertical, NotchStyle.Space.xs + 1)
        .background(
            RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                .fill(isHovered ? NotchStyle.Palette.rowBackground : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onCopy)
        .contextMenu {
            Button("Copy", action: onCopy)
            Button("Delete", role: .destructive, action: onRemove)
        }
        .animation(.easeOut(duration: 0.15), value: justCopied)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Copies this again")
    }

    @ViewBuilder
    private var leading: some View {
        switch clip.kind {
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                symbol("photo")
            }
        case .files:
            if let first = clip.filePaths?.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first))
                    .resizable()
            } else {
                symbol("doc")
            }
        case .link:
            symbol("link")
        case .text:
            symbol("text.alignleft")
        }
    }

    private func symbol(_ name: String) -> some View {
        ZStack {
            NotchStyle.Palette.placeholder
            Image(systemName: name)
                .font(.system(size: NotchStyle.Clipboard.symbolSize))
                .foregroundStyle(NotchStyle.Palette.secondaryText)
        }
    }

    private var title: String {
        switch clip.kind {
        case .text, .link:
            return ClipText.preview(clip.text ?? "", maxLength: 160)
        case .image:
            return "Image"
        case .files:
            let paths = clip.filePaths ?? []
            let first = paths.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Files"
            return paths.count > 1 ? "\(first) and \(paths.count - 1) more" : first
        }
    }

    private var subtitle: String {
        let when = clip.copiedAt.formatted(.relative(presentation: .named))
        guard let app = clip.sourceAppName, !app.isEmpty else { return when }
        return "\(app) · \(when)"
    }
}
