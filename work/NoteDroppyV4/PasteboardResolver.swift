// NoteDroppy V4 — Pasteboard / drop-target detection
//
// Etape 2 du plan de migration V5 (toujours sans UI, sans drag & drop reel —
// juste la logique pure de "qu'est-ce qu'il y a sur ce pasteboard ?").
// Correspond a deux des composants listes pour l'architecture V5 :
//   - PasteboardInspector : lecture brute d'un NSPasteboard (strings, noms de
//     fichiers, aperçu debug) sans opinion sur ce que ça represente.
//   - DropTargetResolver  : shortcutTarget(from:), qui prend cette lecture
//     brute et decide s'il y a une cible utilisable (fichier .md, lien
//     noteplan://, lien obsidian://, ...) et sous quelle forme.
//
// Code copie verbatim depuis NotePlanURLDrop/main.swift (memes 15 branches
// de detection, meme ordre de priorite) — aucune logique inventee. Seul
// changement : writeDebugLog(...) -> Log.write(...), pour reutiliser le
// logger deja present dans NoteDroppyV4/main.swift (Paths.logFile) plutot
// que d'ecrire un second fichier de log parallele a
// /tmp/NotePlanURLDrop.log.

import AppKit
import Foundation

// MARK: - PasteboardInspector

let shortcutDropPasteboardTypes: [NSPasteboard.PasteboardType] = [
    .fileURL,
    .URL,
    .string,
    NSPasteboard.PasteboardType("public.utf8-plain-text"),
    NSPasteboard.PasteboardType("public.text"),
    NSPasteboard.PasteboardType("public.url"),
    NSPasteboard.PasteboardType("public.url-name"),
    NSPasteboard.PasteboardType("public.data"),
    NSPasteboard.PasteboardType("public.item"),
    NSPasteboard.PasteboardType("public.content"),
    NSPasteboard.PasteboardType("co.noteplan.notecard"),
    NSPasteboard.PasteboardType("NSFilesPromisePboardType"),
    NSPasteboard.PasteboardType("com.apple.NSFilesPromisePboardType"),
    NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"),
    NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-content-type"),
    NSPasteboard.PasteboardType("com.apple.NSFilePromiseItemMetaData"),
    NSPasteboard.PasteboardType("com.apple.finder.node"),
    NSPasteboard.PasteboardType("net.daringfireball.markdown"),
    NSPasteboard.PasteboardType("com.apple.traditional-mac-plain-text")
]

func preferredDragOperation(from mask: NSDragOperation) -> NSDragOperation {
    for operation in [NSDragOperation.copy, .link, .generic, .move] {
        if mask.contains(operation) {
            return operation
        }
    }
    return .copy
}

private func pasteboardFilenames(from pasteboard: NSPasteboard) -> [String] {
    let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    guard let data = pasteboard.data(forType: filenamesType),
          let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    else {
        return []
    }
    var filenames = strings(fromPropertyList: plist)
    filenames = filenames.filter { filename in
        !filename.isEmpty &&
        !filename.hasPrefix("/.file/id=") &&
        FileManager.default.fileExists(atPath: filename)
    }
    return filenames
}

private func existingFinderPath(from text: String) -> String? {
    let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }

    var candidates = [raw]
    if let embeddedPath = embeddedMarkdownPath(from: raw) {
        candidates.append(embeddedPath)
    }

    for candidate in candidates {
        let decoded = candidate.removingPercentEncoding ?? candidate
        let path: String
        if let url = URL(string: decoded), url.isFileURL {
            guard !url.path.hasPrefix("/.file/id=") else { continue }
            path = url.path
        } else {
            path = decoded
        }
        if path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) {
            return path
        }
    }
    return nil
}

private func pasteboardStrings(from pasteboard: NSPasteboard) -> [String] {
    var values: [String] = []
    for type in pasteboard.types ?? [] {
        if let value = pasteboard.string(forType: type)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            values.append(value)
        }
        if let data = pasteboard.data(forType: type) {
            if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
                values.append(contentsOf: strings(fromPropertyList: plist))
            }
            values.append(contentsOf: strings(fromPasteboardData: data))
        }
    }
    if let objects = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String] {
        values.append(contentsOf: objects.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    var seen = Set<String>()
    return values.filter { value in
        if seen.contains(value) {
            return false
        } else {
            seen.insert(value)
            return true
        }
    }
}

private func strings(fromPropertyList value: Any) -> [String] {
    if let string = value as? String {
        return [string.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
    }
    if let array = value as? [Any] {
        return array.flatMap { strings(fromPropertyList: $0) }
    }
    if let dictionary = value as? [AnyHashable: Any] {
        return dictionary.flatMap { key, value in
            strings(fromPropertyList: key).filter { !$0.isEmpty } + strings(fromPropertyList: value)
        }
    }
    return []
}

private func strings(fromPasteboardData data: Data) -> [String] {
    var values: [String] = []
    for encoding in [String.Encoding.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .macOSRoman] {
        if let value = String(data: data, encoding: encoding)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            values.append(value)
        }
    }

    let printableBytes = data.map { byte -> UInt8 in
        if byte == 10 || byte == 13 || byte == 9 || (byte >= 32 && byte <= 126) {
            return byte
        }
        return 32
    }
    if let printable = String(bytes: printableBytes, encoding: .utf8) {
        values.append(contentsOf: printable
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { value in
                value.range(of: "noteplan://", options: .caseInsensitive) != nil ||
                value.range(of: "obsidian://", options: .caseInsensitive) != nil ||
                value.lowercased().hasSuffix(".md") ||
                value.lowercased().contains(".md") ||
                value.range(of: "notePath=", options: .caseInsensitive) != nil ||
                value.range(of: "fileName=", options: .caseInsensitive) != nil
            })
    }
    return values
}

private func embeddedMarkdownPath(from text: String) -> String? {
    let cleaned = text
        .replacingOccurrences(of: "<string>", with: "")
        .replacingOccurrences(of: "</string>", with: "")
        .replacingOccurrences(of: "&amp;", with: "&")

    let patterns = [
        #"file:///(?:Users|Volumes)/[^\s<>"']+?\.md"#,
        #"/(?:Users|Volumes)/[^\n\r<>"']+?\.md"#,
        #"[A-Za-z0-9_@ .-]+/[^\n\r<>"']+?\.md"#
    ]

    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
        let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        for match in regex.matches(in: cleaned, range: range) {
            guard let matchRange = Range(match.range, in: cleaned) else { continue }
            let candidate = String(cleaned[matchRange])
                .removingPercentEncoding?
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n\"'")) ?? ""
            if !candidate.isEmpty {
                return candidate
            }
        }
    }
    return nil
}

func pasteboardPreview(from pasteboard: NSPasteboard) -> String {
    pasteboardStrings(from: pasteboard)
        .prefix(6)
        .map { value in
            let collapsed = value.replacingOccurrences(of: "\n", with: "\\n")
            if collapsed.count > 120 {
                let end = collapsed.index(collapsed.startIndex, offsetBy: 120)
                return String(collapsed[..<end]) + "..."
            }
            return collapsed
        }
        .joined(separator: " | ")
}

func pasteboardDebugDescription(_ pasteboard: NSPasteboard) -> String {
    let types = (pasteboard.types ?? []).map { $0.rawValue }.joined(separator: ",")
    let preview = pasteboardPreview(from: pasteboard)
    return preview.isEmpty ? types : "\(types) :: \(preview)"
}

// MARK: - DropTargetResolver

struct ShortcutTarget {
    let url: URL?
    let rawText: String?

    init(url: URL) {
        self.url = url
        self.rawText = nil
    }

    init(rawText: String) {
        self.url = nil
        self.rawText = rawText
    }
}

func shortcutTarget(from pasteboard: NSPasteboard) -> ShortcutTarget? {
    let strings = pasteboardStrings(from: pasteboard)
    Log.write("shortcut-target:types:\((pasteboard.types ?? []).map { $0.rawValue }.joined(separator: ","))")

    if let filename = pasteboardFilenames(from: pasteboard).first {
        return ShortcutTarget(url: URL(fileURLWithPath: filename))
    }

    if let value = pasteboard.string(forType: .fileURL),
       let url = URL(string: value),
       url.isFileURL,
       !url.path.hasPrefix("/.file/id=") {
        return ShortcutTarget(url: url)
    }

    if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
       let url = objects.first(where: { $0.isFileURL && !$0.path.hasPrefix("/.file/id=") }) {
        return ShortcutTarget(url: url)
    }

    if let existingPath = strings.lazy.compactMap({ existingFinderPath(from: $0) }).first {
        return ShortcutTarget(url: URL(fileURLWithPath: existingPath))
    }

    if let notePlanText = strings.first(where: { $0.range(of: "noteplan://", options: .caseInsensitive) != nil }) {
        return ShortcutTarget(rawText: notePlanText)
    }

    if let obsidianText = strings.first(where: { $0.range(of: "obsidian://", options: .caseInsensitive) != nil }) {
        return ShortcutTarget(rawText: obsidianText)
    }

    if let embeddedPath = strings.lazy.compactMap({ embeddedMarkdownPath(from: $0) }).first {
        return ShortcutTarget(rawText: embeddedPath)
    }

    if let pathLike = strings.first(where: { value in
        let lower = value.lowercased()
        return lower.hasPrefix("file://") || lower.hasSuffix(".md") || lower.contains(".md)")
    }) {
        if let url = URL(string: pathLike), url.scheme?.lowercased() == "file", !url.path.hasPrefix("/.file/id=") {
            return ShortcutTarget(url: url)
        }
        return ShortcutTarget(rawText: pathLike)
    }

    if let value = pasteboard.string(forType: .URL)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
        if let url = URL(string: value), ["file", "noteplan", "obsidian"].contains(url.scheme?.lowercased() ?? "") {
            return ShortcutTarget(url: url)
        }
    }

    if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
       let url = objects.first(where: { ["noteplan", "obsidian"].contains($0.scheme?.lowercased() ?? "") }) {
        return ShortcutTarget(url: url)
    }

    if let title = strings.first(where: { !$0.isEmpty }) {
        return ShortcutTarget(rawText: title)
    }

    return nil
}
