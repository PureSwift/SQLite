//
//  UUIDBinding.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

#if canImport(Foundation)
import Foundation

public extension Binding {
    
    enum UUIDFormat: Equatable, Hashable, Sendable, CaseIterable {
        
        /// UUID as string
        case text
        
        /// UUID as data blob
        case blob
    }
}

public extension Binding.UUIDFormat {
    
    var affinity: TypeAffinity {
        switch self {
        case .text:
            return .text
        case .blob:
            return .blob
        }
    }
}

public extension Binding {
    
    static func uuid(_ uuid: UUID, type: Binding.UUIDFormat = .blob) -> Binding {
        type.format(uuid)
    }
}

public extension Binding.UUIDFormat {
    
    static func format(text uuid: UUID) -> String {
        uuid.uuidString
    }
    
    static func format(blob uuid: UUID) -> Binding.Blob {
        .pointer { body in
            withUnsafeBytes(of: uuid.uuid) { buffer in
                body(buffer)
            }
        }
    }
    
    func format(_ uuid: UUID) -> Binding {
        switch self {
        case .text:
            return Self.format(text: uuid).binding
        case .blob:
            return .blob(Self.format(blob: uuid))
        }
    }
}

#endif
