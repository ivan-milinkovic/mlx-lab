//
//  NLView.swift
//  mlx-lab
//
//  Created by Ivan Milinkovic on 12. 10. 2026..
//

import Foundation
import SwiftUI
import NaturalLanguage

struct NLView: View {
    @State private var input1 = "Hello"
    @State private var input2 = "Hello"
    @State private var outputSim = ""
    @State private var outputEuclDist = ""
    @State private var nl = NLEmbedding.sentenceEmbedding(for: .english)
    
    var body: some View {
        VStack {
            Group {
                TextField("Input 1", text: $input1)
                TextField("Input 2", text: $input2)
            }
            .frame(width: 400)
            .padding(.bottom, 8)
            
            LabeledContent("Cosine Similarity:", value: outputSim)
            LabeledContent("Eucledean Distance:", value: outputEuclDist)
        }
        .task(id: [input1, input2]) {
            do {
                try await Task.sleep(for: .milliseconds(300))
                calcCosSimilarity()
                calcEucledeanDistance()
            } catch {
                // cancellations on id change
            }
        }
    }
    
    func calcCosSimilarity() {
        guard let nl else { return }
        guard let v1 = nl.vector(for: input1) else {
            outputSim = "Could not embed input 1"
            return
        }
        guard let v2 = nl.vector(for: input2) else {
            outputSim = "Could not embed input 2"
            return
        }
        let sim = cos(v1, v2)
        outputSim = sim.formatted(.number.precision(.fractionLength(3)))
    }
    
    func calcEucledeanDistance() {
        guard let nl else { return }
        let dist = nl.distance(between: input1, and: input2, distanceType: .cosine)
        outputEuclDist = dist.formatted(.number.precision(.fractionLength(3)))
    }
}
