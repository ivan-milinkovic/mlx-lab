//
//  ChatView.swift
//  mlx-lab
//
//  Created by Ivan Milinkovic on 10. 10. 2026..
//

import SwiftUI
import MLXLMCommon

struct ChatView: View {
    
    @Environment(AppModel.self) private var vm
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
        @Bindable var vm = vm
        HStack {
            Picker("Model", selection: $vm.model) {
                Text("None")
                    .tag(nil as CachedModel?)
                ForEach(vm.models) { model in
                    Text(model.name)
                        .tag(model as CachedModel?)
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
    
    fileprivate func getVM() -> AppModel { vm }
}

#Preview("ChatView") {
    ChatView()
}

struct MessageListView: View {
    let messages: [AppModel.Message]
    
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
    let m1 = AppModel.Message(chatMessage: .init(role: .user, content: "User text here"))
    let m2 = AppModel.Message(chatMessage: .init(role: .assistant, content: "Assistant text here"))
    MessageListView(messages: [m1, m2])
}

struct MessageView: View {
    let message: AppModel.Message
    
    var body: some View {
        Group {
            Text(Common.makeMarkdown(message.chatMessage.content))
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
    let vmMsg = AppModel.Message(chatMessage: chatMsg)
    MessageView(message: vmMsg)
}
