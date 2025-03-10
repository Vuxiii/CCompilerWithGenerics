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
            .semicolon,
            .eof
        ])
    }
    
    func testGetSubstring() {
        
        let contents = """
struct Line {
    Point point1;
    Point point2;
};
struct Point {
    int x;
    int y;
};
int justADecl;
int a = 69;
a = 2 + 3 * (4 - 1); hej med dig 42.69
"""
        
        let lexer = Lexer(source: contents[...])
        lexer.lex()
        
        let actual = (0..<lexer.tokens.count).map { lexer.getSubstring(representedBy: $0) }
        let expected: [Substring] = [
            "struct",
            "Line",
            "{",
            "Point",
            "point1",
            ";",
            "Point",
            "point2",
            ";",
            "}",
            ";",
            "struct",
            "Point",
            "{",
            "int",
            "x",
            ";",
            "int",
            "y",
            ";",
            "}",
            ";",
            "int",
            "justADecl",
            ";",
            "int",
            "a",
            "=",
            "69",
            ";",
            "a",
            "=",
            "2",
            "+",
            "3",
            "*",
            "(",
            "4",
            "-",
            "1",
            ")",
            ";",
            "hej",
            "med",
            "dig",
            "42.69",
            "EOF"
        ]
        
        XCTAssertEqual(expected, actual)
        
    }
}
