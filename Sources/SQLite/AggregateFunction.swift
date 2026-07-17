//
//  AggregateFunction.swift
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

    /// Registers a custom SQL aggregate function (e.g. `SUM`, `GROUP_CONCAT`).
    ///
    /// - Parameters:
    ///   - name: Name of the function as it will be invoked in SQL.
    ///   - argumentCount: Number of arguments the function accepts, or `nil` for a variable number of arguments.
    ///   - deterministic: Whether the function always returns the same result given the same inputs.
    ///   - initialState: Produces the starting accumulator value for each group.
    ///   - step: Invoked once per row in the group, mutating the accumulator.
    ///   - final: Produces the function's result from the accumulator once the group is exhausted.
    func createAggregateFunction<State>(
        _ name: String,
        argumentCount: Int32? = nil,
        deterministic: Bool = false,
        initialState: @escaping () -> State,
        step: @escaping (inout State, borrowing [Binding]) -> Void,
        final: @escaping (State) -> Binding
    ) throws(SQLiteError) {
        try handle.createAggregateFunction(
            name,
            argumentCount: argumentCount ?? -1,
            deterministic: deterministic,
            initialState: initialState,
            step: step,
            final: final
        ).get()
    }
}

// MARK: - Private Implementation

/// Retains a per-group accumulator behind a type-erased box, so it can be stored via
/// `sqlite3_aggregate_context`, which only provides a raw memory slot.
internal final class AggregateStateBox<State> {

    var state: State

    init(_ state: State) {
        self.state = state
    }
}

/// Type-erases the generic `State` of `createAggregateFunction` so it can be stored
/// behind a single, non-generic `sqlite3_user_data` pointer.
internal final class AggregateFunctionBox {

    let makeState: () -> AnyObject

    let step: (AnyObject, borrowing [Binding]) -> Void

    let final: (AnyObject) -> Binding

    init<State>(
        initialState: @escaping () -> State,
        step: @escaping (inout State, borrowing [Binding]) -> Void,
        final: @escaping (State) -> Binding
    ) {
        self.makeState = { AggregateStateBox(initialState()) }
        self.step = { boxed, arguments in
            let box = boxed as! AggregateStateBox<State>
            step(&box.state, arguments)
        }
        self.final = { boxed in
            let box = boxed as! AggregateStateBox<State>
            return final(box.state)
        }
    }
}

internal extension Connection.Handle {

    func createAggregateFunction<State>(
        _ name: String,
        argumentCount: Int32,
        deterministic: Bool,
        initialState: @escaping () -> State,
        step: @escaping (inout State, borrowing [Binding]) -> Void,
        final: @escaping (State) -> Binding
    ) -> Result<Void, SQLiteError> {
        let box = AggregateFunctionBox(initialState: initialState, step: step, final: final)
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
            nil,
            { sqliteContext, argc, argv in
                guard let sqliteContext, let boxPointer = sqlite3_user_data(sqliteContext) else {
                    return
                }
                let functionBox = Unmanaged<AggregateFunctionBox>.fromOpaque(boxPointer).takeUnretainedValue()
                guard let stateObject = sqliteContext.aggregateState(functionBox.makeState) else {
                    return
                }
                let arguments: [Binding] = (0 ..< Int(argc)).map { Binding(sqliteValue: argv?[$0]) }
                functionBox.step(stateObject, arguments)
            },
            { sqliteContext in
                guard let sqliteContext, let boxPointer = sqlite3_user_data(sqliteContext) else {
                    return
                }
                let functionBox = Unmanaged<AggregateFunctionBox>.fromOpaque(boxPointer).takeUnretainedValue()
                let stateObject = sqliteContext.finalizeAggregateState() ?? functionBox.makeState()
                sqliteContext.setResult(functionBox.final(stateObject))
            },
            { boxPointer in
                guard let boxPointer else { return }
                Unmanaged<AggregateFunctionBox>.fromOpaque(boxPointer).release()
            }
        )
        guard resultCode == SQLITE_OK else {
            Unmanaged<AggregateFunctionBox>.fromOpaque(context).release()
            return check(resultCode)
        }
        return .success(())
    }
}

internal extension OpaquePointer {

    /// Retrieves this invocation's accumulator, allocating and retaining it via
    /// `sqlite3_aggregate_context` on first use within the group.
    func aggregateState(_ makeState: () -> AnyObject) -> AnyObject? {
        guard let raw = sqlite3_aggregate_context(self, Int32(MemoryLayout<UnsafeMutableRawPointer?>.size)) else {
            return nil
        }
        let slot = raw.assumingMemoryBound(to: UnsafeMutableRawPointer?.self)
        if let existing = slot.pointee {
            return Unmanaged<AnyObject>.fromOpaque(existing).takeUnretainedValue()
        }
        let state = makeState()
        slot.pointee = Unmanaged.passRetained(state).toOpaque()
        return state
    }

    /// Retrieves this invocation's accumulator without allocating a new one, leaving
    /// ownership untouched. Returns `nil` if `xStep` was never called.
    func peekAggregateState() -> AnyObject? {
        guard let raw = sqlite3_aggregate_context(self, 0) else {
            return nil
        }
        let slot = raw.assumingMemoryBound(to: UnsafeMutableRawPointer?.self)
        guard let existing = slot.pointee else {
            return nil
        }
        return Unmanaged<AnyObject>.fromOpaque(existing).takeUnretainedValue()
    }

    /// Retrieves and releases this invocation's accumulator without allocating a new one,
    /// for use in `xFinal`. Returns `nil` if `xStep` was never called (an empty group).
    func finalizeAggregateState() -> AnyObject? {
        guard let raw = sqlite3_aggregate_context(self, 0) else {
            return nil
        }
        let slot = raw.assumingMemoryBound(to: UnsafeMutableRawPointer?.self)
        guard let existing = slot.pointee else {
            return nil
        }
        return Unmanaged<AnyObject>.fromOpaque(existing).takeRetainedValue()
    }
}
