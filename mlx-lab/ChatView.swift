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
    @State private var promptString = ""
    @FocusState private var isPromptFocused
    
    var body: some View {
        VStack {
            model
            // singleResponse
            messages
            prompt
        }
        .padding()
        .overlay {
            if vm.isLoading {
                ProgressView().progressViewStyle(.circular)
            }
        }
        .disabled(vm.isLoading)
        .onChange(of: vm.isLoading) { _, isLoading in
            guard !isLoading, vm.chatSession != nil else { return }
            Task { @MainActor in
                isPromptFocused = true
            }
        }
        .task {
            vm.setup()
        }
    }
    
    @ViewBuilder var model: some View {
        HStack {
            Picker("Model", selection: $vm.model) {
                Text("None")
                    .tag(nil as CachedModel?)
                ForEach(vm.models) { model in
                    Text(model.name)
                        .tag(model)
                }
            }
            .disabled(vm.modelContainer != nil)
            
            if vm.model != nil {
                if vm.modelContainer == nil {
                    Button("Load") {
                        Task {
                            await vm.load()
                            if vm.chatSession != nil {
                                isPromptFocused = true
                            }
                        }
                    }
                } else {
                    Button("Unload") {
                        Task { await vm.unload() }
                    }
                }
            }
        }
    }
    
    @ViewBuilder var prompt: some View {
        HStack {
            TextField("Prompt", text: $promptString)
                .focused($isPromptFocused)
                .frame(maxWidth: 400)
                .onSubmit {
                    sendPrompt()
                }
                .disabled(vm.chatSession == nil)
            
            Button("", systemImage: "arrow.right.circle") {
                sendPrompt()
            }
            .buttonStyle(.plain)
        }
    }
    
    private func sendPrompt() {
        Task { @MainActor in
            await vm.sendPrompt(promptString)
            promptString = ""
        }
    }
    
    @ViewBuilder var singleResponse: some View {
        Text("Response")
        ScrollView {
            Text(Common.makeMarkdown(vm.response))
        }
        .frame(maxWidth: 400, maxHeight: 400)
    }
    
    @ViewBuilder var messages: some View {
        ScrollViewReader { scrollProxy in
            MessageListView(messages: vm.messages)
            .onChange(of: vm.messages.last?.chatMessage.content) {
                if let id = vm.messages.last?.id {
                    scrollProxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: 800, maxHeight: 800)
    }
    
    fileprivate func getVM() -> ChatViewModel { vm }
}

#Preview("ChatView") {
    ChatView()
}

struct MessageListView: View {
    let messages: [ChatViewModel.Message]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(messages) {
                    MessageView(message: $0)
                }
            }
        }
    }
}

#Preview("MessageListView") {
    let m1 = ChatViewModel.Message(chatMessage: .init(role: .user, content: "User text here"))
    let m2 = ChatViewModel.Message(chatMessage: .init(role: .assistant, content: "Assistant text here"))
    MessageListView(messages: [m1, m2])
}

struct MessageView: View {
    let message: ChatViewModel.Message
    
    var body: some View {
        Group {
            Text(message.chatMessage.content)
                .textSelection(.enabled)
        }
        .padding(8)
        .foregroundStyle(color)
    }
    
    var color: Color {
        message.chatMessage.role == .user
        ? Color.accentColor
        : Color.primary
    }
}

#Preview("MessageView") {
    let chatMsg = Chat.Message(role: .user, content: "User text here")
    let vmMsg = ChatViewModel.Message(chatMessage: chatMsg)
    MessageView(message: vmMsg)
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
    var messages: [Message] = []
    var isLoading = false
    
    @ObservationIgnored var modelContainer: ModelContainer?
    @ObservationIgnored var chatSession: SendableWrapper<ChatSession>?
    
    @ObservationIgnored var promptTask: Task<Void, Never>?
    
    struct Message: Identifiable {
        let id = UUID()
        var chatMessage: Chat.Message
    }
    
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
    
    func unload() async {
        isLoading = true; defer { isLoading = false }
        await promptTask?.value
        promptTask = nil
        chatSession = nil
        modelContainer = nil
        messages = []
        response = ""
    }
    
    func sendPrompt(_ promptStr: String) async {
        if let promptTask {
            await promptTask.value
        }
        promptTask = Task {
            // await simplePrompt(promptStr)
            // await streamingPrompt(promptStr)
            await streamingMessagePrompt(promptStr)
        }
    }
    
    func simplePrompt(_ promptStr: String) async {
        isLoading = true; defer { isLoading = false }
        guard let chatSession else { return }
        do {
            self.response = try await chatSession.value.respond(to: promptStr)
        } catch {
            print("error responding:", error)
        }
    }
    
    func streamingPrompt(_ promptStr: String) async {
        guard let chatSession else { return }
        response = ""
        do {
            for try await chunk in chatSession.value.streamResponse(to: promptStr) {
                response += chunk
            }
        } catch {
            print("error responding:", error)
        }
    }
    
    func streamingMessagePrompt(_ promptStr: String) async {
        guard let chatSession else { return }
        isLoading = true; defer { isLoading = false }
        let userMessage = Message(chatMessage: Chat.Message(role: .user, content: promptStr))
        let responseMessage = Message(chatMessage: Chat.Message(role: .assistant, content: ""))
        messages.append(userMessage)
        messages.append(responseMessage)
        let idx = messages.endIndex.advanced(by: -1)
        do {
            for try await chunk in chatSession.value.streamResponse(to: promptStr) {
                messages[idx].chatMessage.content += chunk
            }
        } catch {
            let errorMessage = Message(chatMessage: Chat.Message(role: .assistant, content: error.localizedDescription))
            messages.append(errorMessage)
        }
    }
}
