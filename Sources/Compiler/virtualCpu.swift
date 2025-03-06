//
//  virtualCpu.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 05/03/2025.
//

extension Dictionary {
    subscript(instruction: Key) -> Value
    where Key == VirtualMachine.Register, Value == Int {
        get { self[instruction, default: 0] }
        set { self[instruction, default: 0] = newValue }
    }
    
    
}

class VirtualMachine {
    var registers: [Register: Int] = [:]
    var stack = [Int]()
    var heap = [Int]()
    
    let instructions: [Instruction]
    
    public init(instructions: [Instruction]) {
        self.instructions = instructions
        registers.merge(Register.allCases.map { ($0, 0) }, uniquingKeysWith: { a, b in a })
    }
    
    
    func getValue(from: Instruction.Source) -> Int {
        switch from {
            case .immediate(let immediate):
                switch immediate {
                    case .address(let address):
                        stack[address]
                    case .integer(let value):
                        value
                }
            case .register(let reg):
                registers[reg, default: 0]
        }
    }
    
    
    public func run() {
        while registers[.instructionPointer] < instructions.count {
            let currentInstruction = instructions[registers[.instructionPointer]]
            
            switch currentInstruction {
                case .move(let to, let from):
                    let value = getValue(from: from)
                    switch to {
                        case .register(let reg):
                            registers[reg] = value
                        case .address(let address):
                            stack[address] = value
                    }
                case .add(let to, let from):
                    let value = getValue(from: from)
                    switch to {
                        case .register(let reg):
                            registers[reg, default: 0] += value
                        case .address(let address):
                            stack[address] += value
                    }
                    
            }
            
            registers[.instructionPointer] += 1
        }
    }
}

extension VirtualMachine {
    enum Register: CaseIterable, Hashable {
        static let allCases: [VirtualMachine.Register] = [
            .general(.r0),
            .general(.r1),
            .general(.r2),
            .general(.r3),
            .general(.r4),
            .general(.r5),
            .stackPointer,
            .instructionPointer,
            .flag(.zeroSet),
            .flag(.equal),
            .flag(.greaterThan),
            .flag(.lessThan),
        ]
        
        enum GeneralRegister: Int, CaseIterable {
            case r0 = 0
            case r1 = 1
            case r2 = 2
            case r3 = 3
            case r4 = 4
            case r5 = 5
        }
        
        enum Flag: Int, CaseIterable {
            case zeroSet = 0
            case equal = 1
            case greaterThan = 2
            case lessThan = 3
        }
        
        case general(GeneralRegister)
        case stackPointer
        case instructionPointer
        case flag(Flag)
    }
}

extension VirtualMachine {
    enum Instruction {
        case move(to: Target, from: Source)
        case add(to: Target, from: Source)
    }
}

extension VirtualMachine.Instruction {
    enum Target {
        case register(VirtualMachine.Register)
        case address(Int)
    }
    
    enum Immediate {
        case integer(Int)
        case address(Int)
    }
    
    enum Source {
        case immediate(Immediate)
        case register(VirtualMachine.Register)
        //        case address(Int)
    }
}

extension VirtualMachine.Register { // Convenience inits.
    static let r1 = VirtualMachine.Register.general(.r1)
    static let r2 = VirtualMachine.Register.general(.r2)
    static let r3 = VirtualMachine.Register.general(.r3)
    static let r4 = VirtualMachine.Register.general(.r4)
    static let r5 = VirtualMachine.Register.general(.r5)
    
    static let zeroFlag = VirtualMachine.Register.flag(.zeroSet)
    static let equalFlag = VirtualMachine.Register.flag(.equal)
    static let greaterThanFlag = VirtualMachine.Register.flag(.greaterThan)
    static let lessThanFlag = VirtualMachine.Register.flag(.lessThan)
}
