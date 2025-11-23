//
//  ContentView.swift
//  HexEditor
//
//  Created by guru on 23.11.2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var document: HexDocument
    @State private var selection: Set<Int> = []
    @State private var showJumpToOffset = false
    @State private var showSearch = false
    @State private var showChecksum = false
    @State private var showStatistics = false
    @State private var showQuickActions = false
    @State private var isOverwriteMode = false
    @State private var byteGrouping = 8
    @State private var hexInputMode = false
    @State private var showInspector = false

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                // Main hex grid
                HexGridView(
                    document: document,
                    selection: $selection,
                    isOverwriteMode: $isOverwriteMode,
                    hexInputMode: $hexInputMode,
                    byteGrouping: byteGrouping
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
                isOverwriteMode: isOverwriteMode,
                hexInputMode: $hexInputMode
            )
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Navigation tools
                Button(action: { showJumpToOffset = true }) {
                    Label("Jump to Offset", systemImage: "arrow.right.circle")
                }
                .help("Jump to a specific offset (⌘J)")
                
                Button(action: { showSearch = true }) {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .help("Search for data (⌘F)")
                
                Divider()
                
                // Edit tools
                Button(action: { isOverwriteMode.toggle() }) {
                    Label(isOverwriteMode ? "Overwrite" : "Insert", 
                          systemImage: isOverwriteMode ? "pencil.slash" : "pencil")
                }
                .help(isOverwriteMode ? "Switch to Insert Mode" : "Switch to Overwrite Mode")
                
                Button(action: { showQuickActions = true }) {
                    Label("Quick Actions", systemImage: "wand.and.stars")
                }
                .help("Quick editing actions")
                
                Divider()
                
                // View tools
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
                
                Button(action: { showStatistics = true }) {
                    Label("Statistics", systemImage: "chart.bar")
                }
                .help("View file statistics")
                
                Button(action: { showChecksum = true }) {
                    Label("Checksum", systemImage: "number.square")
                }
                .help("Calculate checksums")
                
                Divider()
                
                // Inspector toggle
                Button(action: { showInspector.toggle() }) {
                    Label("Inspector", systemImage: showInspector ? "sidebar.right" : "sidebar.right")
                }
                .help(showInspector ? "Hide Inspector" : "Show Inspector")
            }
        }
        .sheet(isPresented: $showJumpToOffset) {
            JumpToOffsetView(document: document, selection: $selection, isPresented: $showJumpToOffset)
        }
        .sheet(isPresented: $showSearch) {
            SearchView(document: document, selection: $selection, isPresented: $showSearch)
        }
        .sheet(isPresented: $showChecksum) {
            ChecksumView(document: document, selection: $selection, isPresented: $showChecksum)
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView(document: document, isPresented: $showStatistics)
        }
        .sheet(isPresented: $showQuickActions) {
            QuickActionsView(document: document, selection: $selection, isPresented: $showQuickActions)
        }
    }
}

#Preview {
    ContentView(document: HexDocument())
}
