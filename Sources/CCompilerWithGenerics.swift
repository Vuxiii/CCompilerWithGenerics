// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation

@main
struct CCompilerWithGenerics: AsyncParsableCommand {
    @Argument(
        help: "The filepath of the file to compile.",
        transform: URL.init(fileURLWithPath:)
    )
    var filePath: URL
    
    @Option(name: [.short, .long], help: "The destination for the output")
    var output: String?
    
    mutating func run() async throws {
        print("Running Lexer on file \(filePath.lastPathComponent)")
        
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
a = 2 + 3 * (4 - 1);
"""
//        let simpleSSATest = """
//a = 2 + 69 * 42;
//"""
        let simpleSSATest = """
a = 2 + 3 * (4 - 1);
"""
        
        let scopeInput = """
{
    int a;
    int b;
    int c;

    a = 42;
    b = 69;
    c = 5;
}
"""
        
        let lexer = Lexer(source: contents[...])
        lexer.lex()
        for index in lexer.tokens.indices {
            print("\(lexer.tokens[index]): '\(lexer.getSubstring(representedBy: index))'")
        }
        
        print("\nRunning Parser...")
        let parser = Parser(tokens: lexer.tokens[...])
        parser.parse()
        
        for node in parser.nodes {
            switch node {
                case .identifier(let descriptor), .number(let descriptor):
                    print("\(node)->\(lexer.getSubstring(representedBy: descriptor))")
                default:
                    print("\(node)")
            }
        }
        
        let layout = Layout(
            nodes: parser.nodes[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        layout.computeLayouts(andPublish: true)
        
        for type in layout.userTypes {
            print("Size for \(type.typeName): \(await type.getSize())")
            for field in type.fields {
                print("\t\(field.name): Offset->\(await type.getOffset(for: field.name)) Size->\(await field.getSize())")
            }
        }
        
        let stripped = stripDeclarations(from: parser.nodes[...])
        
        print("\nStripped: \(stripped)\n")
        
        print("\nLowering...")
        let lower = Lowering(
            nodes: parser.nodes[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        let ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        let instructions = lowerSSA(
            ssas: ssas[...],
            scopes: [:]
        )
        
        let machine = VirtualMachine(instructions: instructions)
//        machine.run()
    }
    
    
}

func lowerSSA(
    ssas: [Lowering.SSA].SubSequence,
    scopes: [Range<Node.Descriptor>: Layout.ScopeLayout]
) -> [VirtualMachine.Instruction] {
    
    for ssa in ssas {
        switch ssa.name {
            case let .temp(version):
                break
            case let .variable(descriptor, version):
                break
        }
    }
    
    return []
}

// TODO(William): Consider if we want to do this. Or maybe just do a guard let so we don't make a copy of the entire AST.
func stripDeclarations(
    from nodes: [Node].SubSequence
) -> [Node.Stripped] {
    return nodes.compactMap(Node.Stripped.construct(from:))
}

extension Lowering.SSA {
    func stringRepresentation(resolver stringResolver: StringResolver) -> String {
        let name = switch self.name {
            case .temp(let version):
                "[T\(version)]"
            case let .variable(descriptor, version):
                "\(stringResolver.resolve(descriptor))\(version)"
        }
        
        let lhs: Substring = switch self.left {
            case .ssaVar(let variable):
                switch variable {
                    case .temp(let version):
                        "[T\(version)]"
                    case let .variable(descriptor, version):
                        "\(stringResolver.resolve(descriptor))\(version)"
                }
            case .number(let descriptor):
                stringResolver.resolve(descriptor)
        }
        
        guard let (op, right) = self.rhs else {
            return "\(name) = \(lhs)"
        }
        
        let rhs: Substring = switch right {
            case .ssaVar(let variable):
                switch variable {
                    case .temp(let version):
                        "[T\(version)]"
                    case let .variable(descriptor, version):
                        "\(stringResolver.resolve(descriptor))\(version)"
                }
            case .number(let descriptor):
                stringResolver.resolve(descriptor)
        }
        
        return "\(name) = \(lhs) \(op) \(rhs)"
    }
}

enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

extension Either {
    var isLeft: Bool {
        switch self {
            case .left: return true
            case .right: return false
        }
    }
    
    var isRight: Bool {
        return !isLeft
    }
    
    func mapLeft<T>(
        _ transform: (Left) throws -> T
    ) rethrows -> Either<T, Right> {
        switch self {
            case .left(let left): return .left(try transform(left))
            case .right(let right): return .right(right)
        }
    }
    
    func mapRight<T>(
        _ transform: (Right) throws -> T
    ) rethrows -> Either<Left, T> {
        switch self {
            case .left(let left): return .left(left)
            case .right(let right): return .right(try transform(right))
        }
    }
}

class Lowering {
    var nodes: [Node].SubSequence
    var blocks: [SSABlock] = []
    
    var variables = [Substring: Int]()
    var latestTempVersion: VersionNumber = 0
    
    let stringResolver: StringResolver
    
    public init(
        nodes: [Node].SubSequence,
        stringResolver: StringResolver
    ) {
        self.nodes = nodes
        self.stringResolver = stringResolver
    }
    
    struct SSABlock {
        var predecessors: [SSABlock]
    }

    typealias VersionNumber = Int
    
    enum SSAVar {
        case temp(VersionNumber)
        case variable(Node.Descriptor, VersionNumber)
    }
    
    enum SSAValue {
        case ssaVar(SSAVar)
        case number(Node.Descriptor)
    }
    
    enum Operator {
        case plus, minus, times, div
    }
    
    struct SSA {
        var name: SSAVar
        let left: SSAValue
        let rhs: (op: Operator, right: SSAValue)?
        
        public init(
            name: SSAVar,
            left: SSAValue
        ) {
            self.name = name
            self.left = left
            self.rhs = nil
        }
        
        public init(
            name: SSAVar,
            left: SSAValue,
            right: SSAValue,
            op: Operator
        ) {
            self.name = name
            self.left = left
            self.rhs = (op, right)
        }
    }

    func nextVersion(for descriptor: Node.Descriptor) -> Int {
        let variable = stringResolver.resolve(descriptor)
//        defer {
            variables[variable, default: 0] += 1
//        }
        return variables[variable, default: 0]
    }

    func nextTempVersion() -> Int {
        latestTempVersion += 1
        return latestTempVersion
    }
    
    func latestVersionNumber(for variable: Node.Descriptor) -> VersionNumber {
        let name = stringResolver.resolve(variable)
        return variables[name, default: 0]
    }
    
    func extractExpressions(nodes: inout [Node].SubSequence) -> (SSAValue, [Lowering.SSA]) {
        switch lowerExpression(nodes: &nodes) {
            case .left(let subExpressions):
                return (.ssaVar(.temp(latestTempVersion)), subExpressions)
            case .right(let value):
                return (value, [])
        }
    }
    
    func lowerExpression(nodes: inout [Node].SubSequence) -> Either<[SSA], SSAValue> {
        guard let node = nodes.first else {
            return .left([])
        }
        
        switch node {
            case .identifier(let descriptor):
                nodes.removeFirst()
                return .right(.ssaVar(.variable(descriptor, latestVersionNumber(for: descriptor))))
            case .number(let descriptor):
                nodes.removeFirst()
                return .right(.number(descriptor))
            case .addExpression, .subExpression, .divExpression, .timesExpression:
                nodes.removeFirst()
                var output = [SSA]()
                
                var (lhs, lhsSubExpressions) = extractExpressions(nodes: &nodes)
                
                if [.addExpression, .subExpression,
                     .divExpression, .timesExpression].contains(nodes.first) && lhsSubExpressions.isEmpty {
                    let singleSSA = SSA(
                        name: .temp(nextTempVersion()),
                        left: lhs
                    )
                    lhs = .ssaVar(.temp(latestTempVersion))
                    output.append(singleSSA)
                }
                
                let (rhs, rhsSubExpressions) = extractExpressions(nodes: &nodes)
                
                output.append(contentsOf: lhsSubExpressions)
                output.append(contentsOf: rhsSubExpressions)
                
                let op: Operator = if case .addExpression = node { Operator.plus }
                              else if case .subExpression = node { .minus }
                              else if case .divExpression = node { .div }
                              else { .times }

                
                let ssa = SSA(
                    name: .temp(nextTempVersion()),
                    left: lhs,
                    right: rhs,
                    op: op
                )
                
                output.append(ssa)
                
                return .left(output)
            default:
                preconditionFailure("Unrecognized node \(node) during lowering of expression")
        }
    }
    
    
    // TODO(William): Delete below
//    func lowerExpression(nodes: inout [Node].SubSequence) -> [SSA] {
//        guard let node = nodes.first else {
//            return []
//        }
//        
//        switch node {
//            case .addExpression, .subExpression, .divExpression, .timesExpression:
//                nodes.removeFirst()
//                var output = [SSA]()
//                                
//                var lhs: SSAValue
//                var leftExpressions = [SSA]()
//                if case let .number(descriptor) = nodes.first {
//                    lhs = .number(descriptor)
//                    nodes.removeFirst()
//                } else if case let .identifier(descriptor) = node {
//                    lhs = .ssaVar(.variable(descriptor, latestVersionNumber(for: descriptor)))
//                    nodes.removeFirst()
//                } else {
//                    leftExpressions = lowerExpression(nodes: &nodes)
//                    lhs = .ssaVar(.temp(latestTempVersion))
//                }
//                
//                let rhs: SSAValue
//                var rightExpressions = [SSA]()
//                if case let .number(descriptor) = nodes.first {
//                    rhs = .number(descriptor)
//                    nodes.removeFirst()
//                } else if case let .identifier(descriptor) = node {
//                    rhs = .ssaVar(.variable(descriptor, latestVersionNumber(for: descriptor)))
//                    nodes.removeFirst()
//                } else {
//                    if leftExpressions.isEmpty {
//                        // The lhs is a single value and rhs is compound expression. For this reason, we need to compute lhs first and store it in a temp variable. Then we can compute rhs expression. This also means that we need to update lhs to point to our tmp variable.
//                        let singleSSA = SSA(
//                            name: .temp(nextTempVersion()),
//                            left: lhs
//                        )
//                        lhs = .ssaVar(.temp(latestTempVersion))
//                        output.append(singleSSA)
//                    }
//                    rightExpressions = lowerExpression(nodes: &nodes)
//                    rhs = .ssaVar(.temp(latestTempVersion))
//                }
//                
//                output.append(contentsOf: leftExpressions)
//                output.append(contentsOf: rightExpressions)
//                
//                let op: Operator = if case .addExpression = node { Operator.plus }
//                              else if case .subExpression = node { .minus }
//                              else if case .divExpression = node { .div }
//                              else { .times }
//
//                
//                let ssa = SSA(
//                    name: .temp(nextTempVersion()),
//                    left: lhs,
//                    right: rhs,
//                    op: op
//                )
//                
//                output.append(ssa)
//                
//                return output
//            default:
//                switch node {
//                    case .identifier(let desc), .number(let desc):
//                        preconditionFailure("Unrecognized node \(node)->[\(stringResolver.resolve( desc))] during lowering of expression")
//                    default:
//                        preconditionFailure("Unrecognized node \(node) during lowering of expression")
//                }
//                
//        }
//    }

    func lowerAssignmentOrExpressionToSSA() -> [SSA] {
        while let node = nodes.first {
            switch node {
                case .assignment:
                    nodes.removeFirst()
                    
                    guard case let .identifier(lhs) = nodes.removeFirst() else {
                        preconditionFailure("Left hand side of an assignment should be an identifier (For now).")
                    }
                    
                    switch lowerExpression(nodes: &nodes) {
                        case .left(var rhs):
                            let updated = SSAVar.variable(lhs, nextVersion(for: lhs))
                            rhs[rhs.count-1].name = updated
                            
                            // We are consuming a temp here. We want to give the temp version number back to reuse it.
                            latestTempVersion -= 1
                            return rhs
                        case .right(let rhs):
                            return [
                                .init(
                                    name: .variable(lhs, nextVersion(for: lhs)),
                                    left: rhs
                                )
                            ]
                    }
                    
//                    var rhs = lowerExpression(nodes: &nodes)
//                    let updated = SSAVar.variable(lhs, nextVersion(for: lhs))
//                    rhs[rhs.count-1].name = updated
//                    latestTempVersion -= 1
//                    return rhs
                case .addExpression, .subExpression, .divExpression, .timesExpression:
                    let ssas = lowerExpression(nodes: &nodes)
                    
//                    return ssas
                default:
                    nodes.removeFirst()
            }
        }
        return []
    }

}


enum State {
    enum Assignment {
        case start
        case variable(Node.Descriptor)
        case expression(Node.Descriptor)
    }
    case readyForStatement
    case assignment(Assignment)

}

extension State {
    func consume(_ node: Node) -> Self? {
        switch self {
            case .readyForStatement:
                switch node {
                    case .assignment:
                        return .assignment(.start)
                    default:
                        print("Not implemented yet: \(node)")
                        return nil
                }
            case .assignment(let state):
                switch state {
                    case .start:
                        break
                    case .variable:
                        break
                    case .expression:
                        break
                }
                return nil
        }
    }
}

//
//
//func lower(
//    stringResolver: StringResolver,
//    nodes: [Node].SubSequence
//) -> [VirtualMachine.Instruction] {
//    var currentState = State.readyForStatement
//    
//    for i in nodes.indices {
//        let node = nodes[i]
//        switch node {
//            case .assignment:
//                guard let nextState = currentState.consume(node) else {
//                    preconditionFailure()
//                }
//                currentState = nextState
//            case .variableDeclaration:
//                // Ignore
//            case .structDeclaration:
//                // Ignore
//            case .structMemberDeclaration:
//                // Ignore
//            case .addExpression:
////                <#code#>
//            case .subExpression:
////                <#code#>
//            case .divExpression:
////                <#code#>
//            case .timesExpression:
////                <#code#>
//            case .scope:
////                <#code#>
//            case .scopeEnd:
////                <#code#>
//            case .number(_):
////                <#code#>
//            case .identifier(_):
////                <#code#>
//        }
//    }
//    
//    
//    return []
//}
