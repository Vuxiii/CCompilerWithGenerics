//
//  LinearScanRegisterAllocation.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 12/03/2025.
//

extension [Liveness.Var: RegisterScan.Register] {
    func stringRepresentation() -> String {
        self.map { variable, register in "\(variable): \(register)"}.joined(separator: "\n")
    }
}

extension Liveness.Var {
    var debugDescription: String {
        switch self {
            case .temp(let version):
                "[T\(version)]"
            case let .variable(name, version):
                "\(name)\(version)"
        }
    }
}


class RegisterScan {
    typealias Register = VirtualMachine.Register.GeneralRegister
    struct Assignment: Hashable {
        let range: Range<Liveness.SSADescriptor>
        let variable: Liveness.Var
    }
    
    let liveness: [Assignment]
    let interferenceGraph: [Liveness.Var: InterferenceGraph.Node]
    
    var active = [(
        reg: Register,
        range: Range<Liveness.SSADescriptor>,
        variable: Liveness.Var
    )]()
    
    var freeRegisters = Register.allCases
    
    var registerAssignments: [Liveness.Var: Register]
    
    var currentStackSlot = 0
    
    var stack: [Assignment: Int] = .init()
    
    public init(
        liveness: Dictionary<Liveness.Var, Range<Liveness.SSADescriptor>>,
        interferenceGraph: [Liveness.Var : InterferenceGraph.Node]
    ) {
        self.liveness = liveness.sorted(by: { (left, right) in
            left.value.lowerBound < right.value.lowerBound
        }).map { Assignment.init(range: $0.value, variable: $0.key) }
        
        self.interferenceGraph = interferenceGraph
        self.registerAssignments = .init(minimumCapacity: interferenceGraph.keys.count)
    }
    
    var registerCount: Int {
        VirtualMachine.Register.GeneralRegister.allCases.count
    }
    
    public func compute() {
        for assignment in liveness {
            expireOldIntervals(upToBeginningOf: assignment.range)
            if active.count == registerCount {
                spillAt(interval: assignment)
            } else {
                let freeRegister = freeRegisters.removeLast()
                registerAssignments[assignment.variable] = freeRegister
                add(
                    register: freeRegister,
                    toActiveRange: assignment.range,
                    using: assignment.variable
                )
            }
        }
    }
    
    func spillAt(interval assignment: Assignment) {
        let range = assignment.range
        guard let spill = active.last else {
            return
        }
        
        if spill.range.upperBound > range.upperBound {
            
            registerAssignments.removeValue(forKey: assignment.variable)
            stack[assignment] = currentStackSlot
            
            
            active.removeLast()
            add(register: spill.reg, toActiveRange: range, using: assignment.variable)
        } else {
            stack[assignment] = currentStackSlot
        }
        currentStackSlot += 1
    }
    
    func expireOldIntervals(upToBeginningOf range: Range<Liveness.SSADescriptor>) {
        while active.count > 0 {
            guard let upperBound = active.first?.range.upperBound else {
                return
            }
            if upperBound >= range.lowerBound {
                return
            }
            let releasedRegister = active.removeFirst().reg
            freeRegisters.append(releasedRegister)
        }
    }
    
    func add(
        register: Register, toActiveRange
        range: Range<Liveness.SSADescriptor>,
        using variable: Liveness.Var
    ) {
        var index = active.startIndex
        while index < active.endIndex && active[index].range.upperBound < range.upperBound {
            index = active.index(after: index)
        }
        active.insert((reg: register, range: range, variable: variable ), at: index)
    }
}

//} else if !didInsert {
//    index = active.index(after: index)
//    active.swapAt(index, active.index(after: index))
//    didInsert = true
//} else if index < active.endIndex {
//    index = active.index(after: index)
//    active.swapAt(index, active.index(after: index))
//}
