//
//  TestSSA.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 08/03/2025.
//

import XCTest
@testable import CCompilerWithGenerics

struct BiDictionary<Left, Right> where Left: Hashable & Equatable, Right: Hashable & Equatable {
    private var first: [Left: Right] = [:]
    private var second: [Right: Left] = [:]
}

extension BiDictionary : ExpressibleByDictionaryLiteral {

    /// Creates a dictionary initialized with a dictionary literal.
    ///
    /// Do not call this initializer directly. It is called by the compiler to
    /// handle dictionary literals. To use a dictionary literal as the initial
    /// value of a dictionary, enclose a comma-separated list of key-value pairs
    /// in square brackets.
    ///
    /// For example, the code sample below creates a dictionary with string keys
    /// and values.
    ///
    ///     let countryCodes = ["BR": "Brazil", "GH": "Ghana", "JP": "Japan"]
    ///     print(countryCodes)
    ///     // Prints "["BR": "Brazil", "JP": "Japan", "GH": "Ghana"]"
    ///
    /// - Parameter elements: The key-value pairs that will make up the new
    ///   dictionary. Each key in `elements` must be unique.
    @inlinable public init(dictionaryLiteral elements: (Left, Right)...) {
        self.first.reserveCapacity(elements.count)
        self.second.reserveCapacity(elements.count)
        for (key, value) in elements {
            self.first[key] = value
            self.second[value] = key
        }
    }
    
    @inlinable public subscript(key: Left) -> Right? {
        self.first[key]
    }
    
    @inlinable public subscript(key: Right) -> Left? {
        self.second[key]
    }
}

final class TestSSA: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSSALowering() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "2",
            4: "3",
            7: "4",
            9: "1"
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node.Stripped] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .addExpression,
            .number(descriptorMap["2"]!),
            .timesExpression,
            .number(descriptorMap["3"]!),
            .subExpression,
            .number(descriptorMap["4"]!),
            .number(descriptorMap["1"]!)
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        let ssas = lower.convertToSSA()
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
[T1] = 2
[T2] = 3
[T3] = 4 minus 1
[T4] = [T2] times [T3]
a0 = [T1] plus [T4]
""")
    }
}
