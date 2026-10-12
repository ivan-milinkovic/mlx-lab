//
//  AppModel.swift
//  mlx-lab
//
//  Created by Ivan Milinkovic on 12. 10. 2026..
//

import Foundation
import Observation
import HuggingFace
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import MLX
import Algorithms

@Observable @MainActor
final class AppModel {
    
    static let shared = AppModel()
    
    var models: [CachedModel] = []
    var model: CachedModel?
    var messages: [Message] = []
    var isLoading = false
    var useRag = true
    
    struct RagEntry {
        let content: String
        let embedding: [Float]
    }
    
    private var ragEntries: [RagEntry] = []
    
    @ObservationIgnored var modelContainer: ModelContainer?
    @ObservationIgnored var chatSession: SendableWrapper<ChatSession>?
    
    @ObservationIgnored var promptTask: Task<Void, Never>?
    
    private let chunkSize = 300
    
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
    }
    
    func sendPrompt(_ promptStr: String) async {
        if let promptTask {
            await promptTask.value
        }
        promptTask = Task {
            await streamingMessagePrompt(promptStr)
        }
        await promptTask?.value
    }
    
    func simplePrompt(_ promptStr: String) async {
        isLoading = true; defer { isLoading = false }
        guard let chatSession else { return }
        do {
            let response = try await chatSession.value.respond(to: promptStr)
            print(response)
        } catch {
            print("error responding:", error)
        }
    }
    
    func streamingMessagePrompt(_ promptStr: String) async {
        guard let chatSession else { return }
        isLoading = true; defer { isLoading = false }
        let userMessage = await makeUserMessage(promptStr)
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
    
    private func makeUserMessage(_ promptStr: String) async -> Message {
        if useRag {
            return await makeUserMessageWithRag(promptStr)
        } else {
            return Message(chatMessage: Chat.Message(role: .user, content: promptStr))
        }
    }
    
    // MARK: - RAG
    
    private func makeUserMessageWithRag(_ promptStr: String) async -> Message {
        if let ragEntry = await findRagEntry(promptStr) {
            let augmentedPrompt = """
                Use the following context to answer the question:
                <context>
                \(ragEntry.content)
                </context>
                Question: \(promptStr)
                """
            return Message(chatMessage: Chat.Message(role: .user, content: augmentedPrompt))
        } else {
            return Message(chatMessage: Chat.Message(role: .user, content: promptStr))
        }
    }
    
    func findRagEntry(_ promptStr: String) async -> RagEntry? {
        let v = await embed(promptStr)
        var maxSim: Float = 0.0
        var idx: Int = -1
        for (i, re) in ragEntries.enumerated() {
            let sim = cos(re.embedding, v)
            if sim > maxSim {
                maxSim = sim
                idx = i
            }
        }
        if idx >= 0 {
            return ragEntries[idx]
        } else {
            return nil
        }
    }
    
    func takeRagResources(_ content: String) async {
        let chunks = chunkContent(content)
        for chunk in chunks {
            let emb = await embed(chunk)
            let entry = RagEntry(content: chunk, embedding: emb)
            ragEntries.append(entry)
        }
        print("rag entries:", ragEntries.count)
    }
    
    func chunkContent(_ content: String) -> [String] {
        content.chunks(ofCount: chunkSize).map(String.init)
    }
    
    private func embed(_ text: String) async -> [Float] {
        guard let container = modelContainer else {
            return []
        }
        
        return await container.perform { (context: ModelContext) in
            let tokenizer = context.tokenizer
            
            // 1. Tokenize text
            let tokens = tokenizer.encode(text: text)
            let inputIds = MLXArray(tokens).expandedDimensions(axes: [0]) // [1, sequenceLength]
            
            // 2. Forward pass through your loaded LLM (all transformer layers)
            // output has shape [1, sequenceLength, vocabSize]
            let output = context.model(inputIds, cache: nil)
            
            // 3. Pool the sequence:
            // Mean pooling across all tokens: [1, sequenceLength, vocabSize] -> [vocabSize]
            let pooled = MLX.mean(output[0], axis: 0)
            
            // 4. L2-normalize so cosine similarity is just the dot product
            let normalized = pooled / (MLX.norm(pooled) + 1e-9)
            
            // 5. Evaluate on GPU and return as [Float]
            normalized.eval()
            return normalized.asArray(Float.self)
        }
    }
}
