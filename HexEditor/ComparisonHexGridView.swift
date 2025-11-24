import SwiftUI

struct ComparisonHexGridView: View {
    @ObservedObject var document: HexDocument
    var diffResult: EnhancedDiffResult?
    var isLeftSide: Bool
    @Binding var scrollTarget: ComparisonContentView.ScrollTarget?
    var showOnlyDifferences: Bool
    var currentBlockIndex: Int
    
    @State private var scrollPosition: Int?
    @State private var highlightedOffset: Int?
    
    let bytesPerRow = 16
    let rowHeight: CGFloat = 20
    
    // Cache for diff-only rows to avoid recalculating on every scroll
    @State private var cachedDiffRows: [RowData] = []
    @State private var lastDiffResultId: UUID?
    
    struct RowData: Identifiable {
        let id: Int
        let offset: Int
        let bytes: [UInt8]
        let isDiffBlock: Bool
        let isCollapsedRegion: Bool
        let collapsedByteCount: Int?
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if showOnlyDifferences {
                        // Diff Only Mode: Use cached rows
                        ForEach(cachedDiffRows) { rowData in
                            if rowData.isCollapsedRegion {
                                collapsedRegionView(rowData: rowData)
                            } else {
                                rowView(rowData: rowData)
                            }
                        }
                    } else {
                        // Full Mode: Generate rows on demand
                        let totalBytes = document.buffer.count
                        let totalRows = (totalBytes + bytesPerRow - 1) / bytesPerRow
                        
                        ForEach(0..<totalRows, id: \.self) { rowIndex in
                            rowView(for: rowIndex, totalBytes: totalBytes)
                        }
                    }
                }
                .padding(8)
            }
            .onChange(of: scrollTarget) { oldValue, newValue in
                if let target = newValue {
                    let targetRow: Int
                    if showOnlyDifferences {
                        // Find the row index in cachedDiffRows
                        if let index = cachedDiffRows.firstIndex(where: { $0.offset <= target.offset && ($0.offset + bytesPerRow) > target.offset }) {
                            targetRow = index // This is actually the ID/index in the list
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(cachedDiffRows[index].id, anchor: .center)
                            }
                        } else {
                            return
                        }
                    } else {
                        targetRow = target.offset / bytesPerRow
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(targetRow, anchor: .center)
                        }
                    }
                    
                    // Flash highlight
                    highlightedOffset = target.offset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            highlightedOffset = nil
                        }
                    }
                }
            }
            .onChange(of: diffResult?.blocks) { _, _ in
                updateCachedDiffRows()
            }
            .onChange(of: showOnlyDifferences) { _, _ in
                updateCachedDiffRows()
            }
            .onAppear {
                updateCachedDiffRows()
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private func updateCachedDiffRows() {
        guard showOnlyDifferences, let diff = diffResult else { return }
        cachedDiffRows = createDiffOnlyRows(diff: diff)
    }
    
    @ViewBuilder
    private func collapsedRegionView(rowData: RowData) -> some View {
        HStack {
            Image(systemName: "ellipsis")
                .foregroundColor(.secondary)
                .frame(width: 70)
            
            Text("\(rowData.collapsedByteCount ?? 0) matching bytes")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .id(rowData.id)
    }
    
    private func rowView(for rowIndex: Int, totalBytes: Int) -> some View {
        let offset = rowIndex * bytesPerRow
        let remainingBytes = totalBytes - offset
        let bytesToRead = min(bytesPerRow, remainingBytes)
        
        // Efficiently read bytes
        // Note: GapBuffer.subscript is fast, but we could add a batch read method to GapBuffer for even better perf
        var bytes = [UInt8]()
        bytes.reserveCapacity(bytesToRead)
        for i in 0..<bytesToRead {
            bytes.append(document.buffer[offset + i])
        }
        
        let rowData = RowData(
            id: rowIndex,
            offset: offset,
            bytes: bytes,
            isDiffBlock: false, // Not used in full view for layout, only for coloring
            isCollapsedRegion: false,
            collapsedByteCount: nil
        )
        
        return rowView(rowData: rowData)
    }
    
    @ViewBuilder
    private func rowView(rowData: RowData) -> some View {
        let isHighlighted = isRowHighlighted(rowData: rowData)
        
        HStack(spacing: 8) {
            // Offset
            Text(String(format: "%08X", rowData.offset))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            // Hex bytes
            HStack(spacing: 4) {
                ForEach(0..<bytesPerRow, id: \.self) { byteIndex in
                    if byteIndex < rowData.bytes.count {
                        let globalOffset = rowData.offset + byteIndex
                        let byte = rowData.bytes[byteIndex]
                        let (textColor, bgColor) = getByteColors(at: globalOffset)
                        
                        Text(String(format: "%02X", byte))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(textColor)
                            .frame(width: 22, height: rowHeight)
                            .background(bgColor)
                            .cornerRadius(2)
                    } else {
                        Text("  ")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 22, height: rowHeight)
                    }
                }
            }
            
            Spacer()
            
            // ASCII representation
            HStack(spacing: 0) {
                ForEach(0..<bytesPerRow, id: \.self) { byteIndex in
                    if byteIndex < rowData.bytes.count {
                        let globalOffset = rowData.offset + byteIndex
                        let byte = rowData.bytes[byteIndex]
                        let char = (byte >= 32 && byte < 127) ? String(UnicodeScalar(byte)) : "."
                        let (textColor, _) = getByteColors(at: globalOffset)
                        
                        Text(char)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(textColor)
                            .frame(width: 8)
                    } else {
                        Text(" ")
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 8)
                    }
                }
            }
            .padding(.leading, 8)
        }
        .frame(height: rowHeight)
        .padding(.horizontal, 4)
        .background(isHighlighted ? Color.yellow.opacity(0.4) : Color.clear)
        .id(rowData.id)
    }
    
    private func isRowHighlighted(rowData: RowData) -> Bool {
        guard let highlightOffset = highlightedOffset else { return false }
        let rowRange = rowData.offset..<(rowData.offset + rowData.bytes.count)
        return rowRange.contains(highlightOffset)
    }
    
    private func getByteColors(at offset: Int) -> (text: Color, background: Color) {
        guard let diff = diffResult else {
            return (.primary, .clear)
        }
        
        // Optimization: Use binary search to find the block
        // Blocks are sorted by range.lowerBound
        
        var foundBlock: DiffBlock? = nil
        var blockIndex: Int? = nil
        
        // Binary search
        var low = 0
        var high = diff.blocks.count - 1
        
        while low <= high {
            let mid = (low + high) / 2
            let block = diff.blocks[mid]
            
            if block.range.contains(offset) {
                foundBlock = block
                blockIndex = mid
                break
            } else if block.range.lowerBound > offset {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }
        
        guard let block = foundBlock, let idx = blockIndex else {
            return (.primary, .clear)
        }
        
        let isCurrentBlock = (idx == currentBlockIndex)
        
        switch block.type {
        case .modified:
            return (.white, isCurrentBlock ? Color.red.opacity(0.9) : Color.red.opacity(0.6))
        case .onlyInFirst:
            if isLeftSide {
                return (.white, isCurrentBlock ? Color.orange.opacity(0.9) : Color.orange.opacity(0.6))
            }
        case .onlyInSecond:
            if !isLeftSide {
                return (.white, isCurrentBlock ? Color.green.opacity(0.9) : Color.green.opacity(0.6))
            }
        }
        
        return (.primary, .clear)
    }
    
    private func createDiffOnlyRows(diff: EnhancedDiffResult) -> [RowData] {
        var rows: [RowData] = []
        let totalBytes = document.buffer.count
        
        if diff.blocks.isEmpty {
            // Show message that files are identical
            return [
                RowData(
                    id: 0,
                    offset: 0,
                    bytes: [],
                    isDiffBlock: false,
                    isCollapsedRegion: true,
                    collapsedByteCount: totalBytes
                )
            ]
        }
        
        var currentOffset = 0
        
        for block in diff.blocks {
            // Add collapsed region for gap before this block
            if currentOffset < block.range.lowerBound {
                let gapSize = block.range.lowerBound - currentOffset
                rows.append(RowData(
                    id: rows.count,
                    offset: currentOffset,
                    bytes: [],
                    isDiffBlock: false,
                    isCollapsedRegion: true,
                    collapsedByteCount: gapSize
                ))
                currentOffset = block.range.lowerBound
            }
            
            // Add rows for this diff block
            let blockStart = block.range.lowerBound
            let blockEnd = min(block.range.upperBound, totalBytes - 1)
            let blockSize = blockEnd - blockStart + 1
            
            let blockRows = (blockSize + bytesPerRow - 1) / bytesPerRow
            for rowInBlock in 0..<blockRows {
                let rowOffset = blockStart + rowInBlock * bytesPerRow
                let remainingInBlock = blockEnd - rowOffset + 1
                let bytesToRead = min(bytesPerRow, remainingInBlock)
                
                var bytes: [UInt8] = []
                for i in 0..<bytesToRead {
                    if rowOffset + i < totalBytes {
                        bytes.append(document.buffer[rowOffset + i])
                    }
                }
                
                rows.append(RowData(
                    id: rows.count,
                    offset: rowOffset,
                    bytes: bytes,
                    isDiffBlock: true,
                    isCollapsedRegion: false,
                    collapsedByteCount: nil
                ))
            }
            
            currentOffset = blockEnd + 1
        }
        
        // Add collapsed region for remaining bytes after last block
        if currentOffset < totalBytes {
            let gapSize = totalBytes - currentOffset
            rows.append(RowData(
                id: rows.count,
                offset: currentOffset,
                bytes: [],
                isDiffBlock: false,
                isCollapsedRegion: true,
                collapsedByteCount: gapSize
            ))
        }
        
        return rows
    }
}
