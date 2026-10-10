import SwiftUI

struct HuggingFaceListView: View {
    
    @State private var vm = HuggingFaceListViewModel()
    
    var body: some View {
        VStack {
            HStack {
                TextField("", text: $vm.searchQuery)
                    .textFieldStyle(.roundedBorder)
                Button("search") {
                    Task { await vm.search() }
                }
            }
            
            if let progress = vm.downloadProgress {
                ProgressView("Downloading", value: progress)
                    .progressViewStyle(.linear)
            }
            
            downloadedModelList
            
            Divider()
            
            ModelListView(vm: vm)
            
            Button("Test \(vm.smallModel) (needs auth)") {
                Task { await vm.inference() }
            }
            
            MesssageView(message: $vm.message)
                .frame(minHeight: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // await vm.search()
            vm.updateDownloadedList()
        }
    }
    
    var downloadedModelList: some View {
        Section {
            if vm.downloadedModels.isEmpty {
                Text("None")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List(vm.downloadedModels) { model in
                    HStack {
                        Text(model.name)
                        #if os(macOS)
                        Spacer()
                        Button("", systemImage: "arrow.right.circle") {
                            NSWorkspace.shared.open(model.url)
                        }
                        .buttonStyle(.plain)
                        #endif // os(macOS)
                    }
                }
                .frame(minHeight: 70)
            }
        } header: {
            Text("Downloaded")
                .font(.headline)
               .frame(maxWidth: .infinity, alignment: .leading)
        }
        // .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if os(macOS)

struct ModelListView: View {
    @Bindable var vm: HuggingFaceListViewModel
    var body: some View {
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
                Button("Download") {
                    Task { await vm.download(model.id) }
                }
                .buttonStyle(.bordered)
            }
            .width(ideal: 200)
        }
        .frame(maxHeight: .infinity)
        .layoutPriority(1)
    }
}

#else

struct ModelListView: View {
    @Bindable var vm: HuggingFaceListViewModel
    var body: some View {
        List(vm.models) { model in
            ModelRowView(
                model: model,
                onLoadSize: { modelId in
                    Task { await vm.loadSize(modelId) }
                },
                onDownload: { modelId in
                    Task { await vm.download(modelId) }
                }
            )
        }
        .frame(maxHeight: .infinity)
        .layoutPriority(1)
    }
}

struct ModelRowView: View {
    let model: Model
    let onLoadSize: (Repo.ID) -> Void
    let onDownload: (Repo.ID) -> Void
    var body: some View {
        VStack(alignment: .leading) {
            Text(model.id.name)
            Group {
                Text("namespace: \(model.id.namespace)")
                Text("library: \(model.libraryString)")
                if model.usedStorage == nil {
                    Button("Load Size") {
                        onLoadSize(model.id)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("size: \(model.sizeString)")
                }
                Button("Download") {
                    onDownload(model.id)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)
            .padding(.horizontal)
        }
    }
}

#endif


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
                .textSelection(.enabled)
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
    private(set) var downloadedModels: [CachedModel] = []
    var message: String = ""
    var downloadProgress: Double?
    
    let smallModel = "mlx-community/gemma-3-1b-it-4bit-DWQ"
    
    func search() async {
        do {
            let response = try await self.hubClient.listModels(search: searchQuery, limit: 50)
            models = response.items //.sorted(by: { ($0.downloads ?? 0) > ($1.downloads ?? 0) })
            updateDownloadedList()
        } catch {
            message = error.localizedDescription
            print(error)
        }
    }
    
    func updateDownloadedList() {
        downloadedModels = Common.loadCachedModels()
        print("downloadedModels: \(downloadedModels)")
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
    
    func download(_ repoId: Repo.ID) async {
        guard downloadProgress == nil else {
            message = "Another download already in progress, skipping"
            return
        }
        downloadProgress = 0.0
        do {
            let url = try await self.hubClient.downloadSnapshot(of: repoId) { progress in
                self.downloadProgress = progress.fractionCompleted
            }
            message = "Downloaded to: \(url.path(percentEncoded: false))"
            print(message)
        } catch {
            message = error.localizedDescription
            print(error)
        }
        downloadProgress = nil
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
