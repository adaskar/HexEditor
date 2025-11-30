//
//  HxEditorApp.swift
//  HxEditor
//
//  Created by guru on 23.11.2025.
//

import SwiftUI

@main
struct HxEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("quitWhenLastWindowClosed") private var quitWhenLastWindowClosed = false
    
    var body: some Scene {
        DocumentGroup(newDocument: { HexDocument() }) { configuration in
            ContentView(document: configuration.document)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Toggle("Quit When Last Window Closed", isOn: $quitWhenLastWindowClosed)
                    .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hasFinishedLaunching = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        hasFinishedLaunching = true
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Don't open untitled file on launch - this prevents empty document
        // when dropping a file on the app icon for the first time
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If no windows are visible, create a new document
        if !flag {
            NSDocumentController.shared.newDocument(nil)
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit during app launch
        guard hasFinishedLaunching else {
            return false
        }
        
        // Only quit if preference is enabled
        guard UserDefaults.standard.bool(forKey: "quitWhenLastWindowClosed") else {
            return false
        }
        
        // Delay the check to allow new documents to be created (e.g. after Open Panel closes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Check if there are any open documents
            if NSDocumentController.shared.documents.isEmpty {
                // Double check for any visible windows (like Settings)
                let hasVisibleWindows = NSApp.windows.contains { $0.isVisible && !($0.contentView is NSTextView) }
                
                if !hasVisibleWindows {
                    NSApp.terminate(nil)
                }
            }
        }
        
        return false
    }
}
