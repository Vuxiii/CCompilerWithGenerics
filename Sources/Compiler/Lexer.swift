//
//  Lexer.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 03/03/2025.
//

import Foundation

enum Token: Equatable {
    case identifier
    case number
    case plus
    case minus
    case times
    case div
    case lcurl
    case rcurl
    case lbracket
    case rbracket
    case lparen
    case rparen
    case `struct`
    case equal
    case doubleEqual
    case semicolon
}

extension Token {
    public typealias Descriptor = [Token].SubSequence.Index
}

struct StringResolver {
    let resolve: (Token.Descriptor) -> Substring
}

class Lexer {
    let originalSource: Substring
    private var source: Substring
    var tokens: [Token] = []
    
    public init(source: Substring) {
        self.originalSource = source
        self.source = originalSource
    }
    
    public func getSubstring( // TODO(William): Possibly put in a cache if it takes too long to lookup the result
        representedBy descriptor: Token.Descriptor
    ) -> Substring {
        var copy = originalSource
        for _ in 0..<descriptor {
            _ = Lexer.lexSingleToken(from: &copy)
        }
        var start = copy.startIndex
        _ = Lexer.lexSingleToken(from: &copy)
        let end = copy.startIndex
        while originalSource[start].isWhitespace {
            start = originalSource.index(after: start)
        }
        return originalSource[start..<end]
    }
    
    private static func lexSingleToken(from source: inout Substring) -> Token? {
        try? source.trimPrefix(while: \.isWhitespace)
        guard let char = source.popFirst() else { return nil }
        switch char {
            case ";":
                return .semicolon
            case "{":
                return .lcurl
            case "}":
                return .rcurl
            case "+":
                return .plus
            case "-":
                return .minus
            case "*":
                return .times
            case "/":
                return .div
            case "[":
                return .lbracket
            case "]":
                return .rbracket
            case "(":
                return .lparen
            case ")":
                return .rparen
            case "=":
                if let nextChar = source.first, nextChar == "=" {
                    source.removeFirst()
                    return .doubleEqual
                } else {
                    return .equal
                }
            case "1", "2", "3", "4", "5", "6", "7", "8", "9", "0":
                while let next = source.first, next.isNumber || next == "." {
                    _ = source.removeFirst()
                }
                return .number
            default:
                // Identifier
                if source.starts(with: "truct") {
                    source.removeFirst("struct".count);
                    return .struct
                }
                while let next = source.first, next.isLetter || next.isNumber || next == "_" {
                    _ = source.removeFirst()
                }
                return .identifier
        }
    }
    
    public func lex() {
        guard tokens.isEmpty else { return }
        
        while let token = Lexer.lexSingleToken(from: &source) {
            tokens.append(token)
        }
    }
}
