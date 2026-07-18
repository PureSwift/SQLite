//
//  Function.swift
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

    /// Registers a custom SQL scalar function.
    ///
    /// - Parameters:
    ///   - name: Name of the function as it will be invoked in SQL.
    ///   - argumentCount: Number of arguments the function accepts, or `nil` for a variable number of arguments.
    ///   - deterministic: Whether the function always returns the same result given the same inputs, allowing SQLite to optimize queries that use it.
    ///   - block: Closure invoked with the function's arguments, returning the value to bind as the result.
    func createFunction(
        _ name: String,
        argumentCount: Int32? = nil,
        deterministic: Bool = false,
        _ block: @escaping (borrowing [Binding]) throws -> Binding
    ) throws(SQLiteError) {
        try handle.createFunction(
            name,
            argumentCount: argumentCount ?? -1,
            deterministic: deterministic,
            block: block
        ).get()
    }

    /// Removes a previously registered custom SQL scalar function.
    func removeFunction(_ name: String, argumentCount: Int32? = nil) throws(SQLiteError) {
        try handle.removeFunction(name, argumentCount: argumentCount ?? -1).get()
    }
}

// MARK: - Private Implementation

fileprivate final class FunctionBox {

    let block: (borrowing [Binding]) throws -> Binding

    init(_ block: @escaping (borrowing [Binding]) throws -> Binding) {
        self.block = block
    }
}

internal extension Connection.Handle {

    func createFunction(
        _ name: String,
        argumentCount: Int32,
        deterministic: Bool,
        block: @escaping (borrowing [Binding]) throws -> Binding
    ) -> Result<Void, SQLiteError> {
        let box = FunctionBox(block)
        let context = Unmanaged.passRetained(box).toOpaque()
        var flags = SQLITE_UTF8
        if deterministic {
            flags |= SQLITE_DETERMINISTIC
        }
        let resultCode = sqlite3_create_function_v2(
            pointer,
            name,
            argumentCount,
            flags,
            context,
            { sqliteContext, argc, argv in
                guard let sqliteContext, let boxPointer = sqlite3_user_data(sqliteContext) else {
                    return
                }
                let box = Unmanaged<FunctionBox>.fromOpaque(boxPointer).takeUnretainedValue()
                let arguments: [Binding] = (0 ..< Int(argc)).map { index in
                    let value = argv?[index]
                    return Binding(sqliteValue: value)
                }
                do {
                    let result = try box.block(arguments)
                    sqliteContext.setResult(result)
                } catch {
                    sqliteContext.setError(error)
                }
            },
            nil,
            nil,
            { boxPointer in
                guard let boxPointer else { return }
                Unmanaged<FunctionBox>.fromOpaque(boxPointer).release()
            }
        )
        guard resultCode == SQLITE_OK else {
            // sqlite3_create_function_v2 invokes the xDestroy callback when
            // registration fails, so the box has already been released
            return check(resultCode)
        }
        return .success(())
    }

    func removeFunction(_ name: String, argumentCount: Int32) -> Result<Void, SQLiteError> {
        check(sqlite3_create_function_v2(pointer, name, argumentCount, SQLITE_UTF8, nil, nil, nil, nil, nil))
    }
}

internal extension Binding {

    init(sqliteValue value: OpaquePointer?) {
        guard let value else {
            self = .null
            return
        }
        switch sqlite3_value_type(value) {
        case SQLITE_INTEGER:
            self = .integer(sqlite3_value_int64(value))
        case SQLITE_FLOAT:
            self = .double(sqlite3_value_double(value))
        case SQLITE_TEXT:
            self = .text(sqlite3_value_text(value).flatMap { String(cString: $0) } ?? "")
        case SQLITE_BLOB:
            let count = sqlite3_value_bytes(value)
            guard count > 0, let bytes = sqlite3_value_blob(value) else {
                self = .blob(.zero(0))
                return
            }
            let data = Array(UnsafeRawBufferPointer(start: bytes, count: Int(count)))
            self = .blob(.pointer({ block in
                data.withUnsafeBytes { buffer in
                    block(buffer)
                }
            }))
        default:
            self = .null
        }
    }
}

internal extension OpaquePointer {

    /// Sets the result of a SQL function invocation, given `self` as the `sqlite3_context`.
    func setResult(_ binding: Binding) {
        switch binding {
        case .null:
            sqlite3_result_null(self)
        case let .integer(value):
            sqlite3_result_int64(self, value)
        case let .double(value):
            sqlite3_result_double(self, value)
        case let .text(value):
            sqlite3_result_text(self, value, -1, SQLITE_TRANSIENT)
        case .blob(.zero(let count)):
            sqlite3_result_zeroblob(self, count)
        case .blob(.pointer(let block)):
            _ = block { buffer in
                sqlite3_result_blob(self, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
                return .success(())
            }
        }
    }

    /// Reports `error` as the result of a SQL function invocation, given `self` as the `sqlite3_context`.
    func setError(_ error: Error) {
        let message = String(describing: error)
        sqlite3_result_error(self, message, -1)
    }
}
