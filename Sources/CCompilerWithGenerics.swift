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
a = 2 + 3 * (4 - 1); hej med dig 42.69
"""
        let simpleSSATest = """
a = 2 + 69 * 42;
"""
//        let simpleSSATest = """
//a = 1 + 2 + 3;
//"""
        
        let lexer = Lexer(source: simpleSSATest[...])
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
            nodes: stripped[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        let ssas = lower.convertToSSA()
        
        let machine = VirtualMachine(instructions: [
            .add(to: .register(.r1), from: .immediate(.integer(2))),
            .add(to: .register(.r1), from: .immediate(.integer(2))),
            .add(to: .register(.r1), from: .immediate(.integer(2))),
            .add(to: .register(.r1), from: .immediate(.integer(2))),
        ])
//        machine.run()
    }
    
    
}

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
        
        guard let op = self.op, let right = self.right else {
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

class Lowering {
    var nodes: [Node.Stripped].SubSequence
    var blocks: [SSABlock] = []
    
    var variables = [Substring: Int]()
    var latestTempVersion: VersionNumber = 0
    
    let stringResolver: StringResolver
    
    public init(
        nodes: [Node.Stripped].SubSequence,
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
        let right: SSAValue? // TODO(William): We could combine this and op in a optional tuple
        let op: Operator?
    }

    func nextVersion(for descriptor: Node.Descriptor) -> Int { // TODO(William): default name should be mangled or something. Maybe switch to using enums instead.
        let variable = stringResolver.resolve(descriptor)
        defer {
            variables[variable, default: 0] += 1
        }
        return variables[variable, default: 0]
    }

    func latestVersionNumber(for variable: Node.Descriptor) -> VersionNumber {
        let name = stringResolver.resolve(variable)
        return variables[name, default: 0]
    }
    
    
    
    enum Whatever {
        case single(to: Substring, value: Substring)
        case assignment(to: Substring, lhs: Substring, rhs: Substring)
    }
    
    func lowerExpression(nodes: inout [Node.Stripped].SubSequence) -> [SSA] {
        guard let node = nodes.first else {
            return []
        }
//        assignment
//        identifier(30)->a
//        addExpression
//        number(32)->2
//        timesExpression
//        number(34)->3
//        subExpression
//        number(37)->4
//        number(39)->1
        
        switch node {
            case .addExpression, .subExpression, .divExpression, .timesExpression:
                nodes.removeFirst()
                var output = [SSA]()
                
                var lhs: SSAValue
                if case let .number(descriptor) = nodes.first {
                    lhs = .number(descriptor)
                    nodes.removeFirst()
                } else if case let .identifier(descriptor) = node {
                    lhs = .ssaVar(.variable(descriptor, latestVersionNumber(for: descriptor)))
                    nodes.removeFirst()
                } else {
                    output.append(contentsOf: lowerExpression(nodes: &nodes))
                    lhs = .ssaVar(.temp(latestTempVersion))
                }
                
                let rhs: SSAValue
                if case let .number(descriptor) = nodes.first {
                    rhs = .number(descriptor)
                    nodes.removeFirst()
                } else if case let .identifier(descriptor) = node {
                    rhs = .ssaVar(.variable(descriptor, latestVersionNumber(for: descriptor)))
                    nodes.removeFirst()
                } else {
                    output.append(contentsOf: lowerExpression(nodes: &nodes))
                    rhs = .ssaVar(.temp(latestTempVersion))
                }
                
                let op: Operator = if case .addExpression = node { Operator.plus }
                              else if case .subExpression = node { .minus }
                              else if case .divExpression = node { .div }
                              else { .times }

                latestTempVersion += 1
                let ssa = SSA(
                    name: .temp(latestTempVersion),
                    left: lhs,
                    right: rhs,
                    op: op
                )
                
                output.append(ssa)
                
                return output
            default:
                preconditionFailure("Unrecognized node \(node) during lowering of expression")
        }
        
        return []
    }

    func convertToSSA() -> [SSABlock] {
        while let node = nodes.first {
            switch node {
                case .assignment:
                    nodes.removeFirst()
                    
                    guard case let .identifier(lhs) = nodes.removeFirst() else {
                        preconditionFailure("Left hand side of an assignment should be an identifier (For now).")
                    }
                    
                    var rhs = lowerExpression(nodes: &nodes)
                    let updated = SSAVar.variable(lhs, nextVersion(for: lhs))
                    rhs[rhs.count-1].name = updated
                    
                    let strings = rhs.map { $0.stringRepresentation(resolver: stringResolver) }
                        .joined(separator: "\n")
                    
                    print(strings)
                case .addExpression, .subExpression, .divExpression, .timesExpression:
                    let ssas = lowerExpression(nodes: &nodes)
                    
                    let tempVar = "tempVariable"
                    
                case .scope:
                    break
                case .scopeEnd:
                    break
                case .number(let descriptor):
                    break
                case .identifier(let descriptor):
                    break
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
