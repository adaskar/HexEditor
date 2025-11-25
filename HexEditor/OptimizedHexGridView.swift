import SwiftUI
import Combine

struct OptimizedHexGridView: NSViewRepresentable {
    @ObservedObject var document: HexDocument
    @Binding var selection: Set<Int>
    @Binding var isOverwriteMode: Bool
    @Binding var hexInputMode: Bool
    var byteGrouping: Int
    @Binding var showSearch: Bool
    @Binding var selectionAnchor: Int?
    @Binding var cursorIndex: Int?
    @ObservedObject var bookmarkManager: BookmarkManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(named: "BackgroundColor") ?? .textBackgroundColor
        
        let textView = HexTextView()
        textView.hexDocument = document
        textView.bookmarkManager = bookmarkManager
        textView.byteGrouping = byteGrouping
        textView.isHexInputMode = hexInputMode
        textView.isOverwriteMode = isOverwriteMode
        
        // Set up callbacks
        let coordinator = context.coordinator
        coordinator.textView = textView
        textView.onSelectionChanged = { [weak coordinator] newSelection in
            coordinator?.updateSelection(newSelection)
        }
        
        textView.onCursorChanged = { [weak coordinator] newCursor in
            coordinator?.updateCursor(newCursor)
        }
        
        scrollView.documentView = textView
        textView.regenerateContent()
        
        // Subscribe to document changes
        context.coordinator.setupDocumentObserver()
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? HexTextView else { return }
        
        // Update document reference
        if textView.hexDocument !== document {
            textView.hexDocument = document
            textView.bookmarkManager = bookmarkManager
            textView.regenerateContent()
            context.coordinator.setupDocumentObserver()
        }
        
        // Update configuration
        if textView.byteGrouping != byteGrouping {
            textView.byteGrouping = byteGrouping
        }
        
        textView.isHexInputMode = hexInputMode
        textView.isOverwriteMode = isOverwriteMode
        
        // Sync selection from SwiftUI state
        if textView.currentSelection != selection || textView.currentCursor != cursorIndex {
            textView.setSelection(selection, anchor: selectionAnchor, cursor: cursorIndex)
        }
    }
    
    class Coordinator {
        var parent: OptimizedHexGridView
        var documentObserver: AnyCancellable?
        weak var textView: HexTextView?
        
        init(_ parent: OptimizedHexGridView) {
            self.parent = parent
        }
        
        func setupDocumentObserver() {
            documentObserver?.cancel()
            documentObserver = parent.document.objectWillChange.sink { [weak self] _ in
                // When document changes, regenerate content
                DispatchQueue.main.async {
                    self?.regenerateTextView()
                }
            }
        }
        
        func regenerateTextView() {
            // Trigger regeneration after a short delay to batch rapid changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.textView?.regenerateContent()
            }
        }
        
        func updateSelection(_ newSelection: Set<Int>) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.selection = newSelection
            }
        }
        
        func updateCursor(_ newCursor: Int?) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.cursorIndex = newCursor
                if let cursor = newCursor {
                    self?.parent.selectionAnchor = cursor
                }
            }
        }
    }
}
