//
//  TestLinearScanRegisterAllocation.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 12/03/2025.
//

import XCTest
@testable import CCompilerWithGenerics

final class TestLinearScanRegisterAllocation: XCTestCase {

    func testExample() throws {
        let stringResolver = StringResolver {
            [
                0: "a"
            ][$0]!
        }
        let t1 = Liveness.Var(.temp(1), using: stringResolver)
        let t2 = Liveness.Var(.temp(2), using: stringResolver)
        let t3 = Liveness.Var(.temp(3), using: stringResolver)
        let t4 = Liveness.Var(.temp(4), using: stringResolver)
        let a1 = Liveness.Var(.variable(0, 1), using: stringResolver)
        
        
        
        let livenessRanges = [
            t1: 0..<5,
            t2: 1..<4,
            t3: 2..<3,
            t4: 3..<4,
            a1: 4..<5,
        ]
        
        let graph = InterferenceGraph(
            livenessRanges: livenessRanges
        )
        
        graph.compute()
        
        
        
        let allocator = RegisterScan(
            liveness: graph.livenessRanges,
            interferenceGraph: graph.nodes
        )
        
        allocator.compute()
        
        XCTAssertTrue(true)
    }
    
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
        
        let interferenceGraph = InterferenceGraph(livenessRanges: livenessAnalysis.livenessRanges)
        
        interferenceGraph.compute()
        
        let allocator = RegisterScan(
            liveness: livenessAnalysis.livenessRanges,
            interferenceGraph: interferenceGraph.nodes
        )
        allocator.compute()
        
        XCTAssertEqual(allocator.registerAssignments[.variable("a", 1)], .r5)
        XCTAssertEqual(allocator.registerAssignments[.variable("b", 1)], .r4)
        XCTAssertEqual(allocator.registerAssignments[.variable("c", 1)], .r3)
    }
    
    func testReuseRegisters() {
        let input = """
a = 42;
b = 6;
a = 69;
c = 31;
d = b;
"""
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
        ssas.append(contentsOf: lower.lowerAssignmentOrExpressionToSSA())
        
        let livenessAnalysis = Liveness(
            instructions: ssas[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        livenessAnalysis.compute()
        
        let interferenceGraph = InterferenceGraph(livenessRanges: livenessAnalysis.livenessRanges)
        
        interferenceGraph.compute()
        
        let allocator = RegisterScan(
            liveness: livenessAnalysis.livenessRanges,
            interferenceGraph: interferenceGraph.nodes
        )
        allocator.compute()
        
        let repre = allocator.registerAssignments.stringRepresentation()
        print(repre)
        XCTAssertEqual(allocator.registerAssignments[.variable("a", 1)], .r5)
        XCTAssertEqual(allocator.registerAssignments[.variable("b", 1)], .r4)
        XCTAssertEqual(allocator.registerAssignments[.variable("c", 1)], .r5)
    }
}
