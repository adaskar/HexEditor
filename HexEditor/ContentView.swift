//
//  ContentView.swift
//  HexEditor
//
//  Created by guru on 23.11.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var document: HexDocument
    @State private var selection: Set<Int> = []
    @Environment(\.undoManager) var undoManager
    @State private var showJumpToOffset = false
    @State private var showSearch = false
    @State private var showChecksum = false
    @State private var showStatistics = false
    @State private var showQuickActions = false
    @State private var isOverwriteMode = false
    @State private var byteGrouping = 8
    @State private var hexInputMode = false
    @State private var showInspector = false
    @State private var showStrings = false
    @State private var showBitmap = false
    @State private var showFileComparison = false
    @State private var cursorIndex: Int? = nil
    @State private var selectionAnchor: Int? = nil
    @State private var showDuplicateAlert = false
    @State private var showFileExporter = false
    @State private var showEditWarning = false
    @Environment(\.openDocument) private var openDocument

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                // Main hex grid
                HexGridView(
                    document: document,
                    selection: $selection,
                    isOverwriteMode: $isOverwriteMode,
                    hexInputMode: $hexInputMode,
                    byteGrouping: byteGrouping,
                    selectionAnchor: $selectionAnchor,
                    cursorIndex: $cursorIndex
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Enhanced inspector panel
                if showInspector {
                    FileInfoView(document: document, selection: $selection)
                        .frame(width: 280)
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Status bar at bottom
            StatusBarView(
                document: document,
                selection: $selection,
                isOverwriteMode: $isOverwriteMode,
                hexInputMode: $hexInputMode
            )
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Navigation & Search
                Button(action: { showJumpToOffset = true }) {
                    Label("Jump to Offset", systemImage: "arrow.right.circle")
                }
                .help("Jump to a specific offset (⌘J)")

                Button(action: { showSearch = true }) {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .help("Search for data (⌘F)")

                Button(action: { showStrings = true }) {
                    Label("Strings", systemImage: "text.quote")
                }
                .help("Extract strings")

                Divider()

                // Data Analysis
                Button(action: { showStatistics = true }) {
                    Label("Statistics", systemImage: "chart.bar")
                }
                .help("View file statistics")

                Button(action: { showChecksum = true }) {
                    Label("Checksum", systemImage: "number.square")
                }
                .help("Calculate checksums")

                Divider()

                // View & Edit
                Menu {
                    Picker("Grouping", selection: $byteGrouping) {
                        Text("1 Byte").tag(1)
                        Text("2 Bytes").tag(2)
                        Text("4 Bytes").tag(4)
                        Text("8 Bytes").tag(8)
                        Text("16 Bytes").tag(16)
                    }
                } label: {
                    Label("Grouping", systemImage: "square.grid.3x3")
                }
                .help("Change byte grouping")

                Button(action: { showBitmap = true }) {
                    Label("Bitmap", systemImage: "photo")
                }
                .help("Bitmap Visualizer")

                Button(action: { showFileComparison = true }) {
                    Label("Compare", systemImage: "arrow.left.arrow.right.square")
                }
                .help("Compare with another file")

                Button(action: { showQuickActions = true }) {
                    Label("Quick Actions", systemImage: "wand.and.stars")
                }
                .help("Quick editing actions")

                Button(action: { showInspector.toggle() }) {
                    Label("Inspector", systemImage: showInspector ? "sidebar.right" : "sidebar.right")
                }
                .help(showInspector ? "Hide Inspector" : "Show Inspector")
            }
        }
        .onChange(of: document.requestDuplicate) { _, newValue in
            if newValue {
                showDuplicateAlert = true
                document.requestDuplicate = false
            }
        }
        .sheet(isPresented: $showJumpToOffset) {
            JumpToOffsetView(
                document: document,
                selection: $selection,
                cursorIndex: $cursorIndex,
                selectionAnchor: $selectionAnchor,
                isPresented: $showJumpToOffset
            )
        }
        .sheet(isPresented: $showSearch) {
            SearchView(document: document, selection: $selection, isPresented: $showSearch)
        }
        .sheet(isPresented: $showStrings) {
            StringsView(
                document: document,
                selection: $selection,
                isPresented: $showStrings,
                cursorIndex: $cursorIndex,
                selectionAnchor: $selectionAnchor
            )
        }
        .sheet(isPresented: $showChecksum) {
            ChecksumView(document: document, selection: $selection, isPresented: $showChecksum)
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView(document: document, isPresented: $showStatistics)
        }
        .sheet(isPresented: $showBitmap) {
            BitmapView(document: document, isPresented: $showBitmap)
        }
        .sheet(isPresented: $showFileComparison) {
            FileComparisonView(document: document, isPresented: $showFileComparison)
        }
        .sheet(isPresented: $showQuickActions) {
            QuickActionsView(document: document, selection: $selection, isPresented: $showQuickActions, undoManager: undoManager)
        }
        .confirmationDialog("Read-Only Document", isPresented: $showDuplicateAlert, titleVisibility: .visible) {
            Button("Duplicate", role: .none) {
                showFileExporter = true
            }
            Button("Edit Directly", role: .destructive) {
                showEditWarning = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This document is read-only. How would you like to proceed?")
        }
        .alert(isPresented: $showEditWarning) {
            Alert(
                title: Text("Warning"),
                message: Text("Editing this file directly may overwrite the original data. Are you sure you want to continue?"),
                primaryButton: .destructive(Text("Yes, Edit")) {
                    document.readOnly = false
                },
                secondaryButton: .cancel()
            )
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: document,
            contentType: .item,
            defaultFilename: "Duplicate"
        ) { result in
            if case .success(let url) = result {
                UserDefaults.standard.set(true, forKey: "makeEditable")
                Task {
                    do {
                        try await openDocument(at: url)
                    } catch {
                        // Handle error if needed
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView(document: HexDocument(readOnly: false))
}
