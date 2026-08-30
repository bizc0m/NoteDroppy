// NoteDroppy V4 — Etape 5 du plan de migration V5 (partie 1 : NotePlanWriter/ObsidianWriter/CaptureRouter)
//
// Ce que fait vraiment un raccourci : formatter le texte capture en ligne
// de tache NotePlan (prefixe, priorite, echeance, tags), puis l'ecrire soit
// via x-callback-url NotePlan, soit dans un fichier de section precise,
// soit dans une note Obsidian. Copie depuis les methodes privees
// d'AppDelegate dans NotePlanURLDrop/main.swift (sendTodo, writeNotePlanTask,
// writeObsidianTask, notePlanTarget, notePlanFileTarget, et leurs
// dependances) — converties de methodes d'instance en fonctions libres
// (aucune ne mutait d'etat d'AppDelegate, elles ne faisaient que lire
// Settings/ShortcutSlot et ecrire des fichiers), Settings.X ->
// ShortcutSlotStore.X, log(...)/writeDebugLog(...) -> Log.write(...).
//
// PORTEE REDUITE PAR RAPPORT A L'ORIGINAL, EXPLICITEMENT :
// CaptureRulesStore.metadata(for:) (titres de lien auto-devines depuis
// capture-rules.json) et llmTags(in:) (tags auto-inferes depuis les regles
// de capture) sont omis ici. Ni CaptureRulesStore ni les tags LLM
// n'etaient dans la liste des fonctions/variables a preserver — c'est un
// systeme separat, pas encore audite pour V5. formattedTask/
// markdownLinkForWebURL degradent proprement sans eux (titre de lien
// devine depuis l'URL au lieu d'un titre appris ; tags = ceux ecrits dans
// le champ Tag & Config, sans enrichissement automatique). Note pour la
// suite : porter CaptureRulesStore comme etape separee si ces
// fonctionnalites sont utilisees en pratique.

import AppKit
import Foundation

private enum CaptureSectionPosition {
    case sectionTop
    case sectionBottom
    case beforeSection
    case afterSection
}

private enum CaptureLinePrefix {
    case task
    case star
    case plus
    case plain
}

// MARK: - CaptureRouter (sendTodo)

func sendTodo(_ todoText: String, shortcutSlot: ShortcutSlot? = nil, sourceURL: String? = nil, sourceTitle: String? = nil) {
    let tagSource = shortcutSlot?.tags ?? ShortcutSlotStore.taskTag
    guard let content = normalizedTaskContent(expandedVariables(todoText), tags: tagSource, sourceURL: sourceURL, sourceTitle: sourceTitle) else { return }
    Log.write("sendTodo:\(content)")
    let task = formattedTask(from: content, tags: tagSource, sourceURL: sourceURL, sourceTitle: sourceTitle)
    Log.write("sendTodoTask:\(task)")
    if shortcutSlot?.engine == .obsidian {
        writeObsidianTask(task, shortcutSlot: shortcutSlot)
        return
    }
    if let sectionTarget = captureSectionTarget(from: tagSource),
       writeNotePlanTask(task, shortcutSlot: shortcutSlot, sectionTarget: sectionTarget) {
        return
    }
    let openNoteValue = ShortcutSlotStore.openNote ? "yes" : "no"
    let noteTarget = notePlanTarget(for: shortcutSlot)
    Log.write("sendTodoTarget:\(noteTarget)")
    let targetPrefix = noteTarget.isEmpty ? "" : "\(noteTarget)&"
    let target = "noteplan://x-callback-url/addText?\(targetPrefix)text=\(encode(task))&mode=append&openNote=\(openNoteValue)"
    if let url = URL(string: target) {
        NSWorkspace.shared.open(url)
    }
}

// MARK: - ObsidianWriter

func writeObsidianTask(_ task: String, shortcutSlot: ShortcutSlot?) {
    guard let shortcutSlot else { return }
    let note = expandedVariables(shortcutSlot.noteReference).trimmingCharacters(in: .whitespacesAndNewlines)
    let folder = expandedVariables(shortcutSlot.folder).trimmingCharacters(in: .whitespacesAndNewlines)
    let fileURL: URL
    if note.hasPrefix("/") {
        fileURL = URL(fileURLWithPath: note)
    } else if folder.hasPrefix("/") {
        fileURL = URL(fileURLWithPath: folder).appendingPathComponent(note)
    } else {
        Log.write("obsidian:error:no-absolute-target")
        NSSound.beep()
        return
    }

    let finalURL = fileURL.pathExtension.isEmpty ? fileURL.appendingPathExtension("md") : fileURL
    do {
        try FileManager.default.createDirectory(at: finalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let prefix: String
        if FileManager.default.fileExists(atPath: finalURL.path),
           let data = try? Data(contentsOf: finalURL),
           !data.isEmpty,
           data.last != 10 {
            prefix = "\n"
        } else {
            prefix = ""
        }
        let payload = "\(prefix)\(task)\n"
        if FileManager.default.fileExists(atPath: finalURL.path) {
            let handle = try FileHandle(forWritingTo: finalURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(payload.utf8))
        } else {
            try Data(payload.utf8).write(to: finalURL, options: .atomic)
        }
        Log.write("obsidian:write:\(finalURL.path)")
        if ShortcutSlotStore.openNote {
            NSWorkspace.shared.open(finalURL)
        }
    } catch {
        Log.write("obsidian:error:\(error.localizedDescription)")
        NSSound.beep()
    }
}

// MARK: - NotePlanWriter (ecriture par section, x-callback, resolution de cible)

private func captureSectionTarget(from config: String) -> (name: String, position: CaptureSectionPosition)? {
    guard let section = captureSectionName(from: config) else { return nil }
    let tokens = configTokens(config)
    let position: CaptureSectionPosition
    if tokens.contains("!sectiontop") || tokens.contains("!topsection") || tokens.contains("!hautsection") {
        position = .sectionTop
    } else if tokens.contains("!beforesection") || tokens.contains("!avantsection") {
        position = .beforeSection
    } else if tokens.contains("!aftersection") || tokens.contains("!apressection") || tokens.contains("!aprèssection") {
        position = .afterSection
    } else {
        position = .sectionBottom
    }
    return (section, position)
}

private func captureSectionName(from config: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"\$section\(([^)]{1,120})\)"#, options: [.caseInsensitive]) else {
        return nil
    }
    let range = NSRange(config.startIndex..<config.endIndex, in: config)
    guard let match = regex.firstMatch(in: config, range: range),
          let valueRange = Range(match.range(at: 1), in: config) else {
        return nil
    }
    let value = String(config[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}

private func writeNotePlanTask(_ task: String, shortcutSlot: ShortcutSlot?, sectionTarget: (name: String, position: CaptureSectionPosition)) -> Bool {
    guard let target = notePlanFileTarget(for: shortcutSlot) else {
        Log.write("noteplan-section:error:no-target")
        NSSound.beep()
        return false
    }
    do {
        try FileManager.default.createDirectory(at: target.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let existing = (try? String(contentsOf: target.fileURL, encoding: .utf8)) ?? ""
        let updated = markdownByInserting(task: task, in: existing, section: sectionTarget.name, position: sectionTarget.position)
        try updated.write(to: target.fileURL, atomically: true, encoding: .utf8)
        Log.write("noteplan-section:write:\(target.relativePath):\(sectionTarget.name)")
        if ShortcutSlotStore.openNote {
            openNotePlanFile(relativePath: target.relativePath)
        }
        return true
    } catch {
        Log.write("noteplan-section:error:\(error.localizedDescription)")
        NSSound.beep()
        return false
    }
}

private func markdownByInserting(task: String, in markdown: String, section: String, position: CaptureSectionPosition) -> String {
    var lines = markdown.components(separatedBy: "\n")
    let hadTrailingNewline = markdown.hasSuffix("\n")
    let taskLines = task.components(separatedBy: "\n")
    if let heading = headingRange(named: section, in: lines) {
        let insertionIndex: Int
        switch position {
        case .beforeSection:
            insertionIndex = heading.start
        case .sectionTop:
            insertionIndex = min(heading.start + 1, lines.count)
        case .sectionBottom, .afterSection:
            insertionIndex = heading.end
        }
        lines.insert(contentsOf: taskLines, at: insertionIndex)
        if insertionIndex < lines.count - taskLines.count,
           lines[insertionIndex + taskLines.count].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            lines.insert("", at: insertionIndex + taskLines.count)
        }
    } else {
        if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            lines.append("")
        }
        lines.append("## \(section)")
        lines.append(contentsOf: taskLines)
    }
    let output = lines.joined(separator: "\n")
    return hadTrailingNewline || output.hasSuffix("\n") ? output : output + "\n"
}

private func headingRange(named section: String, in lines: [String]) -> (start: Int, end: Int)? {
    let wanted = normalizedSectionTitle(section)
    for index in lines.indices {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("#") else { continue }
        let level = line.prefix { $0 == "#" }.count
        let title = normalizedSectionTitle(String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces))
        guard title == wanted else { continue }
        var end = lines.count
        for next in lines.index(after: index)..<lines.count {
            let nextLine = lines[next].trimmingCharacters(in: .whitespaces)
            guard nextLine.hasPrefix("#") else { continue }
            let nextLevel = nextLine.prefix { $0 == "#" }.count
            if nextLevel <= level {
                end = next
                break
            }
        }
        return (index, end)
    }
    return nil
}

private func normalizedSectionTitle(_ value: String) -> String {
    value
        .trimmingCharacters(in: CharacterSet(charactersIn: "# \t\r\n"))
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
        .lowercased()
}

private func notePlanFileTarget(for shortcutSlot: ShortcutSlot?) -> (relativePath: String, fileURL: URL)? {
    guard let root = normalizedNotePlanBaseRoot() else { return nil }
    let relativePath: String
    guard let shortcutSlot else {
        relativePath = todayNotePlanRelativePath()
        return (relativePath, root.appendingPathComponent(relativePath))
    }
    switch shortcutSlot.destination {
    case .standard, .today:
        relativePath = todayNotePlanRelativePath()
    case .noteTitle:
        let noteTitle = expandedVariables(shortcutSlot.noteReference).trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = expandedVariables(shortcutSlot.folder).trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = joinedNotePath(folder: folder, note: noteTitle)
        if !joined.isEmpty {
            relativePath = notePlanRelativePath(joined)
        } else if let found = notePathMatchingTitleForCapture(noteTitle, notesRoot: root.appendingPathComponent("Notes")) {
            relativePath = notePlanRelativePath(found)
        } else {
            relativePath = notePlanRelativePath(noteTitle.hasSuffix(".md") ? noteTitle : "\(noteTitle).md")
        }
    case .notePath:
        let note = expandedVariables(shortcutSlot.noteReference).trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = expandedVariables(shortcutSlot.folder).trimmingCharacters(in: .whitespacesAndNewlines)
        relativePath = notePlanRelativePath(joinedNotePath(folder: folder, note: note))
    }
    return (relativePath, root.appendingPathComponent(relativePath))
}

private func normalizedNotePlanBaseRoot() -> URL? {
    guard let selected = ShortcutSlotStore.selectedNotesRoot()?.standardizedFileURL else { return nil }
    if selected.lastPathComponent == "Notes" {
        let parent = selected.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parent.appendingPathComponent("Calendar").path) {
            return parent
        }
    }
    return selected
}

private func todayNotePlanRelativePath(date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return "Calendar/\(formatter.string(from: date)).md"
}

private func notePlanRelativePath(_ path: String) -> String {
    let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
    if clean.hasPrefix("Calendar/") || clean.hasPrefix("Notes/") {
        return clean
    }
    return "Notes/\(clean)"
}

private func notePathMatchingTitleForCapture(_ title: String, notesRoot: URL) -> String? {
    let cleanTitle = title.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n#[]"))
    guard !cleanTitle.isEmpty else { return nil }
    let lowerTitle = cleanTitle.lowercased()
    let exactFileName = cleanTitle.hasSuffix(".md") ? cleanTitle : "\(cleanTitle).md"
    let matches = noteMarkdownFiles(under: notesRoot).compactMap { url -> String? in
        let relativePath = url.path.replacingOccurrences(of: notesRoot.path + "/", with: "")
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

private func openNotePlanFile(relativePath: String) {
    let target: String
    if relativePath.hasPrefix("Calendar/") {
        target = "noteDate=today"
    } else {
        let notePath = relativePath.hasPrefix("Notes/")
            ? String(relativePath.dropFirst("Notes/".count))
            : relativePath
        target = "notePath=\(encode(notePath))&fileName=\(encode(notePath))"
    }
    if let url = URL(string: "noteplan://x-callback-url/openNote?\(target)") {
        NSWorkspace.shared.open(url)
    }
}

private func notePlanTarget(for shortcutSlot: ShortcutSlot?) -> String {
    guard let shortcutSlot else { return "noteDate=today" }

    switch shortcutSlot.destination {
    case .standard, .today:
        // "Standard" traite comme "Aujourd'hui" ici, coherent avec
        // notePlanFileTarget ci-dessus — meme correction que celle
        // appliquee dans NotePlanURLDrop/main.swift (commit dfc03ca).
        return "noteDate=today"
    case .noteTitle:
        let noteTitle = expandedVariables(shortcutSlot.noteReference).trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = expandedVariables(shortcutSlot.folder).trimmingCharacters(in: .whitespacesAndNewlines)
        if !folder.isEmpty {
            let path = joinedNotePath(folder: folder, note: noteTitle)
            return path.isEmpty ? "noteDate=today" : "notePath=\(encode(path))&fileName=\(encode(path))"
        }
        return noteTitle.isEmpty ? "noteDate=today" : "noteTitle=\(encode(noteTitle))"
    case .notePath:
        let note = expandedVariables(shortcutSlot.noteReference).trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = expandedVariables(shortcutSlot.folder).trimmingCharacters(in: .whitespacesAndNewlines)
        let path = joinedNotePath(folder: folder, note: note)
        return path.isEmpty ? "noteDate=today" : "notePath=\(encode(path))&fileName=\(encode(path))"
    }
}

private func joinedNotePath(folder: String, note: String) -> String {
    let cleanFolder = folder.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
    let cleanNote = note.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
    if cleanFolder.isEmpty {
        return cleanNote
    }
    if cleanNote.isEmpty {
        return cleanFolder
    }
    return "\(cleanFolder)/\(cleanNote)"
}

// MARK: - Formatage de la ligne de tache

private func stripLeadingCheckbox(_ value: String) -> String {
    var content = value
    let taskPrefixPattern = #"^[-*]\s+\[[ xX]\]\s+"#
    while let range = content.range(of: taskPrefixPattern, options: .regularExpression) {
        content.removeSubrange(range)
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return content
}

private func formattedTask(from content: String, tags: String, sourceURL: String? = nil, sourceTitle: String? = nil) -> String {
    let expandedConfig = expandedVariables(tags)
    // Note: pas d'enrichissement automatique par CaptureRulesStore/llmTags
    // ici (cf. commentaire d'en-tete de fichier) — seuls les tags saisis
    // dans Tag & Config sont utilises.
    let tag = normalizedTags(expandedConfig)
    let prefix = captureLinePrefix(from: expandedConfig)
    let priority = capturePriority(from: expandedConfig)
    let schedule = captureSchedule(from: expandedConfig)
    var lines = content.components(separatedBy: .newlines)
    while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
        lines.removeFirst()
    }
    while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
        lines.removeLast()
    }

    guard let first = lines.first else {
        return emptyCaptureLine(prefix: prefix, tags: tag, priority: priority, schedule: schedule)
    }
    let firstLine = first.trimmingCharacters(in: .whitespacesAndNewlines)

    var continuation = lines.dropFirst().map { line -> String in
        line.isEmpty ? ">" : "> \(stripLeadingCheckbox(line))"
    }
    if let sourceLine = sourceContinuationLine(sourceURL, title: sourceTitle, content: content) {
        continuation.append(sourceLine)
    }
    let suffix = tag.isEmpty ? "" : " \(tag)"
    return ([captureLine(prefix: prefix, content: firstLine, suffix: suffix, priority: priority, schedule: schedule)] + continuation).joined(separator: "\n")
}

private func captureLinePrefix(from config: String) -> CaptureLinePrefix {
    let tokens = configTokens(config)
    if tokens.contains("!star") || tokens.contains("!bulletstar") || tokens.contains("$mark:*") || tokens.contains("$marker:*") {
        return .star
    }
    if tokens.contains("!plus") || tokens.contains("!bulletplus") || tokens.contains("$mark:+") || tokens.contains("$marker:+") {
        return .plus
    }
    if tokens.contains("!text") || tokens.contains("!plain") || tokens.contains("$mark:text") || tokens.contains("$marker:text") {
        return .plain
    }
    return .task
}

private func configTokens(_ config: String) -> [String] {
    config
        .replacingOccurrences(of: ",", with: " ")
        .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
}

private func normalizedConfigText(_ config: String) -> String {
    config
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        .lowercased()
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: "_", with: "")
}

private func capturePriority(from config: String) -> String {
    for token in configTokens(config) {
        if token.allSatisfy({ $0 == "!" }), (1...5).contains(token.count) {
            return String(repeating: "!", count: token.count)
        }
        if token.hasPrefix("!p"),
           let value = Int(token.dropFirst(2)),
           (1...5).contains(value) {
            return String(repeating: "!", count: value)
        }
        if token.hasPrefix("$prio:") {
            let rawValue = String(token.dropFirst("$prio:".count))
            if rawValue.allSatisfy({ $0 == "!" }), (1...5).contains(rawValue.count) {
                return String(repeating: "!", count: rawValue.count)
            }
            if let value = Int(rawValue), (1...5).contains(value) {
                return String(repeating: "!", count: value)
            }
        }
    }
    return ""
}

private func captureSchedule(from config: String, date: Date = Date()) -> String {
    let normalized = normalizedConfigText(config)
    let aliases: [(keys: [String], offset: () -> Date?)] = [
        (["!demain", "$date:demain", "$date:tomorrow"], { Calendar.current.date(byAdding: .day, value: 1, to: date) }),
        (["!weekend", "!weekend", "$date:weekend"], { upcomingSaturday(from: date) }),
        (["!semainepro", "$date:semainepro", "$date:nextweek"], { nextMonday(from: date) }),
        (["!moisprochain", "$date:moisprochain", "$date:nextmonth"], { firstDayOfNextMonth(from: date) }),
        (["!dans6mois", "!6mois", "$date:dans6mois", "$date:6mois", "$date:6months"], { Calendar.current.date(byAdding: .month, value: 6, to: date) })
    ]
    for alias in aliases {
        if alias.keys.contains(where: { normalized.contains($0.replacingOccurrences(of: "-", with: "")) }),
           let target = alias.offset() {
            return notePlanDateToken(for: target)
        }
    }
    return ""
}

private func upcomingSaturday(from date: Date) -> Date? {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)
    let saturday = 7
    let daysUntilSaturday = (saturday - weekday + 7) % 7
    return calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 0 : daysUntilSaturday, to: date)
}

private func nextMonday(from date: Date) -> Date? {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)
    let monday = 2
    let daysUntilMonday = (monday - weekday + 7) % 7
    return calendar.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: date)
}

private func firstDayOfNextMonth(from date: Date) -> Date? {
    let calendar = Calendar.current
    guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else { return nil }
    return calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))
}

private func notePlanDateToken(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.dateFormat = "yyyy-MM-dd"
    return ">\(formatter.string(from: date))"
}

private func decoratedCaptureContent(_ content: String, priority: String, schedule: String) -> String {
    [schedule, priority, content]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

private func captureLine(prefix: CaptureLinePrefix, content: String, suffix: String, priority: String, schedule: String) -> String {
    let decoratedContent = decoratedCaptureContent(content, priority: priority, schedule: schedule)
    switch prefix {
    case .task:
        return "- [ ] \(decoratedContent)\(suffix)"
    case .star:
        return "* \(decoratedContent)\(suffix)"
    case .plus:
        return "+ \(decoratedContent)\(suffix)"
    case .plain:
        return "\(decoratedContent)\(suffix)"
    }
}

private func emptyCaptureLine(prefix: CaptureLinePrefix, tags: String, priority: String, schedule: String) -> String {
    let decoratedContent = decoratedCaptureContent("", priority: priority, schedule: schedule)
    let suffix = tags.isEmpty ? "" : " \(tags)"
    switch prefix {
    case .task:
        return decoratedContent.isEmpty ? "- [ ]\(suffix)" : "- [ ] \(decoratedContent)\(suffix)"
    case .star:
        return decoratedContent.isEmpty ? "*\(suffix)" : "* \(decoratedContent)\(suffix)"
    case .plus:
        return decoratedContent.isEmpty ? "+\(suffix)" : "+ \(decoratedContent)\(suffix)"
    case .plain:
        return decoratedContent.isEmpty ? tags : "\(decoratedContent)\(suffix)"
    }
}

// MARK: - Lien de source (Ajouter la source / Ajouter le doc)

private func sourceContinuationLine(_ sourceURL: String?, title: String? = nil, content: String) -> String? {
    guard ShortcutSlotStore.includeSource,
          let sourceURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines),
          !contentAlreadyReferencesSource(content, sourceURL: sourceURL),
          let link = markdownLinkForSourceURL(sourceURL, title: title) else {
        return nil
    }
    return "> Source : \(link)"
}

private func markdownLinkForSourceURL(_ value: String, title: String?) -> String? {
    if let webLink = markdownLinkForWebURL(value, title: title) {
        return webLink
    }

    guard ShortcutSlotStore.includeDocumentSource,
          let fileURL = standaloneFileURL(from: value) else {
        return nil
    }
    let label = cleanSourceTitle(title) ?? fileURL.deletingPathExtension().lastPathComponent
    return "[\(escapedMarkdownLinkTitle(label))](\(URL(fileURLWithPath: fileURL.standardizedFileURL.path, isDirectory: isDirectory(fileURL)).absoluteString))"
}

private func cleanSourceTitle(_ value: String?) -> String? {
    let cleaned = value?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: #"(?i)\s+[-–—]\s+(TextEdit|Aperçu|Preview|Pages|Numbers|Keynote|Microsoft Word|Word|PDF Expert)$"#, with: "", options: .regularExpression)
    guard let cleaned, !cleaned.isEmpty, cleaned != "(null)" else { return nil }
    return cleaned
}

private func escapedMarkdownLinkTitle(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "[", with: "\\[")
        .replacingOccurrences(of: "]", with: "\\]")
}

private func contentAlreadyReferencesSource(_ content: String, sourceURL: String) -> Bool {
    if let fileURL = standaloneFileURL(from: sourceURL) {
        let fileURLString = fileURL.absoluteString
        return content.contains(fileURLString) || content.contains(fileURL.path)
    }
    guard let sourceKey = comparableWebURLKey(sourceURL) else {
        return content.contains(sourceURL)
    }
    if content.contains(sourceURL) {
        return true
    }
    return webURLs(in: content).contains { comparableWebURLKey($0) == sourceKey }
}

private func webURLs(in text: String) -> [String] {
    let pattern = #"(?:https?://)?(?:www\.)?[A-Za-z0-9][A-Za-z0-9.-]+\.[A-Za-z]{2,}(?::\d+)?(?:/[^\s<>"'\)]*)?"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        guard let matchRange = Range(match.range, in: text) else { return nil }
        return String(text[matchRange])
    }
}

private func comparableWebURLKey(_ value: String) -> String? {
    guard let normalized = normalizedWebURL(value),
          let components = URLComponents(string: normalized),
          let host = components.host?.lowercased() else {
        return nil
    }
    let canonicalHost = host.replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
    let port = components.port.map { ":\($0)" } ?? ""
    let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
    let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
    return "\(canonicalHost)\(port)\(path)\(query)"
}

private func normalizedWebURL(_ value: String) -> String? {
    let trimmed = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]{}\"'.,;"))
    guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }

    let withScheme = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
        ? trimmed
        : "https://\(trimmed)"
    guard var components = URLComponents(string: withScheme),
          components.scheme?.hasPrefix("http") == true,
          components.host?.contains(".") == true else {
        return nil
    }

    let trackingNames = Set(["_gl", "_gs", "gclid", "gbraid", "wbraid", "fbclid", "msclkid", "yclid"])
    components.queryItems = components.queryItems?.filter { item in
        let name = item.name.lowercased()
        return !name.hasPrefix("utm_") && !trackingNames.contains(name)
    }
    if components.queryItems?.isEmpty == true {
        components.queryItems = nil
    }
    components.fragment = nil
    return components.url?.absoluteString
}

private func markdownLinkForWebURL(_ value: String, title: String? = nil) -> String? {
    guard let normalized = normalizedWebURL(value),
          let url = URL(string: normalized),
          let host = url.host else {
        return nil
    }
    // Note: pas de CaptureRulesStore.metadata(for:) ici (cf. commentaire
    // d'en-tete) — titre devine depuis l'URL si non fourni explicitement.
    let title = cleanSourceTitle(title) ?? webLinkTitle(for: url, host: host)
    let escapedTitle = title
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "[", with: "\\[")
        .replacingOccurrences(of: "]", with: "\\]")
    return "[\(escapedTitle)](\(normalized))"
}

private func webLinkTitle(for url: URL, host: String) -> String {
    let pathTitle = url.deletingPathExtension().lastPathComponent.removingPercentEncoding ?? ""
    let cleanPathTitle = pathTitle
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "_", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if !cleanPathTitle.isEmpty, cleanPathTitle != "/" {
        return cleanPathTitle
            .split(separator: " ")
            .map { word in word.prefix(1).uppercased() + word.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    return host
        .replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
        .split(separator: ".")
        .first
        .map { String($0).prefix(1).uppercased() + String($0.dropFirst()) } ?? host
}

// MARK: - Contenu normalise (nettoyage du texte capture avant formatage)

private func normalizedTaskContent(_ value: String, tags: String, sourceURL: String? = nil, sourceTitle: String? = nil) -> String? {
    var content = stripLeadingCheckbox(value.trimmingCharacters(in: .whitespacesAndNewlines))
    guard !content.isEmpty, content != "(null)" else { return nil }

    for tag in normalizedPreferenceTags(expandedVariables(tags)) {
        if content == tag {
            return nil
        }
        if content.hasSuffix(" \(tag)") {
            content.removeLast(tag.count + 1)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    guard !content.isEmpty, content != "(null)" else { return nil }
    if let fileURL = standaloneFileURL(from: content) {
        return fileMarkdownLink(for: fileURL)
    }
    let matchingSourceTitle = comparableWebURLKey(content) == sourceURL.flatMap(comparableWebURLKey) ? sourceTitle : nil
    if let markdownLink = markdownLinkForWebURL(content, title: matchingSourceTitle) {
        return markdownLink
    }
    return content
}

private func fileMarkdownLink(for fileURL: URL) -> String {
    let linkURL = URL(fileURLWithPath: fileURL.standardizedFileURL.path, isDirectory: isDirectory(fileURL))
    let label = fileURL.lastPathComponent.isEmpty ? fileURL.path : fileURL.lastPathComponent
    let escapedLabel = label
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "[", with: "\\[")
        .replacingOccurrences(of: "]", with: "\\]")
    return "[\(escapedLabel)](\(linkURL.absoluteString))"
}

private func standaloneFileURL(from value: String) -> URL? {
    let trimmed = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    guard !trimmed.isEmpty, !trimmed.contains("\n") else { return nil }

    let fileURL: URL
    if trimmed.lowercased().hasPrefix("file://"),
       let url = URL(string: trimmed),
       url.isFileURL {
        fileURL = url
    } else if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
        fileURL = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
    } else {
        return nil
    }

    return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
}

private func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    return isDirectory.boolValue
}

private func normalizedTags(_ value: String, extra: [String] = []) -> String {
    var tags: [String] = []
    var seen = Set<String>()
    for tag in normalizedPreferenceTags(value) + extra {
        let key = tag.lowercased()
        if seen.insert(key).inserted {
            tags.append(tag)
        }
    }
    return tags.joined(separator: " ")
}

private func encode(_ value: String) -> String {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "&+=?#/")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
}
