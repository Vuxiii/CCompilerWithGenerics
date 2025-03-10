//
//  TestInterferenceGraph.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 11/03/2025.
//

import XCTest
@testable import CCompilerWithGenerics

final class TestInterferenceGraph: XCTestCase {

    func testSimpleAssignmentInterferenceGraph() throws {
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
        let nodes1 = graph.nodes[t1]!.connects.map(\.ssaVariable)
        let nodes2 = graph.nodes[t2]!.connects.map(\.ssaVariable)
        let nodes3 = graph.nodes[t3]!.connects.map(\.ssaVariable)
        let nodes4 = graph.nodes[t4]!.connects.map(\.ssaVariable)
        let nodesa1 = graph.nodes[a1]!.connects.map(\.ssaVariable)
        
        XCTAssertTrue(nodes1.allSatisfy { [a1, t3, t2, t4].contains($0)})
        XCTAssertTrue(nodes2.allSatisfy { [t3, t1, t4].contains($0)})
        XCTAssertTrue(nodes3.allSatisfy { [t2, t1].contains($0)})
        XCTAssertTrue(nodes4.allSatisfy { [t2, t1].contains($0)})
        XCTAssertTrue(nodesa1.allSatisfy { [t1].contains($0)})
    }

}
