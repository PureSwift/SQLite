//
//  Collation.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/16/26.
//

#if SQLITE_SWIFT_STANDALONE
import sqlite3
#elseif SQLITE_SWIFT_SQLCIPHER
import SQLCipher
#elseif os(Linux)
import SwiftToolchainCSQLite
#else
import SQLite3
#endif

public extension Connection {

    /// Registers a custom SQL collating sequence for use with `COLLATE` clauses.
    ///
    /// - Parameters:
    ///   - name: Name of the collation as it will be invoked in SQL (e.g. `COLLATE NAME`).
    ///   - compare: Compares two strings, returning a negative value if `lhs` sorts before `rhs`,
    ///     zero if they are equivalent, or a positive value if `lhs` sorts after `rhs` — matching
    ///     the convention of `strcmp`.
    func createCollation(_ name: String, _ compare: @escaping (_ lhs: String, _ rhs: String) -> Int) throws(SQLiteError) {
        try handle.createCollation(name, compare: compare).get()
    }

    /// Removes a previously registered custom collating sequence.
    func removeCollation(_ name: String) throws(SQLiteError) {
        try handle.removeCollation(name).get()
    }
}

// MARK: - Private Implementation

fileprivate final class CollationBox {

    let compare: (String, String) -> Int

    init(_ compare: @escaping (String, String) -> Int) {
        self.compare = compare
    }
}

internal extension Connection.Handle {

    func createCollation(_ name: String, compare: @escaping (String, String) -> Int) -> Result<Void, SQLiteError> {
        let box = CollationBox(compare)
        let context = Unmanaged.passRetained(box).toOpaque()
        let resultCode = sqlite3_create_collation_v2(
            pointer,
            name,
            SQLITE_UTF8,
            context,
            { pArg, length1, data1, length2, data2 in
                guard let pArg else {
                    return 0
                }
                let box = Unmanaged<CollationBox>.fromOpaque(pArg).takeUnretainedValue()
                let string1 = String(sqliteCollationBytes: data1, count: length1)
                let string2 = String(sqliteCollationBytes: data2, count: length2)
                return Int32(box.compare(string1, string2))
            },
            { pArg in
                guard let pArg else { return }
                Unmanaged<CollationBox>.fromOpaque(pArg).release()
            }
        )
        guard resultCode == SQLITE_OK else {
            Unmanaged<CollationBox>.fromOpaque(context).release()
            return check(resultCode)
        }
        return .success(())
    }

    func removeCollation(_ name: String) -> Result<Void, SQLiteError> {
        check(sqlite3_create_collation_v2(pointer, name, SQLITE_UTF8, nil, nil, nil))
    }
}

fileprivate extension String {

    init(sqliteCollationBytes pointer: UnsafeRawPointer?, count: Int32) {
        guard count > 0, let pointer else {
            self = ""
            return
        }
        self = String(decoding: UnsafeRawBufferPointer(start: pointer, count: Int(count)), as: UTF8.self)
    }
}
