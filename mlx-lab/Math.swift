//
//  Math.swift
//  mlx-lab
//
//  Created by Ivan Milinkovic on 13. 10. 2026..
//

import Foundation

// Double

func cos(_ a1: [Double], _ a2: [Double]) -> Double {
    let d1 = len(a1)
    let d2 = len(a2)
    guard d1 != 0 && d2 != 0 else { return 0 }
    return dot(a1, a2) / (d1 * d2)
}

func dot(_ a1: [Double], _ a2: [Double]) -> Double {
    precondition(a1.count == a2.count)
    var sum = 0.0
    for i in 0..<a1.count {
        sum += a1[i] * a2[i]
    }
    return sum
}

func len(_ a: [Double]) -> Double {
    var sum = 0.0
    for i in 0..<a.count {
        sum += a[i] * a[i]
    }
    return sqrt(sum)
}

// Float

func cos(_ a1: [Float], _ a2: [Float]) -> Float {
    let d1 = len(a1)
    let d2 = len(a2)
    guard d1 != 0 && d2 != 0 else { return 0 }
    return dot(a1, a2) / (d1 * d2)
}

func dot(_ a1: [Float], _ a2: [Float]) -> Float {
    precondition(a1.count == a2.count)
    var sum: Float = 0.0
    for i in 0..<a1.count {
        sum += a1[i] * a2[i]
    }
    return sum
}

func len(_ a: [Float]) -> Float {
    var sum: Float = 0.0
    for i in 0..<a.count {
        sum += a[i] * a[i]
    }
    return sqrt(sum)
}
