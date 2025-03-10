//
//  TestLayout.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 08/03/2025.
//

import XCTest
@testable import CCompilerWithGenerics

final class TestLayout: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testScopeLayoutWithThreeInts() async throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "int",
            1: "a",
            2: "b",
            3: "c",
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        let AST: [Node] = [
            .scopeOpen,
            .variableDeclaration,
            .identifier(descriptorMap["a"]!),
            .identifier(descriptorMap["int"]!),
            .variableDeclaration,
            .identifier(descriptorMap["b"]!),
            .identifier(descriptorMap["int"]!),
            .variableDeclaration,
            .identifier(descriptorMap["c"]!),
            .identifier(descriptorMap["int"]!),
            .scopeEnd,
        ]
        let layout = Layout(nodes: AST[...], stringResolver: stringResolver)
        layout.computeLayouts()
        
        let scopeLayout = layout.scopes[1..<11]
        
        let offsetForA = await scopeLayout?.offset(for: "a")
        let offsetForB = await scopeLayout?.offset(for: "b")
        let offsetForC = await scopeLayout?.offset(for: "c")
        
        XCTAssertNotNil(scopeLayout)
        
        
        XCTAssertEqual(offsetForA, 0)
        XCTAssertEqual(offsetForB, 4)
        XCTAssertEqual(offsetForC, 8)
    }
    
    func testScopeLayoutWithStruct() async throws {
        let descriptorMap: BiDictionary<Int, String> = [
            0: "int",
            1: "a",
            2: "b",
            3: "c",
            4: "Point"
        ]
        
        let stringResolver = StringResolver { descriptor in
            return descriptorMap[descriptor]![...]
        }
        
        await TypesBroker.shared.publish(
            layout: .init(
                typeName: "Point",
                fields: [
                    .init(name: "x", type: "int"),
                    .init(name: "y", type: "int"),
                ]
            )
        )
        
        let AST: [Node] = [
            .scopeOpen,
            .variableDeclaration,
            .identifier(descriptorMap["a"]!),
            .identifier(descriptorMap["Point"]!),
            .variableDeclaration,
            .identifier(descriptorMap["b"]!),
            .identifier(descriptorMap["int"]!),
            .variableDeclaration,
            .identifier(descriptorMap["c"]!),
            .identifier(descriptorMap["Point"]!),
            .scopeEnd,
        ]
        let layout = Layout(nodes: AST[...], stringResolver: stringResolver)
        layout.computeLayouts()
        
        let scopeLayout = layout.scopes[1..<11]
        
        let offsetForA = await scopeLayout?.offset(for: "a")
        let offsetForB = await scopeLayout?.offset(for: "b")
        let offsetForC = await scopeLayout?.offset(for: "c")
        
        XCTAssertNotNil(scopeLayout)
        
        XCTAssertEqual(offsetForA, 0)
        XCTAssertEqual(offsetForB, 8)
        XCTAssertEqual(offsetForC, 12)
    }

}
