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
            nodes: parser.nodes[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        let ssas = lower.lowerAssignmentOrExpressionToSSA()
        
        print("Computing liveness")
        let livenessAnalysis = Liveness(
            instructions: ssas[...],
            stringResolver: .init(resolve: lexer.getSubstring(representedBy:))
        )
        
        livenessAnalysis.compute()
        
        for (variable, range) in livenessAnalysis.livenessRanges {
            print("\(variable) -> \(range)")
        }
        print(ssas.map { $0.stringRepresentation(resolver: .init(resolve: lexer.getSubstring(representedBy:)))}.joined(separator: "\n"))
        
        print("Computing Interference Graph")
        
        let interferenceGraph = InterferenceGraph(livenessRanges: livenessAnalysis.livenessRanges)
        
        interferenceGraph.compute()
        
        for (node, connectingNodes) in interferenceGraph.nodes {
            print("\(node):")
            for connected in connectingNodes.connects {
                print("\t\(connected.ssaVariable)")
            }
        }
        
        return
        
        
        let instructions = lowerSSA(
            ssas: ssas[...],
            scopes: [:]
        )
        
        let machine = VirtualMachine(instructions: instructions)
//        machine.run()
    }
}

func lowerSSA(
    ssas: [Lowering.SSAInstruction].SubSequence,
    scopes: [Range<Node.Descriptor>: Layout.ScopeLayout]
) -> [VirtualMachine.Instruction] {
    for ssa in ssas {
        switch ssa.name {
            case .temp(let versionNumber):
                break
            case let .variable(descriptor, versionNumber):
                break
        }
        
        switch ssa.left {
            case .ssaVar(let sSAVar):
                break
            case .number(let descriptor):
                break
        }
        
        if let (op, right) = ssa.rhs {
            switch right {
                case .ssaVar(let sSAVar):
                    break
                case .number(let descriptor):
                    break
            }
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

extension Lowering.SSAInstruction {
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
        let predecessors: [SSABlock]
        let instructions: [SSAInstruction]
    }

    typealias VersionNumber = Int
    
    enum SSAVar { // TODO(William): Probably move this into an IR scope instead.
        case temp(VersionNumber)
        case variable(Node.Descriptor, VersionNumber)
    }
    
    enum SSAValue {
        case ssaVar(SSAVar)
        case number(Node.Descriptor)
    }
    
    enum SSAOperator {
        case plus, minus, times, div
    }
    
    struct SSAInstruction {
        var name: SSAVar
        let left: SSAValue
        let rhs: (op: SSAOperator, right: SSAValue)?
        
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
            op: SSAOperator
        ) {
            self.name = name
            self.left = left
            self.rhs = (op, right)
        }
    }

    func nextVersion(for descriptor: Node.Descriptor) -> Int {
        let variable = stringResolver.resolve(descriptor)
        variables[variable, default: 0] += 1
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
    
    func extractExpressions(nodes: inout [Node].SubSequence) -> (SSAValue, [Lowering.SSAInstruction]) {
        switch lowerExpression(nodes: &nodes) {
            case .left(let subExpressions):
                return (.ssaVar(.temp(latestTempVersion)), subExpressions)
            case .right(let value):
                return (value, [])
        }
    }
    
    func lowerExpression(nodes: inout [Node].SubSequence) -> Either<[SSAInstruction], SSAValue> {
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
                var output = [SSAInstruction]()
                
                var (lhs, lhsSubExpressions) = extractExpressions(nodes: &nodes)
                
                if [.addExpression, .subExpression,
                     .divExpression, .timesExpression].contains(nodes.first) && lhsSubExpressions.isEmpty {
                    let singleSSA = SSAInstruction(
                        name: .temp(nextTempVersion()),
                        left: lhs
                    )
                    lhs = .ssaVar(.temp(latestTempVersion))
                    output.append(singleSSA)
                }
                
                let (rhs, rhsSubExpressions) = extractExpressions(nodes: &nodes)
                
                output.append(contentsOf: lhsSubExpressions)
                output.append(contentsOf: rhsSubExpressions)
                
                let op: SSAOperator = if case .addExpression = node { SSAOperator.plus }
                              else if case .subExpression = node { .minus }
                              else if case .divExpression = node { .div }
                              else { .times }

                
                let ssa = SSAInstruction(
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

    func lowerAssignmentOrExpressionToSSA() -> [SSAInstruction] {
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
                    
                case .addExpression, .subExpression, .divExpression, .timesExpression:
                    switch lowerExpression(nodes: &nodes) {
                        case .left(let expressions):
                            return expressions
                        case .right(let value):
                            return [
                                .init(
                                    name: .temp(nextTempVersion()),
                                    left: value
                                )
                            ]
                    }
                default:
                    nodes.removeFirst()
            }
        }
        return []
    }

}
