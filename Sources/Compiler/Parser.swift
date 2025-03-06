//
//  Parser.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 04/03/2025.
//

enum Node: Equatable {
    case assignment
    
    case variableDeclaration
    case structDeclaration
    case structMemberDeclaration
    
    case addExpression
    case subExpression
    case divExpression
    case timesExpression
    
    case scope
    case scopeEnd
    
    case number(Token.Descriptor)
    case identifier(Token.Descriptor)
}

extension Node {
    enum Stripped: Equatable {
        case assignment
        
        case addExpression
        case subExpression
        case divExpression
        case timesExpression
        
        case scope
        case scopeEnd
        
        case number(Token.Descriptor)
        case identifier(Token.Descriptor)
        
        static func construct(from node: Node) -> Self? {
            switch node {
                case .assignment:
                    .assignment
                case .variableDeclaration:
                    nil
                case .structDeclaration:
                    nil
                case .structMemberDeclaration:
                    nil
                case .addExpression:
                    .addExpression
                case .subExpression:
                    .subExpression
                case .divExpression:
                    .divExpression
                case .timesExpression:
                    .timesExpression
                case .scope:
                    .scope
                case .scopeEnd:
                    .scopeEnd
                case .number(let num):
                    .number(num)
                case .identifier(let ident):
                    .identifier(ident)
            }
        }
    }
    
    
}

extension Node {
    @inlinable static func constructVariableDeclaration(
        variableName: Token.Descriptor,
        typeName: Token.Descriptor
    ) -> [Self] {
        [.variableDeclaration, .identifier(variableName), .identifier(typeName)]
    }
    
    @inlinable static func constructStructDeclaration(
        structName: Token.Descriptor
    ) -> [Self] {
        [.structDeclaration, .identifier(structName)]
    }
    
    @inlinable static func constructStructMemberDeclaration(
        memberName: Token.Descriptor,
        typeName: Token.Descriptor
    ) -> [Self] {
        [.structMemberDeclaration, .identifier(memberName), .identifier(typeName)]
    }
}

extension Node {
    public typealias Descriptor = [Node].SubSequence.Index
}

class ExtraData {
    struct ScopeLayout {
        
    }
    
    var scopes: [Node.Descriptor: ScopeLayout] = [:]
}

extension Parser {
    func getCurrentTokenDescriptor() -> Node.Descriptor {
        return tokens.startIndex // Meh
    }
}

class Parser {
    var nodes: [Node] = []
    let originalTokens: [Token].SubSequence
    var tokens: [Token].SubSequence
    
    
    init(tokens: [Token].SubSequence) {
        self.tokens = tokens
        self.originalTokens = tokens
    }
    
    
    func token(at: Int) -> Token {
        tokens[tokens.index(tokens.startIndex, offsetBy: at)]
    }
    
    func parse() {
//        parseStructDeclaration()
//        parseStructDeclaration()
//        parseVariableDeclaration()
//        parseVariableAssignmentDeclaration()
        parseAssignment()
    }
    
    private func parseTopLevel() {
        
    }
    
    private func parseStatement() {
        
    }
    
    private func parseScope() {
        precondition(token(at: 0) == .lcurl)
        
        tokens.removeFirst()
        nodes.append(.scope)
        while tokens.first != .rcurl {
            parseStatement()
        }
        tokens.removeFirst()
        nodes.append(.scopeEnd)
    }
    
    private func parseStructDeclaration() {
        precondition(tokens.count >= 3)
        precondition(token(at: 0) == .struct)
        precondition(token(at: 1) == .identifier)
        precondition(token(at: 2) == .lcurl)
        
        let structNameDescriptor = getCurrentTokenDescriptor().advanced(by: 1)
        nodes.append(
            contentsOf: Node.constructStructDeclaration(structName: structNameDescriptor)
        )
        
        tokens.removeFirst(3)
        
        while let first = tokens.first, first != .rcurl {
            precondition(token(at: 0) == .identifier)
            precondition(token(at: 1) == .identifier)
            precondition(token(at: 2) == .semicolon)
            
            let memberDescriptor = getCurrentTokenDescriptor().advanced(by: 1)
            let typeDescriptor = getCurrentTokenDescriptor()
            
            nodes.append(contentsOf: Node.constructStructMemberDeclaration(
                memberName: memberDescriptor,
                typeName: typeDescriptor
            ))
            
            tokens.removeFirst(3)
        }
        precondition(token(at: 1) == .semicolon)
        tokens.removeFirst(2)
        
    }
    
    private func parseVariableDeclaration() {
        precondition(tokens.count >= 3)
        precondition(token(at: 0) == .identifier)
        precondition(token(at: 1) == .identifier)
        precondition(token(at: 2) == .semicolon)
        
        let nameDescriptor = getCurrentTokenDescriptor().advanced(by: 1)
        let typeDescriptor = getCurrentTokenDescriptor()
        
        nodes.append(contentsOf: Node.constructVariableDeclaration(
            variableName: nameDescriptor,
            typeName: typeDescriptor)
        )
        
        tokens.removeFirst(3)
    }
    
    private func parseVariableAssignmentDeclaration() {
        precondition(tokens.count >= 3)
        precondition(token(at: 0) == .identifier) // Type
        precondition(token(at: 1) == .identifier) // Name
        precondition(token(at: 2) == .equal)      // Equals
        
        let nameDescriptor = getCurrentTokenDescriptor().advanced(by: 1)
        let typeDescriptor = getCurrentTokenDescriptor()
        
        
        nodes.append(contentsOf: Node.constructVariableDeclaration(
            variableName: nameDescriptor,
            typeName: typeDescriptor)
        )
        
        tokens.removeFirst()
        parseAssignment()
    }
    
    private func parseAssignment() {
        precondition(tokens.first == .identifier)
        precondition(tokens.count >= 3)
        precondition(token(at: 1) == .equal)
        nodes.append(.assignment)
        nodes.append(.identifier(getCurrentTokenDescriptor()))
        tokens.removeFirst(2)

        parseExpression()
        precondition(tokens.first == .semicolon, "A statement in C must end with a semicolon ';'\n")
        tokens.removeFirst()
    }
    
    private func parseExpression() {
        parseSum()
    }
    
    private func parseSum() {
        let beginning = nodes.count
        parseProduct()
        while let first = tokens.first, [.plus, .minus].contains(first) {
            tokens.removeFirst()
            parseProduct()
            
            if first == .plus {
                nodes.insert(.addExpression, at: beginning)
            } else {
                nodes.insert(.subExpression, at: beginning)
            }
        }
    }
    
    private func parseProduct() {
        let beginning = nodes.count
        parseFactor()
        while let first = tokens.first, [.times, .div].contains(first) {
            tokens.removeFirst()
            parseFactor()
            
            if first == .times {
                nodes.insert(.timesExpression, at: beginning)
            } else {
                nodes.insert(.divExpression, at: beginning)
            }
        }
    }
    
    private func parseFactor() {
        guard let firstToken = tokens.first else {
            preconditionFailure("When parsing a factor, there should always be something present. As this is in the middle of an expression.")
        }
        switch firstToken {
            case .number:
                nodes.append(.number(getCurrentTokenDescriptor()))
                tokens.removeFirst()
            case .identifier:
                nodes.append(.identifier(getCurrentTokenDescriptor()))
                tokens.removeFirst()
            case .lparen:
                tokens.removeFirst()
                parseExpression()
                precondition(tokens.first == .rparen, "Expected a closing parenthesis.")
                tokens.removeFirst()
            default:
                preconditionFailure("Incorrect token: \(firstToken)")
        }
    }
}
