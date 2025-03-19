//
//  LinearScanRegisterAllocation.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 12/03/2025.
//

extension [Liveness.Var: RegisterAllocation.LinearScan.Register] {
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

class RegisterAllocation {
    class LinearScan {
        typealias Register = VirtualMachine.Register.GeneralRegister
        struct Assignment: Hashable {
            let range: Range<Liveness.SSADescriptor>
            let variable: Liveness.Var
        }
        
        let liveness: [Assignment]
        
        var active = [(
            reg: Register,
            range: Range<Liveness.SSADescriptor>,
            variable: Liveness.Var
        )]()
        
        var freeRegisters: [Register]
        let registerCount: Int
        
        var registerAssignments: [Liveness.Var: Register]
        
        var currentStackSlot = 0
        
        var stack: [Liveness.Var: Int] = .init()
        
        public init(
            liveness: Dictionary<Liveness.Var, Range<Liveness.SSADescriptor>>,
            availableRegisters: [Register]
        ) {
            self.liveness = liveness.sorted(by: { (left, right) in
                left.value.lowerBound < right.value.lowerBound
            }).map { Assignment.init(range: $0.value, variable: $0.key) }
            
            self.registerAssignments = .init()
            self.freeRegisters = availableRegisters
            self.registerCount = availableRegisters.count
        }
        
        enum AllocationSpot: Equatable {
            case register(Register)
            case spilled(Int)
        }
        
        public func getAssignment(for variable: Liveness.Var) -> AllocationSpot? {
            if let reg = registerAssignments[variable] {
                .register(reg)
            } else if let stackSpot = stack[variable] {
                .spilled(stackSpot)
            } else {
                nil
            }
        }
        
        public func compute() {
            var step = 0
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
                step += 1
            }
        }
        
        func spillAt(interval assignment: Assignment) {
            guard let spill = active.last else {
                return
            }
            
            if spill.range.upperBound > assignment.range.upperBound {
                guard let freedRegister = registerAssignments.removeValue(forKey: spill.variable) else {
                    fatalError("The assignment was not assigned a register")
                }
                
                registerAssignments[assignment.variable] = freedRegister
                
                stack[spill.variable] = currentStackSlot
                
                active.removeLast()
                add(register: freedRegister, toActiveRange: assignment.range, using: assignment.variable)
            } else {
                stack[assignment.variable] = currentStackSlot
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
}
//} else if !didInsert {
//    index = active.index(after: index)
//    active.swapAt(index, active.index(after: index))
//    didInsert = true
//} else if index < active.endIndex {
//    index = active.index(after: index)
//    active.swapAt(index, active.index(after: index))
//}
