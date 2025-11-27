//
//  DisassemblerView.swift
//  HexEditor
//
//  Disassembler view for viewing assembly instructions
//

import SwiftUI

struct DisassemblerView: View {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isPresented: Bool
    @Binding var cursorIndex: Int?
    @Binding var selectionAnchor: Int?
    
    @State private var architecture: DisassemblerEngine.Architecture = .x86_64
    @State private var instructions: [DisassemblerEngine.Instruction] = []
    @State private var isDisassembling = false
    @State private var startOffset: Int = 0
    @State private var maxInstructions: Int = 100
    @State private var offsetInput: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Disassembler")
                    .font(.title2.bold())
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding()
            
            Divider()
            
            // Controls
            HStack(spacing: 16) {
                // Architecture selection
                Picker("Architecture", selection: $architecture) {
                    ForEach(DisassemblerEngine.Architecture.allCases) { arch in
                        Text(arch.rawValue).tag(arch)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                Divider()
                    .frame(height: 20)
                
                // Start offset
                HStack(spacing: 4) {
                    Text("Offset:")
                        .font(.caption)
                    TextField("0x0", text: $offsetInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onSubmit {
                            updateStartOffset()
                        }
                }
                
                // Max instructions
                HStack(spacing: 4) {
                    Text("Max:")
                        .font(.caption)
                    Stepper("\(maxInstructions)", value: $maxInstructions, in: 10...1000, step: 10)
                        .frame(width: 100)
                }
                
                Spacer()
                
                // Action buttons
                Button(action: {
                    useCurrentSelection()
                }) {
                    Label("From Selection", systemImage: "selection.pin.in.out")
                }
                .buttonStyle(.bordered)
                .disabled(selection.isEmpty)
                
                Button(action: {
                    performDisassembly()
                }) {
                    Label("Disassemble", systemImage: "cpu")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDisassembling)
            }
            .padding()
            
            Divider()
            
            // Instructions list
            if isDisassembling {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Disassembling...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if instructions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No disassembly")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Select an offset and click Disassemble")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack(spacing: 0) {
                            Text("Address")
                                .font(.system(.caption, design: .monospaced).bold())
                                .frame(width: 100, alignment: .leading)
                            Text("Bytes")
                                .font(.system(.caption, design: .monospaced).bold())
                                .frame(width: 200, alignment: .leading)
                            Text("Instruction")
                                .font(.system(.caption, design: .monospaced).bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        
                        Divider()
                        
                        // Instructions
                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                            InstructionRow(
                                instruction: instruction,
                                isEven: index % 2 == 0,
                                onTap: {
                                    jumpToAddress(instruction.address)
                                }
                            )
                        }
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
        .onChange(of: architecture) { _, _ in
            if !instructions.isEmpty {
                performDisassembly()
            }
        }
        .onAppear {
            // Use current selection as start point if available
            if let min = selection.min() {
                startOffset = min
                offsetInput = String(format: "0x%X", min)
            } else if let cursor = cursorIndex {
                startOffset = cursor
                offsetInput = String(format: "0x%X", cursor)
            }
            
            // Auto-disassemble on appear
            performDisassembly()
        }
    }
    
    private func updateStartOffset() {
        let cleaned = offsetInput.trimmingCharacters(in: .whitespaces)
        
        // Try to parse hex (with or without 0x prefix)
        let hexString = cleaned.hasPrefix("0x") || cleaned.hasPrefix("0X") 
            ? String(cleaned.dropFirst(2)) 
            : cleaned
        
        if let value = Int(hexString, radix: 16) {
            startOffset = value
            performDisassembly()
        } else if let value = Int(cleaned) {
            // Try decimal
            startOffset = value
            offsetInput = String(format: "0x%X", value)
            performDisassembly()
        }
    }
    
    private func useCurrentSelection() {
        if let min = selection.min() {
            startOffset = min
            offsetInput = String(format: "0x%X", min)
            performDisassembly()
        }
    }
    
    private func performDisassembly() {
        guard startOffset < document.buffer.count else { return }
        
        isDisassembling = true
        
        Task {
            let engine = DisassemblerEngine(architecture: architecture)
            
            // Get data from buffer
            let endOffset = min(startOffset + maxInstructions * 16, document.buffer.count)
            let data = (startOffset..<endOffset).map { document.buffer[$0] }
            
            let result = engine.disassemble(data: data, startAddress: startOffset, maxInstructions: maxInstructions)
            
            await MainActor.run {
                instructions = result
                isDisassembling = false
            }
        }
    }
    
    private func jumpToAddress(_ address: Int) {
        // Jump to the address in the hex view
        if address >= 0 && address < document.buffer.count {
            selection = [address]
            cursorIndex = address
            selectionAnchor = address
            
            // Close disassembler to show hex view
            isPresented = false
        }
    }
}

struct InstructionRow: View {
    let instruction: DisassemblerEngine.Instruction
    let isEven: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Address
                Text(String(format: "%08X", instruction.address))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(instruction.isValid ? .primary : .red)
                    .frame(width: 100, alignment: .leading)
                
                // Bytes
                Text(instruction.hexString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 200, alignment: .leading)
                
                // Instruction
                HStack(spacing: 4) {
                    Text(instruction.mnemonic)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(mnemonicColor(instruction.mnemonic))
                    
                    if !instruction.operands.isEmpty {
                        Text(instruction.operands)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(isEven ? Color.clear : Color.secondary.opacity(0.05))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to jump to offset \(String(format: "0x%X", instruction.address))")
    }
    
    private func mnemonicColor(_ mnemonic: String) -> Color {
        // Color code instructions by type
        if mnemonic.starts(with: "j") || mnemonic == "call" {
            return .blue // Jumps and calls
        } else if mnemonic == "ret" || mnemonic.starts(with: "ret") {
            return .purple // Returns
        } else if mnemonic == "nop" {
            return .gray // NOPs
        } else if mnemonic.starts(with: ".") {
            return .orange // Data directives
        } else if mnemonic == "push" || mnemonic == "pop" {
            return .green // Stack operations
        } else {
            return .primary // Default
        }
    }
}
