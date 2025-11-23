import SwiftUI

struct StringsView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isPresented: Bool
    @Binding var cursorIndex: Int?
    @Binding var selectionAnchor: Int?
    
    @State private var foundStrings: [FoundString] = []
    @State private var isScanning = false
    @State private var minLengthString = "4"
    @State private var showAscii = true
    @State private var showUnicode = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Controls
            HStack {
                Text("Strings")
                    .font(.headline)
                
                Spacer()
                
                HStack {
                    Text("Min Length:")
                    TextField("4", text: $minLengthString)
                        .frame(width: 40)
                        .textFieldStyle(.roundedBorder)
                    
                    Toggle("ASCII", isOn: $showAscii)
                    Toggle("Unicode", isOn: $showUnicode)
                    
                    Button("Scan") {
                        scanStrings()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if isScanning {
                VStack {
                    Spacer()
                    ProgressView("Scanning...")
                    Spacer()
                }
            } else if foundStrings.isEmpty {
                VStack {
                    Spacer()
                    Text("No strings found or not scanned yet.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(foundStrings, id: \.id) { str in
                    HStack {
                        Text(String(format: "%08X", str.offset))
                            .font(.monospaced(.caption)())
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                        
                        Text(str.type.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(str.value)
                            .font(.monospaced(.body)())
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Spacer()
                        
                        Text("Len: \(str.value.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectString(str)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("\(foundStrings.count) strings found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
    
    private func scanStrings() {
        guard let minLen = Int(minLengthString), minLen > 0 else { return }
        isScanning = true
        foundStrings = []
        
        Task {
            let allStrings = await StringExtractor.extractStrings(from: document.buffer, minLength: minLen)
            
            await MainActor.run {
                // Filter based on toggles
                self.foundStrings = allStrings.filter { str in
                    if str.type == .ascii && !showAscii { return false }
                    if str.type == .unicode && !showUnicode { return false }
                    return true
                }
                self.isScanning = false
            }
        }
    }
    
    private func selectString(_ str: FoundString) {
        let range = str.offset..<(str.offset + str.length)
        selection = Set(range)
        cursorIndex = str.offset
        selectionAnchor = str.offset
        // Close? Maybe keep open for browsing
    }
}
