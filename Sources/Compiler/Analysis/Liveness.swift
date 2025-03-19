//
//  Liveness.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 10/03/2025.
//

extension Liveness.Var {
    public init(
        _ value: Lowering.SSAVar,
        using stringResolver: StringResolver
    ) {
        self = switch value {
            case let .temp(versionNumber):
                .temp(versionNumber)
            case let .variable(descriptor, versionNumber):
                .variable(stringResolver.resolve(descriptor), versionNumber)
        }
    }
}

class Liveness {
    typealias SSADescriptor = [Lowering.SSAInstruction].SubSequence.Index
    
    enum Var: Hashable {
        case temp(Lowering.VersionNumber)
        case variable(Substring, Lowering.VersionNumber)
    }
    
    var livenessRanges: Dictionary<Var, Range<SSADescriptor>>
    
    var ssaInstructions: [Lowering.SSAInstruction].SubSequence
    
    let stringResolver: StringResolver
    
    func printLivenessRanges() {
        let ranges = livenessRanges.sorted(by: { $0.value.lowerBound < $1.value.lowerBound })
        
        var output = ""
        
        for (variable, range) in ranges {
            output += "\(variable): "
            let spacing = String.init(repeating: "  ", count: range.lowerBound)
            let dashes = String.init(repeating: "--", count: range.lowerBound.distance(to: range.upperBound-1))
            output += "\(spacing)+-\(dashes)+\n"
        }
        let max = ranges.max(by: { $0.value.upperBound < $1.value.upperBound })!
        let spacing = String.init(repeating: " ", count: "\(max.key): ".count)
        output += spacing
        for index in 0...max.value.upperBound {
            output += "\(index) "
        }
        print(output)
    }
    
    public init(
        instructions: [Lowering.SSAInstruction].SubSequence,
        stringResolver: StringResolver
    ) {
        self.livenessRanges = .init()
        self.ssaInstructions = instructions
        self.stringResolver = stringResolver
    }
    
    func updateRange(for variable: Lowering.SSAVar) {
        let variable = Var.init(variable, using: stringResolver)
        var currentRange = livenessRanges[variable, default: .init(
            uncheckedBounds: (
                ssaInstructions.startIndex,
                ssaInstructions.startIndex.advanced(by: 1)
            )
        )]
        
        if currentRange.upperBound < ssaInstructions.startIndex {
            currentRange = Range(
                uncheckedBounds: (
                    currentRange.lowerBound,
                    ssaInstructions.startIndex//.advanced(by: 1)
                )
            )
        }
        livenessRanges[variable] = currentRange
    }
    
    func compute() {
        while let instruction = ssaInstructions.first {
            updateRange(for: instruction.name)
            if case let .ssaVar(variable) = instruction.left {
                updateRange(for: variable)
            }
            if let (_, right) = instruction.rhs, case let .ssaVar(variable) = right {
                updateRange(for: variable)
            }
            ssaInstructions.removeFirst()
        }
    }
}
