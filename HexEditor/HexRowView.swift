import SwiftUI
import Combine

class SelectionState: ObservableObject {
    @Published var selection: Set<Int> = []
}

struct HexRowView: View {
    let rowIndex: Int
    let bytesPerRow: Int
    let byteGrouping: Int
    @ObservedObject var document: HexDocument
    @ObservedObject var selectionState: SelectionState
    @ObservedObject var bookmarkManager: BookmarkManager
    
    // Configuration
    let rowHeight: CGFloat
    let offsetWidth: CGFloat
    let offsetSpacing: CGFloat
    let hexCellWidth: CGFloat
    let hexCellSpacing: CGFloat
    let groupingSpacing: CGFloat
    let asciiCellWidth: CGFloat
    
    // Actions
    var onCopyHex: () -> Void
    var onCopyAscii: () -> Void
    var onPasteHex: () -> Void
    var onPasteAscii: () -> Void
    var onSelect: (Int) -> Void
    var onInsert: (Int) -> Void
    var onDelete: () -> Void
    var onZeroOut: () -> Void
    var onToggleBookmark: (Int) -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Offset
            Text(String(format: "%08X", rowIndex * bytesPerRow))
                .font(.monospaced(.caption)())
                .foregroundColor(ByteColorScheme.offsetColor)
                .frame(width: offsetWidth, alignment: .leading)
            
            Spacer().frame(width: offsetSpacing)
            
            // Hex Bytes
            HStack(spacing: 0) {
                ForEach(0..<bytesPerRow, id: \.self) { byteIndex in
                    let index = rowIndex * bytesPerRow + byteIndex
                    
                    // Add extra spacing for grouping
                    if byteIndex > 0 && byteIndex % byteGrouping == 0 {
                        Spacer().frame(width: groupingSpacing)
                    }
                    
                    if index < document.buffer.count {
                        let byte = document.buffer[index]
                        let isSelected = selectionState.selection.contains(index)
                        let hasBookmark = bookmarkManager.hasBookmark(at: index)
                        
                        Text(ByteColorScheme.hexString(for: byte))
                            .font(.monospaced(.body)())
                            .foregroundColor(isSelected ?
                                             ByteColorScheme.selectionTextColor :
                                                ByteColorScheme.color(for: byte, colorScheme: colorScheme))
                            .frame(width: hexCellWidth, height: rowHeight, alignment: .center)
                            .background(
                                ZStack {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(ByteColorScheme.selectionColor)
                                    }
                                    if hasBookmark {
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.yellow, lineWidth: 2)
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                            .contextMenu {
                                contextMenuContent(for: index)
                            }
                    } else {
                        Text("  ")
                            .font(.monospaced(.body)())
                            .frame(width: hexCellWidth, height: rowHeight)
                    }
                    
                    if byteIndex < bytesPerRow - 1 {
                        Spacer().frame(width: hexCellSpacing)
                    }
                }
            }
            
            Spacer().frame(width: 10)
            
            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)
            
            // ASCII
            HStack(spacing: 0) {
                ForEach(0..<bytesPerRow, id: \.self) { byteIndex in
                    let index = rowIndex * bytesPerRow + byteIndex
                    if index < document.buffer.count {
                        let byte = document.buffer[index]
                        let char = (byte >= 32 && byte <= 126) ? String(UnicodeScalar(byte)) : "·"
                        let isSelected = selectionState.selection.contains(index)
                        
                        Text(char)
                            .font(.monospaced(.body)())
                            .foregroundColor(isSelected ?
                                             ByteColorScheme.selectionTextColor :
                                                ByteColorScheme.color(for: byte, colorScheme: colorScheme))
                            .frame(width: asciiCellWidth, height: rowHeight, alignment: .center)
                            .background(isSelected ? ByteColorScheme.selectionColor : Color.clear)
                            .contentShape(Rectangle())
                            .contextMenu {
                                contextMenuContent(for: index)
                            }
                    } else {
                        Text(" ")
                            .font(.monospaced(.body)())
                            .frame(width: asciiCellWidth, height: rowHeight)
                    }
                }
            }
            Spacer()
        }
        .frame(height: rowHeight)
    }
    
    @ViewBuilder
    private func contextMenuContent(for index: Int) -> some View {
        // Copy Hex operation
        Button(action: {
            if !selectionState.selection.contains(index) {
                onSelect(index)
            }
            onCopyHex()
        }) {
            Label("Copy Hex", systemImage: "doc.on.doc")
        }
        .keyboardShortcut("c", modifiers: .command)

        // Copy ASCII operation
        Button(action: {
            if !selectionState.selection.contains(index) {
                onSelect(index)
            }
            onCopyAscii()
        }) {
            Label("Copy ASCII", systemImage: "text.quote")
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])
        
        // Paste Hex operation
        Button(action: {
            if !selectionState.selection.contains(index) {
                onSelect(index)
            }
            onPasteHex()
        }) {
            Label("Paste Hex", systemImage: "doc.on.clipboard")
        }
        .keyboardShortcut("v", modifiers: .command)
        
        // Paste ASCII operation
        Button(action: {
            if !selectionState.selection.contains(index) {
                onSelect(index)
            }
            onPasteAscii()
        }) {
            Label("Paste ASCII", systemImage: "doc.on.clipboard")
        }
        .keyboardShortcut("v", modifiers: [.command, .shift])
        
        // Insert operation
        Button(action: {
            onInsert(index)
        }) {
            Label("Insert...", systemImage: "plus.square")
        }
        .keyboardShortcut("i", modifiers: .command)
        
        Divider()
        
        // Delete operation
        Button(action: {
            if !selectionState.selection.contains(index) {
                onSelect(index)
            }
            onDelete()
        }) {
            Label("Delete", systemImage: "trash")
        }
        
        // Zero out operation
        Button(action: {
            if !selectionState.selection.contains(index) {
                onSelect(index)
            }
            onZeroOut()
        }) {
            Label("Zero Out", systemImage: "0.circle")
        }
        .keyboardShortcut("0", modifiers: .command)
        
        Divider()
        
        // Bookmark operation
        Button(action: { onToggleBookmark(index) }) {
            let hasBookmark = bookmarkManager.hasBookmark(at: index)
            Label(hasBookmark ? "Remove Bookmark" : "Add Bookmark",
                  systemImage: hasBookmark ? "bookmark.slash" : "bookmark")
        }
        .keyboardShortcut("b", modifiers: .command)
    }
}
