import SwiftUI

struct HuggingFaceListView: View {
    
    @State private var vm = HuggingFaceListViewModel()
    
    var body: some View {
        VStack {
            HStack {
                TextField("", text: $vm.searchQuery)
                Button("search") {
                    Task { await vm.search() }
                }
            }
            
            Table(vm.models) {
                TableColumn("Name", value: \.id.name)
                    .width(ideal: 300)
                TableColumn("Namespace", value: \.id.namespace)
                    .width(ideal: 100)
                TableColumn("Library", value: \.libraryString)
                    .width(ideal: 50)
                TableColumn("Size", value: \.sizeString)
                    .width(ideal: 70)
                TableColumn("Actions") { model in
                    Button("Load Size") {
                        Task { await vm.loadSize(model.id) }
                    }
                    .buttonStyle(.bordered)
                }
                .width(ideal: 200)
            }
            .frame(maxHeight: .infinity)
            .layoutPriority(1)
            
            Button("Test \(vm.smallModel) (needs auth)") {
                Task { await vm.inference() }
            }
            
            MesssageView(message: $vm.message)
                .frame(minHeight: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await vm.search()
        }
    }
}

struct ModelView: View {
    let model: Model
    var body: some View {
        VStack(alignment: .leading) {
            Text(model.id.name)
            Group {
                Text("namespace: \(model.id.namespace)")
                Text("library: \(model.libraryString)")
                Text("size: \(model.sizeString)")
            }
            .font(.subheadline)
            .padding(.horizontal)
        }
    }
}

struct MesssageView: View {
    @Binding var message: String
    var body: some View {
        ScrollView {
            if !message.isEmpty {
                Button("Clear", systemImage: "x.circle") {
                    message = ""
                }
            }
            Text(message)
        }
    }
}

#Preview {
    HuggingFaceListView()
}


import Observation
import HuggingFace

@MainActor @Observable final class HuggingFaceListViewModel {
    
    @ObservationIgnored let hubClient = HubClient.default
    @ObservationIgnored let inferenceClient = InferenceClient.default
    
    var searchQuery: String = "mlx-community"
    private(set) var models: [Model] = []
    var message: String = ""
    
    let smallModel = "mlx-community/gemma-3-1b-it-4bit-DWQ"
    
    func search() async {
        do {
           let response = try await self.hubClient.listModels(search: searchQuery, limit: 50)
           models = response.items //.sorted(by: { ($0.downloads ?? 0) > ($1.downloads ?? 0) })
        } catch {
            message = error.localizedDescription
            print(error)
        }
    }
    
    func loadSize(_ repoId: Repo.ID) async {
        do {
            let model = try await self.hubClient.getModel(repoId)
            guard let i = models.firstIndex(where: { $0.id == model.id })
            else { return }
            models[i] = model
        } catch {
            message = error.localizedDescription
            print(error)
        }
    }
    
    func inference() async {
        do {
            for try await chunk in inferenceClient.chatCompletionStream(
                model: smallModel,
                messages: [.user("Hello, what are you?")],
                provider: .groq,
                temperature: 0.7,
                maxTokens: 1000
            ) {
                if let content = chunk.choices.first?.message.content {
                    print(content, terminator: "")
                }
            }
        } catch {
            message = error.localizedDescription
            print(error)
        }
    }
}

func formattedStorage(bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB]
    formatter.countStyle = .decimal
    return formatter.string(fromByteCount: Int64(bytes))
}

extension Model {
    var sizeString: String {
        if let size = usedStorage {
            formattedStorage(bytes: size)
        } else {
            "?"
        }
    }
    
    var libraryString: String {
        library ?? "-"
    }
}
