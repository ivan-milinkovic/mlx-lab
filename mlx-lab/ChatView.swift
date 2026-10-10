//
//  ChatView.swift
//  mlx-lab
//
//  Created by Ivan Milinkovic on 10. 10. 2026..
//

import SwiftUI
import MLXLMCommon

struct ChatView: View {
    
    @State private var vm = ChatViewModel()
    @State private var prompt = ""
    
    var body: some View {
        VStack {
            Text("Chat")
            Picker("Model", selection: $vm.model) {
                Text("None")
                    .tag(nil as CachedModel?)
                ForEach(vm.models) { model in
                    Text(model.name)
                        .tag(model)
                }
            }
            
            if vm.modelContainer == nil {
                Button("Load") {
                    Task { await vm.load() }
                }
            }
            
            TextField("Prompt", text: $prompt)
                .frame(maxWidth: 200)
                .onSubmit {
                    Task { await vm.sendPrompt(prompt) }
                }
            
            Text("Response")
            Text(vm.response)
        }
        .overlay {
            if vm.isLoading {
                ProgressView().progressViewStyle(.circular)
            }
        }
        .task {
            vm.setup()
        }
    }
}

import Observation
import HuggingFace
import MLXHuggingFace
import Tokenizers

@Observable @MainActor
final class ChatViewModel {
    
    var models: [CachedModel] = []
    var model: CachedModel?
    var response: String = ""
    var isLoading = false
    
    @ObservationIgnored var modelContainer: ModelContainer?
    @ObservationIgnored var chatSession: SendableWrapper<ChatSession>?
    
    @ObservationIgnored var promptTask: Task<Void, Never>?
    
    func setup() {
        models = Common.loadCachedModels()
        model = models.first
    }
    
    func load() async {
        guard let model else { return }
        isLoading = true; defer { isLoading = false }
        let config = ModelConfiguration(id: model.name)
        do {
            let container = try await #huggingFaceLoadModelContainer(configuration: config)
            let session = ChatSession(container)
            
            modelContainer = container
            chatSession = SendableWrapper(session)
        } catch {
            print(error)
        }
    }
    
    func sendPrompt(_ promptStr: String) async {
        if let promptTask {
            await promptTask.value
        }
        promptTask = Task {
            await prompt(promptStr)
        }
    }
    
    func prompt(_ promptStr: String) async {
        isLoading = true; defer { isLoading = false }
        guard let chatSession else { return }
        do {
            self.response = try await chatSession.value.respond(to: promptStr)
        } catch {
            print("error responding:", error)
        }
    }
}

#Preview {
    ChatView()
}
