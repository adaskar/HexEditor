import Foundation

// MARK: - Diff Models

/// Represents a contiguous block of differences
struct DiffBlock: Identifiable, Equatable {
    let id = UUID()
    let range: ClosedRange<Int>
    let type: DiffType
    
    enum DiffType: Equatable {
        case modified      // Bytes differ between files
        case onlyInFirst   // Bytes only in first file
        case onlyInSecond  // Bytes only in second file
    }
    
    var size: Int {
        range.count
    }
}

/// Enhanced diff result with blocks and statistics
struct EnhancedDiffResult {
    let blocks: [DiffBlock]
    let totalDifferences: Int
    let bytesChanged: Int
    let matchPercentage: Double
    let file1Size: Int
    let file2Size: Int
    
    var hasDifferences: Bool {
        !blocks.isEmpty
    }
    
    /// Get the index of the block containing the given byte offset
    func blockIndex(containing offset: Int) -> Int? {
        blocks.firstIndex { $0.range.contains(offset) }
    }
}

// MARK: - Diff Engine

class DiffEngine {
    /// Compare two buffers and return enhanced diff results with blocks
    static func compare(buffer1: GapBuffer, buffer2: GapBuffer) async -> EnhancedDiffResult {
        await Task.yield()
        
        let count1 = buffer1.count
        let count2 = buffer2.count
        let minCount = min(count1, count2)
        
        var differences = Set<Int>()
        var onlyInFirst = Set<Int>()
        var onlyInSecond = Set<Int>()
        
        // Compare overlapping region
        for i in 0..<minCount {
            if buffer1[i] != buffer2[i] {
                differences.insert(i)
            }
            
            // Yield occasionally to keep UI responsive
            if i % 10000 == 0 {
                await Task.yield()
            }
        }
        
        // Handle size differences
        if count1 > count2 {
            for i in count2..<count1 {
                onlyInFirst.insert(i)
            }
        } else if count2 > count1 {
            for i in count1..<count2 {
                onlyInSecond.insert(i)
            }
        }
        
        // Convert to blocks
        let blocks = await createDiffBlocks(
            differences: differences,
            onlyInFirst: onlyInFirst,
            onlyInSecond: onlyInSecond
        )
        
        // Calculate statistics
        let totalDiffs = differences.count + onlyInFirst.count + onlyInSecond.count
        let bytesChanged = totalDiffs
        let largerSize = max(count1, count2)
        let matchPercentage = largerSize > 0 ? Double(largerSize - totalDiffs) / Double(largerSize) * 100.0 : 100.0
        
        return EnhancedDiffResult(
            blocks: blocks,
            totalDifferences: totalDiffs,
            bytesChanged: bytesChanged,
            matchPercentage: matchPercentage,
            file1Size: count1,
            file2Size: count2
        )
    }
    
    /// Create contiguous diff blocks from individual byte differences
    private static func createDiffBlocks(
        differences: Set<Int>,
        onlyInFirst: Set<Int>,
        onlyInSecond: Set<Int>
    ) async -> [DiffBlock] {
        await Task.yield()
        
        var blocks: [DiffBlock] = []
        
        // Process modified bytes
        blocks.append(contentsOf: createBlocksFromSet(differences, type: .modified))
        
        // Process bytes only in first file
        blocks.append(contentsOf: createBlocksFromSet(onlyInFirst, type: .onlyInFirst))
        
        // Process bytes only in second file
        blocks.append(contentsOf: createBlocksFromSet(onlyInSecond, type: .onlyInSecond))
        
        // Sort by range start
        blocks.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        return blocks
    }
    
    /// Convert a set of indices into contiguous blocks
    private static func createBlocksFromSet(_ indices: Set<Int>, type: DiffBlock.DiffType) -> [DiffBlock] {
        guard !indices.isEmpty else { return [] }
        
        let sorted = indices.sorted()
        var blocks: [DiffBlock] = []
        var currentStart = sorted[0]
        var currentEnd = sorted[0]
        
        for i in 1..<sorted.count {
            let index = sorted[i]
            if index == currentEnd + 1 {
                // Contiguous, extend current block
                currentEnd = index
            } else {
                // Gap found, save current block and start new one
                blocks.append(DiffBlock(range: currentStart...currentEnd, type: type))
                currentStart = index
                currentEnd = index
            }
        }
        
        // Add the last block
        blocks.append(DiffBlock(range: currentStart...currentEnd, type: type))
        
        return blocks
    }
}
