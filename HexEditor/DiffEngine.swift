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
        
        // Use Myers Diff Algorithm
        // Note: For very large files with many differences, this can be slow.
        // We might want to add a size limit or optimization later.
        let ops = await myersDiff(old: buffer1, new: buffer2)
        
        // Convert operations to blocks
        let blocks = createDiffBlocks(from: ops)
        
        // Calculate statistics
        var inserts = 0
        var deletes = 0
        var keeps = 0
        
        for op in ops {
            switch op {
            case .insert: inserts += 1
            case .delete: deletes += 1
            case .keep: keeps += 1
            }
        }
        
        let totalDiffs = inserts + deletes
        let bytesChanged = totalDiffs
        let largerSize = max(count1, count2)
        let matchPercentage = largerSize > 0 ? Double(keeps) / Double(largerSize) * 100.0 : 100.0
        
        return EnhancedDiffResult(
            blocks: blocks,
            totalDifferences: totalDiffs,
            bytesChanged: bytesChanged,
            matchPercentage: matchPercentage,
            file1Size: count1,
            file2Size: count2
        )
    }
    
    // MARK: - Myers Diff Implementation
    
    private enum DiffOperation {
        case insert(Int) // Index in new
        case delete(Int) // Index in old
        case keep(Int)   // Index in old
    }
    
    private static func myersDiff(old: GapBuffer, new: GapBuffer) async -> [DiffOperation] {
        let n = old.count
        let m = new.count
        let max = n + m
        
        // Optimization: If files are identical, return early
        if n == m {
            var identical = true
            for i in 0..<n {
                if i % 10000 == 0 { await Task.yield() }
                if old[i] != new[i] {
                    identical = false
                    break
                }
            }
            if identical {
                return (0..<n).map { .keep($0) }
            }
        }
        
        var v = Array(repeating: 0, count: 2 * max + 1)
        var trace: [[Int]] = []
        
        // Run the Myers algorithm
        for d in 0...max {
            // Yield occasionally to keep UI responsive
            if d % 100 == 0 { await Task.yield() }
            
            let vCopy = v
            trace.append(vCopy)
            
            for k in stride(from: -d, through: d, by: 2) {
                var x: Int
                if k == -d || (k != d && v[max + k - 1] < v[max + k + 1]) {
                    x = v[max + k + 1]
                } else {
                    x = v[max + k - 1] + 1
                }
                
                var y = x - k
                
                while x < n && y < m && old[x] == new[y] {
                    x += 1
                    y += 1
                }
                
                v[max + k] = x
                
                if x >= n && y >= m {
                    // Found solution, backtrack
                    return backtrack(trace: trace, old: old, new: new)
                }
            }
        }
        return []
    }
    
    private static func backtrack(trace: [[Int]], old: GapBuffer, new: GapBuffer) -> [DiffOperation] {
        var ops: [DiffOperation] = []
        let n = old.count
        let m = new.count
        let max = n + m
        
        var x = n
        var y = m
        
        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let v = trace[d]
            let k = x - y
            
            let prevK: Int
            if k == -d || (k != d && v[max + k - 1] < v[max + k + 1]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }
            
            let prevX = v[max + prevK]
            let prevY = prevX - prevK
            
            while x > prevX && y > prevY {
                ops.append(.keep(x - 1))
                x -= 1
                y -= 1
            }
            
            if d > 0 {
                if x == prevX {
                    ops.append(.insert(y - 1))
                    y -= 1
                } else {
                    ops.append(.delete(x - 1))
                    x -= 1
                }
            }
        }
        
        return ops.reversed()
    }
    
    /// Convert diff operations into contiguous blocks
    private static func createDiffBlocks(from ops: [DiffOperation]) -> [DiffBlock] {
        var blocks: [DiffBlock] = []
        
        // We need to group consecutive operations of the same type
        // Note: 'keep' operations are ignored for blocks (they are matches)
        
        var currentType: DiffBlock.DiffType? = nil
        var startRange: Int? = nil
        var endRange: Int? = nil
        
        for op in ops {
            switch op {
            case .insert(let index):
                if currentType == .onlyInSecond {
                    // Extend current block
                    endRange = index
                } else {
                    // Close previous block if any
                    if let type = currentType, let start = startRange, let end = endRange {
                        blocks.append(DiffBlock(range: start...end, type: type))
                    }
                    // Start new block
                    currentType = .onlyInSecond
                    startRange = index
                    endRange = index
                }
                
            case .delete(let index):
                if currentType == .onlyInFirst {
                    // Extend current block
                    endRange = index
                } else {
                    // Close previous block if any
                    if let type = currentType, let start = startRange, let end = endRange {
                        blocks.append(DiffBlock(range: start...end, type: type))
                    }
                    // Start new block
                    currentType = .onlyInFirst
                    startRange = index
                    endRange = index
                }
                
            case .keep:
                // Close previous block if any
                if let type = currentType, let start = startRange, let end = endRange {
                    blocks.append(DiffBlock(range: start...end, type: type))
                }
                currentType = nil
                startRange = nil
                endRange = nil
            }
        }
        
        // Close final block
        if let type = currentType, let start = startRange, let end = endRange {
            blocks.append(DiffBlock(range: start...end, type: type))
        }
        
        return blocks
    }
}
