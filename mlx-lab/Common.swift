//
//  Common.swift
//  mlx-lab
//
//  Created by Ivan Milinkovic on 10. 10. 2026..
//

import Foundation
import HuggingFace

struct CachedModel: Identifiable, Hashable {
    let name: String
    let url: URL
    var id: URL { url }
}

enum Common {
    static func loadCachedModels() -> [CachedModel] {
        let cachesDirUrl = HubCache.default.cacheDirectory
        let cachesDirPath = cachesDirUrl.path(percentEncoded: false)
        let contents: [String] = (try? FileManager.default.contentsOfDirectory(atPath: cachesDirPath)) ?? []
        let filtered = contents.filter { !$0.hasPrefix(".") }
        let models = filtered.map {
            let url = cachesDirUrl.appending(path: $0, directoryHint: .isDirectory)
            return CachedModel(name: repoId(fromCacheFolder: $0), url: url)
        }
        return models
    }
    
    // A repo name that itself contains -- would be converted wrongly. Unlikely case.
    static func repoId(fromCacheFolder folder: String) -> String {
        folder
            .replacingOccurrences(of: "models--", with: "", options: .anchored)
            .replacingOccurrences(of: "--", with: "/")
    }
    
    static func makeMarkdown(_ content: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let astr = try? AttributedString(markdown: content, options: opts) {
            return astr
        } else {
            return AttributedString(stringLiteral: content)
        }
    }
}
