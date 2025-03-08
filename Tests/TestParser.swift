//
//  TestParser.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 08/03/2025.
//

import XCTest
@testable import CCompilerWithGenerics

final class TestParser: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAssignment() {
        let tokens: [Token] = [
            .identifier,
            .equal,
            .number,
            .plus,
            .number,
            .times,
            .lparen,
            .number,
            .minus,
            .number,
            .rparen,
            .semicolon
        ]
        
        let parser = Parser(tokens: tokens[...])
        parser.parseAssignment()
        
        XCTAssertEqual(parser.nodes, [
            .assignment,
            .identifier(0),
            .addExpression,
            .number(2),
            .timesExpression,
            .number(4),
            .subExpression,
            .number(7),
            .number(9)
        ])
    }
}
