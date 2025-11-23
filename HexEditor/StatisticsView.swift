import SwiftUI

struct StatisticsView: View {
    @ObservedObject var document: HexDocument
    @Binding var isPresented: Bool
    
    @State private var byteCounts: [Int] = Array(repeating: 0, count: 256)
    @State private var entropy: Double = 0.0
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 20) {
            Text("File Statistics")
                .font(.headline)
            
            if isLoading {
                ProgressView("Calculating...")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Entropy Section
                    GroupBox(label: Label("Entropy", systemImage: "waveform.path.ecg")) {
                        VStack(alignment: .leading) {
                            Text("\(String(format: "%.4f", entropy)) bits/byte")
                                .font(.title2.monospaced())
                            
                            ProgressView(value: entropy, total: 8.0)
                                .tint(entropyColor)
                            
                            Text("0.0 = Order, 8.0 = Random/Encrypted")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }
                    
                    // Histogram Section
                    GroupBox(label: Label("Byte Distribution", systemImage: "chart.bar.fill")) {
                        VStack(alignment: .leading) {
                            GeometryReader { geometry in
                                HStack(alignment: .bottom, spacing: 0) {
                                    if let maxCount = byteCounts.max(), maxCount > 0 {
                                        ForEach(0..<256) { i in
                                            let count = byteCounts[i]
                                            let height = CGFloat(count) / CGFloat(maxCount) * geometry.size.height
                                            
                                            Rectangle()
                                                .fill(Color.accentColor.opacity(0.8))
                                                .frame(width: geometry.size.width / 256, height: height)
                                                .help("Byte 0x\(String(format: "%02X", i)): \(count) occurrences")
                                        }
                                    }
                                }
                            }
                            .frame(height: 150)
                            .background(Color.gray.opacity(0.1))
                            .border(Color.gray.opacity(0.2))
                            
                            HStack {
                                Text("0x00")
                                Spacer()
                                Text("0xFF")
                            }
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }
                    
                    // Summary
                    GroupBox(label: Label("Summary", systemImage: "doc.text")) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Bytes: \(document.buffer.count)")
                                Text("Unique Bytes: \(byteCounts.filter { $0 > 0 }.count)")
                            }
                            .font(.caption)
                            Spacer()
                        }
                        .padding(8)
                    }
                }
            }
            
            HStack {
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
        .onAppear {
            calculateStatistics()
        }
    }
    
    private var entropyColor: Color {
        if entropy < 4.0 { return .green }
        if entropy < 7.0 { return .orange }
        return .red
    }
    
    private func calculateStatistics() {
        isLoading = true
        let buffer = document.buffer
        
        Task {
            var counts = Array(repeating: 0, count: 256)
            // Use a simpler loop for now, optimization can come later if needed
            for byte in buffer {
                counts[Int(byte)] += 1
            }
            
            // Calculate Entropy
            // H = -sum(p_i * log2(p_i))
            var ent: Double = 0.0
            let total = Double(buffer.count)
            if total > 0 {
                for count in counts {
                    if count > 0 {
                        let p = Double(count) / total
                        ent -= p * log2(p)
                    }
                }
            }
            
            await MainActor.run {
                self.byteCounts = counts
                self.entropy = ent
                self.isLoading = false
            }
        }
    }
}
