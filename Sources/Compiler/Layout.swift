//
//  Layout.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 04/03/2025.
//
import Foundation

actor TypesBroker {
    static let shared = TypesBroker(
        sizes: [
            "int": 4,
            "float": 4,
            "double": 8,
            "char": 1,
        ]
    )
    
    
    private var sizes: [Substring: Int]
    private var waitingTasks: [Substring: [CheckedContinuation<Int, Never>]] = [:]

    private init(sizes: [Substring : Int]) {
        self.sizes = sizes
    }
}

extension TypesBroker {
    public func publish(layout: Layout.UserType) async {
        guard sizes[layout.typeName] == nil else {
            print("Tried to publish \(layout.typeName) multiple times...")
            return
        }
        
        var totalSize = 0
        
        for field in layout.fields {
            let size = await getSize(for: field.type)
            totalSize += size
        }
        
        print("`\(layout.typeName)`s size has been resolved to \(totalSize)...")
        sizes[layout.typeName] = totalSize
        notifyWaitingTasks(for: layout.typeName, size: totalSize)
    }
    
    private func notifyWaitingTasks(for typeName: Substring, size: Int) {
        if let continuations = waitingTasks.removeValue(forKey: typeName) {
            for continuation in continuations {
                continuation.resume(returning: size) // This will make the getSize(for:) methods return the given size.
            }
        }
    }
    
    public func getSize(for typeName: Substring) async -> Int {
        if let size = sizes[typeName] {
            return size
        }
        print("Waiting for `\(typeName)`s size to be published...")
        return await withCheckedContinuation { continuation in
            waitingTasks[typeName, default: []].append(continuation)
        }
    }
    
    public func getOffset(
        for field: Substring,
        given type: Layout.UserType
    ) async -> Int {
        guard let fieldIndex = type.fields.firstIndex(where: { $0.name == field }) else {
            preconditionFailure("\(field) was not found in the type \(type.typeName)")
        }
        var offset = 0
        
        for field in type.fields[..<fieldIndex] {
            offset += await getSize(for: field.type)
        }
        
        return offset
    }
}


class Layout {
    struct Field {
        let name: Substring
        let type: Substring
    }
    
    struct UserType {
        let typeName: Substring
        let fields: [Field]
    }
    
    struct ScopeLayout {
        let variables: [Field]
    }
    
    struct FunctionParameterLayout {
        let parameters: [Field]
    }
    
    var nodes: [Node].SubSequence
    var userTypes: [UserType] = []
    
    var scopes = [Node.Descriptor: ScopeLayout]()
    
    let stringResolver: StringResolver
    
    init(
        nodes: [Node].SubSequence,
        stringResolver: StringResolver
    ) {
        self.nodes = nodes
        self.stringResolver = stringResolver
    }
}

extension Layout.Field {
    func getSize() async -> Int {
        return await TypesBroker.shared.getSize(for: self.type)
    }
}

extension Layout.UserType {
    func getSize() async -> Int {
        return await TypesBroker.shared.getSize(for: self.typeName)
    }
    
    func getOffset(for field: Substring) async -> Int {
        return await TypesBroker.shared.getOffset(for: field, given: self)
    }
    
    func publishLayout() {
        Task {
            await TypesBroker.shared.publish(layout: self)
        }
    }
}

extension Layout {
    private func computeStructLayout(andPublish shouldPublishFoundTypes: Bool = true) {
        nodes.removeFirst()
        guard case .identifier(let structNameDescriptor) = nodes.first else {
            preconditionFailure()
        }
        
        var fields = [Layout.Field]()
        nodes.removeFirst()
        while nodes.first == .structMemberDeclaration {
            nodes.removeFirst()
            guard case .identifier(let nameDescriptor) = nodes.first else {
                preconditionFailure()
            }
            nodes.removeFirst()
            guard case .identifier(let typeDescriptor) = nodes.first else {
                preconditionFailure()
            }
            nodes.removeFirst()
            
            fields.append(.init(
                name: stringResolver.resolve(nameDescriptor),
                type: stringResolver.resolve(typeDescriptor)
            ))
        }
        let userType = UserType(
            typeName: stringResolver.resolve(structNameDescriptor),
            fields: fields
        )
        if shouldPublishFoundTypes {
            userType.publishLayout()
        }
        userTypes.append(userType)
    }
    
    func computeScopeLayout() {
        nodes.removeFirst()
        var scopeVariables = [Layout.Field]()
        while nodes.isEmpty != false && nodes.first != .scopeEnd {
            if nodes.first == .scope {
                // TODO(William): Recurse here
            }
            if nodes.first != .variableDeclaration {
                nodes.removeFirst()
                continue
            }
            nodes.removeFirst()
            guard case .identifier(let nameDescriptor) = nodes.first else {
                preconditionFailure()
            }
            nodes.removeFirst()
            guard case .identifier(let typeDescriptor) = nodes.first else {
                preconditionFailure()
            }
            nodes.removeFirst()
            
            scopeVariables.append(.init(
                name: stringResolver.resolve(nameDescriptor),
                type: stringResolver.resolve(typeDescriptor)
            ))
        }
    }
    
    func computeLayouts(andPublish shouldPublishFoundTypes: Bool = true) {
        while nodes.isEmpty == false {
            switch nodes.first {
                case .structDeclaration:
                    computeStructLayout(andPublish: shouldPublishFoundTypes)
                case .scope:
                    computeScopeLayout()
                default:
                    nodes.removeFirst()
            }
        }
    }
}
