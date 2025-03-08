//
//  TestLexer.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 08/03/2025.
//

import XCTest
@testable import CCompilerWithGenerics

final class TestLexer: XCTestCase {
    func testLexer() throws {
        let input = """
a = 2 + 3 * (4 - 1);
"""
        let lexer = Lexer(source: input[...])
        
        lexer.lex()
        
        XCTAssertEqual(lexer.tokens, [
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
        ])
    }
}
