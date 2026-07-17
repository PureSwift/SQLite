//
//  WindowFunction.swift
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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, visionOS 1.0, *)
public extension Connection {

    /// Registers a custom SQL aggregate window function (e.g. for use with `OVER (...)`).
    ///
    /// - Parameters:
    ///   - name: Name of the function as it will be invoked in SQL.
    ///   - argumentCount: Number of arguments the function accepts, or `nil` for a variable number of arguments.
    ///   - deterministic: Whether the function always returns the same result given the same inputs.
    ///   - initialState: Produces the starting accumulator value for each window partition.
    ///   - step: Invoked when a row enters the window frame, mutating the accumulator.
    ///   - inverse: Invoked when a row leaves the window frame, undoing its effect on the accumulator.
    ///   - value: Produces the function's current result from the accumulator without ending the partition.
    ///   - final: Produces the function's result from the accumulator once the partition is exhausted.
    func createWindowFunction<State>(
        _ name: String,
        argumentCount: Int32? = nil,
        deterministic: Bool = false,
        initialState: @escaping () -> State,
        step: @escaping (inout State, borrowing [Binding]) -> Void,
        inverse: @escaping (inout State, borrowing [Binding]) -> Void,
        value: @escaping (State) -> Binding,
        final: @escaping (State) -> Binding
    ) throws(SQLiteError) {
        try handle.createWindowFunction(
            name,
            argumentCount: argumentCount ?? -1,
            deterministic: deterministic,
            initialState: initialState,
            step: step,
            inverse: inverse,
            value: value,
            final: final
        ).get()
    }
}

// MARK: - Private Implementation

/// Type-erases the generic `State` of `createWindowFunction` so it can be stored
/// behind a single, non-generic `sqlite3_user_data` pointer.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, visionOS 1.0, *)
internal final class WindowFunctionBox {

    let makeState: () -> AnyObject

    let step: (AnyObject, borrowing [Binding]) -> Void

    let inverse: (AnyObject, borrowing [Binding]) -> Void

    let value: (AnyObject) -> Binding

    let final: (AnyObject) -> Binding

    init<State>(
        initialState: @escaping () -> State,
        step: @escaping (inout State, borrowing [Binding]) -> Void,
        inverse: @escaping (inout State, borrowing [Binding]) -> Void,
        value: @escaping (State) -> Binding,
        final: @escaping (State) -> Binding
    ) {
        self.makeState = { AggregateStateBox(initialState()) }
        self.step = { boxed, arguments in
            let box = boxed as! AggregateStateBox<State>
            step(&box.state, arguments)
        }
        self.inverse = { boxed, arguments in
            let box = boxed as! AggregateStateBox<State>
            inverse(&box.state, arguments)
        }
        self.value = { boxed in
            let box = boxed as! AggregateStateBox<State>
            return value(box.state)
        }
        self.final = { boxed in
            let box = boxed as! AggregateStateBox<State>
            return final(box.state)
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, visionOS 1.0, *)
internal extension Connection.Handle {

    func createWindowFunction<State>(
        _ name: String,
        argumentCount: Int32,
        deterministic: Bool,
        initialState: @escaping () -> State,
        step: @escaping (inout State, borrowing [Binding]) -> Void,
        inverse: @escaping (inout State, borrowing [Binding]) -> Void,
        value: @escaping (State) -> Binding,
        final: @escaping (State) -> Binding
    ) -> Result<Void, SQLiteError> {
        let box = WindowFunctionBox(
            initialState: initialState,
            step: step,
            inverse: inverse,
            value: value,
            final: final
        )
        let context = Unmanaged.passRetained(box).toOpaque()
        var flags = SQLITE_UTF8
        if deterministic {
            flags |= SQLITE_DETERMINISTIC
        }
        let resultCode = sqlite3_create_window_function(
            pointer,
            name,
            argumentCount,
            flags,
            context,
            { sqliteContext, argc, argv in
                guard let sqliteContext, let boxPointer = sqlite3_user_data(sqliteContext) else {
                    return
                }
                let functionBox = Unmanaged<WindowFunctionBox>.fromOpaque(boxPointer).takeUnretainedValue()
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
                let functionBox = Unmanaged<WindowFunctionBox>.fromOpaque(boxPointer).takeUnretainedValue()
                let stateObject = sqliteContext.finalizeAggregateState() ?? functionBox.makeState()
                sqliteContext.setResult(functionBox.final(stateObject))
            },
            { sqliteContext in
                guard let sqliteContext, let boxPointer = sqlite3_user_data(sqliteContext) else {
                    return
                }
                let functionBox = Unmanaged<WindowFunctionBox>.fromOpaque(boxPointer).takeUnretainedValue()
                let stateObject = sqliteContext.peekAggregateState() ?? functionBox.makeState()
                sqliteContext.setResult(functionBox.value(stateObject))
            },
            { sqliteContext, argc, argv in
                guard let sqliteContext, let boxPointer = sqlite3_user_data(sqliteContext) else {
                    return
                }
                let functionBox = Unmanaged<WindowFunctionBox>.fromOpaque(boxPointer).takeUnretainedValue()
                guard let stateObject = sqliteContext.aggregateState(functionBox.makeState) else {
                    return
                }
                let arguments: [Binding] = (0 ..< Int(argc)).map { Binding(sqliteValue: argv?[$0]) }
                functionBox.inverse(stateObject, arguments)
            },
            { boxPointer in
                guard let boxPointer else { return }
                Unmanaged<WindowFunctionBox>.fromOpaque(boxPointer).release()
            }
        )
        guard resultCode == SQLITE_OK else {
            Unmanaged<WindowFunctionBox>.fromOpaque(context).release()
            return check(resultCode)
        }
        return .success(())
    }
}
