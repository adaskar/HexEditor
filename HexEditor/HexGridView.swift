import SwiftUI

struct HexGridView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isOverwriteMode: Bool
    @Binding var hexInputMode: Bool
    var byteGrouping: Int
    @Binding var showSearch: Bool
    @Environment(\.undoManager) var undoManager
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var hexInputHelper = HexInputHelper()
    @StateObject private var bookmarkManager = BookmarkManager()
    @State private var dragStart: Int?
    @Binding var selectionAnchor: Int?
    @Binding var cursorIndex: Int?
    @State private var focusedPane: FocusedPane = .hex
    @State private var showInsertDialog = false
    @State private var insertPosition = 0
    @FocusState private var isFocused: Bool
    
    // Arrow key support

    @State private var scrollProxy: ScrollViewProxy?
    
    enum FocusedPane {
        case hex, ascii
    }
    
    @StateObject private var selectionState = SelectionState()
    
    // Configuration
    let bytesPerRow: Int = 16
    let rowHeight: CGFloat = 20
    let offsetWidth: CGFloat = 80
    let offsetSpacing: CGFloat = 10
    let hexCellWidth: CGFloat = 24
    let hexCellSpacing: CGFloat = 4
    let groupingSpacing: CGFloat = 12
    let dividerWidth: CGFloat = 1
    let asciiCellWidth: CGFloat = 10
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Hex input mode indicator
                if hexInputHelper.isHexInputMode {
                    HStack(spacing: 8) {
                        Image(systemName: "number.circle.fill")
                            .foregroundStyle(.green)
                            .imageScale(.medium)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hex Input Mode")
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                            
                            if !hexInputHelper.partialHexInput.isEmpty {
                                Text("Partial: \(hexInputHelper.partialHexInput)")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text("⌘G to toggle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                            .shadow(color: .green.opacity(0.2), radius: 2, x: 0, y: 1)
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            let totalBytes = document.buffer.count
                            let totalRows = (totalBytes + bytesPerRow - 1) / bytesPerRow
                            
                            ForEach(0..<totalRows, id: \.self) { rowIndex in
                                HexRowView(
                                    rowIndex: rowIndex,
                                    bytesPerRow: bytesPerRow,
                                    byteGrouping: byteGrouping,
                                    document: document,
                                    selection: selection,
                                    bookmarkManager: bookmarkManager,
                                    rowHeight: rowHeight,
                                    offsetWidth: offsetWidth,
                                    offsetSpacing: offsetSpacing,
                                    hexCellWidth: hexCellWidth,
                                    hexCellSpacing: hexCellSpacing,
                                    groupingSpacing: groupingSpacing,
                                    asciiCellWidth: asciiCellWidth,
                                    onCopyHex: { copySelectionAsHex() },
                                    onCopyAscii: { copySelectionAsAscii() },
                                    onPasteHex: { pasteAsHex() },
                                    onPasteAscii: { pasteAsAscii() },
                                    onSelect: { index in
                                        selection = [index]
                                        cursorIndex = index
                                        selectionAnchor = index
                                    },
                                    onInsert: { index in
                                        insertPosition = index
                                        showInsertDialog = true
                                    },
                                    onDelete: {
                                        if !selection.isEmpty {
                                            let sortedIndices = selection.sorted(by: >)
                                            performDelete(indices: sortedIndices)
                                        }
                                    },
                                    onZeroOut: { zeroSelection() },
                                    onToggleBookmark: { index in toggleBookmark(at: index) }
                                )

                                .id(rowIndex)
                            }
                        }
                        .background(Color.clear) // Ensure it captures gestures
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                .onChanged { value in
                                    handleDragGesture(value: value)
                                }
                                .onEnded { _ in
                                    finalizeDrag()
                                }
                        )
                    }
                    .padding(16)
                    .onAppear {
                        self.scrollProxy = proxy
                        self.isFocused = true
                        // Initialize selection state
                        self.selectionState.selection = self.selection
                    }
                }

                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(phases: [.down, .repeat]) { press in
                // Handle arrow keys
                switch press.key {
                case .leftArrow:
                    performArrowKeyMove(.left, withModifiers: press.modifiers)
                    return .handled
                case .rightArrow:
                    performArrowKeyMove(.right, withModifiers: press.modifiers)
                    return .handled
                case .upArrow:
                    performArrowKeyMove(.up, withModifiers: press.modifiers)
                    return .handled
                case .downArrow:
                    performArrowKeyMove(.down, withModifiers: press.modifiers)
                    return .handled
                default:
                    break
                }
                
                // Handle other keys
                return handleKeyPress(press)
            }
        }
        .focused($isFocused)
        .sheet(isPresented: $showInsertDialog) {
            InsertDataView(
                document: document,
                insertPosition: $insertPosition,
                isPresented: $showInsertDialog
            )
        }
        .onChange(of: hexInputMode) { _, newValue in
            // PERFORMANCE: Direct update - already on MainActor
            if hexInputHelper.isHexInputMode != newValue {
                hexInputHelper.isHexInputMode = newValue
                hexInputHelper.clearPartialInput()
            }
        }
        .onChange(of: hexInputHelper.isHexInputMode) { _, newValue in
            // PERFORMANCE: Direct update - already on MainActor
            if hexInputMode != newValue {
                hexInputMode = newValue
            }
        }
        .onChange(of: cursorIndex) { _, newValue in
            // Scroll to cursor position when it changes externally

            if let cursor = newValue, let scrollProxy = scrollProxy, !isInteracting {
                let rowIndex = cursor / bytesPerRow
                scrollProxy.scrollTo(rowIndex)
            }
        }
        .onChange(of: selection) { _, newValue in
            // Sync selection to internal state
            if selectionState.selection != newValue {
                selectionState.selection = newValue
            }
        }
    }
    
    
    // Track if we're actively dragging
    @State private var isDragging = false
    @State private var isInteracting = false // PERFORMANCE: Track interaction to skip auto-scroll
    @State private var lastDragIndex: Int?  // PERFORMANCE: Track last index to avoid redundant updates

    
    private func handleDragGesture(value: DragGesture.Value) {
        let location = value.location
        
        // Calculate index from location
        // Since gesture is on LazyVStack, location is local to content
        
        let relativeX = location.x
        let relativeY = location.y
        
        guard relativeY >= 0 else { return }
        
        let rowIndex = Int(relativeY / rowHeight)
        guard rowIndex >= 0 else { return }
        
        // Determine if we are in Hex or ASCII area
        // Hex area start: offsetWidth + offsetSpacing
        // Hex area end: offsetWidth + offsetSpacing + (bytesPerRow * (hexCellWidth + hexCellSpacing)) + (grouping spacers)
        
        let hexStartX = offsetWidth + offsetSpacing
        
        // Calculate hex width more accurately
        // 16 bytes * 24 width = 384
        // 15 spaces * 4 width = 60
        // (16/grouping - 1) * 4 width = ...
        
        var currentX = hexStartX
        var colIndex = -1
        var isAscii = false
        
        // Check Hex Area
        for i in 0..<bytesPerRow {
            // Grouping spacer
            if i > 0 && i % byteGrouping == 0 {
                currentX += groupingSpacing
            }
            
            if relativeX >= currentX && relativeX < currentX + hexCellWidth + hexCellSpacing {
                colIndex = i
                break
            }
            
            currentX += hexCellWidth + hexCellSpacing
        }
        
        // If not in hex, check ASCII
        // ASCII starts after hex area + spacer + divider + padding
        // Let's approximate or calculate exact start
        // We can just check if x is far enough right
        
        if colIndex == -1 {
            // Calculate where ASCII starts
            // It's after the hex loop finishes
            // Actually let's just use the loop end X
            
            if relativeX > currentX {
                 // Check ASCII
                 let asciiStart = currentX + 10 + 9 // Spacer(10) + Divider area
                 if relativeX >= asciiStart {
                     let asciiCol = Int((relativeX - asciiStart) / asciiCellWidth)
                     if asciiCol >= 0 && asciiCol < bytesPerRow {
                         colIndex = asciiCol
                         isAscii = true
                     }
                 }
            }
        }
        
        // If we found a valid column
        if colIndex != -1 {
            let index = rowIndex * bytesPerRow + colIndex
            if index < document.buffer.count {
                
                // PERFORMANCE: Only update if index changed
                if lastDragIndex == index {
                    return
                }
                lastDragIndex = index
                
                if !isDragging {
                    // Start of drag
                    isDragging = true
                    isInteracting = true
                    dragStart = index
                    selectionAnchor = index
                    cursorIndex = index
                    selection = [index]
                    focusedPane = isAscii ? .ascii : .hex
                    hexInputHelper.clearPartialInput()
                } else {
                    // Continue drag - OPTIMIZED: Only update when index changes
                    if let start = dragStart {
                        let range = min(start, index)...max(start, index)
                        selection = Set(range)
                        cursorIndex = index
                    }
                }
            }
        }
    }
    
    private func finalizeDrag() {
        // When drag ends, if we didn't actually drag, it was just a tap
        // The selection is already set, so just clean up
        dragStart = nil
        isDragging = false
        isInteracting = false
        lastDragIndex = nil  // PERFORMANCE: Clear cached index
    }
    
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        // Handle modifier commands first
        if press.modifiers.contains(.command) {
            switch press.key {
            case "a", "A":
                // Select all
                DispatchQueue.main.async {
                    self.selection = Set(0..<self.document.buffer.count)
                    self.selectionAnchor = 0
                    self.cursorIndex = self.document.buffer.count - 1
                }
                return .handled
            case "x", "X":
                // Cut selection
                copySelectionAsHex()
                if !selection.isEmpty {
                    let sortedIndices = selection.sorted(by: >)
                    DispatchQueue.main.async {
                        self.performDelete(indices: sortedIndices)
                    }
                }
                return .handled
            case "d", "D":
                // Duplicate selection
                if !selection.isEmpty {
                    let sortedIndices = selection.sorted()
                    let bytes = sortedIndices.map { document.buffer[$0] }
                    if let lastIndex = sortedIndices.last {
                        DispatchQueue.main.async {
                            var currentIndex = lastIndex + 1
                            for byte in bytes {
                                self.performInsert(byte, at: currentIndex)
                                currentIndex += 1
                            }
                        }
                    }
                }
                return .handled
            case "c", "C":
                if press.modifiers.contains(.shift) {
                    copySelectionAsAscii()
                } else {
                    copySelectionAsHex()
                }
                return .handled
            case "v", "V":
                if press.modifiers.contains(.shift) {
                    pasteAsAscii()
                } else {
                    pasteAsHex()
                }
                return .handled
            case "0":
                DispatchQueue.main.async {
                    self.zeroSelection()
                }
                return .handled
            case "g", "G":
                DispatchQueue.main.async {
                    self.hexInputHelper.toggleMode()
                    self.hexInputMode = self.hexInputHelper.isHexInputMode
                }
                return .handled
            case "b", "B":
                DispatchQueue.main.async {
                    let currentCursor = self.cursorIndex ?? self.selection.max() ?? 0 // Re-capture
                    self.toggleBookmark(at: currentCursor)
                }
                return .handled
            case "f", "F":
                DispatchQueue.main.async {
                    self.showSearch = true
                }
                return .handled
            case "z", "Z":
                // Let system handle undo
                return .ignored
            default:
                break
            }
        }
        
        // Helper to update selection based on movement
        func moveSelection(to newIndex: Int) {
            DispatchQueue.main.async {
                let currentCursor = self.cursorIndex ?? self.selection.max() ?? 0 // Re-capture
                if press.modifiers.contains(.shift) {
                    // Extend selection
                    let anchor = self.selectionAnchor ?? currentCursor
                    self.selectionAnchor = anchor // Ensure anchor is set
                    self.cursorIndex = newIndex
                    
                    let range = min(anchor, newIndex)...max(anchor, newIndex)
                    self.selection = Set(range)
                } else {
                    // Move selection
                    self.selection = [newIndex]
                    self.selectionAnchor = newIndex
                    self.cursorIndex = newIndex
                }
                self.hexInputHelper.clearPartialInput()
            }
        }
        
        switch press.key {
        case .delete: // Backspace
            DispatchQueue.main.async {
                if self.selection.count > 1 {
                    let sortedIndices = self.selection.sorted(by: >)
                    self.performDelete(indices: sortedIndices)
                } else {
                    if let singleIndex = self.selection.first, singleIndex > 0 {
                        self.performDelete(indices: [singleIndex - 1])
                    }
                }
                self.hexInputHelper.clearPartialInput()
            }
            return .handled
            
        case .deleteForward: // Delete
            if !selection.isEmpty {
                let sortedIndices = selection.sorted(by: >)
                DispatchQueue.main.async {
                    self.performDelete(indices: sortedIndices)
                    self.hexInputHelper.clearPartialInput()
                }
                return .handled
            }
            
        case .tab:
            // Toggle between hex and ASCII pane
            DispatchQueue.main.async {
                self.focusedPane = self.focusedPane == .hex ? .ascii : .hex
            }
            return .handled
            
        case .escape:
            DispatchQueue.main.async {
                self.hexInputHelper.clearPartialInput()
            }
            return .handled
            
        default:
            // Handle character input
            if let char = press.characters.first {
                if hexInputHelper.isHexInputMode {
                    // Hex input mode
                    if hexInputHelper.isValidHexChar(char) {
                        // Defer processing to avoid publishing changes during view updates
                        DispatchQueue.main.async {
                            // Re-capture cursor to get the LATEST position after previous insertions
                            let latestCursor = self.cursorIndex ?? self.selection.max() ?? 0
                            
                            if let byte = self.hexInputHelper.processHexCharacter(char) {
                                // We have a complete hex byte
                                if self.isOverwriteMode {
                                    self.performReplace(at: latestCursor, with: byte)
                                    let nextIndex = min(latestCursor + 1, self.document.buffer.count - 1)
                                    self.selection = [nextIndex]
                                    self.cursorIndex = nextIndex
                                    self.selectionAnchor = nextIndex
                                } else {
                                    self.performInsert(byte, at: latestCursor)
                                }
                            }
                        }
                        return .handled
                    }
                } else {
                    // ASCII input mode
                    if char.isASCII {
                        let byte = UInt8(char.asciiValue!)
                        
                        // Handle Backspace (127) explicitly if it wasn't caught by .delete
                        if byte == 127 {
                            DispatchQueue.main.async {
                                if self.selection.count > 1 {
                                    let sortedIndices = self.selection.sorted(by: >)
                                    self.performDelete(indices: sortedIndices)
                                } else {
                                    if let singleIndex = self.selection.first, singleIndex > 0 {
                                        self.performDelete(indices: [singleIndex - 1])
                                    }
                                }
                                self.hexInputHelper.clearPartialInput()
                            }
                            return .handled
                        }
                        
                        // Ignore control characters (0-31)
                        if byte < 32 {
                            return .handled
                        }
                        
                        // ASCII input - process synchronously
                        DispatchQueue.main.async {
                            let currentCursor = self.cursorIndex ?? self.selection.max() ?? 0 // Re-capture
                            if self.isOverwriteMode && currentCursor < self.document.buffer.count {
                                // Overwrite mode: replace existing byte
                                self.performReplace(at: currentCursor, with: byte)
                                let nextIndex = min(currentCursor + 1, self.document.buffer.count)
                                self.selection = [nextIndex]
                                self.cursorIndex = nextIndex
                                self.selectionAnchor = nextIndex
                            } else {
                                // Insert mode: insert new byte
                                self.performInsert(byte, at: currentCursor)
                            }
                        }
                        return .handled
                    }
                }
            }
        }
        
        return .ignored
    }
    
    private func toggleBookmark(at index: Int) {
        if bookmarkManager.hasBookmark(at: index) {
            bookmarkManager.removeBookmark(at: index)
        } else {
            bookmarkManager.addBookmark(offset: index, name: "Bookmark at 0x\(String(format: "%X", index))")
        }
    }
    
    private func zeroSelection() {
        guard !selection.isEmpty else { return }
        // Zero out all selected bytes
        // UndoManager groups by event loop usually for undo operations.
        for index in self.selection {
            self.performReplace(at: index, with: 0)
        }
    }
    
    private func performReplace(at index: Int, with byte: UInt8) {
        document.replace(at: index, with: byte, undoManager: undoManager)
    }
    
    private func copySelectionAsHex() {
        guard !selection.isEmpty else { return }
        let sortedIndices = selection.sorted()
        let bytes = sortedIndices.map { document.buffer[$0] }
        let hexString = bytes.map { String(format: "%02X", $0) }.joined()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hexString, forType: .string)
    }

    private func copySelectionAsAscii() {
        guard !selection.isEmpty else { return }
        let sortedIndices = selection.sorted()
        let bytes = sortedIndices.map { document.buffer[$0] }
        let asciiString = bytes.map { byte in
            if byte >= 32 && byte <= 126 {
                return String(UnicodeScalar(byte))
            } else {
                return "·"
            }
        }.joined()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(asciiString, forType: .string)
    }
    
    private func pasteBytes(_ bytes: [UInt8]) {
        guard let index = selection.max() else { return }
        guard !bytes.isEmpty else { return }
        
        DispatchQueue.main.async {
            if self.isOverwriteMode {
                self.document.replace(bytes: bytes, at: index, undoManager: self.undoManager)
            } else {
                self.document.insert(bytes: bytes, at: index, undoManager: self.undoManager)
            }
            
            let newIndex = index + bytes.count
            self.selection = [newIndex]
            self.cursorIndex = newIndex
            self.selectionAnchor = newIndex
        }
    }
    
    private func pasteAsHex() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            // Filter for valid hex characters
            let hexChars = string.uppercased().filter { "0123456789ABCDEF".contains($0) }
            
            // Must have even number of chars for valid hex bytes
            // If odd, we can either drop the last one or prepend 0. Let's drop last one for now or just process pairs.
            var bytes: [UInt8] = []
            var currentIndex = hexChars.startIndex
            
            while currentIndex < hexChars.endIndex {
                let nextIndex = hexChars.index(after: currentIndex)
                if nextIndex < hexChars.endIndex {
                    let pair = hexChars[currentIndex...nextIndex]
                    if let byte = UInt8(pair, radix: 16) {
                        bytes.append(byte)
                    }
                    currentIndex = hexChars.index(after: nextIndex)
                } else {
                    break
                }
            }
            
            pasteBytes(bytes)
        }
    }
    
    private func pasteAsAscii() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            if let data = string.data(using: .utf8) {
                let bytes = [UInt8](data)
                pasteBytes(bytes)
            }
        }
    }
    
    private func performInsert(_ byte: UInt8, at index: Int) {
        document.insert(byte, at: index, undoManager: undoManager)
        let newIndex = index + 1
        selection = [newIndex]
        cursorIndex = newIndex
        selectionAnchor = newIndex
    }
    
    private enum ArrowDirection {
        case up, down, left, right
    }
    
    private func performArrowKeyMove(_ direction: ArrowDirection, withModifiers modifiers: EventModifiers) {
        DispatchQueue.main.async {
            let currentCursor = self.cursorIndex ?? self.selection.max() ?? 0

            func moveSelection(to newIndex: Int) {
                if modifiers.contains(.shift) {
                    // Extend selection
                    let anchor = self.selectionAnchor ?? currentCursor
                    self.selectionAnchor = anchor
                    self.cursorIndex = newIndex

                    let range = min(anchor, newIndex)...max(anchor, newIndex)
                    self.selection = Set(range)
                } else {
                    // Move selection
                    self.selection = [newIndex]
                    self.selectionAnchor = newIndex
                    self.cursorIndex = newIndex
                }
                self.hexInputHelper.clearPartialInput()
            }

            switch direction {
            case .left:
                if currentCursor > 0 {
                    moveSelection(to: currentCursor - 1)
                }
            case .right:
                if currentCursor < self.document.buffer.count {
                    moveSelection(to: currentCursor + 1)
                }
            case .up:
                if currentCursor >= self.bytesPerRow {
                    moveSelection(to: currentCursor - self.bytesPerRow)
                }
            case .down:
                if currentCursor + self.bytesPerRow < self.document.buffer.count {
                    moveSelection(to: currentCursor + self.bytesPerRow)
                }
            }
        }
    }
    
    private func performDelete(indices: [Int]) {
        // Indices must be sorted descending
        guard let firstIndex = indices.last else { return } // The smallest index
        
        self.document.delete(indices: indices, undoManager: self.undoManager)
        
        // Select the point where deletion happened (smallest index)
        // Ensure we don't go out of bounds if we deleted the last byte
        let newCursor = min(firstIndex, self.document.buffer.count)
        self.selection = [newCursor]
        self.cursorIndex = newCursor
        self.selectionAnchor = newCursor
    }
}



