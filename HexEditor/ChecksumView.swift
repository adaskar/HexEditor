import SwiftUI
import CryptoKit

struct ChecksumView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isPresented: Bool
    
    @State private var md5Hash: String = "Calculating..."
    @State private var sha1Hash: String = "Calculating..."
    @State private var sha256Hash: String = "Calculating..."
    @State private var useSelection: Bool = false
    @State private var isCalculating: Bool = false
    @State private var copiedHash: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Checksums")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(dataDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Scope Toggle
                Toggle(isOn: $useSelection) {
                    HStack(spacing: 6) {
                        Image(systemName: useSelection ? "checkmark.square.fill" : "square")
                            .foregroundColor(useSelection ? .accentColor : .secondary)
                            .imageScale(.medium)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Calculate for Selection Only")
                                .font(.callout)
                                .fontWeight(.medium)
                            
                            if !selection.isEmpty {
                                Text("\(selection.count) bytes selected")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .disabled(selection.isEmpty)
                .onChange(of: useSelection) {
                    calculateChecksums()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                // Hash Results
                VStack(spacing: 10) {
                    hashCard(
                        title: "MD5",
                        subtitle: "128-bit hash",
                        icon: "number.circle.fill",
                        iconColor: .orange,
                        hash: md5Hash
                    )
                    
                    hashCard(
                        title: "SHA-1",
                        subtitle: "160-bit hash",
                        icon: "shield.lefthalf.filled",
                        iconColor: .blue,
                        hash: sha1Hash
                    )
                    
                    hashCard(
                        title: "SHA-256",
                        subtitle: "256-bit hash", 
                        icon: "checkmark.shield.fill",
                        iconColor: .green,
                        hash: sha256Hash
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            
            Divider()
            
            // Footer with status and close button
            HStack {
                if isCalculating {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    
                    Text("Calculating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let copied = copiedHash {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .imageScale(.small)
                        Text("\(copied) copied")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 600, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if !selection.isEmpty {
                useSelection = true
            }
            calculateChecksums()
        }
    }
    
    private var dataDescription: String {
        if useSelection && !selection.isEmpty {
            return "\(selection.count) bytes from selection"
        } else {
            return "\(document.buffer.count) bytes from file"
        }
    }
    
    private func hashCard(title: String, subtitle: String, icon: String, iconColor: Color, hash: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(iconColor.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    copyToClipboard(hash, name: title)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.small)
                        Text("Copy")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .disabled(hash == "Calculating..." || isCalculating)
            }
            
            // Hash Value
            if hash == "Calculating..." {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                    
                    Text("Computing hash...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                Text(hash)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        )
    }
    
    private func copyToClipboard(_ text: String, name: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        withAnimation {
            copiedHash = name
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedHash = nil
            }
        }
    }
    
    private func calculateChecksums() {
        isCalculating = true
        md5Hash = "Calculating..."
        sha1Hash = "Calculating..."
        sha256Hash = "Calculating..."
        
        let dataToHash: Data
        if useSelection && !selection.isEmpty {
            let sortedIndices = selection.sorted()
            let bytes = sortedIndices.map { document.buffer[$0] }
            dataToHash = Data(bytes)
        } else {
            dataToHash = Data(document.buffer)
        }
        
        Task {
            let md5 = Insecure.MD5.hash(data: dataToHash).map { String(format: "%02x", $0) }.joined()
            let sha1 = Insecure.SHA1.hash(data: dataToHash).map { String(format: "%02x", $0) }.joined()
            let sha256 = SHA256.hash(data: dataToHash).map { String(format: "%02x", $0) }.joined()
            
            await MainActor.run {
                self.md5Hash = md5
                self.sha1Hash = sha1
                self.sha256Hash = sha256
                self.isCalculating = false
            }
        }
    }
}
