import SwiftUI
import UniformTypeIdentifiers
import Combine

final class HexDocument: ReferenceFileDocument {
    @Published var buffer: GapBuffer
    
    init(initialData: Data = Data()) {
        self.buffer = GapBuffer(data: initialData)
    }

    static var readableContentTypes: [UTType] { [.item] }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.buffer = GapBuffer(data: data)
    }
    
    func snapshot(contentType: UTType) throws -> Data {
        return buffer.toData()
    }
    
    func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: snapshot)
    }
    
    func insert(_ byte: UInt8, at index: Int) {
        buffer.insert(byte, at: index)
    }
    
    func delete(at index: Int) {
        buffer.delete(at: index)
    }
    
    func replace(at index: Int, with byte: UInt8) {
        buffer[index] = byte
    }
}
