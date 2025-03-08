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

    func testDeclAssignment() {
        let tokens: [Token] = [
            .identifier,
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
        parser.parseVariableAssignmentDeclaration()
        
        XCTAssertEqual(parser.nodes, [
            .variableDeclaration,
            .identifier(1),
            .identifier(0),
            .assignment,
            .identifier(1),
            .addExpression,
            .number(3),
            .timesExpression,
            .number(5),
            .subExpression,
            .number(8),
            .number(10)
        ])
    }
    
    func testVarDecl() {
        let tokens: [Token] = [
            .identifier,
            .identifier,
            .semicolon
        ]
        
        let parser = Parser(tokens: tokens[...])
        parser.parseVariableDeclaration()
        
        XCTAssertEqual(parser.nodes, [
            .variableDeclaration,
            .identifier(1),
            .identifier(0)
        ])
    }
    
    func testStructDeclNoFields() {
        let tokens: [Token] = [
            .struct,
            .identifier,
            .lcurl,
            .rcurl,
            .semicolon
        ]
        
        let parser = Parser(tokens: tokens[...])
        parser.parseStructDeclaration()
        
        XCTAssertEqual(parser.nodes, [
            .structDeclaration,
            .identifier(1)
        ])
    }
}
