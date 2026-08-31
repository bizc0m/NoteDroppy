// NoteDroppy V4 — Etape 5 (partie 3) du plan de migration V5
//
// Ce qui se passe quand on depose une cible (fichier .md, lien noteplan://
// ou obsidian://, texte colle) sur une ligne ShortcutSlotRow : resoudre le
// chemin relatif au dossier NotePlan, l'appliquer a la ligne, persister,
// et rapporter un statut. C'est le pont entre PasteboardResolver (etape 2,
// "y a-t-il quelque chose d'exploitable sur le pasteboard ?") et
// ShortcutSlotRow (etape 3, "affiche cette cible").
//
// Copie depuis les methodes privees de SettingsWindowController dans
// NotePlanURLDrop/main.swift (applyDroppedTarget, commitDroppedPath,
// applyDroppedObsidianTarget, pasteTarget, et leurs dependances de
// resolution de chemin/URL). Regroupees dans une petite classe
// ShortcutTargetRouter plutot qu'en fonctions libres : contrairement a
// CaptureWriter/CaptureTrigger (etape 5, parties 1-2) qui ne lisaient que
// des reglages, ces methodes ecrivaient directement dans les champs de
// SettingsWindowController (statusLabel.stringValue = ...) et
// appelaient shortcutRows.forEach { Settings.setShortcutSlot(...) } (tout
// le formulaire). Ici : un callback onStatus fermeture au lieu d'un label
// direct, et persistence limitee a la ligne modifiee (ShortcutSlotStore.
// setShortcutSlot(row.slot)) plutot qu'a tout le formulaire — l'effet
// observable est le meme pour un depot sur une ligne, sans dependre d'un
// formulaire complet pas encore assemble en V4.

import AppKit
import Foundation

final class ShortcutTargetRouter {
    var onStatus: ((String) -> Void)?

    init(onStatus: ((String) -> Void)? = nil) {
        self.onStatus = onStatus
    }

    private func status(_ message: String) {
        onStatus?(message)
    }

    func applyDroppedTarget(_ target: ShortcutTarget, to row: ShortcutSlotRow) -> Bool {
        Log.write("shortcut-drop:apply-target:slot:\(row.index):url:\(target.url?.absoluteString ?? "-"):text:\(target.rawText ?? "-")")
        if obsidianURL(from: target) != nil {
            row.setEngine(.obsidian)
            return applyDroppedObsidianTarget(target, to: row)
        }

        if row.slot.engine == .obsidian {
            return applyDroppedObsidianTarget(target, to: row)
        }

        guard let root = ShortcutSlotStore.selectedNotesRoot() else {
            status("Choisis d'abord le dossier Notes NotePlan, puis dépose une note .md.")
            NSSound.beep()
            return false
        }

        if let url = target.url {
            if url.scheme?.lowercased() == "noteplan",
               let path = notePathFromDroppedText(url.absoluteString, root: root) {
                return commitDroppedPath(relativePath: path, isDirectory: false, row: row)
            }

            guard url.isFileURL else {
                status("Dépose une note .md, un dossier, ou colle un lien NotePlan.")
                NSSound.beep()
                return false
            }

            let fileURL = url.standardizedFileURL
            let rootURL = root.standardizedFileURL
            let filePath = fileURL.path
            let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"

            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory)

            guard filePath == rootURL.path || filePath.hasPrefix(rootPath) else {
                if isDirectory.boolValue {
                    return commitDroppedPath(relativePath: fileURL.lastPathComponent, isDirectory: true, row: row)
                }
                if fileURL.pathExtension.lowercased() == "md" {
                    return commitDroppedPath(relativePath: fileURL.lastPathComponent, isDirectory: false, row: row)
                }
                status("Pour Cible, dépose un dossier Finder ou une note .md.")
                NSSound.beep()
                return false
            }

            let relativePath = filePath == rootURL.path
                ? ""
                : String(filePath.dropFirst(rootPath.count))
            if !isDirectory.boolValue, fileURL.pathExtension.lowercased() != "md" {
                status("Dépose une note .md ou un dossier NotePlan.")
                NSSound.beep()
                return false
            }

            return commitDroppedPath(relativePath: relativePath, isDirectory: isDirectory.boolValue, row: row)
        }

        if let text = target.rawText, let path = notePathFromDroppedText(text, root: root) {
            var isDirectory: ObjCBool = false
            let targetURL = root.appendingPathComponent(path)
            FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDirectory)
            return commitDroppedPath(relativePath: path, isDirectory: isDirectory.boolValue, row: row)
        }

        status("Dépose une note .md depuis Finder.")
        NSSound.beep()
        return false
    }

    private func applyDroppedObsidianTarget(_ target: ShortcutTarget, to row: ShortcutSlotRow) -> Bool {
        if let obsidianURL = obsidianURL(from: target),
           let parsed = obsidianTarget(from: obsidianURL) {
            row.applyDroppedObsidianURI(vault: parsed.vault, note: parsed.note)
            persist(row)
            status("Cible Obsidian enregistrée : \(parsed.note)")
            return true
        }

        guard let url = target.url, url.isFileURL else {
            status("Pour Obsidian, dépose une note .md, un dossier, ou un lien obsidian://.")
            NSSound.beep()
            return false
        }

        let fileURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            status("Fichier introuvable : \(fileURL.path)")
            NSSound.beep()
            return false
        }

        if !isDirectory.boolValue, fileURL.pathExtension.lowercased() != "md" {
            status("Pour Obsidian, dépose une note .md ou un dossier.")
            NSSound.beep()
            return false
        }

        row.applyDroppedPath(relativePath: fileURL.path, isDirectory: isDirectory.boolValue)
        persist(row)
        status("Cible Obsidian enregistrée : \(fileURL.path)")
        return true
    }

    private func obsidianURL(from target: ShortcutTarget) -> URL? {
        if let url = target.url, url.scheme?.lowercased() == "obsidian" {
            return url
        }
        if let text = target.rawText {
            for candidate in droppedObsidianURLCandidates(from: text) {
                if let url = URL(string: candidate), url.scheme?.lowercased() == "obsidian" {
                    return url
                }
            }
        }
        return nil
    }

    func pasteTarget(for row: ShortcutSlotRow) {
        Log.write("shortcut-paste:slot:\(row.index):\(pasteboardPreview(from: NSPasteboard.general))")
        var target = shortcutTarget(from: NSPasteboard.general)
        if target == nil {
            Log.write("shortcut-paste:fallback-noteplan-url:start")
            if copyCurrentNotePlanURLToPasteboard() {
                Log.write("shortcut-paste:fallback-noteplan-url:clipboard:\(pasteboardPreview(from: NSPasteboard.general))")
                target = shortcutTarget(from: NSPasteboard.general)
            } else {
                Log.write("shortcut-paste:fallback-noteplan-url:failed")
            }
        }

        guard let target else {
            status("Depuis NotePlan, ouvre une note puis utilise Note > Copier l'URL vers la note, ou copie un titre/chemin .md.")
            NSSound.beep()
            return
        }
        _ = applyDroppedTarget(target, to: row)
    }

    private func copyCurrentNotePlanURLToPasteboard() -> Bool {
        let script = """
        set copied to false
        tell application "NotePlan" to activate
        delay 0.15
        tell application "System Events"
          if exists process "NotePlan" then
            tell process "NotePlan"
              repeat with itemName in {"Copier l'URL vers la note", "Copy Note URL", "Copy URL to Note", "Copy URL to note"}
                try
                  click menu item itemName of menu "Note" of menu bar 1
                  set copied to true
                  exit repeat
                end try
              end repeat
            end tell
          end if
        end tell
        delay 0.2
        tell application "NoteDroppy V4" to activate
        return copied
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            Log.write("shortcut-paste:fallback-noteplan-url:error:\(error)")
        }
        return result.booleanValue
    }

    private func commitDroppedPath(relativePath: String, isDirectory: Bool, row: ShortcutSlotRow) -> Bool {
        Log.write("shortcut-drop:commit-path:slot:\(row.index):path:\(relativePath):isDirectory:\(isDirectory)")
        row.applyDroppedPath(relativePath: relativePath, isDirectory: isDirectory)
        persist(row)
        status("Cible enregistrée : \(relativePath.isEmpty ? "Notes" : relativePath)")
        return true
    }

    /// Persiste uniquement la ligne modifiee (ShortcutSlotStore.setShortcutSlot),
    /// contrairement a l'original qui sauvait tout le formulaire — cf.
    /// commentaire d'en-tete de fichier.
    private func persist(_ row: ShortcutSlotRow) {
        ShortcutSlotStore.setShortcutSlot(row.slot)
        let slot = row.slot
        Log.write("shortcut-drop:saved:slot:\(slot.index):destination:\(slot.destination.rawValue):folder:\(slot.folder):note:\(slot.noteReference):engine:\(slot.engine.rawValue)")
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    // MARK: - Resolution de chemin depuis un texte/URL depose

    private func notePathFromDroppedText(_ text: String, root: URL) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for urlText in droppedURLCandidates(from: trimmed) {
            if let path = notePathFromNotePlanURL(urlText, root: root) {
                return path
            }
        }

        if let path = notePathFromQueryText(trimmed, root: root) {
            return path
        }

        if let url = URL(string: trimmed), url.isFileURL {
            let fileURL = url.standardizedFileURL
            let rootURL = root.standardizedFileURL
            let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
            if fileURL.path.hasPrefix(rootPath) {
                return String(fileURL.path.dropFirst(rootPath.count))
            }
        }

        if trimmed.hasPrefix(root.path) {
            let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
            return String(trimmed.dropFirst(rootPath.count))
        }

        for candidateText in droppedTitleCandidates(from: trimmed) {
            if candidateText.contains("/") || candidateText.hasSuffix(".md") {
                let candidate = candidateText.hasSuffix(".md") ? candidateText : "\(candidateText).md"
                if FileManager.default.fileExists(atPath: root.appendingPathComponent(candidate).path) {
                    return candidate
                }
            }
            if let match = notePathMatchingTitle(candidateText, root: root) {
                return match
            }
        }
        return nil
    }

    private func notePathFromQueryText(_ text: String, root: URL) -> String? {
        let queryText: String
        if let questionMark = text.firstIndex(of: "?") {
            queryText = String(text[text.index(after: questionMark)...])
        } else {
            queryText = text
        }

        guard queryText.contains("="),
              let components = URLComponents(string: "noteplan://local?\(queryText)") else {
            return nil
        }

        let items = components.queryItems ?? []
        for name in ["notePath", "fileName"] {
            if let value = items.first(where: { $0.name == name })?.value, !value.isEmpty {
                return value
            }
        }
        if let title = items.first(where: { $0.name == "noteTitle" })?.value, !title.isEmpty {
            return notePathMatchingTitle(title, root: root) ?? (title.hasSuffix(".md") ? title : "\(title).md")
        }
        return nil
    }

    private func notePathFromNotePlanURL(_ text: String, root: URL) -> String? {
        guard let components = URLComponents(string: text),
              components.scheme?.lowercased() == "noteplan" else {
            return nil
        }
        let items = components.queryItems ?? []
        for name in ["notePath", "fileName"] {
            if let value = items.first(where: { $0.name == name })?.value, !value.isEmpty {
                return value
            }
        }
        if let title = items.first(where: { $0.name == "noteTitle" })?.value, !title.isEmpty {
            return notePathMatchingTitle(title, root: root) ?? (title.hasSuffix(".md") ? title : "\(title).md")
        }
        return nil
    }

    private func droppedURLCandidates(from text: String) -> [String] {
        var candidates: [String] = [text]
        let pattern = #"(?:noteplan|obsidian)://[^\s\)\]>"]+"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                if let matchRange = Range(match.range, in: text) {
                    candidates.append(String(text[matchRange]))
                }
            }
        }
        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    private func droppedObsidianURLCandidates(from text: String) -> [String] {
        droppedURLCandidates(from: text).filter { $0.range(of: "obsidian://", options: .caseInsensitive) != nil }
    }

    private func obsidianTarget(from url: URL) -> (vault: String?, note: String)? {
        guard url.scheme?.lowercased() == "obsidian" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let vault = items.first(where: { $0.name.caseInsensitiveCompare("vault") == .orderedSame })?.value
        let file = items.first(where: { ["file", "path"].contains($0.name.lowercased()) })?.value
            ?? components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let file, !file.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return (vault, file)
    }

    private func droppedTitleCandidates(from text: String) -> [String] {
        var candidates: [String] = []
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            let cleanHeading = line.trimmingCharacters(in: CharacterSet(charactersIn: "# \t"))
            if line.hasPrefix("#"), !cleanHeading.isEmpty {
                candidates.append(cleanHeading)
            }
            if line.hasPrefix("["),
               let close = line.firstIndex(of: "]") {
                let title = String(line[line.index(after: line.startIndex)..<close])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { candidates.append(title) }
            }
            candidates.append(line)
        }

        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n[]"))
        if !flattened.isEmpty { candidates.append(flattened) }

        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    private func notePathMatchingTitle(_ title: String, root: URL) -> String? {
        let cleanTitle = title.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n#[]"))
        guard !cleanTitle.isEmpty else { return nil }
        let lowerTitle = cleanTitle.lowercased()
        let exactFileName = cleanTitle.hasSuffix(".md") ? cleanTitle : "\(cleanTitle).md"

        let matches = noteMarkdownFiles(under: root).compactMap { url -> String? in
            let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let fileName = url.lastPathComponent
            if fileName.compare(exactFileName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                return relativePath
            }
            let baseName = url.deletingPathExtension().lastPathComponent.lowercased()
            if baseName == lowerTitle {
                return relativePath
            }
            let summary = noteSearchSummary(from: url)
            if summary.title?.lowercased() == lowerTitle {
                return relativePath
            }
            return nil
        }
        return matches.sorted { $0.count < $1.count }.first
    }
}
