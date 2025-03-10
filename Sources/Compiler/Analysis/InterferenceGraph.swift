//
//  InterferenceGraph.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 10/03/2025.
//

class InterferenceGraph {
    class Node: Hashable {
        static func == (lhs: InterferenceGraph.Node, rhs: InterferenceGraph.Node) -> Bool {
            lhs.ssaVariable == rhs.ssaVariable
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(ssaVariable)
        }
        
        let ssaVariable: Liveness.Var
        var connects: Set<Node> = []
        
        public init(ssaVariable: Liveness.Var) {
            self.ssaVariable = ssaVariable
        }
    }
    
    var nodes = [Liveness.Var: Node]()
    
    let livenessRanges: Dictionary<Liveness.Var, Range<Liveness.SSADescriptor>>
    
    public init(
        livenessRanges: Dictionary<Liveness.Var, Range<Liveness.SSADescriptor>>
    ) {
        self.livenessRanges = livenessRanges
    }
    
    public func compute() {
        for (variable, _) in livenessRanges {
            if nodes[variable] == nil {
                nodes[variable] = Node(ssaVariable: variable)
            }
        }
        
        for (variable, range) in livenessRanges {
            let node = nodes[variable]!
            for (otherVariable, otherRange) in livenessRanges where variable != otherVariable {
                if range.overlaps(otherRange) {
                    let otherNode = nodes[otherVariable]!
                    node.connects.insert(otherNode)
                    otherNode.connects.insert(node)
                }
            }
        }
    }
}
