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
    static let captureSectionKey = "captureSection"
    static let openNoteKey = "openNote"
    static let includeSourceKey = "includeSource"
    static let includeDocumentSourceKey = "includeDocumentSource"
    static let serviceNameKey = "serviceName"
    static let notesRootPathKey = "notesRootPath"
    static let notesRootBookmarkKey = "notesRootBookmark"
    static let shortcutEnabledKey = "shortcutEnabled"
    static let shortcutKeyCodeKey = "shortcutKeyCode"
    static let shortcutModifiersKey = "shortcutModifiers"
    static let didShowFirstLaunchSettingsKey = "didShowFirstLaunchSettings"
    static let shortcutLayoutVersionKey = "shortcutLayoutVersion"
    static let shortcutVisibleCountKey = "shortcutVisibleCount"
    static let shortcutSlotCount = 30
    static let defaultVisibleShortcutCount = 20
    static let currentShortcutLayoutVersion = 2

    static var taskTag: String {
        let value = UserDefaults.standard.string(forKey: taskTagKey) ?? "#capture"
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "#capture" : trimmed
    }

    static var captureSection: String {
        let standard = UserDefaults.standard.string(forKey: captureSectionKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !standard.isEmpty {
            return standard
        }
        return plistPreferenceString(forKey: captureSectionKey)
    }

    private static func plistPreferenceString(forKey key: String) -> String {
        let identifier = Bundle.main.bundleIdentifier ?? "local.codex.notedroopy"
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(identifier).plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let value = plist[key] as? String else {
            return ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
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

    static var includeDocumentSource: Bool {
        if UserDefaults.standard.object(forKey: includeDocumentSourceKey) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: includeDocumentSourceKey)
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
        let actionKey = "shortcutSlot\(index).action"
        let markerKey = "shortcutSlot\(index).marker"
        let priorityKey = "shortcutSlot\(index).priority"
        let scheduleKey = "shortcutSlot\(index).schedule"
        let outputKey = "shortcutSlot\(index).output"
        let noteKey = "shortcutSlot\(index).note"
        let folderKey = "shortcutSlot\(index).folder"
        let tagsKey = "shortcutSlot\(index).tags"
        let sectionKey = "shortcutSlot\(index).section"
        let insertPositionKey = "shortcutSlot\(index).insertPosition"
        let privacyKey = "shortcutSlot\(index).privacy"
        let indexingKey = "shortcutSlot\(index).indexing"
        let llmRoutingKey = "shortcutSlot\(index).llmRouting"
        let contentModeKey = "shortcutSlot\(index).contentMode"
        let openNoteOverrideKey = "shortcutSlot\(index).openNoteOverride"
        let includeSourceOverrideKey = "shortcutSlot\(index).includeSourceOverride"
        let includeDocumentSourceOverrideKey = "shortcutSlot\(index).includeDocumentSourceOverride"

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
        let section = UserDefaults.standard.string(forKey: sectionKey) ?? (index == 1 ? captureSection : "")
        let insertPosition = UserDefaults.standard.string(forKey: insertPositionKey)
            .flatMap { ShortcutInsertPosition(rawValue: $0) } ?? .endOfSection
        let openNoteOverride = UserDefaults.standard.string(forKey: openNoteOverrideKey)
            .flatMap { ShortcutOptionOverride(rawValue: $0) } ?? .inherit
        let includeSourceOverride = UserDefaults.standard.string(forKey: includeSourceOverrideKey)
            .flatMap { ShortcutOptionOverride(rawValue: $0) } ?? .inherit
        let includeDocumentSourceOverride = UserDefaults.standard.string(forKey: includeDocumentSourceOverrideKey)
            .flatMap { ShortcutOptionOverride(rawValue: $0) } ?? .inherit
        let savedDestination = UserDefaults.standard.string(forKey: destinationKey)
            .flatMap { ShortcutDestination(rawValue: $0) }
        let destination = Settings.validDestination(savedDestination ?? (index == 1 ? .today : .standard), for: index)
        let engine = UserDefaults.standard.string(forKey: engineKey)
            .flatMap { ShortcutEngine(rawValue: $0) } ?? .notePlan
        let action = UserDefaults.standard.string(forKey: actionKey)
            .flatMap { ShortcutAction(rawValue: $0) } ?? .capture
        let marker = UserDefaults.standard.string(forKey: markerKey)
            .flatMap { ShortcutMarker(rawValue: $0) } ?? .task
        let priority = UserDefaults.standard.string(forKey: priorityKey)
            .flatMap { ShortcutPriority(rawValue: $0) } ?? .none
        let schedule = UserDefaults.standard.string(forKey: scheduleKey)
            .flatMap { ShortcutSchedule(rawValue: $0) } ?? .none
        let output = UserDefaults.standard.string(forKey: outputKey)
            .flatMap { ShortcutOutput(rawValue: $0) } ?? ShortcutOutput(engine: engine, destination: destination)
        let privacy = UserDefaults.standard.string(forKey: privacyKey)
            .flatMap { ShortcutPrivacy(rawValue: $0) } ?? .personal
        let indexing = UserDefaults.standard.string(forKey: indexingKey)
            .flatMap { ShortcutIndexing(rawValue: $0) } ?? .inherit
        let llmRouting = UserDefaults.standard.string(forKey: llmRoutingKey)
            .flatMap { ShortcutLLMRouting(rawValue: $0) } ?? .none
        let contentMode = UserDefaults.standard.string(forKey: contentModeKey)
            .flatMap { ShortcutContentMode(rawValue: $0) } ?? .expanded

        return ShortcutSlot(
            index: index,
            enabled: enabled,
            combo: KeyCombo(keyCode: keyCode, carbonModifiers: normalizedCarbonModifiers(rawModifiers)),
            action: action,
            marker: marker,
            priority: priority,
            schedule: schedule,
            output: output,
            engine: engine,
            destination: destination,
            noteReference: note.trimmingCharacters(in: .whitespacesAndNewlines),
            folder: folder.trimmingCharacters(in: .whitespacesAndNewlines),
            section: section.trimmingCharacters(in: .whitespacesAndNewlines),
            insertPosition: insertPosition,
            privacy: privacy,
            indexing: indexing,
            llmRouting: llmRouting,
            contentMode: contentMode,
            openNoteOverride: openNoteOverride,
            includeSourceOverride: includeSourceOverride,
            includeDocumentSourceOverride: includeDocumentSourceOverride,
            tags: tags.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func setShortcutSlot(_ slot: ShortcutSlot) {
        UserDefaults.standard.set(slot.enabled, forKey: "shortcutSlot\(slot.index).enabled")
        UserDefaults.standard.set(Int(slot.combo.keyCode), forKey: "shortcutSlot\(slot.index).keyCode")
        UserDefaults.standard.set(Int(slot.combo.carbonModifiers), forKey: "shortcutSlot\(slot.index).modifiers")
        UserDefaults.standard.set(slot.action.rawValue, forKey: "shortcutSlot\(slot.index).action")
        UserDefaults.standard.set(slot.marker.rawValue, forKey: "shortcutSlot\(slot.index).marker")
        UserDefaults.standard.set(slot.priority.rawValue, forKey: "shortcutSlot\(slot.index).priority")
        UserDefaults.standard.set(slot.schedule.rawValue, forKey: "shortcutSlot\(slot.index).schedule")
        UserDefaults.standard.set(slot.output.rawValue, forKey: "shortcutSlot\(slot.index).output")
        UserDefaults.standard.set(slot.output.engine.rawValue, forKey: "shortcutSlot\(slot.index).engine")
        let destination = Settings.validDestination(slot.output.destination, for: slot.index)
        UserDefaults.standard.set(destination.rawValue, forKey: "shortcutSlot\(slot.index).destination")
        UserDefaults.standard.set(slot.noteReference, forKey: "shortcutSlot\(slot.index).note")
        UserDefaults.standard.set(slot.folder, forKey: "shortcutSlot\(slot.index).folder")
        UserDefaults.standard.set(slot.section, forKey: "shortcutSlot\(slot.index).section")
        UserDefaults.standard.set(slot.insertPosition.rawValue, forKey: "shortcutSlot\(slot.index).insertPosition")
        UserDefaults.standard.set(slot.privacy.rawValue, forKey: "shortcutSlot\(slot.index).privacy")
        UserDefaults.standard.set(slot.indexing.rawValue, forKey: "shortcutSlot\(slot.index).indexing")
        UserDefaults.standard.set(slot.llmRouting.rawValue, forKey: "shortcutSlot\(slot.index).llmRouting")
        UserDefaults.standard.set(slot.contentMode.rawValue, forKey: "shortcutSlot\(slot.index).contentMode")
        UserDefaults.standard.set(slot.openNoteOverride.rawValue, forKey: "shortcutSlot\(slot.index).openNoteOverride")
        UserDefaults.standard.set(slot.includeSourceOverride.rawValue, forKey: "shortcutSlot\(slot.index).includeSourceOverride")
        UserDefaults.standard.set(slot.includeDocumentSourceOverride.rawValue, forKey: "shortcutSlot\(slot.index).includeDocumentSourceOverride")
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

    static var visibleShortcutCount: Int {
        let stored = UserDefaults.standard.integer(forKey: shortcutVisibleCountKey)
        guard stored > 0 else { return defaultVisibleShortcutCount }
        return max(defaultVisibleShortcutCount, min(stored, shortcutSlotCount))
    }

    static func setVisibleShortcutCount(_ count: Int) {
        UserDefaults.standard.set(max(1, min(count, shortcutSlotCount)), forKey: shortcutVisibleCountKey)
        UserDefaults.standard.synchronize()
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
            UInt32(kVK_ANSI_6), UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9), UInt32(kVK_ANSI_0),
            UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4), UInt32(kVK_F5), UInt32(kVK_F6),
            UInt32(kVK_F7), UInt32(kVK_F8), UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
            UInt32(kVK_F13), UInt32(kVK_F14), UInt32(kVK_F15), UInt32(kVK_F16), UInt32(kVK_F17), UInt32(kVK_F18),
            UInt32(kVK_F19), UInt32(kVK_F20)
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

        for index in 1...10 {
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
    var action: ShortcutAction
    var marker: ShortcutMarker
    var priority: ShortcutPriority
    var schedule: ShortcutSchedule
    var output: ShortcutOutput
    var engine: ShortcutEngine
    var destination: ShortcutDestination
    var noteReference: String
    var folder: String
    var section: String
    var insertPosition: ShortcutInsertPosition
    var privacy: ShortcutPrivacy
    var indexing: ShortcutIndexing
    var llmRouting: ShortcutLLMRouting
    var contentMode: ShortcutContentMode
    var openNoteOverride: ShortcutOptionOverride
    var includeSourceOverride: ShortcutOptionOverride
    var includeDocumentSourceOverride: ShortcutOptionOverride
    var tags: String
}

enum ShortcutMarker: String, CaseIterable, Codable {
    case task
    case bulletStar
    case bulletPlus
    case plainText

    var title: String {
        switch self {
        case .task: return "- [ ]"
        case .bulletStar: return "*"
        case .bulletPlus: return "+"
        case .plainText: return "Texte"
        }
    }
}

enum ShortcutPriority: String, CaseIterable, Codable {
    case none
    case one
    case two
    case three

    var title: String {
        switch self {
        case .none: return "Aucune"
        case .one: return "!"
        case .two: return "!!"
        case .three: return "!!!"
        }
    }
}

enum ShortcutSchedule: String, CaseIterable, Codable {
    case none
    case tomorrow
    case weekend
    case nextWeek
    case customDate

    var title: String {
        switch self {
        case .none: return "Aucune"
        case .tomorrow: return "Demain"
        case .weekend: return "Ce week-end"
        case .nextWeek: return "Semaine pro"
        case .customDate: return "Date..."
        }
    }
}

enum ShortcutPrivacy: String, CaseIterable, Codable {
    case personal
    case secret
    case `public`

    var title: String {
        switch self {
        case .personal: return "Perso"
        case .secret: return "Secret"
        case .public: return "Public"
        }
    }
}

enum ShortcutIndexing: String, CaseIterable, Codable {
    case inherit
    case indexable
    case noIndex

    var title: String {
        switch self {
        case .inherit: return "Global"
        case .indexable: return "Indexable"
        case .noIndex: return "Non indexable"
        }
    }
}

enum ShortcutLLMRouting: String, CaseIterable, Codable {
    case none
    case local
    case remote

    var title: String {
        switch self {
        case .none: return "Aucun"
        case .local: return "Local"
        case .remote: return "Distant"
        }
    }
}

enum ShortcutContentMode: String, CaseIterable, Codable {
    case expanded
    case folded

    var title: String {
        switch self {
        case .expanded: return "Déplié"
        case .folded: return "Plié"
        }
    }
}

enum ShortcutAction: String, CaseIterable, Codable {
    case capture
    case captureOpen
    case open

    var title: String {
        switch self {
        case .capture: return "Capturer"
        case .captureOpen: return "Capturer + ouvrir"
        case .open: return "Ouvrir"
        }
    }
}

enum ShortcutOutput: String, CaseIterable, Codable {
    case todayNotePlan
    case notePathNotePlan
    case standardMarkdown
    case obsidianMarkdown
    case plainText

    var title: String {
        switch self {
        case .todayNotePlan: return "NotePlan Today"
        case .notePathNotePlan: return "NotePlan Note"
        case .standardMarkdown: return "Markdown .md"
        case .obsidianMarkdown: return "Obsidian • .md"
        case .plainText: return ".txt"
        }
    }

    var engine: ShortcutEngine {
        switch self {
        case .obsidianMarkdown:
            return .obsidian
        case .todayNotePlan, .notePathNotePlan, .standardMarkdown, .plainText:
            return .notePlan
        }
    }

    var destination: ShortcutDestination {
        switch self {
        case .todayNotePlan:
            return .today
        case .notePathNotePlan, .obsidianMarkdown, .plainText:
            return .notePath
        case .standardMarkdown:
            return .standard
        }
    }

    init(engine: ShortcutEngine, destination: ShortcutDestination) {
        if engine == .obsidian {
            self = .obsidianMarkdown
        } else {
            switch destination {
            case .today: self = .todayNotePlan
            case .notePath, .noteTitle: self = .notePathNotePlan
            case .standard: self = .standardMarkdown
            }
        }
    }
}

enum ShortcutOptionOverride: String, CaseIterable, Codable {
    case inherit
    case enabled
    case disabled

    var title: String {
        switch self {
        case .inherit: return "G"
        case .enabled: return "Oui"
        case .disabled: return "Non"
        }
    }

    var fullTitle: String {
        switch self {
        case .inherit: return "Global"
        case .enabled: return "Oui"
        case .disabled: return "Non"
        }
    }

    func resolved(default defaultValue: Bool) -> Bool {
        switch self {
        case .inherit: return defaultValue
        case .enabled: return true
        case .disabled: return false
        }
    }
}

enum ShortcutInsertPosition: String, CaseIterable, Codable {
    case topOfNote
    case bottomOfNote
    case startOfSection
    case endOfSection

    var title: String {
        switch self {
        case .topOfNote: return "Haut note"
        case .bottomOfNote: return "Bas note"
        case .startOfSection: return "Début section"
        case .endOfSection: return "Fin section"
        }
    }
}

struct CaptureSource {
    var url: String
    var title: String?
}

struct LLMURLMetadata {
    let title: String
    let tags: [String]
    let section: String?
}

struct CaptureRulesFile: Codable {
    var version: Int
    var rules: [CaptureRule]
}

struct CaptureRule: Codable {
    struct Match: Codable {
        var domains: [String]?
        var pathContains: [String]?
    }

    struct TitleRule: Codable {
        var fallback: String?
    }

    var id: String
    var enabled: Bool
    var match: Match
    var title: TitleRule?
    var tags: [String]?
    var section: String?
}

private enum CaptureRulesStore {
    static let fileName = "capture-rules.json"
    static let docName = "capture-rules.md"

    static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NoteDroopy", isDirectory: true)
    }

    static var rulesURL: URL { supportDirectory.appendingPathComponent(fileName) }
    static var docURL: URL { supportDirectory.appendingPathComponent(docName) }

    static func ensureFiles() {
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: rulesURL.path) {
            let bundled = Bundle.main.url(forResource: "capture-rules", withExtension: "json")
            let content = bundled.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? defaultRulesJSON
            try? content.write(to: rulesURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: docURL.path) {
            let bundled = Bundle.main.url(forResource: "capture-rules", withExtension: "md")
            let content = bundled.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? defaultRulesDocumentation
            try? content.write(to: docURL, atomically: true, encoding: .utf8)
        }
    }

    static func metadata(for normalizedURL: String) -> LLMURLMetadata? {
        guard let components = URLComponents(string: normalizedURL),
              let host = components.host?.lowercased() else {
            return nil
        }
        let canonicalHost = canonical(host)
        let path = components.path.lowercased()

        for rule in activeRules() {
            let domains = rule.match.domains?.map { canonical($0.lowercased()) } ?? []
            guard domains.contains(canonicalHost) else { continue }
            if let pathContains = rule.match.pathContains,
               !pathContains.isEmpty,
               !pathContains.contains(where: { path.contains($0.lowercased()) }) {
                continue
            }
            let tags = normalizedRuleTags(rule.tags ?? [])
            let explicitSection = rule.section?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let inferredSection = tags.contains { $0.lowercased() == "#llm" } ? "LLM" : nil
            return LLMURLMetadata(
                title: rule.title?.fallback ?? fallbackTitle(for: canonicalHost),
                tags: tags,
                section: explicitSection.isEmpty ? inferredSection : explicitSection
            )
        }
        return nil
    }

    private static func activeRules() -> [CaptureRule] {
        ensureFiles()
        guard let data = try? Data(contentsOf: rulesURL),
              let file = try? JSONDecoder().decode(CaptureRulesFile.self, from: data) else {
            return defaultRules()
        }
        return file.rules.filter(\.enabled)
    }

    private static func defaultRules() -> [CaptureRule] {
        guard let data = defaultRulesJSON.data(using: .utf8),
              let file = try? JSONDecoder().decode(CaptureRulesFile.self, from: data) else {
            return []
        }
        return file.rules.filter(\.enabled)
    }

    private static func canonical(_ host: String) -> String {
        host.replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
    }

    private static func fallbackTitle(for host: String) -> String {
        host.split(separator: ".").first.map { String($0).capitalized } ?? host
    }

    private static func normalizedRuleTags(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.hasPrefix("#") || $0.hasPrefix("@") ? $0 : "#\($0)" }
    }

    static let defaultRulesJSON = """
    {
      "version": 1,
      "rules": [
        {
          "id": "llm-gpt",
          "enabled": true,
          "match": { "domains": ["chatgpt.com", "chat.openai.com"] },
          "title": { "fallback": "GPT Chat" },
          "tags": ["#LLM", "#GPT"],
          "section": "LLM",
          "destination": { "engine": "noteplan", "type": "slot" },
          "format": "linkTask",
          "source": "textOnly"
        },
        {
          "id": "llm-perplexity-task",
          "enabled": true,
          "match": { "domains": ["perplexity.ai"], "pathContains": ["/computer/tasks/"] },
          "title": { "fallback": "Perplexity Task" },
          "tags": ["#LLM", "#Perplexity"],
          "section": "LLM",
          "destination": { "engine": "noteplan", "type": "slot" },
          "format": "linkTask",
          "source": "textOnly"
        },
        {
          "id": "llm-perplexity",
          "enabled": true,
          "match": { "domains": ["perplexity.ai"] },
          "title": { "fallback": "Perplexity" },
          "tags": ["#LLM", "#Perplexity"],
          "section": "LLM",
          "destination": { "engine": "noteplan", "type": "slot" },
          "format": "linkTask",
          "source": "textOnly"
        },
        {
          "id": "llm-claude",
          "enabled": true,
          "match": { "domains": ["claude.ai"] },
          "title": { "fallback": "Claude Chat" },
          "tags": ["#LLM", "#Claude"],
          "section": "LLM",
          "destination": { "engine": "noteplan", "type": "slot" },
          "format": "linkTask",
          "source": "textOnly"
        }
      ]
    }
    """

    static let defaultRulesDocumentation = """
    # NoteDroopy capture-rules.json

    JSON actif : `~/Library/Application Support/NoteDroopy/capture-rules.json`

    Champs utiles :
    - `id` : nom stable de la règle.
    - `enabled` : active/désactive la règle.
    - `match.domains` : domaines sans obligation de mettre `www`.
    - `match.pathContains` : fragments de chemin optionnels.
    - `title.fallback` : titre utilisé si le vrai titre navigateur est absent.
    - `tags` : tags ajoutés automatiquement.
    - `destination` : prévu pour la prochaine passe de routage par règle.
    - `format` : prévu pour les formats avancés.
    - `source` : `textOnly` = source seulement quand la capture est du texte.

    Formats :
    - URL seule : `- [ ] [Titre](url) #capture #LLM #GPT`
    - Texte sélectionné : `- [ ] texte #capture #LLM #GPT` puis `> Source : [Titre](url)`
    - Multi-ligne : première ligne en tâche, lignes suivantes en citation.
    """
}

struct PreferencesFile: Codable {
    var version: Int
    var openNote: Bool
    var includeSource: Bool?
    var includeDocumentSource: Bool?
    var serviceName: String
    var defaultTags: String
    var defaultSection: String?
    var notesRootPath: String?
    var shortcuts: [ShortcutSlotFile]

    static func current() -> PreferencesFile {
        PreferencesFile(
            version: 1,
            openNote: Settings.openNote,
            includeSource: Settings.includeSource,
            includeDocumentSource: Settings.includeDocumentSource,
            serviceName: Settings.serviceName,
            defaultTags: Settings.taskTag,
            defaultSection: Settings.captureSection,
            notesRootPath: Settings.notesRootPath,
            shortcuts: Settings.allShortcutSlots().map(ShortcutSlotFile.init(slot:))
        )
    }

    func apply() {
        UserDefaults.standard.set(openNote, forKey: Settings.openNoteKey)
        UserDefaults.standard.set(includeSource ?? true, forKey: Settings.includeSourceKey)
        UserDefaults.standard.set(includeDocumentSource ?? false, forKey: Settings.includeDocumentSourceKey)
        UserDefaults.standard.set(serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "NotePlan : ajouter en tâche" : serviceName, forKey: Settings.serviceNameKey)
        UserDefaults.standard.set(defaultTags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "#capture" : defaultTags, forKey: Settings.taskTagKey)
        UserDefaults.standard.set((defaultSection ?? "").trimmingCharacters(in: .whitespacesAndNewlines), forKey: Settings.captureSectionKey)
        let trimmedNotesRoot = (notesRootPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotesRoot.isEmpty {
            Settings.setNotesRoot(URL(fileURLWithPath: trimmedNotesRoot))
        }
        for shortcut in shortcuts.prefix(Settings.shortcutSlotCount) {
            Settings.setShortcutSlot(shortcut.slot)
        }
        if !shortcuts.isEmpty {
            Settings.setVisibleShortcutCount(max(Settings.defaultVisibleShortcutCount, min(shortcuts.count, Settings.shortcutSlotCount)))
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
    var action: ShortcutAction?
    var marker: ShortcutMarker?
    var priority: ShortcutPriority?
    var schedule: ShortcutSchedule?
    var output: ShortcutOutput?
    var engine: ShortcutEngine
    var destination: ShortcutDestination
    var folder: String
    var notePath: String
    var section: String?
    var insertPosition: ShortcutInsertPosition?
    var privacy: ShortcutPrivacy?
    var indexing: ShortcutIndexing?
    var llmRouting: ShortcutLLMRouting?
    var contentMode: ShortcutContentMode?
    var openNoteOverride: ShortcutOptionOverride?
    var includeSourceOverride: ShortcutOptionOverride?
    var includeDocumentSourceOverride: ShortcutOptionOverride?
    var tags: [String]

    enum CodingKeys: String, CodingKey {
        case index, enabled, shortcut, keyCode, modifiers, action, marker, priority, schedule, output, engine, destination, folder, notePath, section, insertPosition, privacy, indexing, llmRouting, contentMode, openNoteOverride, includeSourceOverride, includeDocumentSourceOverride, tags
    }

    init(slot: ShortcutSlot) {
        index = slot.index
        enabled = slot.enabled
        shortcut = shortcutString(from: slot.combo)
        keyCode = slot.combo.keyCode
        modifiers = slot.combo.carbonModifiers
        action = slot.action
        marker = slot.marker
        priority = slot.priority
        schedule = slot.schedule
        output = slot.output
        engine = slot.engine
        destination = slot.destination
        folder = slot.folder
        notePath = slot.noteReference
        section = slot.section
        insertPosition = slot.insertPosition
        privacy = slot.privacy
        indexing = slot.indexing
        llmRouting = slot.llmRouting
        contentMode = slot.contentMode
        openNoteOverride = slot.openNoteOverride
        includeSourceOverride = slot.includeSourceOverride
        includeDocumentSourceOverride = slot.includeDocumentSourceOverride
        tags = normalizedPreferenceTags(slot.tags)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        shortcut = (try? container.decode(String.self, forKey: .shortcut)) ?? ""
        keyCode = try container.decode(UInt32.self, forKey: .keyCode)
        modifiers = try container.decode(UInt32.self, forKey: .modifiers)
        action = (try? container.decode(ShortcutAction.self, forKey: .action)) ?? .capture
        marker = (try? container.decode(ShortcutMarker.self, forKey: .marker)) ?? .task
        priority = (try? container.decode(ShortcutPriority.self, forKey: .priority)) ?? ShortcutPriority.none
        schedule = (try? container.decode(ShortcutSchedule.self, forKey: .schedule)) ?? ShortcutSchedule.none
        output = try? container.decode(ShortcutOutput.self, forKey: .output)
        engine = (try? container.decode(ShortcutEngine.self, forKey: .engine)) ?? .notePlan
        destination = try container.decode(ShortcutDestination.self, forKey: .destination)
        folder = (try? container.decode(String.self, forKey: .folder)) ?? ""
        notePath = (try? container.decode(String.self, forKey: .notePath)) ?? ""
        section = (try? container.decode(String.self, forKey: .section)) ?? ""
        insertPosition = (try? container.decode(ShortcutInsertPosition.self, forKey: .insertPosition)) ?? .endOfSection
        privacy = (try? container.decode(ShortcutPrivacy.self, forKey: .privacy)) ?? .personal
        indexing = (try? container.decode(ShortcutIndexing.self, forKey: .indexing)) ?? .inherit
        llmRouting = (try? container.decode(ShortcutLLMRouting.self, forKey: .llmRouting)) ?? ShortcutLLMRouting.none
        contentMode = (try? container.decode(ShortcutContentMode.self, forKey: .contentMode)) ?? .expanded
        openNoteOverride = (try? container.decode(ShortcutOptionOverride.self, forKey: .openNoteOverride)) ?? .inherit
        includeSourceOverride = (try? container.decode(ShortcutOptionOverride.self, forKey: .includeSourceOverride)) ?? .inherit
        includeDocumentSourceOverride = (try? container.decode(ShortcutOptionOverride.self, forKey: .includeDocumentSourceOverride)) ?? .inherit
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
    }

    var slot: ShortcutSlot {
        ShortcutSlot(
            index: max(1, min(index, Settings.shortcutSlotCount)),
            enabled: enabled,
            combo: KeyCombo(keyCode: keyCode, carbonModifiers: normalizedCarbonModifiers(modifiers)),
            action: action ?? .capture,
            marker: marker ?? .task,
            priority: priority ?? .none,
            schedule: schedule ?? .none,
            output: output ?? ShortcutOutput(engine: engine, destination: destination),
            engine: engine,
            destination: destination,
            noteReference: notePath,
            folder: folder,
            section: (section ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            insertPosition: insertPosition ?? .endOfSection,
            privacy: privacy ?? .personal,
            indexing: indexing ?? .inherit,
            llmRouting: llmRouting ?? .none,
            contentMode: contentMode ?? .expanded,
            openNoteOverride: openNoteOverride ?? .inherit,
            includeSourceOverride: includeSourceOverride ?? .inherit,
            includeDocumentSourceOverride: includeDocumentSourceOverride ?? .inherit,
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

private func visibleShortcutTags(_ value: String) -> String {
    value
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("!") && !isGeneratedConfigToken($0) }
        .joined(separator: ", ")
}

private func isGeneratedConfigToken(_ value: String) -> Bool {
    let lowercased = value.lowercased()
    return [
        "$mark:", "$prio:", "$date:", "$open:", "$web:", "$file:",
        "$sec:", "$pos:", "$privacy:", "$idx:", "$llm:", "$content:"
    ].contains { lowercased.hasPrefix($0) }
}

private func normalizedPreferenceTags(_ value: String) -> [String] {
    value
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .filter { !$0.hasPrefix("!") && !isGeneratedConfigToken($0) }
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

private func noteDroopyLogoImage(size: NSSize? = nil) -> NSImage {
    let image: NSImage
    if let url = Bundle.main.url(forResource: "notedroppy-logo", withExtension: "png"),
       let bundled = NSImage(contentsOf: url) {
        image = bundled
    } else {
        image = NSApplication.shared.applicationIconImage
    }
    if let size {
        image.size = size
    }
    return image
}

private func styleFillableField(_ field: NSTextField) {
    field.drawsBackground = true
    field.backgroundColor = NSColor.controlBackgroundColor.blended(withFraction: 0.16, of: .white) ?? .controlBackgroundColor
    field.textColor = .labelColor
}

private func styleConfigField(_ field: NSTextField) {
    styleFillableField(field)
    field.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.12)
    field.wantsLayer = true
    field.layer?.cornerRadius = 5
    field.layer?.borderWidth = 1
    field.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.35).cgColor
}

private func applyTagsConfigColors(to field: NSTextField) {
    let value = field.stringValue
    let baseFont = field.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
    let attributed = NSMutableAttributedString(
        string: value,
        attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: baseFont
        ]
    )
    let styles: [(pattern: String, color: NSColor)] = [
        (#"#[^\s,]+"#, NSColor(calibratedRed: 0.38, green: 0.78, blue: 0.48, alpha: 1.0)),
        (#"\$[A-Za-z][A-Za-z0-9_]*"#, NSColor(calibratedRed: 0.40, green: 0.68, blue: 0.95, alpha: 1.0)),
        (#"![A-Za-z][A-Za-z0-9_]*"#, NSColor(calibratedRed: 0.56, green: 0.64, blue: 0.95, alpha: 1.0)),
        (#"@[^\s,]+"#, NSColor(calibratedRed: 0.95, green: 0.58, blue: 0.30, alpha: 1.0)),
        (#"\$(?:mark|prio|date|open|web|file|sec|pos|privacy|idx|llm|content):[^\s,]+"#, NSColor(calibratedRed: 0.98, green: 0.36, blue: 0.36, alpha: 1.0))
    ]
    let fullRange = NSRange(value.startIndex..<value.endIndex, in: value)
    for style in styles {
        guard let regex = try? NSRegularExpression(pattern: style.pattern) else { continue }
        for match in regex.matches(in: value, range: fullRange) {
            attributed.addAttributes([
                .foregroundColor: style.color,
                .font: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .medium)
            ], range: match.range)
        }
    }
    field.attributedStringValue = attributed
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
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
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

final class ShortcutMakerDropView: NSView {
    var onDropTarget: ((ShortcutTarget) -> Bool)?
    private let titleLabel = NSTextField(labelWithString: "Déposer une note NotePlan ici")
    private let detailLabel = NSTextField(labelWithString: "Glisser une note .md depuis Finder, ou un lien noteplan:// depuis NotePlan.")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        registerForDraggedTypes(shortcutDropPasteboardTypes)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 2

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(detailLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 150),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        writeDebugLog("shortcut-maker-drop:entered:\(pasteboardDebugDescription(sender.draggingPasteboard))")
        guard shortcutTarget(from: sender.draggingPasteboard) != nil else { return NSDragOperation() }
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        return preferredDragOperation(from: sender.draggingSourceOperationMask)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        shortcutTarget(from: sender.draggingPasteboard) == nil
            ? NSDragOperation()
            : preferredDragOperation(from: sender.draggingSourceOperationMask)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        resetDropStyle()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        writeDebugLog("shortcut-maker-drop:perform:\(pasteboardDebugDescription(sender.draggingPasteboard))")
        resetDropStyle()
        guard let target = shortcutTarget(from: sender.draggingPasteboard) else {
            NSSound.beep()
            return false
        }
        return onDropTarget?(target) ?? false
    }

    private func resetDropStyle() {
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
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

final class ShortcutTargetPopUpButton: NSPopUpButton {
    var acceptsDrop = true
    var onDropTarget: ((ShortcutTarget) -> Bool)?

    convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }

    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        registerForDraggedTypes(shortcutDropPasteboardTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(shortcutDropPasteboardTypes)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        writeDebugLog("shortcut-drop:popup:entered:\(pasteboardDebugDescription(sender.draggingPasteboard))")
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
        writeDebugLog("shortcut-drop:popup:perform:\(pasteboardDebugDescription(sender.draggingPasteboard))")
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

private func resolveObsidianVaultPath(named vaultName: String) -> String? {
    let cleanVault = vaultName.removingPercentEncoding?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? vaultName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanVault.isEmpty else { return nil }

    let home = FileManager.default.homeDirectoryForCurrentUser
    let roots = [
        home.appendingPathComponent("Desktop"),
        home.appendingPathComponent("Documents"),
        home.appendingPathComponent("Library/Mobile Documents/iCloud~md~obsidian/Documents")
    ]

    for root in roots {
        let candidate = root.appendingPathComponent(cleanVault)
        let marker = candidate.appendingPathComponent(".obsidian")
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: marker.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return candidate.path
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

final class PayloadButton: NSButton {
    var payload: Any?
}

final class AdvancedPreviewController: NSObject, NSTextFieldDelegate {
    weak var markerPopup: NSPopUpButton?
    weak var priorityPopup: NSPopUpButton?
    weak var schedulePopup: NSPopUpButton?
    weak var contentPopup: NSPopUpButton?
    weak var openPopup: NSPopUpButton?
    weak var webPopup: NSPopUpButton?
    weak var filePopup: NSPopUpButton?
    weak var sectionInput: NSTextField?
    weak var positionPopup: NSPopUpButton?
    weak var privacyPopup: NSPopUpButton?
    weak var indexingPopup: NSPopUpButton?
    weak var llmPopup: NSPopUpButton?
    weak var previewLabel: NSTextField?
    weak var orderLabel: NSTextField?

    @objc func update() {
        previewLabel?.attributedStringValue = preview()
        orderLabel?.stringValue = order()
    }

    func controlTextDidChange(_ obj: Notification) {
        update()
    }

    private func value(_ popup: NSPopUpButton?) -> String {
        popup?.titleOfSelectedItem?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func order() -> String {
        "ordre : marqueur -> priorité -> contenu -> date -> tags -> config"
    }

    private func preview() -> NSAttributedString {
        let marker = value(markerPopup)
        let priority = value(priorityPopup)
        let schedule = value(schedulePopup)
        let section = sectionInput?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let position = value(positionPopup)
        let privacy = value(privacyPopup)
        let llm = value(llmPopup)

        let markerText: String
        switch marker {
        case "*": markerText = "*"
        case "+": markerText = "+"
        case "Texte": markerText = ""
        default: markerText = "- [ ]"
        }

        var pieces = [markerText, priority == "Aucune" ? "" : priority, "Texte capturé"]
            .filter { !$0.isEmpty }
        if schedule != "Aucune" {
            pieces.append(">\(schedule)")
        }
        pieces.append("#capture")

        var configs: [String] = []
        if value(webPopup) != "G" { configs.append("$web:\(value(webPopup).lowercased())") }
        if value(filePopup) != "G" { configs.append("$file:\(value(filePopup).lowercased())") }
        if value(openPopup) != "G" { configs.append("$open:\(value(openPopup).lowercased())") }
        if !section.isEmpty { configs.append("$sec:\(section)") }
        if position != "Fin section" { configs.append("$pos:\(position)") }
        if privacy != "Perso" { configs.append("$privacy:\(privacy.lowercased())") }
        if llm != "Aucun" { configs.append("$llm:\(llm.lowercased())") }

        let text = (pieces + configs).joined(separator: " ")
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let styles: [(String, NSColor)] = [
            (#"#[^\s]+"#, NSColor(calibratedRed: 0.38, green: 0.78, blue: 0.48, alpha: 1.0)),
            (#"\$[^\s]+"#, NSColor(calibratedRed: 0.98, green: 0.36, blue: 0.36, alpha: 1.0)),
            (#">[^\s]+"#, NSColor(calibratedRed: 0.40, green: 0.68, blue: 0.95, alpha: 1.0)),
            (#"!!?!"#, NSColor(calibratedRed: 0.98, green: 0.70, blue: 0.30, alpha: 1.0))
        ]
        for (pattern, color) in styles {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: fullRange) {
                attributed.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
        return attributed
    }
}

final class ShortcutSlotRow: NSObject, NSTextFieldDelegate {
    let index: Int
    let enabledCheckbox: NSButton
    let recorder: ShortcutRecorderButton
    let actionPopup = NSPopUpButton()
    let outputPopup = ShortcutTargetPopUpButton()
    let enginePopup = ShortcutTargetPopUpButton()
    let destinationPopup = ShortcutTargetPopUpButton()
    let folderField: NSTextField
    let noteField: NSTextField
    let searchButton = NSButton(title: "Rechercher", target: nil, action: nil)
    let targetField = ShortcutTargetField()
    let sectionField: NSTextField
    let insertPositionPopup = NSPopUpButton()
    let openNoteOverridePopup = NSPopUpButton()
    let includeSourceOverridePopup = NSPopUpButton()
    let includeDocumentSourceOverridePopup = NSPopUpButton()
    let tagsField: NSTextField
    let advancedButton = NSButton(title: "+", target: nil, action: nil)
    var onSearch: ((ShortcutSlotRow) -> Void)?
    var onAdvanced: ((ShortcutSlotRow) -> Void)?
    var onTargetDrop: ((ShortcutSlotRow, ShortcutTarget) -> Bool)?
    var onPasteTarget: ((ShortcutSlotRow) -> Void)?
    var onFocus: ((ShortcutSlotRow) -> Void)?
    var onChange: ((ShortcutSlotRow) -> Void)?
    private weak var rowView: NSStackView?
    private var storedCombo: KeyCombo
    var marker: ShortcutMarker
    var priority: ShortcutPriority
    var schedule: ShortcutSchedule
    var privacy: ShortcutPrivacy
    var indexing: ShortcutIndexing
    var llmRouting: ShortcutLLMRouting
    var contentMode: ShortcutContentMode
    private var displayIndex: String { index == 10 ? "0" : "\(index)" }

    init(slot: ShortcutSlot) {
        self.index = slot.index
        self.storedCombo = slot.combo
        self.marker = slot.marker
        self.priority = slot.priority
        self.schedule = slot.schedule
        self.privacy = slot.privacy
        self.indexing = slot.indexing
        self.llmRouting = slot.llmRouting
        self.contentMode = slot.contentMode
        self.enabledCheckbox = NSButton(checkboxWithTitle: slot.index == 10 ? "0" : "\(slot.index)", target: nil, action: nil)
        self.recorder = ShortcutRecorderButton(combo: slot.combo)
        self.folderField = NSTextField(string: slot.folder)
        self.noteField = NSTextField(string: slot.noteReference)
        self.sectionField = NSTextField(string: slot.section)
        self.tagsField = NSTextField(string: visibleShortcutTags(slot.tags))

        super.init()

        enabledCheckbox.state = slot.enabled ? .on : .off
        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(rowChanged)
        ShortcutAction.allCases.forEach { actionPopup.addItem(withTitle: $0.title) }
        actionPopup.selectItem(withTitle: slot.action.title)
        actionPopup.target = self
        actionPopup.action = #selector(actionChanged)
        ShortcutOutput.allCases.forEach { outputPopup.addItem(withTitle: $0.title) }
        outputPopup.selectItem(withTitle: slot.output.title)
        outputPopup.target = self
        outputPopup.action = #selector(outputChanged)
        ShortcutEngine.allCases.forEach { enginePopup.addItem(withTitle: $0.title) }
        enginePopup.selectItem(withTitle: slot.engine.title)
        enginePopup.target = self
        enginePopup.action = #selector(engineChanged)
        Settings.destinations(forShortcut: slot.index).forEach { destinationPopup.addItem(withTitle: $0.title) }
        destinationPopup.selectItem(withTitle: Settings.validDestination(slot.destination, for: slot.index).title)
        destinationPopup.target = self
        destinationPopup.action = #selector(destinationChanged)
        [outputPopup, enginePopup, destinationPopup].forEach { (popup: ShortcutTargetPopUpButton) in
            popup.acceptsDrop = true
            popup.onDropTarget = { [weak self] target in
                guard let self else { return false }
                return self.onTargetDrop?(self, target) ?? false
            }
        }
        folderField.placeholderString = "Dossier"
        noteField.placeholderString = placeholder(for: slot.output.destination)
        sectionField.placeholderString = "Notes et idées"
        ShortcutInsertPosition.allCases.forEach { insertPositionPopup.addItem(withTitle: $0.title) }
        insertPositionPopup.selectItem(withTitle: slot.insertPosition.title)
        insertPositionPopup.target = self
        insertPositionPopup.action = #selector(rowChanged)
        configureOverridePopup(openNoteOverridePopup, selected: slot.openNoteOverride, toolTip: "Ouvrir l'app après capture")
        configureOverridePopup(includeSourceOverridePopup, selected: slot.includeSourceOverride, toolTip: "Ajouter source web")
        configureOverridePopup(includeDocumentSourceOverridePopup, selected: slot.includeDocumentSourceOverride, toolTip: "Ajouter source document")
        targetField.placeholderString = ""
        applyTargetDisplay(targetDisplay(for: slot.output.destination, folder: slot.folder, note: slot.noteReference))
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
        sectionField.delegate = self
        sectionField.target = self
        sectionField.action = #selector(rowChanged)
        advancedButton.target = self
        advancedButton.action = #selector(showAdvanced)
        advancedButton.bezelStyle = .rounded
        advancedButton.toolTip = "Options avancées : marqueur, priorité, date, source, confidentialité, indexation, LLM, contenu"
        refreshAdvancedBadge()
        tagsField.placeholderString = "#capture, #LLM, @client"
        tagsField.delegate = self
        tagsField.target = self
        tagsField.action = #selector(rowChanged)
        [folderField, noteField, sectionField, tagsField].forEach(styleFillableField)
        styleConfigField(tagsField)
        refreshTagsConfigDisplay()

        [enabledCheckbox, recorder, actionPopup, outputPopup, enginePopup, destinationPopup, folderField, noteField, searchButton, targetField, sectionField, insertPositionPopup, openNoteOverridePopup, includeSourceOverridePopup, includeDocumentSourceOverridePopup, tagsField, advancedButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        enabledCheckbox.widthAnchor.constraint(equalToConstant: Self.columnWidths[0]).isActive = true
        recorder.widthAnchor.constraint(equalToConstant: Self.columnWidths[1]).isActive = true
        actionPopup.widthAnchor.constraint(equalToConstant: Self.columnWidths[2]).isActive = true
        advancedButton.widthAnchor.constraint(equalToConstant: Self.columnWidths[3]).isActive = true
        outputPopup.widthAnchor.constraint(equalToConstant: Self.columnWidths[4]).isActive = true
        enginePopup.widthAnchor.constraint(equalToConstant: 112).isActive = true
        destinationPopup.widthAnchor.constraint(equalToConstant: 142).isActive = true
        targetField.widthAnchor.constraint(equalToConstant: Self.columnWidths[5]).isActive = true
        searchButton.widthAnchor.constraint(equalToConstant: 88).isActive = true
        tagsField.widthAnchor.constraint(equalToConstant: Self.columnWidths[6]).isActive = true
        refreshNoteFieldState()
    }

    static let columnSpacing: CGFloat = 12
    static let columnTitles = ["Actif", "Raccourci", "Action", "+", "Sortie", "Cible", "Tag & Config"]
    static let columnWidths: [CGFloat] = [42, 86, 132, 36, 138, 150, 430]

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
        let output = selectedOutput()
        let destination = output.destination
        return ShortcutSlot(
            index: index,
            enabled: enabledCheckbox.state == .on,
            combo: storedCombo,
            action: selectedAction(),
            marker: marker,
            priority: priority,
            schedule: schedule,
            output: output,
            engine: output.engine,
            destination: destination,
            noteReference: output.engine == .obsidian || destination.acceptsTarget ? noteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            folder: output.engine == .obsidian || destination.acceptsTarget ? folderField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            section: sectionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            insertPosition: selectedInsertPosition(),
            privacy: privacy,
            indexing: indexing,
            llmRouting: llmRouting,
            contentMode: contentMode,
            openNoteOverride: selectedOverride(openNoteOverridePopup),
            includeSourceOverride: selectedOverride(includeSourceOverridePopup),
            includeDocumentSourceOverride: selectedOverride(includeDocumentSourceOverridePopup),
            tags: plainTagsFromField()
        )
    }

    func setCombo(_ combo: KeyCombo) {
        storedCombo = combo
        recorder.setCombo(combo)
    }

    func setEngine(_ engine: ShortcutEngine) {
        enginePopup.selectItem(withTitle: engine.title)
        refreshNoteFieldState()
    }

    func view() -> NSView {
        let row = ShortcutSlotDropStack()
        row.orientation = .horizontal
        row.spacing = Self.columnSpacing
        row.alignment = .centerY
        row.acceptsDrop = true
        row.wantsLayer = true
        row.layer?.cornerRadius = 6
        row.onDropTarget = { [weak self] target in
            guard let self else { return false }
            return self.onTargetDrop?(self, target) ?? false
        }
        rowView = row
        row.addArrangedSubview(enabledCheckbox)
        row.addArrangedSubview(recorder)
        row.addArrangedSubview(actionPopup)
        row.addArrangedSubview(advancedButton)
        row.addArrangedSubview(outputPopup)
        row.addArrangedSubview(targetField)
        row.addArrangedSubview(tagsField)
        return row
    }

    func setActive(_ active: Bool) {
        rowView?.layer?.backgroundColor = active ? NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor : NSColor.clear.cgColor
        tagsField.layer?.borderColor = active ? NSColor.controlAccentColor.cgColor : NSColor.systemBlue.withAlphaComponent(0.35).cgColor
        tagsField.layer?.borderWidth = active ? 1.6 : 1.0
    }

    func applySelectedNote(_ result: NoteSearchResult) {
        destinationPopup.selectItem(withTitle: ShortcutDestination.notePath.title)
        folderField.stringValue = result.folder
        noteField.stringValue = URL(fileURLWithPath: result.relativePath).lastPathComponent
        applyTargetDisplay(targetDisplay(for: .notePath, folder: result.folder, note: URL(fileURLWithPath: result.relativePath).lastPathComponent))
        if tagsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tagsField.stringValue = result.tags.prefix(4).joined(separator: ", ")
        }
        refreshTagsConfigDisplay()
        refreshNoteFieldState()
    }

    func apply(slot: ShortcutSlot) {
        let output = slot.output
        let destination = Settings.validDestination(output.destination, for: index)
        enabledCheckbox.state = slot.enabled ? .on : .off
        enabledCheckbox.title = displayIndex
        setCombo(slot.combo)
        marker = slot.marker
        priority = slot.priority
        schedule = slot.schedule
        privacy = slot.privacy
        indexing = slot.indexing
        llmRouting = slot.llmRouting
        contentMode = slot.contentMode
        refreshAdvancedBadge()
        actionPopup.selectItem(withTitle: slot.action.title)
        outputPopup.selectItem(withTitle: output.title)
        enginePopup.selectItem(withTitle: output.engine.title)
        destinationPopup.removeAllItems()
        Settings.destinations(forShortcut: index).forEach { destinationPopup.addItem(withTitle: $0.title) }
        destinationPopup.selectItem(withTitle: destination.title)
        folderField.stringValue = slot.folder
        noteField.stringValue = slot.noteReference
        applyTargetDisplay(targetDisplay(for: destination, folder: slot.folder, note: slot.noteReference))
        sectionField.stringValue = slot.section
        insertPositionPopup.selectItem(withTitle: slot.insertPosition.title)
        tagsField.stringValue = visibleShortcutTags(slot.tags)
        refreshTagsConfigDisplay()
        noteField.placeholderString = placeholder(for: destination)
        refreshNoteFieldState()
    }

    @objc private func engineChanged() {
        refreshNoteFieldState()
        rowChanged()
    }

    @objc private func actionChanged() {
        rowChanged()
    }

    @objc private func outputChanged() {
        let output = selectedOutput()
        enginePopup.selectItem(withTitle: output.engine.title)
        destinationPopup.selectItem(withTitle: Settings.validDestination(output.destination, for: index).title)
        noteField.placeholderString = placeholder(for: output.destination)
        applyTargetDisplay(targetDisplay(for: output.destination, folder: folderField.stringValue, note: noteField.stringValue))
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

    @objc private func showAdvanced() {
        onAdvanced?(self)
    }

    func applyAdvanced(
        marker: ShortcutMarker,
        priority: ShortcutPriority,
        schedule: ShortcutSchedule,
        privacy: ShortcutPrivacy,
        indexing: ShortcutIndexing,
        llmRouting: ShortcutLLMRouting,
        contentMode: ShortcutContentMode
    ) {
        self.marker = marker
        self.priority = priority
        self.schedule = schedule
        self.privacy = privacy
        self.indexing = indexing
        self.llmRouting = llmRouting
        self.contentMode = contentMode
        refreshAdvancedBadge()
        refreshTagsConfigDisplay()
        rowChanged()
    }

    private func refreshAdvancedBadge() {
        let hasAdvanced = marker != .task
            || priority != .none
            || schedule != .none
            || privacy != .personal
            || indexing != .inherit
            || llmRouting != .none
            || contentMode != .expanded
            || !sectionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedInsertPosition() != .endOfSection
        advancedButton.title = hasAdvanced ? "+✓" : "+"
        advancedButton.contentTintColor = hasAdvanced ? .systemRed : nil
        if hasAdvanced {
            advancedButton.toolTip = "Config avancée active"
        } else {
            advancedButton.toolTip = "Ajouter une config avancée"
        }
    }

    private func plainTagsFromField() -> String {
        visibleShortcutTags(tagsField.stringValue)
    }

    private func refreshTagsConfigDisplay() {
        let tags = plainTagsFromField()
        let tokens = advancedConfigTokens()
        tagsField.stringValue = ([tags] + tokens).filter { !$0.isEmpty }.joined(separator: ", ")
        applyTagsConfigColors(to: tagsField)
    }

    private func advancedConfigTokens() -> [String] {
        var tokens: [String] = []
        if marker != .task {
            tokens.append(marker == .bulletStar ? "$mark:*" : marker == .bulletPlus ? "$mark:+" : "$mark:text")
        }
        if priority != .none {
            tokens.append("$prio:\(priority.title)")
        }
        if schedule != .none {
            tokens.append("$date:\(schedule.rawValue)")
        }
        if selectedOverride(openNoteOverridePopup) != .inherit {
            tokens.append("$open:\(selectedOverride(openNoteOverridePopup).rawValue)")
        }
        if selectedOverride(includeSourceOverridePopup) != .inherit {
            tokens.append("$web:\(selectedOverride(includeSourceOverridePopup).rawValue)")
        }
        if selectedOverride(includeDocumentSourceOverridePopup) != .inherit {
            tokens.append("$file:\(selectedOverride(includeDocumentSourceOverridePopup).rawValue)")
        }
        if !sectionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tokens.append("$sec:set")
        }
        if selectedInsertPosition() != .endOfSection {
            tokens.append("$pos:\(selectedInsertPosition().rawValue)")
        }
        if privacy != .personal {
            tokens.append("$privacy:\(privacy.rawValue)")
        }
        if indexing != .inherit {
            tokens.append("$idx:\(indexing.rawValue)")
        }
        if llmRouting != .none {
            tokens.append("$llm:\(llmRouting.rawValue)")
        }
        if contentMode != .expanded {
            tokens.append("$content:\(contentMode.rawValue)")
        }
        return tokens
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
        if let field = obj.object as? NSTextField, field === tagsField {
            refreshTagsConfigDisplay()
        }
        onChange?(self)
    }

    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField, field === tagsField {
            applyTagsConfigColors(to: tagsField)
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        onFocus?(self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === targetField, commandSelector == #selector(NSText.paste(_:)) else {
            return false
        }
        onPasteTarget?(self)
        return true
    }

    private func selectedEngine() -> ShortcutEngine {
        selectedOutput().engine
    }

    private func selectedDestination() -> ShortcutDestination {
        Settings.validDestination(selectedOutput().destination, for: index)
    }

    private func selectedAction() -> ShortcutAction {
        ShortcutAction.allCases.first { $0.title == actionPopup.titleOfSelectedItem } ?? .capture
    }

    private func selectedOutput() -> ShortcutOutput {
        let selected = ShortcutOutput.allCases.first { $0.title == outputPopup.titleOfSelectedItem } ?? (index == 1 ? .todayNotePlan : .standardMarkdown)
        if index != 1, selected == .todayNotePlan {
            return .standardMarkdown
        }
        return selected
    }

    private func selectedInsertPosition() -> ShortcutInsertPosition {
        ShortcutInsertPosition.allCases.first { $0.title == insertPositionPopup.titleOfSelectedItem } ?? .endOfSection
    }

    private func selectedOverride(_ popup: NSPopUpButton) -> ShortcutOptionOverride {
        ShortcutOptionOverride.allCases.first { $0.title == popup.titleOfSelectedItem } ?? .inherit
    }

    private func configureOverridePopup(_ popup: NSPopUpButton, selected: ShortcutOptionOverride, toolTip: String) {
        ShortcutOptionOverride.allCases.forEach { popup.addItem(withTitle: $0.title) }
        popup.selectItem(withTitle: selected.title)
        popup.target = self
        popup.action = #selector(rowChanged)
        popup.toolTip = "\(toolTip) : G=Global, Oui=forcé actif, Non=forcé inactif"
    }

    private func tagConfigOverride(positive: String, negative: String) -> ShortcutOptionOverride {
        let tokens = configTokens(in: tagsField.stringValue)
        if tokens.contains(negative.lowercased()) { return .disabled }
        if tokens.contains(positive.lowercased()) { return .enabled }
        return .inherit
    }

    private func configTokens(in tags: String) -> Set<String> {
        Set(tags
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.hasPrefix("!") })
    }

    private func refreshNoteFieldState() {
        let output = selectedOutput()
        let engine = selectedEngine()
        let destination = selectedDestination()
        let acceptsTarget = engine == .obsidian || destination.acceptsTarget
        destinationPopup.isEnabled = engine == .notePlan
        folderField.isEnabled = acceptsTarget
        noteField.isEnabled = acceptsTarget
        let isAutomaticToday = output == .todayNotePlan
        targetField.isEditable = !isAutomaticToday
        targetField.isSelectable = true
        targetField.acceptsDrop = !isAutomaticToday
        searchButton.isEnabled = true
        if isAutomaticToday {
            folderField.stringValue = ""
            noteField.stringValue = ""
            applyTargetDisplay(targetDisplay(for: destination, folder: "", note: ""))
        } else if engine == .obsidian {
            folderField.placeholderString = "Vault Obsidian"
            noteField.placeholderString = "Inbox/Captures.md"
            if targetField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || targetField.stringValue == "Raccourci standard" || targetField.stringValue == "Automatique aujourd'hui" {
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
        if !folderField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           value == noteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) {
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
        if !clean.contains("/"),
           !folderField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            noteField.stringValue = clean
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

    func applyDroppedObsidianURI(vault: String?, note: String) {
        setEngine(.obsidian)
        let cleanNote = note.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        if !cleanNote.isEmpty {
            noteField.stringValue = cleanNote.hasSuffix(".md") ? cleanNote : "\(cleanNote).md"
        }
        if folderField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let vault,
           !vault.isEmpty {
            folderField.stringValue = resolveObsidianVaultPath(named: vault) ?? vault
        }
        applyTargetDisplay(targetDisplay(for: .notePath, folder: folderField.stringValue, note: noteField.stringValue))
        refreshNoteFieldState()
    }

    private func applyTargetDisplay(_ fullText: String) {
        targetField.toolTip = fullText.contains("/") ? fullText : nil
        targetField.stringValue = compactTargetDisplay(fullText)
    }

    private func compactTargetDisplay(_ fullText: String) -> String {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "Déposer" || trimmed == "Raccourci standard" || trimmed.contains("Déposer depuis Finder") || trimmed.contains("coller un lien NotePlan") {
            return ""
        }
        if trimmed == "Automatique aujourd'hui" {
            return "Aujourd'hui"
        }
        guard trimmed.contains("/"), !trimmed.hasSuffix("/") else { return trimmed }
        let fileName = URL(fileURLWithPath: trimmed).lastPathComponent
        return fileName.isEmpty ? trimmed : fileName
    }

    private func targetDisplay(for destination: ShortcutDestination, folder: String, note: String) -> String {
        if selectedEngine() == .obsidian {
            let cleanVault = folder.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanNote = note.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
            if cleanVault.isEmpty && cleanNote.isEmpty { return "Vault Obsidian + note .md" }
            if cleanNote.isEmpty { return cleanVault }
            return cleanNote
        }
        if destination == .standard { return "" }
        if destination == .today { return "Automatique aujourd'hui" }
        let cleanFolder = folder.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        let cleanNote = note.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        if cleanFolder.isEmpty && cleanNote.isEmpty { return "" }
        if cleanFolder.isEmpty { return cleanNote }
        if cleanNote.isEmpty { return "\(cleanFolder)/" }
        return cleanNote
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

final class SettingsWindowController: NSWindowController, NSTabViewDelegate {
    private let serviceNameField = NSTextField(string: Settings.serviceName)
    private let tagField = NSTextField(string: visibleShortcutTags(Settings.taskTag))
    private let captureSectionField = NSTextField(string: Settings.captureSection)
    private let notesRootField = NSTextField(string: Settings.notesRootPath)
    private let chooseNotesRootButton = NSButton(title: "Choisir dossier Notes", target: nil, action: nil)
    private let openNoteCheckbox = NSButton(checkboxWithTitle: "Ouvrir NotePlan après l'ajout", target: nil, action: nil)
    private let includeSourceCheckbox = NSButton(checkboxWithTitle: "Ajouter la source (lien capturé)", target: nil, action: nil)
    private let includeDocumentSourceCheckbox = NSButton(checkboxWithTitle: "Ajouter la source document (titre + lien fichier)", target: nil, action: nil)
    private let configWebPopup = NSPopUpButton()
    private let configFilePopup = NSPopUpButton()
    private let addConfigButton = NSButton(title: "Ajouter tokens", target: nil, action: nil)
    private let replaceConfigButton = NSButton(title: "Réappliquer", target: nil, action: nil)
    private var shortcutRows: [ShortcutSlotRow] = []
    private weak var activeConfigRow: ShortcutSlotRow?
    private let slotsStack = NSStackView()
    private let addShortcutButton = NSButton(title: "+ Ajouter raccourci", target: nil, action: nil)
    private let shortcutHelpLabel = NSTextField(labelWithString: "Ligne 1 par défaut : NotePlan + Aujourd'hui (NotePlan). Sinon choisir Standard, déposer depuis Finder une note .md, ou coller un lien NotePlan.")
    private let variablesHelpLabel = NSTextField(labelWithString: "Variables : $date, $day, $time, $datetime, $month, $year")
    private let helpButton = NSButton(title: "Aide", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Autoriser Accessibilité", target: nil, action: nil)
    private let exportButton = NSButton(title: "Exporter JSON", target: nil, action: nil)
    private let importButton = NSButton(title: "Importer JSON", target: nil, action: nil)
    private let captureRulesButton = NSButton(title: "Règles capture", target: nil, action: nil)
    private let captureRulesHelpButton = NSButton(title: "Doc formats", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "Enregistrer", target: nil, action: nil)
    private let shortcutMakerNoteField = NSTextField(labelWithString: "")
    private let shortcutMakerDestinationField = NSTextField(labelWithString: "")
    private let shortcutMakerOpenWithField = NSTextField(labelWithString: "")
    private let shortcutMakerDropView = ShortcutMakerDropView()
    private let shortcutMakerRecentTextView = NSTextView()
    private let nc2Controller = NotePlanEditorWindowController()
    private var generatedShortcutURL: URL?
    private let shortcutMakerNotePathKey = "noteplanShortcutMaker.notePath"
    private let shortcutMakerNoteURLKey = "noteplanShortcutMaker.noteURL"
    private let shortcutMakerNoteDisplayKey = "noteplanShortcutMaker.noteDisplay"
    private let shortcutMakerDestinationPathKey = "noteplanShortcutMaker.destinationPath"
    private let shortcutMakerOpenWithAppPathKey = "noteplanShortcutMaker.openWithAppPath"
    private let shortcutMakerRecentShortcutsKey = "noteplanShortcutMaker.recentShortcuts"
    private var hasPendingChanges = false
    private var pasteMonitor: Any?

    convenience init() {
        let window = centeredWindow("Préférences NoteDroppy", width: 1220, height: 860, style: [.titled, .closable, .miniaturizable, .resizable])
        window.minSize = NSSize(width: 1220, height: 860)
        window.setContentSize(NSSize(width: 1220, height: 860))
        self.init(window: window)
        buildContent()
    }

    private func configBuilderView() -> NSView {
        addShortcutButton.target = self
        addShortcutButton.action = #selector(addVisibleShortcut)
        addShortcutButton.bezelStyle = .rounded

        let row = horizontalRow(spacing: 8)
        let label = NSTextField(labelWithString: "Tags visibles dans la note. Le reste est dans Avancé…")
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        row.addArrangedSubview(label)
        row.addArrangedSubview(addShortcutButton)
        return row
    }

    private func configureConfigPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        ["Global", "Oui", "Non"].forEach { popup.addItem(withTitle: $0) }
        popup.selectItem(withTitle: "Global")
        popup.target = self
        popup.action = #selector(configPopupChanged)
        popup.toolTip = "Global = reglage general, Oui/Non ajoute un token ! dans la case Tags / Config selectionnee"
        popup.wantsLayer = true
        popup.layer?.cornerRadius = 6
        popup.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.12).cgColor
        popup.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.35).cgColor
        popup.layer?.borderWidth = 1
    }

    @objc private func configPopupChanged(_ sender: NSPopUpButton) {
        applyConfigToActiveShortcut(replace: true, automatic: true)
    }

    private func tagsConfigLegendView() -> NSView {
        let row = horizontalRow(spacing: 10)
        row.addArrangedSubview(formLabel("Format", width: 118))
        let label = NSTextField(labelWithString: "#tag, @contexte, $variable. Avancé = priorité, date, source, confidentialité, LLM, contenu.")
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        row.addArrangedSubview(label)
        return row
    }

    @discardableResult
    private func addShortcutRow(for slot: ShortcutSlot) -> ShortcutSlotRow {
        let row = ShortcutSlotRow(slot: slot)
        row.recorder.onChange = { [weak self, weak row] combo in
            guard let row else { return }
            self?.setActiveConfigRow(row)
            row.setCombo(combo)
            self?.autosaveSettings(message: "Raccourci enregistré.")
        }
        row.onSearch = { [weak self] row in
            self?.setActiveConfigRow(row)
            self?.showNoteSearch(for: row)
        }
        row.advancedButton.target = self
        row.advancedButton.action = #selector(openAdvancedFromButton(_:))
        row.advancedButton.tag = row.index
        row.onAdvanced = { [weak self] row in
            self?.setActiveConfigRow(row)
            self?.showAdvancedSettings(for: row)
        }
        row.onTargetDrop = { [weak self] row, target in
            self?.setActiveConfigRow(row)
            return self?.applyDroppedTarget(target, to: row) ?? false
        }
        row.onPasteTarget = { [weak self] row in
            self?.setActiveConfigRow(row)
            self?.pasteTarget(for: self?.activeShortcutRow(defaultingTo: row) ?? row)
        }
        row.onFocus = { [weak self] row in
            self?.setActiveConfigRow(row)
            self?.statusLabel.stringValue = "Ligne \(row.index) sélectionnée pour Tags / Config."
        }
        row.onChange = { [weak self] row in
            self?.setActiveConfigRow(row)
            self?.autosaveSettings(message: "Réglages enregistrés.")
        }
        shortcutRows.append(row)
        slotsStack.addArrangedSubview(row.view())
        addShortcutButton.isEnabled = shortcutRows.count < Settings.shortcutSlotCount
        return row
    }

    @objc private func openAdvancedFromButton(_ sender: NSButton) {
        guard let row = shortcutRows.first(where: { $0.index == sender.tag }) else { return }
        setActiveConfigRow(row)
        showAdvancedSettings(for: row)
    }

    private func setActiveConfigRow(_ row: ShortcutSlotRow) {
        activeConfigRow = row
        shortcutRows.forEach { $0.setActive($0 === row) }
    }

    private func advancedPopup<T: CaseIterable>(_ values: [T], selected: T, title: (T) -> String) -> NSPopUpButton where T: Equatable {
        let popup = NSPopUpButton()
        values.forEach { popup.addItem(withTitle: title($0)) }
        popup.selectItem(withTitle: title(selected))
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: 132).isActive = true
        return popup
    }

    private func advancedLine(_ title: String, _ control: NSView) -> NSView {
        let row = horizontalRow(spacing: 8)
        row.alignment = .centerY
        row.addArrangedSubview(formLabel(title, width: 86))
        row.addArrangedSubview(control)
        return row
    }

    private func advancedGroup(_ title: String, rows: [NSView]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabelColor
        stack.addArrangedSubview(label)
        rows.forEach { stack.addArrangedSubview($0) }
        return stack
    }

    private func selectedAdvancedValue<T: CaseIterable>(_ type: T.Type, popup: NSPopUpButton, title: (T) -> String, fallback: T) -> T where T: Equatable {
        T.allCases.first { title($0) == popup.titleOfSelectedItem } ?? fallback
    }

    private func showAdvancedSettings(for row: ShortcutSlotRow) {
        guard let parentWindow = window else { return }

        let markerPopup = advancedPopup(Array(ShortcutMarker.allCases), selected: row.marker, title: { $0.title })
        let priorityPopup = advancedPopup(Array(ShortcutPriority.allCases), selected: row.priority, title: { $0.title })
        let schedulePopup = advancedPopup(Array(ShortcutSchedule.allCases), selected: row.schedule, title: { $0.title })
        let privacyPopup = advancedPopup(Array(ShortcutPrivacy.allCases), selected: row.privacy, title: { $0.title })
        let indexingPopup = advancedPopup(Array(ShortcutIndexing.allCases), selected: row.indexing, title: { $0.title })
        let llmPopup = advancedPopup(Array(ShortcutLLMRouting.allCases), selected: row.llmRouting, title: { $0.title })
        let contentPopup = advancedPopup(Array(ShortcutContentMode.allCases), selected: row.contentMode, title: { $0.title })
        let sectionInput = NSTextField(string: row.sectionField.stringValue)
        sectionInput.placeholderString = "Notes et idées"
        sectionInput.translatesAutoresizingMaskIntoConstraints = false
        sectionInput.widthAnchor.constraint(equalToConstant: 132).isActive = true
        styleFillableField(sectionInput)
        let positionPopup = advancedPopup(Array(ShortcutInsertPosition.allCases), selected: row.slot.insertPosition, title: { $0.title })
        let openPopup = includeSourceOverridePopupClone(selected: row.slot.openNoteOverride)
        let webSourcePopup = includeSourceOverridePopupClone(selected: row.slot.includeSourceOverride)
        let fileSourcePopup = includeSourceOverridePopupClone(selected: row.slot.includeDocumentSourceOverride)
        let previewController = AdvancedPreviewController()
        let previewLabel = NSTextField(labelWithString: "")
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.widthAnchor.constraint(equalToConstant: 540).isActive = true
        previewLabel.lineBreakMode = .byTruncatingTail
        let orderLabel = NSTextField(labelWithString: "")
        orderLabel.font = .systemFont(ofSize: 11)
        orderLabel.textColor = .secondaryLabelColor
        orderLabel.translatesAutoresizingMaskIntoConstraints = false
        orderLabel.widthAnchor.constraint(equalToConstant: 540).isActive = true

        previewController.markerPopup = markerPopup
        previewController.priorityPopup = priorityPopup
        previewController.schedulePopup = schedulePopup
        previewController.contentPopup = contentPopup
        previewController.openPopup = openPopup
        previewController.webPopup = webSourcePopup
        previewController.filePopup = fileSourcePopup
        previewController.sectionInput = sectionInput
        previewController.positionPopup = positionPopup
        previewController.privacyPopup = privacyPopup
        previewController.indexingPopup = indexingPopup
        previewController.llmPopup = llmPopup
        previewController.previewLabel = previewLabel
        previewController.orderLabel = orderLabel

        [markerPopup, priorityPopup, schedulePopup, contentPopup, positionPopup, openPopup, webSourcePopup, fileSourcePopup, privacyPopup, indexingPopup, llmPopup].forEach {
            $0.target = previewController
            $0.action = #selector(AdvancedPreviewController.update)
        }
        sectionInput.delegate = previewController
        previewController.update()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 610, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Avancé raccourci \(row.index)"
        panel.isReleasedWhenClosed = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Raccourci \(row.index)")
        title.font = .boldSystemFont(ofSize: 14)
        stack.addArrangedSubview(title)

        let columns = horizontalRow(spacing: 22)
        columns.alignment = .top
        columns.addArrangedSubview(advancedGroup("FORMAT", rows: [
            advancedLine("Marqueur", markerPopup),
            advancedLine("Priorité", priorityPopup),
            advancedLine("Date", schedulePopup),
            advancedLine("Contenu", contentPopup),
            advancedLine("Section", sectionInput),
            advancedLine("Position", positionPopup)
        ]))
        columns.addArrangedSubview(advancedGroup("ROUTAGE", rows: [
            advancedLine("Ouvrir", openPopup),
            advancedLine("Web", webSourcePopup),
            advancedLine("Fichier", fileSourcePopup),
            advancedLine("Secret", privacyPopup),
            advancedLine("Index", indexingPopup),
            advancedLine("LLM", llmPopup)
        ]))
        stack.addArrangedSubview(columns)

        let previewStack = NSStackView()
        previewStack.orientation = .vertical
        previewStack.spacing = 4
        previewStack.alignment = .leading
        let previewTitle = NSTextField(labelWithString: "APERÇU")
        previewTitle.font = .systemFont(ofSize: 12, weight: .bold)
        previewTitle.textColor = .secondaryLabelColor
        previewStack.addArrangedSubview(previewTitle)
        previewStack.addArrangedSubview(orderLabel)
        previewStack.addArrangedSubview(previewLabel)
        stack.addArrangedSubview(previewStack)

        let buttons = horizontalRow(spacing: 10)
        buttons.alignment = .centerY
        let cancelButton = PayloadButton(title: "Annuler", target: nil, action: nil)
        let saveButton = PayloadButton(title: "OK", target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        buttons.addArrangedSubview(NSView())
        buttons.addArrangedSubview(cancelButton)
        buttons.addArrangedSubview(saveButton)
        stack.addArrangedSubview(buttons)

        panel.contentView = NSView()
        panel.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            stack.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor)
        ])

        cancelButton.target = self
        cancelButton.action = #selector(closeAdvancedSheet(_:))
        saveButton.target = self
        saveButton.action = #selector(applyAdvancedSheet(_:))
        cancelButton.payload = panel
        saveButton.payload = [
            "panel": panel,
            "row": row,
            "marker": markerPopup,
            "priority": priorityPopup,
            "schedule": schedulePopup,
            "privacy": privacyPopup,
            "indexing": indexingPopup,
            "llm": llmPopup,
            "content": contentPopup,
            "section": sectionInput,
            "position": positionPopup,
            "open": openPopup,
            "web": webSourcePopup,
            "file": fileSourcePopup,
            "preview": previewController
        ]

        parentWindow.beginSheet(panel)
    }

    private func includeSourceOverridePopupClone(selected: ShortcutOptionOverride) -> NSPopUpButton {
        let popup = NSPopUpButton()
        ShortcutOptionOverride.allCases.forEach { popup.addItem(withTitle: $0.title) }
        popup.selectItem(withTitle: selected.title)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: 132).isActive = true
        return popup
    }

    @objc private func closeAdvancedSheet(_ sender: NSButton) {
        guard let panel = (sender as? PayloadButton)?.payload as? NSPanel else { return }
        panel.sheetParent?.endSheet(panel)
    }

    @objc private func applyAdvancedSheet(_ sender: NSButton) {
        guard
            let values = (sender as? PayloadButton)?.payload as? [String: Any],
            let panel = values["panel"] as? NSPanel,
            let row = values["row"] as? ShortcutSlotRow,
            let markerPopup = values["marker"] as? NSPopUpButton,
            let priorityPopup = values["priority"] as? NSPopUpButton,
            let schedulePopup = values["schedule"] as? NSPopUpButton,
            let privacyPopup = values["privacy"] as? NSPopUpButton,
            let indexingPopup = values["indexing"] as? NSPopUpButton,
            let llmPopup = values["llm"] as? NSPopUpButton,
            let contentPopup = values["content"] as? NSPopUpButton,
            let sectionInput = values["section"] as? NSTextField,
            let positionPopup = values["position"] as? NSPopUpButton,
            let openPopup = values["open"] as? NSPopUpButton,
            let webSourcePopup = values["web"] as? NSPopUpButton,
            let fileSourcePopup = values["file"] as? NSPopUpButton
        else { return }

        row.openNoteOverridePopup.selectItem(withTitle: openPopup.titleOfSelectedItem ?? ShortcutOptionOverride.inherit.title)
        row.includeSourceOverridePopup.selectItem(withTitle: webSourcePopup.titleOfSelectedItem ?? ShortcutOptionOverride.inherit.title)
        row.includeDocumentSourceOverridePopup.selectItem(withTitle: fileSourcePopup.titleOfSelectedItem ?? ShortcutOptionOverride.inherit.title)
        row.sectionField.stringValue = sectionInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        row.insertPositionPopup.selectItem(withTitle: positionPopup.titleOfSelectedItem ?? ShortcutInsertPosition.endOfSection.title)
        row.applyAdvanced(
            marker: selectedAdvancedValue(ShortcutMarker.self, popup: markerPopup, title: { $0.title }, fallback: .task),
            priority: selectedAdvancedValue(ShortcutPriority.self, popup: priorityPopup, title: { $0.title }, fallback: .none),
            schedule: selectedAdvancedValue(ShortcutSchedule.self, popup: schedulePopup, title: { $0.title }, fallback: .none),
            privacy: selectedAdvancedValue(ShortcutPrivacy.self, popup: privacyPopup, title: { $0.title }, fallback: .personal),
            indexing: selectedAdvancedValue(ShortcutIndexing.self, popup: indexingPopup, title: { $0.title }, fallback: .inherit),
            llmRouting: selectedAdvancedValue(ShortcutLLMRouting.self, popup: llmPopup, title: { $0.title }, fallback: .none),
            contentMode: selectedAdvancedValue(ShortcutContentMode.self, popup: contentPopup, title: { $0.title }, fallback: .expanded)
        )
        Settings.setShortcutSlot(row.slot)
        UserDefaults.standard.synchronize()
        statusLabel.stringValue = "Avancé raccourci \(row.index) enregistré."
        markPendingChanges(true)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        panel.sheetParent?.endSheet(panel)
    }

    @objc private func addVisibleShortcut() {
        guard shortcutRows.count < Settings.shortcutSlotCount else {
            statusLabel.stringValue = "Limite atteinte : 30 raccourcis."
            NSSound.beep()
            return
        }
        let nextCount = shortcutRows.count + 1
        Settings.setVisibleShortcutCount(nextCount)
        let row = addShortcutRow(for: Settings.shortcutSlot(nextCount))
        setActiveConfigRow(row)
        statusLabel.stringValue = "Raccourci \(nextCount) ajouté. Configure la touche puis la destination."
        markPendingChanges(true)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.delegate = self
        contentView.addSubview(tabView)

        let settingsContainer = NSView()
        let settingsTab = NSTabViewItem(identifier: "settings")
        settingsTab.label = "Capture"
        settingsTab.view = settingsContainer
        tabView.addTabViewItem(settingsTab)

        let shortcutMakerTab = NSTabViewItem(identifier: "shortcutMaker")
        shortcutMakerTab.label = "Raccourcis"
        shortcutMakerTab.view = shortcutMakerTabView()
        tabView.addTabViewItem(shortcutMakerTab)

        let nc2Tab = NSTabViewItem(identifier: "nc2")
        nc2Tab.label = "Commander"
        nc2Tab.view = nc2Controller.embeddedView()
        tabView.addTabViewItem(nc2Tab)
        nc2Controller.onCloseEmbeddedSort = { [weak tabView] in
            guard let tabView,
                  let settingsTab = tabView.tabViewItems.first(where: { ($0.identifier as? String) == "settings" }) else { return }
            tabView.selectTabViewItem(settingsTab)
        }
        tabView.selectTabViewItem(settingsTab)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        settingsContainer.addSubview(stack)

        let title = NSTextField(labelWithString: "NoteDroppy")
        title.font = .boldSystemFont(ofSize: 18)

        let tagline = NSTextField(labelWithString: "Time is precious.\nSpend it with those you love")
        tagline.font = .systemFont(ofSize: 11)
        tagline.textColor = .secondaryLabelColor
        tagline.maximumNumberOfLines = 2
        tagline.lineBreakMode = .byWordWrapping

        let logo = NSImageView()
        logo.image = noteDroopyLogoImage()
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
        captureSectionField.placeholderString = "Notes et idées"

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
        serviceTagRow.addArrangedSubview(formLabel("Section via service", width: 128))
        serviceTagRow.addArrangedSubview(captureSectionField)

        let notesRootRow = horizontalRow(spacing: 10)
        notesRootRow.addArrangedSubview(formLabel("Dossier Notes", width: 118))
        notesRootRow.addArrangedSubview(notesRootField)
        notesRootRow.addArrangedSubview(chooseNotesRootButton)

        openNoteCheckbox.state = Settings.openNote ? .on : .off
        includeSourceCheckbox.state = Settings.includeSource ? .on : .off
        includeDocumentSourceCheckbox.state = Settings.includeDocumentSource ? .on : .off
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

        captureRulesButton.target = self
        captureRulesButton.action = #selector(openCaptureRulesJSON)
        captureRulesButton.bezelStyle = .rounded

        captureRulesHelpButton.target = self
        captureRulesHelpButton.action = #selector(openCaptureRulesHelp)
        captureRulesHelpButton.bezelStyle = .rounded

        exportButton.target = self
        exportButton.action = #selector(exportPreferencesJSON)
        exportButton.bezelStyle = .rounded

        importButton.target = self
        importButton.action = #selector(importPreferencesJSON)
        importButton.bezelStyle = .rounded

        buttons.addArrangedSubview(saveButton)
        buttons.addArrangedSubview(exportButton)
        buttons.addArrangedSubview(importButton)
        buttons.addArrangedSubview(captureRulesButton)
        buttons.addArrangedSubview(captureRulesHelpButton)
        buttons.addArrangedSubview(helpButton)
        buttons.addArrangedSubview(accessibilityButton)
        buttons.addArrangedSubview(quitButton)

        [serviceNameField, tagField, captureSectionField, notesRootField].forEach { field in
            styleFillableField(field)
            field.translatesAutoresizingMaskIntoConstraints = false
        }
        serviceNameField.widthAnchor.constraint(equalToConstant: 300).isActive = true
        tagField.widthAnchor.constraint(equalToConstant: 170).isActive = true
        captureSectionField.widthAnchor.constraint(equalToConstant: 170).isActive = true
        notesRootField.widthAnchor.constraint(equalToConstant: 560).isActive = true

        slotsStack.orientation = .vertical
        slotsStack.spacing = 8
        slotsStack.alignment = .leading
        slotsStack.translatesAutoresizingMaskIntoConstraints = false

        slotsStack.addArrangedSubview(ShortcutSlotRow.headerView())

        shortcutRows = []
        Settings.allShortcutSlots().prefix(Settings.visibleShortcutCount).forEach { addShortcutRow(for: $0) }

        let slotsDocumentView = NSView()
        slotsDocumentView.translatesAutoresizingMaskIntoConstraints = false
        slotsDocumentView.addSubview(slotsStack)
        NSLayoutConstraint.activate([
            slotsStack.leadingAnchor.constraint(equalTo: slotsDocumentView.leadingAnchor),
            slotsStack.trailingAnchor.constraint(lessThanOrEqualTo: slotsDocumentView.trailingAnchor),
            slotsStack.topAnchor.constraint(equalTo: slotsDocumentView.topAnchor),
            slotsStack.bottomAnchor.constraint(equalTo: slotsDocumentView.bottomAnchor),
            slotsDocumentView.widthAnchor.constraint(greaterThanOrEqualToConstant: ShortcutSlotRow.columnWidths.reduce(0, +) + ShortcutSlotRow.columnSpacing * CGFloat(ShortcutSlotRow.columnWidths.count - 1)),
            slotsDocumentView.heightAnchor.constraint(greaterThanOrEqualTo: slotsStack.heightAnchor)
        ])

        let slotsScrollView = NSScrollView()
        slotsScrollView.hasVerticalScroller = true
        slotsScrollView.hasHorizontalScroller = true
        slotsScrollView.borderType = .noBorder
        slotsScrollView.documentView = slotsDocumentView
        slotsScrollView.translatesAutoresizingMaskIntoConstraints = false
        slotsScrollView.heightAnchor.constraint(equalToConstant: 600).isActive = true

        stack.addArrangedSubview(titleStack)
        stack.addArrangedSubview(serviceTagRow)
        stack.addArrangedSubview(notesRootRow)
        stack.addArrangedSubview(openNoteCheckbox)
        stack.addArrangedSubview(includeSourceCheckbox)
        stack.addArrangedSubview(includeDocumentSourceCheckbox)
        stack.addArrangedSubview(shortcutHelpLabel)
        stack.addArrangedSubview(variablesHelpLabel)
        stack.addArrangedSubview(configBuilderView())
        stack.addArrangedSubview(tagsConfigLegendView())
        stack.addArrangedSubview(slotsScrollView)
        stack.addArrangedSubview(buttons)
        stack.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            stack.leadingAnchor.constraint(equalTo: settingsContainer.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: settingsContainer.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: settingsContainer.topAnchor, constant: 12)
        ])
        contentView.layoutSubtreeIfNeeded()
        let fitting = stack.fittingSize
        let contentSize = NSSize(width: max(1220, fitting.width + 72), height: max(860, fitting.height + 92))
        window?.setContentSize(contentSize)
        window?.minSize = NSSize(width: 1220, height: 860)
        refreshAccessibilityStatus()
        markPendingChanges(false)
        installPasteMonitorIfNeeded()
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        switch tabViewItem?.identifier as? String {
        case "nc2":
            nc2Controller.activateEmbeddedSort()
        default:
            window?.title = "Préférences NoteDroppy"
        }
    }

    private func functionsTabView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let title = NSTextField(labelWithString: "Fonctions")
        title.font = .boldSystemFont(ofSize: 18)

        let detail = NSTextField(labelWithString: "Accès rapide aux fonctions complémentaires sans modifier les réglages de capture.")
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byWordWrapping
        detail.maximumNumberOfLines = 2

        let editorButton = NSButton(title: "Ouvrir l’éditeur NotePlan", target: self, action: #selector(openEditorFromSettings))
        let searchButton = NSButton(title: "Rechercher dans les notes", target: self, action: #selector(searchNotesFromSettings))
        let exportButton = NSButton(title: "Exporter les préférences JSON", target: self, action: #selector(exportPreferencesJSON))
        let helpButton = NSButton(title: "Aide", target: self, action: #selector(openHelp))

        [editorButton, searchButton, exportButton, helpButton].forEach { button in
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 260).isActive = true
            stack.addArrangedSubview(button)
        }

        stack.insertArrangedSubview(detail, at: 0)
        stack.insertArrangedSubview(title, at: 0)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 18)
        ])
        return container
    }

    private func shortcutMakerTabView() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let title = NSTextField(labelWithString: "Raccourci .app vers une note")
        title.font = .boldSystemFont(ofSize: 18)

        let detail = NSTextField(labelWithString: "Crée une petite app qui ouvre directement la note choisie dans NotePlan.")
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byWordWrapping
        detail.maximumNumberOfLines = 2

        shortcutMakerNoteField.lineBreakMode = .byTruncatingMiddle
        shortcutMakerDestinationField.lineBreakMode = .byTruncatingMiddle
        shortcutMakerOpenWithField.lineBreakMode = .byTruncatingMiddle
        shortcutMakerDropView.translatesAutoresizingMaskIntoConstraints = false
        shortcutMakerDropView.onDropTarget = { [weak self] target in
            self?.applyShortcutMakerDrop(target) ?? false
        }
        shortcutMakerDropView.widthAnchor.constraint(equalToConstant: 760).isActive = true
        refreshShortcutMakerFields()

        let chooseNoteButton = NSButton(title: "Choisir une note .md", target: self, action: #selector(chooseShortcutMakerNote))
        let chooseDestinationButton = NSButton(title: "Choisir destination", target: self, action: #selector(chooseShortcutMakerDestination))
        let chooseOpenWithButton = NSButton(title: "Choisir app…", target: self, action: #selector(chooseShortcutMakerOpenWithApp))
        let resetOpenWithButton = NSButton(title: "NotePlan par défaut", target: self, action: #selector(resetShortcutMakerOpenWithApp))
        let generateButton = NSButton(title: "Créer le raccourci .app", target: self, action: #selector(generateShortcutMakerApp))
        let revealButton = NSButton(title: "Révéler le dernier raccourci", target: self, action: #selector(revealShortcutMakerApp))
        let recentTitle = NSTextField(labelWithString: "Derniers raccourcis créés")
        recentTitle.font = .boldSystemFont(ofSize: 13)

        shortcutMakerRecentTextView.isEditable = false
        shortcutMakerRecentTextView.isSelectable = true
        shortcutMakerRecentTextView.drawsBackground = false
        shortcutMakerRecentTextView.font = .systemFont(ofSize: 12)
        shortcutMakerRecentTextView.textColor = .secondaryLabelColor

        let recentScroll = NSScrollView()
        recentScroll.hasVerticalScroller = true
        recentScroll.drawsBackground = false
        recentScroll.borderType = .lineBorder
        recentScroll.documentView = shortcutMakerRecentTextView
        recentScroll.translatesAutoresizingMaskIntoConstraints = false
        recentScroll.widthAnchor.constraint(equalToConstant: 760).isActive = true
        recentScroll.heightAnchor.constraint(equalToConstant: 110).isActive = true

        [chooseNoteButton, chooseDestinationButton, chooseOpenWithButton, resetOpenWithButton, generateButton, revealButton].forEach { button in
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 260).isActive = true
        }

        let openWithButtons = NSStackView()
        openWithButtons.orientation = .horizontal
        openWithButtons.spacing = 10
        openWithButtons.alignment = .centerY
        openWithButtons.addArrangedSubview(chooseOpenWithButton)
        openWithButtons.addArrangedSubview(resetOpenWithButton)

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(detail)
        stack.addArrangedSubview(shortcutMakerDropView)
        stack.addArrangedSubview(shortcutMakerInfoRow(title: "Note", value: shortcutMakerNoteField))
        stack.addArrangedSubview(chooseNoteButton)
        stack.addArrangedSubview(shortcutMakerInfoRow(title: "Ouvrir avec", value: shortcutMakerOpenWithField))
        stack.addArrangedSubview(openWithButtons)
        stack.addArrangedSubview(shortcutMakerInfoRow(title: "Destination", value: shortcutMakerDestinationField))
        stack.addArrangedSubview(chooseDestinationButton)
        stack.addArrangedSubview(generateButton)
        stack.addArrangedSubview(revealButton)
        stack.addArrangedSubview(recentTitle)
        stack.addArrangedSubview(recentScroll)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 18)
        ])
        return container
    }

    private func shortcutMakerInfoRow(title: String, value: NSTextField) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        let label = formLabel(title, width: 90)
        value.textColor = .secondaryLabelColor
        value.translatesAutoresizingMaskIntoConstraints = false
        value.widthAnchor.constraint(equalToConstant: 620).isActive = true
        row.addArrangedSubview(label)
        row.addArrangedSubview(value)
        return row
    }

    private func refreshShortcutMakerFields() {
        shortcutMakerNoteField.stringValue = shortcutMakerNoteDisplay()
        shortcutMakerDestinationField.stringValue = shortcutMakerDestinationURL().path
        shortcutMakerOpenWithField.stringValue = shortcutMakerOpenWithDisplay()
        shortcutMakerRecentTextView.string = shortcutMakerRecentShortcuts()
            .map { "• \($0)" }
            .joined(separator: "\n")
    }

    private func shortcutMakerNoteDisplay() -> String {
        if let display = UserDefaults.standard.string(forKey: shortcutMakerNoteDisplayKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !display.isEmpty {
            return display
        }
        if let urlString = UserDefaults.standard.string(forKey: shortcutMakerNoteURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !urlString.isEmpty {
            return "NotePlan : \(shortcutMakerAppName(fromNotePlanURL: urlString))"
        }
        if let path = UserDefaults.standard.string(forKey: shortcutMakerNotePathKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }
        return "Aucune note choisie"
    }

    private func shortcutMakerDestinationURL() -> URL {
        if let path = UserDefaults.standard.string(forKey: shortcutMakerDestinationPathKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    private func shortcutMakerOpenWithAppURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: shortcutMakerOpenWithAppPathKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    private func shortcutMakerOpenWithDisplay() -> String {
        guard let appURL = shortcutMakerOpenWithAppURL() else {
            return "NotePlan"
        }
        return "\(appURL.deletingPathExtension().lastPathComponent) — \(appURL.path)"
    }

    private func shortcutMakerRecentShortcuts() -> [String] {
        UserDefaults.standard.stringArray(forKey: shortcutMakerRecentShortcutsKey) ?? []
    }

    private func rememberShortcutMakerApp(_ appURL: URL) {
        var recent = shortcutMakerRecentShortcuts()
        recent.removeAll { $0 == appURL.path }
        recent.insert(appURL.path, at: 0)
        UserDefaults.standard.set(Array(recent.prefix(10)), forKey: shortcutMakerRecentShortcutsKey)
        UserDefaults.standard.synchronize()
        refreshShortcutMakerFields()
    }

    private func setShortcutMakerNote(path: String) {
        UserDefaults.standard.set(path, forKey: shortcutMakerNotePathKey)
        UserDefaults.standard.removeObject(forKey: shortcutMakerNoteURLKey)
        UserDefaults.standard.set(path, forKey: shortcutMakerNoteDisplayKey)
        UserDefaults.standard.synchronize()
        refreshShortcutMakerFields()
    }

    private func setShortcutMakerNote(notePlanURL: String, displayName: String) {
        UserDefaults.standard.set(notePlanURL, forKey: shortcutMakerNoteURLKey)
        UserDefaults.standard.removeObject(forKey: shortcutMakerNotePathKey)
        UserDefaults.standard.set("NotePlan : \(displayName)", forKey: shortcutMakerNoteDisplayKey)
        UserDefaults.standard.synchronize()
        refreshShortcutMakerFields()
    }

    private func applyShortcutMakerDrop(_ target: ShortcutTarget) -> Bool {
        if let url = target.url {
            if url.scheme?.lowercased() == "noteplan" {
                let urlString = url.absoluteString
                setShortcutMakerNote(notePlanURL: urlString, displayName: shortcutMakerAppName(fromNotePlanURL: urlString))
                statusLabel.stringValue = "NotePlan enregistré : \(shortcutMakerAppName(fromNotePlanURL: urlString))"
                return true
            }
            if url.isFileURL, url.pathExtension.lowercased() == "md" {
                setShortcutMakerNote(path: url.standardizedFileURL.path)
                statusLabel.stringValue = "Note choisie : \(url.lastPathComponent)"
                return true
            }
        }

        if let text = target.rawText {
            if let notePlanURL = notePlanURLCandidate(from: text) {
                setShortcutMakerNote(notePlanURL: notePlanURL, displayName: shortcutMakerAppName(fromNotePlanURL: notePlanURL))
                statusLabel.stringValue = "NotePlan enregistré : \(shortcutMakerAppName(fromNotePlanURL: notePlanURL))"
                return true
            }
            if let path = existingFinderPath(from: text), path.lowercased().hasSuffix(".md") {
                setShortcutMakerNote(path: path)
                statusLabel.stringValue = "Note choisie : \(URL(fileURLWithPath: path).lastPathComponent)"
                return true
            }
        }

        statusLabel.stringValue = "Dépose une note .md ou un lien noteplan://."
        NSSound.beep()
        return false
    }

    private func notePlanURLCandidate(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme?.lowercased() == "noteplan" {
            return trimmed
        }
        let pattern = #"noteplan://[^\s\)\]>"]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let matchRange = Range(match.range, in: trimmed) else {
            return nil
        }
        return String(trimmed[matchRange])
    }

    private func shortcutMakerAppName(fromNotePlanURL urlString: String) -> String {
        guard let components = URLComponents(string: urlString) else {
            return "NotePlan Shortcut"
        }
        let items = components.queryItems ?? []
        for name in ["noteTitle", "notePath", "fileName"] {
            if let value = items.first(where: { $0.name == name })?.value,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return URL(fileURLWithPath: value).deletingPathExtension().lastPathComponent
            }
        }
        let fallback = components.host ?? components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return fallback.isEmpty ? "NotePlan Shortcut" : fallback
    }

    @objc private func chooseShortcutMakerNote() {
        let panel = NSOpenPanel()
        panel.title = "Choisir une note NotePlan"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }
        panel.directoryURL = Settings.selectedNotesRoot() ?? FileManager.default.homeDirectoryForCurrentUser
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setShortcutMakerNote(path: url.path)
        statusLabel.stringValue = "Note choisie : \(url.lastPathComponent)"
    }

    @objc private func chooseShortcutMakerDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choisir destination"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = shortcutMakerDestinationURL()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: shortcutMakerDestinationPathKey)
        UserDefaults.standard.synchronize()
        refreshShortcutMakerFields()
        statusLabel.stringValue = "Destination choisie : \(url.path)"
    }

    @objc private func chooseShortcutMakerOpenWithApp() {
        let panel = NSOpenPanel()
        panel.title = "Choisir l’app pour ouvrir la note"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.standardizedFileURL.path, forKey: shortcutMakerOpenWithAppPathKey)
        UserDefaults.standard.synchronize()
        refreshShortcutMakerFields()
        statusLabel.stringValue = "App d’ouverture choisie : \(url.deletingPathExtension().lastPathComponent)"
    }

    @objc private func resetShortcutMakerOpenWithApp() {
        UserDefaults.standard.removeObject(forKey: shortcutMakerOpenWithAppPathKey)
        UserDefaults.standard.synchronize()
        refreshShortcutMakerFields()
        statusLabel.stringValue = "Raccourcis : NotePlan par défaut."
    }

    @objc private func generateShortcutMakerApp() {
        let notePath = UserDefaults.standard.string(forKey: shortcutMakerNotePathKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let notePlanURL = UserDefaults.standard.string(forKey: shortcutMakerNoteURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !notePath.isEmpty || !notePlanURL.isEmpty else {
            chooseShortcutMakerNote()
            return
        }
        let destinationURL = shortcutMakerDestinationURL()

        do {
            let result: EditorShortcutResult
            if !notePlanURL.isEmpty {
                result = try EditorNotePlanShortcutGenerator.generate(
                    noteURLString: notePlanURL,
                    appName: shortcutMakerAppName(fromNotePlanURL: notePlanURL),
                    destinationURL: destinationURL,
                    confirmReplace: confirmShortcutMakerReplacement(appURL:)
                )
            } else {
                result = try EditorNotePlanShortcutGenerator.generate(
                    noteURL: URL(fileURLWithPath: notePath),
                    openWithApplicationURL: shortcutMakerOpenWithAppURL(),
                    destinationURL: destinationURL,
                    confirmReplace: confirmShortcutMakerReplacement(appURL:)
                )
            }
            generatedShortcutURL = result.appURL
            rememberShortcutMakerApp(result.appURL)
            statusLabel.stringValue = "Raccourci généré : \(result.appURL.path)"
            askRevealShortcutMakerApp(result.appURL)
        } catch EditorNotePlanShortcutError.cancelled {
            statusLabel.stringValue = "Génération annulée."
        } catch {
            statusLabel.stringValue = "Erreur raccourci : \(error.localizedDescription)"
        }
    }

    @objc private func revealShortcutMakerApp() {
        guard let generatedShortcutURL else {
            statusLabel.stringValue = "Aucun raccourci généré."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([generatedShortcutURL])
    }

    private func confirmShortcutMakerReplacement(appURL: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Remplacer le raccourci existant ?"
        alert.informativeText = appURL.path
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remplacer")
        alert.addButton(withTitle: "Annuler")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func askRevealShortcutMakerApp(_ appURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Raccourci généré"
        alert.informativeText = appURL.path
        alert.addButton(withTitle: "Révéler dans Finder")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([appURL])
        }
    }

    @objc private func openEditorFromSettings() {
        NotePlanEditorWindowController.show()
    }

    @objc private func searchNotesFromSettings() {
        NoteSearchWindowController.show(initialQuery: "") { [weak self] selected in
            self?.statusLabel.stringValue = "Note trouvée : \(selected.relativePath)"
        }
    }

    deinit {
        if let pasteMonitor {
            NSEvent.removeMonitor(pasteMonitor)
        }
    }

    private func installPasteMonitorIfNeeded() {
        guard pasteMonitor == nil else { return }
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  event.window === self.window,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
                  event.charactersIgnoringModifiers?.lowercased() == "v",
                  let row = self.focusedTargetRow()
            else {
                return event
            }
            self.pasteTarget(for: row)
            return nil
        }
    }

    private func focusedTargetRow() -> ShortcutSlotRow? {
        guard let firstResponder = window?.firstResponder else { return nil }
        for row in shortcutRows {
            if firstResponder === row.targetField {
                return row
            }
            if let editor = row.targetField.currentEditor(), firstResponder === editor {
                return row
            }
        }
        return nil
    }

    private func focusedShortcutRow() -> ShortcutSlotRow? {
        guard let firstResponder = window?.firstResponder else { return nil }
        for row in shortcutRows {
            let fields = [row.targetField, row.sectionField, row.tagsField]
            for field in fields {
                if firstResponder === field {
                    return row
                }
                if let editor = field.currentEditor(), firstResponder === editor {
                    return row
                }
            }
        }
        return activeConfigRow
    }

    private func selectedConfigTokens() -> [(positive: String, negative: String, selected: String)] {
        [
            ("!Web", "!NoWeb", configWebPopup.titleOfSelectedItem ?? "Global"),
            ("!File", "!NoFile", configFilePopup.titleOfSelectedItem ?? "Global")
        ]
    }

    @objc private func addConfigToActiveShortcut() {
        applyConfigToActiveShortcut(replace: false)
    }

    @objc private func replaceConfigOnActiveShortcut() {
        applyConfigToActiveShortcut(replace: true)
    }

    private func applyConfigToActiveShortcut(replace: Bool, automatic: Bool = false) {
        guard let row = focusedShortcutRow() else {
            statusLabel.stringValue = automatic
                ? "Choisis d'abord une ligne : clique dans sa case Tags / Config."
                : "Clique d'abord dans une case Tags / Config, Section ou Cible de la ligne à modifier."
            if !automatic {
                NSSound.beep()
            }
            return
        }
        setActiveConfigRow(row)
        row.tagsField.stringValue = tagsByApplyingConfig(
            to: row.tagsField.stringValue,
            selections: selectedConfigTokens(),
            replace: replace
        )
        applyTagsConfigColors(to: row.tagsField)
        flashTagsConfigField(row.tagsField)
        Settings.setShortcutSlot(row.slot)
        UserDefaults.standard.synchronize()
        if automatic {
            statusLabel.stringValue = "Tags / Config ligne \(row.index) mis à jour automatiquement."
        } else {
            statusLabel.stringValue = replace ? "Options remplacées dans Tags / Config ligne \(row.index)." : "Options ajoutées dans Tags / Config ligne \(row.index)."
        }
        markPendingChanges(true)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    private func flashTagsConfigField(_ field: NSTextField) {
        field.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.28).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            field.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.12).cgColor
        }
    }

    private func tagsByApplyingConfig(
        to value: String,
        selections: [(positive: String, negative: String, selected: String)],
        replace: Bool
    ) -> String {
        let allConfigTokens = Set(selections.flatMap { [$0.positive.lowercased(), $0.negative.lowercased()] })
        var tokens = value
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if replace {
            tokens.removeAll { allConfigTokens.contains($0.lowercased()) }
        }

        for selection in selections {
            let selected = selection.selected.lowercased()
            guard selected == "oui" || selected == "non" else { continue }
            let pair = Set([selection.positive.lowercased(), selection.negative.lowercased()])
            tokens.removeAll { pair.contains($0.lowercased()) }
            tokens.append(selected == "oui" ? selection.positive : selection.negative)
        }

        var seen = Set<String>()
        let unique = tokens.filter { seen.insert($0.lowercased()).inserted }
        return unique.joined(separator: ", ")
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
        if obsidianURL(from: target) != nil {
            row.setEngine(.obsidian)
            return applyDroppedObsidianTarget(target, to: row)
        }

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
        if let obsidianURL = obsidianURL(from: target),
           let parsed = obsidianTarget(from: obsidianURL) {
            row.applyDroppedObsidianURI(vault: parsed.vault, note: parsed.note)
            autosaveSettings()
            statusLabel.stringValue = "Cible Obsidian enregistrée : \(parsed.note)"
            return true
        }

        guard let url = target.url, url.isFileURL else {
            statusLabel.stringValue = "Pour Obsidian, dépose une note .md, un dossier, ou un lien obsidian://."
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
        tell application "NoteDroppy" to activate
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
        let section = captureSectionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(serviceName.isEmpty ? "NotePlan : ajouter en tâche" : serviceName, forKey: Settings.serviceNameKey)
        UserDefaults.standard.set(tag.isEmpty ? "#capture" : tag, forKey: Settings.taskTagKey)
        UserDefaults.standard.set(section, forKey: Settings.captureSectionKey)
        UserDefaults.standard.set(openNoteCheckbox.state == .on, forKey: Settings.openNoteKey)
        UserDefaults.standard.set(includeSourceCheckbox.state == .on, forKey: Settings.includeSourceKey)
        UserDefaults.standard.set(includeDocumentSourceCheckbox.state == .on, forKey: Settings.includeDocumentSourceKey)
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

    @objc private func openCaptureRulesJSON() {
        CaptureRulesStore.ensureFiles()
        NSWorkspace.shared.open(CaptureRulesStore.rulesURL)
        statusLabel.stringValue = "Règles capture : \(CaptureRulesStore.rulesURL.path)"
    }

    @objc private func openCaptureRulesHelp() {
        CaptureRulesStore.ensureFiles()
        NSWorkspace.shared.open(CaptureRulesStore.docURL)
        statusLabel.stringValue = "Doc formats : \(CaptureRulesStore.docURL.path)"
    }

    private func saveCurrentControlsToDefaults() {
        let serviceName = serviceNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = tagField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let section = captureSectionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(serviceName.isEmpty ? "NotePlan : ajouter en tâche" : serviceName, forKey: Settings.serviceNameKey)
        UserDefaults.standard.set(tag.isEmpty ? "#capture" : tag, forKey: Settings.taskTagKey)
        UserDefaults.standard.set(section, forKey: Settings.captureSectionKey)
        UserDefaults.standard.set(openNoteCheckbox.state == .on, forKey: Settings.openNoteKey)
        UserDefaults.standard.set(includeSourceCheckbox.state == .on, forKey: Settings.includeSourceKey)
        UserDefaults.standard.set(includeDocumentSourceCheckbox.state == .on, forKey: Settings.includeDocumentSourceKey)
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
        captureSectionField.stringValue = Settings.captureSection
        notesRootField.stringValue = Settings.notesRootPath
        openNoteCheckbox.state = Settings.openNote ? .on : .off
        includeSourceCheckbox.state = Settings.includeSource ? .on : .off
        includeDocumentSourceCheckbox.state = Settings.includeDocumentSource ? .on : .off
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
    private var hotKeySlotIDs: [UInt32: Int] = [:]
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
                hotKeySlotIDs[UInt32(slot.index)] = slot.index
            }
        }

        let slot1 = Settings.shortcutSlot(1)
        let legacySlot1ID: UInt32 = 101
        let legacySlot1Key = UInt32(kVK_ANSI_Slash)
        let legacySlot1Modifiers = UInt32(controlKey | optionKey | cmdKey)
        if slot1.enabled,
           (slot1.combo.keyCode != legacySlot1Key || slot1.combo.carbonModifiers != legacySlot1Modifiers) {
            var ref: EventHotKeyRef?
            let carbonHotKeyID = EventHotKeyID(signature: hotKeySignature, id: legacySlot1ID)
            let registerStatus = RegisterEventHotKey(
                legacySlot1Key,
                legacySlot1Modifiers,
                carbonHotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if registerStatus == noErr, let ref {
                hotKeyRefs[legacySlot1ID] = ref
                hotKeySlotIDs[legacySlot1ID] = 1
                writeDebugLog("shortcut:legacy-slot1-slash:registered")
            } else {
                writeDebugLog("shortcut:legacy-slot1-slash:register-failed:\(registerStatus)")
            }
        }
    }

    private func stop() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        hotKeySlotIDs.removeAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate func fireIfMatching(signature: UInt32, id: UInt32) -> OSStatus {
        guard signature == hotKeySignature, hotKeyRefs[id] != nil, let slotIndex = hotKeySlotIDs[id] else {
            return OSStatus(eventNotHandledErr)
        }
        guard Date().timeIntervalSince(lastFire) > 0.8 else { return noErr }
        lastFire = Date()
        DispatchQueue.main.async {
            self.handler(slotIndex)
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
    private var lastShortcutCaptureAt = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("launch")
        Settings.migrateShortcutLayoutIfNeeded()
        if !isAccessibilityTrusted(prompt: false) {
            log("accessibility:prompt-on-launch")
            _ = isAccessibilityTrusted(prompt: true)
        }
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
        alert.icon = noteDroopyLogoImage(size: NSSize(width: 96, height: 96))
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        alert.messageText = "NoteDroppy"
        alert.informativeText = """
        Version \(version) build \(build)

        Capture texte, URL et chemins de fichiers vers NotePlan, Markdown, Obsidian ou TXT.

        20 raccourcis configurables.
        + rouge = configuration avancée active.
        Tag & Config = tags visibles + résumé des options.

        GitHub:
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
        let linkURL = URL(fileURLWithPath: fileURL.standardizedFileURL.path, isDirectory: isDirectory(fileURL))
        let label = fileURL.lastPathComponent.isEmpty ? fileURL.path : fileURL.lastPathComponent
        let escapedLabel = label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return "[\(escapedLabel)](\(linkURL.absoluteString))"
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

    private func markdownLinkForWebURL(_ value: String, title: String? = nil) -> String? {
        guard let normalized = normalizedWebURL(value),
              let url = URL(string: normalized),
              let host = url.host else {
            return nil
        }
        let title = preferredSourceTitle(title, fallback: nil, url: normalized) ?? CaptureRulesStore.metadata(for: normalized)?.title ?? webLinkTitle(for: url, host: host)
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
        guard Date().timeIntervalSince(lastShortcutCaptureAt) > 0.8 else {
            log("shortcut:debounced:slot:\(slotIndex)")
            return
        }
        lastShortcutCaptureAt = Date()
        let slot = Settings.shortcutSlot(slotIndex)
        guard slot.enabled else {
            log("shortcut:disabled-slot:\(slotIndex)")
            return
        }
        log("shortcut:invoked:slot:\(slotIndex)")
        if slot.action == .open {
            log("shortcut:open-only:slot:\(slotIndex)")
            openShortcutTarget(slot)
            return
        }
        guard canCaptureFrontmostApplication() else {
            log("shortcut:ignored-frontmost-app")
            NSSound.beep()
            return
        }
        let accessibilityTrusted = isAccessibilityTrusted(prompt: false)
        if !accessibilityTrusted {
            log("shortcut:accessibility-not-trusted:clipboard-only")
        }
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let frontmostTitle = sourceWindowTitle(for: frontmostApplication)
        let pageSource = sourceWebPage(for: frontmostApplication).map {
            CaptureSource(url: $0.url, title: preferredSourceTitle($0.title, fallback: frontmostTitle, url: $0.url))
        }
        let documentSource = accessibilityTrusted ? sourceDocumentFileURL(for: frontmostApplication, shortcutSlot: slot) : nil

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
            let axText = accessibilityTrusted
                ? self.selectedTextFromAccessibility().flatMap { self.normalizedTodoText($0) }
                : nil
            if let normalized = self.bestShortcutText(clipboardText: clipboardText, axText: axText) {
                self.log("shortcut:text:\(normalized)")
                let source = pastedSourceURL.map { CaptureSource(url: $0, title: self.preferredSourceTitle(pageSource?.title, fallback: frontmostTitle, url: $0)) } ?? pageSource ?? documentSource
                self.sendTodo(normalized, shortcutSlot: slot, sourceURL: source?.url, sourceTitle: source?.title)
                return
            }
            self.log("shortcut:no-selected-text")
            if !accessibilityTrusted {
                self.showSettingsWindow()
            }
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

    private func sourceWebPage(for application: NSRunningApplication?) -> CaptureSource? {
        guard let appName = application?.localizedName else { return nil }
        let escapedAppName = appName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        set frontApp to "\(escapedAppName)"
        set chromiumApps to {"Google Chrome", "Google Chrome Canary", "Brave Browser", "Microsoft Edge", "Arc", "Chromium", "Comet", "Dia", "Vivaldi", "Opera"}
        if frontApp is "Safari" then
            tell application "Safari"
                if (count of windows) > 0 then return (URL of current tab of front window) & linefeed & (name of current tab of front window)
            end tell
        else if chromiumApps contains frontApp then
            using terms from application "Google Chrome"
                tell application frontApp
                    if (count of windows) > 0 then return (URL of active tab of front window) & linefeed & (title of active tab of front window)
                end tell
            end using terms from
        end if
        return ""
        """
        guard let output = shell(["/usr/bin/osascript", "-e", script], timeout: 1.0)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            log("source-url:none-or-timeout:\(appName)")
            return nil
        }
        let lines = output.components(separatedBy: .newlines)
        guard let url = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              isWebURL(url) else {
            log("source-url:none-or-timeout:\(appName)")
            return nil
        }
        let title = cleanSourceTitle(lines.dropFirst().joined(separator: " "))
        log("source-url:\(url)")
        return CaptureSource(url: url, title: title)
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

    private func sourceWindowTitle(for application: NSRunningApplication?) -> String? {
        guard let application else { return nil }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let focusedWindow = axElementAttribute(appElement, kAXFocusedWindowAttribute)
        let title = focusedWindow.flatMap { axStringAttribute($0, kAXTitleAttribute) }
            ?? axStringAttribute(appElement, kAXTitleAttribute)
            ?? application.localizedName
        return cleanSourceTitle(title)
    }

    private func sourceDocumentFileURL(for application: NSRunningApplication?, shortcutSlot: ShortcutSlot?) -> CaptureSource? {
        guard resolvedIncludeDocumentSource(for: shortcutSlot),
              let application,
              let bundleIdentifier = application.bundleIdentifier else {
            return nil
        }
        let blockedIdentifiers: Set<String> = [
            Bundle.main.bundleIdentifier ?? "",
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.systemsettings",
            "com.apple.SecurityAgent",
            "com.apple.loginwindow"
        ]
        guard !blockedIdentifiers.contains(bundleIdentifier) else { return nil }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let focusedWindow = axElementAttribute(appElement, kAXFocusedWindowAttribute)
        let focusedElement = axElementAttribute(appElement, kAXFocusedUIElementAttribute)
        let candidates = [focusedElement, focusedWindow, appElement].compactMap { $0 }
        for element in candidates {
            if let rawDocument = axStringAttribute(element, kAXDocumentAttribute),
               let fileURL = standaloneFileURL(from: rawDocument) {
                let title = axStringAttribute(element, kAXTitleAttribute)
                    ?? focusedWindow.flatMap { axStringAttribute($0, kAXTitleAttribute) }
                    ?? application.localizedName
                log("source-document:\(fileURL.absoluteString)")
                return CaptureSource(url: fileURL.absoluteString, title: title)
            }
        }
        return nil
    }

    private func axElementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func axStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let string = value as? String else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

    private func sendTodo(_ todoText: String, shortcutSlot: ShortcutSlot? = nil, sourceURL: String? = nil, sourceTitle: String? = nil) {
        let tagSource = shortcutSlot?.tags ?? Settings.taskTag
        guard let content = normalizedTaskContent(expandedVariables(todoText), tags: tagSource, sourceURL: sourceURL, sourceTitle: sourceTitle) else { return }
        log("sendTodo:\(content)")
        let task = formattedTask(from: content, tags: tagSource, sourceURL: sourceURL, sourceTitle: sourceTitle, shortcutSlot: shortcutSlot)
        log("sendTodoTask:\(task)")
        if shortcutSlot?.engine == .obsidian {
            writeObsidianTask(task, shortcutSlot: shortcutSlot)
            return
        }
        if shortcutSlot?.output == .plainText {
            writePlainTextTask(task, shortcutSlot: shortcutSlot)
            return
        }
        if writeNotePlanTaskIfSectioned(task, shortcutSlot: shortcutSlot) {
            return
        }
        let openNoteValue = resolvedOpenNote(for: shortcutSlot) ? "yes" : "no"
        let noteTarget = notePlanTarget(for: shortcutSlot)
        log("sendTodoTarget:\(noteTarget)")
        let targetPrefix = noteTarget.isEmpty ? "" : "\(noteTarget)&"
        let target = "noteplan://x-callback-url/addText?\(targetPrefix)text=\(encode(task))&mode=append&openNote=\(openNoteValue)"
        if let url = URL(string: target) {
            NSWorkspace.shared.open(url)
        }
    }

    private func openShortcutTarget(_ slot: ShortcutSlot) {
        switch slot.output {
        case .obsidianMarkdown:
            let note = expandedVariables(slot.noteReference).trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty,
               let url = URL(string: "obsidian://open?path=\(encode(note))") {
                NSWorkspace.shared.open(url)
                return
            }
        case .plainText:
            if let fileURL = plainTextFileURL(for: slot) {
                NSWorkspace.shared.open(fileURL)
                return
            }
        case .todayNotePlan, .notePathNotePlan, .standardMarkdown:
            if let fileURL = notePlanFileURL(for: slot) {
                openNotePlanFile(fileURL, shortcutSlot: slot)
                return
            }
        }
        NSSound.beep()
    }

    private func writeNotePlanTaskIfSectioned(_ task: String, shortcutSlot: ShortcutSlot?) -> Bool {
        let explicitSection = expandedVariables(shortcutSlot?.section ?? Settings.captureSection)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let section = explicitSection.isEmpty ? automaticSection(for: task) : explicitSection
        let position = shortcutSlot?.insertPosition ?? .endOfSection
        guard !section.isEmpty || position == .topOfNote || position == .bottomOfNote else {
            log("section-write:disabled")
            return false
        }
        guard let fileURL = notePlanFileURL(for: shortcutSlot) else {
            log("section-write:fallback-no-file")
            return false
        }

        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let original = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let updated = markdownByAppending(task: task, underSection: section, position: position, to: original)
            try updated.write(to: fileURL, atomically: true, encoding: .utf8)
            log("section-write:\(fileURL.path):\(section)")
            if resolvedOpenNote(for: shortcutSlot) {
                openNotePlanFile(fileURL, shortcutSlot: shortcutSlot)
            }
            return true
        } catch {
            log("section-write:error:\(error.localizedDescription)")
            NSSound.beep()
            return true
        }
    }

    private func automaticSection(for task: String) -> String {
        for url in webURLs(in: task) {
            guard let normalized = normalizedWebURL(url),
                  let section = CaptureRulesStore.metadata(for: normalized)?.section,
                  !section.isEmpty else {
                continue
            }
            return section
        }
        return ""
    }

    private func notePlanFileURL(for shortcutSlot: ShortcutSlot?) -> URL? {
        guard let appRoot = notePlanAppRoot() else {
            return nil
        }
        guard let shortcutSlot else {
            return appRoot.appendingPathComponent(todayCalendarRelativePath())
        }

        switch shortcutSlot.destination {
        case .today:
            return appRoot.appendingPathComponent(todayCalendarRelativePath())
        case .notePath, .noteTitle:
            let note = expandedVariables(shortcutSlot.noteReference).trimmingCharacters(in: .whitespacesAndNewlines)
            let folder = expandedVariables(shortcutSlot.folder).trimmingCharacters(in: .whitespacesAndNewlines)
            let path = joinedNotePath(folder: folder, note: note)
            guard !path.isEmpty else {
                return appRoot.appendingPathComponent(todayCalendarRelativePath())
            }
            let notesRoot = notePlanNotesRoot(from: appRoot)
            let finalPath = path.hasSuffix(".md") ? path : "\(path).md"
            return notesRoot.appendingPathComponent(finalPath)
        case .standard:
            return appRoot.appendingPathComponent(todayCalendarRelativePath())
        }
    }

    private func notePlanAppRoot() -> URL? {
        if let selected = Settings.selectedNotesRoot()?.standardizedFileURL {
            return selected.lastPathComponent == "Notes" ? selected.deletingLastPathComponent() : selected
        }
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application Support/co.noteplan.NotePlan-setapp", isDirectory: true)
        return FileManager.default.fileExists(atPath: root.path) ? root : nil
    }

    private func notePlanNotesRoot(from appRoot: URL) -> URL {
        appRoot.lastPathComponent == "Notes" ? appRoot : appRoot.appendingPathComponent("Notes", isDirectory: true)
    }

    private func todayCalendarRelativePath() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "Calendar/\(formatter.string(from: Date())).md"
    }

    private func markdownByAppending(task: String, underSection section: String, position: ShortcutInsertPosition, to original: String) -> String {
        switch position {
        case .topOfNote:
            if original.isEmpty {
                return "\(task)\n"
            }
            return "\(task)\n\(original.hasPrefix("\n") ? "" : "\n")\(original)"
        case .bottomOfNote:
            let prefix = original.isEmpty || original.hasSuffix("\n") ? "" : "\n"
            return "\(original)\(prefix)\(task)\n"
        case .startOfSection, .endOfSection:
            break
        }

        let cleanSection = section.trimmingCharacters(in: CharacterSet(charactersIn: "# \t\r\n"))
        guard !cleanSection.isEmpty else {
            let prefix = original.isEmpty || original.hasSuffix("\n") ? "" : "\n"
            return "\(original)\(prefix)\(task)\n"
        }

        var lines = original.components(separatedBy: "\n")
        if lines.last == "" {
            lines.removeLast()
        }

        var sectionIndex: Int?
        var sectionLevel = 2
        for (index, line) in lines.enumerated() {
            guard let heading = markdownHeading(from: line) else { continue }
            if heading.title.compare(cleanSection, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                sectionIndex = index
                sectionLevel = heading.level
                break
            }
        }

        guard let start = sectionIndex else {
            var output = original
            if !output.isEmpty, !output.hasSuffix("\n") {
                output += "\n"
            }
            if !output.isEmpty {
                output += "\n"
            }
            output += "## \(cleanSection)\n\(task)\n"
            return output
        }

        if position == .startOfSection {
            var insertIndex = start + 1
            while insertIndex < lines.count, lines[insertIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                insertIndex += 1
            }
            lines.insert(task, at: insertIndex)
            return lines.joined(separator: "\n") + "\n"
        }

        var insertIndex = lines.count
        for index in lines.indices.dropFirst(start + 1) {
            guard let heading = markdownHeading(from: lines[index]), heading.level <= sectionLevel else {
                continue
            }
            insertIndex = index
            break
        }

        if insertIndex > start + 1, lines[insertIndex - 1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.insert(task, at: insertIndex - 1)
        } else {
            lines.insert(task, at: insertIndex)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func markdownHeading(from line: String) -> (level: Int, title: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        let level = trimmed.prefix { $0 == "#" }.count
        guard level > 0, level <= 6 else { return nil }
        let title = trimmed.dropFirst(level).trimmingCharacters(in: CharacterSet(charactersIn: " \t#"))
        guard !title.isEmpty else { return nil }
        return (level, String(title))
    }

    private func openNotePlanFile(_ fileURL: URL, shortcutSlot: ShortcutSlot?) {
        let target = notePlanTarget(for: shortcutSlot)
        if !target.isEmpty, let url = URL(string: "noteplan://x-callback-url/openNote?\(target)") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(fileURL)
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

    private func writePlainTextTask(_ task: String, shortcutSlot: ShortcutSlot?) {
        guard let shortcutSlot, let fileURL = plainTextFileURL(for: shortcutSlot) else {
            log("plaintext:error:no-target")
            NSSound.beep()
            return
        }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let original = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let prefix = original.isEmpty || original.hasSuffix("\n") ? "" : "\n"
            let updated = "\(original)\(prefix)\(task)\n"
            try updated.write(to: fileURL, atomically: true, encoding: .utf8)
            log("plaintext-write:\(fileURL.path)")
            if resolvedOpenNote(for: shortcutSlot) {
                NSWorkspace.shared.open(fileURL)
            }
        } catch {
            log("plaintext:error:\(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private func plainTextFileURL(for slot: ShortcutSlot) -> URL? {
        let note = expandedVariables(slot.noteReference).trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = expandedVariables(slot.folder).trimmingCharacters(in: .whitespacesAndNewlines)
        let path = joinedNotePath(folder: folder, note: note)
        guard !path.isEmpty else { return nil }
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path.hasSuffix(".txt") ? path : "\(path).txt")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(path.hasSuffix(".txt") ? path : "\(path).txt")
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

    private func formattedTask(from content: String, tags: String, sourceURL: String? = nil, sourceTitle: String? = nil, shortcutSlot: ShortcutSlot? = nil) -> String {
        let tag = normalizedTags(expandedVariables(tags), extra: llmTags(in: [content, sourceURL].compactMap { $0 }))
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
        if let sourceLine = sourceContinuationLine(sourceURL, title: sourceTitle, content: content, shortcutSlot: shortcutSlot) {
            continuation.append(sourceLine)
        }
        let suffix = tag.isEmpty ? "" : " \(tag)"
        return (["- [ ] \(firstLine)\(suffix)"] + continuation).joined(separator: "\n")
    }

    private func llmTags(in values: [String]) -> [String] {
        var tags: [String] = []
        var seen = Set<String>()
        for value in values {
            for url in webURLs(in: value) {
                guard let normalized = normalizedWebURL(url),
                      let metadata = CaptureRulesStore.metadata(for: normalized) else { continue }
                for tag in metadata.tags where seen.insert(tag.lowercased()).inserted {
                    tags.append(tag)
                }
            }
        }
        return tags
    }

    private func sourceContinuationLine(_ sourceURL: String?, title: String? = nil, content: String, shortcutSlot: ShortcutSlot?) -> String? {
        guard resolvedIncludeSource(for: shortcutSlot),
              let sourceURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !contentAlreadyReferencesSource(content, sourceURL: sourceURL),
              let link = markdownLinkForSourceURL(sourceURL, title: title, shortcutSlot: shortcutSlot) else {
            return nil
        }
        return "> Source : \(link)"
    }

    private func markdownLinkForSourceURL(_ value: String, title: String?, shortcutSlot: ShortcutSlot?) -> String? {
        if let webLink = markdownLinkForWebURL(value, title: title) {
            return webLink
        }

        guard resolvedIncludeDocumentSource(for: shortcutSlot),
              let fileURL = standaloneFileURL(from: value) else {
            return nil
        }
        let label = cleanSourceTitle(title) ?? fileURL.deletingPathExtension().lastPathComponent
        return "[\(escapedMarkdownLinkTitle(label))](\(URL(fileURLWithPath: fileURL.standardizedFileURL.path, isDirectory: isDirectory(fileURL)).absoluteString))"
    }

    private func resolvedOpenNote(for shortcutSlot: ShortcutSlot?) -> Bool {
        if let action = shortcutSlot?.action {
            return action == .captureOpen || action == .open
        }
        let override = shortcutOptionOverride(in: shortcutSlot?.tags, positive: "!Open", negative: "!NoOpen")
            ?? shortcutSlot?.openNoteOverride
            ?? .inherit
        return override.resolved(default: Settings.openNote)
    }

    private func resolvedIncludeSource(for shortcutSlot: ShortcutSlot?) -> Bool {
        let override = shortcutOptionOverride(in: shortcutSlot?.tags, positive: "!Web", negative: "!NoWeb")
            ?? shortcutSlot?.includeSourceOverride
            ?? .inherit
        return override.resolved(default: Settings.includeSource)
    }

    private func resolvedIncludeDocumentSource(for shortcutSlot: ShortcutSlot?) -> Bool {
        let override = shortcutOptionOverride(in: shortcutSlot?.tags, positive: "!File", negative: "!NoFile")
            ?? shortcutSlot?.includeDocumentSourceOverride
            ?? .inherit
        return override.resolved(default: Settings.includeDocumentSource)
    }

    private func shortcutOptionOverride(in tags: String?, positive: String, negative: String) -> ShortcutOptionOverride? {
        let tokens = Set((tags ?? "")
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.hasPrefix("!") })
        if tokens.contains(negative.lowercased()) { return .disabled }
        if tokens.contains(positive.lowercased()) { return .enabled }
        return nil
    }

    private func cleanSourceTitle(_ value: String?) -> String? {
        let cleaned = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"(?i)\s+[-–—]\s+(TextEdit|Aperçu|Preview|Pages|Numbers|Keynote|Microsoft Word|Word|PDF Expert)$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\s+[-–—]\s+(Safari|Google Chrome|Chrome|Comet|Biscuit|Arc|Brave Browser|Brave|Microsoft Edge|Edge|Dia|Vivaldi|Opera)(\s+[-–—]\s+.*)?$"#, with: "", options: .regularExpression)
        guard let cleaned, !cleaned.isEmpty, cleaned != "(null)" else { return nil }
        return cleaned
    }

    private func preferredSourceTitle(_ title: String?, fallback: String?, url: String?) -> String? {
        let cleanedTitle = cleanSourceTitle(title)
        if let usable = usableLLMTitle(cleanedTitle, for: url) {
            return usable
        }

        let cleanedFallback = cleanSourceTitle(fallback)
        if let usable = usableLLMTitle(cleanedFallback, for: url) {
            return usable
        }

        if let url,
           let normalized = normalizedWebURL(url),
           let metadata = CaptureRulesStore.metadata(for: normalized) {
            return metadata.title
        }

        return cleanedTitle ?? cleanedFallback
    }

    private func usableLLMTitle(_ title: String?, for url: String?) -> String? {
        guard let title else { return nil }
        if isGenericLLMTitle(title, for: url) {
            return nil
        }
        guard isLLMURL(url) else {
            return title
        }
        if title.count <= 120 {
            return title
        }
        return compactLLMTitle(title)
    }

    private func isLLMURL(_ url: String?) -> Bool {
        guard let url,
              let normalized = normalizedWebURL(url) else {
            return false
        }
        return CaptureRulesStore.metadata(for: normalized) != nil
    }

    private func compactLLMTitle(_ title: String) -> String? {
        let separators = [" : ", ": ", " — ", " - ", " | "]
        for separator in separators {
            guard let range = title.range(of: separator) else { continue }
            let prefix = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if prefix.count >= 4, prefix.count <= 90 {
                return prefix
            }
        }
        return nil
    }

    private func isGenericLLMTitle(_ title: String?, for url: String?) -> Bool {
        guard let title else { return true }
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return true }

        let genericTitles: Set<String> = [
            "perplexity",
            "perplexity task",
            "perplexity search",
            "claude",
            "claude chat",
            "gpt",
            "gpt chat",
            "chatgpt",
            "chatgpt chat"
        ]
        if genericTitles.contains(key) {
            return true
        }

        guard let url,
              let normalized = normalizedWebURL(url),
              let metadata = CaptureRulesStore.metadata(for: normalized) else {
            return false
        }
        return key == metadata.title.lowercased()
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
        let pattern = #"(?:https?://)?(?:www\.)?[A-Za-z0-9][A-Za-z0-9.-]+\.[A-Za-z]{2,}(?::\d+)?(?:/[^\s<>"'\]\)\[]*)?"#
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
            guard !tag.hasPrefix("!") else { continue }
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

final class NotePlanSortTextView: NSTextView {
    var onDroppedPath: ((String) -> Bool)?

    convenience init() {
        self.init(frame: NSRect(x: 0, y: 0, width: 900, height: 500), textContainer: nil)
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedPath(from: sender.draggingPasteboard) == nil ? super.draggingEntered(sender) : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedPath(from: sender.draggingPasteboard) == nil ? super.draggingUpdated(sender) : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let path = droppedPath(from: sender.draggingPasteboard) else {
            return super.performDragOperation(sender)
        }
        return onDroppedPath?(path) ?? false
    }

    private func droppedPath(from pasteboard: NSPasteboard) -> String? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            return url.isFileURL ? url.path : url.absoluteString
        }
        if let raw = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            if raw.hasPrefix("file://"), let url = URL(string: raw) {
                return url.path
            }
            return raw
        }
        return nil
    }
}

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
        controller.loadInitialFileIfNeeded()
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
    var onCloseEmbeddedSort: (() -> Void)?
    private var functionsWindow: NSWindow?
    private var openAfterFunctionCheckbox: NSButton?
    private var generatedShortcutURL: URL?
    private var editorMenu: NSMenu!
    private var embeddedContentView: NSView?
    private var didLoadInitialFile = false

    private var rootURL: URL
    private var currentFileURL: URL?
    private var loadedContent = ""
    private var sourceMarkdown = ""
    private var collapsedBlockStarts = Set<Int>()
    private var initialCollapsedBlockStarts = Set<Int>()
    private var displayedSourceLines: [Int] = []
    private var isFoldView = false
    private var isApplyingHighlight = false

    private struct LoadedFile {
        let relativePath: String
        let fileURL: URL
        let content: String
    }

    override init() {
        let defaultRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application Support/co.noteplan.NotePlan-setapp")
        rootURL = Settings.selectedNotesRoot().map(Self.normalizedNotePlanRoot)
            ?? UserDefaults.standard.string(forKey: "noteplanRoot").map(URL.init(fileURLWithPath:))
            ?? defaultRoot
        super.init()
    }

    private func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func embeddedView() -> NSView {
        if let embeddedContentView {
            return embeddedContentView
        }
        buildMenu()
        let content = buildEditorContentView()
        embeddedContentView = content
        return content
    }

    func activateEmbeddedSort() {
        if let selectedRoot = Settings.selectedNotesRoot() {
            let normalized = Self.normalizedNotePlanRoot(selectedRoot)
            if rootURL.path != normalized.path {
                rootURL = normalized
                rootField.stringValue = normalized.path
                didLoadInitialFile = false
            }
        }
        loadInitialFileIfNeeded()
        if textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           currentFileURL != nil || fileField.stringValue.hasPrefix("Calendar/") {
            loadTodayDirect(reason: "activation")
        }
        textView.window?.makeFirstResponder(textView)
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
        window.contentView = buildEditorContentView()
    }

    private func buildEditorContentView() -> NSView {
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false

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
        let applyButton = NSButton(title: "Valider dossier", target: self, action: #selector(applyRootFromField))
        let loadButton = NSButton(title: "Charger", target: self, action: #selector(loadFileFromField))
        let previousDayButton = NSButton(title: "← Jour", target: self, action: #selector(loadPreviousDay))
        let todayButton = NSButton(title: "Aujourd'hui", target: self, action: #selector(loadTodayAction))
        let nextDayButton = NSButton(title: "Jour →", target: self, action: #selector(loadNextDay))
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(reloadFile))
        let closeSortButton = NSButton(title: "Fermer Note Commander", target: self, action: #selector(closeEmbeddedSort))
        reloadButton.target = self
        reloadButton.action = #selector(reloadFile)
        saveButton.target = self
        saveButton.action = #selector(saveFile)
        setSaveButtonState(.clean)
        let sortButton = NSButton(title: "Trier priorités", target: self, action: #selector(sortPriorities))
        let sortAtButton = NSButton(title: "Trier @", target: self, action: #selector(sortAtContext))
        let sortHashButton = NSButton(title: "Trier #", target: self, action: #selector(sortHashContext))
        let sortImportanceButton = NSButton(title: "Trier ^^", target: self, action: #selector(sortImportance))
        let sortMinutesButton = NSButton(title: "Trier --", target: self, action: #selector(sortMinutes))
        let flattenButton = NSButton(title: "Aplatir chapitres", target: self, action: #selector(flattenChapters))
        let paletteLabel = NSTextField(labelWithString: "NotePlan")
        paletteLabel.font = .systemFont(ofSize: 12, weight: .medium)
        let palettePopup = NSPopUpButton()
        palettePopup.addItems(withTitles: EditorMarkdownHighlighter.Palette.allCases.map(\.rawValue))
        palettePopup.selectItem(withTitle: EditorMarkdownHighlighter.palette.rawValue)
        palettePopup.target = self
        palettePopup.action = #selector(changeMarkdownPalette(_:))
        let foldBlockButton = NSButton(title: "Plier bloc", target: self, action: #selector(foldCurrentBlock))
        let unfoldBlockButton = NSButton(title: "Déplier bloc", target: self, action: #selector(unfoldCurrentBlock))
        let foldAllButton = NSButton(title: "Tout plier", target: self, action: #selector(foldAllBlocks))
        let unfoldAllButton = NSButton(title: "Tout déplier", target: self, action: #selector(unfoldAllBlocks))
        let restoreFoldButton = NSButton(title: "État initial", target: self, action: #selector(restoreInitialFoldState))
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
        textView.isAutomaticLinkDetectionEnabled = false
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .controlAccentColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.frame = NSRect(x: 0, y: 0, width: 1100, height: 640)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 1100,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.setAccessibilityElement(true)
        textView.setAccessibilityRole(.textArea)
        textView.setAccessibilityLabel("Contenu de la note")
        textView.delegate = self
        textView.string = ""
        applySyntaxHighlighting()

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

        let fileActionRow = NSStackView(views: [fileActionsLabel, previousDayButton, todayButton, nextDayButton, reloadButton, refreshButton, saveButton, closeSortButton])
        fileActionRow.orientation = .horizontal
        fileActionRow.spacing = 8
        fileActionRow.alignment = .centerY

        let sortRow = NSStackView(views: [sortLabel, sortButton, sortAtButton, sortHashButton, sortImportanceButton, sortMinutesButton, flattenButton])
        sortRow.orientation = .horizontal
        sortRow.spacing = 8
        sortRow.alignment = .centerY

        let viewRow = NSStackView(views: [paletteLabel, palettePopup, foldBlockButton, unfoldBlockButton, foldAllButton, unfoldAllButton, restoreFoldButton])
        viewRow.orientation = .horizontal
        viewRow.spacing = 8
        viewRow.alignment = .centerY

        let searchRow = NSStackView(views: [searchLabel, searchField, searchButton, time15Button, time30Button, time60Button, timeMoreButton])
        searchRow.orientation = .horizontal
        searchRow.spacing = 8
        searchRow.alignment = .centerY

        let rangeRow = NSStackView(views: [rangeStartLabel, rangeStartField, rangeEndLabel, rangeEndField, flattenRangeButton])
        rangeRow.orientation = .horizontal
        rangeRow.spacing = 8
        rangeRow.alignment = .centerY

        let header = NSStackView(views: [topRow, fileRow, fileActionRow, sortRow, viewRow, searchRow, rangeRow, pathLabel, statusLabel])
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
        return content
    }

    @objc private func closeEmbeddedSort() {
        onCloseEmbeddedSort?()
    }

    private func loadInitialFileIfNeeded() {
        guard !didLoadInitialFile else { return }
        didLoadInitialFile = true
        loadTodayAsync()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.textView.window?.makeFirstResponder(self.textView)
        }
    }

    private func todayPath() -> String {
        "Calendar/\(todayStamp()).md"
    }

    private func todayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }

    private func calendarPath(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "Calendar/\(formatter.string(from: date)).md"
    }

    private func dateFromCurrentCalendarPath() -> Date? {
        let value = fileField.stringValue
        guard let match = value.range(of: #"\d{8}"#, options: .regularExpression) else { return nil }
        let stamp = String(value[match])
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: stamp)
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
            let normalized = Self.normalizedNotePlanRoot(url)
            try validateRoot(normalized)
            rootURL = normalized
            UserDefaults.standard.set(normalized.path, forKey: "noteplanRoot")
            Settings.setNotesRoot(url)
            rootField.stringValue = normalized.path
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
        loadTodayDirect(reason: "bouton")
    }

    private func loadTodayDirect(reason: String) {
        rootURL = Self.normalizedNotePlanRoot(rootURL)
        rootField.stringValue = rootURL.path
        let path = todayPath()
        fileField.stringValue = path
        do {
            let loaded = try Self.readFile(pathString: path, rootURL: rootURL, createIfMissing: true)
            applyLoadedFile(loaded, statusText: "Aujourd'hui chargé (\(reason))")
        } catch {
            status("Erreur aujourd'hui: \(error.localizedDescription)")
        }
    }

    @objc private func loadPreviousDay() {
        loadRelativeDay(offset: -1)
    }

    @objc private func loadNextDay() {
        loadRelativeDay(offset: 1)
    }

    private func loadRelativeDay(offset: Int) {
        guard currentEditorMarkdown() == loadedContent else {
            status("Sauvegarde avant de changer de jour.")
            setSaveButtonState(.dirty)
            return
        }
        let base = dateFromCurrentCalendarPath() ?? Date()
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: base) else {
            status("Date invalide.")
            return
        }
        let path = calendarPath(for: date)
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

    private func openDroppedFile(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        open(pathString: trimmed, createIfMissing: false)
        return true
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
        let rootURL = normalizedNotePlanRoot(rootURL)
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
            let cleanedPath = pathString.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = resolveRelativeNotePlanFile(cleanedPath, rootURL: rootURL, createIfMissing: createIfMissing)
            relativePath = resolved.relativePath
            fileURL = resolved.fileURL
        }
        if createIfMissing && !FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        let content = try readUTF8File(fileURL)
        return LoadedFile(relativePath: relativePath, fileURL: fileURL, content: content)
    }

    private static func normalizedNotePlanRoot(_ url: URL) -> URL {
        if url.lastPathComponent == "Notes" {
            let parent = url.deletingLastPathComponent()
            let hasCalendar = FileManager.default.fileExists(atPath: parent.appendingPathComponent("Calendar").path)
            let hasNotes = FileManager.default.fileExists(atPath: parent.appendingPathComponent("Notes").path)
            if hasCalendar && hasNotes {
                return parent
            }
        }
        return url
    }

    private static func resolveRelativeNotePlanFile(_ path: String, rootURL: URL, createIfMissing: Bool) -> (relativePath: String, fileURL: URL) {
        let candidate = rootURL.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: candidate.path) || path.hasPrefix("Calendar/") || path.hasPrefix("Notes/") || createIfMissing {
            return (path, candidate)
        }

        let notesCandidate = rootURL.appendingPathComponent("Notes").appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: notesCandidate.path) {
            return ("Notes/\(path)", notesCandidate)
        }

        return (path, candidate)
    }

    private static func readUTF8File(_ url: URL) throws -> String {
        if let direct = try? String(contentsOf: url, encoding: .utf8) {
            return direct
        }

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
            return try String(contentsOf: url, encoding: .utf8)
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

    private func applyLoadedFile(_ loaded: LoadedFile, statusText: String = "Fichier chargé et éditable") {
        currentFileURL = loaded.fileURL
        loadedContent = loaded.content
        sourceMarkdown = loaded.content
        collapsedBlockStarts.removeAll()
        initialCollapsedBlockStarts.removeAll()
        isFoldView = false
        displayedSourceLines = Array(0..<loaded.content.components(separatedBy: "\n").count)
        textView.isEditable = true
        textView.string = loaded.content
        applySyntaxHighlighting()
        let contentWidth = max(scrollView.contentSize.width, 1100)
        textView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: max(scrollView.contentSize.height, 640))
        textView.textContainer?.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
        if let container = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: container)
        }
        textView.needsDisplay = true
        scrollView.documentView = textView
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollToBeginningOfDocument(nil)
        pathLabel.stringValue = loaded.relativePath
        fileField.stringValue = loaded.relativePath
        setVisibleTitle("Note Commander - \(loaded.relativePath)")
        textView.window?.makeFirstResponder(textView)
        setSaveButtonState(.clean)
        status("\(statusText) - \(loaded.content.count) caractères")
    }

    @objc private func reloadFile() {
        guard let currentFileURL else { return }
        open(pathString: currentFileURL.path.replacingOccurrences(of: rootURL.path + "/", with: ""), createIfMissing: false)
    }

    @objc private func saveFile() {
        guard let fileURL = currentFileURL else { return }
        do {
            if isFoldView {
                status("Déplie avant de sauvegarder: le pliage est un affichage.")
                return
            }
            let disk = try String(contentsOf: fileURL, encoding: .utf8)
            guard disk == loadedContent else {
                status("Le fichier a changé sur disque. Recharge avant de sauvegarder.")
                return
            }
            try backup(fileURL: fileURL, content: disk)
            let markdown = currentEditorMarkdown()
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            loadedContent = markdown
            sourceMarkdown = markdown
            setSaveButtonState(.saved)
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
        alert.icon = noteDroopyLogoImage(size: NSSize(width: 96, height: 96))
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
        infoWindow.title = "Actions NoteDroppy"

        let titleLabel = NSTextField(labelWithString: "Actions")
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
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorPrioritySorter.sort(currentEditorMarkdown()))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortMinutes() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorTaskSorter.sort(currentEditorMarkdown(), mode: .minutes))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri -- appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortAtContext() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorTaskSorter.sort(currentEditorMarkdown(), mode: .atContext))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri @ appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortHashContext() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorTaskSorter.sort(currentEditorMarkdown(), mode: .hashTag))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri # appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortImportance() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorTaskSorter.sort(currentEditorMarkdown(), mode: .importance))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri ^^ appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func flattenChapters() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorChapterFlattener.flatten(currentEditorMarkdown()))
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
        sourceMarkdown = output
        setSaveButtonState(.clean)
        pathLabel.stringValue = "Résultats de recherche non sauvegardables"
        setVisibleTitle("Note Commander - \(title)")
        status("\(results.count) résultat(s)")
    }

    private func setVisibleTitle(_ title: String) {
        if let visibleWindow = textView.window {
            visibleWindow.title = title
        } else {
            window.title = title
        }
    }

    private func replaceEditorText(_ newText: String) {
        guard ensureEditableMarkdownView() else { return }
        guard let storage = textView.textStorage else {
            textView.string = newText
            sourceMarkdown = newText
            return
        }
        let oldText = textView.string
        let range = NSRange(location: 0, length: storage.length)
        textView.undoManager?.registerUndo(withTarget: self) { target in
            target.replaceEditorText(oldText)
        }
        storage.replaceCharacters(in: range, with: newText)
        sourceMarkdown = newText
        applySyntaxHighlighting()
    }

    func textDidChange(_ notification: Notification) {
        if !isApplyingHighlight && !isFoldView {
            sourceMarkdown = textView.string
        }
        applySyntaxHighlighting()
        setSaveButtonState(currentFileURL != nil && currentEditorMarkdown() != loadedContent ? .dirty : .clean)
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        NSWorkspace.shared.open(url)
        status("Lien ouvert: \(url.absoluteString)")
        return true
    }

    @objc private func changeMarkdownPalette(_ sender: NSPopUpButton) {
        if let title = sender.selectedItem?.title, let palette = EditorMarkdownHighlighter.Palette(rawValue: title) {
            EditorMarkdownHighlighter.palette = palette
            UserDefaults.standard.set(title, forKey: "markdownPalette")
            applySyntaxHighlighting()
            status("Palette: \(title)")
        }
    }

    @objc private func foldCurrentBlock() {
        let sourceLine = currentSourceLineIndex()
        guard hasChildLine(after: sourceLine, in: sourceLines()) else {
            status("Aucun sous-bloc sur cette ligne.")
            return
        }
        collapsedBlockStarts.insert(sourceLine)
        renderFoldView(statusText: "Bloc plié")
    }

    @objc private func unfoldCurrentBlock() {
        let sourceLine = currentSourceLineIndex()
        collapsedBlockStarts.remove(sourceLine)
        renderFoldView(statusText: "Bloc déplié")
    }

    @objc private func foldAllBlocks() {
        let lines = sourceLines()
        collapsedBlockStarts = Set(lines.indices.filter { hasChildLine(after: $0, in: lines) })
        renderFoldView(statusText: "Tout plié")
    }

    @objc private func unfoldAllBlocks() {
        collapsedBlockStarts.removeAll()
        isFoldView = false
        textView.isEditable = true
        textView.string = sourceMarkdown
        displayedSourceLines = Array(0..<sourceLines().count)
        applySyntaxHighlighting()
        setSaveButtonState(currentFileURL != nil && sourceMarkdown != loadedContent ? .dirty : .clean)
        status("Tout déplié: Markdown complet éditable")
    }

    @objc private func restoreInitialFoldState() {
        collapsedBlockStarts = initialCollapsedBlockStarts
        if collapsedBlockStarts.isEmpty {
            unfoldAllBlocks()
        } else {
            renderFoldView(statusText: "État initial restauré")
        }
    }

    private func ensureEditableMarkdownView() -> Bool {
        if isFoldView {
            status("Déplie avant modification: le Markdown complet est protégé.")
            return false
        }
        return true
    }

    private func currentEditorMarkdown() -> String {
        isFoldView ? sourceMarkdown : textView.string
    }

    private func sourceLines() -> [String] {
        sourceMarkdown.components(separatedBy: "\n")
    }

    private func currentSourceLineIndex() -> Int {
        let selected = textView.selectedRange().location
        let visible = textView.string as NSString
        let clamped = min(max(selected, 0), visible.length)
        let prefix = visible.substring(with: NSRange(location: 0, length: clamped))
        let displayLine = prefix.reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
        guard displayLine >= 0, displayLine < displayedSourceLines.count else {
            return min(displayLine, max(sourceLines().count - 1, 0))
        }
        return displayedSourceLines[displayLine]
    }

    private func renderFoldView(statusText: String) {
        sourceMarkdown = currentEditorMarkdown()
        let result = foldedMarkdown(lines: sourceLines(), collapsed: collapsedBlockStarts)
        isFoldView = !collapsedBlockStarts.isEmpty
        displayedSourceLines = result.sourceLineIndexes
        textView.isEditable = !isFoldView
        textView.string = result.text
        applySyntaxHighlighting()
        setSaveButtonState(currentFileURL != nil && sourceMarkdown != loadedContent ? .dirty : .clean)
        status(isFoldView ? "\(statusText) - affichage seul, Markdown conservé" : statusText)
    }

    private func foldedMarkdown(lines: [String], collapsed: Set<Int>) -> (text: String, sourceLineIndexes: [Int]) {
        var visible: [String] = []
        var map: [Int] = []
        var hiddenUntilIndent: Int?
        for index in lines.indices {
            let indent = lineIndent(lines[index])
            if let hiddenIndent = hiddenUntilIndent {
                if lines[index].trimmingCharacters(in: .whitespaces).isEmpty || indent > hiddenIndent {
                    continue
                }
                hiddenUntilIndent = nil
            }
            let marker: String
            if hasChildLine(after: index, in: lines) {
                marker = collapsed.contains(index) ? "▸ " : "▾ "
            } else {
                marker = ""
            }
            visible.append(marker + lines[index])
            map.append(index)
            if collapsed.contains(index) {
                hiddenUntilIndent = indent
            }
        }
        return (visible.joined(separator: "\n"), map)
    }

    private func hasChildLine(after index: Int, in lines: [String]) -> Bool {
        guard index >= 0, index < lines.count else { return false }
        let parentIndent = lineIndent(lines[index])
        let parentTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
        guard !parentTrimmed.isEmpty else { return false }
        for next in lines.index(after: index)..<lines.count {
            let trimmed = lines[next].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let indent = lineIndent(lines[next])
            if indent <= parentIndent { return false }
            return true
        }
        return false
    }

    private func lineIndent(_ line: String) -> Int {
        line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 2 : 1) }
    }

    private enum SaveButtonState {
        case clean
        case dirty
        case saved
    }

    private func setSaveButtonState(_ state: SaveButtonState) {
        switch state {
        case .clean:
            styleButton(saveButton, title: "Sauvegarder", background: .controlColor, foreground: .secondaryLabelColor, enabled: false)
        case .dirty:
            styleButton(saveButton, title: "Sauvegarder", background: .systemOrange, foreground: .white, enabled: true)
        case .saved:
            styleButton(saveButton, title: "Sauvegardé", background: .systemGreen, foreground: .white, enabled: true)
        }
    }

    private func styleButton(_ button: NSButton, title: String, background: NSColor, foreground: NSColor, enabled: Bool) {
        button.isEnabled = enabled
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = background.cgColor
        button.layer?.cornerRadius = 6
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: foreground,
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
            ]
        )
    }

    private func applySyntaxHighlighting() {
        guard !isApplyingHighlight, let storage = textView.textStorage else { return }
        isApplyingHighlight = true
        let selectedRanges = textView.selectedRanges
        EditorMarkdownHighlighter.apply(to: storage)
        textView.selectedRanges = selectedRanges
        isApplyingHighlight = false
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

private enum EditorMarkdownHighlighter {
    enum Palette: String, CaseIterable {
        case notePlan = "NotePlan"
        case contrast = "Contraste"
        case soft = "Douce"
    }

    static var palette: Palette = {
        if let value = UserDefaults.standard.string(forKey: "markdownPalette"),
           let palette = Palette(rawValue: value) {
            return palette
        }
        return .notePlan
    }()

    private static let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    static func apply(to storage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        storage.beginEditing()
        storage.setAttributes(baseAttributes(), range: fullRange)

        let text = storage.string as NSString
        text.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            styleLine(in: storage, nsText: text, lineRange: lineRange)
        }

        applyRegex(#"`[^`]+`"#, storage: storage, fullRange: fullRange, color: .secondaryLabelColor, font: codeFont)
        applyRegex(#"#[\p{L}\p{N}_/-]+"#, storage: storage, fullRange: fullRange, color: NSColor.systemOrange)
        applyRegex(#"(?<!\S)@[\p{L}\p{N}_/-]+"#, storage: storage, fullRange: fullRange, color: NSColor.systemBlue)
        applyRegex(#">\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?"#, storage: storage, fullRange: fullRange, color: NSColor.systemPurple)
        applyRegex(#"\b\d{1,2}:\d{2}\b"#, storage: storage, fullRange: fullRange, color: NSColor.systemPurple)
        applyMarkdownLinks(to: storage, fullRange: fullRange)

        storage.endEditing()
    }

    private static func styleLine(in storage: NSTextStorage, nsText: NSString, lineRange: NSRange) {
        guard lineRange.length > 0 else { return }
        let line = nsText.substring(with: lineRange)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indent = line.prefix { $0 == " " || $0 == "\t" }.count

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 1
        paragraph.headIndent = CGFloat(min(indent, 12)) * 7
        storage.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)

        if trimmed.hasPrefix("#") {
            let level = min(trimmed.prefix { $0 == "#" }.count, 4)
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: CGFloat(max(20 - level * 2, 14)), weight: .bold),
                .foregroundColor: NSColor.systemOrange
            ], range: lineRange)
            return
        }

        if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("* [x]") || trimmed.hasPrefix("- [X]") || trimmed.hasPrefix("* [X]") {
            storage.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ], range: lineRange)
        } else if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("* [ ]") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            storage.addAttribute(.foregroundColor, value: colorForIndent(indent), range: lineRange)
        }

        styleUrgency(in: storage, nsText: nsText, lineRange: lineRange, line: line)
    }

    private static func styleUrgency(in storage: NSTextStorage, nsText: NSString, lineRange: NSRange, line: String) {
        let urgency: (token: String, color: NSColor, background: NSColor)?
        if line.contains("!!!") {
            urgency = ("!!!", .white, NSColor.systemRed.withAlphaComponent(0.78))
        } else if line.contains("!!") {
            urgency = ("!!", NSColor.systemRed, NSColor.systemRed.withAlphaComponent(0.16))
        } else if line.contains("!") {
            urgency = ("!", NSColor.systemOrange, NSColor.systemOrange.withAlphaComponent(0.12))
        } else {
            urgency = nil
        }
        guard let urgency else { return }

        storage.addAttribute(.backgroundColor, value: urgency.background, range: lineRange)
        var searchStart = lineRange.location
        let lineEnd = lineRange.location + lineRange.length
        while searchStart < lineEnd {
            let found = nsText.range(of: urgency.token, options: [], range: NSRange(location: searchStart, length: lineEnd - searchStart))
            if found.location == NSNotFound { break }
            storage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold),
                .foregroundColor: urgency.color
            ], range: found)
            searchStart = found.location + max(found.length, 1)
        }
    }

    private static func applyRegex(_ pattern: String, storage: NSTextStorage, fullRange: NSRange, color: NSColor, font: NSFont? = nil) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        regex.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let range = match?.range, range.location != NSNotFound else { return }
            storage.addAttribute(.foregroundColor, value: color, range: range)
            if let font {
                storage.addAttribute(.font, value: font, range: range)
            }
        }
    }

    private static func applyMarkdownLinks(to storage: NSTextStorage, fullRange: NSRange) {
        applyLinkRegex(
            #"\[([^\]\n]+)\]\\?\(\[(https?://[^\]\n]+)\]\((https?://[^)\s]+)\)\)"#,
            storage: storage,
            fullRange: fullRange,
            titleGroup: 1,
            urlGroup: 3
        )
        applyLinkRegex(
            #"(?<!\()\[([^\]\n]+)\]\((https?://[^)\s]+)\)"#,
            storage: storage,
            fullRange: fullRange,
            titleGroup: 1,
            urlGroup: 2
        )
    }

    private static func applyLinkRegex(_ pattern: String, storage: NSTextStorage, fullRange: NSRange, titleGroup: Int, urlGroup: Int) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let text = storage.string as NSString
        regex.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let match else { return }
            let titleRange = match.range(at: titleGroup)
            let urlRange = match.range(at: urlGroup)
            guard titleRange.location != NSNotFound, urlRange.location != NSNotFound else { return }
            let urlString = text.substring(with: urlRange)
            guard let url = URL(string: urlString) else { return }

            let hiddenAttributes: [NSAttributedString.Key: Any] = [
                .link: url,
                .foregroundColor: NSColor.clear,
                .font: NSFont.monospacedSystemFont(ofSize: 0.1, weight: .regular)
            ]
            let titleStart = titleRange.location
            let titleEnd = titleRange.location + titleRange.length
            let matchEnd = match.range.location + match.range.length

            if titleStart > match.range.location {
                storage.addAttributes(hiddenAttributes, range: NSRange(location: match.range.location, length: titleStart - match.range.location))
            }
            if matchEnd > titleEnd {
                storage.addAttributes(hiddenAttributes, range: NSRange(location: titleEnd, length: matchEnd - titleEnd))
            }
            if titleEnd < matchEnd {
                storage.addAttributes(arrowAttributes(url: url), range: NSRange(location: titleEnd, length: 1))
            }
            storage.addAttributes([
                .link: url,
                .foregroundColor: NSColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
            ], range: titleRange)
        }
    }

    private static func arrowAttributes(url: URL) -> [NSAttributedString.Key: Any] {
        let attachment = NSTextAttachment()
        if let image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: "Ouvrir le lien") {
            image.isTemplate = true
            attachment.image = image
            attachment.bounds = NSRect(x: 1, y: -1, width: 10, height: 10)
        }
        return [
            .attachment: attachment,
            .link: url,
            .foregroundColor: NSColor.systemBlue,
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        ]
    }

    private static func baseAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor.textBackgroundColor
        ]
    }

    private static func colorForIndent(_ indent: Int) -> NSColor {
        let level = max(0, min(indent / 2, 5))
        switch palette {
        case .notePlan:
            let colors: [NSColor] = [.labelColor, .systemOrange, .systemTeal, .systemBlue, .systemIndigo, .secondaryLabelColor]
            return colors[level]
        case .contrast:
            let colors: [NSColor] = [.labelColor, .systemRed, .systemOrange, .systemGreen, .systemBlue, .systemPurple]
            return colors[level]
        case .soft:
            let colors: [NSColor] = [.labelColor, .systemBrown, .systemMint, .systemCyan, .systemGray, .secondaryLabelColor]
            return colors[level]
        }
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
        openWithApplicationURL: URL? = nil,
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

        let noteURLString = openWithApplicationURL == nil
            ? notePlanOpenURLString(for: noteURL, fallbackTitle: noteName)
            : noteURL.standardizedFileURL.absoluteString
        let finalAppPath = destinationURL.path + "/" + noteName + ".app"
        if let openWithApplicationURL {
            try compileFileShortcutApp(
                fileURL: noteURL,
                applicationURL: openWithApplicationURL,
                appName: noteName,
                finalAppPath: finalAppPath,
                destinationDir: destinationURL
            )
        } else {
            try compileShortcutApp(
                noteURLString: noteURLString,
                appName: noteName,
                finalAppPath: finalAppPath,
                destinationDir: destinationURL
            )
        }
        try verify(appURL: appURL, noteName: noteName, noteURLString: noteURLString)

        return EditorShortcutResult(noteName: noteName, noteURLString: noteURLString, appURL: appURL)
    }

    static func generate(
        noteURLString: String,
        appName: String,
        destinationURL: URL,
        confirmReplace: (URL) -> Bool = { _ in true }
    ) throws -> EditorShortcutResult {
        guard URLComponents(string: noteURLString)?.scheme?.lowercased() == "noteplan" else {
            throw EditorNotePlanShortcutError.commandFailed("URL NotePlan invalide.")
        }

        let noteName = sanitizedAppName(appName)
        guard !noteName.isEmpty else {
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
        let escapedNoteURLString = appleScriptString(noteURLString)
        let script = """
        open location "\(escapedNoteURLString)"
        delay 0.1
        try
            tell application "NotePlan" to activate
        end try
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
            try run("/usr/bin/codesign", ["--force", "--deep", "-s", "-", finalAppPath])
        } catch {
            try? FileManager.default.removeItem(at: tempAppURL)
            throw error
        }
    }

    private static func compileFileShortcutApp(fileURL: URL, applicationURL: URL, appName: String, finalAppPath: String, destinationDir: URL) throws {
        guard FileManager.default.fileExists(atPath: applicationURL.path),
              applicationURL.pathExtension.lowercased() == "app" else {
            throw EditorNotePlanShortcutError.commandFailed("App d’ouverture invalide: \(applicationURL.path)")
        }

        let filePath = appleScriptString(fileURL.standardizedFileURL.path)
        let appPath = appleScriptString(applicationURL.standardizedFileURL.path)
        let targetURLString = fileURL.standardizedFileURL.absoluteString
        let script = """
        do shell script "/usr/bin/open -a " & quoted form of "\(appPath)" & " " & quoted form of "\(filePath)"
        """
        let tempAppURL = destinationDir.appendingPathComponent(".nps-tmp-\(UUID().uuidString).app")

        do {
            try run("/usr/bin/osacompile", ["-o", tempAppURL.path, "-e", script])
            let plistURL = tempAppURL.appendingPathComponent("Contents/Info.plist")
            try setPlistStrings(
                [
                    "CFBundleName": appName,
                    "CFBundleDisplayName": appName,
                    "NotePlanShortcutURL": targetURLString,
                    "NoteDroopyOpenWithApp": applicationURL.standardizedFileURL.path
                ],
                plistURL: plistURL
            )
            try renamePreservingUnicode(fromPath: tempAppURL.path, toPath: finalAppPath)
            try run("/usr/bin/codesign", ["--force", "--deep", "-s", "-", finalAppPath])
        } catch {
            try? FileManager.default.removeItem(at: tempAppURL)
            throw error
        }
    }

    private static func notePlanOpenURLString(for noteURL: URL, fallbackTitle: String) -> String {
        if let notePath = notePathRelativeToNotesRoot(for: noteURL) {
            let encodedPath = urlEncode(notePath)
            return "noteplan://x-callback-url/openNote?notePath=\(encodedPath)&fileName=\(encodedPath)"
        }
        return "noteplan://x-callback-url/openNote?noteTitle=\(urlEncode(fallbackTitle))"
    }

    private static func notePathRelativeToNotesRoot(for noteURL: URL) -> String? {
        let fileURL = noteURL.standardizedFileURL
        let filePath = normalizedPath(fileURL)
        for rootURL in notePlanNotesRootCandidates() {
            let rootPath = normalizedPath(rootURL)
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            guard filePath.hasPrefix(prefix) else {
                continue
            }
            let relative = String(filePath.dropFirst(prefix.count))
            return relative.isEmpty ? nil : relative
        }
        return nil
    }

    private static func notePlanNotesRootCandidates() -> [URL] {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let selectedRoot = Settings.selectedNotesRoot()?.standardizedFileURL {
            if selectedRoot.lastPathComponent == "Notes" {
                candidates.append(selectedRoot)
            } else {
                candidates.append(selectedRoot.appendingPathComponent("Notes", isDirectory: true))
            }
        }

        let home = fileManager.homeDirectoryForCurrentUser
        candidates.append(home.appendingPathComponent("Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application Support/co.noteplan.NotePlan-setapp/Notes", isDirectory: true))
        candidates.append(home.appendingPathComponent("Library/Containers/co.noteplan.NotePlan/Data/Library/Application Support/co.noteplan.NotePlan/Notes", isDirectory: true))

        var seen = Set<String>()
        return candidates.compactMap { url in
            let standardized = url.standardizedFileURL
            let path = normalizedPath(standardized)
            guard seen.insert(path).inserted else {
                return nil
            }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            return standardized
        }
    }

    private static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path.precomposedStringWithCanonicalMapping
    }

    private static func appleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
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

    private static func sanitizedAppName(_ value: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:")
        let cleaned = value
            .components(separatedBy: illegal)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
        return cleaned.isEmpty ? "NotePlan Shortcut" : cleaned
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
