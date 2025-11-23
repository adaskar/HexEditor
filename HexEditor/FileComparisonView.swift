import SwiftUI
import UniformTypeIdentifiers

struct FileComparisonView: View {
    @ObservedObject var document: HexDocument
    @Binding var isPresented: Bool
    
    @State private var comparisonDocument: HexDocument?
    @State private var diffResult: DiffResult?
    @State private var isComparing = false
    @State private var showFileImporter = false
    
    @State private var sortedDiffIndices: [Int] = []
    @State private var currentDiffIndex: Int = -1
    @State private var scrollTarget: ScrollTarget?
    
    struct ScrollTarget: Equatable {
        let row: Int
        let id = UUID()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("File Comparison")
                    .font(.headline)
                
                Spacer()
                
                if comparisonDocument != nil {
                    HStack(spacing: 12) {
                        Text("\(sortedDiffIndices.count) Differences")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: { navigateDiff(forward: false) }) {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(sortedDiffIndices.isEmpty)
                        .help("Previous Difference")
                        
                        Button(action: { navigateDiff(forward: true) }) {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(sortedDiffIndices.isEmpty)
                        .help("Next Difference")
                    }
                    .padding(.horizontal)
                    
                    Button("Re-Compare") {
                        performComparison()
                    }
                    .disabled(isComparing)
                } else {
                    Button("Load File to Compare...") {
                        showFileImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if isComparing {
                VStack {
                    Spacer()
                    ProgressView("Comparing...")
                    Spacer()
                }
            } else if let compDoc = comparisonDocument {
                HSplitView {
                    // Original File
                    VStack {
                        Text("Original")
                            .font(.caption)
                            .padding(4)
                        
                        ComparisonHexGrid(
                            document: document,
                            diffResult: diffResult,
                            isOriginal: true,
                            scrollTarget: $scrollTarget
                        )
                    }
                    
                    // Comparison File
                    VStack {
                        Text("Comparison")
                            .font(.caption)
                            .padding(4)
                        
                        ComparisonHexGrid(
                            document: compDoc,
                            diffResult: diffResult,
                            isOriginal: false,
                            scrollTarget: $scrollTarget
                        )
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("Load a file to start comparison")
                        .foregroundColor(.secondary)
                    Button("Load File...") {
                        showFileImporter = true
                    }
                    Spacer()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadComparisonFile(url: url)
                }
            case .failure(let error):
                print("Error loading file: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadComparisonFile(url: URL) {
        // Secure access
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let doc = HexDocument(initialData: data)
            self.comparisonDocument = doc
            performComparison()
        } catch {
            print("Failed to load file data: \(error)")
        }
    }
    
    private func performComparison() {
        guard let compDoc = comparisonDocument else { return }
        isComparing = true
        
        Task {
            let result = await DiffEngine.compare(buffer1: document.buffer, buffer2: compDoc.buffer)
            
            // Sort indices for navigation
            let allDiffs = result.differentIndices.union(result.onlyInFirst).union(result.onlyInSecond)
            let sorted = allDiffs.sorted()
            
            await MainActor.run {
                self.diffResult = result
                self.sortedDiffIndices = sorted
                self.currentDiffIndex = -1
                self.isComparing = false
            }
        }
    }
    
    private func navigateDiff(forward: Bool) {
        guard !sortedDiffIndices.isEmpty else { return }
        
        if forward {
            if currentDiffIndex < sortedDiffIndices.count - 1 {
                currentDiffIndex += 1
            } else {
                currentDiffIndex = 0 // Wrap around
            }
        } else {
            if currentDiffIndex > 0 {
                currentDiffIndex -= 1
            } else {
                currentDiffIndex = sortedDiffIndices.count - 1 // Wrap around
            }
        }
        
        let targetByteIndex = sortedDiffIndices[currentDiffIndex]
        // Calculate row index (assuming 16 bytes per row)
        let rowIndex = targetByteIndex / 16
        scrollTarget = ScrollTarget(row: rowIndex)
    }
}

// Simplified Hex Grid for Comparison
struct ComparisonHexGrid: View {
    @ObservedObject var document: HexDocument
    var diffResult: DiffResult?
    var isOriginal: Bool
    @Binding var scrollTarget: FileComparisonView.ScrollTarget?
    @State private var highlightedRow: Int?
    
    let bytesPerRow = 16
    let rowHeight: CGFloat = 20
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let totalBytes = document.buffer.count
                    let totalRows = (totalBytes + bytesPerRow - 1) / bytesPerRow
                    
                    ForEach(0..<totalRows, id: \.self) { rowIndex in
                        HStack(spacing: 4) {
                            // Offset
                            Text(String(format: "%08X", rowIndex * bytesPerRow))
                                .font(.monospaced(.caption)())
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .leading)
                            
                            // Hex
                            HStack(spacing: 4) {
                                ForEach(0..<bytesPerRow, id: \.self) { byteIndex in
                                    let index = rowIndex * bytesPerRow + byteIndex
                                    if index < totalBytes {
                                        let byte = document.buffer[index]
                                        let color = getDiffColor(at: index)
                                        
                                        Text(String(format: "%02X", byte))
                                            .font(.monospaced(.body)())
                                            .foregroundColor(color)
                                            .frame(width: 20, height: rowHeight)
                                            .background(color == .primary ? Color.clear : color.opacity(0.1))
                                    } else {
                                        Text("  ")
                                            .font(.monospaced(.body)())
                                            .frame(width: 20, height: rowHeight)
                                    }
                                }
                            }
                        }
                        .background(highlightedRow == rowIndex ? Color.yellow.opacity(0.5) : Color.clear)
                        .id(rowIndex)
                    }
                }
                .padding()
            }
            .onChange(of: scrollTarget) { oldValue, newValue in
                if let target = newValue {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(target.row, anchor: .center)
                    }
                    
                    // Flash highlight
                    highlightedRow = target.row
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            highlightedRow = nil
                        }
                    }
                }
            }
        }
    }
    
    private func getDiffColor(at index: Int) -> Color {
        guard let diff = diffResult else { return .primary }
        
        if diff.differentIndices.contains(index) {
            return .red
        }
        if isOriginal {
            if diff.onlyInFirst.contains(index) { return .orange }
        } else {
            if diff.onlyInSecond.contains(index) { return .green }
        }
        
        return .primary
    }
}
