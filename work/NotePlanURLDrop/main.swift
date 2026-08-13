import AppKit
import ApplicationServices
import Carbon
import Darwin
import Foundation
import UniformTypeIdentifiers

private enum Settings {
    static let codeSignIdentity = "NoteDroppy Local Code Signing"
    static let repositoryURL = "https://github.com/bizc0m/NoteDroppy"
    static let taskTagKey = "taskTag"
    static let openNoteKey = "openNote"
    static let includeSourceKey = "includeSource"
    static let serviceNameKey = "serviceName"
    static let notesRootPathKey = "notesRootPath"
    static let notesRootBookmarkKey = "notesRootBookmark"
    static let shortcutEnabledKey = "shortcutEnabled"
    static let shortcutKeyCodeKey = "shortcutKeyCode"
    static let shortcutModifiersKey = "shortcutModifiers"
    static let didShowFirstLaunchSettingsKey = "didShowFirstLaunchSettings"
    static let shortcutLayoutVersionKey = "shortcutLayoutVersion"
    static let shortcutSlotCount = 10
    static let currentShortcutLayoutVersion = 2

    static var taskTag: String {
        let value = UserDefaults.standard.string(forKey: taskTagKey) ?? "#capture"
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "#capture" : trimmed
    }

    static var openNote: Bool {
        if UserDefaults.standard.object(forKey: openNoteKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: openNoteKey)
    }

    static var includeSource: Bool {
        if UserDefaults.standard.object(forKey: includeSourceKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: includeSourceKey)
    }

    static var serviceName: String {
        let value = UserDefaults.standard.string(forKey: serviceNameKey) ?? "NotePlan : ajouter en tâche"
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "NotePlan : ajouter en tâche" : trimmed
    }

    static var notesRootPath: String {
        let value = UserDefaults.standard.string(forKey: notesRootPathKey) ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func selectedNotesRoot() -> URL? {
        if let data = UserDefaults.standard.data(forKey: notesRootBookmarkKey) {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                if stale {
                    setNotesRoot(url)
                }
                return url
            }
        }

        let path = notesRootPath
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    static func setNotesRoot(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: notesRootPathKey)
        if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: notesRootBookmarkKey)
        }
        UserDefaults.standard.synchronize()
    }

    static var shortcutEnabled: Bool {
        if UserDefaults.standard.object(forKey: shortcutEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: shortcutEnabledKey)
    }

    static var shortcutKeyCode: UInt32 {
        if UserDefaults.standard.object(forKey: shortcutKeyCodeKey) == nil {
            return UInt32(kVK_ANSI_P)
        }
        return UInt32(UserDefaults.standard.integer(forKey: shortcutKeyCodeKey))
    }

    static var shortcutModifiers: UInt32 {
        if UserDefaults.standard.object(forKey: shortcutModifiersKey) == nil {
            return UInt32(controlKey | optionKey | cmdKey)
        }
        let raw = UInt32(UserDefaults.standard.integer(forKey: shortcutModifiersKey))
        let allowedCarbon = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        if raw != 0, raw & ~allowedCarbon == 0 {
            return raw
        }

        let converted = carbonModifiers(fromRawNSEventFlags: UInt(raw))
        if converted != 0 {
            UserDefaults.standard.set(Int(converted), forKey: shortcutModifiersKey)
            return converted
        }
        return UInt32(controlKey | optionKey | cmdKey)
    }

    static var shortcutDisplay: String {
        shortcutSlot(1).combo.display
    }

    static func shortcutSlot(_ index: Int) -> ShortcutSlot {
        let enabledKey = "shortcutSlot\(index).enabled"
        let keyCodeKey = "shortcutSlot\(index).keyCode"
        let modifiersKey = "shortcutSlot\(index).modifiers"
        let destinationKey = "shortcutSlot\(index).destination"
        let engineKey = "shortcutSlot\(index).engine"
        let noteKey = "shortcutSlot\(index).note"
        let folderKey = "shortcutSlot\(index).folder"
        let tagsKey = "shortcutSlot\(index).tags"

        let defaultCombo = defaultShortcutCombo(index)
        let enabled: Bool
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            enabled = index == 1 ? shortcutEnabled : false
        } else {
            enabled = UserDefaults.standard.bool(forKey: enabledKey)
        }

        let keyCode = UserDefaults.standard.object(forKey: keyCodeKey) == nil
            ? defaultCombo.keyCode
            : UInt32(UserDefaults.standard.integer(forKey: keyCodeKey))
        let rawModifiers = UserDefaults.standard.object(forKey: modifiersKey) == nil
            ? defaultCombo.carbonModifiers
            : UInt32(UserDefaults.standard.integer(forKey: modifiersKey))
        let note = UserDefaults.standard.string(forKey: noteKey) ?? ""
        let folder = UserDefaults.standard.string(forKey: folderKey) ?? ""
        let tags = UserDefaults.standard.string(forKey: tagsKey) ?? (index == 1 ? taskTag : "#capture")
        let savedDestination = UserDefaults.standard.string(forKey: destinationKey)
            .flatMap { ShortcutDestination(rawValue: $0) }
        let destination = Settings.validDestination(savedDestination ?? (index == 1 ? .today : .standard), for: index)
        let engine = UserDefaults.standard.string(forKey: engineKey)
            .flatMap { ShortcutEngine(rawValue: $0) } ?? .notePlan

        return ShortcutSlot(
            index: index,
            enabled: enabled,
            combo: KeyCombo(keyCode: keyCode, carbonModifiers: normalizedCarbonModifiers(rawModifiers)),
            engine: engine,
            destination: destination,
            noteReference: note.trimmingCharacters(in: .whitespacesAndNewlines),
            folder: folder.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func setShortcutSlot(_ slot: ShortcutSlot) {
        UserDefaults.standard.set(slot.enabled, forKey: "shortcutSlot\(slot.index).enabled")
        UserDefaults.standard.set(Int(slot.combo.keyCode), forKey: "shortcutSlot\(slot.index).keyCode")
        UserDefaults.standard.set(Int(slot.combo.carbonModifiers), forKey: "shortcutSlot\(slot.index).modifiers")
        UserDefaults.standard.set(slot.engine.rawValue, forKey: "shortcutSlot\(slot.index).engine")
        let destination = Settings.validDestination(slot.destination, for: slot.index)
        UserDefaults.standard.set(destination.rawValue, forKey: "shortcutSlot\(slot.index).destination")
        UserDefaults.standard.set(slot.noteReference, forKey: "shortcutSlot\(slot.index).note")
        UserDefaults.standard.set(slot.folder, forKey: "shortcutSlot\(slot.index).folder")
        UserDefaults.standard.set(slot.tags, forKey: "shortcutSlot\(slot.index).tags")
        if slot.index == 1 {
            UserDefaults.standard.set(slot.enabled, forKey: shortcutEnabledKey)
            UserDefaults.standard.set(Int(slot.combo.keyCode), forKey: shortcutKeyCodeKey)
            UserDefaults.standard.set(Int(slot.combo.carbonModifiers), forKey: shortcutModifiersKey)
            UserDefaults.standard.set(slot.tags.isEmpty ? "#capture" : slot.tags, forKey: taskTagKey)
        }
        UserDefaults.standard.synchronize()
    }

    static func allShortcutSlots() -> [ShortcutSlot] {
        (1...shortcutSlotCount).map { shortcutSlot($0) }
    }

    static func destinations(forShortcut index: Int) -> [ShortcutDestination] {
        index == 1 ? ShortcutDestination.allCases : ShortcutDestination.allCases.filter { $0 != .today }
    }

    static func validDestination(_ destination: ShortcutDestination, for index: Int) -> ShortcutDestination {
        index == 1 || destination != .today ? destination : .standard
    }

    static func defaultShortcutCombo(_ index: Int) -> KeyCombo {
        let codes: [UInt32] = [
            UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3), UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5),
            UInt32(kVK_ANSI_6), UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9), UInt32(kVK_ANSI_0)
        ]
        return KeyCombo(keyCode: codes[max(0, min(index - 1, codes.count - 1))], carbonModifiers: UInt32(controlKey | optionKey | cmdKey))
    }

    static func migrateShortcutLayoutIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: shortcutLayoutVersionKey) < currentShortcutLayoutVersion else { return }

        let legacyCodes: [UInt32] = [
            UInt32(kVK_ANSI_P), UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3), UInt32(kVK_ANSI_4),
            UInt32(kVK_ANSI_5), UInt32(kVK_ANSI_6), UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9)
        ]
        let newCodes: [UInt32] = [
            UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3), UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5),
            UInt32(kVK_ANSI_6), UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9), UInt32(kVK_ANSI_0)
        ]
        let defaultModifiers = UInt32(controlKey | optionKey | cmdKey)

        for index in 1...shortcutSlotCount {
            let keyCodeKey = "shortcutSlot\(index).keyCode"
            let modifiersKey = "shortcutSlot\(index).modifiers"
            let hasKey = defaults.object(forKey: keyCodeKey) != nil
            let storedKey = hasKey ? UInt32(defaults.integer(forKey: keyCodeKey)) : legacyCodes[index - 1]
            let storedModifiers = defaults.object(forKey: modifiersKey) == nil
                ? defaultModifiers
                : UInt32(defaults.integer(forKey: modifiersKey))
            if storedKey == legacyCodes[index - 1], normalizedCarbonModifiers(storedModifiers) == defaultModifiers {
                defaults.set(Int(newCodes[index - 1]), forKey: keyCodeKey)
                defaults.set(Int(defaultModifiers), forKey: modifiersKey)
            }
        }

        defaults.set(Int(newCodes[0]), forKey: shortcutKeyCodeKey)
        defaults.set(Int(defaultModifiers), forKey: shortcutModifiersKey)
        defaults.set(currentShortcutLayoutVersion, forKey: shortcutLayoutVersionKey)
        defaults.synchronize()
    }
}

struct ShortcutSlot {
    let index: Int
    var enabled: Bool
    var combo: KeyCombo
    var engine: ShortcutEngine
    var destination: ShortcutDestination
    var noteReference: String
    var folder: String
    var tags: String
}

struct PreferencesFile: Codable {
    var version: Int
    var openNote: Bool
    var includeSource: Bool?
    var serviceName: String
    var defaultTags: String
    var notesRootPath: String?
    var shortcuts: [ShortcutSlotFile]

    static func current() -> PreferencesFile {
        PreferencesFile(
            version: 1,
            openNote: Settings.openNote,
            includeSource: Settings.includeSource,
            serviceName: Settings.serviceName,
            defaultTags: Settings.taskTag,
            notesRootPath: Settings.notesRootPath,
            shortcuts: Settings.allShortcutSlots().map(ShortcutSlotFile.init(slot:))
        )
    }

    func apply() {
        UserDefaults.standard.set(openNote, forKey: Settings.openNoteKey)
        UserDefaults.standard.set(includeSource ?? true, forKey: Settings.includeSourceKey)
        UserDefaults.standard.set(serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "NotePlan : ajouter en tâche" : serviceName, forKey: Settings.serviceNameKey)
        UserDefaults.standard.set(defaultTags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "#capture" : defaultTags, forKey: Settings.taskTagKey)
        let trimmedNotesRoot = (notesRootPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotesRoot.isEmpty {
            Settings.setNotesRoot(URL(fileURLWithPath: trimmedNotesRoot))
        }
        for shortcut in shortcuts.prefix(Settings.shortcutSlotCount) {
            Settings.setShortcutSlot(shortcut.slot)
        }
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}

struct ShortcutSlotFile: Codable {
    var index: Int
    var enabled: Bool
    var shortcut: String
    var keyCode: UInt32
    var modifiers: UInt32
    var engine: ShortcutEngine
    var destination: ShortcutDestination
    var folder: String
    var notePath: String
    var tags: [String]

    enum CodingKeys: String, CodingKey {
        case index, enabled, shortcut, keyCode, modifiers, engine, destination, folder, notePath, tags
    }

    init(slot: ShortcutSlot) {
        index = slot.index
        enabled = slot.enabled
        shortcut = shortcutString(from: slot.combo)
        keyCode = slot.combo.keyCode
        modifiers = slot.combo.carbonModifiers
        engine = slot.engine
        destination = slot.destination
        folder = slot.folder
        notePath = slot.noteReference
        tags = normalizedPreferenceTags(slot.tags)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        shortcut = (try? container.decode(String.self, forKey: .shortcut)) ?? ""
        keyCode = try container.decode(UInt32.self, forKey: .keyCode)
        modifiers = try container.decode(UInt32.self, forKey: .modifiers)
        engine = (try? container.decode(ShortcutEngine.self, forKey: .engine)) ?? .notePlan
        destination = try container.decode(ShortcutDestination.self, forKey: .destination)
        folder = (try? container.decode(String.self, forKey: .folder)) ?? ""
        notePath = (try? container.decode(String.self, forKey: .notePath)) ?? ""
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
    }

    var slot: ShortcutSlot {
        ShortcutSlot(
            index: max(1, min(index, Settings.shortcutSlotCount)),
            enabled: enabled,
            combo: KeyCombo(keyCode: keyCode, carbonModifiers: normalizedCarbonModifiers(modifiers)),
            engine: engine,
            destination: destination,
            noteReference: notePath,
            folder: folder,
            tags: tags.joined(separator: ", ")
        )
    }
}

enum ShortcutEngine: String, CaseIterable, Codable {
    case notePlan
    case obsidian

    var title: String {
        switch self {
        case .notePlan: return "NotePlan"
        case .obsidian: return "Obsidian beta"
        }
    }
}

enum ShortcutDestination: String, CaseIterable {
    case standard
    case today
    case noteTitle
    case notePath

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .today: return "Aujourd'hui (NotePlan)"
        case .noteTitle: return "Note nommée"
        case .notePath: return "Chemin de note"
        }
    }

    var acceptsTarget: Bool {
        switch self {
        case .noteTitle, .notePath:
            return true
        case .standard, .today:
            return false
        }
    }
}

extension ShortcutDestination: Codable {}

struct NoteSearchResult {
    let title: String
    let relativePath: String
    let folder: String
    let tags: [String]
    let modifiedAt: Date
}

private func expandedVariables(_ value: String, date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    func format(_ template: String) -> String {
        formatter.dateFormat = template
        return formatter.string(from: date)
    }
    return value
        .replacingOccurrences(of: "$datetime", with: format("yyyy-MM-dd HH:mm"))
        .replacingOccurrences(of: "$date", with: format("yyyy-MM-dd"))
        .replacingOccurrences(of: "$day", with: format("EEEE"))
        .replacingOccurrences(of: "$time", with: format("HH:mm"))
        .replacingOccurrences(of: "$month", with: format("yyyy-MM"))
        .replacingOccurrences(of: "$year", with: format("yyyy"))
}

private func shortcutString(from combo: KeyCombo) -> String {
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

private func normalizedPreferenceTags(_ value: String) -> [String] {
    value
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map { $0.hasPrefix("#") || $0.hasPrefix("@") ? $0 : "#\($0)" }
}

private func notePlanNotesRoots() -> [URL] {
    guard let selectedRoot = Settings.selectedNotesRoot() else { return [] }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: selectedRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        return []
    }
    return [selectedRoot]
}

private func loadNoteSearchResults() -> [NoteSearchResult] {
    var seen = Set<String>()
    var results: [NoteSearchResult] = []

    for root in notePlanNotesRoots() {
        let scopedAccess = root.startAccessingSecurityScopedResource()
        defer {
            if scopedAccess {
                root.stopAccessingSecurityScopedResource()
            }
        }
        writeDebugLog("search:index:root:start:\(root.path)")
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
        writeDebugLog("search:index:root:done:\(root.path):\(results.count)")
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

private func centeredWindow(_ title: String, width: CGFloat, height: CGFloat, style: NSWindow.StyleMask = [.titled, .closable, .resizable]) -> NSWindow {
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

private func writeDebugLog(_ message: String) {
    let line = "\(Date()) \(message)\n"
    let url = URL(fileURLWithPath: "/tmp/NotePlanURLDrop.log")
    guard let data = line.data(using: .utf8) else { return }
    if FileManager.default.fileExists(atPath: url.path),
       let handle = try? FileHandle(forWritingTo: url) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: url)
    }
}

private func styleFillableField(_ field: NSTextField) {
    field.drawsBackground = true
    field.backgroundColor = NSColor.controlBackgroundColor.blended(withFraction: 0.16, of: .white) ?? .controlBackgroundColor
    field.textColor = .labelColor
}

private func formLabel(_ title: String, width: CGFloat = 142) -> NSTextField {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.widthAnchor.constraint(equalToConstant: width).isActive = true
    return label
}

private func horizontalRow(spacing: CGFloat = 8) -> NSStackView {
    let row = NSStackView()
    row.orientation = .horizontal
    row.spacing = spacing
    row.alignment = .centerY
    row.translatesAutoresizingMaskIntoConstraints = false
    return row
}

struct KeyCombo {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    var display: String {
        let parts = modifierDisplay + [keyDisplay]
        return parts.joined()
    }

    private var modifierDisplay: [String] {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        return parts
    }

    private var keyDisplay: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Grave: return "`"
        case kVK_Space: return "Espace"
        case kVK_Return: return "Retour"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_ANSI_Keypad0: return "Num0"
        case kVK_ANSI_Keypad1: return "Num1"
        case kVK_ANSI_Keypad2: return "Num2"
        case kVK_ANSI_Keypad3: return "Num3"
        case kVK_ANSI_Keypad4: return "Num4"
        case kVK_ANSI_Keypad5: return "Num5"
        case kVK_ANSI_Keypad6: return "Num6"
        case kVK_ANSI_Keypad7: return "Num7"
        case kVK_ANSI_Keypad8: return "Num8"
        case kVK_ANSI_Keypad9: return "Num9"
        case kVK_ANSI_KeypadDecimal: return "Num."
        case kVK_ANSI_KeypadMultiply: return "Num*"
        case kVK_ANSI_KeypadPlus: return "Num+"
        case kVK_ANSI_KeypadMinus: return "Num-"
        case kVK_ANSI_KeypadDivide: return "Num/"
        case kVK_ANSI_KeypadEquals: return "Num="
        case kVK_ANSI_KeypadEnter: return "NumRetour"
        case kVK_ANSI_KeypadClear: return "NumEffacer"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_ForwardDelete: return "Suppr"
        case kVK_Delete: return "Effacer"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "#\(keyCode)"
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    fileprivate var onChange: ((KeyCombo) -> Void)?
    private var localMonitor: Any?
    private var isRecording = false
    private var combo: KeyCombo

    init(combo: KeyCombo = Settings.defaultShortcutCombo(1)) {
        self.combo = combo
        super.init(frame: .zero)
        title = combo.display
        bezelStyle = .rounded
        target = self
        action = #selector(beginRecording)
    }

    required init?(coder: NSCoder) {
        self.combo = Settings.defaultShortcutCombo(1)
        super.init(coder: coder)
    }

    deinit {
        stopRecording(updateTitle: false)
    }

    @objc private func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        title = "Tape le nouveau raccourci..."
        NotificationCenter.default.post(name: .shortcutRecordingBegan, object: nil)
        window?.makeFirstResponder(self)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return nil
        }
    }

    override func keyDown(with event: NSEvent) {
        record(event)
    }

    private func record(_ event: NSEvent) {
        guard isRecording else { return }
        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            NSSound.beep()
            title = "Ajoute ⌃ ⌥ ⇧ ou ⌘"
            return
        }
        guard event.keyCode != UInt16(kVK_ANSI_C) || modifiers != UInt32(cmdKey) else {
            NSSound.beep()
            title = "⌘C est réservé"
            return
        }
        guard !isReservedMenuShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers) else {
            NSSound.beep()
            title = "Raccourci réservé par l'app"
            return
        }
        let combo = KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
        setCombo(combo)
        onChange?(combo)
        stopRecording(updateTitle: false)
    }

    fileprivate func setCombo(_ combo: KeyCombo) {
        self.combo = combo
        title = combo.display
    }

    private func stopRecording(updateTitle: Bool = true) {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if isRecording {
            NotificationCenter.default.post(name: .shortcutRecordingEnded, object: nil)
        }
        isRecording = false
        if updateTitle {
            title = combo.display
        }
    }
}

private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    let normalized = flags.intersection(.deviceIndependentFlagsMask)
    var result: UInt32 = 0
    if normalized.contains(.control) { result |= UInt32(controlKey) }
    if normalized.contains(.option) { result |= UInt32(optionKey) }
    if normalized.contains(.shift) { result |= UInt32(shiftKey) }
    if normalized.contains(.command) { result |= UInt32(cmdKey) }
    return result
}

private func carbonModifiers(fromRawNSEventFlags raw: UInt) -> UInt32 {
    carbonModifiers(from: NSEvent.ModifierFlags(rawValue: raw))
}

private func normalizedCarbonModifiers(_ raw: UInt32) -> UInt32 {
    let allowedCarbon = UInt32(controlKey | optionKey | shiftKey | cmdKey)
    if raw != 0, raw & ~allowedCarbon == 0 {
        return raw
    }
    let converted = carbonModifiers(fromRawNSEventFlags: UInt(raw))
    return converted == 0 ? UInt32(controlKey | optionKey | cmdKey) : converted
}

private func isReservedMenuShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
    let commandOnly = UInt32(cmdKey)
    let commandShift = UInt32(cmdKey | shiftKey)
    let commandOption = UInt32(cmdKey | optionKey)

    if keyCode == UInt32(kVK_ANSI_Q), modifiers & UInt32(cmdKey) != 0 {
        return true
    }
    if keyCode == UInt32(kVK_ANSI_Comma), modifiers & UInt32(cmdKey) != 0 {
        return true
    }
    if keyCode == UInt32(kVK_ANSI_Slash), modifiers == commandOnly || modifiers == commandShift || modifiers == commandOption {
        return true
    }
    return false
}

final class ShortcutTargetField: NSTextField {
    var acceptsDrop = true
    var onDropTarget: ((ShortcutTarget) -> Bool)?
    var onPasteTarget: (() -> Void)?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        isEditable = true
        isSelectable = true
        lineBreakMode = .byTruncatingHead
        registerForDraggedTypes(shortcutDropPasteboardTypes)
        configurePasteMenu()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        isEditable = true
        isSelectable = true
        lineBreakMode = .byTruncatingHead
        registerForDraggedTypes(shortcutDropPasteboardTypes)
        configurePasteMenu()
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if acceptsDrop,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            pasteTargetFromField(nil)
            return
        }
        super.keyDown(with: event)
    }

    @objc func paste(_ sender: Any?) {
        if acceptsDrop {
            pasteTargetFromField(sender)
        }
    }

    @objc private func pasteTargetFromField(_ sender: Any?) {
        guard acceptsDrop else {
            NSSound.beep()
            return
        }
        writeDebugLog("shortcut-target:paste-field:\(pasteboardPreview(from: NSPasteboard.general))")
        onPasteTarget?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        writeDebugLog("shortcut-drop:field:entered:\(pasteboardDebugDescription(sender.draggingPasteboard))")
        return dragOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderWidth = 0
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        acceptsDrop && shortcutTarget(from: sender.draggingPasteboard) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        writeDebugLog("shortcut-drop:field:perform:\(pasteboardDebugDescription(sender.draggingPasteboard))")
        layer?.borderWidth = 0
        guard acceptsDrop, let target = shortcutTarget(from: sender.draggingPasteboard) else {
            NSSound.beep()
            return false
        }
        return onDropTarget?(target) ?? false
    }

    private func configurePasteMenu() {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Coller cible", action: #selector(pasteTargetFromField(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        self.menu = menu
        toolTip = "Déposer une note .md, ou cliquer ici puis Cmd+V depuis Finder/NotePlan"
    }

    private func dragOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        guard acceptsDrop, shortcutTarget(from: sender.draggingPasteboard) != nil else {
            layer?.borderWidth = 0
            return NSDragOperation()
        }
        layer?.cornerRadius = 5
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        return preferredDragOperation(from: sender.draggingSourceOperationMask)
    }
}

final class ShortcutSlotDropStack: NSStackView {
    var acceptsDrop = true
    var onDropTarget: ((ShortcutTarget) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(shortcutDropPasteboardTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(shortcutDropPasteboardTypes)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        writeDebugLog("shortcut-drop:row:entered:\(pasteboardDebugDescription(sender.draggingPasteboard))")
        return acceptsDrop && shortcutTarget(from: sender.draggingPasteboard) != nil
            ? preferredDragOperation(from: sender.draggingSourceOperationMask)
            : NSDragOperation()
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        acceptsDrop && shortcutTarget(from: sender.draggingPasteboard) != nil
            ? preferredDragOperation(from: sender.draggingSourceOperationMask)
            : NSDragOperation()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        acceptsDrop && shortcutTarget(from: sender.draggingPasteboard) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        writeDebugLog("shortcut-drop:row:perform:\(pasteboardDebugDescription(sender.draggingPasteboard))")
        guard acceptsDrop, let target = shortcutTarget(from: sender.draggingPasteboard) else {
            NSSound.beep()
            return false
        }
        return onDropTarget?(target) ?? false
    }
}

private let shortcutDropPasteboardTypes: [NSPasteboard.PasteboardType] = [
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

private func preferredDragOperation(from mask: NSDragOperation) -> NSDragOperation {
    for operation in [NSDragOperation.copy, .link, .generic, .move] {
        if mask.contains(operation) {
            return operation
        }
    }
    return .copy
}

private func shortcutTarget(from pasteboard: NSPasteboard) -> ShortcutTarget? {
    let strings = pasteboardStrings(from: pasteboard)
    writeDebugLog("shortcut-target:types:\((pasteboard.types ?? []).map { $0.rawValue }.joined(separator: ","))")

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
        if let url = URL(string: value), url.scheme?.lowercased() == "file" || url.scheme?.lowercased() == "noteplan" {
            return ShortcutTarget(url: url)
        }
    }

    if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
       let url = objects.first(where: { $0.scheme?.lowercased() == "noteplan" }) {
        return ShortcutTarget(url: url)
    }

    if let title = strings.first(where: { !$0.isEmpty }) {
        return ShortcutTarget(rawText: title)
    }

    return nil
}

private func pasteboardFilenames(from pasteboard: NSPasteboard) -> [String] {
    let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    guard let data = pasteboard.data(forType: filenamesType),
          let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    else {
        return []
    }
    return strings(fromPropertyList: plist).filter { FileManager.default.fileExists(atPath: $0) }
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

private func pasteboardPreview(from pasteboard: NSPasteboard) -> String {
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

private func pasteboardDebugDescription(_ pasteboard: NSPasteboard) -> String {
    let types = (pasteboard.types ?? []).map { $0.rawValue }.joined(separator: ",")
    let preview = pasteboardPreview(from: pasteboard)
    return preview.isEmpty ? types : "\(types) :: \(preview)"
}

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

final class ShortcutSlotRow: NSObject, NSTextFieldDelegate {
    let index: Int
    let enabledCheckbox: NSButton
    let recorder: ShortcutRecorderButton
    let enginePopup = NSPopUpButton()
    let destinationPopup = NSPopUpButton()
    let folderField: NSTextField
    let noteField: NSTextField
    let searchButton = NSButton(title: "Rechercher", target: nil, action: nil)
    let targetField = ShortcutTargetField()
    let tagsField: NSTextField
    var onSearch: ((ShortcutSlotRow) -> Void)?
    var onTargetDrop: ((ShortcutSlotRow, ShortcutTarget) -> Bool)?
    var onPasteTarget: ((ShortcutSlotRow) -> Void)?
    var onChange: ((ShortcutSlotRow) -> Void)?
    private var storedCombo: KeyCombo
    private var displayIndex: String { index == 10 ? "0" : "\(index)" }

    init(slot: ShortcutSlot) {
        self.index = slot.index
        self.storedCombo = slot.combo
        self.enabledCheckbox = NSButton(checkboxWithTitle: slot.index == 10 ? "0" : "\(slot.index)", target: nil, action: nil)
        self.recorder = ShortcutRecorderButton(combo: slot.combo)
        self.folderField = NSTextField(string: slot.folder)
        self.noteField = NSTextField(string: slot.noteReference)
        self.tagsField = NSTextField(string: slot.tags)

        super.init()

        enabledCheckbox.state = slot.enabled ? .on : .off
        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(rowChanged)
        ShortcutEngine.allCases.forEach { enginePopup.addItem(withTitle: $0.title) }
        enginePopup.selectItem(withTitle: slot.engine.title)
        enginePopup.target = self
        enginePopup.action = #selector(engineChanged)
        Settings.destinations(forShortcut: slot.index).forEach { destinationPopup.addItem(withTitle: $0.title) }
        destinationPopup.selectItem(withTitle: Settings.validDestination(slot.destination, for: slot.index).title)
        destinationPopup.target = self
        destinationPopup.action = #selector(destinationChanged)
        folderField.placeholderString = "Dossier"
        noteField.placeholderString = placeholder(for: slot.destination)
        targetField.placeholderString = "Déposer depuis Finder une note .md ou coller un lien NotePlan"
        applyTargetDisplay(targetDisplay(for: slot.destination, folder: slot.folder, note: slot.noteReference))
        styleFillableField(targetField)
        targetField.acceptsDrop = true
        targetField.onDropTarget = { [weak self] target in
            guard let self else { return false }
            return self.onTargetDrop?(self, target) ?? false
        }
        targetField.onPasteTarget = { [weak self] in
            guard let self else { return }
            self.onPasteTarget?(self)
        }
        targetField.delegate = self
        targetField.target = self
        targetField.action = #selector(rowChanged)
        searchButton.target = self
        searchButton.action = #selector(searchNote)
        searchButton.bezelStyle = .rounded
        tagsField.placeholderString = "capture, $year, #projet"
        tagsField.delegate = self
        tagsField.target = self
        tagsField.action = #selector(rowChanged)
        [folderField, noteField, tagsField].forEach(styleFillableField)

        [enabledCheckbox, recorder, enginePopup, destinationPopup, folderField, noteField, searchButton, targetField, tagsField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        enabledCheckbox.widthAnchor.constraint(equalToConstant: Self.columnWidths[0]).isActive = true
        recorder.widthAnchor.constraint(equalToConstant: Self.columnWidths[1]).isActive = true
        enginePopup.widthAnchor.constraint(equalToConstant: 112).isActive = true
        destinationPopup.widthAnchor.constraint(equalToConstant: 142).isActive = true
        targetField.widthAnchor.constraint(equalToConstant: 190).isActive = true
        searchButton.widthAnchor.constraint(equalToConstant: 88).isActive = true
        tagsField.widthAnchor.constraint(equalToConstant: Self.columnWidths[3]).isActive = true
        refreshNoteFieldState()
    }

    static let columnSpacing: CGFloat = 12
    static let columnTitles = ["Actif", "Raccourci", "App / Cible", "Tags"]
    static let columnWidths: [CGFloat] = [44, 92, 560, 240]

    static func headerView() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = columnSpacing
        row.alignment = .centerY
        for (title, width) in zip(columnTitles, columnWidths) {
            let label = NSTextField(labelWithString: title)
            label.font = .boldSystemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: width).isActive = true
            row.addArrangedSubview(label)
        }
        return row
    }

    var slot: ShortcutSlot {
        let destination = selectedDestination()
        return ShortcutSlot(
            index: index,
            enabled: enabledCheckbox.state == .on,
            combo: storedCombo,
            engine: selectedEngine(),
            destination: destination,
            noteReference: selectedEngine() == .obsidian || destination.acceptsTarget ? noteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            folder: selectedEngine() == .obsidian || destination.acceptsTarget ? folderField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            tags: tagsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func setCombo(_ combo: KeyCombo) {
        storedCombo = combo
        recorder.setCombo(combo)
    }

    func view() -> NSView {
        let row = ShortcutSlotDropStack()
        row.orientation = .horizontal
        row.spacing = Self.columnSpacing
        row.alignment = .centerY
        row.acceptsDrop = true
        row.onDropTarget = { [weak self] target in
            guard let self else { return false }
            return self.onTargetDrop?(self, target) ?? false
        }
        let targetStack = ShortcutSlotDropStack()
        targetStack.orientation = .horizontal
        targetStack.spacing = 8
        targetStack.alignment = .centerY
        targetStack.acceptsDrop = true
        targetStack.onDropTarget = { [weak self] target in
            guard let self else { return false }
            return self.onTargetDrop?(self, target) ?? false
        }
        targetStack.translatesAutoresizingMaskIntoConstraints = false
        targetStack.widthAnchor.constraint(equalToConstant: Self.columnWidths[2]).isActive = true
        targetStack.addArrangedSubview(enginePopup)
        targetStack.addArrangedSubview(destinationPopup)
        targetStack.addArrangedSubview(targetField)
        targetStack.addArrangedSubview(searchButton)
        row.addArrangedSubview(enabledCheckbox)
        row.addArrangedSubview(recorder)
        row.addArrangedSubview(targetStack)
        row.addArrangedSubview(tagsField)
        return row
    }

    func applySelectedNote(_ result: NoteSearchResult) {
        destinationPopup.selectItem(withTitle: ShortcutDestination.notePath.title)
        folderField.stringValue = result.folder
        noteField.stringValue = URL(fileURLWithPath: result.relativePath).lastPathComponent
        applyTargetDisplay(targetDisplay(for: .notePath, folder: result.folder, note: URL(fileURLWithPath: result.relativePath).lastPathComponent))
        if tagsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tagsField.stringValue = result.tags.prefix(4).joined(separator: ", ")
        }
        refreshNoteFieldState()
    }

    func apply(slot: ShortcutSlot) {
        let destination = Settings.validDestination(slot.destination, for: index)
        enabledCheckbox.state = slot.enabled ? .on : .off
        enabledCheckbox.title = displayIndex
        setCombo(slot.combo)
        enginePopup.selectItem(withTitle: slot.engine.title)
        destinationPopup.removeAllItems()
        Settings.destinations(forShortcut: index).forEach { destinationPopup.addItem(withTitle: $0.title) }
        destinationPopup.selectItem(withTitle: destination.title)
        folderField.stringValue = slot.folder
        noteField.stringValue = slot.noteReference
        applyTargetDisplay(targetDisplay(for: destination, folder: slot.folder, note: slot.noteReference))
        tagsField.stringValue = slot.tags
        noteField.placeholderString = placeholder(for: destination)
        refreshNoteFieldState()
    }

    @objc private func engineChanged() {
        refreshNoteFieldState()
        rowChanged()
    }

    @objc private func destinationChanged() {
        noteField.placeholderString = placeholder(for: selectedDestination())
        refreshNoteFieldState()
        rowChanged()
    }

    @objc private func searchNote() {
        onSearch?(self)
    }

    @objc private func rowChanged() {
        syncTargetTextIfNeeded()
        onChange?(self)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSTextField, field === targetField {
            syncTargetTextIfNeeded()
            applyTargetDisplay(targetDisplay(for: selectedDestination(), folder: folderField.stringValue, note: noteField.stringValue))
        }
        onChange?(self)
    }

    private func selectedEngine() -> ShortcutEngine {
        ShortcutEngine.allCases.first { $0.title == enginePopup.titleOfSelectedItem } ?? .notePlan
    }

    private func selectedDestination() -> ShortcutDestination {
        let selected = ShortcutDestination.allCases.first { $0.title == destinationPopup.titleOfSelectedItem } ?? (index == 1 ? .today : .standard)
        return Settings.validDestination(selected, for: index)
    }

    private func refreshNoteFieldState() {
        let engine = selectedEngine()
        let destination = selectedDestination()
        let acceptsTarget = engine == .obsidian || destination.acceptsTarget
        destinationPopup.isEnabled = engine == .notePlan
        folderField.isEnabled = acceptsTarget
        noteField.isEnabled = acceptsTarget
        targetField.isEditable = acceptsTarget
        targetField.acceptsDrop = true
        searchButton.isEnabled = true
        if engine == .obsidian {
            folderField.placeholderString = "Vault Obsidian"
            noteField.placeholderString = "Inbox/Captures.md"
            if targetField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetField.stringValue == "Raccourci standard" || targetField.stringValue == "Aujourd'hui NotePlan" {
                applyTargetDisplay(targetDisplay(for: destination, folder: folderField.stringValue, note: noteField.stringValue))
            }
        } else if !acceptsTarget {
            folderField.placeholderString = "Dossier"
            folderField.stringValue = ""
            noteField.stringValue = ""
            applyTargetDisplay(targetDisplay(for: destination, folder: "", note: ""))
        } else if targetField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            applyTargetDisplay(targetDisplay(for: destination, folder: folderField.stringValue, note: noteField.stringValue))
        }
    }

    private func syncTargetTextIfNeeded() {
        let engine = selectedEngine()
        let destination = selectedDestination()
        guard engine == .obsidian || destination.acceptsTarget else { return }
        var value = targetField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value == targetDisplay(for: destination, folder: "", note: "") {
            value = ""
            targetField.stringValue = ""
        }
        guard !value.isEmpty else {
            folderField.stringValue = ""
            noteField.stringValue = ""
            return
        }

        if engine == .notePlan && destination == .noteTitle {
            folderField.stringValue = ""
            noteField.stringValue = value
            return
        }

        let clean = value.trimmingCharacters(in: CharacterSet(charactersIn: " "))
        if clean.hasSuffix("/") {
            folderField.stringValue = clean.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
            noteField.stringValue = ""
            return
        }

        let url = URL(fileURLWithPath: clean)
        let folder = url.deletingLastPathComponent().relativePath
        folderField.stringValue = folder == "." ? "" : folder
        noteField.stringValue = url.lastPathComponent
    }

    func applyDroppedPath(relativePath: String, isDirectory: Bool) {
        destinationPopup.selectItem(withTitle: ShortcutDestination.notePath.title)
        if isDirectory {
            folderField.stringValue = relativePath
            noteField.stringValue = ""
            targetField.stringValue = relativePath.isEmpty ? "Déposer une note .md ici" : "\(relativePath)/"
        } else {
            let url = URL(fileURLWithPath: relativePath)
            let folder = url.deletingLastPathComponent().relativePath
            folderField.stringValue = folder == "." ? "" : folder
            noteField.stringValue = url.lastPathComponent
            applyTargetDisplay(relativePath)
        }
        refreshNoteFieldState()
    }

    private func applyTargetDisplay(_ fullText: String) {
        targetField.toolTip = fullText.contains("/") ? fullText : nil
        targetField.stringValue = fullText
    }

    private func targetDisplay(for destination: ShortcutDestination, folder: String, note: String) -> String {
        if selectedEngine() == .obsidian {
            let cleanVault = folder.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanNote = note.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
            if cleanVault.isEmpty && cleanNote.isEmpty { return "Vault Obsidian + note .md" }
            if cleanNote.isEmpty { return cleanVault }
            return cleanNote
        }
        if destination == .standard { return "Raccourci standard" }
        if destination == .today { return "Aujourd'hui NotePlan" }
        let cleanFolder = folder.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        let cleanNote = note.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        if cleanFolder.isEmpty && cleanNote.isEmpty { return "Déposer depuis Finder une note .md, ou coller un lien NotePlan" }
        if cleanFolder.isEmpty { return cleanNote }
        if cleanNote.isEmpty { return "\(cleanFolder)/" }
        return "\(cleanFolder)/\(cleanNote)"
    }

    private func placeholder(for destination: ShortcutDestination) -> String {
        switch destination {
        case .standard: return "Raccourci standard"
        case .today: return "noteDate=today"
        case .noteTitle: return "Titre NotePlan"
        case .notePath: return "Note.md ou Sous-dossier/Note.md"
        }
    }
}

final class NoteSearchWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private static var retainedControllers: [NoteSearchWindowController] = []
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var allResults: [NoteSearchResult] = []
    private var filteredResults: [NoteSearchResult] = []
    private var isIndexing = false
    private let onSelect: (NoteSearchResult) -> Void

    convenience init(initialQuery: String, onSelect: @escaping (NoteSearchResult) -> Void) {
        let window = centeredWindow("Rechercher une note NotePlan", width: 780, height: 540)
        self.init(window: window, initialQuery: initialQuery, onSelect: onSelect)
    }

    init(window: NSWindow, initialQuery: String, onSelect: @escaping (NoteSearchResult) -> Void) {
        self.onSelect = onSelect
        super.init(window: window)
        buildContent(initialQuery: initialQuery)
        window.delegate = self
        loadResultsAsync()
    }

    private func loadResultsAsync() {
        guard Settings.selectedNotesRoot() != nil else {
            allResults = []
            filteredResults = []
            tableView.reloadData()
            statusLabel.stringValue = "Aucun dossier Notes choisi. Ouvre Préférences > Choisir dossier Notes."
            return
        }

        isIndexing = true
        statusLabel.stringValue = "Indexation des notes en cours..."
        writeDebugLog("search:index:start")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let results = loadNoteSearchResults()
            writeDebugLog("search:index:done:\(results.count)")
            DispatchQueue.main.async {
                guard let self else { return }
                self.isIndexing = false
                self.allResults = results
                self.applyFilter()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self, self.isIndexing else { return }
            self.statusLabel.stringValue = "Indexation trop lente ou bloquée. Vérifie le dossier Notes choisi dans Préférences."
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func show(initialQuery: String, onSelect: @escaping (NoteSearchResult) -> Void) {
        let controller = NoteSearchWindowController(initialQuery: initialQuery, onSelect: onSelect)
        retainedControllers.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    fileprivate static func release(_ controller: NoteSearchWindowController) {
        retainedControllers.removeAll { $0 === controller }
    }

    private func buildContent(initialQuery: String) {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        searchField.placeholderString = "Titre, chemin, #tag ou @contexte"
        searchField.stringValue = initialQuery
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchChanged)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = tableView

        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Note"
        titleColumn.width = 240
        let pathColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathColumn.title = "Chemin"
        pathColumn.width = 320
        let tagsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tags"))
        tagsColumn.title = "Tags / Contextes"
        tagsColumn.width = 190
        tableView.addTableColumn(titleColumn)
        tableView.addTableColumn(pathColumn)
        tableView.addTableColumn(tagsColumn)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(validateSelection)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        let validateButton = NSButton(title: "Valider", target: self, action: #selector(validateSelection))
        validateButton.bezelStyle = .rounded
        validateButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "Annuler", target: self, action: #selector(closeWindow))
        cancelButton.bezelStyle = .rounded
        buttonRow.addArrangedSubview(validateButton)
        buttonRow.addArrangedSubview(cancelButton)

        stack.addArrangedSubview(searchField)
        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(buttonRow)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 360)
        ])

        applyFilter()
    }

    @objc private func searchChanged() {
        applyFilter()
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            filteredResults = Array(allResults.prefix(250))
        } else {
            let terms = query.split(separator: " ").map(String.init)
            filteredResults = allResults.filter { result in
                terms.allSatisfy { term in
                    if term.hasPrefix("#") {
                        return result.tags.contains { $0.lowercased().contains(term) }
                    }
                    return result.title.lowercased().contains(term)
                        || result.relativePath.lowercased().contains(term)
                        || result.tags.contains { $0.lowercased().contains(term) }
                }
            }.prefix(250).map { $0 }
        }
        tableView.reloadData()
        if !filteredResults.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        statusLabel.stringValue = "\(filteredResults.count) resultat(s) affiche(s) sur \(allResults.count) notes. Chercher par titre, chemin, #tag ou @contexte."
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredResults.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < filteredResults.count else { return nil }
        let result = filteredResults[row]
        let value: String
        switch tableColumn?.identifier.rawValue {
        case "title":
            value = result.title
        case "tags":
            value = result.tags.prefix(8).joined(separator: " ")
        default:
            value = result.relativePath
        }
        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: value)
        textField.lineBreakMode = .byTruncatingMiddle
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    @objc private func validateSelection() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredResults.count else {
            NSSound.beep()
            return
        }
        onSelect(filteredResults[row])
        close()
    }

    @objc private func closeWindow() {
        close()
    }
}

extension NoteSearchWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NoteSearchWindowController.release(self)
    }
}

final class SettingsWindowController: NSWindowController {
    private let serviceNameField = NSTextField(string: Settings.serviceName)
    private let tagField = NSTextField(string: Settings.taskTag)
    private let notesRootField = NSTextField(string: Settings.notesRootPath)
    private let chooseNotesRootButton = NSButton(title: "Choisir dossier Notes", target: nil, action: nil)
    private let openNoteCheckbox = NSButton(checkboxWithTitle: "Ouvrir NotePlan après l'ajout", target: nil, action: nil)
    private let includeSourceCheckbox = NSButton(checkboxWithTitle: "Ajouter la source (lien capturé)", target: nil, action: nil)
    private var shortcutRows: [ShortcutSlotRow] = []
    private let shortcutHelpLabel = NSTextField(labelWithString: "Ligne 1 par défaut : NotePlan + Aujourd'hui (NotePlan). Sinon choisir Standard, déposer depuis Finder une note .md, ou coller un lien NotePlan.")
    private let variablesHelpLabel = NSTextField(labelWithString: "Variables : $date, $day, $time, $datetime, $month, $year")
    private let helpButton = NSButton(title: "Aide", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Autoriser Accessibilité", target: nil, action: nil)
    private let exportButton = NSButton(title: "Exporter JSON", target: nil, action: nil)
    private let importButton = NSButton(title: "Importer JSON", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "Enregistrer", target: nil, action: nil)
    private var hasPendingChanges = false

    convenience init() {
        let window = centeredWindow("Préférences NoteDroppy", width: 980, height: 800, style: [.titled, .closable, .miniaturizable, .resizable])
        self.init(window: window)
        buildContent()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "local"
        let title = NSTextField(labelWithString: "NoteDroppy Integrated \(appVersion) (\(appBuild))")
        title.font = .boldSystemFont(ofSize: 18)

        let tagline = NSTextField(labelWithString: "Time is precious.\nSpend it with those you love")
        tagline.font = .systemFont(ofSize: 11)
        tagline.textColor = .secondaryLabelColor
        tagline.maximumNumberOfLines = 2
        tagline.lineBreakMode = .byWordWrapping

        let logo = NSImageView()
        logo.image = NSApplication.shared.applicationIconImage
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.widthAnchor.constraint(equalToConstant: 64).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let titleStack = NSStackView()
        titleStack.orientation = .horizontal
        titleStack.spacing = 12
        titleStack.alignment = .centerY
        titleStack.addArrangedSubview(logo)
        titleStack.addArrangedSubview(title)
        titleStack.addArrangedSubview(tagline)

        serviceNameField.placeholderString = "NotePlan : ajouter en tâche"
        serviceNameField.lineBreakMode = .byTruncatingTail

        tagField.placeholderString = "#capture"

        notesRootField.placeholderString = "Choisir le dossier Notes pour activer la recherche"
        notesRootField.isEditable = false
        notesRootField.isSelectable = true
        notesRootField.lineBreakMode = .byTruncatingMiddle

        chooseNotesRootButton.target = self
        chooseNotesRootButton.action = #selector(chooseNotesRoot)
        chooseNotesRootButton.bezelStyle = .rounded

        let serviceTagRow = horizontalRow(spacing: 10)
        serviceTagRow.addArrangedSubview(formLabel("Nom du Service", width: 118))
        serviceTagRow.addArrangedSubview(serviceNameField)
        serviceTagRow.addArrangedSubview(formLabel("Tag de la tâche via service", width: 178))
        serviceTagRow.addArrangedSubview(tagField)

        let notesRootRow = horizontalRow(spacing: 10)
        notesRootRow.addArrangedSubview(formLabel("Dossier Notes", width: 118))
        notesRootRow.addArrangedSubview(notesRootField)
        notesRootRow.addArrangedSubview(chooseNotesRootButton)

        openNoteCheckbox.state = Settings.openNote ? .on : .off
        includeSourceCheckbox.state = Settings.includeSource ? .on : .off
        shortcutHelpLabel.textColor = .secondaryLabelColor
        shortcutHelpLabel.lineBreakMode = .byWordWrapping
        shortcutHelpLabel.maximumNumberOfLines = 2
        variablesHelpLabel.textColor = .secondaryLabelColor
        variablesHelpLabel.lineBreakMode = .byWordWrapping
        variablesHelpLabel.maximumNumberOfLines = 1

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.alignment = .centerY

        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let quitButton = NSButton(title: "Quitter", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quitButton.bezelStyle = .rounded
        quitButton.keyEquivalent = "q"

        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibilitySettings)
        accessibilityButton.bezelStyle = .rounded

        helpButton.target = self
        helpButton.action = #selector(openHelp)
        helpButton.bezelStyle = .rounded

        exportButton.target = self
        exportButton.action = #selector(exportPreferencesJSON)
        exportButton.bezelStyle = .rounded

        importButton.target = self
        importButton.action = #selector(importPreferencesJSON)
        importButton.bezelStyle = .rounded

        buttons.addArrangedSubview(saveButton)
        buttons.addArrangedSubview(exportButton)
        buttons.addArrangedSubview(importButton)
        buttons.addArrangedSubview(helpButton)
        buttons.addArrangedSubview(accessibilityButton)
        buttons.addArrangedSubview(quitButton)

        [serviceNameField, tagField, notesRootField].forEach { field in
            styleFillableField(field)
            field.translatesAutoresizingMaskIntoConstraints = false
        }
        serviceNameField.widthAnchor.constraint(equalToConstant: 360).isActive = true
        tagField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        notesRootField.widthAnchor.constraint(equalToConstant: 560).isActive = true

        let slotsStack = NSStackView()
        slotsStack.orientation = .vertical
        slotsStack.spacing = 8
        slotsStack.alignment = .leading

        slotsStack.addArrangedSubview(ShortcutSlotRow.headerView())

        shortcutRows = Settings.allShortcutSlots().map { slot in
            let row = ShortcutSlotRow(slot: slot)
            row.recorder.onChange = { [weak self, weak row] combo in
                guard let row else { return }
                row.setCombo(combo)
                self?.autosaveSettings(message: "Raccourci enregistré.")
            }
            row.onSearch = { [weak self] row in
                self?.showNoteSearch(for: row)
            }
            row.onTargetDrop = { [weak self] row, target in
                self?.applyDroppedTarget(target, to: row) ?? false
            }
            row.onPasteTarget = { [weak self] row in
                self?.pasteTarget(for: self?.activeShortcutRow(defaultingTo: row) ?? row)
            }
            row.onChange = { [weak self] _ in
                self?.autosaveSettings(message: "Réglages enregistrés.")
            }
            slotsStack.addArrangedSubview(row.view())
            return row
        }

        stack.addArrangedSubview(titleStack)
        stack.addArrangedSubview(serviceTagRow)
        stack.addArrangedSubview(notesRootRow)
        stack.addArrangedSubview(openNoteCheckbox)
        stack.addArrangedSubview(includeSourceCheckbox)
        stack.addArrangedSubview(shortcutHelpLabel)
        stack.addArrangedSubview(variablesHelpLabel)
        stack.addArrangedSubview(slotsStack)
        stack.addArrangedSubview(buttons)
        stack.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22)
        ])
        contentView.layoutSubtreeIfNeeded()
        let fitting = stack.fittingSize
        let contentSize = NSSize(width: max(980, fitting.width + 48), height: max(620, fitting.height + 44))
        window?.setContentSize(contentSize)
        window?.minSize = NSSize(width: 980, height: 560)
        refreshAccessibilityStatus()
        markPendingChanges(false)
    }

    private func showNoteSearch(for row: ShortcutSlotRow) {
        guard Settings.selectedNotesRoot() != nil else {
            statusLabel.stringValue = "Choisis d'abord le dossier Notes NotePlan pour activer la recherche."
            return
        }
        let initial = [row.folderField.stringValue, row.noteField.stringValue]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        NoteSearchWindowController.show(initialQuery: initial) { selected in
            row.applySelectedNote(selected)
            self.statusLabel.stringValue = "Note sélectionnée : \(selected.relativePath)"
        }
    }

    private func applyDroppedTarget(_ target: ShortcutTarget, to row: ShortcutSlotRow) -> Bool {
        if row.slot.engine == .obsidian {
            return applyDroppedObsidianTarget(target, to: row)
        }

        guard let root = Settings.selectedNotesRoot() else {
            statusLabel.stringValue = "Choisis d'abord le dossier Notes NotePlan, puis dépose une note .md."
            NSSound.beep()
            return false
        }

        if let url = target.url {
            if url.scheme?.lowercased() == "noteplan",
               let path = notePathFromDroppedText(url.absoluteString, root: root) {
                return commitDroppedPath(relativePath: path, isDirectory: false, row: row)
            }

            guard url.isFileURL else {
                statusLabel.stringValue = "Dépose une note .md, un dossier, ou colle un lien NotePlan."
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
                statusLabel.stringValue = "Pour Cible, dépose un dossier Finder ou une note .md."
                NSSound.beep()
                return false
            }

            let relativePath = filePath == rootURL.path
                ? ""
                : String(filePath.dropFirst(rootPath.count))
            if !isDirectory.boolValue, fileURL.pathExtension.lowercased() != "md" {
                statusLabel.stringValue = "Dépose une note .md ou un dossier NotePlan."
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

        statusLabel.stringValue = "Dépose une note .md depuis Finder."
        NSSound.beep()
        return false
    }

    private func applyDroppedObsidianTarget(_ target: ShortcutTarget, to row: ShortcutSlotRow) -> Bool {
        guard let url = target.url, url.isFileURL else {
            statusLabel.stringValue = "Pour Obsidian, dépose une note .md ou un dossier depuis Finder."
            NSSound.beep()
            return false
        }

        let fileURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            statusLabel.stringValue = "Fichier introuvable : \(fileURL.path)"
            NSSound.beep()
            return false
        }

        if !isDirectory.boolValue, fileURL.pathExtension.lowercased() != "md" {
            statusLabel.stringValue = "Pour Obsidian, dépose une note .md ou un dossier."
            NSSound.beep()
            return false
        }

        row.applyDroppedPath(relativePath: fileURL.path, isDirectory: isDirectory.boolValue)
        autosaveSettings()
        statusLabel.stringValue = "Cible Obsidian enregistrée : \(fileURL.path)"
        return true
    }

    private func pasteTarget(for row: ShortcutSlotRow) {
        writeDebugLog("shortcut-paste:slot:\(row.index):\(pasteboardPreview(from: NSPasteboard.general))")
        var target = shortcutTarget(from: NSPasteboard.general)
        if target == nil {
            writeDebugLog("shortcut-paste:fallback-noteplan-url:start")
            if copyCurrentNotePlanURLToPasteboard() {
                writeDebugLog("shortcut-paste:fallback-noteplan-url:clipboard:\(pasteboardPreview(from: NSPasteboard.general))")
                target = shortcutTarget(from: NSPasteboard.general)
            } else {
                writeDebugLog("shortcut-paste:fallback-noteplan-url:failed")
            }
        }

        guard let target else {
            statusLabel.stringValue = "Depuis NotePlan, ouvre une note puis utilise Note > Copier l'URL vers la note, ou copie un titre/chemin .md."
            NSSound.beep()
            return
        }
        _ = applyDroppedTarget(target, to: row)
    }

    private func activeShortcutRow(defaultingTo fallback: ShortcutSlotRow) -> ShortcutSlotRow {
        guard let firstResponder = window?.firstResponder else { return fallback }
        for row in shortcutRows {
            if firstResponder === row.targetField {
                return row
            }
            if let editor = row.targetField.currentEditor(), firstResponder === editor {
                return row
            }
        }
        return fallback
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
        tell application id "\(Bundle.main.bundleIdentifier ?? "local.codex.notedroppy.integrated")" to activate
        return copied
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            writeDebugLog("shortcut-paste:fallback-noteplan-url:error:\(error)")
        }
        return result.booleanValue
    }

    private func commitDroppedPath(relativePath: String, isDirectory: Bool, row: ShortcutSlotRow) -> Bool {
        row.applyDroppedPath(relativePath: relativePath, isDirectory: isDirectory)
        autosaveSettings()
        statusLabel.stringValue = "Cible enregistrée : \(relativePath.isEmpty ? "Notes" : relativePath)"
        return true
    }

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
        let pattern = #"noteplan://[^\s\)\]>"]+"#
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

    @objc private func chooseNotesRoot() {
        let panel = NSOpenPanel()
        panel.title = "Choisir le dossier Notes NotePlan"
        panel.prompt = "Choisir"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if !Settings.notesRootPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: Settings.notesRootPath)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Settings.setNotesRoot(url)
        notesRootField.stringValue = url.path
        statusLabel.stringValue = "Dossier Notes choisi : \(url.path)"
    }

    @objc private func saveSettings() {
        let serviceName = serviceNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = tagField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(serviceName.isEmpty ? "NotePlan : ajouter en tâche" : serviceName, forKey: Settings.serviceNameKey)
        UserDefaults.standard.set(tag.isEmpty ? "#capture" : tag, forKey: Settings.taskTagKey)
        UserDefaults.standard.set(openNoteCheckbox.state == .on, forKey: Settings.openNoteKey)
        UserDefaults.standard.set(includeSourceCheckbox.state == .on, forKey: Settings.includeSourceKey)
        shortcutRows.forEach { Settings.setShortcutSlot($0.slot) }
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)

        if applyServiceNameToBundle(serviceName.isEmpty ? "NotePlan : ajouter en tâche" : serviceName) {
            statusLabel.stringValue = "Réglages enregistrés. Le menu Services peut demander quelques secondes pour se rafraîchir."
        } else {
            statusLabel.stringValue = "Réglages enregistrés. Nom du Service gardé pour l'app, mais macOS n'a pas pu être rafraîchi."
        }
        refreshAccessibilityStatus(append: true)
        markPendingChanges(false)
    }

    @objc private func exportPreferencesJSON() {
        saveCurrentControlsToDefaults()
        let panel = NSSavePanel()
        panel.title = "Exporter les préférences NoteDroppy"
        panel.nameFieldStringValue = "notedroppy-preferences.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(PreferencesFile.current())
            try data.write(to: url, options: .atomic)
            statusLabel.stringValue = "Préférences exportées : \(url.path)"
        } catch {
            statusLabel.stringValue = "Export JSON impossible : \(error.localizedDescription)"
        }
    }

    @objc private func importPreferencesJSON() {
        let panel = NSOpenPanel()
        panel.title = "Importer les préférences NoteDroppy"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let preferences = try JSONDecoder().decode(PreferencesFile.self, from: data)
            preferences.apply()
            reloadControlsFromSettings()
            statusLabel.stringValue = "Préférences importées : \(url.path)"
        } catch {
            statusLabel.stringValue = "Import JSON impossible : \(error.localizedDescription)"
        }
    }

    private func saveCurrentControlsToDefaults() {
        let serviceName = serviceNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = tagField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(serviceName.isEmpty ? "NotePlan : ajouter en tâche" : serviceName, forKey: Settings.serviceNameKey)
        UserDefaults.standard.set(tag.isEmpty ? "#capture" : tag, forKey: Settings.taskTagKey)
        UserDefaults.standard.set(openNoteCheckbox.state == .on, forKey: Settings.openNoteKey)
        UserDefaults.standard.set(includeSourceCheckbox.state == .on, forKey: Settings.includeSourceKey)
        shortcutRows.forEach { Settings.setShortcutSlot($0.slot) }
        UserDefaults.standard.synchronize()
    }

    private func autosaveSettings(message: String? = nil) {
        saveCurrentControlsToDefaults()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        if let message {
            statusLabel.stringValue = message
        }
        markPendingChanges(true)
    }

    private func markPendingChanges(_ pending: Bool) {
        hasPendingChanges = pending
        saveButton.bezelColor = pending ? .systemOrange : .systemGreen
    }

    private func reloadControlsFromSettings() {
        serviceNameField.stringValue = Settings.serviceName
        tagField.stringValue = Settings.taskTag
        notesRootField.stringValue = Settings.notesRootPath
        openNoteCheckbox.state = Settings.openNote ? .on : .off
        includeSourceCheckbox.state = Settings.includeSource ? .on : .off
        let slots = Settings.allShortcutSlots()
        for (row, slot) in zip(shortcutRows, slots) {
            row.apply(slot: slot)
        }
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    @objc private func openAccessibilitySettings() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refreshAccessibilityStatus()
    }

    @objc private func openHelp() {
        showHelpDocument(named: "HELP", title: "Aide NoteDroppy")
    }

    private func refreshAccessibilityStatus(append: Bool = false) {
        let trusted = AXIsProcessTrusted()
        accessibilityButton.isEnabled = !trusted
        let accessibilityText = trusted
            ? "Accessibilité OK. Le raccourci global peut copier la sélection."
            : "Accessibilité requise pour le raccourci global."
        statusLabel.stringValue = append && !statusLabel.stringValue.isEmpty
            ? "\(statusLabel.stringValue) \(accessibilityText)"
            : accessibilityText
    }

    private func applyServiceNameToBundle(_ serviceName: String) -> Bool {
        let plistURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              var plist = (try? PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: nil)) as? [String: Any],
              var services = plist["NSServices"] as? [[String: Any]],
              !services.isEmpty else {
            return false
        }

        var firstService = services[0]
        firstService["NSMenuItem"] = ["default": serviceName]
        services[0] = firstService
        plist["NSServices"] = services

        guard let updatedData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            return false
        }

        do {
            try updatedData.write(to: plistURL, options: .atomic)
        } catch {
            return false
        }

        _ = runProcess("/usr/bin/codesign", ["--force", "--deep", "-s", Settings.codeSignIdentity, Bundle.main.bundlePath])
        _ = runProcess("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", ["-f", Bundle.main.bundlePath])
        _ = runProcess("/System/Library/CoreServices/pbs", ["-flush"])
        _ = runProcess("/System/Library/CoreServices/pbs", ["-update"])
        return true
    }

    private func runProcess(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

final class HelpWindowController: NSWindowController {
    private static var retainedControllers: [HelpWindowController] = []

    convenience init(title: String, content: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        self.init(window: window)
        buildContent(content)
        window.delegate = self
    }

    static func show(title: String, content: String) {
        let controller = HelpWindowController(title: title, content: content)
        retainedControllers.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent(_ content: String) {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.string = content
        scrollView.documentView = textView

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        let githubButton = NSButton(title: "GitHub Repository", target: self, action: #selector(openGitHub))
        githubButton.bezelStyle = .rounded
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.bezelStyle = .rounded

        buttonRow.addArrangedSubview(githubButton)
        buttonRow.addArrangedSubview(closeButton)

        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(buttonRow)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 480)
        ])
    }

    @objc private func openGitHub() {
        openRepository()
    }

    @objc private func closeWindow() {
        close()
    }

    fileprivate static func release(_ controller: HelpWindowController) {
        retainedControllers.removeAll { $0 === controller }
    }
}

extension HelpWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        HelpWindowController.release(self)
    }
}

private func showHelpDocument(named name: String, title: String) {
    let content: String
    if let url = Bundle.main.url(forResource: name, withExtension: "md"),
       let loaded = try? String(contentsOf: url, encoding: .utf8) {
        content = loaded
    } else {
        content = "Help content is missing from the app bundle."
    }
    HelpWindowController.show(title: title, content: content)
}

private func openRepository() {
    if let url = URL(string: Settings.repositoryURL) {
        NSWorkspace.shared.open(url)
    }
}

private extension Notification.Name {
    static let settingsDidChange = Notification.Name("NoteDroppySettingsDidChange")
    static let shortcutRecordingBegan = Notification.Name("NoteDroppyShortcutRecordingBegan")
    static let shortcutRecordingEnded = Notification.Name("NoteDroppyShortcutRecordingEnded")
}

final class ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard = .general) {
        self.items = pasteboard.pasteboardItems?.map { item in
            var values: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    values[type] = data
                }
            }
            return values
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let restoredItems = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}

final class GlobalShortcutMonitor {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var lastFire = Date.distantPast
    private let handler: (Int) -> Void
    private let hotKeySignature = fourCharCode("NDPY")

    init(handler: @escaping (Int) -> Void) {
        self.handler = handler
        update()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .settingsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecordingBegan),
            name: .shortcutRecordingBegan,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecordingEnded),
            name: .shortcutRecordingEnded,
            object: nil
        )
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func settingsDidChange() {
        update()
    }

    @objc private func shortcutRecordingBegan() {
        stop()
    }

    @objc private func shortcutRecordingEnded() {
        update()
    }

    private func update() {
        stop()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotKeyHandler,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            return
        }

        for slot in Settings.allShortcutSlots() where slot.enabled {
            var ref: EventHotKeyRef?
            let carbonHotKeyID = EventHotKeyID(signature: hotKeySignature, id: UInt32(slot.index))
            let registerStatus = RegisterEventHotKey(
                slot.combo.keyCode,
                slot.combo.carbonModifiers,
                carbonHotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if registerStatus == noErr, let ref {
                hotKeyRefs[UInt32(slot.index)] = ref
            }
        }
    }

    private func stop() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate func fireIfMatching(signature: UInt32, id: UInt32) -> OSStatus {
        guard signature == hotKeySignature, hotKeyRefs[id] != nil else {
            return OSStatus(eventNotHandledErr)
        }
        guard Date().timeIntervalSince(lastFire) > 0.8 else { return noErr }
        lastFire = Date()
        DispatchQueue.main.async {
            self.handler(Int(id))
        }
        return noErr
    }
}

private func fourCharCode(_ value: String) -> UInt32 {
    var result: UInt32 = 0
    for scalar in value.unicodeScalars.prefix(4) {
        result = (result << 8) + UInt32(scalar.value)
    }
    return result
}

private let globalHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else {
        return status
    }

    let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(userData).takeUnretainedValue()
    return monitor.fireIfMatching(signature: hotKeyID.signature, id: hotKeyID.id)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didReceiveOpenEvent = false
    private var settingsWindowController: SettingsWindowController?
    private var shortcutMonitor: GlobalShortcutMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("launch")
        Settings.migrateShortcutLayoutIfNeeded()
        shortcutMonitor = GlobalShortcutMonitor { [weak self] slotIndex in
            self?.captureSelectedTextWithShortcut(slotIndex: slotIndex)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if !self.didReceiveOpenEvent {
                if !UserDefaults.standard.bool(forKey: Settings.didShowFirstLaunchSettingsKey) {
                    UserDefaults.standard.set(true, forKey: Settings.didShowFirstLaunchSettingsKey)
                    UserDefaults.standard.synchronize()
                    self.log("show-settings:first-launch")
                    self.showSettingsWindow()
                } else {
                    self.log("hide-settings:normal-launch")
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow()
        return true
    }

    @objc func showSettingsWindowFromMenu(_ sender: Any?) {
        showSettingsWindow()
    }

    @objc func showEditorWindowFromMenu(_ sender: Any?) {
        NotePlanEditorWindowController.show()
    }

    @objc func showAbout(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "NoteDroppy"
        alert.informativeText = """
        Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")

        Ajoute rapidement des tâches dans NotePlan depuis le Dock, le Service macOS ou le raccourci global.

        Repository:
        \(Settings.repositoryURL)
        """
        alert.addButton(withTitle: "GitHub")
        alert.addButton(withTitle: "Aide")
        alert.addButton(withTitle: "OK")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openRepository()
        } else if response == .alertSecondButtonReturn {
            showHelpDocument(named: "HELP", title: "Aide NoteDroppy")
        }
    }

    @objc func openHelp(_ sender: Any?) {
        showHelpDocument(named: "HELP", title: "Aide NoteDroppy")
    }

    @objc func openEnglishHelp(_ sender: Any?) {
        showHelpDocument(named: "HELP.en", title: "NoteDroppy Help")
    }

    @objc func openGitHubRepository(_ sender: Any?) {
        openRepository()
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        didReceiveOpenEvent = true
        log("openFiles:\(filenames.joined(separator: " | "))")
        for filename in filenames {
            let fileURL = URL(fileURLWithPath: filename)
            let droppedText = extractTodoText(from: fileURL) ?? fileMarkdownLink(for: fileURL)
            log("openFiles:extracted:\(droppedText)")
            sendTodo(droppedText)
        }
        NSApp.reply(toOpenOrPrint: .success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if NSApp.windows.isEmpty {
                NSApp.terminate(nil)
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        didReceiveOpenEvent = true
        log("openURLs:\(urls.map { $0.absoluteString }.joined(separator: " | "))")
        for url in urls {
            if url.isFileURL {
                let droppedText = extractTodoText(from: url) ?? fileMarkdownLink(for: url)
                log("openURLs:file-extracted:\(droppedText)")
                sendTodo(droppedText)
            } else {
                sendTodo(url.absoluteString)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if NSApp.windows.isEmpty {
                NSApp.terminate(nil)
            }
        }
    }

    private func extractTodoText(from fileURL: URL) -> String? {
        let ext = fileURL.pathExtension.lowercased()

        if ext == "webloc" || ext == "url" {
            if let data = try? Data(contentsOf: fileURL),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let dict = plist as? [String: Any],
               let value = dict["URL"] as? String,
               isWebURL(value) {
                return value
            }

            if let text = try? String(contentsOf: fileURL, encoding: .utf8),
               let value = firstWebURL(in: text) {
                return value
            }
        }

        if ext == "textclipping",
           let value = shell(["/usr/bin/mdls", "-raw", "-name", "kMDItemTextContent", fileURL.path]) {
            return normalizedTodoText(value)
        }

        if ext == "rtf",
           let attributed = try? NSAttributedString(url: fileURL, options: [:], documentAttributes: nil) {
            return normalizedTodoText(attributed.string)
        }

        if isPlainTextFile(fileURL),
           let text = try? String(contentsOf: fileURL, encoding: .utf8),
           let normalized = normalizedTodoText(text) {
            return normalized
        }

        return fileMarkdownLink(for: fileURL)
    }

    private func fileMarkdownLink(for fileURL: URL) -> String {
        let label = fileURL.lastPathComponent.isEmpty ? fileURL.path : fileURL.lastPathComponent
        let escapedLabel = label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return "[\(escapedLabel)](\(fileURL.absoluteString))"
    }

    private func isPlainTextFile(_ fileURL: URL) -> Bool {
        let textExtensions: Set<String> = ["txt", "md", "markdown", "text", "csv", "json", "xml", "yaml", "yml", "log"]
        if textExtensions.contains(fileURL.pathExtension.lowercased()) {
            return true
        }
        guard let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) else {
            return false
        }
        return looksLikePlainText(data.prefix(4096))
    }

    private func looksLikePlainText(_ bytes: Data.SubSequence) -> Bool {
        guard !bytes.isEmpty else { return false }
        for byte in bytes {
            if byte == 0 { return false }
            if byte < 0x09 { return false }
            if byte > 0x0D && byte < 0x20 { return false }
        }
        return true
    }

    private func firstWebURL(in text: String) -> String? {
        let pattern = #"(?:https?://)?(?:www\.)?[A-Za-z0-9][A-Za-z0-9.-]+\.[A-Za-z]{2,}(?:/[^\s<>"']*)?"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return normalizedWebURL(String(text[range]))
    }

    private func isWebURL(_ value: String) -> Bool {
        normalizedWebURL(value) != nil
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

    private func markdownLinkForWebURL(_ value: String) -> String? {
        guard let normalized = normalizedWebURL(value),
              let url = URL(string: normalized),
              let host = url.host else {
            return nil
        }
        let title = webLinkTitle(for: url, host: host)
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

    private func normalizedTodoText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "(null)" else { return nil }
        return trimmed
    }

    @objc func addSelectionAsTodo(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        didReceiveOpenEvent = true
        log("service:invoked")
        guard let text = pasteboard.string(forType: .string) else {
            log("service:no-text")
            error.pointee = "Aucun texte sélectionné" as NSString
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
            return
        }
        log("service:text:\(text)")
        sendTodo(text, sourceURL: sourceWebURL(from: pasteboard))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if NSApp.windows.isEmpty {
                NSApp.terminate(nil)
            }
        }
    }

    private func captureSelectedTextWithShortcut(slotIndex: Int) {
        let slot = Settings.shortcutSlot(slotIndex)
        guard slot.enabled else {
            log("shortcut:disabled-slot:\(slotIndex)")
            return
        }
        log("shortcut:invoked:slot:\(slotIndex)")
        guard canCaptureFrontmostApplication() else {
            log("shortcut:ignored-frontmost-app")
            NSSound.beep()
            return
        }
        guard isAccessibilityTrusted(prompt: false) else {
            log("shortcut:accessibility-required:no-selection-capture")
            NSSound.beep()
            showSettingsWindow()
            return
        }

        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot(pasteboard: pasteboard)
        let previousChangeCount = pasteboard.changeCount

        guard postCopyShortcut() else {
            log("shortcut:copy-post-failed")
            return
        }

        waitForCopiedText(pasteboard: pasteboard, previousChangeCount: previousChangeCount, attemptsRemaining: 12) { text, pastedSourceURL in
            defer { snapshot.restore(to: pasteboard) }
            let clipboardText = text.flatMap { self.normalizedTodoText($0) }
            let axText = self.selectedTextFromAccessibility().flatMap { self.normalizedTodoText($0) }
            if let normalized = self.bestShortcutText(clipboardText: clipboardText, axText: axText) {
                self.log("shortcut:text:\(normalized)")
                self.sendTodo(normalized, shortcutSlot: slot, sourceURL: pastedSourceURL)
                return
            }
            self.log("shortcut:no-selected-text")
        }
    }

    private func bestShortcutText(clipboardText: String?, axText: String?) -> String? {
        guard let clipboardText else { return axText }
        guard let axText else { return clipboardText }
        if clipboardText == axText { return clipboardText }
        if clipboardText.hasSuffix(axText) { return axText }
        if axText.hasSuffix(clipboardText) { return clipboardText }
        return clipboardText
    }

    private func selectedTextFromAccessibility() -> String? {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            log("shortcut:ax:no-frontmost-app")
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
        var focusedValue: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedStatus == .success, let focusedValue else {
            log("shortcut:ax:no-focused-element:\(focusedStatus.rawValue)")
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement
        var selectedValue: CFTypeRef?
        let selectedStatus = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )
        guard selectedStatus == .success, let selectedText = selectedValue as? String else {
            log("shortcut:ax:no-selected-text:\(selectedStatus.rawValue)")
            return nil
        }

        return selectedText
    }

    private func sourceWebPageURL(for application: NSRunningApplication?) -> String? {
        guard let appName = application?.localizedName else { return nil }
        let escapedAppName = appName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        set frontApp to "\(escapedAppName)"
        set chromiumApps to {"Google Chrome", "Google Chrome Canary", "Brave Browser", "Microsoft Edge", "Arc", "Chromium"}
        if frontApp is "Safari" then
            tell application "Safari"
                if (count of windows) > 0 then return URL of current tab of front window
            end tell
        else if chromiumApps contains frontApp then
            using terms from application "Google Chrome"
                tell application frontApp
                    if (count of windows) > 0 then return URL of active tab of front window
                end tell
            end using terms from
        end if
        return ""
        """
        guard let output = shell(["/usr/bin/osascript", "-e", script], timeout: 1.0)?.trimmingCharacters(in: .whitespacesAndNewlines),
              isWebURL(output) else {
            log("source-url:none-or-timeout:\(appName)")
            return nil
        }
        log("source-url:\(output)")
        return output
    }

    private func sourceWebURL(from pasteboard: NSPasteboard) -> String? {
        for candidate in pasteboardStrings(from: pasteboard) {
            if isWebURL(candidate), let url = URL(string: candidate), url.host != nil {
                log("source-url:pasteboard:\(candidate)")
                return candidate
            }
        }
        return nil
    }

    private func waitForCopiedText(
        pasteboard: NSPasteboard,
        previousChangeCount: Int,
        attemptsRemaining: Int,
        completion: @escaping (String?, String?) -> Void
    ) {
        if pasteboard.changeCount != previousChangeCount {
            completion(pasteboard.string(forType: .string), sourceWebURL(from: pasteboard))
            return
        }
        guard attemptsRemaining > 0 else {
            completion(nil, nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.waitForCopiedText(
                pasteboard: pasteboard,
                previousChangeCount: previousChangeCount,
                attemptsRemaining: attemptsRemaining - 1,
                completion: completion
            )
        }
    }

    private func canCaptureFrontmostApplication() -> Bool {
        if NSApp.isActive {
            return false
        }

        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = frontmost.bundleIdentifier else {
            return true
        }

        let blockedIdentifiers: Set<String> = [
            Bundle.main.bundleIdentifier ?? "",
            "com.apple.systempreferences",
            "com.apple.systemsettings",
            "com.apple.SecurityAgent",
            "com.apple.loginwindow"
        ]
        return !blockedIdentifiers.contains(bundleIdentifier)
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func postCopyShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func sendTodo(_ todoText: String, shortcutSlot: ShortcutSlot? = nil, sourceURL: String? = nil) {
        let tagSource = shortcutSlot?.tags ?? Settings.taskTag
        guard let content = normalizedTaskContent(expandedVariables(todoText), tags: tagSource) else { return }
        log("sendTodo:\(content)")
        let task = formattedTask(from: content, tags: tagSource, sourceURL: sourceURL)
        if shortcutSlot?.engine == .obsidian {
            writeObsidianTask(task, shortcutSlot: shortcutSlot)
            return
        }
        let openNoteValue = Settings.openNote ? "yes" : "no"
        let noteTarget = notePlanTarget(for: shortcutSlot)
        log("sendTodoTarget:\(noteTarget)")
        let targetPrefix = noteTarget.isEmpty ? "" : "\(noteTarget)&"
        let target = "noteplan://x-callback-url/addText?\(targetPrefix)text=\(encode(task))&mode=append&openNote=\(openNoteValue)"
        if let url = URL(string: target) {
            NSWorkspace.shared.open(url)
        }
    }

    private func writeObsidianTask(_ task: String, shortcutSlot: ShortcutSlot?) {
        guard let shortcutSlot else { return }
        let note = expandedVariables(shortcutSlot.noteReference).trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = expandedVariables(shortcutSlot.folder).trimmingCharacters(in: .whitespacesAndNewlines)
        let fileURL: URL
        if note.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: note)
        } else if folder.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: folder).appendingPathComponent(note)
        } else {
            log("obsidian:error:no-absolute-target")
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
            log("obsidian:write:\(finalURL.path)")
            if Settings.openNote {
                NSWorkspace.shared.open(finalURL)
            }
        } catch {
            log("obsidian:error:\(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private func notePlanTarget(for shortcutSlot: ShortcutSlot?) -> String {
        guard let shortcutSlot else { return "noteDate=today" }

        switch shortcutSlot.destination {
        case .standard:
            return ""
        case .today:
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

    private func stripLeadingCheckbox(_ value: String) -> String {
        var content = value
        let taskPrefixPattern = #"^[-*]\s+\[[ xX]\]\s+"#
        while let range = content.range(of: taskPrefixPattern, options: .regularExpression) {
            content.removeSubrange(range)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return content
    }

    private func formattedTask(from content: String, tags: String, sourceURL: String? = nil) -> String {
        let tag = normalizedTags(expandedVariables(tags))
        var lines = content.components(separatedBy: .newlines)
        while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeFirst()
        }
        while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeLast()
        }

        guard let first = lines.first else {
            return "- [ ] \(tag)"
        }
        let firstLine = first.trimmingCharacters(in: .whitespacesAndNewlines)

        var continuation = lines.dropFirst().map { line -> String in
            line.isEmpty ? ">" : "> \(stripLeadingCheckbox(line))"
        }
        if let sourceLine = sourceContinuationLine(sourceURL, content: content) {
            continuation.append(sourceLine)
        }
        let suffix = tag.isEmpty ? "" : " \(tag)"
        return (["- [ ] \(firstLine)\(suffix)"] + continuation).joined(separator: "\n")
    }

    private func sourceContinuationLine(_ sourceURL: String?, content: String) -> String? {
        guard Settings.includeSource,
              let sourceURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              isWebURL(sourceURL),
              !content.contains(sourceURL),
              let link = markdownLinkForWebURL(sourceURL) else {
            return nil
        }
        return "> Source : \(link)"
    }

    private func normalizedTaskContent(_ value: String, tags: String) -> String? {
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
        if let markdownLink = markdownLinkForWebURL(content) {
            return markdownLink
        }
        return content
    }

    private func normalizedTags(_ value: String) -> String {
        normalizedPreferenceTags(value).joined(separator: " ")
    }

    private func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private func shell(_ args: [String], timeout: TimeInterval? = nil) -> String? {
        guard let executable = args.first else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(args.dropFirst())
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            if let timeout {
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.global(qos: .utility).async {
                    process.waitUntilExit()
                    semaphore.signal()
                }
                if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                    process.terminate()
                    return nil
                }
            } else {
                process.waitUntilExit()
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/NotePlanURLDrop.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }

    private func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NotePlan Editor (merged from NoteDroppy V3 / work/NoteDroppyV3/main.swift)

final class NotePlanEditorWindowController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    static var shared: NotePlanEditorWindowController?

    static func show() {
        if let shared {
            shared.showMainWindow()
            return
        }
        let controller = NotePlanEditorWindowController()
        controller.buildMenu()
        controller.buildUI()
        controller.window.delegate = controller
        shared = controller
        controller.showMainWindow()
        controller.loadTodayAsync()
        controller.window.makeFirstResponder(controller.textView)
    }

    private let window = NSWindow(
        contentRect: NSRect(x: 160, y: 120, width: 1100, height: 760),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )

    private let rootField = NSTextField()
    private let fileField = NSTextField()
    private let searchField = NSTextField()
    private let rangeStartField = NSTextField()
    private let rangeEndField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "Aucun fichier ouvert")
    private let textView = NSTextView()
    private let scrollView = NSScrollView()
    private let saveButton = NSButton(title: "Sauvegarder", target: nil, action: nil)
    private let reloadButton = NSButton(title: "Recharger", target: nil, action: nil)
    private var functionsWindow: NSWindow?
    private var openAfterFunctionCheckbox: NSButton?
    private var generatedShortcutURL: URL?
    private var editorMenu: NSMenu!

    private var rootURL: URL
    private var currentFileURL: URL?
    private var loadedContent = ""

    private struct LoadedFile {
        let relativePath: String
        let fileURL: URL
        let content: String
    }

    override init() {
        let defaultRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application Support/co.noteplan.NotePlan-setapp")
        rootURL = UserDefaults.standard.string(forKey: "noteplanRoot").map(URL.init(fileURLWithPath:)) ?? defaultRoot
        super.init()
    }

    private func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.mainMenu = editorMenu
    }

    func windowDidResignKey(_ notification: Notification) {
        NSApp.mainMenu = mainMenu
    }

    private func buildMenu() {
        let editorMainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "NoteDroppy")
        appMenu.addItem(NSMenuItem(title: "About NoteDroppy", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "Changelog", action: #selector(showChangelog), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "Fonctions NoteDroppy / NoteplanShorty", action: #selector(showFunctionsWindow), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Fermer l'éditeur", action: #selector(closeEditorWindow), keyEquivalent: "w"))
        appMenu.addItem(NSMenuItem(title: "Quitter NoteDroppy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        editorMainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Édition")
        editMenu.addItem(NSMenuItem(title: "Annuler", action: #selector(undoEdit), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Rétablir", action: #selector(redoEdit), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Tout sélectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        editorMainMenu.addItem(editMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "Fichier")
        fileMenu.addItem(NSMenuItem(title: "Ouvrir aujourd'hui", action: #selector(loadTodayAction), keyEquivalent: "t"))
        fileMenu.addItem(NSMenuItem(title: "Recharger", action: #selector(reloadFile), keyEquivalent: "r"))
        fileMenu.addItem(NSMenuItem(title: "Sauvegarder", action: #selector(saveFile), keyEquivalent: "s"))
        fileMenuItem.submenu = fileMenu
        editorMainMenu.addItem(fileMenuItem)

        editorMenu = editorMainMenu
    }

    @objc private func closeEditorWindow() {
        window.close()
    }

    private func buildUI() {
        window.title = "NoteDroppy - Éditeur NotePlan"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let rootLabel = NSTextField(labelWithString: "Dossier NotePlan")
        rootLabel.font = .systemFont(ofSize: 12, weight: .medium)

        rootField.stringValue = rootURL.path
        rootField.lineBreakMode = .byTruncatingMiddle
        rootField.target = self
        rootField.action = #selector(applyRootFromField)

        let fileLabel = NSTextField(labelWithString: "Fichier")
        fileLabel.font = .systemFont(ofSize: 12, weight: .medium)
        fileField.stringValue = todayPath()
        fileField.lineBreakMode = .byTruncatingMiddle
        fileField.target = self
        fileField.action = #selector(loadFileFromField)

        let chooseButton = NSButton(title: "Choisir...", target: self, action: #selector(chooseRoot))
        let applyButton = NSButton(title: "Appliquer", target: self, action: #selector(applyRootFromField))
        let loadButton = NSButton(title: "Charger", target: self, action: #selector(loadFileFromField))
        let todayButton = NSButton(title: "Aujourd'hui", target: self, action: #selector(loadTodayAction))
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(reloadFile))
        reloadButton.target = self
        reloadButton.action = #selector(reloadFile)
        saveButton.target = self
        saveButton.action = #selector(saveFile)
        saveButton.isEnabled = false
        let sortButton = NSButton(title: "Trier priorités", target: self, action: #selector(sortPriorities))
        let sortAtButton = NSButton(title: "Trier @", target: self, action: #selector(sortAtContext))
        let sortHashButton = NSButton(title: "Trier #", target: self, action: #selector(sortHashContext))
        let sortImportanceButton = NSButton(title: "Trier ^^", target: self, action: #selector(sortImportance))
        let sortMinutesButton = NSButton(title: "Trier --", target: self, action: #selector(sortMinutes))
        let flattenButton = NSButton(title: "Aplatir chapitres", target: self, action: #selector(flattenChapters))
        let fileActionsLabel = NSTextField(labelWithString: "Fichier")
        fileActionsLabel.font = .systemFont(ofSize: 12, weight: .medium)
        let sortLabel = NSTextField(labelWithString: "Tris")
        sortLabel.font = .systemFont(ofSize: 12, weight: .medium)
        let searchLabel = NSTextField(labelWithString: "Recherche")
        searchLabel.font = .systemFont(ofSize: 12, weight: .medium)
        searchField.placeholderString = "texte, @contexte ou #tag"
        searchField.target = self
        searchField.action = #selector(searchAllNotes)
        let searchButton = NSButton(title: "Chercher", target: self, action: #selector(searchAllNotes))
        let time15Button = NSButton(title: "<=15", target: self, action: #selector(search15))
        let time30Button = NSButton(title: "<=30", target: self, action: #selector(search30))
        let time60Button = NSButton(title: "<=60", target: self, action: #selector(search60))
        let timeMoreButton = NSButton(title: ">60", target: self, action: #selector(searchMore60))
        let rangeStartLabel = NSTextField(labelWithString: "Du")
        rangeStartLabel.font = .systemFont(ofSize: 12, weight: .medium)
        let rangeEndLabel = NSTextField(labelWithString: "Au")
        rangeEndLabel.font = .systemFont(ofSize: 12, weight: .medium)
        rangeStartField.stringValue = todayStamp()
        rangeEndField.stringValue = todayStamp()
        rangeStartField.placeholderString = "YYYYMMDD"
        rangeEndField.placeholderString = "YYYYMMDD"
        let flattenRangeButton = NSButton(title: "Aplatir plage", target: self, action: #selector(flattenDateRange))
        let functionsButton = NSButton(title: "FONCTIONS", target: self, action: #selector(showFunctionsWindow))
        functionsButton.bezelStyle = .rounded
        functionsButton.isBordered = false
        functionsButton.font = .systemFont(ofSize: 13, weight: .bold)
        functionsButton.wantsLayer = true
        functionsButton.layer?.backgroundColor = NSColor.systemGreen.cgColor
        functionsButton.layer?.cornerRadius = 6
        functionsButton.attributedTitle = NSAttributedString(
            string: "FONCTIONS",
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 13, weight: .bold)
            ]
        )

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        pathLabel.lineBreakMode = .byTruncatingMiddle

        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .controlAccentColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = self
        textView.string = ""

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .bezelBorder

        let topRow = NSStackView(views: [rootLabel, rootField, chooseButton, applyButton, functionsButton])
        topRow.orientation = .horizontal
        topRow.spacing = 8
        topRow.alignment = .centerY

        let fileRow = NSStackView(views: [fileLabel, fileField, loadButton])
        fileRow.orientation = .horizontal
        fileRow.spacing = 8
        fileRow.alignment = .centerY

        let fileActionRow = NSStackView(views: [fileActionsLabel, todayButton, reloadButton, refreshButton, saveButton])
        fileActionRow.orientation = .horizontal
        fileActionRow.spacing = 8
        fileActionRow.alignment = .centerY

        let sortRow = NSStackView(views: [sortLabel, sortButton, sortAtButton, sortHashButton, sortImportanceButton, sortMinutesButton, flattenButton])
        sortRow.orientation = .horizontal
        sortRow.spacing = 8
        sortRow.alignment = .centerY

        let searchRow = NSStackView(views: [searchLabel, searchField, searchButton, time15Button, time30Button, time60Button, timeMoreButton])
        searchRow.orientation = .horizontal
        searchRow.spacing = 8
        searchRow.alignment = .centerY

        let rangeRow = NSStackView(views: [rangeStartLabel, rangeStartField, rangeEndLabel, rangeEndField, flattenRangeButton])
        rangeRow.orientation = .horizontal
        rangeRow.spacing = 8
        rangeRow.alignment = .centerY

        let header = NSStackView(views: [topRow, fileRow, fileActionRow, sortRow, searchRow, rangeRow, pathLabel, statusLabel])
        header.orientation = .vertical
        header.spacing = 8
        header.alignment = .leading

        for view in [header, scrollView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            rootField.widthAnchor.constraint(greaterThanOrEqualToConstant: 620),
            fileField.widthAnchor.constraint(greaterThanOrEqualToConstant: 620),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
            rangeStartField.widthAnchor.constraint(equalToConstant: 110),
            rangeEndField.widthAnchor.constraint(equalToConstant: 110),
            functionsButton.widthAnchor.constraint(equalToConstant: 112),
            functionsButton.heightAnchor.constraint(equalToConstant: 28),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14)
        ])
    }

    private func todayPath() -> String {
        "Calendar/\(todayStamp()).md"
    }

    private func todayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }

    private func validateRoot(_ url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw NSError(domain: "NotePlanText", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dossier introuvable"])
        }
        let hasCalendar = FileManager.default.fileExists(atPath: url.appendingPathComponent("Calendar").path)
        let hasNotes = FileManager.default.fileExists(atPath: url.appendingPathComponent("Notes").path)
        guard hasCalendar || hasNotes else {
            throw NSError(domain: "NotePlanText", code: 2, userInfo: [NSLocalizedDescriptionKey: "Calendar ou Notes introuvable"])
        }
    }

    @objc private func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = rootURL
        if panel.runModal() == .OK, let url = panel.url {
            rootField.stringValue = url.path
            applyRoot(url)
        }
    }

    @objc private func applyRootFromField() {
        applyRoot(URL(fileURLWithPath: rootField.stringValue))
    }

    private func applyRoot(_ url: URL) {
        do {
            try validateRoot(url)
            rootURL = url
            UserDefaults.standard.set(url.path, forKey: "noteplanRoot")
            status("Dossier appliqué")
            loadToday()
        } catch {
            status("Erreur dossier: \(error.localizedDescription)")
        }
    }

    @objc private func loadTodayAction() {
        loadToday()
    }

    private func loadToday() {
        let path = todayPath()
        fileField.stringValue = path
        open(pathString: path, createIfMissing: true)
    }

    private func loadTodayAsync() {
        let path = todayPath()
        let root = rootURL
        fileField.stringValue = path
        status("Chargement du fichier du jour...")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loaded = try Self.readFile(pathString: path, rootURL: root, createIfMissing: true)
                DispatchQueue.main.async {
                    guard self.rootURL.path == root.path else { return }
                    self.applyLoadedFile(loaded)
                }
            } catch {
                DispatchQueue.main.async {
                    self.status("Erreur ouverture: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func loadFileFromField() {
        open(pathString: fileField.stringValue, createIfMissing: false)
    }

    private func open(pathString: String, createIfMissing: Bool) {
        do {
            let loaded = try Self.readFile(pathString: pathString, rootURL: rootURL, createIfMissing: createIfMissing)
            applyLoadedFile(loaded)
        } catch {
            status("Erreur ouverture: \(error.localizedDescription)")
        }
    }

    private static func readFile(pathString: String, rootURL: URL, createIfMissing: Bool) throws -> LoadedFile {
        try validateRoot(rootURL)
        let relativePath: String
        let fileURL: URL
        if pathString.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: pathString)
            guard fileURL.path.hasPrefix(rootURL.path + "/") else {
                throw NSError(domain: "NotePlanText", code: 3, userInfo: [NSLocalizedDescriptionKey: "Fichier hors dossier NotePlan"])
            }
            relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
        } else {
            relativePath = pathString.trimmingCharacters(in: .whitespacesAndNewlines)
            fileURL = rootURL.appendingPathComponent(relativePath)
        }
        if createIfMissing && !FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        let content = try readUTF8File(fileURL)
        return LoadedFile(relativePath: relativePath, fileURL: fileURL, content: content)
    }

    private static func readUTF8File(_ url: URL) throws -> String {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notedroppy-\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/cp")
        process.arguments = [url.path, tempURL.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        guard editorWait(process: process, timeout: 4.0) else {
            process.terminate()
            throw NSError(domain: "NotePlanText", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Lecture NotePlan bloquee par macOS"
            ])
        }
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "NotePlanText", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: errorText?.isEmpty == false ? errorText! : "Copie du fichier impossible"
            ])
        }

        return try String(contentsOf: tempURL, encoding: .utf8)
    }

    private static func validateRoot(_ url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw NSError(domain: "NotePlanText", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dossier introuvable"])
        }
        let hasCalendar = FileManager.default.fileExists(atPath: url.appendingPathComponent("Calendar").path)
        let hasNotes = FileManager.default.fileExists(atPath: url.appendingPathComponent("Notes").path)
        guard hasCalendar || hasNotes else {
            throw NSError(domain: "NotePlanText", code: 2, userInfo: [NSLocalizedDescriptionKey: "Calendar ou Notes introuvable"])
        }
    }

    private func applyLoadedFile(_ loaded: LoadedFile) {
        currentFileURL = loaded.fileURL
        loadedContent = loaded.content
        textView.string = loaded.content
        pathLabel.stringValue = loaded.relativePath
        fileField.stringValue = loaded.relativePath
        window.title = "NoteDroppy - Éditeur NotePlan - \(loaded.relativePath)"
        window.makeFirstResponder(textView)
        saveButton.isEnabled = false
        status("Fichier chargé et éditable")
    }

    @objc private func reloadFile() {
        guard let currentFileURL else { return }
        open(pathString: currentFileURL.path.replacingOccurrences(of: rootURL.path + "/", with: ""), createIfMissing: false)
    }

    @objc private func saveFile() {
        guard let fileURL = currentFileURL else { return }
        do {
            let disk = try String(contentsOf: fileURL, encoding: .utf8)
            guard disk == loadedContent else {
                status("Le fichier a changé sur disque. Recharge avant de sauvegarder.")
                return
            }
            try backup(fileURL: fileURL, content: disk)
            try textView.string.write(to: fileURL, atomically: true, encoding: .utf8)
            loadedContent = textView.string
            saveButton.isEnabled = false
            status("Sauvegardé")
        } catch {
            status("Erreur sauvegarde: \(error.localizedDescription)")
        }
    }

    @objc private func undoEdit() {
        if textView.undoManager?.canUndo == true {
            textView.undoManager?.undo()
            textDidChange(Notification(name: NSText.didChangeNotification))
            status("Undo")
        } else {
            status("Rien à annuler")
        }
    }

    @objc private func redoEdit() {
        if textView.undoManager?.canRedo == true {
            textView.undoManager?.redo()
            textDidChange(Notification(name: NSText.didChangeNotification))
            status("Redo")
        } else {
            status("Rien à rétablir")
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "NoteDroppy"
        alert.informativeText = """
        Éditeur NotePlan local (fusionné depuis NoteDroppy V3.7).

        App macOS locale pour éditer directement les fichiers Markdown NotePlan.

        Aucun cloud. Aucune API distante. Sauvegardes locales avant écriture.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func showChangelog() {
        let changelog = """
        Changelog éditeur (fusionné depuis NoteDroppy V3)

        - App macOS native AppKit.
        - Ouverture automatique de Calendar/YYYYMMDD.md au lancement.
        - Choix du dossier NotePlan.
        - Chargement manuel d'un fichier relatif ou absolu.
        - Édition texte directe.
        - Sauvegarde avec backup dans .codex-backups.
        - Protection si le fichier a changé sur disque.
        - Tri des priorités.
        - Aplatissement des chapitres en liste unique.
        - Aplatissement sur plage de jours.
        - Menu Édition avec Annuler/Rétablir.
        - Barre de tri: @, #, ^^, --.
        - Recherche agenda avec tranches de temps <=15, <=30, <=60, >60.
        """
        let alert = NSAlert()
        alert.messageText = "Changelog"
        alert.informativeText = changelog
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func showFunctionsWindow() {
        if let functionsWindow {
            functionsWindow.makeKeyAndOrderFront(nil)
            functionsWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let infoWindow = NSWindow(
            contentRect: NSRect(x: 220, y: 160, width: 820, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        infoWindow.isReleasedWhenClosed = false
        infoWindow.title = "Fonctions NoteDroppy / NoteplanShorty"

        let titleLabel = NSTextField(labelWithString: "Fonctions")
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)

        let subtitleLabel = NSTextField(labelWithString: "Actions locales. Les écritures NotePlan demandent une validation avant modification.")
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping

        let openCheckbox = NSButton(checkboxWithTitle: "Ouvrir NotePlan après action", target: self, action: #selector(toggleOpenAfterFunction))
        openCheckbox.state = UserDefaults.standard.bool(forKey: "functionsOpenNotePlanAfterAction") ? .on : .off
        openAfterFunctionCheckbox = openCheckbox

        let noteDroppyRows = [
            functionRow(title: "Ajouter une tâche à aujourd’hui", detail: "Demande le texte, confirme, puis ajoute dans Calendar/\(todayStamp()).md.", action: #selector(addTaskToToday)),
            functionRow(title: "Ajouter une URL à aujourd’hui", detail: "Demande une URL et écrit le serveur avant le lien.", action: #selector(addURLToToday)),
            functionRow(title: "Ajouter du texte sélectionné à aujourd’hui", detail: "Récupère le texte du presse-papiers courant, demande validation, puis ajoute.", action: #selector(addSelectedTextToToday)),
            functionRow(title: "Rechercher dans les notes", detail: "Cherche localement dans Calendar et Notes.", action: #selector(searchNotesFromFunctions))
        ]

        let shortyRows = [
            functionRow(title: "Choisir une note `.md`", detail: "Sélectionne une note Markdown source.", action: #selector(chooseShortcutNote)),
            functionRow(title: "Choisir une destination", detail: "Sélectionne un dossier destination pour le raccourci.", action: #selector(chooseShortcutDestination)),
            functionRow(title: "Générer un raccourci `.app`", detail: "Choisit note et destination, confirme le remplacement, puis génère le .app.", action: #selector(generateShortcutApp)),
            functionRow(title: "Confirmer avant remplacement", detail: "Intégré au générateur: aucun remplacement sans accord.", action: #selector(generateShortcutApp)),
            functionRow(title: "Révéler le raccourci généré dans Finder", detail: "Sélectionne le dernier .app généré dans Finder.", action: #selector(revealGeneratedShortcut))
        ]

        let noteDroppySection = section(title: "NOTE DROPPY", rows: noteDroppyRows + [openCheckbox])
        let shortySection = section(title: "NOTEPLANSHORTY", rows: shortyRows)

        let stack = NSStackView(views: [titleLabel, subtitleLabel, noteDroppySection, shortySection])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        infoWindow.contentView = content
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
            subtitleLabel.widthAnchor.constraint(equalToConstant: 760)
        ])

        functionsWindow = infoWindow
        infoWindow.makeKeyAndOrderFront(nil)
        infoWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func section(title: String, rows: [NSView]) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [label] + rows)
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }

    private func functionRow(title: String, detail: String, action: Selector) -> NSView {
        let button = greenButton(title: "LANCER", action: action)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping

        let labels = NSStackView(views: [titleLabel, detailLabel])
        labels.orientation = .vertical
        labels.spacing = 2
        labels.alignment = .leading

        let row = NSStackView(views: [button, labels])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 96),
            button.heightAnchor.constraint(equalToConstant: 28),
            labels.widthAnchor.constraint(equalToConstant: 650)
        ])
        return row
    }

    private func greenButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.systemGreen.cgColor
        button.layer?.cornerRadius = 6
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 12, weight: .bold)
            ]
        )
        return button
    }

    @objc private func toggleOpenAfterFunction() {
        UserDefaults.standard.set(openAfterFunctionCheckbox?.state == .on, forKey: "functionsOpenNotePlanAfterAction")
    }

    @objc private func addTaskToToday() {
        guard let text = promptText(title: "Ajouter une tâche", message: "Texte de la tâche") else {
            status("Ajout annulé")
            return
        }
        let task = "- [ ] \(stripLeadingTaskMarker(text))"
        appendToTodayAfterConfirmation(task, actionName: "Ajouter cette tâche ?")
    }

    @objc private func addURLToToday() {
        let pasteboardURL = NSPasteboard.general.string(forType: .string).flatMap { EditorURLLineFormatter.normalizedWebURL($0) } ?? ""
        guard let text = promptText(title: "Ajouter une URL", message: "URL", defaultValue: pasteboardURL) else {
            status("Ajout URL annulé")
            return
        }
        guard let normalized = EditorURLLineFormatter.normalizedWebURL(text) else {
            status("URL invalide")
            return
        }
        let task = "- [ ] \(EditorURLLineFormatter.withHostPrefix(normalized))"
        appendToTodayAfterConfirmation(task, actionName: "Ajouter cette URL ?")
    }

    @objc private func addSelectedTextToToday() {
        let clipboardText = NSPasteboard.general.string(forType: .string) ?? ""
        guard let text = promptText(title: "Ajouter le texte sélectionné", message: "Texte à ajouter", defaultValue: clipboardText) else {
            status("Ajout texte annulé")
            return
        }
        let task = "- [ ] \(stripLeadingTaskMarker(text))"
        appendToTodayAfterConfirmation(task, actionName: "Ajouter ce texte ?")
    }

    @objc private func searchNotesFromFunctions() {
        guard let query = promptText(title: "Rechercher dans les notes", message: "Recherche", defaultValue: searchField.stringValue) else {
            status("Recherche annulée")
            return
        }
        searchField.stringValue = query
        do {
            let results = try EditorTaskSearch.search(rootURL: rootURL, query: query, bucket: nil, scope: .calendarAndNotes)
            showSearchResults(results, title: "Recherche Calendar + Notes")
        } catch {
            status("Erreur recherche: \(error.localizedDescription)")
        }
    }

    @objc private func chooseShortcutNote() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }
        panel.directoryURL = rootURL
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: "noteplanShortyNotePath")
            status("Note choisie: \(url.lastPathComponent)")
        }
    }

    @objc private func chooseShortcutDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: "noteplanShortyDestinationPath")
            status("Destination choisie: \(url.path)")
        }
    }

    @objc private func generateShortcutApp() {
        let noteURL: URL
        if let saved = UserDefaults.standard.string(forKey: "noteplanShortyNotePath"), FileManager.default.fileExists(atPath: saved) {
            noteURL = URL(fileURLWithPath: saved)
        } else {
            chooseShortcutNote()
            guard let saved = UserDefaults.standard.string(forKey: "noteplanShortyNotePath") else { return }
            noteURL = URL(fileURLWithPath: saved)
        }

        let destinationURL: URL
        if let saved = UserDefaults.standard.string(forKey: "noteplanShortyDestinationPath") {
            destinationURL = URL(fileURLWithPath: saved)
        } else {
            chooseShortcutDestination()
            guard let saved = UserDefaults.standard.string(forKey: "noteplanShortyDestinationPath") else { return }
            destinationURL = URL(fileURLWithPath: saved)
        }

        do {
            let result = try EditorNotePlanShortcutGenerator.generate(
                noteURL: noteURL,
                destinationURL: destinationURL,
                confirmReplace: confirmShortcutReplacement(appURL:)
            )
            generatedShortcutURL = result.appURL
            status("Raccourci généré: \(result.appURL.path)")
            askRevealShortcut(result.appURL)
        } catch EditorNotePlanShortcutError.cancelled {
            status("Génération annulée")
        } catch {
            status("Erreur raccourci: \(error.localizedDescription)")
        }
    }

    @objc private func revealGeneratedShortcut() {
        guard let generatedShortcutURL else {
            status("Aucun raccourci généré")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([generatedShortcutURL])
        status("Raccourci révélé dans Finder")
    }

    private func promptText(title: String, message: String, defaultValue: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Continuer")
        alert.addButton(withTitle: "Annuler")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func appendToTodayAfterConfirmation(_ line: String, actionName: String) {
        let fileURL = rootURL.appendingPathComponent(todayPath())
        let alert = NSAlert()
        alert.messageText = actionName
        alert.informativeText = "\(todayPath())\n\n\(line)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Ajouter")
        alert.addButton(withTitle: "Annuler")
        guard alert.runModal() == .alertFirstButtonReturn else {
            status("Écriture annulée")
            return
        }

        do {
            try validateRoot(rootURL)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let original = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            try backup(fileURL: fileURL, content: original)
            let prefix = original.isEmpty || original.hasSuffix("\n") ? "" : "\n"
            let payload = "\(prefix)\(line)\n"
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(payload.utf8))
            } else {
                try payload.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            if currentFileURL?.path == fileURL.path || currentFileURL == nil {
                open(pathString: todayPath(), createIfMissing: true)
            }
            if UserDefaults.standard.bool(forKey: "functionsOpenNotePlanAfterAction") {
                openTodayInNotePlan()
            }
            status("Ajouté dans \(todayPath())")
        } catch {
            status("Erreur ajout: \(error.localizedDescription)")
        }
    }

    private func confirmShortcutReplacement(appURL: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Remplacer le raccourci existant ?"
        alert.informativeText = appURL.path
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remplacer")
        alert.addButton(withTitle: "Annuler")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func askRevealShortcut(_ appURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Raccourci généré"
        alert.informativeText = appURL.path
        alert.addButton(withTitle: "Révéler dans Finder")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([appURL])
        }
    }

    private func openTodayInNotePlan() {
        if let url = URL(string: "noteplan://x-callback-url/openNote?noteDate=today") {
            NSWorkspace.shared.open(url)
        }
    }

    private func stripLeadingTaskMarker(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\s*[-*]\s+\[[ xX]\]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
    }

    private func backup(fileURL: URL, content: String) throws {
        let backupDir = rootURL.appendingPathComponent(".codex-backups")
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let relative = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "").replacingOccurrences(of: "/", with: "__")
        try content.write(to: backupDir.appendingPathComponent("\(stamp)__\(relative)"), atomically: true, encoding: .utf8)
    }

    @objc private func sortPriorities() {
        replaceEditorText(EditorPrioritySorter.sort(textView.string))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortMinutes() {
        replaceEditorText(EditorTaskSorter.sort(textView.string, mode: .minutes))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri -- appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortAtContext() {
        replaceEditorText(EditorTaskSorter.sort(textView.string, mode: .atContext))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri @ appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortHashContext() {
        replaceEditorText(EditorTaskSorter.sort(textView.string, mode: .hashTag))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri # appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortImportance() {
        replaceEditorText(EditorTaskSorter.sort(textView.string, mode: .importance))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri ^^ appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func flattenChapters() {
        replaceEditorText(EditorChapterFlattener.flatten(textView.string))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Chapitres aplatis en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func flattenDateRange() {
        do {
            try validateRoot(rootURL)
            let dates = try calendarDates(from: rangeStartField.stringValue, to: rangeEndField.stringValue)
            let alert = NSAlert()
            alert.messageText = "Aplatir \(dates.count) note(s) journalière(s) ?"
            alert.informativeText = "Chaque fichier existant sera sauvegardé dans .codex-backups avant modification."
            alert.addButton(withTitle: "Aplatir")
            alert.addButton(withTitle: "Annuler")
            guard alert.runModal() == .alertFirstButtonReturn else {
                status("Plage annulée")
                return
            }

            var changed = 0
            var missing = 0
            for date in dates {
                let fileURL = rootURL.appendingPathComponent("Calendar/\(date).md")
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    missing += 1
                    continue
                }
                let original = try String(contentsOf: fileURL, encoding: .utf8)
                let flattened = EditorChapterFlattener.flatten(original)
                guard flattened != original else { continue }
                try backup(fileURL: fileURL, content: original)
                try flattened.write(to: fileURL, atomically: true, encoding: .utf8)
                changed += 1
            }
            reloadFile()
            status("Plage traitée: \(changed) modifiée(s), \(missing) absente(s)")
        } catch {
            status("Erreur plage: \(error.localizedDescription)")
        }
    }

    @objc private func searchAllNotes() {
        do {
            let results = try EditorTaskSearch.search(rootURL: rootURL, query: searchField.stringValue, bucket: nil, scope: .calendarOnly)
            showSearchResults(results, title: "Recherche agenda")
        } catch {
            status("Erreur recherche: \(error.localizedDescription)")
        }
    }

    @objc private func search15() {
        searchTimeBucket(.max(15), label: "Tâches <= 15 min")
    }

    @objc private func search30() {
        searchTimeBucket(.max(30), label: "Tâches <= 30 min")
    }

    @objc private func search60() {
        searchTimeBucket(.max(60), label: "Tâches <= 60 min")
    }

    @objc private func searchMore60() {
        searchTimeBucket(.moreThan(60), label: "Tâches > 60 min")
    }

    private func searchTimeBucket(_ bucket: EditorTaskSearch.Bucket, label: String) {
        do {
            let results = try EditorTaskSearch.search(rootURL: rootURL, query: searchField.stringValue, bucket: bucket, scope: .calendarAndNotes)
            showSearchResults(results, title: label)
        } catch {
            status("Erreur recherche: \(error.localizedDescription)")
        }
    }

    private func showSearchResults(_ results: [EditorTaskSearch.Result], title: String) {
        let lines = results.map { "- \(EditorURLLineFormatter.withHostPrefix($0.text)) [\($0.path):\($0.line)]" }
        let output = "# \(title)\n\n" + (lines.isEmpty ? "Aucun résultat\n" : lines.joined(separator: "\n") + "\n")
        replaceEditorText(output)
        currentFileURL = nil
        loadedContent = output
        saveButton.isEnabled = false
        pathLabel.stringValue = "Résultats de recherche non sauvegardables"
        window.title = "NoteDroppy - Éditeur NotePlan - \(title)"
        status("\(results.count) résultat(s)")
    }

    private func replaceEditorText(_ newText: String) {
        guard let storage = textView.textStorage else {
            textView.string = newText
            return
        }
        let oldText = textView.string
        let range = NSRange(location: 0, length: storage.length)
        textView.undoManager?.registerUndo(withTarget: self) { target in
            target.replaceEditorText(oldText)
        }
        storage.replaceCharacters(in: range, with: newText)
    }

    func textDidChange(_ notification: Notification) {
        saveButton.isEnabled = currentFileURL != nil && textView.string != loadedContent
    }

    private func status(_ text: String) {
        statusLabel.stringValue = text
    }

    private func calendarDates(from start: String, to end: String) throws -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let startDate = formatter.date(from: start.trimmingCharacters(in: .whitespacesAndNewlines)),
              let endDate = formatter.date(from: end.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw NSError(domain: "NotePlanText", code: 4, userInfo: [NSLocalizedDescriptionKey: "Dates invalides: utiliser YYYYMMDD"])
        }
        guard startDate <= endDate else {
            throw NSError(domain: "NotePlanText", code: 5, userInfo: [NSLocalizedDescriptionKey: "La date Du doit être avant Au"])
        }
        var dates: [String] = []
        var current = startDate
        let calendar = Calendar.current
        while current <= endDate {
            dates.append(formatter.string(from: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }
}

private func editorWait(process: Process, timeout: TimeInterval) -> Bool {
    let semaphore = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in semaphore.signal() }
    return semaphore.wait(timeout: .now() + timeout) == .success
}

enum EditorPrioritySorter {
    struct Block {
        let originalIndex: Int
        var lines: [String]
        var main: String { lines.first ?? "" }
    }

    static func sort(_ text: String) -> String {
        let hadTrailingNewline = text.hasSuffix("\n")
        let lines = text.components(separatedBy: "\n")
        var output: [String] = []
        var finished: [Block] = []
        var i = 0

        while i < lines.count {
            if isHeading(lines[i]) {
                output.append(lines[i])
                i += 1
                continue
            }
            if isTopBullet(lines[i]) {
                var blocks: [Block] = []
                let startCount = output.count
                while i < lines.count && !isHeading(lines[i]) {
                    if lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                        flush(blocks: &blocks, into: &output, finished: &finished)
                        output.append(lines[i])
                        i += 1
                    } else if isTopBullet(lines[i]) {
                        var blockLines = [normalizeMain(lines[i])]
                        i += 1
                        while i < lines.count && !isHeading(lines[i]) && !isTopBullet(lines[i]) {
                            blockLines.append(lines[i])
                            i += 1
                        }
                        blocks.append(Block(originalIndex: blocks.count + startCount, lines: blockLines))
                    } else {
                        flush(blocks: &blocks, into: &output, finished: &finished)
                        output.append(lines[i])
                        i += 1
                    }
                }
                flush(blocks: &blocks, into: &output, finished: &finished)
            } else {
                output.append(lines[i])
                i += 1
            }
        }

        while output.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            output.removeLast()
        }
        if !finished.isEmpty {
            output.append("")
            output.append(contentsOf: finished.flatMap(\.lines))
        }
        let result = output.joined(separator: "\n")
        return hadTrailingNewline ? result + "\n" : result
    }

    private static func flush(blocks: inout [Block], into output: inout [String], finished: inout [Block]) {
        let sorted = blocks.sorted { a, b in
            let ap = priority(a.main)
            let bp = priority(b.main)
            if ap != bp { return ap > bp }
            return a.originalIndex < b.originalIndex
        }
        for block in sorted {
            if isFullyDone(block) {
                finished.append(block)
            } else {
                output.append(contentsOf: block.lines)
            }
        }
        blocks.removeAll()
    }

    private static func isHeading(_ line: String) -> Bool {
        line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil
    }

    private static func isTopBullet(_ line: String) -> Bool {
        line.range(of: #"^[-*](\s|$)"#, options: .regularExpression) != nil
    }

    private static func normalizeMain(_ line: String) -> String {
        if line.range(of: #"^\*\s+\[[ xX]\]"#, options: .regularExpression) != nil {
            return "-" + String(line.dropFirst())
        }
        if line.range(of: #"^\*\s+"#, options: .regularExpression) != nil {
            return line.replacingOccurrences(of: #"^\*\s+"#, with: "- [ ] ", options: .regularExpression)
        }
        if line.range(of: #"^-\s+(?!\[[ xX]\]).*!"#, options: .regularExpression) != nil {
            return line.replacingOccurrences(of: #"^-\s+"#, with: "- [ ] ", options: .regularExpression)
        }
        return line
    }

    private static func priority(_ line: String) -> Int {
        guard let range = line.range(of: #"^[-*]\s+(?:\[[ xX]\]\s*)?(!{1,3})(?=\s|$)"#, options: .regularExpression) else {
            return 0
        }
        return line[range].filter { $0 == "!" }.count
    }

    private static func isFullyDone(_ block: Block) -> Bool {
        guard block.main.range(of: #"^[-*]\s+\[[xX]\]"#, options: .regularExpression) != nil else {
            return false
        }
        for line in block.lines.dropFirst() {
            if line.range(of: #"^\s+[-*]\s+\[\s\]"#, options: .regularExpression) != nil {
                return false
            }
        }
        return true
    }
}

enum EditorTaskSorter {
    enum Mode: Equatable {
        case atContext
        case hashTag
        case importance
        case minutes
    }

    struct Block {
        let originalIndex: Int
        let lines: [String]
        var main: String { lines.first ?? "" }
    }

    static func sort(_ text: String, mode: Mode) -> String {
        let hadTrailingNewline = text.hasSuffix("\n")
        let lines = text.components(separatedBy: "\n")
        var blocks: [Block] = []
        var loose: [String] = []
        var i = 0

        while i < lines.count {
            if isTopBullet(lines[i]) {
                var blockLines = [lines[i]]
                i += 1
                while i < lines.count && !isTopBullet(lines[i]) {
                    blockLines.append(lines[i])
                    i += 1
                }
                blocks.append(Block(originalIndex: blocks.count, lines: blockLines))
            } else {
                loose.append(lines[i])
                i += 1
            }
        }

        let sortableBlocks: [Block]
        let unsortedBlocks: [Block]
        if mode == .minutes {
            sortableBlocks = blocks.filter { isTask($0.main) && minutes($0.main) != Int.max }
            unsortedBlocks = blocks.filter { !(isTask($0.main) && minutes($0.main) != Int.max) }
        } else if mode == .importance {
            sortableBlocks = blocks.filter { isTask($0.main) && importance($0.main) != Int.max }
            unsortedBlocks = blocks.filter { !(isTask($0.main) && importance($0.main) != Int.max) }
        } else {
            sortableBlocks = blocks
            unsortedBlocks = []
        }

        let sorted = sortableBlocks.sorted { a, b in
            let ad = isDone(a.main)
            let bd = isDone(b.main)
            if ad != bd { return !ad && bd }

            switch mode {
            case .atContext:
                let ac = token(a.main, prefix: "@")
                let bc = token(b.main, prefix: "@")
                if ac != bc { return ac < bc }
                let am = minutes(a.main)
                let bm = minutes(b.main)
                if am != bm { return am < bm }
            case .hashTag:
                let ac = token(a.main, prefix: "#")
                let bc = token(b.main, prefix: "#")
                if ac != bc { return ac < bc }
                let am = minutes(a.main)
                let bm = minutes(b.main)
                if am != bm { return am < bm }
            case .importance:
                let ai = importance(a.main)
                let bi = importance(b.main)
                if ai != bi { return ai < bi }
                let am = minutes(a.main)
                let bm = minutes(b.main)
                if am != bm { return am < bm }
            case .minutes:
                let am = minutes(a.main)
                let bm = minutes(b.main)
                if am != bm { return am < bm }
                return a.originalIndex < b.originalIndex
            }

            let ap = priority(a.main)
            let bp = priority(b.main)
            if ap != bp { return ap > bp }
            return a.originalIndex < b.originalIndex
        }

        var output = loose.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !output.isEmpty && !sorted.isEmpty { output.append("") }
        output.append(contentsOf: sorted.flatMap(\.lines))
        if !unsortedBlocks.isEmpty {
            if !output.isEmpty { output.append("") }
            output.append(contentsOf: unsortedBlocks.sorted { $0.originalIndex < $1.originalIndex }.flatMap(\.lines))
        }
        let result = output.joined(separator: "\n")
        return hadTrailingNewline ? result + "\n" : result
    }

    static func isTask(_ line: String) -> Bool {
        line.range(of: #"^\s*[-*]\s+\[[ xX]\]"#, options: .regularExpression) != nil
    }

    static func isDone(_ line: String) -> Bool {
        line.range(of: #"^\s*[-*]\s+\[[xX]\]"#, options: .regularExpression) != nil
    }

    static func minutes(_ line: String) -> Int {
        guard let range = line.range(of: #"--\s*\d+\b"#, options: .regularExpression) else {
            return Int.max
        }
        let value = line[range].replacingOccurrences(of: #"--\s*"#, with: "", options: .regularExpression)
        return Int(value) ?? Int.max
    }

    static func importance(_ line: String) -> Int {
        guard let range = line.range(of: #"\^\^\s*[ABCabc123]\b"#, options: .regularExpression) else {
            return Int.max
        }
        let raw = line[range]
            .replacingOccurrences(of: #"^\^\^\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        switch raw {
        case "A", "1":
            return 1
        case "B", "2":
            return 2
        case "C", "3":
            return 3
        default:
            return Int.max
        }
    }

    private static func isTopBullet(_ line: String) -> Bool {
        line.range(of: #"^\s*[-*](\s|$)"#, options: .regularExpression) != nil
    }

    private static func token(_ line: String, prefix: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: prefix)
        if let range = line.range(of: "\(escaped)[A-Za-z0-9_À-ÿ-]+", options: .regularExpression) {
            return String(line[range]).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
        return "zz_sans_\(prefix)"
    }

    private static func priority(_ line: String) -> Int {
        guard let range = line.range(of: #"!{1,3}"#, options: .regularExpression) else {
            return 0
        }
        return line[range].filter { $0 == "!" }.count
    }
}

enum EditorTaskSearch {
    enum Scope {
        case calendarOnly
        case calendarAndNotes
    }

    enum Bucket {
        case max(Int)
        case moreThan(Int)
    }

    struct Result {
        let path: String
        let line: Int
        let text: String
    }

    static func search(rootURL: URL, query: String, bucket: Bucket?, scope: Scope) throws -> [Result] {
        let files = try markdownFiles(rootURL: rootURL, scope: scope)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var results: [Result] = []

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let rel = file.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            for (index, line) in content.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard isTaskLine(trimmed), !EditorTaskSorter.isDone(trimmed) else { continue }
                if !normalizedQuery.isEmpty && !trimmed.lowercased().contains(normalizedQuery) { continue }
                if let bucket, !matches(bucket: bucket, minutes: EditorTaskSorter.minutes(trimmed)) { continue }
                results.append(Result(path: rel, line: index + 1, text: trimmed))
            }
        }

        return results.sorted {
            let am = EditorTaskSorter.minutes($0.text)
            let bm = EditorTaskSorter.minutes($1.text)
            if am != bm { return am < bm }
            if $0.path != $1.path { return $0.path < $1.path }
            return $0.line < $1.line
        }
    }

    private static func markdownFiles(rootURL: URL, scope: Scope) throws -> [URL] {
        let rootNames: [String]
        switch scope {
        case .calendarOnly:
            rootNames = ["Calendar"]
        case .calendarAndNotes:
            rootNames = ["Calendar", "Notes"]
        }
        let roots = rootNames.map { rootURL.appendingPathComponent($0) }
        var output: [URL] = []
        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let file as URL in enumerator {
                let path = file.path
                if path.contains("/@Trash/") || path.contains("/Backups/") || path.contains("/Plugins/") || path.contains("/Logs/") {
                    continue
                }
                if file.pathExtension.lowercased() == "md" {
                    output.append(file)
                }
            }
        }
        return output
    }

    private static func isTaskLine(_ line: String) -> Bool {
        line.range(of: #"^\s*[-*]\s+"#, options: .regularExpression) != nil
    }

    private static func matches(bucket: Bucket, minutes: Int) -> Bool {
        guard minutes != Int.max else { return false }
        switch bucket {
        case .max(let value):
            return minutes <= value
        case .moreThan(let value):
            return minutes > value
        }
    }
}

enum EditorChapterFlattener {
    struct Item {
        let text: String
        let chapter: String
        let priority: Int
        let index: Int
    }

    static func flatten(_ text: String) -> String {
        var currentChapter: String?
        var items: [Item] = []

        for (index, rawLine) in text.components(separatedBy: "\n").enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            if let heading = headingTitle(line) {
                currentChapter = heading
                continue
            }

            let detectedPriority = priority(line)
            let item = EditorURLLineFormatter.withHostPrefix(cleanedItem(line))
            if item.isEmpty { continue }
            let chapter = currentChapter ?? "Sans chapitre"
            items.append(Item(text: item, chapter: chapter, priority: detectedPriority, index: index))
        }

        let prioritized = items
            .filter { $0.priority > 0 }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.index < $1.index
            }
        let normal = items.filter { $0.priority == 0 }.sorted { $0.index < $1.index }
        let output = (prioritized + normal).map { item in
            if item.chapter.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == "taches prioritaires" {
                return "- \(item.text)"
            }
            return "- \(item.text) (\(item.chapter))"
        }
        return output.joined(separator: "\n") + (output.isEmpty ? "" : "\n")
    }

    private static func headingTitle(_ line: String) -> String? {
        guard let range = line.range(of: #"^#{1,6}\s+.+"#, options: .regularExpression) else {
            return nil
        }
        let heading = String(line[range])
            .replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return heading.isEmpty ? nil : heading
    }

    private static func cleanedItem(_ line: String) -> String {
        var item = line.trimmingCharacters(in: .whitespacesAndNewlines)
        item = item.replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
        item = item.replacingOccurrences(of: #"^\[[ xX]\]\s+"#, with: "", options: .regularExpression)
        item = item.replacingOccurrences(of: #"^!{1,3}\s+"#, with: "", options: .regularExpression)
        return item.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func priority(_ line: String) -> Int {
        let cleaned = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\[[ xX]\]\s+"#, with: "", options: .regularExpression)
        guard let range = cleaned.range(of: #"^!{1,3}(?=\s|$)"#, options: .regularExpression) else {
            return 0
        }
        return cleaned[range].filter { $0 == "!" }.count
    }
}

enum EditorURLLineFormatter {
    static func normalizedWebURL(_ value: String) -> String? {
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

    static func withHostPrefix(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let urlRange = trimmed.range(of: #"https?://[^\s)\]]+"#, options: .regularExpression) else {
            return trimmed
        }
        let urlText = String(trimmed[urlRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
        guard let url = URL(string: urlText), let host = url.host, !host.isEmpty else {
            return trimmed
        }
        let cleanHost = host.replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
        if trimmed.hasPrefix(cleanHost + " ") || trimmed.hasPrefix(cleanHost + " - ") {
            return trimmed
        }
        return "\(cleanHost) \(trimmed)"
    }
}

enum EditorNotePlanShortcutError: LocalizedError {
    case notMarkdown
    case emptyNoteName
    case cancelled
    case verificationFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notMarkdown:
            return "Le fichier choisi doit être une note .md."
        case .emptyNoteName:
            return "Le nom de la note est vide."
        case .cancelled:
            return "Opération annulée."
        case .verificationFailed(let message), .commandFailed(let message):
            return message
        }
    }
}

struct EditorShortcutResult {
    let noteName: String
    let noteURLString: String
    let appURL: URL
}

struct EditorNotePlanShortcutGenerator {
    static func generate(
        noteURL: URL,
        destinationURL: URL,
        confirmReplace: (URL) -> Bool = { _ in true }
    ) throws -> EditorShortcutResult {
        guard noteURL.pathExtension.lowercased() == "md" else {
            throw EditorNotePlanShortcutError.notMarkdown
        }

        let noteName = noteURL.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
        guard !noteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EditorNotePlanShortcutError.emptyNoteName
        }

        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let appURL = destinationURL.appendingPathComponent("\(noteName).app", isDirectory: true)
        if FileManager.default.fileExists(atPath: appURL.path) {
            guard confirmReplace(appURL) else {
                throw EditorNotePlanShortcutError.cancelled
            }
            try FileManager.default.removeItem(at: appURL)
        }

        let noteURLString = "noteplan://x-callback-url/openNote?noteTitle=\(urlEncode(noteName))"
        let finalAppPath = destinationURL.path + "/" + noteName + ".app"
        try compileShortcutApp(
            noteURLString: noteURLString,
            appName: noteName,
            finalAppPath: finalAppPath,
            destinationDir: destinationURL
        )
        try verify(appURL: appURL, noteName: noteName, noteURLString: noteURLString)

        return EditorShortcutResult(noteName: noteName, noteURLString: noteURLString, appURL: appURL)
    }

    private static func compileShortcutApp(noteURLString: String, appName: String, finalAppPath: String, destinationDir: URL) throws {
        let script = """
        tell application "NotePlan" to activate
        open location "\(noteURLString)"
        """
        let tempAppURL = destinationDir.appendingPathComponent(".nps-tmp-\(UUID().uuidString).app")

        do {
            try run("/usr/bin/osacompile", ["-o", tempAppURL.path, "-e", script])
            let plistURL = tempAppURL.appendingPathComponent("Contents/Info.plist")
            try setPlistStrings(
                [
                    "CFBundleName": appName,
                    "CFBundleDisplayName": appName,
                    "NotePlanShortcutURL": noteURLString
                ],
                plistURL: plistURL
            )
            try renamePreservingUnicode(fromPath: tempAppURL.path, toPath: finalAppPath)
        } catch {
            try? FileManager.default.removeItem(at: tempAppURL)
            throw error
        }
    }

    private static func setPlistStrings(_ values: [String: String], plistURL: URL) throws {
        let data = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw EditorNotePlanShortcutError.commandFailed("Info.plist illisible: \(plistURL.path)")
        }
        for (key, value) in values {
            plist[key] = value
        }
        let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try newData.write(to: plistURL)
    }

    private static func renamePreservingUnicode(fromPath: String, toPath: String) throws {
        let result = fromPath.withCString { src in
            toPath.withCString { dst in
                rename(src, dst)
            }
        }
        guard result == 0 else {
            throw EditorNotePlanShortcutError.commandFailed("rename() a échoué: \(String(cString: strerror(errno)))")
        }
    }

    private static func verify(appURL: URL, noteName: String, noteURLString: String) throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw EditorNotePlanShortcutError.verificationFailed("Vérification échouée: le dossier .app n'existe pas.")
        }
        guard appURL.lastPathComponent == "\(noteName).app" else {
            throw EditorNotePlanShortcutError.verificationFailed("Vérification échouée: nom .app incorrect.")
        }

        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let bundleName = try plistValue("CFBundleName", plistURL: plistURL)
        let displayName = try plistValue("CFBundleDisplayName", plistURL: plistURL)
        let storedURL = try plistValue("NotePlanShortcutURL", plistURL: plistURL)

        guard bundleName == noteName else {
            throw EditorNotePlanShortcutError.verificationFailed("Vérification échouée: CFBundleName incorrect.")
        }
        guard displayName == noteName else {
            throw EditorNotePlanShortcutError.verificationFailed("Vérification échouée: CFBundleDisplayName incorrect.")
        }
        guard storedURL == noteURLString else {
            throw EditorNotePlanShortcutError.verificationFailed("Vérification échouée: URL NotePlan incorrecte.")
        }
    }

    private static func plistValue(_ key: String, plistURL: URL) throws -> String {
        try runAndCapture("/usr/bin/plutil", ["-extract", key, "raw", plistURL.path])
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        _ = try runAndCapture(executable, arguments)
    }

    private static func runAndCapture(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw EditorNotePlanShortcutError.commandFailed(errorText.isEmpty ? outputText : errorText)
        }
        return outputText
    }

    static func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.servicesProvider = delegate

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "À propos de NoteDroppy", action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")
appMenu.addItem(NSMenuItem.separator())
appMenu.addItem(withTitle: "Réglages...", action: #selector(AppDelegate.showSettingsWindowFromMenu(_:)), keyEquivalent: ",")
appMenu.addItem(withTitle: "Éditeur NotePlan...", action: #selector(AppDelegate.showEditorWindowFromMenu(_:)), keyEquivalent: "e")
appMenu.addItem(NSMenuItem.separator())
appMenu.addItem(withTitle: "Quitter NoteDroppy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appMenuItem.submenu = appMenu
app.mainMenu = mainMenu

let helpMenuItem = NSMenuItem()
mainMenu.addItem(helpMenuItem)
let helpMenu = NSMenu(title: "Aide")
helpMenu.addItem(withTitle: "Aide NoteDroppy", action: #selector(AppDelegate.openHelp(_:)), keyEquivalent: "")
helpMenu.addItem(withTitle: "Help NoteDroppy English", action: #selector(AppDelegate.openEnglishHelp(_:)), keyEquivalent: "")
helpMenu.addItem(NSMenuItem.separator())
helpMenu.addItem(withTitle: "GitHub Repository", action: #selector(AppDelegate.openGitHubRepository(_:)), keyEquivalent: "")
helpMenuItem.submenu = helpMenu

app.run()
