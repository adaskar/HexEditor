# Verification: Selection Performance Fix

## Goal
Verify that selecting a single byte at the end of a large file is instant and that the selection logic works correctly with scrolling.

## Changes
- Refactored `HexGridView` to use `HexRowView` for row rendering.
- Implemented `SelectionState` observable object to isolate selection updates from the main grid view.
- Moved `DragGesture` to `LazyVStack` to ensure correct coordinate handling when scrolled.
- Updated `HexRowView` to support all context menu actions.

## Verification Steps

### 1. Performance Test
1. Open a large file (e.g., > 10MB).
2. Scroll to the very end of the file.
3. Click on a byte.
4. **Expected Result**: The selection should appear instantly without any lag.
5. Use arrow keys to move the selection.
6. **Expected Result**: Movement should be smooth.

### 2. Selection Correctness
1. Scroll to the middle of the file.
2. Click on a specific byte (e.g., at offset `0x1000`).
3. Verify the status bar shows the correct offset.
4. **Expected Result**: The selected byte matches the clicked location.

### 3. Drag Selection
1. Click and drag to select a range of bytes.
2. **Expected Result**: The selection should update smoothly as you drag.

### 4. Context Menu
1. Right-click on a byte.
2. Verify all options are present (Copy, Paste, Insert, Delete, Zero Out, Bookmark).
3. Test "Copy Hex" and "Paste Hex".
4. **Expected Result**: Actions work as expected.

### 5. Hex/ASCII Sync
1. Select a byte in the Hex pane.
2. Verify the corresponding character is highlighted in the ASCII pane.
3. Select a character in the ASCII pane.
### 6. End of File Selection Performance
1. Open a very large file (e.g., > 10MB).
2. Scroll to the very end of the file.
3. Click on the last byte.
4. **Expected Result**: Selection should be instant.
5. Drag to select a range at the end.
6. **Expected Result**: Selection should update smoothly without lag.
7. Use arrow keys to move selection.
### 7. Arrow Key Navigation Performance
1. Open a very large file (e.g., > 10MB).
2. Scroll to the very end of the file.
3. Select a byte.
4. Hold down the Right Arrow or Down Arrow key.
5. **Expected Result**: Selection should move smoothly without lag.
6. Continue holding until the cursor reaches the edge of the screen.
7. **Expected Result**: The view should scroll automatically to keep the cursor visible.
