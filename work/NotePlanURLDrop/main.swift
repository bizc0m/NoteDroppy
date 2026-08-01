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
        let storedDestination = UserDefaults.standard.string(forKey: destinationKey)
            .flatMap(ShortcutDestination.init(rawValue:)) ?? .today
        let destination: ShortcutDestination = index == 1 ? .today : storedDestination

        return ShortcutSlot(
            index: index,
            enabled: enabled,
            combo: KeyCombo(keyCode: keyCode, carbonModifiers: normalizedCarbonModifiers(rawModifiers)),
            destination: destination,
            noteReference: index == 1 ? "" : note.trimmingCharacters(in: .whitespacesAndNewlines),
            folder: index == 1 ? "" : folder.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func setShortcutSlot(_ slot: ShortcutSlot) {
        let destination: ShortcutDestination = slot.index == 1 ? .today : slot.destination
        let noteReference = slot.index == 1 ? "" : slot.noteReference
        let folder = slot.index == 1 ? "" : slot.folder
        UserDefaults.standard.set(slot.enabled, forKey: "shortcutSlot\(slot.index).enabled")
        UserDefaults.standard.set(Int(slot.combo.keyCode), forKey: "shortcutSlot\(slot.index).keyCode")
        UserDefaults.standard.set(Int(slot.combo.carbonModifiers), forKey: "shortcutSlot\(slot.index).modifiers")
        UserDefaults.standard.set(destination.rawValue, forKey: "shortcutSlot\(slot.index).destination")
        UserDefaults.standard.set(noteReference, forKey: "shortcutSlot\(slot.index).note")
        UserDefaults.standard.set(folder, forKey: "shortcutSlot\(slot.index).folder")
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
    var destination: ShortcutDestination
    var noteReference: String
    var folder: String
    var tags: String
}

struct PreferencesFile: Codable {
    var version: Int
    var openNote: Bool
    var serviceName: String
    var defaultTags: String
    var notesRootPath: String?
    var shortcuts: [ShortcutSlotFile]

    static func current() -> PreferencesFile {
        PreferencesFile(
            version: 1,
            openNote: Settings.openNote,
            serviceName: Settings.serviceName,
            defaultTags: Settings.taskTag,
            notesRootPath: Settings.notesRootPath,
            shortcuts: Settings.allShortcutSlots().map(ShortcutSlotFile.init(slot:))
        )
    }

    func apply() {
        UserDefaults.standard.set(openNote, forKey: Settings.openNoteKey)
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
    var destination: ShortcutDestination
    var folder: String
    var notePath: String
    var tags: [String]

    init(slot: ShortcutSlot) {
        index = slot.index
        enabled = slot.enabled
        shortcut = shortcutString(from: slot.combo)
        keyCode = slot.combo.keyCode
        modifiers = slot.combo.carbonModifiers
        destination = slot.destination
        folder = slot.folder
        notePath = slot.noteReference
        tags = normalizedPreferenceTags(slot.tags)
    }

    var slot: ShortcutSlot {
        ShortcutSlot(
            index: max(1, min(index, Settings.shortcutSlotCount)),
            enabled: enabled,
            combo: KeyCombo(keyCode: keyCode, carbonModifiers: normalizedCarbonModifiers(modifiers)),
            destination: destination,
            noteReference: notePath,
            folder: folder,
            tags: tags.joined(separator: ", ")
        )
    }
}

enum ShortcutDestination: String, CaseIterable {
    case today
    case noteTitle
    case notePath

    var title: String {
        switch self {
        case .today: return "Aujourd'hui"
        case .noteTitle: return "Note nommée"
        case .notePath: return "Chemin de note"
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

    init() {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = true
        lineBreakMode = .byTruncatingMiddle
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isEditable = false
        isSelectable = true
        lineBreakMode = .byTruncatingMiddle
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        acceptsDrop && target(from: sender.draggingPasteboard) != nil ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard acceptsDrop, let target = target(from: sender.draggingPasteboard) else {
            NSSound.beep()
            return false
        }
        return onDropTarget?(target) ?? false
    }

    private func target(from pasteboard: NSPasteboard) -> ShortcutTarget? {
        if let url = droppedURL(from: pasteboard) {
            return ShortcutTarget(url: url)
        }
        if let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            if let url = Foundation.URL(string: text), url.scheme != nil {
                return ShortcutTarget(url: url)
            }
            return ShortcutTarget(rawText: text)
        }
        return nil
    }

    private func droppedURL(from pasteboard: NSPasteboard) -> URL? {
        if let value = pasteboard.string(forType: .fileURL), let url = Foundation.URL(string: value) {
            return url
        }
        if let value = pasteboard.string(forType: .URL), let url = Foundation.URL(string: value) {
            return url
        }
        if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            return objects.first
        }
        return nil
    }
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

final class ShortcutSlotRow {
    let index: Int
    let enabledCheckbox: NSButton
    let recorder: ShortcutRecorderButton
    let destinationPopup = NSPopUpButton()
    let folderField: NSTextField
    let noteField: NSTextField
    let searchButton = NSButton(title: "Rechercher", target: nil, action: nil)
    let targetField = ShortcutTargetField()
    let tagsField: NSTextField
    var onSearch: ((ShortcutSlotRow) -> Void)?
    var onTargetDrop: ((ShortcutSlotRow, ShortcutTarget) -> Bool)?
    private var storedCombo: KeyCombo
    private var isTodaySlot: Bool { index == 1 }
    private var displayIndex: String { index == 10 ? "0" : "\(index)" }

    init(slot: ShortcutSlot) {
        self.index = slot.index
        self.storedCombo = slot.combo
        self.enabledCheckbox = NSButton(checkboxWithTitle: slot.index == 10 ? "0" : "\(slot.index)", target: nil, action: nil)
        self.recorder = ShortcutRecorderButton(combo: slot.combo)
        self.folderField = NSTextField(string: slot.index == 1 ? "" : slot.folder)
        self.noteField = NSTextField(string: slot.index == 1 ? "" : slot.noteReference)
        self.tagsField = NSTextField(string: slot.tags)

        enabledCheckbox.state = slot.enabled ? .on : .off
        ShortcutDestination.allCases.forEach { destinationPopup.addItem(withTitle: $0.title) }
        destinationPopup.selectItem(withTitle: (slot.index == 1 ? ShortcutDestination.today : slot.destination).title)
        destinationPopup.target = self
        destinationPopup.action = #selector(destinationChanged)
        folderField.placeholderString = "Dossier"
        noteField.placeholderString = placeholder(for: slot.index == 1 ? .today : slot.destination)
        targetField.placeholderString = slot.index == 1 ? "Aujourd'hui" : "Déposer une note .md ici"
        targetField.stringValue = targetDisplay(for: slot.index == 1 ? .today : slot.destination, folder: slot.folder, note: slot.noteReference)
        targetField.acceptsDrop = slot.index != 1
        targetField.onDropTarget = { [weak self] target in
            guard let self else { return false }
            return self.onTargetDrop?(self, target) ?? false
        }
        searchButton.target = self
        searchButton.action = #selector(searchNote)
        searchButton.bezelStyle = .rounded
        tagsField.placeholderString = "capture, $year, #projet"

        [enabledCheckbox, recorder, destinationPopup, folderField, noteField, searchButton, targetField, tagsField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        enabledCheckbox.widthAnchor.constraint(equalToConstant: Self.columnWidths[0]).isActive = true
        recorder.widthAnchor.constraint(equalToConstant: Self.columnWidths[1]).isActive = true
        targetField.widthAnchor.constraint(equalToConstant: Self.columnWidths[2]).isActive = true
        tagsField.widthAnchor.constraint(equalToConstant: Self.columnWidths[3]).isActive = true
        refreshNoteFieldState()
    }

    static let columnSpacing: CGFloat = 12
    static let columnTitles = ["Actif", "Raccourci", "Cible", "Tags"]
    static let columnWidths: [CGFloat] = [44, 92, 470, 240]

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
        let destination: ShortcutDestination = isTodaySlot ? .today : selectedDestination()
        return ShortcutSlot(
            index: index,
            enabled: enabledCheckbox.state == .on,
            combo: storedCombo,
            destination: destination,
            noteReference: destination == .today ? "" : noteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            folder: destination == .today ? "" : folderField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tagsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func setCombo(_ combo: KeyCombo) {
        storedCombo = combo
        recorder.setCombo(combo)
    }

    func view() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = Self.columnSpacing
        row.alignment = .centerY
        row.addArrangedSubview(enabledCheckbox)
        row.addArrangedSubview(recorder)
        row.addArrangedSubview(targetField)
        row.addArrangedSubview(tagsField)
        return row
    }

    func applySelectedNote(_ result: NoteSearchResult) {
        guard !isTodaySlot else { return }
        destinationPopup.selectItem(withTitle: ShortcutDestination.notePath.title)
        folderField.stringValue = result.folder
        noteField.stringValue = URL(fileURLWithPath: result.relativePath).lastPathComponent
        targetField.stringValue = targetDisplay(for: .notePath, folder: result.folder, note: URL(fileURLWithPath: result.relativePath).lastPathComponent)
        if tagsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tagsField.stringValue = result.tags.prefix(4).joined(separator: ", ")
        }
        refreshNoteFieldState()
    }

    func apply(slot: ShortcutSlot) {
        enabledCheckbox.state = slot.enabled ? .on : .off
        enabledCheckbox.title = displayIndex
        setCombo(slot.combo)
        let destination: ShortcutDestination = isTodaySlot ? .today : slot.destination
        destinationPopup.selectItem(withTitle: destination.title)
        folderField.stringValue = isTodaySlot ? "" : slot.folder
        noteField.stringValue = isTodaySlot ? "" : slot.noteReference
        targetField.stringValue = targetDisplay(for: destination, folder: slot.folder, note: slot.noteReference)
        tagsField.stringValue = slot.tags
        noteField.placeholderString = placeholder(for: destination)
        refreshNoteFieldState()
    }

    @objc private func destinationChanged() {
        noteField.placeholderString = placeholder(for: selectedDestination())
        refreshNoteFieldState()
    }

    @objc private func searchNote() {
        guard !isTodaySlot else { return }
        onSearch?(self)
    }

    private func selectedDestination() -> ShortcutDestination {
        ShortcutDestination.allCases.first { $0.title == destinationPopup.titleOfSelectedItem } ?? .today
    }

    private func refreshNoteFieldState() {
        let destination: ShortcutDestination = isTodaySlot ? .today : selectedDestination()
        if isTodaySlot {
            destinationPopup.selectItem(withTitle: ShortcutDestination.today.title)
        }
        destinationPopup.isEnabled = !isTodaySlot
        folderField.isEnabled = destination != .today
        noteField.isEnabled = destination != .today
        targetField.acceptsDrop = !isTodaySlot
        searchButton.isEnabled = !isTodaySlot
        if destination == .today {
            folderField.stringValue = ""
            noteField.stringValue = ""
            targetField.stringValue = "Aujourd'hui"
        } else if targetField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetField.stringValue = targetDisplay(for: destination, folder: folderField.stringValue, note: noteField.stringValue)
        }
    }

    func applyDroppedPath(relativePath: String, isDirectory: Bool) {
        guard !isTodaySlot else { return }
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
            targetField.stringValue = relativePath
        }
        refreshNoteFieldState()
    }

    private func targetDisplay(for destination: ShortcutDestination, folder: String, note: String) -> String {
        if destination == .today { return "Aujourd'hui" }
        let cleanFolder = folder.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        let cleanNote = note.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        if cleanFolder.isEmpty && cleanNote.isEmpty { return "Déposer une note .md ici" }
        if cleanFolder.isEmpty { return cleanNote }
        if cleanNote.isEmpty { return "\(cleanFolder)/" }
        return "\(cleanFolder)/\(cleanNote)"
    }

    private func placeholder(for destination: ShortcutDestination) -> String {
        switch destination {
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
    private var shortcutRows: [ShortcutSlotRow] = []
    private let shortcutHelpLabel = NSTextField(labelWithString: "Actif | Raccourci | Cible | Tags. Dépose une note .md sur les slots 2-10. Variables: $date, $day, $time, $datetime, $month, $year")
    private let helpButton = NSButton(title: "Aide", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Autoriser Accessibilité", target: nil, action: nil)
    private let exportButton = NSButton(title: "Exporter JSON", target: nil, action: nil)
    private let importButton = NSButton(title: "Importer JSON", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")

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

        let title = NSTextField(labelWithString: "NoteDroppy")
        title.font = .boldSystemFont(ofSize: 18)

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

        let serviceLabel = NSTextField(labelWithString: "Nom du Service")
        serviceNameField.placeholderString = "NotePlan : ajouter en tâche"
        serviceNameField.lineBreakMode = .byTruncatingTail

        let tagLabel = NSTextField(labelWithString: "Tag ajouté à la tâche")
        tagField.placeholderString = "#capture"

        let notesRootLabel = NSTextField(labelWithString: "Dossier Notes NotePlan")
        notesRootField.placeholderString = "Choisir le dossier Notes pour activer la recherche"
        notesRootField.isEditable = false
        notesRootField.isSelectable = true
        notesRootField.lineBreakMode = .byTruncatingMiddle

        chooseNotesRootButton.target = self
        chooseNotesRootButton.action = #selector(chooseNotesRoot)
        chooseNotesRootButton.bezelStyle = .rounded

        let notesRootRow = NSStackView()
        notesRootRow.orientation = .horizontal
        notesRootRow.spacing = 8
        notesRootRow.alignment = .centerY
        notesRootRow.addArrangedSubview(notesRootField)
        notesRootRow.addArrangedSubview(chooseNotesRootButton)

        openNoteCheckbox.state = Settings.openNote ? .on : .off
        shortcutHelpLabel.textColor = .secondaryLabelColor
        shortcutHelpLabel.lineBreakMode = .byWordWrapping
        shortcutHelpLabel.maximumNumberOfLines = 2

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.alignment = .centerY

        let saveButton = NSButton(title: "Enregistrer", target: self, action: #selector(saveSettings))
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
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 360).isActive = true
        }

        let slotsStack = NSStackView()
        slotsStack.orientation = .vertical
        slotsStack.spacing = 8
        slotsStack.alignment = .leading

        slotsStack.addArrangedSubview(ShortcutSlotRow.headerView())

        shortcutRows = Settings.allShortcutSlots().map { slot in
            let row = ShortcutSlotRow(slot: slot)
            row.recorder.onChange = { combo in
                row.setCombo(combo)
                NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            }
            row.onSearch = { [weak self] row in
                self?.showNoteSearch(for: row)
            }
            row.onTargetDrop = { [weak self] row, target in
                self?.applyDroppedTarget(target, to: row) ?? false
            }
            slotsStack.addArrangedSubview(row.view())
            return row
        }

        stack.addArrangedSubview(titleStack)
        stack.addArrangedSubview(serviceLabel)
        stack.addArrangedSubview(serviceNameField)
        stack.addArrangedSubview(tagLabel)
        stack.addArrangedSubview(tagField)
        stack.addArrangedSubview(notesRootLabel)
        stack.addArrangedSubview(notesRootRow)
        stack.addArrangedSubview(openNoteCheckbox)
        stack.addArrangedSubview(shortcutHelpLabel)
        stack.addArrangedSubview(slotsStack)
        stack.addArrangedSubview(buttons)
        stack.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22)
        ])
        refreshAccessibilityStatus()
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
        guard let root = Settings.selectedNotesRoot() else {
            statusLabel.stringValue = "Choisis d'abord le dossier Notes NotePlan, puis dépose une note .md."
            NSSound.beep()
            return false
        }

        if let url = target.url {
            guard url.isFileURL else {
                statusLabel.stringValue = "Dépose une note .md ou un dossier depuis Finder."
                NSSound.beep()
                return false
            }

            let fileURL = url.standardizedFileURL
            let rootURL = root.standardizedFileURL
            let filePath = fileURL.path
            let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"

            guard filePath == rootURL.path || filePath.hasPrefix(rootPath) else {
                statusLabel.stringValue = "La cible doit être dans le dossier Notes choisi."
                NSSound.beep()
                return false
            }

            let relativePath = filePath == rootURL.path
                ? ""
                : String(filePath.dropFirst(rootPath.count))
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory)
            if !isDirectory.boolValue, fileURL.pathExtension.lowercased() != "md" {
                statusLabel.stringValue = "Dépose une note .md ou un dossier NotePlan."
                NSSound.beep()
                return false
            }

            row.applyDroppedPath(relativePath: relativePath, isDirectory: isDirectory.boolValue)
            statusLabel.stringValue = "Cible définie : \(relativePath.isEmpty ? rootURL.lastPathComponent : relativePath)"
            return true
        }

        if let text = target.rawText, let path = notePathFromDroppedText(text) {
            row.applyDroppedPath(relativePath: path, isDirectory: false)
            statusLabel.stringValue = "Cible définie : \(path)"
            return true
        }

        statusLabel.stringValue = "Dépose une note .md depuis Finder."
        NSSound.beep()
        return false
    }

    private func notePathFromDroppedText(_ text: String) -> String? {
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
            return title.hasSuffix(".md") ? title : "\(title).md"
        }
        return nil
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
        shortcutRows.forEach { Settings.setShortcutSlot($0.slot) }
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)

        if applyServiceNameToBundle(serviceName.isEmpty ? "NotePlan : ajouter en tâche" : serviceName) {
            statusLabel.stringValue = "Réglages enregistrés. Le menu Services peut demander quelques secondes pour se rafraîchir."
        } else {
            statusLabel.stringValue = "Réglages enregistrés. Nom du Service gardé pour l'app, mais macOS n'a pas pu être rafraîchi."
        }
        refreshAccessibilityStatus(append: true)
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
        shortcutRows.forEach { Settings.setShortcutSlot($0.slot) }
        UserDefaults.standard.synchronize()
    }

    private func reloadControlsFromSettings() {
        serviceNameField.stringValue = Settings.serviceName
        tagField.stringValue = Settings.taskTag
        notesRootField.stringValue = Settings.notesRootPath
        openNoteCheckbox.state = Settings.openNote ? .on : .off
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
        var handled = false
        for filename in filenames {
            let fileURL = URL(fileURLWithPath: filename)
            if let droppedText = extractTodoText(from: fileURL) {
                log("openFiles:extracted:\(droppedText)")
                sendTodo(droppedText)
                handled = true
            } else {
                log("openFiles:failed-extract:\(filename)")
            }
        }
        NSApp.reply(toOpenOrPrint: handled ? .success : .failure)
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
            if url.isFileURL, let droppedText = extractTodoText(from: url) {
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
           let text = try? String(contentsOf: fileURL, encoding: .utf8) {
            return normalizedTodoText(text)
        }

        return markdownFileLink(for: fileURL)
    }

    private func markdownFileLink(for fileURL: URL) -> String {
        let label = fileURL.lastPathComponent
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return "[\(label)](<\(fileURL.absoluteString)>)"
    }

    private func isPlainTextFile(_ fileURL: URL) -> Bool {
        let textExtensions: Set<String> = ["txt", "md", "markdown", "text", "csv", "json", "xml", "yaml", "yml", "log"]
        if textExtensions.contains(fileURL.pathExtension.lowercased()) {
            return true
        }
        guard let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) else {
            return false
        }
        return !data.prefix(4096).contains(0)
    }

    private func firstWebURL(in text: String) -> String? {
        let pattern = #"https?://[^\s<>"']+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return String(text[range])
    }

    private func isWebURL(_ value: String) -> Bool {
        value.lowercased().hasPrefix("http://") || value.lowercased().hasPrefix("https://")
    }

    private func normalizedTodoText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "(null)" else { return nil }
        return firstWebURL(in: trimmed) ?? trimmed
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
        sendTodo(text)
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

        waitForCopiedText(pasteboard: pasteboard, previousChangeCount: previousChangeCount, attemptsRemaining: 12) { text in
            defer { snapshot.restore(to: pasteboard) }
            let clipboardText = text.flatMap { self.normalizedTodoText($0) }
            let axText = self.selectedTextFromAccessibility().flatMap { self.normalizedTodoText($0) }
            if let normalized = self.bestShortcutText(clipboardText: clipboardText, axText: axText) {
                self.log("shortcut:text:\(normalized)")
                self.sendTodo(normalized, shortcutSlot: slot)
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

    private func waitForCopiedText(
        pasteboard: NSPasteboard,
        previousChangeCount: Int,
        attemptsRemaining: Int,
        completion: @escaping (String?) -> Void
    ) {
        if pasteboard.changeCount != previousChangeCount {
            completion(pasteboard.string(forType: .string))
            return
        }
        guard attemptsRemaining > 0 else {
            completion(nil)
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

    private func sendTodo(_ todoText: String, shortcutSlot: ShortcutSlot? = nil) {
        let tagSource = shortcutSlot?.tags ?? Settings.taskTag
        guard let content = normalizedTaskContent(expandedVariables(todoText), tags: tagSource) else { return }
        log("sendTodo:\(content)")
        let task = formattedTask(from: content, tags: tagSource)
        let openNoteValue = Settings.openNote ? "yes" : "no"
        let noteTarget = notePlanTarget(for: shortcutSlot)
        log("sendTodoTarget:\(noteTarget)")
        let target = "noteplan://x-callback-url/addText?\(noteTarget)&text=\(encode(task))&mode=append&openNote=\(openNoteValue)"
        if let url = URL(string: target) {
            NSWorkspace.shared.open(url)
        }
    }

    private func notePlanTarget(for shortcutSlot: ShortcutSlot?) -> String {
        guard let shortcutSlot else { return "noteDate=today" }

        switch shortcutSlot.destination {
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

    private func formattedTask(from content: String, tags: String) -> String {
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

        let continuation = lines.dropFirst().map { line in
            line.isEmpty ? ">" : "> \(line)"
        }
        let suffix = tag.isEmpty ? "" : " \(tag)"
        return (["- [ ] \(firstLine)\(suffix)"] + continuation).joined(separator: "\n")
    }

    private func normalizedTaskContent(_ value: String, tags: String) -> String? {
        var content = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content != "(null)" else { return nil }

        let taskPrefixPattern = #"^[-*]\s+\[[ xX]\]\s+"#
        while let range = content.range(of: taskPrefixPattern, options: .regularExpression) {
            content.removeSubrange(range)
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

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

    private func shell(_ args: [String]) -> String? {
        guard let executable = args.first else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(args.dropFirst())
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
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
