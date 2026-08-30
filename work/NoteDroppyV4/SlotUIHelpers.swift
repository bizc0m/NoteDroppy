// NoteDroppy V4 — Etape 3a du plan de migration V5
//
// Dependances communes pour porter ShortcutSlotRow et sa fenetre de
// recherche : indexation des notes du dossier NotePlan, helpers de style
// visuel des champs (dont les couleurs #tag/$variable/!config/@contexte a
// garder), et un helper de fenetre centree. Copie verbatim depuis
// NotePlanURLDrop/main.swift, writeDebugLog(...) -> Log.write(...).
//
// Utilise ShortcutSlotStore.selectedNotesRoot() (etape 1, cle
// "notesRootPath"/"notesRootBookmark" non prefixee) — PAS le
// Settings.notesRootPath prefixe "v4." deja utilise par
// MainWindowController pour son propre picker. Les deux coexistent : ce
// fichier lit le dossier NotePlan que Note Droopy connait deja.

import AppKit
import Carbon
import Foundation

struct NoteSearchResult {
    let title: String
    let relativePath: String
    let folder: String
    let tags: [String]
    let modifiedAt: Date
}

private func notePlanNotesRoots() -> [URL] {
    guard let selectedRoot = ShortcutSlotStore.selectedNotesRoot() else { return [] }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: selectedRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        return []
    }
    return [selectedRoot]
}

func loadNoteSearchResults() -> [NoteSearchResult] {
    var seen = Set<String>()
    var results: [NoteSearchResult] = []

    for root in notePlanNotesRoots() {
        let scopedAccess = root.startAccessingSecurityScopedResource()
        defer {
            if scopedAccess {
                root.stopAccessingSecurityScopedResource()
            }
        }
        Log.write("search:index:root:start:\(root.path)")
        for url in noteMarkdownFiles(under: root) {
            let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
            guard seen.insert(relativePath).inserted else { continue }

            let summary = noteSearchSummary(from: url)
            let folder = URL(fileURLWithPath: relativePath).deletingLastPathComponent().relativePath
            results.append(NoteSearchResult(
                title: summary.title ?? url.deletingPathExtension().lastPathComponent,
                relativePath: relativePath,
                folder: folder == "." ? "" : folder,
                tags: summary.tags,
                modifiedAt: .distantPast
            ))
        }
        Log.write("search:index:root:done:\(root.path):\(results.count)")
    }

    return results.sorted {
        if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
        return $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending
    }
}

private func noteMarkdownFiles(under root: URL) -> [URL] {
    let skippedDirectories = Set(["@Trash", "@Archive", ".obsidian"])
    var files: [URL] = []
    var pending: [(path: String, depth: Int)] = [(root.path, 0)]

    while let current = pending.popLast() {
        guard current.depth <= 8 else { continue }
        guard let directory = opendir(current.path) else { continue }
        defer { closedir(directory) }

        while let entry = readdir(directory) {
            var dName = entry.pointee.d_name
            let dNameCapacity = MemoryLayout.size(ofValue: dName)
            let name = withUnsafePointer(to: &dName) {
                $0.withMemoryRebound(to: CChar.self, capacity: dNameCapacity) {
                    String(cString: $0)
                }
            }
            if name == "." || name == ".." || name.hasPrefix(".") { continue }
            if skippedDirectories.contains(name) { continue }

            let childPath = (current.path as NSString).appendingPathComponent(name)
            var info = stat()
            guard lstat(childPath, &info) == 0 else { continue }

            if (info.st_mode & S_IFMT) == S_IFDIR {
                pending.append((childPath, current.depth + 1))
            } else if (info.st_mode & S_IFMT) == S_IFREG, childPath.lowercased().hasSuffix(".md") {
                files.append(URL(fileURLWithPath: childPath))
            }
        }
    }

    return files
}

private func noteSearchSummary(from url: URL) -> (title: String?, tags: [String]) {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return (nil, []) }
    defer { try? handle.close() }
    let data = handle.readData(ofLength: 65536)
    guard let content = String(data: data, encoding: .utf8) else { return (nil, []) }
    var title: String?
    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if title == nil, trimmed.hasPrefix("# ") {
            let parsedTitle = trimmed.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
            title = parsedTitle.isEmpty ? nil : parsedTitle
        }
    }
    return (title, noteTags(in: content))
}

private let noteTagPattern = try? NSRegularExpression(pattern: #"(?<![\p{L}\p{N}_])[#@][\p{L}\p{N}_][\p{L}\p{N}_/-]*"#)

private func noteTags(in content: String) -> [String] {
    guard let regex = noteTagPattern else { return [] }
    let range = NSRange(content.startIndex..<content.endIndex, in: content)
    var seen = Set<String>()
    var tags: [String] = []
    for match in regex.matches(in: content, range: range) {
        guard let swiftRange = Range(match.range, in: content) else { continue }
        let tag = String(content[swiftRange])
        if seen.insert(tag.lowercased()).inserted {
            tags.append(tag)
        }
    }
    return tags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

func centeredWindow(_ title: String, width: CGFloat, height: CGFloat, style: NSWindow.StyleMask = [.titled, .closable, .resizable]) -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: style,
        backing: .buffered,
        defer: false
    )
    window.title = title
    if let visibleFrame = NSScreen.main?.visibleFrame {
        var frame = window.frame
        frame.origin.x = visibleFrame.midX - frame.width / 2
        frame.origin.y = visibleFrame.midY - frame.height / 2
        window.setFrame(frame, display: true)
    } else {
        window.center()
    }
    return window
}

func styleFillableField(_ field: NSTextField) {
    field.drawsBackground = true
    field.backgroundColor = NSColor.controlBackgroundColor.blended(withFraction: 0.16, of: .white) ?? .controlBackgroundColor
    field.textColor = .labelColor
}

func styleConfigField(_ field: NSTextField) {
    styleFillableField(field)
    field.wantsLayer = true
    field.layer?.borderWidth = 1
    field.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.35).cgColor
    field.layer?.cornerRadius = 5
}

/// Colore le contenu d'un champ Tag & Config : #tag vert, $variable bleu,
/// !config indigo (violet), @contexte orange — a garder tel quel, c'est la
/// grammaire visuelle demandee.
func applyTagsConfigColors(to field: NSTextField) {
    let text = field.stringValue
    let attributed = NSMutableAttributedString(
        string: text,
        attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
        ]
    )
    let nsText = text as NSString
    let fullRange = NSRange(location: 0, length: nsText.length)
    let rules: [(String, NSColor)] = [
        (#"#[\p{L}\p{N}_/-]+"#, .systemGreen),
        (#"\$[A-Za-z][A-Za-z0-9_:-]*"#, .systemBlue),
        (#"!{1,5}|![A-Za-z][A-Za-z0-9_:-]*"#, .systemIndigo),
        (#"@[\p{L}\p{N}_/-]+"#, .systemOrange)
    ]
    for (pattern, color) in rules {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
        regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            attributed.addAttribute(.foregroundColor, value: color, range: range)
        }
    }
    field.attributedStringValue = attributed
}

func formLabel(_ title: String, width: CGFloat = 142) -> NSTextField {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.widthAnchor.constraint(equalToConstant: width).isActive = true
    return label
}

/// Format "ctrl+option+cmd+p" — utilise pour l'export JSON des Preferences
/// (PreferencesFile, pas encore porte) ; inclus ici car il vit a cote de
/// KeyCombo dans le fichier d'origine.
func shortcutString(from combo: KeyCombo) -> String {
    var parts: [String] = []
    if combo.carbonModifiers & UInt32(controlKey) != 0 { parts.append("ctrl") }
    if combo.carbonModifiers & UInt32(optionKey) != 0 { parts.append("option") }
    if combo.carbonModifiers & UInt32(shiftKey) != 0 { parts.append("shift") }
    if combo.carbonModifiers & UInt32(cmdKey) != 0 { parts.append("cmd") }
    parts.append(combo.display
        .replacingOccurrences(of: "⌃", with: "")
        .replacingOccurrences(of: "⌥", with: "")
        .replacingOccurrences(of: "⇧", with: "")
        .replacingOccurrences(of: "⌘", with: "")
        .lowercased())
    return parts.joined(separator: "+")
}

extension Notification.Name {
    static let shortcutRecordingBegan = Notification.Name("NoteDroppyShortcutRecordingBegan")
    static let shortcutRecordingEnded = Notification.Name("NoteDroppyShortcutRecordingEnded")
}
