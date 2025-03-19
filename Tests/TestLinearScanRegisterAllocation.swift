//
//  TestLinearScanRegisterAllocation.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 12/03/2025.
//

import XCTest
@testable import CCompilerWithGenerics

final class TestLinearScanRegisterAllocation: XCTestCase {
    func testThreeAssignments() {
        let input = """
a = 42;
b = 6;
c = 69;
"""
        let lexer = Lexer(source: input[...])
        lexer.lex()
        let parser = Parser(tokens: lexer.tokens[...])
        
        parser.parseAssignment()
        parser.parseAssignment()
        parser.parseAssignment()
        
        let lower = Lowering(
            nodes: parser.nodes[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        var ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        
        let livenessAnalysis = Liveness(
            instructions: ssas[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        livenessAnalysis.compute()
        livenessAnalysis.printLivenessRanges()
        let allocator = RegisterAllocation.LinearScan(
            liveness: livenessAnalysis.livenessRanges,
            availableRegisters: [.r4, .r5]
        )
        allocator.compute()
        
        XCTAssertEqual(allocator.registerAssignments[.variable("a", 1)], .r5)
        XCTAssertEqual(allocator.registerAssignments[.variable("b", 1)], .r4)
        XCTAssertEqual(allocator.registerAssignments[.variable("c", 1)], .r5)
    }
    
    func testReuseRegisters() {
        let input = """
a = 1;
b = 2;
c = a + b;
d = c;
e = d;
"""
        // 0 -> a0 = 1
        // 1 -> b0 = 2
        // 2 -> c0 = a0 + b0
        // 3 -> d0 = c0
        // 4 -> e0 = d0
        
        // Gives ranges
        // A: +---+
        // B:   +-+
        // C:     +-+
        // D:       +-+
        // E:         +-+
        //    0 1 2 3 4 5 6
        
        let lexer = Lexer(source: input[...])
        lexer.lex()
        let parser = Parser(tokens: lexer.tokens[...])
        
        parser.parse()
        
        let lower = Lowering(
            nodes: parser.nodes[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        var ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        
        let livenessAnalysis = Liveness(
            instructions: ssas[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        livenessAnalysis.compute()
        
        livenessAnalysis.printLivenessRanges()

        let allocator = RegisterAllocation.LinearScan(
            liveness: livenessAnalysis.livenessRanges,
            availableRegisters: [.r3, .r4, .r5]
        )
        allocator.compute()
        
        let repre = allocator.registerAssignments.stringRepresentation()
        print(repre)
        XCTAssertEqual(allocator.registerAssignments[.variable("a", 1)], .r5)
        XCTAssertEqual(allocator.registerAssignments[.variable("b", 1)], .r4)
        XCTAssertEqual(allocator.registerAssignments[.variable("c", 1)], .r3)
        XCTAssertEqual(allocator.registerAssignments[.variable("d", 1)], .r5)
        XCTAssertEqual(allocator.registerAssignments[.variable("e", 1)], .r3)
    }
    
    func testSpilling() throws {
        let input = """
a = 1;
b = 2;
c = a + b;
d = c;
e = d;
"""
        // 0 -> a0 = 1
        // 1 -> b0 = 2
        // 2 -> c0 = a0 + b0
        // 3 -> d0 = c0
        // 4 -> e0 = d0
        
        // Gives ranges
        // A: +---+
        // B:   +-+
        // C:     +-+
        // D:       +-+
        // E:         +-+
        //    0 1 2 3 4 5 6
        
        let lexer = Lexer(source: input[...])
        lexer.lex()
        let parser = Parser(tokens: lexer.tokens[...])
        
        parser.parse()
        
        let lower = Lowering(
            nodes: parser.nodes[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        var ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        
        let livenessAnalysis = Liveness(
            instructions: ssas[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        livenessAnalysis.compute()
        
        livenessAnalysis.printLivenessRanges()

        let allocator = RegisterAllocation.LinearScan(
            liveness: livenessAnalysis.livenessRanges,
            availableRegisters: [.r4, .r5]
        )
        allocator.compute()
        
        let repre = allocator.registerAssignments.stringRepresentation()
        print(repre)
        
        let a = try XCTUnwrap(allocator.getAssignment(for: .variable("a", 1)))
        let b = try XCTUnwrap(allocator.getAssignment(for: .variable("b", 1)))
        let c = try XCTUnwrap(allocator.getAssignment(for: .variable("c", 1)))
        let d = try XCTUnwrap(allocator.getAssignment(for: .variable("d", 1)))
        let e = try XCTUnwrap(allocator.getAssignment(for: .variable("e", 1)))
        
        XCTAssertEqual(a, .register(.r5))
        XCTAssertEqual(b, .register(.r4))
        XCTAssertEqual(c, .spilled(0))
        XCTAssertEqual(d, .register(.r5))
        XCTAssertEqual(e, .register(.r4))
    }
}
