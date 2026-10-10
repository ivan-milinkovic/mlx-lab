//
//  Wrapper.swift
//  mlx-lab
//
//  Created by Ivan Milinkovic on 10. 10. 2026..
//

nonisolated class SendableWrapper<T>: @unchecked Sendable {
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
}
