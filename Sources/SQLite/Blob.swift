//
//  Blob.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

/// A BLOB value's raw bytes.
public struct Blob: Equatable, Hashable, Sendable {

    public let bytes: [UInt8]

    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }
}

extension Blob: BindingConvertible {

    public var binding: Binding {
        .blob(.pointer { block in bytes.withUnsafeBytes(block) })
    }
}

public extension Binding {

    /// The blob's raw bytes, reading them out of a `.blob` binding. `nil` for any other case.
    var bytes: [UInt8]? {
        guard case let .blob(blob) = self else {
            return nil
        }
        switch blob {
        case let .zero(count):
            return [UInt8](repeating: 0, count: Int(count))
        case let .pointer(block):
            var result = [UInt8]()
            _ = block { buffer in
                result = [UInt8](buffer)
                return .success(())
            }
            return result
        }
    }
}
