//
//  StatementColumnView.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

public extension Statement {
    
    func withColumns<T>(_ block: (borrowing ColumnView) -> (T)) -> T {
        let view = ColumnView(handle: handle)
        return block(view)
    }
    
    struct ColumnView {
        
        let handle: Statement.Handle
    }
}

// MARK: - RandomAccessCollection

extension Statement.ColumnView: RandomAccessCollection {
    
    public typealias Element = String
    
    public typealias Index = Int

    public var isEmpty: Bool {
        count == 0
    }
    
    public var count: Int {
        Int(handle.columnCount)
    }
    
    public var startIndex: Int { 0 }
    
    public var endIndex: Int { count }
    
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < count, "Index out of bounds")
        return handle.columnName(at: Int32(position))
    }
    
    public func index(after i: Int) -> Int {
        i + 1
    }
}
