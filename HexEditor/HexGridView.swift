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
    
    // Arrow key press-and-hold support
    @State private var arrowKeyTimer: Timer?
    @State private var currentArrowDirection: ArrowDirection?
    @State private var scrollProxy: ScrollViewProxy?
    
    enum ArrowDirection {
        case up, down, left, right
    }
    
    enum FocusedPane {
        case hex, ascii
    }
    
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
                                        
                                        if index < totalBytes {
                                            let byte = document.buffer[index]
                                            let isSelected = selection.contains(index)
                                            let hasBookmark = bookmarkManager.hasBookmark(at: index)
                                            
                                            Text(String(format: "%02X", byte))
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
                                                     // Copy Hex operation
                                                     Button(action: {
                                                         if !selection.contains(index) {
                                                             selection = [index]
                                                             cursorIndex = index
                                                             selectionAnchor = index
                                                         }
                                                         copySelectionAsHex()
                                                     }) {
                                                         Label("Copy Hex", systemImage: "doc.on.doc")
                                                     }
                                                     .keyboardShortcut("c", modifiers: .command)

                                                     // Copy ASCII operation
                                                     Button(action: {
                                                         if !selection.contains(index) {
                                                             selection = [index]
                                                             cursorIndex = index
                                                             selectionAnchor = index
                                                         }
                                                         copySelectionAsAscii()
                                                     }) {
                                                         Label("Copy ASCII", systemImage: "text.quote")
                                                     }
                                                    
                                                    // Paste operation
                                                    Button(action: {
                                                        if !selection.contains(index) {
                                                            selection = [index]
                                                            cursorIndex = index
                                                            selectionAnchor = index
                                                        }
                                                        pasteFromClipboard()
                                                    }) {
                                                        Label("Paste", systemImage: "doc.on.clipboard")
                                                    }
                                                    .keyboardShortcut("v", modifiers: .command)
                                                    
                                                    // Insert operation
                                                    Button(action: {
                                                        insertPosition = index
                                                        showInsertDialog = true
                                                    }) {
                                                        Label("Insert...", systemImage: "plus.square")
                                                    }
                                                    .keyboardShortcut("i", modifiers: .command)
                                                    
                                                    Divider()
                                                    
                                                    // Delete operation
                                                    Button(action: {
                                                        if !selection.contains(index) {
                                                            selection = [index]
                                                            cursorIndex = index
                                                            selectionAnchor = index
                                                        }
                                                        if !selection.isEmpty {
                                                            let sortedIndices = selection.sorted(by: >)
                                                            performDelete(indices: sortedIndices)
                                                        }
                                                    }) {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                    
                                                    // Zero out operation
                                                    Button(action: {
                                                        if !selection.contains(index) {
                                                            selection = [index]
                                                            cursorIndex = index
                                                            selectionAnchor = index
                                                        }
                                                        zeroSelection()
                                                    }) {
                                                        Label("Zero Out", systemImage: "0.circle")
                                                    }
                                                    .keyboardShortcut("0", modifiers: .command)
                                                    
                                                    Divider()
                                                    
                                                    // Bookmark operation
                                                    Button(action: { toggleBookmark(at: index) }) {
                                                        Label(hasBookmark ? "Remove Bookmark" : "Add Bookmark", 
                                                              systemImage: hasBookmark ? "bookmark.slash" : "bookmark")
                                                    }
                                                    .keyboardShortcut("b", modifiers: .command)
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
                                        if index < totalBytes {
                                            let byte = document.buffer[index]
                                            let char = (byte >= 32 && byte <= 126) ? String(UnicodeScalar(byte)) : "·"
                                            let isSelected = selection.contains(index)
                                            
                                            Text(char)
                                                .font(.monospaced(.body)())
                                                .foregroundColor(isSelected ? 
                                                    ByteColorScheme.selectionTextColor : 
                                                    ByteColorScheme.color(for: byte, colorScheme: colorScheme))
                                                .frame(width: asciiCellWidth, height: rowHeight, alignment: .center)
                                                .background(isSelected ? ByteColorScheme.selectionColor : Color.clear)
                                                .contentShape(Rectangle())
                                                .contextMenu {
                                                   // Copy Hex operation
                                                   Button(action: {
                                                       if !selection.contains(index) {
                                                           selection = [index]
                                                           cursorIndex = index
                                                           selectionAnchor = index
                                                       }
                                                       copySelectionAsHex()
                                                   }) {
                                                       Label("Copy Hex", systemImage: "doc.on.doc")
                                                   }
                                                   .keyboardShortcut("c", modifiers: .command)

                                                   // Copy ASCII operation
                                                   Button(action: {
                                                       if !selection.contains(index) {
                                                           selection = [index]
                                                           cursorIndex = index
                                                           selectionAnchor = index
                                                       }
                                                       copySelectionAsAscii()
                                                   }) {
                                                       Label("Copy ASCII", systemImage: "text.quote")
                                                   }
                                                    
                                                    // Paste operation
                                                    Button(action: {
                                                        if !selection.contains(index) {
                                                            selection = [index]
                                                            cursorIndex = index
                                                            selectionAnchor = index
                                                        }
                                                        pasteFromClipboard()
                                                    }) {
                                                        Label("Paste", systemImage: "doc.on.clipboard")
                                                    }
                                                    .keyboardShortcut("v", modifiers: .command)
                                                    
                                                    // Insert operation
                                                    Button(action: {
                                                        insertPosition = index
                                                        showInsertDialog = true
                                                    }) {
                                                        Label("Insert...", systemImage: "plus.square")
                                                    }
                                                    .keyboardShortcut("i", modifiers: .command)
                                                    
                                                    Divider()
                                                    
                                                    // Delete operation
                                                    Button(action: {
                                                        if !selection.contains(index) {
                                                            selection = [index]
                                                            cursorIndex = index
                                                            selectionAnchor = index
                                                        }
                                                        if !selection.isEmpty {
                                                            let sortedIndices = selection.sorted(by: >)
                                                            performDelete(indices: sortedIndices)
                                                        }
                                                    }) {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                    
                                                    // Zero out operation
                                                    Button(action: {
                                                        if !selection.contains(index) {
                                                            selection = [index]
                                                            cursorIndex = index
                                                            selectionAnchor = index
                                                        }
                                                        zeroSelection()
                                                    }) {
                                                        Label("Zero Out", systemImage: "0.circle")
                                                    }
                                                    .keyboardShortcut("0", modifiers: .command)
                                                    
                                                    Divider()
                                                    
                                                    // Bookmark operation
                                                    Button(action: { toggleBookmark(at: index) }) {
                                                        let hasBookmark = bookmarkManager.hasBookmark(at: index)
                                                        Label(hasBookmark ? "Remove Bookmark" : "Add Bookmark", 
                                                              systemImage: hasBookmark ? "bookmark.slash" : "bookmark")
                                                    }
                                                    .keyboardShortcut("b", modifiers: .command)
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
                            .id(rowIndex)
                        }
                    }
                    .padding(16)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                handleDragGesture(value: value)
                            }
                            .onEnded { _ in
                                finalizeDrag()
                            }
                    )
                    .onAppear {
                        self.scrollProxy = proxy
                        self.isFocused = true
                    }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(phases: .all) { press in
                // Suppress beep sound for arrow keys
                let isArrowKey = [KeyEquivalent.leftArrow, .rightArrow, .upArrow, .downArrow].contains(press.key)
                
                // Handle arrow keys with press-and-hold support
                if press.phase == .down {
                    switch press.key {
                    case .leftArrow:
                        startArrowKeyRepeat(.left, withModifiers: press.modifiers)
                        return .handled
                    case .rightArrow:
                        startArrowKeyRepeat(.right, withModifiers: press.modifiers)
                        return .handled
                    case .upArrow:
                        startArrowKeyRepeat(.up, withModifiers: press.modifiers)
                        return .handled
                    case .downArrow:
                        startArrowKeyRepeat(.down, withModifiers: press.modifiers)
                        return .handled
                    default:
                        break
                    }
                } else if press.phase == .up {
                    // Stop arrow key repeat on key release
                    if isArrowKey {
                        stopArrowKeyRepeat()
                        return .handled
                    }
                } else if press.phase == .repeat {
                    // Suppress repeat phase for arrow keys to prevent beep
                    if isArrowKey {
                        return .handled
                    }
                }
                
                // Handle other keys normally (only on press)
                if press.phase == .down {
                    return handleKeyPress(press)
                }
                
                return .ignored
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
            // Sync external binding to internal helper state
            Task { @MainActor in
                if hexInputHelper.isHexInputMode != newValue {
                    hexInputHelper.isHexInputMode = newValue
                    hexInputHelper.clearPartialInput()
                }
            }
        }
        .onChange(of: hexInputHelper.isHexInputMode) { _, newValue in
            // Sync internal helper state to external binding
            Task { @MainActor in
                if hexInputMode != newValue {
                    hexInputMode = newValue
                }
            }
        }
        .onChange(of: cursorIndex) { _, newValue in
            // Scroll to cursor position when it changes externally
            if let cursor = newValue, let scrollProxy = scrollProxy {
                let rowIndex = cursor / bytesPerRow
                scrollProxy.scrollTo(rowIndex)
            }
        }
    }
    
    
    // Track if we're actively dragging
    @State private var isDragging = false
    
    private func handleDragGesture(value: DragGesture.Value) {
        let location = value.location
        
        // Calculate index from location
        // We need to account for padding
        let padding: CGFloat = 16
        let relativeX = location.x - padding
        let relativeY = location.y - padding
        
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
                
                if !isDragging {
                    // Start of drag
                    isDragging = true
                    dragStart = index
                    selectionAnchor = index
                    cursorIndex = index
                    selection = [index]
                    focusedPane = isAscii ? .ascii : .hex
                    hexInputHelper.clearPartialInput()
                } else {
                    // Continue drag
                    if let start = dragStart {
                        let range = min(start, index)...max(start, index)
                        selection = Set(range)
                        cursorIndex = index
                        hexInputHelper.clearPartialInput()
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
    }
    
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        // Determine current cursor position
        // If we have a tracked cursor, use it. Otherwise fallback to max of selection.
        let currentCursor = cursorIndex ?? selection.max() ?? 0
        
        // Handle modifier commands first
        if press.modifiers.contains(.command) {
            switch press.key {
            case "a":
                // Select all
                DispatchQueue.main.async {
                    self.selection = Set(0..<self.document.buffer.count)
                    self.selectionAnchor = 0
                    self.cursorIndex = self.document.buffer.count - 1
                }
                return .handled
            case "x":
                // Cut selection
                copySelectionAsHex()
                if !selection.isEmpty {
                    let sortedIndices = selection.sorted(by: >)
                    performDelete(indices: sortedIndices)
                }
                return .handled
            case "d":
                // Duplicate selection
                if !selection.isEmpty {
                    let sortedIndices = selection.sorted()
                    let bytes = sortedIndices.map { document.buffer[$0] }
                    if let lastIndex = sortedIndices.last {
                        var currentIndex = lastIndex + 1
                        for byte in bytes {
                            performInsert(byte, at: currentIndex)
                            currentIndex += 1
                        }
                    }
                }
                return .handled
            case "c":
                copySelectionAsHex()
                return .handled
            case "v":
                pasteFromClipboard()
                return .handled
            case "0":
                zeroSelection()
                return .handled
            case "g":
                hexInputHelper.toggleMode()
                hexInputMode = hexInputHelper.isHexInputMode
                return .handled
            case "b":
                toggleBookmark(at: currentCursor)
                return .handled
            case "f":
                showSearch = true
                return .handled
            case "z":
                // Let system handle undo
                return .ignored
            default:
                break
            }
        }
        
        // Helper to update selection based on movement
        func moveSelection(to newIndex: Int) {
            if press.modifiers.contains(.shift) {
                // Extend selection
                let anchor = selectionAnchor ?? currentCursor
                selectionAnchor = anchor // Ensure anchor is set
                cursorIndex = newIndex
                
                let range = min(anchor, newIndex)...max(anchor, newIndex)
                selection = Set(range)
            } else {
                // Move selection
                selection = [newIndex]
                selectionAnchor = newIndex
                cursorIndex = newIndex
            }
            hexInputHelper.clearPartialInput()
        }
        
        switch press.key {
        case .delete: // Backspace
            if selection.count > 1 {
                let sortedIndices = selection.sorted(by: >)
                performDelete(indices: sortedIndices)
            } else {
                if let singleIndex = selection.first, singleIndex > 0 {
                    performDelete(indices: [singleIndex - 1])
                }
            }
            hexInputHelper.clearPartialInput()
            return .handled
            
        case .deleteForward: // Delete
            if !selection.isEmpty {
                let sortedIndices = selection.sorted(by: >)
                performDelete(indices: sortedIndices)
                hexInputHelper.clearPartialInput()
                return .handled
            }
            
        case .tab:
            // Toggle between hex and ASCII pane
            focusedPane = focusedPane == .hex ? .ascii : .hex
            return .handled
            
        case .escape:
            hexInputHelper.clearPartialInput()
            return .handled
            
        default:
            // Handle character input
            if let char = press.characters.first {
                if hexInputHelper.isHexInputMode {
                    // Hex input mode
                    if hexInputHelper.isValidHexChar(char) {
                        // Defer processing to avoid publishing changes during view updates
                        DispatchQueue.main.async {
                            if let byte = self.hexInputHelper.processHexCharacter(char) {
                                // We have a complete hex byte
                                if self.isOverwriteMode {
                                    self.performReplace(at: currentCursor, with: byte)
                                    let nextIndex = min(currentCursor + 1, self.document.buffer.count - 1)
                                    self.selection = [nextIndex]
                                    self.cursorIndex = nextIndex
                                    self.selectionAnchor = nextIndex
                                } else {
                                    self.performInsert(byte, at: currentCursor)
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
                        
                        // ASCII input
                        DispatchQueue.main.async {
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
        // We need to group this into one undo operation?
        // UndoManager groups by event loop usually.
        for index in selection {
            performReplace(at: index, with: 0)
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
    
    private func pasteFromClipboard() {
        guard let index = selection.max() else { return }
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = cleaned.data(using: .utf8) {
                var currentIndex = index
                // If selection is range, maybe replace?
                // Standard paste inserts.
                for byte in data {
                    performInsert(byte, at: currentIndex)
                    currentIndex += 1
                }
                selection = [currentIndex]
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
    
    // MARK: - Arrow Key Press-and-Hold Support
    
    private func startArrowKeyRepeat(_ direction: ArrowDirection, withModifiers modifiers: EventModifiers) {
        // Stop any existing timer
        stopArrowKeyRepeat()
        
        currentArrowDirection = direction
        
        // Execute immediately
        performArrowKeyMove(direction, withModifiers: modifiers)
        
        // Start repeating timer (initial delay: 0.4s, repeat: 0.05s)
        var initialDelay = true
        arrowKeyTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if initialDelay {
                // Skip first few iterations for initial delay
                initialDelay = false
                return
            }
            
            self.performArrowKeyMove(direction, withModifiers: modifiers)
        }
    }
    
    private func stopArrowKeyRepeat() {
        arrowKeyTimer?.invalidate()
        arrowKeyTimer = nil
        currentArrowDirection = nil
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
            
            // Smart scroll: only scroll to keep cursor visible
            if let scrollProxy = self.scrollProxy, let cursor = self.cursorIndex {
                let rowIndex = cursor / self.bytesPerRow
                scrollProxy.scrollTo(rowIndex)
            }
        }
    }
    
    private func performDelete(indices: [Int]) {
        // Indices must be sorted descending
        guard let firstIndex = indices.last else { return } // The smallest index
        
        document.delete(indices: indices, undoManager: undoManager)
        
        // Select the point where deletion happened (smallest index)
        // Ensure we don't go out of bounds if we deleted the last byte
        let newCursor = min(firstIndex, document.buffer.count)
        selection = [newCursor]
        cursorIndex = newCursor
        selectionAnchor = newCursor
    }
}
