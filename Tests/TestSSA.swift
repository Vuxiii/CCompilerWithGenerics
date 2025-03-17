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
        
        let AST: [Node] = [
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
        
        let ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
[T1] = 2
[T2] = 3
[T3] = 4 minus 1
[T4] = [T2] times [T3]
a1 = [T1] plus [T4]
""")
    }
    
    func testSSALowering_simpleAssignment_singleNumber() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "2"
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .number(descriptorMap["2"]!)
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        let ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
a1 = 2
""")
    }
    
    func testSSALowering_simpleAssignment_WithOneBinaryOperator() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "2",
            4: "4"
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .addExpression,
            .number(descriptorMap["2"]!),
            .number(descriptorMap["4"]!)
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        let ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
a1 = 2 plus 4
""")
    }
    
    func testSSALowering_simpleAssignment_WithTwoBinaryOperator() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "2",
            4: "4",
            6: "8",
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .timesExpression,
            .addExpression,
            .number(descriptorMap["2"]!),
            .number(descriptorMap["4"]!),
            .number(descriptorMap["8"]!)
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        let ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
[T1] = 2 plus 4
a1 = [T1] times 8
""")
    }
    
    func testSSALowering_simpleAssignment_WithTwoBinaryOperator_UsingItself() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "2",
            4: "4",
            6: "8",
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .timesExpression,
            .addExpression,
            .identifier(descriptorMap["a"]!),
            .identifier(descriptorMap["a"]!),
            .identifier(descriptorMap["a"]!)
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        let ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
[T1] = a0 plus a0
a1 = [T1] times a0
""")
    }
    
    func testSSALowering_simpleAssignment_WithTwoBinaryOperator_AndMultipleVariables() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "b",
            4: "c",
            6: "d",
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .timesExpression,
            .addExpression,
            .identifier(descriptorMap["b"]!),
            .identifier(descriptorMap["c"]!),
            .identifier(descriptorMap["d"]!)
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        let ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
[T1] = b0 plus c0
a1 = [T1] times d0
""")
    }
    
    func testSSALowering_MultipleAssignments() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "2",
            4: "3",
            6: "4",
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .number(descriptorMap["2"]!),
            .assignment,
            .identifier(descriptorMap["a"]!),
            .addExpression,
            .identifier(descriptorMap["a"]!),
            .number(descriptorMap["2"]!),
            .assignment,
            .identifier(descriptorMap["a"]!),
            .timesExpression,
            .identifier(descriptorMap["a"]!),
            .number(descriptorMap["4"]!)
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        var ssas = lower.lowerAssignmentOrExpressionToSSA()
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
a1 = 2
a2 = a1 plus 2
a3 = a2 times 4
""")
    }
    
    func testSSALowering_MultipleAssignments_withMultipleTemp() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "2",
            4: "3",
            6: "4",
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .number(descriptorMap["2"]!),
            .assignment,
            .identifier(descriptorMap["a"]!),
            .addExpression,
            .identifier(descriptorMap["a"]!),
            .timesExpression,
            .number(descriptorMap["2"]!),
            .number(descriptorMap["3"]!),
            .assignment,
            .identifier(descriptorMap["a"]!),
            .timesExpression,
            .identifier(descriptorMap["a"]!),
            .number(descriptorMap["4"]!)
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        var ssas = lower.lowerAssignmentOrExpressionToSSA()
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
a1 = 2
[T1] = a1
[T2] = 2 times 3
a2 = [T1] plus [T2]
a3 = a2 times 4
""")
    }
    
    func testSSALowering_MultipleAssignments_withMultipleTemp_More() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "2",
            4: "3",
            6: "4",
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .number(descriptorMap["2"]!),
            .assignment,
            .identifier(descriptorMap["a"]!),
            .addExpression,
            .identifier(descriptorMap["a"]!),
            .timesExpression,
            .number(descriptorMap["2"]!),
            .number(descriptorMap["3"]!),
            .assignment,
            .identifier(descriptorMap["a"]!),
            .timesExpression,
            .identifier(descriptorMap["a"]!),
            .addExpression,
            .number(descriptorMap["2"]!),
            .number(descriptorMap["4"]!)
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        var ssas = lower.lowerAssignmentOrExpressionToSSA()
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
a1 = 2
[T1] = a1
[T2] = 2 times 3
a2 = [T1] plus [T2]
[T3] = a2
[T4] = 2 plus 4
a3 = [T3] times [T4]
""")
    }
    
    func testSSALowering_ReuseVariable() throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "a",
            2: "b",
            4: "c",
            6: "10",
            8: "11",
            10: "12",
            12: "13",
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .assignment,
            .identifier(descriptorMap["a"]!),
            .number(descriptorMap["10"]!),
            .assignment,
            .identifier(descriptorMap["b"]!),
            .number(descriptorMap["11"]!),
            .assignment,
            .identifier(descriptorMap["a"]!),
            .number(descriptorMap["12"]!),
            .assignment,
            .identifier(descriptorMap["c"]!),
            .number(descriptorMap["13"]!),
        ]
        let lower = Lowering(
            nodes: AST[...],
            stringResolver: stringResolver
        )
        
        var ssas = lower.lowerAssignmentOrExpressionToSSA()
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        
        let strings = ssas.map { $0.stringRepresentation(resolver: stringResolver) }
            .joined(separator: "\n")
        
        XCTAssertEqual(strings,  """
a1 = 10
b1 = 11
a1 = 12
c1 = 13
""")
    }
}
