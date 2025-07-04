//
//  TypeAffinity.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
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

/**
 Column Storage Type
 
 The type affinity of a column is the recommended type for data stored in that column. The important idea here is that the type is recommended, not required. Any column can still store any type of data. It is just that some columns, given the choice, will prefer to use one storage class over another. The preferred storage class for a column is called its "affinity".

 Each column in an SQLite 3 database is assigned one of the following type affinities:

 - TEXT
 - NUMERIC
 - INTEGER
 - REAL
 - BLOB
 
 [See Also](https://sqlite.org/datatype3.html#determination_of_column_affinity)
 */
public enum TypeAffinity: String, Equatable, Hashable, CaseIterable, Sendable {
    
    /**
     A column with TEXT affinity stores all data using storage classes NULL, TEXT or BLOB. If numerical data is inserted into a column with TEXT affinity it is converted into text form before being stored.
     */
    case text = "TEXT"
    
    /**
     A column that uses INTEGER affinity behaves the same as a column with NUMERIC affinity. The difference between INTEGER and NUMERIC affinity is only evident in a CAST expression: The expression "CAST(4.0 AS INT)" returns an integer 4, whereas "CAST(4.0 AS NUMERIC)" leaves the value as a floating-point 4.0.
     */
    case integer = "INTEGER"
    
    /**
     A column with NUMERIC affinity may contain values using all five storage classes. When text data is inserted into a NUMERIC column, the storage class of the text is converted to INTEGER or REAL (in order of preference) if the text is a well-formed integer or real literal, respectively. If the TEXT value is a well-formed integer literal that is too large to fit in a 64-bit signed integer, it is converted to REAL. For conversions between TEXT and REAL storage classes, only the first 15 significant decimal digits of the number are preserved. If the TEXT value is not a well-formed integer or real literal, then the value is stored as TEXT. For the purposes of this paragraph, hexadecimal integer literals are not considered well-formed and are stored as TEXT. (This is done for historical compatibility with versions of SQLite prior to version 3.8.6 2014-08-15 where hexadecimal integer literals were first introduced into SQLite.) If a floating point value that can be represented exactly as an integer is inserted into a column with NUMERIC affinity, the value is converted into an integer. No attempt is made to convert NULL or BLOB values.
     */
    case numeric = "NUMERIC"
    
    /**
     A column with REAL affinity behaves like a column with NUMERIC affinity except that it forces integer values into floating point representation. (As an internal optimization, small floating point values with no fractional component and stored in columns with REAL affinity are written to disk as integers in order to take up less space and are automatically converted back into floating point as the value is read out. This optimization is completely invisible at the SQL level and can only be detected by examining the raw bits of the database file.)


     */
    case real = "REAL"
    
    /**
     A column with affinity BLOB does not prefer one storage class over another and no attempt is made to coerce data from one storage class into another.
     */
    case blob = "BLOB"
}

public extension TypeAffinity {
    
    /**
     For tables not declared as STRICT, the affinity of a column is determined by the declared type of the column, according to the following rules in the order shown:

     If the declared type contains the string "INT" then it is assigned INTEGER affinity.

     If the declared type of the column contains any of the strings "CHAR", "CLOB", or "TEXT" then that column has TEXT affinity. Notice that the type VARCHAR contains the string "CHAR" and is thus assigned TEXT affinity.

     If the declared type for a column contains the string "BLOB" or if no type is specified then the column has affinity BLOB.

     If the declared type for a column contains any of the strings "REAL", "FLOA", or "DOUB" then the column has REAL affinity.

     Otherwise, the affinity is NUMERIC.

     Note that the order of the rules for determining column affinity is important. A column whose declared type is "CHARINT" will match both rules 1 and 2 but the first rule takes precedence and so the column affinity will be INTEGER.
     
     [See Also](https://sqlite.org/datatype3.html#determination_of_column_affinity)
     */
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    init(_ string: String) {
        let test = string.uppercased()
        if test.contains("INT") { // Rule 1
            self = .integer
        } else if ["CHAR", "CLOB", "TEXT"].first(where: {test.contains($0)}) != nil { // Rule 2
            self = .text
        } else if string.contains("BLOB") { // Rule 3
            self = .blob
        } else if ["REAL", "FLOA", "DOUB"].first(where: {test.contains($0)}) != nil { // Rule 4
            self = .real
        } else { // Rule 5
            self = .numeric
        }
    }
    
    /// Affinity Rule
    var rule: Int {
        switch self {
        case .integer:
            1
        case .text:
            2
        case .blob:
            3
        case .real:
            4
        case .numeric:
            5
        }
    }
}

// MARK: - CustomStringConvertible

extension TypeAffinity: CustomStringConvertible {
    
    public var description: String {
        rawValue
    }
}
