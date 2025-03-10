//
//  Either.swift
//  CCompilerWithGenerics
//
//  Created by William Juhl on 10/03/2025.
//

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
