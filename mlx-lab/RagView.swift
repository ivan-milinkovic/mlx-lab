//
//  RagView.swift
//  mlx-lab
//
//  Created by Ivan Milinkovic on 12. 10. 2026..
//

import SwiftUI

struct RagView: View {
    
    @State private var resourcesInput: String = ""
    @State private var searchInput: String = ""
    @State private var output: String = ""
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        VStack {
            TextEditor(text: $resourcesInput)
                .frame(maxHeight: 400)
                .onSubmit {
                    submitResources()
                }
            Button("Submit") {
                submitResources()
            }
            
            TextField("Prompt", text: $searchInput)
                .onSubmit {
                    search()
                }
            Button("Search") {
                search()
            }
            Text(output)
        }
        .padding()
    }
    
    private func submitResources() {
        Task {
            await appModel.takeRagResources(resourcesInput)
        }
    }
    
    private func search() {
        Task {
            let re = await appModel.findRagEntry(searchInput)
            output = re?.content ?? "-"
        }
    }
}

#Preview {
    RagView()
}
