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
    static let autoSaveKey = "autoSave"
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
    static let shortcutSlotCount = 20
    static let currentShortcutLayoutVersion = 3

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

    static var autoSave: Bool {
        if UserDefaults.standard.object(forKey: autoSaveKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: autoSaveKey)
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
        let value = UserDefaults.standard.string(forKey: serviceNameKey) ?? "-> Today"
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-> Today" : trimmed
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
            UInt32(kVK_ANSI_6), UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9), UInt32(kVK_ANSI_0),
            UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4), UInt32(kVK_F5),
            UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8), UInt32(kVK_F9), UInt32(kVK_F10)
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

        for index in 1...min(shortcutSlotCount, legacyCodes.count, newCodes.count) {
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

struct CaptureSource {
    var url: String
    var title: String?
}

struct LLMURLMetadata {
    let title: String
    let tags: [String]
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
            return LLMURLMetadata(
                title: rule.title?.fallback ?? fallbackTitle(for: canonicalHost),
                tags: normalizedRuleTags(rule.tags ?? [])
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

struct PromptLibraryFile: Codable {
    var version: Int
    var prompts: [PromptTemplate]
}

struct PromptTemplate: Codable {
    var id: String
    var enabled: Bool
    var title: String
    var apps: [String]?
    var bundleIds: [String]?
    var domains: [String]?
    var tags: [String]?
    var template: String
}

private enum PromptLibraryStore {
    static let fileName = "prompts.json"
    static let docName = "prompts.md"

    static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NoteDroopy", isDirectory: true)
    }

    static var promptsURL: URL { supportDirectory.appendingPathComponent(fileName) }
    static var docURL: URL { supportDirectory.appendingPathComponent(docName) }

    static func ensureFiles() {
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: promptsURL.path) {
            let bundled = Bundle.main.url(forResource: "prompts", withExtension: "json")
            let content = bundled.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? defaultPromptsJSON
            try? content.write(to: promptsURL, atomically: true, encoding: .utf8)
        }
        if !FileManager.default.fileExists(atPath: docURL.path) {
            let bundled = Bundle.main.url(forResource: "prompts", withExtension: "md")
            let content = bundled.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? defaultPromptsDocumentation
            try? content.write(to: docURL, atomically: true, encoding: .utf8)
        }
    }

    static func activePrompts() -> [PromptTemplate] {
        ensureFiles()
        guard let data = try? Data(contentsOf: promptsURL),
              let file = try? JSONDecoder().decode(PromptLibraryFile.self, from: data) else {
            return defaultPrompts()
        }
        return file.prompts.filter { $0.enabled && !$0.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func validate(data: Data) throws {
        _ = try JSONDecoder().decode(PromptLibraryFile.self, from: data)
    }

    private static func defaultPrompts() -> [PromptTemplate] {
        guard let data = defaultPromptsJSON.data(using: .utf8),
              let file = try? JSONDecoder().decode(PromptLibraryFile.self, from: data) else {
            return []
        }
        return file.prompts.filter { $0.enabled }
    }

    static let defaultPromptsJSON = """
    {
      "version": 1,
      "prompts": [
        {
          "id": "llm-resume-source",
          "enabled": true,
          "title": "Resumer la source",
          "apps": ["ChatGPT", "Claude", "Codex", "Perplexity"],
          "domains": ["chatgpt.com", "claude.ai", "perplexity.ai"],
          "tags": ["#LLM", "#prompt"],
          "template": "Resumer cette source en 5 points.\\\\n\\\\nURL : $url\\\\nTitre : $title\\\\nApp : $app\\\\n\\\\nSelection :\\\\n$selection"
        },
        {
          "id": "llm-action-noteplan",
          "enabled": true,
          "title": "Transformer en actions NotePlan",
          "apps": ["ChatGPT", "Claude", "Codex", "Perplexity"],
          "tags": ["#LLM", "#action"],
          "template": "Transforme ce contenu en taches NotePlan courtes, sans commentaire.\\\\n\\\\nSource : $source\\\\nDate : $date $time\\\\n\\\\nContenu :\\\\n$selection"
        }
      ]
    }
    """

    static let defaultPromptsDocumentation = """
    # NoteDroopy prompts.json

    JSON actif : `~/Library/Application Support/NoteDroopy/prompts.json`

    Champs utiles :
    - `id` : identifiant stable.
    - `enabled` : active/desactive le prompt.
    - `title` : nom affiche.
    - `apps`, `bundleIds`, `domains` : contexte indicatif.
    - `tags` : tags ajoutes a la ligne NotePlan.
    - `template` : texte du prompt.

    Variables : `$date`, `$day`, `$time`, `$datetime`, `$month`, `$year`, `$app`, `$bundleId`, `$url`, `$title`, `$source`, `$selection`.
    """
}

struct PreferencesFile: Codable {
    var version: Int
    var openNote: Bool
    var autoSave: Bool?
    var includeSource: Bool?
    var includeDocumentSource: Bool?
    var serviceName: String
    var defaultTags: String
    var notesRootPath: String?
    var shortcuts: [ShortcutSlotFile]

    static func current() -> PreferencesFile {
        PreferencesFile(
            version: 1,
            openNote: Settings.openNote,
            autoSave: Settings.autoSave,
            includeSource: Settings.includeSource,
            includeDocumentSource: Settings.includeDocumentSource,
            serviceName: Settings.serviceName,
            defaultTags: Settings.taskTag,
            notesRootPath: Settings.notesRootPath,
            shortcuts: Settings.allShortcutSlots().map(ShortcutSlotFile.init(slot:))
        )
    }

    func apply() {
        UserDefaults.standard.set(openNote, forKey: Settings.openNoteKey)
        UserDefaults.standard.set(autoSave ?? true, forKey: Settings.autoSaveKey)
        UserDefaults.standard.set(includeSource ?? true, forKey: Settings.includeSourceKey)
        UserDefaults.standard.set(includeDocumentSource ?? false, forKey: Settings.includeDocumentSourceKey)
        UserDefaults.standard.set(serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-> Today" : serviceName, forKey: Settings.serviceNameKey)
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

private enum CaptureSectionPosition {
    case sectionTop
    case sectionBottom
    case beforeSection
    case afterSection
}

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
        .filter { !$0.hasPrefix("!") && !$0.hasPrefix("$") }
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

private func coloredVariableHelp(_ text: String) -> NSAttributedString {
    let attributed = NSMutableAttributedString(
        string: text,
        attributes: [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
        ]
    )
    let nsText = text as NSString
    let regex = try? NSRegularExpression(pattern: #"\$[A-Za-z][A-Za-z0-9_]*"#)
    regex?.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
        guard let range = match?.range else { return }
        attributed.addAttributes([
            .foregroundColor: NSColor.systemBlue,
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
        ], range: range)
    }
    return attributed
}

private func tokenLegend(_ text: String, _ color: NSColor) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 13, weight: .bold)
    label.textColor = color
    label.drawsBackground = true
    label.backgroundColor = color.withAlphaComponent(0.16)
    label.alignment = .center
    label.wantsLayer = true
    label.layer?.cornerRadius = 5
    label.translatesAutoresizingMaskIntoConstraints = false
    label.widthAnchor.constraint(equalToConstant: 104).isActive = true
    return label
}

private func styleConfigField(_ field: NSTextField) {
    styleFillableField(field)
    field.wantsLayer = true
    field.layer?.borderWidth = 1
    field.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.35).cgColor
    field.layer?.cornerRadius = 5
}

private func applyTagsConfigColors(to field: NSTextField) {
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

struct ShortcutConflict {
    let title: String
    let detail: String
}

private func registerHotKeyProbe(_ combo: KeyCombo) -> OSStatus {
    var ref: EventHotKeyRef?
    let hotKeyID = EventHotKeyID(signature: fourCharCode("NDPR"), id: 9999)
    let status = RegisterEventHotKey(
        combo.keyCode,
        combo.carbonModifiers,
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &ref
    )
    if let ref {
        UnregisterEventHotKey(ref)
    }
    return status
}

final class ShortcutRecorderButton: NSButton {
    fileprivate var onChange: ((KeyCombo) -> Void)?
    fileprivate var onValidate: ((KeyCombo) -> ShortcutConflict?)?
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
        if let conflict = onValidate?(combo) {
            NSSound.beep()
            title = "Déjà pris"
            showShortcutConflictAlert(conflict)
            title = "Tape le nouveau raccourci..."
            window?.makeFirstResponder(self)
            return
        }
        setCombo(combo)
        onChange?(combo)
        stopRecording(updateTitle: false)
    }

    private func showShortcutConflictAlert(_ conflict: ShortcutConflict) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = conflict.title
        alert.informativeText = conflict.detail
        alert.addButton(withTitle: "Choisir un autre raccourci")
        alert.runModal()
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
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.allowsEditingTextAttributes = false
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 2
        detailLabel.isEditable = false
        detailLabel.isSelectable = false
        detailLabel.allowsEditingTextAttributes = false

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

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        shortcutTarget(from: sender.draggingPasteboard) != nil
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

final class ShortcutMakerTabDropView: NSView {
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
        writeDebugLog("shortcut-maker-tab:entered:\(pasteboardDebugDescription(sender.draggingPasteboard))")
        return shortcutTarget(from: sender.draggingPasteboard) == nil
            ? NSDragOperation()
            : preferredDragOperation(from: sender.draggingSourceOperationMask)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        shortcutTarget(from: sender.draggingPasteboard) == nil
            ? NSDragOperation()
            : preferredDragOperation(from: sender.draggingSourceOperationMask)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        shortcutTarget(from: sender.draggingPasteboard) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        writeDebugLog("shortcut-maker-tab:perform:\(pasteboardDebugDescription(sender.draggingPasteboard))")
        guard let target = shortcutTarget(from: sender.draggingPasteboard) else {
            NSSound.beep()
            return false
        }
        return onDropTarget?(target) ?? false
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
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
    var filenames = strings(fromPropertyList: plist)
    // Ajout d'une validation supplémentaire pour éviter les chemins non valides
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

final class ShortcutSlotRow: NSObject, NSTextFieldDelegate {
    let index: Int
    let enabledCheckbox: NSButton
    let recorder: ShortcutRecorderButton
    let outputPopup = ShortcutTargetPopUpButton()
    let enginePopup = ShortcutTargetPopUpButton()
    let destinationPopup = ShortcutTargetPopUpButton()
    let folderField: NSTextField
    let noteField: NSTextField
    let searchButton = NSButton(title: "Rechercher", target: nil, action: nil)
    let targetField = ShortcutTargetField()
    let tagsField: NSTextField
    let advancedButton = NSButton(title: "+", target: nil, action: nil)
    var onSearch: ((ShortcutSlotRow) -> Void)?
    var onTargetDrop: ((ShortcutSlotRow, ShortcutTarget) -> Bool)?
    var onPasteTarget: ((ShortcutSlotRow) -> Void)?
    var onFocus: ((ShortcutSlotRow) -> Void)?
    var onChange: ((ShortcutSlotRow) -> Void)?
    private weak var rowView: NSStackView?
    private var storedCombo: KeyCombo
    private var displayIndex: String { index == 10 ? "0" : "\(index)" }
    private struct OutputOption {
        let title: String
        let engine: ShortcutEngine
        let destination: ShortcutDestination
    }
    private static let outputOptions: [OutputOption] = [
        OutputOption(title: "NotePlan Today", engine: .notePlan, destination: .today),
        OutputOption(title: "NotePlan Note", engine: .notePlan, destination: .notePath),
        OutputOption(title: "Markdown .md", engine: .notePlan, destination: .standard),
        OutputOption(title: "Obsidian .md", engine: .obsidian, destination: .notePath),
        OutputOption(title: "md / txt / ...", engine: .notePlan, destination: .standard)
    ]

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
        Self.outputOptions.forEach { outputPopup.addItem(withTitle: $0.title) }
        outputPopup.selectItem(withTitle: outputTitle(engine: slot.engine, destination: Settings.validDestination(slot.destination, for: slot.index)))
        outputPopup.target = self
        outputPopup.action = #selector(outputChanged)
        [enginePopup, destinationPopup].forEach { (popup: ShortcutTargetPopUpButton) in
            popup.acceptsDrop = true
            popup.onDropTarget = { [weak self] target in
                guard let self else { return false }
                return self.onTargetDrop?(self, target) ?? false
            }
        }
        outputPopup.acceptsDrop = true
        outputPopup.onDropTarget = { [weak self] target in
            guard let self else { return false }
            return self.onTargetDrop?(self, target) ?? false
        }
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
        advancedButton.target = self
        advancedButton.action = #selector(openAdvancedConfig)
        advancedButton.bezelStyle = .rounded
        advancedButton.controlSize = .small
        advancedButton.isBordered = true
        advancedButton.contentTintColor = .systemYellow
        advancedButton.attributedTitle = NSAttributedString(
            string: "+",
            attributes: [
                .foregroundColor: NSColor.systemYellow,
                .font: NSFont.systemFont(ofSize: 13, weight: .bold)
            ]
        )
        [folderField, noteField].forEach(styleFillableField)
        styleConfigField(tagsField)
        refreshTagsConfigDisplay()

        [enabledCheckbox, recorder, outputPopup, enginePopup, destinationPopup, folderField, noteField, searchButton, targetField, tagsField, advancedButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        enabledCheckbox.widthAnchor.constraint(equalToConstant: Self.columnWidths[0]).isActive = true
        recorder.widthAnchor.constraint(equalToConstant: Self.columnWidths[1]).isActive = true
        outputPopup.widthAnchor.constraint(equalToConstant: Self.columnWidths[2]).isActive = true
        targetField.widthAnchor.constraint(equalToConstant: Self.columnWidths[3]).isActive = true
        searchButton.widthAnchor.constraint(equalToConstant: 88).isActive = true
        tagsField.widthAnchor.constraint(equalToConstant: 236).isActive = true
        advancedButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        advancedButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        refreshNoteFieldState()
    }

    static let columnSpacing: CGFloat = 12
    static let columnTitles = ["Actif", "Raccourci", "Sortie", "Cible", "Tag & Config"]
    static let columnWidths: [CGFloat] = [44, 92, 174, 330, 290]

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

    func setEngine(_ engine: ShortcutEngine) {
        enginePopup.selectItem(withTitle: engine.title)
        outputPopup.selectItem(withTitle: outputTitle(engine: engine, destination: selectedDestination()))
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
        let outputStack = ShortcutSlotDropStack()
        outputStack.orientation = .horizontal
        outputStack.spacing = 0
        outputStack.alignment = .centerY
        outputStack.acceptsDrop = true
        outputStack.onDropTarget = { [weak self] target in
            guard let self else { return false }
            return self.onTargetDrop?(self, target) ?? false
        }
        outputStack.translatesAutoresizingMaskIntoConstraints = false
        outputStack.widthAnchor.constraint(equalToConstant: Self.columnWidths[2]).isActive = true
        outputStack.addArrangedSubview(outputPopup)
        row.addArrangedSubview(enabledCheckbox)
        row.addArrangedSubview(recorder)
        row.addArrangedSubview(outputStack)
        row.addArrangedSubview(targetField)
        let configStack = NSStackView()
        configStack.orientation = .horizontal
        configStack.spacing = 6
        configStack.alignment = .centerY
        configStack.translatesAutoresizingMaskIntoConstraints = false
        configStack.widthAnchor.constraint(equalToConstant: Self.columnWidths[3]).isActive = true
        configStack.addArrangedSubview(tagsField)
        configStack.addArrangedSubview(advancedButton)
        row.addArrangedSubview(configStack)
        return row
    }

    func setActive(_ active: Bool) {
        rowView?.layer?.backgroundColor = active ? NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor : NSColor.clear.cgColor
        tagsField.layer?.borderColor = active ? NSColor.controlAccentColor.cgColor : NSColor.systemBlue.withAlphaComponent(0.35).cgColor
        tagsField.layer?.borderWidth = active ? 1.6 : 1.0
    }

    func applySelectedNote(_ result: NoteSearchResult) {
        destinationPopup.selectItem(withTitle: ShortcutDestination.notePath.title)
        outputPopup.selectItem(withTitle: outputTitle(engine: selectedEngine(), destination: .notePath))
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
        let destination = Settings.validDestination(slot.destination, for: index)
        enabledCheckbox.state = slot.enabled ? .on : .off
        enabledCheckbox.title = displayIndex
        setCombo(slot.combo)
        enginePopup.selectItem(withTitle: slot.engine.title)
        destinationPopup.removeAllItems()
        Settings.destinations(forShortcut: index).forEach { destinationPopup.addItem(withTitle: $0.title) }
        destinationPopup.selectItem(withTitle: destination.title)
        outputPopup.selectItem(withTitle: outputTitle(engine: slot.engine, destination: destination))
        folderField.stringValue = slot.folder
        noteField.stringValue = slot.noteReference
        applyTargetDisplay(targetDisplay(for: destination, folder: slot.folder, note: slot.noteReference))
        tagsField.stringValue = slot.tags
        refreshTagsConfigDisplay()
        noteField.placeholderString = placeholder(for: destination)
        refreshNoteFieldState()
    }

    @objc private func engineChanged() {
        outputPopup.selectItem(withTitle: outputTitle(engine: selectedEngine(), destination: selectedDestination()))
        refreshNoteFieldState()
        rowChanged()
    }

    @objc private func destinationChanged() {
        noteField.placeholderString = placeholder(for: selectedDestination())
        outputPopup.selectItem(withTitle: outputTitle(engine: selectedEngine(), destination: selectedDestination()))
        refreshNoteFieldState()
        rowChanged()
    }

    @objc private func outputChanged() {
        let option = selectedOutputOption()
        outputPopup.selectItem(withTitle: option.title)
        enginePopup.selectItem(withTitle: option.engine.title)
        destinationPopup.selectItem(withTitle: Settings.validDestination(option.destination, for: index).title)
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

    func refreshTagsConfigDisplay() {
        applyTagsConfigColors(to: tagsField)
    }

    @objc private func openAdvancedConfig() {
        let menu = NSMenu(title: "Tag & Config")
        addMenuSection("Tags visibles", to: menu)
        addToken("#capture", color: .systemGreen, to: menu)
        addToken("@contexte", color: .systemOrange, to: menu)
        addMenuSection("Variables", to: menu)
        ["$date", "$day", "$time", "$datetime", "$month", "$year", "$source", "$url", "$file", "$LLM"].forEach {
            addToken($0, color: .systemBlue, to: menu)
        }
        addMenuSection("Options capture", to: menu)
        ["!Open", "!Web", "!NoWeb", "!File", "!NoFile"].forEach {
            addToken($0, color: .systemIndigo, to: menu)
        }
        addMenuSection("Format ligne", to: menu)
        ["!Star", "!Plus", "!Text"].forEach {
            addToken($0, color: .systemIndigo, to: menu)
        }
        addMenuSection("Priorité NotePlan", to: menu)
        ["!", "!!", "!!!", "!!!!", "!!!!!"].forEach {
            addToken($0, color: .systemRed, to: menu)
        }
        addMenuSection("Date NotePlan", to: menu)
        ["!Demain", "!Weekend", "!SemainePro", "!MoisProchain", "!Dans6Mois"].forEach {
            addToken($0, color: .systemPink, to: menu)
        }
        addMenuSection("Section NotePlan", to: menu)
        let sectionItem = NSMenuItem(title: "$section(...)", action: #selector(addSectionToken), keyEquivalent: "")
        sectionItem.target = self
        sectionItem.attributedTitle = NSAttributedString(
            string: "$section(...)",
            attributes: [
                .foregroundColor: NSColor.systemBlue,
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
            ]
        )
        menu.addItem(sectionItem)
        ["!SectionTop", "!SectionBottom", "!BeforeSection", "!AfterSection"].forEach {
            addToken($0, color: .systemPink, to: menu)
        }
        menu.addItem(.separator())
        let clearItem = NSMenuItem(title: "Effacer Tag & Config", action: #selector(clearTagsConfig), keyEquivalent: "")
        clearItem.target = self
        clearItem.attributedTitle = NSAttributedString(
            string: clearItem.title,
            attributes: [
                .foregroundColor: NSColor.systemRed,
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
            ]
        )
        menu.addItem(clearItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: advancedButton.bounds.height + 4), in: advancedButton)
    }

    private func addMenuSection(_ title: String, to menu: NSMenu) {
        if menu.items.isEmpty == false {
            menu.addItem(.separator())
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 12, weight: .bold)
            ]
        )
        menu.addItem(item)
    }

    private func addToken(_ token: String, color: NSColor, to menu: NSMenu) {
        let item = NSMenuItem(title: token, action: #selector(addConfigToken(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = token
        item.attributedTitle = NSAttributedString(
            string: token,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
            ]
        )
        menu.addItem(item)
    }

    @objc private func addConfigToken(_ sender: NSMenuItem) {
        guard let token = sender.representedObject as? String else { return }
        let existing = tagsField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if existing.contains(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) {
            refreshTagsConfigDisplay()
            return
        }
        tagsField.stringValue = (existing + [token]).joined(separator: ", ")
        refreshTagsConfigDisplay()
        rowChanged()
    }

    @objc private func addSectionToken() {
        let alert = NSAlert()
        alert.messageText = "Section NotePlan"
        alert.informativeText = "Nom du titre sous lequel insérer la capture."
        alert.addButton(withTitle: "Ajouter")
        alert.addButton(withTitle: "Annuler")
        let field = NSTextField(string: "")
        field.placeholderString = "Notes et idées"
        field.frame = NSRect(x: 0, y: 0, width: 360, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let section = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !section.isEmpty else { return }
        let token = "$section(\(section))"
        let existing = tagsField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.lowercased().hasPrefix("$section(") }
        tagsField.stringValue = (existing + [token]).joined(separator: ", ")
        refreshTagsConfigDisplay()
        rowChanged()
    }

    @objc private func clearTagsConfig() {
        tagsField.stringValue = ""
        refreshTagsConfigDisplay()
        rowChanged()
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        if let field = obj.object as? NSTextField,
           field === targetField || field === tagsField || field === noteField || field === folderField {
            onFocus?(self)
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === tagsField {
            refreshTagsConfigDisplay()
        }
        if field === targetField || field === tagsField || field === noteField || field === folderField {
            onFocus?(self)
        }
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

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === targetField, commandSelector == #selector(NSText.paste(_:)) else {
            return false
        }
        onPasteTarget?(self)
        return true
    }

    private func selectedEngine() -> ShortcutEngine {
        selectedOutputOption().engine
    }

    private func selectedDestination() -> ShortcutDestination {
        Settings.validDestination(selectedOutputOption().destination, for: index)
    }

    private func selectedOutputOption() -> OutputOption {
        let selectedTitle = outputPopup.titleOfSelectedItem ?? ""
        if let option = Self.outputOptions.first(where: { $0.title == selectedTitle }) {
            let validDestination = Settings.validDestination(option.destination, for: index)
            if validDestination == option.destination {
                return option
            }
            return OutputOption(title: outputTitle(engine: option.engine, destination: validDestination), engine: option.engine, destination: validDestination)
        }
        let fallbackEngine = ShortcutEngine.allCases.first { $0.title == enginePopup.titleOfSelectedItem } ?? .notePlan
        let fallbackDestination = ShortcutDestination.allCases.first { $0.title == destinationPopup.titleOfSelectedItem } ?? (index == 1 ? .today : .standard)
        let validDestination = Settings.validDestination(fallbackDestination, for: index)
        return OutputOption(title: outputTitle(engine: fallbackEngine, destination: validDestination), engine: fallbackEngine, destination: validDestination)
    }

    private func outputTitle(engine: ShortcutEngine, destination: ShortcutDestination) -> String {
        if engine == .obsidian { return "Obsidian .md" }
        switch Settings.validDestination(destination, for: index) {
        case .today:
            return "NotePlan Today"
        case .noteTitle, .notePath:
            return "NotePlan Note"
        case .standard:
            return "Markdown .md"
        }
    }

    private func refreshNoteFieldState() {
        let engine = selectedEngine()
        let destination = selectedDestination()
        let acceptsTarget = engine == .obsidian || destination.acceptsTarget
        destinationPopup.isEnabled = engine == .notePlan
        folderField.isEnabled = acceptsTarget
        noteField.isEnabled = acceptsTarget
        targetField.isEditable = true
        targetField.isSelectable = true
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

final class SettingsWindowController: NSWindowController, NSTabViewDelegate {
    private let serviceNameField = NSTextField(string: Settings.serviceName)
    private let tagField = NSTextField(string: Settings.taskTag)
    private let notesRootField = NSTextField(string: Settings.notesRootPath)
    private let chooseNotesRootButton = NSButton(title: "Choisir dossier Notes", target: nil, action: nil)
    private let openNoteCheckbox = NSButton(checkboxWithTitle: "Ouvrir NotePlan", target: nil, action: nil)
    private let autoSaveCheckbox = NSButton(checkboxWithTitle: "Auto save", target: nil, action: nil)
    private let shortcutAutoSaveCheckbox = NSButton(checkboxWithTitle: "Auto save", target: nil, action: nil)
    private let includeSourceCheckbox = NSButton(checkboxWithTitle: "Ajouter le lien", target: nil, action: nil)
    private let includeDocumentSourceCheckbox = NSButton(checkboxWithTitle: "Ajouter le doc (titre + lien fichier)", target: nil, action: nil)
    private var shortcutRows: [ShortcutSlotRow] = []
    private let shortcutHelpLabel = NSTextField(labelWithString: "Ligne 1 par défaut : NotePlan + Aujourd'hui (NotePlan). Sinon choisir Standard, déposer depuis Finder une note .md, ou coller un lien NotePlan.")
    private let variablesHelpLabel = NSTextField(labelWithString: "Variables : $date, $day, $time, $datetime, $month, $year")
    private let helpButton = NSButton(title: "Aide", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Autoriser Accessibilité", target: nil, action: nil)
    private let exportButton = NSButton(title: "Exporter JSON", target: nil, action: nil)
    private let importButton = NSButton(title: "Importer JSON", target: nil, action: nil)
    private let captureRulesButton = NSButton(title: "Règles capture", target: nil, action: nil)
    private let captureRulesHelpButton = NSButton(title: "Doc formats", target: nil, action: nil)
    private let promptsButton = NSButton(title: "Prompts JSON", target: nil, action: nil)
    private let promptsHelpButton = NSButton(title: "Doc prompts", target: nil, action: nil)
    private let reloadPromptsButton = NSButton(title: "Recharger prompts", target: nil, action: nil)
    private let sourceWebPopup = NSPopUpButton()
    private let sourceFilePopup = NSPopUpButton()
    private let addConfigButton = NSButton(title: "Ajouter tokens", target: nil, action: nil)
    private let replaceConfigButton = NSButton(title: "Réappliquer", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "Enregistrer", target: nil, action: nil)
    private let shortcutMakerNoteField = NSTextField(labelWithString: "")
    private let shortcutMakerDestinationField = NSTextField(labelWithString: "")
    private let shortcutMakerDropView = ShortcutMakerDropView()
    private let shortcutMakerRecentTextView = NSTextView()
    private let nc2Controller = NotePlanEditorWindowController()
    private var generatedShortcutURL: URL?
    private weak var activeTagConfigRow: ShortcutSlotRow?
    private let shortcutMakerNotePathKey = "noteplanShortcutMaker.notePath"
    private let shortcutMakerNoteURLKey = "noteplanShortcutMaker.noteURL"
    private let shortcutMakerNoteDisplayKey = "noteplanShortcutMaker.noteDisplay"
    private let shortcutMakerDestinationPathKey = "noteplanShortcutMaker.destinationPath"
    private let shortcutMakerRecentShortcutsKey = "noteplanShortcutMaker.recentShortcuts"
    private var hasPendingChanges = false
    private var pasteMonitor: Any?
    private weak var preferencesTabView: NSTabView?

    convenience init() {
        let window = centeredWindow("Note Droopy — Préférences", width: 1220, height: 860, style: [.titled, .closable, .miniaturizable, .resizable])
        window.minSize = NSSize(width: 1220, height: 860)
        window.setContentSize(NSSize(width: 1220, height: 860))
        self.init(window: window)
        buildContent()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.delegate = self
        preferencesTabView = tabView
        contentView.addSubview(tabView)

        let settingsContainer = NSView()
        let settingsTab = NSTabViewItem(identifier: "settings")
        settingsTab.label = "Capture"
        settingsTab.view = settingsContainer
        tabView.addTabViewItem(settingsTab)

        let shortcutTabContainer = NSView()
        let shortcutMakerTab = NSTabViewItem(identifier: "shortcutMaker")
        shortcutMakerTab.label = "Raccourcis"
        shortcutMakerTab.view = shortcutTabContainer
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

        let settingsScrollView = NSScrollView()
        settingsScrollView.translatesAutoresizingMaskIntoConstraints = false
        settingsScrollView.hasVerticalScroller = true
        settingsScrollView.hasHorizontalScroller = false
        settingsScrollView.autohidesScrollers = false
        settingsScrollView.drawsBackground = false
        settingsScrollView.borderType = .noBorder
        settingsContainer.addSubview(settingsScrollView)

        let settingsDocument = FlippedView()
        settingsDocument.translatesAutoresizingMaskIntoConstraints = false
        settingsScrollView.documentView = settingsDocument

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        settingsDocument.addSubview(stack)

        let title = NSTextField(labelWithString: "Note Droopy")
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

        serviceNameField.placeholderString = "-> Today"
        serviceNameField.lineBreakMode = .byTruncatingTail

        tagField.placeholderString = "#capture"

        notesRootField.placeholderString = "Choisir le dossier Notes pour activer la recherche"
        notesRootField.isEditable = false
        notesRootField.isSelectable = true
        notesRootField.lineBreakMode = .byTruncatingMiddle

        chooseNotesRootButton.target = self
        chooseNotesRootButton.action = #selector(chooseNotesRoot)
        chooseNotesRootButton.bezelStyle = .rounded

        openNoteCheckbox.state = Settings.openNote ? .on : .off
        autoSaveCheckbox.state = Settings.autoSave ? .on : .off
        includeSourceCheckbox.state = Settings.includeSource ? .on : .off
        includeDocumentSourceCheckbox.state = Settings.includeDocumentSource ? .on : .off
        [openNoteCheckbox, autoSaveCheckbox, includeSourceCheckbox, includeDocumentSourceCheckbox].forEach { checkbox in
            checkbox.target = self
            checkbox.action = #selector(autosaveSettingsFromControl(_:))
        }
        shortcutHelpLabel.textColor = .secondaryLabelColor
        shortcutHelpLabel.lineBreakMode = .byWordWrapping
        shortcutHelpLabel.maximumNumberOfLines = 2
        variablesHelpLabel.attributedStringValue = coloredVariableHelp("Variables : $date, $day, $time, $datetime, $month, $year")
        variablesHelpLabel.lineBreakMode = .byWordWrapping
        variablesHelpLabel.maximumNumberOfLines = 1

        [sourceWebPopup, sourceFilePopup].forEach { popup in
            popup.addItems(withTitles: ["Global", "Oui", "Non"])
            popup.selectItem(withTitle: "Global")
            popup.toolTip = "Global = réglage général, Oui/Non ajoute un token dans Tag & Config"
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.widthAnchor.constraint(equalToConstant: 110).isActive = true
        }
        addConfigButton.target = self
        addConfigButton.action = #selector(addConfigTokens)
        addConfigButton.bezelStyle = .rounded
        replaceConfigButton.target = self
        replaceConfigButton.action = #selector(replaceConfigTokens)
        replaceConfigButton.bezelStyle = .rounded

        let optionsRow = horizontalRow(spacing: 12)
        optionsRow.addArrangedSubview(formLabel("Options -> Tags", width: 128))
        optionsRow.addArrangedSubview(formLabel("Source web", width: 92))
        optionsRow.addArrangedSubview(sourceWebPopup)
        optionsRow.addArrangedSubview(formLabel("Source fichier", width: 112))
        optionsRow.addArrangedSubview(sourceFilePopup)
        optionsRow.addArrangedSubview(addConfigButton)
        optionsRow.addArrangedSubview(replaceConfigButton)

        let colorsRow = horizontalRow(spacing: 10)
        colorsRow.addArrangedSubview(formLabel("Couleurs", width: 128))
        colorsRow.addArrangedSubview(tokenLegend("#tag", .systemGreen))
        colorsRow.addArrangedSubview(tokenLegend("$variable", .systemBlue))
        colorsRow.addArrangedSubview(tokenLegend("!config", .systemIndigo))
        colorsRow.addArrangedSubview(tokenLegend("@contexte", .systemOrange))

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

        promptsButton.target = self
        promptsButton.action = #selector(openPromptsJSON)
        promptsButton.bezelStyle = .rounded

        promptsHelpButton.target = self
        promptsHelpButton.action = #selector(openPromptsHelp)
        promptsHelpButton.bezelStyle = .rounded

        reloadPromptsButton.target = self
        reloadPromptsButton.action = #selector(reloadPromptsJSON)
        reloadPromptsButton.bezelStyle = .rounded

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
        buttons.addArrangedSubview(promptsButton)
        buttons.addArrangedSubview(promptsHelpButton)
        buttons.addArrangedSubview(reloadPromptsButton)
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

        let shortcutsContainer = NSStackView()
        shortcutsContainer.orientation = .vertical
        shortcutsContainer.spacing = 6
        shortcutsContainer.alignment = .leading
        shortcutsContainer.addArrangedSubview(ShortcutSlotRow.headerView())

        let shortcutsScrollView = NSScrollView()
        shortcutsScrollView.translatesAutoresizingMaskIntoConstraints = false
        shortcutsScrollView.hasVerticalScroller = true
        shortcutsScrollView.hasHorizontalScroller = false
        shortcutsScrollView.autohidesScrollers = false
        shortcutsScrollView.drawsBackground = false
        shortcutsScrollView.borderType = .noBorder

        let shortcutsDocument = FlippedView()
        shortcutsDocument.translatesAutoresizingMaskIntoConstraints = false
        shortcutsScrollView.documentView = shortcutsDocument

        let slotsStack = NSStackView()
        slotsStack.orientation = .vertical
        slotsStack.spacing = 8
        slotsStack.alignment = .leading
        slotsStack.translatesAutoresizingMaskIntoConstraints = false
        shortcutsDocument.addSubview(slotsStack)
        shortcutsContainer.addArrangedSubview(shortcutsScrollView)

        NSLayoutConstraint.activate([
            shortcutsScrollView.widthAnchor.constraint(equalToConstant: 1012),
            shortcutsScrollView.heightAnchor.constraint(equalToConstant: 238),
            shortcutsDocument.widthAnchor.constraint(equalTo: shortcutsScrollView.contentView.widthAnchor),
            slotsStack.leadingAnchor.constraint(equalTo: shortcutsDocument.leadingAnchor),
            slotsStack.trailingAnchor.constraint(lessThanOrEqualTo: shortcutsDocument.trailingAnchor),
            slotsStack.topAnchor.constraint(equalTo: shortcutsDocument.topAnchor),
            slotsStack.bottomAnchor.constraint(equalTo: shortcutsDocument.bottomAnchor)
        ])

        let shortcutTabScrollView = NSScrollView()
        shortcutTabScrollView.translatesAutoresizingMaskIntoConstraints = false
        shortcutTabScrollView.hasVerticalScroller = true
        shortcutTabScrollView.hasHorizontalScroller = false
        shortcutTabScrollView.autohidesScrollers = false
        shortcutTabScrollView.drawsBackground = false
        shortcutTabScrollView.borderType = .noBorder
        shortcutTabContainer.addSubview(shortcutTabScrollView)

        let shortcutTabDocument = FlippedView()
        shortcutTabDocument.translatesAutoresizingMaskIntoConstraints = false
        shortcutTabScrollView.documentView = shortcutTabDocument

        let shortcutTabStack = NSStackView()
        shortcutTabStack.orientation = .vertical
        shortcutTabStack.alignment = .leading
        shortcutTabStack.spacing = 12
        shortcutTabStack.translatesAutoresizingMaskIntoConstraints = false
        shortcutTabDocument.addSubview(shortcutTabStack)

        shortcutRows = Settings.allShortcutSlots().map { slot in
            let row = ShortcutSlotRow(slot: slot)
            row.recorder.onValidate = { [weak self, weak row] combo in
                guard let self, let row else { return nil }
                return self.shortcutConflict(for: combo, editedRow: row)
            }
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
            row.onFocus = { [weak self] row in
                self?.setActiveTagConfigRow(row)
            }
            row.onChange = { [weak self] _ in
                self?.autosaveSettings(message: "Réglages enregistrés.")
            }
            slotsStack.addArrangedSubview(row.view())
            return row
        }

        stack.addArrangedSubview(titleStack)
        stack.addArrangedSubview(variablesHelpLabel)
        stack.addArrangedSubview(optionsRow)
        stack.addArrangedSubview(colorsRow)
        stack.addArrangedSubview(shortcutsContainer)
        stack.addArrangedSubview(statusLabel)

        shortcutTabStack.addArrangedSubview(shortcutMakerTabView())

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            settingsScrollView.leadingAnchor.constraint(equalTo: settingsContainer.leadingAnchor),
            settingsScrollView.trailingAnchor.constraint(equalTo: settingsContainer.trailingAnchor),
            settingsScrollView.topAnchor.constraint(equalTo: settingsContainer.topAnchor),
            settingsScrollView.bottomAnchor.constraint(equalTo: settingsContainer.bottomAnchor),

            settingsDocument.widthAnchor.constraint(equalTo: settingsScrollView.contentView.widthAnchor),

            stack.leadingAnchor.constraint(equalTo: settingsDocument.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: settingsDocument.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: settingsDocument.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: settingsDocument.bottomAnchor, constant: -12),

            shortcutTabScrollView.leadingAnchor.constraint(equalTo: shortcutTabContainer.leadingAnchor),
            shortcutTabScrollView.trailingAnchor.constraint(equalTo: shortcutTabContainer.trailingAnchor),
            shortcutTabScrollView.topAnchor.constraint(equalTo: shortcutTabContainer.topAnchor),
            shortcutTabScrollView.bottomAnchor.constraint(equalTo: shortcutTabContainer.bottomAnchor),

            shortcutTabDocument.widthAnchor.constraint(equalTo: shortcutTabScrollView.contentView.widthAnchor),

            shortcutTabStack.leadingAnchor.constraint(equalTo: shortcutTabDocument.leadingAnchor, constant: 12),
            shortcutTabStack.trailingAnchor.constraint(lessThanOrEqualTo: shortcutTabDocument.trailingAnchor, constant: -12),
            shortcutTabStack.topAnchor.constraint(equalTo: shortcutTabDocument.topAnchor, constant: 12),
            shortcutTabStack.bottomAnchor.constraint(equalTo: shortcutTabDocument.bottomAnchor, constant: -12)
        ])
        contentView.layoutSubtreeIfNeeded()
        let fitting = stack.fittingSize
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let contentSize = NSSize(
            width: max(1220, min(fitting.width + 72, screenFrame.width - 80)),
            height: max(760, min(860, screenFrame.height - 80))
        )
        window?.setContentSize(contentSize)
        window?.minSize = NSSize(width: 1100, height: 720)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .settingsDidChange,
            object: nil
        )
        refreshAccessibilityStatus()
        markPendingChanges(false)
        installPasteMonitorIfNeeded()
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        switch tabViewItem?.identifier as? String {
        case "nc2":
            nc2Controller.activateEmbeddedSort()
        default:
            window?.title = "Note Droopy — Préférences"
        }
    }

    func selectPreferencesTab(_ identifier: String) {
        showWindow(nil)
        guard let tabView = preferencesTabView,
              let item = tabView.tabViewItems.first(where: { ($0.identifier as? String) == identifier }) else {
            return
        }
        tabView.selectTabViewItem(item)
        NSApp.activate(ignoringOtherApps: true)
    }

    func savePreferencesFromMenu() {
        saveSettings()
    }

    func exportPreferencesFromMenu() {
        exportPreferencesJSON()
    }

    func importPreferencesFromMenu() {
        importPreferencesJSON()
    }

    func openCaptureRulesFromMenu() {
        openCaptureRulesJSON()
    }

    func openCaptureRulesHelpFromMenu() {
        openCaptureRulesHelp()
    }

    func openPromptsFromMenu() {
        openPromptsJSON()
    }

    func openPromptsHelpFromMenu() {
        openPromptsHelp()
    }

    func reloadPromptsFromMenu() {
        reloadPromptsJSON()
    }

    func openAccessibilityFromMenu() {
        openAccessibilitySettings()
    }

    func editServiceNameFromMenu() {
        guard let value = promptPreferenceValue(
            title: "Nom du Service",
            message: "Nom affiché dans le menu Services macOS.",
            currentValue: serviceNameField.stringValue
        ) else { return }
        serviceNameField.stringValue = value
        saveSettings()
    }

    func editServiceTagFromMenu() {
        guard let value = promptPreferenceValue(
            title: "Tag de la tâche via service",
            message: "Tags ajoutés aux captures envoyées par le Service macOS.",
            currentValue: tagField.stringValue
        ) else { return }
        tagField.stringValue = value
        saveSettings()
    }

    func chooseNotesRootFromMenu() {
        chooseNotesRoot()
        autosaveSettings(message: "Dossier Notes enregistré.")
    }

    func toggleOpenNoteFromMenu() {
        openNoteCheckbox.state = openNoteCheckbox.state == .on ? .off : .on
        autosaveSettings(message: "Option Ouvrir NotePlan mise à jour.")
    }

    func toggleAutoSaveFromMenu() {
        autoSaveCheckbox.state = autoSaveCheckbox.state == .on ? .off : .on
        shortcutAutoSaveCheckbox.state = autoSaveCheckbox.state
        autosaveSettings(message: "Auto save mis à jour.")
    }

    func toggleIncludeSourceFromMenu() {
        includeSourceCheckbox.state = includeSourceCheckbox.state == .on ? .off : .on
        autosaveSettings(message: "Option Ajouter le lien mise à jour.")
    }

    func toggleIncludeDocumentSourceFromMenu() {
        includeDocumentSourceCheckbox.state = includeDocumentSourceCheckbox.state == .on ? .off : .on
        autosaveSettings(message: "Option Ajouter le doc mise à jour.")
    }

    func resetSlot1ToTodayFromMenu() {
        var slot = Settings.shortcutSlot(1)
        slot.enabled = true
        slot.engine = .notePlan
        slot.destination = .today
        slot.folder = ""
        slot.noteReference = ""
        Settings.setShortcutSlot(slot)
        shortcutRows.first(where: { $0.index == 1 })?.apply(slot: slot)
        autosaveSettings(message: "Ligne 1 configurée sur NotePlan Today.")
    }

    private func shortcutConflict(for combo: KeyCombo, editedRow: ShortcutSlotRow) -> ShortcutConflict? {
        if let duplicate = shortcutRows.first(where: {
            $0.index != editedRow.index &&
            $0.slot.enabled &&
            $0.slot.combo.keyCode == combo.keyCode &&
            $0.slot.combo.carbonModifiers == combo.carbonModifiers
        }) {
            return ShortcutConflict(
                title: "Raccourci déjà utilisé",
                detail: "\(combo.display) est déjà utilisé par Note Droopy, ligne \(duplicate.index)."
            )
        }

        let status = registerHotKeyProbe(combo)
        guard status != noErr else { return nil }
        return ShortcutConflict(
            title: "Raccourci déjà pris",
            detail: "\(combo.display) est refusé par macOS. Il est probablement utilisé par macOS ou une autre app. macOS ne fournit pas le nom de l'app propriétaire via cette API. Code: \(status)."
        )
    }

    func chooseShortcutMakerNoteFromMenu() {
        chooseShortcutMakerNote()
    }

    func chooseShortcutMakerDestinationFromMenu() {
        chooseShortcutMakerDestination()
    }

    func generateShortcutMakerAppFromMenu() {
        generateShortcutMakerApp()
    }

    func revealShortcutMakerAppFromMenu() {
        revealShortcutMakerApp()
    }

    func showShortcutMakerRecentsFromMenu() {
        refreshShortcutMakerFields()
        let recent = shortcutMakerRecentShortcuts()
        let alert = NSAlert()
        alert.messageText = "Derniers raccourcis créés"
        alert.informativeText = recent.isEmpty ? "Aucun raccourci créé." : recent.map { "• \($0)" }.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func chooseCommanderRootFromMenu() {
        nc2Controller.chooseRootFromMenu()
    }

    func applyCommanderRootFromMenu() {
        nc2Controller.applyRootFromMenu()
    }

    func showCommanderFunctionsFromMenu() {
        nc2Controller.showFunctionsFromMenu()
    }

    private func promptPreferenceValue(title: String, message: String, currentValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Appliquer")
        alert.addButton(withTitle: "Annuler")

        let field = NSTextField(string: currentValue)
        field.frame = NSRect(x: 0, y: 0, width: 420, height: 24)
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let container = ShortcutMakerTabDropView()
        container.onDropTarget = { [weak self] target in
            self?.applyShortcutMakerDrop(target) ?? false
        }
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
        shortcutMakerDropView.translatesAutoresizingMaskIntoConstraints = false
        shortcutMakerDropView.onDropTarget = { [weak self] target in
            self?.applyShortcutMakerDrop(target) ?? false
        }
        shortcutMakerDropView.widthAnchor.constraint(equalToConstant: 760).isActive = true
        refreshShortcutMakerFields()

        let chooseNoteButton = NSButton(title: "Choisir une note .md", target: self, action: #selector(chooseShortcutMakerNote))
        let chooseDestinationButton = NSButton(title: "Choisir destination", target: self, action: #selector(chooseShortcutMakerDestination))
        let generateButton = NSButton(title: "Créer le raccourci .app", target: self, action: #selector(generateShortcutMakerApp))
        let revealButton = NSButton(title: "Révéler le dernier raccourci", target: self, action: #selector(revealShortcutMakerApp))
        let clearButton = NSButton(title: "Nettoyer", target: self, action: #selector(clearShortcutMakerState))
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

        [chooseNoteButton, chooseDestinationButton, generateButton, revealButton, clearButton].forEach { button in
            button.bezelStyle = .rounded
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 260).isActive = true
        }

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(detail)
        stack.addArrangedSubview(shortcutMakerDropView)
        stack.addArrangedSubview(shortcutMakerInfoRow(title: "Note", value: shortcutMakerNoteField))
        stack.addArrangedSubview(chooseNoteButton)
        stack.addArrangedSubview(shortcutMakerInfoRow(title: "Destination", value: shortcutMakerDestinationField))
        stack.addArrangedSubview(chooseDestinationButton)
        stack.addArrangedSubview(generateButton)
        stack.addArrangedSubview(revealButton)
        stack.addArrangedSubview(clearButton)
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

    @objc private func clearShortcutMakerState() {
        UserDefaults.standard.removeObject(forKey: shortcutMakerNotePathKey)
        UserDefaults.standard.removeObject(forKey: shortcutMakerNoteURLKey)
        UserDefaults.standard.removeObject(forKey: shortcutMakerNoteDisplayKey)
        UserDefaults.standard.removeObject(forKey: shortcutMakerRecentShortcutsKey)
        UserDefaults.standard.synchronize()
        generatedShortcutURL = nil
        refreshShortcutMakerFields()
        statusLabel.stringValue = "Raccourcis nettoyés. Dépose une note .md ou choisis une note."
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
                generateShortcutMakerApp()
                return true
            }
            if url.isFileURL, url.pathExtension.lowercased() == "md" {
                setShortcutMakerNote(path: url.standardizedFileURL.path)
                statusLabel.stringValue = "Note choisie : \(url.lastPathComponent)"
                generateShortcutMakerApp()
                return true
            }
        }

        if let text = target.rawText {
            if let notePlanURL = notePlanURLCandidate(from: text) {
                setShortcutMakerNote(notePlanURL: notePlanURL, displayName: shortcutMakerAppName(fromNotePlanURL: notePlanURL))
                statusLabel.stringValue = "NotePlan enregistré : \(shortcutMakerAppName(fromNotePlanURL: notePlanURL))"
                generateShortcutMakerApp()
                return true
            }
            if let path = existingFinderPath(from: text), path.lowercased().hasSuffix(".md") {
                setShortcutMakerNote(path: path)
                statusLabel.stringValue = "Note choisie : \(URL(fileURLWithPath: path).lastPathComponent)"
                generateShortcutMakerApp()
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

    @objc private func generateShortcutMakerApp() {
        let notePath = UserDefaults.standard.string(forKey: shortcutMakerNotePathKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let notePlanURL = UserDefaults.standard.string(forKey: shortcutMakerNoteURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !notePath.isEmpty || !notePlanURL.isEmpty else {
            statusLabel.stringValue = "Aucune note choisie : dépose une note .md ou clique Choisir une note .md."
            NSSound.beep()
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

    private func setActiveTagConfigRow(_ row: ShortcutSlotRow) {
        activeTagConfigRow?.setActive(false)
        activeTagConfigRow = row
        row.setActive(true)
        statusLabel.stringValue = "Ligne \(row.index) sélectionnée pour Tag & Config."
    }

    private func selectedConfigRow() -> ShortcutSlotRow? {
        activeTagConfigRow ?? shortcutRows.first
    }

    private func configTokensFromControls() -> [String] {
        var tokens: [String] = []
        switch sourceWebPopup.titleOfSelectedItem ?? "Global" {
        case "Oui": tokens.append("!Web")
        case "Non": tokens.append("!NoWeb")
        default: break
        }
        switch sourceFilePopup.titleOfSelectedItem ?? "Global" {
        case "Oui": tokens.append("!File")
        case "Non": tokens.append("!NoFile")
        default: break
        }
        return tokens
    }

    @objc private func addConfigTokens() {
        applyConfigTokens(replace: false)
    }

    @objc private func replaceConfigTokens() {
        applyConfigTokens(replace: true)
    }

    private func applyConfigTokens(replace: Bool) {
        guard let row = selectedConfigRow() else {
            statusLabel.stringValue = "Clique d'abord dans une case Tag & Config."
            NSSound.beep()
            return
        }
        setActiveTagConfigRow(row)
        let tokens = configTokensFromControls()
        guard !tokens.isEmpty else {
            statusLabel.stringValue = "Choisis Oui ou Non dans Source web/fichier."
            NSSound.beep()
            return
        }
        var parts = row.tagsField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if replace {
            let replaced = Set(["!Web", "!NoWeb", "!File", "!NoFile"].map { $0.lowercased() })
            parts.removeAll { replaced.contains($0.lowercased()) }
        }
        for token in tokens where !parts.contains(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) {
            parts.append(token)
        }
        row.tagsField.stringValue = parts.joined(separator: ", ")
        row.refreshTagsConfigDisplay()
        autosaveSettings(message: replace ? "Options réappliquées dans Tag & Config ligne \(row.index)." : "Tokens ajoutés dans Tag & Config ligne \(row.index).")
    }

    deinit {
        if let pasteMonitor {
            NSEvent.removeMonitor(pasteMonitor)
        }
        NotificationCenter.default.removeObserver(self)
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
        tell application "Note Droopy" to activate
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

        UserDefaults.standard.set(serviceName.isEmpty ? "-> Today" : serviceName, forKey: Settings.serviceNameKey)
        UserDefaults.standard.set(tag.isEmpty ? "#capture" : tag, forKey: Settings.taskTagKey)
        UserDefaults.standard.set(openNoteCheckbox.state == .on, forKey: Settings.openNoteKey)
        shortcutAutoSaveCheckbox.state = autoSaveCheckbox.state
        UserDefaults.standard.set(autoSaveCheckbox.state == .on, forKey: Settings.autoSaveKey)
        UserDefaults.standard.set(includeSourceCheckbox.state == .on, forKey: Settings.includeSourceKey)
        UserDefaults.standard.set(includeDocumentSourceCheckbox.state == .on, forKey: Settings.includeDocumentSourceKey)
        shortcutRows.forEach { Settings.setShortcutSlot($0.slot) }
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)

        if applyServiceNameToBundle(serviceName.isEmpty ? "-> Today" : serviceName) {
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

    @objc private func openPromptsJSON() {
        PromptLibraryStore.ensureFiles()
        NSWorkspace.shared.open(PromptLibraryStore.promptsURL)
        statusLabel.stringValue = "Prompts : \(PromptLibraryStore.promptsURL.path)"
    }

    @objc private func openPromptsHelp() {
        PromptLibraryStore.ensureFiles()
        NSWorkspace.shared.open(PromptLibraryStore.docURL)
        statusLabel.stringValue = "Doc prompts : \(PromptLibraryStore.docURL.path)"
    }

    @objc private func reloadPromptsJSON() {
        PromptLibraryStore.ensureFiles()
        let count = PromptLibraryStore.activePrompts().count
        statusLabel.stringValue = "\(count) prompt(s) actif(s) charges."
    }

    private func saveCurrentControlsToDefaults() {
        let serviceName = serviceNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = tagField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(serviceName.isEmpty ? "-> Today" : serviceName, forKey: Settings.serviceNameKey)
        UserDefaults.standard.set(tag.isEmpty ? "#capture" : tag, forKey: Settings.taskTagKey)
        UserDefaults.standard.set(openNoteCheckbox.state == .on, forKey: Settings.openNoteKey)
        shortcutAutoSaveCheckbox.state = autoSaveCheckbox.state
        UserDefaults.standard.set(autoSaveCheckbox.state == .on, forKey: Settings.autoSaveKey)
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

    @objc private func autosaveSettingsFromControl(_ sender: Any?) {
        if let checkbox = sender as? NSButton,
           checkbox === autoSaveCheckbox || checkbox === shortcutAutoSaveCheckbox {
            autoSaveCheckbox.state = checkbox.state
            shortcutAutoSaveCheckbox.state = checkbox.state
        }
        autosaveSettings(message: "Réglages enregistrés.")
    }

    @objc private func settingsDidChange() {
        syncAutoSaveCheckboxes()
    }

    private func syncAutoSaveCheckboxes() {
        let state: NSControl.StateValue = Settings.autoSave ? .on : .off
        autoSaveCheckbox.state = state
        shortcutAutoSaveCheckbox.state = state
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
        syncAutoSaveCheckboxes()
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
        CaptureRulesStore.ensureFiles()
        PromptLibraryStore.ensureFiles()
        if !isAccessibilityTrusted(prompt: false) {
            log("accessibility:not-granted")
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
                    self.log("show-settings:normal-launch")
                    self.showSettingsWindow()
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

    @objc func showCapturePreferencesFromMenu(_ sender: Any?) {
        showSettingsWindow(tab: "settings")
    }

    @objc func showShortcutPreferencesFromMenu(_ sender: Any?) {
        showSettingsWindow(tab: "shortcutMaker")
    }

    @objc func showCommanderPreferencesFromMenu(_ sender: Any?) {
        showSettingsWindow(tab: "nc2")
    }

    @objc func savePreferencesFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.savePreferencesFromMenu()
    }

    @objc func exportPreferencesFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.exportPreferencesFromMenu()
    }

    @objc func importPreferencesFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.importPreferencesFromMenu()
    }

    @objc func openCaptureRulesFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.openCaptureRulesFromMenu()
    }

    @objc func openCaptureRulesHelpFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.openCaptureRulesHelpFromMenu()
    }

    @objc func openPromptsFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.openPromptsFromMenu()
    }

    @objc func openPromptsHelpFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.openPromptsHelpFromMenu()
    }

    @objc func reloadPromptsFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.reloadPromptsFromMenu()
    }

    @objc func openAccessibilityFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.openAccessibilityFromMenu()
    }

    @objc func editServiceNameFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.editServiceNameFromMenu()
    }

    @objc func editServiceTagFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.editServiceTagFromMenu()
    }

    @objc func chooseNotesRootFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.chooseNotesRootFromMenu()
    }

    @objc func toggleOpenNoteFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.toggleOpenNoteFromMenu()
        (sender as? NSMenuItem)?.state = Settings.openNote ? .on : .off
    }

    @objc func toggleAutoSaveFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.toggleAutoSaveFromMenu()
        (sender as? NSMenuItem)?.state = Settings.autoSave ? .on : .off
    }

    @objc func toggleIncludeSourceFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.toggleIncludeSourceFromMenu()
        (sender as? NSMenuItem)?.state = Settings.includeSource ? .on : .off
    }

    @objc func toggleIncludeDocumentSourceFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.toggleIncludeDocumentSourceFromMenu()
        (sender as? NSMenuItem)?.state = Settings.includeDocumentSource ? .on : .off
    }

    @objc func resetSlot1ToTodayFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.resetSlot1ToTodayFromMenu()
    }

    @objc func chooseShortcutMakerNoteFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.chooseShortcutMakerNoteFromMenu()
    }

    @objc func chooseShortcutMakerDestinationFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.chooseShortcutMakerDestinationFromMenu()
    }

    @objc func generateShortcutMakerAppFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.generateShortcutMakerAppFromMenu()
    }

    @objc func revealShortcutMakerAppFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.revealShortcutMakerAppFromMenu()
    }

    @objc func showShortcutMakerRecentsFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.showShortcutMakerRecentsFromMenu()
    }

    @objc func chooseCommanderRootFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.chooseCommanderRootFromMenu()
    }

    @objc func applyCommanderRootFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.applyCommanderRootFromMenu()
    }

    @objc func showCommanderFunctionsFromMenu(_ sender: Any?) {
        showSettingsWindow()
        settingsWindowController?.showCommanderFunctionsFromMenu()
    }

    @objc func showEditorWindowFromMenu(_ sender: Any?) {
        NotePlanEditorWindowController.show()
    }

    @objc func showAbout(_ sender: Any?) {
        let alert = NSAlert()
        alert.icon = noteDroopyLogoImage(size: NSSize(width: 96, height: 96))
        alert.messageText = "Note Droopy"
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
        showHelpDocument(named: "HELP.en", title: "Note Droopy Help")
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
        let title = cleanSourceTitle(title) ?? CaptureRulesStore.metadata(for: normalized)?.title ?? webLinkTitle(for: url, host: host)
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
        guard canCaptureFrontmostApplication() else {
            log("shortcut:ignored-frontmost-app")
            NSSound.beep()
            return
        }
        let accessibilityTrusted = isAccessibilityTrusted(prompt: false)
        if !accessibilityTrusted {
            log("shortcut:accessibility-not-trusted:clipboard-only")
        }
        let pageSource = sourceWebPage(for: NSWorkspace.shared.frontmostApplication)
        let documentSource = accessibilityTrusted ? sourceDocumentFileURL(for: NSWorkspace.shared.frontmostApplication) : nil

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
                let source = pastedSourceURL.map { CaptureSource(url: $0, title: pageSource?.title) } ?? pageSource ?? documentSource
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

    private func sourceDocumentFileURL(for application: NSRunningApplication?) -> CaptureSource? {
        guard Settings.includeDocumentSource,
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
        let task = formattedTask(from: content, tags: tagSource, sourceURL: sourceURL, sourceTitle: sourceTitle)
        log("sendTodoTask:\(task)")
        if shortcutSlot?.engine == .obsidian {
            writeObsidianTask(task, shortcutSlot: shortcutSlot)
            return
        }
        if let sectionTarget = captureSectionTarget(from: tagSource),
           writeNotePlanTask(task, shortcutSlot: shortcutSlot, sectionTarget: sectionTarget) {
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
            log("noteplan-section:error:no-target")
            NSSound.beep()
            return false
        }
        do {
            try FileManager.default.createDirectory(at: target.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let existing = (try? String(contentsOf: target.fileURL, encoding: .utf8)) ?? ""
            let updated = markdownByInserting(task: task, in: existing, section: sectionTarget.name, position: sectionTarget.position)
            try updated.write(to: target.fileURL, atomically: true, encoding: .utf8)
            log("noteplan-section:write:\(target.relativePath):\(sectionTarget.name)")
            if Settings.openNote {
                openNotePlanFile(relativePath: target.relativePath)
            }
            return true
        } catch {
            log("noteplan-section:error:\(error.localizedDescription)")
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
        guard let selected = Settings.selectedNotesRoot()?.standardizedFileURL else { return nil }
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

    private func formattedTask(from content: String, tags: String, sourceURL: String? = nil, sourceTitle: String? = nil) -> String {
        let expandedConfig = expandedVariables(tags)
        let tag = normalizedTags(expandedConfig, extra: llmTags(in: [content, sourceURL].compactMap { $0 }))
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

    private enum CaptureLinePrefix {
        case task
        case star
        case plus
        case plain
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
            (["!weekend", "!weekend", "$date:weekend"], { self.upcomingSaturday(from: date) }),
            (["!semainepro", "$date:semainepro", "$date:nextweek"], { self.nextMonday(from: date) }),
            (["!moisprochain", "$date:moisprochain", "$date:nextmonth"], { self.firstDayOfNextMonth(from: date) }),
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

    private func sourceContinuationLine(_ sourceURL: String?, title: String? = nil, content: String) -> String? {
        guard Settings.includeSource,
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

        guard Settings.includeDocumentSource,
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

    private func showSettingsWindow(tab identifier: String? = nil) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        if let identifier {
            settingsWindowController?.selectPreferencesTab(identifier)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NotePlan Editor (merged from NoteDroppy V3 / work/NoteDroppyV3/main.swift)

final class NotePlanSortTextView: NSTextView {
    var onDroppedPath: ((String) -> Bool)?
    var onFoldMarkerClick: ((Int) -> Bool)?

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

    override func mouseDown(with event: NSEvent) {
        if let characterIndex = characterIndex(at: event),
           onFoldMarkerClick?(characterIndex) == true {
            return
        }
        super.mouseDown(with: event)
    }

    private func characterIndex(at event: NSEvent) -> Int? {
        guard let layoutManager, let textContainer else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        let origin = textContainerOrigin
        let containerPoint = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
        guard containerPoint.x >= 0, containerPoint.y >= 0 else { return nil }
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        return min(characterIndex, max((string as NSString).length - 1, 0))
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
            if shared.textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                shared.loadTodayDirect(reason: "réouverture")
            }
            return
        }
        let controller = NotePlanEditorWindowController()
        controller.buildMenu()
        controller.buildUI()
        controller.window.delegate = controller
        shared = controller
        controller.showMainWindow()
        controller.loadTodayDirect(reason: "lancement")
        controller.didLoadInitialFile = true
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
    private let notePlanPreviewView = NSTextView()
    private let notePlanPreviewScrollView = NSScrollView()
    private let saveButton = NSButton(title: "Sauvegarder", target: nil, action: nil)
    private let commanderAutoSaveCheckbox = NSButton(checkboxWithTitle: "Auto save", target: nil, action: nil)
    private let reloadButton = NSButton(title: "Recharger", target: nil, action: nil)
    var onCloseEmbeddedSort: (() -> Void)?
    private var functionsWindow: NSWindow?
    private var openAfterFunctionCheckbox: NSButton?
    private var generatedShortcutURL: URL?
    private var editorMenu: NSMenu!
    private var embeddedContentView: NSView?
    private var didLoadInitialFile = false
    private let selectedPromptTemplateKey = "functionsSelectedPromptTemplateID"

    private var rootURL: URL
    private var currentFileURL: URL?
    private var loadedContent = ""
    private var sourceMarkdown = ""
    private var collapsedBlockStarts = Set<Int>()
    private var initialCollapsedBlockStarts = Set<Int>()
    private var displayedSourceLines: [Int] = []
    private var isFoldView = false
    private var isNotePlanPreviewVisible = false
    private var isApplyingHighlight = false
    private var pendingHighlightWorkItem: DispatchWorkItem?
    private var autoSaveTimer: Timer?

    private struct LoadedFile {
        let relativePath: String
        let fileURL: URL
        let content: String
    }

    override init() {
        let defaultRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents")
        rootURL = Settings.selectedNotesRoot().map(Self.normalizedNotePlanRoot)
            ?? defaultRoot
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .settingsDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func showMainWindow() {
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if window.frame.width < 900 || window.frame.height < 600 {
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 80, y: 80, width: 1440, height: 900)
            let size = NSSize(width: min(1280, screenFrame.width - 80), height: min(820, screenFrame.height - 80))
            let origin = NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.midY - size.height / 2
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true)
        }
        window.setIsVisible(true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.setFrame(window.frame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.order(.above, relativeTo: 0)
        window.orderFrontRegardless()
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
        commanderAutoSaveCheckbox.state = Settings.autoSave ? .on : .off
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
        let settingsItem = NSMenuItem(title: "Réglages...", action: #selector(AppDelegate.showSettingsWindowFromMenu(_:)), keyEquivalent: ",")
        settingsItem.target = NSApp.delegate
        appMenu.addItem(settingsItem)
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
        window.minSize = NSSize(width: 1100, height: 760)
        window.setContentSize(NSSize(width: 1100, height: 760))
        window.center()
        window.contentView = buildEditorContentView()
        window.setContentSize(NSSize(width: 1100, height: 760))
        window.center()
    }

    private func buildEditorContentView() -> NSView {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 760))
        content.translatesAutoresizingMaskIntoConstraints = true

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
        commanderAutoSaveCheckbox.state = Settings.autoSave ? .on : .off
        commanderAutoSaveCheckbox.target = self
        commanderAutoSaveCheckbox.action = #selector(toggleCommanderAutoSave(_:))
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
        let notePlanPreviewButton = NSButton(title: "Vue NotePlan", target: self, action: #selector(toggleNotePlanPreview))
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
        // Keep the initial load path boring and reliable: text first, styling later through explicit NotePlan view actions.
        // Calling the rich highlighter here can leave the NSTextView visually blank while the status says the file loaded.

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .bezelBorder

        notePlanPreviewView.isRichText = true
        notePlanPreviewView.isEditable = false
        notePlanPreviewView.isSelectable = true
        notePlanPreviewView.allowsUndo = false
        notePlanPreviewView.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        notePlanPreviewView.font = .systemFont(ofSize: 15, weight: .regular)
        notePlanPreviewView.textColor = .labelColor
        notePlanPreviewView.backgroundColor = .textBackgroundColor
        notePlanPreviewView.textContainerInset = NSSize(width: 28, height: 22)
        notePlanPreviewView.delegate = self
        notePlanPreviewScrollView.documentView = notePlanPreviewView
        notePlanPreviewScrollView.hasVerticalScroller = true
        notePlanPreviewScrollView.hasHorizontalScroller = false
        notePlanPreviewScrollView.autohidesScrollers = false
        notePlanPreviewScrollView.drawsBackground = true
        notePlanPreviewScrollView.backgroundColor = .textBackgroundColor
        notePlanPreviewScrollView.borderType = .bezelBorder
        notePlanPreviewScrollView.isHidden = true

        let fileRow = NSStackView(views: [fileLabel, fileField, loadButton])
        fileRow.orientation = .horizontal
        fileRow.spacing = 8
        fileRow.alignment = .centerY

        let fileActionRow = NSStackView(views: [fileActionsLabel, previousDayButton, todayButton, nextDayButton, reloadButton, refreshButton, saveButton, commanderAutoSaveCheckbox, closeSortButton])
        fileActionRow.orientation = .horizontal
        fileActionRow.spacing = 8
        fileActionRow.alignment = .centerY

        let sortRow = NSStackView(views: [sortLabel, sortButton, sortAtButton, sortHashButton, sortImportanceButton, sortMinutesButton, flattenButton])
        sortRow.orientation = .horizontal
        sortRow.spacing = 8
        sortRow.alignment = .centerY

        let viewRow = NSStackView(views: [paletteLabel, palettePopup, notePlanPreviewButton, foldBlockButton, unfoldBlockButton, foldAllButton, unfoldAllButton, restoreFoldButton])
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

        let header = NSStackView(views: [fileRow, fileActionRow, sortRow, viewRow, searchRow, rangeRow, pathLabel, statusLabel])
        header.orientation = .vertical
        header.spacing = 8
        header.alignment = .leading

        for view in [header, scrollView, notePlanPreviewScrollView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            fileField.widthAnchor.constraint(greaterThanOrEqualToConstant: 620),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
            rangeStartField.widthAnchor.constraint(equalToConstant: 110),
            rangeEndField.widthAnchor.constraint(equalToConstant: 110),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            notePlanPreviewScrollView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            notePlanPreviewScrollView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            notePlanPreviewScrollView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            notePlanPreviewScrollView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
        return content
    }

    @objc private func closeEmbeddedSort() {
        onCloseEmbeddedSort?()
    }

    func chooseRootFromMenu() {
        chooseRoot()
    }

    func applyRootFromMenu() {
        applyRootFromField()
    }

    func showFunctionsFromMenu() {
        showFunctionsWindow()
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
        let cleanContent = markdownWithoutFoldPresentation(loaded.content)
        currentFileURL = loaded.fileURL
        loadedContent = cleanContent
        sourceMarkdown = cleanContent
        collapsedBlockStarts.removeAll()
        initialCollapsedBlockStarts.removeAll()
        isFoldView = false
        isNotePlanPreviewVisible = false
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        notePlanPreviewScrollView.isHidden = true
        scrollView.isHidden = false
        displayedSourceLines = Array(0..<cleanContent.components(separatedBy: "\n").count)
        textView.isEditable = true
        textView.string = cleanContent
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
        scheduleSyntaxHighlighting()
        setSaveButtonState(.clean)
        status("\(statusText) - \(cleanContent.count) caractères")
    }

    @objc private func reloadFile() {
        guard let currentFileURL else { return }
        open(pathString: currentFileURL.path.replacingOccurrences(of: rootURL.path + "/", with: ""), createIfMissing: false)
    }

    @objc private func saveFile() {
        saveCurrentFile(isAutoSave: false)
    }

    @objc private func toggleCommanderAutoSave(_ sender: NSButton) {
        let enabled = sender.state == .on
        UserDefaults.standard.set(enabled, forKey: Settings.autoSaveKey)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        if enabled {
            status("Auto save actif")
            scheduleAutoSaveIfNeeded()
        } else {
            autoSaveTimer?.invalidate()
            autoSaveTimer = nil
            status("Auto save désactivé")
        }
    }

    @objc private func settingsDidChange() {
        commanderAutoSaveCheckbox.state = Settings.autoSave ? .on : .off
        if !Settings.autoSave {
            autoSaveTimer?.invalidate()
            autoSaveTimer = nil
        }
    }

    private func saveCurrentFile(isAutoSave: Bool) {
        guard let fileURL = currentFileURL else { return }
        do {
            if isFoldView {
                status("Déplie avant de sauvegarder: le pliage est un affichage.")
                return
            }
            if isNotePlanPreviewVisible {
                status("Reviens au Markdown éditable avant de sauvegarder.")
                return
            }
            let markdown = currentEditorMarkdown()
            guard markdown != loadedContent else {
                if !isAutoSave {
                    setSaveButtonState(.clean)
                    status("Déjà sauvegardé")
                }
                return
            }
            let disk = try String(contentsOf: fileURL, encoding: .utf8)
            guard disk == loadedContent else {
                status(isAutoSave ? "Auto save bloqué: fichier changé sur disque. Recharge avant d'écrire." : "Le fichier a changé sur disque. Recharge avant de sauvegarder.")
                return
            }
            try backup(fileURL: fileURL, content: disk)
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            loadedContent = markdown
            sourceMarkdown = markdown
            setSaveButtonState(.saved)
            status(isAutoSave ? "Auto save" : "Sauvegardé")
        } catch {
            status(isAutoSave ? "Erreur auto save: \(error.localizedDescription)" : "Erreur sauvegarde: \(error.localizedDescription)")
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
            contentRect: NSRect(x: 220, y: 120, width: 840, height: 760),
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

        let promptRows = [
            functionRow(title: "Choisir un prompt", detail: "Charge les prompts actifs depuis prompts.json et mémorise le choix.", action: #selector(choosePromptTemplate)),
            functionRow(title: "Appliquer le prompt à aujourd’hui", detail: "Remplit les variables locales, confirme, puis ajoute dans Calendar/\(todayStamp()).md.", action: #selector(applyPromptTemplateToToday)),
            functionRow(title: "Importer prompts JSON", detail: "Valide un fichier prompts.json externe puis le charge localement.", action: #selector(importPromptLibraryJSON)),
            functionRow(title: "Exporter prompts JSON", detail: "Copie la bibliothèque locale vers le dossier choisi.", action: #selector(exportPromptLibraryJSON)),
            functionRow(title: "Ouvrir prompts.json", detail: "Ouvre le fichier local modifiable sans recompiler l’app.", action: #selector(openPromptLibraryJSON)),
            functionRow(title: "Recharger prompts.json", detail: "Relit le JSON et affiche le nombre de prompts actifs.", action: #selector(reloadPromptLibrary))
        ]

        let noteDroppySection = section(title: "NOTE DROPPY", rows: noteDroppyRows + [openCheckbox])
        let shortySection = section(title: "NOTEPLANSHORTY", rows: shortyRows)
        let promptSection = section(title: "PROMPTS", rows: promptRows)

        let stack = NSStackView(views: [titleLabel, subtitleLabel, noteDroppySection, shortySection, promptSection])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        content.addSubview(scrollView)

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        scrollView.documentView = document
        infoWindow.contentView = content
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            document.heightAnchor.constraint(greaterThanOrEqualToConstant: 1060),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            subtitleLabel.widthAnchor.constraint(equalToConstant: 780)
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

    @objc private func choosePromptTemplate() {
        let prompts = PromptLibraryStore.activePrompts()
        guard !prompts.isEmpty else {
            status("Aucun prompt actif dans prompts.json")
            return
        }
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 420, height: 26), pullsDown: false)
        popup.addItems(withTitles: prompts.map(\.title))
        if let selectedID = UserDefaults.standard.string(forKey: selectedPromptTemplateKey),
           let index = prompts.firstIndex(where: { $0.id == selectedID }) {
            popup.selectItem(at: index)
        }

        let alert = NSAlert()
        alert.messageText = "Choisir un prompt"
        alert.informativeText = "Source : \(PromptLibraryStore.promptsURL.path)"
        alert.accessoryView = popup
        alert.addButton(withTitle: "Choisir")
        alert.addButton(withTitle: "Annuler")
        guard alert.runModal() == .alertFirstButtonReturn else {
            status("Choix prompt annulé")
            return
        }
        let prompt = prompts[max(0, popup.indexOfSelectedItem)]
        UserDefaults.standard.set(prompt.id, forKey: selectedPromptTemplateKey)
        status("Prompt choisi: \(prompt.title)")
    }

    @objc private func applyPromptTemplateToToday() {
        let prompts = PromptLibraryStore.activePrompts()
        guard !prompts.isEmpty else {
            status("Aucun prompt actif dans prompts.json")
            return
        }
        let prompt = selectedPrompt(from: prompts) ?? prompts[0]
        let clipboardText = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let selection = clipboardText.isEmpty
            ? (promptText(title: "Contenu du prompt", message: "Texte ou contexte à injecter") ?? "")
            : clipboardText
        let url = firstWebURLForPrompt(in: selection) ?? ""
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let rendered = renderPrompt(
            prompt.template,
            promptTitle: prompt.title,
            appName: appName,
            bundleID: bundleID,
            url: url,
            selection: selection
        )
        let tags = promptTags(prompt.tags)
        let quoted = rendered
            .components(separatedBy: .newlines)
            .map { "> \($0)" }
            .joined(separator: "\n")
        let line = "- [ ] Prompt: \(prompt.title)\(tags.isEmpty ? "" : " \(tags)")\n\(quoted)"
        appendToTodayAfterConfirmation(line, actionName: "Ajouter ce prompt à aujourd’hui ?")
    }

    @objc private func openPromptLibraryJSON() {
        PromptLibraryStore.ensureFiles()
        NSWorkspace.shared.open(PromptLibraryStore.promptsURL)
        status("Prompts: \(PromptLibraryStore.promptsURL.path)")
    }

    @objc private func importPromptLibraryJSON() {
        let panel = NSOpenPanel()
        panel.title = "Importer prompts.json"
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            status("Import prompts annulé")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            try PromptLibraryStore.validate(data: data)
            PromptLibraryStore.ensureFiles()
            try data.write(to: PromptLibraryStore.promptsURL, options: .atomic)
            status("Prompts importés: \(PromptLibraryStore.activePrompts().count) actif(s)")
        } catch {
            status("Import prompts impossible: \(error.localizedDescription)")
        }
    }

    @objc private func exportPromptLibraryJSON() {
        PromptLibraryStore.ensureFiles()
        let panel = NSSavePanel()
        panel.title = "Exporter prompts.json"
        panel.nameFieldStringValue = "prompts.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else {
            status("Export prompts annulé")
            return
        }
        do {
            try FileManager.default.copyItem(at: PromptLibraryStore.promptsURL, to: url)
            status("Prompts exportés: \(url.path)")
        } catch CocoaError.fileWriteFileExists {
            do {
                try FileManager.default.removeItem(at: url)
                try FileManager.default.copyItem(at: PromptLibraryStore.promptsURL, to: url)
                status("Prompts exportés: \(url.path)")
            } catch {
                status("Export prompts impossible: \(error.localizedDescription)")
            }
        } catch {
            status("Export prompts impossible: \(error.localizedDescription)")
        }
    }

    @objc private func reloadPromptLibrary() {
        PromptLibraryStore.ensureFiles()
        status("\(PromptLibraryStore.activePrompts().count) prompt(s) actif(s)")
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

    private func selectedPrompt(from prompts: [PromptTemplate]) -> PromptTemplate? {
        guard let selectedID = UserDefaults.standard.string(forKey: selectedPromptTemplateKey) else {
            return nil
        }
        return prompts.first { $0.id == selectedID }
    }

    private func promptTags(_ values: [String]?) -> String {
        (values ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.hasPrefix("#") || $0.hasPrefix("@") ? $0 : "#\($0)" }
            .joined(separator: " ")
    }

    private func renderPrompt(_ template: String, promptTitle: String, appName: String, bundleID: String, url: String, selection: String) -> String {
        let nowExpanded = expandedVariables(template)
        let sourceTitle = promptSourceTitle(url: url, fallback: promptTitle)
        let source = url.isEmpty ? appName : "\(sourceTitle) \(url)"
        return nowExpanded
            .replacingOccurrences(of: "$app", with: appName)
            .replacingOccurrences(of: "$bundleId", with: bundleID)
            .replacingOccurrences(of: "$url", with: url)
            .replacingOccurrences(of: "$title", with: sourceTitle)
            .replacingOccurrences(of: "$source", with: source)
            .replacingOccurrences(of: "$selection", with: selection)
    }

    private func firstWebURLForPrompt(in text: String) -> String? {
        if let normalized = EditorURLLineFormatter.normalizedWebURL(text) {
            return normalized
        }
        let pattern = #"(?:https?://)?(?:www\.)?[A-Za-z0-9][A-Za-z0-9.-]+\.[A-Za-z]{2,}(?:/[^\s<>"']*)?"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return EditorURLLineFormatter.normalizedWebURL(String(text[range]))
    }

    private func promptSourceTitle(url: String, fallback: String) -> String {
        guard let parsed = URL(string: url), let host = parsed.host else {
            return fallback
        }
        return host.replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
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
        status(editWriteStatus("Tri appliqué"))
    }

    @objc private func sortMinutes() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorTaskSorter.sort(currentEditorMarkdown(), mode: .minutes))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status(editWriteStatus("Tri -- appliqué"))
    }

    @objc private func sortAtContext() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorTaskSorter.sort(currentEditorMarkdown(), mode: .atContext))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status(editWriteStatus("Tri @ appliqué"))
    }

    @objc private func sortHashContext() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorTaskSorter.sort(currentEditorMarkdown(), mode: .hashTag))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status(editWriteStatus("Tri # appliqué"))
    }

    @objc private func sortImportance() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorTaskSorter.sort(currentEditorMarkdown(), mode: .importance))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status(editWriteStatus("Tri ^^ appliqué"))
    }

    @objc private func flattenChapters() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(EditorChapterFlattener.flatten(currentEditorMarkdown()))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status(editWriteStatus("Chapitres aplatis"))
    }

    private func editWriteStatus(_ action: String) -> String {
        Settings.autoSave ? "\(action). Auto save actif." : "\(action) en mémoire. Clique Sauvegarder pour écrire."
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
        scheduleSyntaxHighlighting()
        setSaveButtonState(currentFileURL != nil && currentEditorMarkdown() != loadedContent ? .dirty : .clean)
        scheduleAutoSaveIfNeeded()
    }

    private func scheduleAutoSaveIfNeeded() {
        autoSaveTimer?.invalidate()
        guard Settings.autoSave,
              currentFileURL != nil,
              !isFoldView,
              !isNotePlanPreviewVisible,
              currentEditorMarkdown() != loadedContent else {
            autoSaveTimer = nil
            return
        }
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveCurrentFile(isAutoSave: true)
        }
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
        scheduleSyntaxHighlighting()
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
        if isNotePlanPreviewVisible {
            hideNotePlanPreview(statusText: "Markdown éditable")
        }
        if isFoldView {
            status("Déplie avant modification: le Markdown complet est protégé.")
            return false
        }
        return true
    }

    private func currentEditorMarkdown() -> String {
        isFoldView ? sourceMarkdown : textView.string
    }

    @objc private func toggleNotePlanPreview() {
        if isNotePlanPreviewVisible {
            hideNotePlanPreview(statusText: "Markdown éditable")
        } else {
            showNotePlanPreview()
        }
    }

    private func showNotePlanPreview() {
        if !isFoldView {
            sourceMarkdown = markdownWithoutFoldPresentation(textView.string)
        }
        notePlanPreviewView.textStorage?.setAttributedString(NotePlanVisualRenderer.render(sourceMarkdown))
        notePlanPreviewScrollView.isHidden = false
        scrollView.isHidden = true
        isNotePlanPreviewVisible = true
        setSaveButtonState(currentFileURL != nil && currentEditorMarkdown() != loadedContent ? .dirty : .clean)
        status("Vue NotePlan - lecture seule, Markdown conservé")
    }

    private func hideNotePlanPreview(statusText: String) {
        notePlanPreviewScrollView.isHidden = true
        scrollView.isHidden = false
        isNotePlanPreviewVisible = false
        textView.window?.makeFirstResponder(textView)
        scheduleSyntaxHighlighting()
        setSaveButtonState(currentFileURL != nil && currentEditorMarkdown() != loadedContent ? .dirty : .clean)
        status(statusText)
    }

    private func sourceLines() -> [String] {
        markdownWithoutFoldPresentation(sourceMarkdown).components(separatedBy: "\n")
    }

    private func currentSourceLineIndex() -> Int {
        sourceLineIndex(atVisibleCharacterIndex: textView.selectedRange().location)
    }

    private func sourceLineIndex(atVisibleCharacterIndex characterIndex: Int) -> Int {
        let selected = characterIndex
        let visible = textView.string as NSString
        let clamped = min(max(selected, 0), visible.length)
        let prefix = visible.substring(with: NSRange(location: 0, length: clamped))
        let displayLine = prefix.reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
        guard displayLine >= 0, displayLine < displayedSourceLines.count else {
            return min(displayLine, max(sourceLines().count - 1, 0))
        }
        return displayedSourceLines[displayLine]
    }

    private func displayLineIndex(atVisibleCharacterIndex characterIndex: Int) -> Int {
        let visible = textView.string as NSString
        let clamped = min(max(characterIndex, 0), visible.length)
        let prefix = visible.substring(with: NSRange(location: 0, length: clamped))
        return prefix.reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
    }

    private func toggleFoldMarker(atVisibleCharacterIndex characterIndex: Int) -> Bool {
        guard isFoldView else { return false }
        let visible = textView.string as NSString
        guard visible.length > 0 else { return false }
        let clamped = min(max(characterIndex, 0), visible.length - 1)
        let lineRange = visible.lineRange(for: NSRange(location: clamped, length: 0))
        let line = visible.substring(with: lineRange)
        let indentCount = line.prefix { $0 == " " || $0 == "\t" }.count
        guard line.dropFirst(indentCount).hasPrefix("▾ ") || line.dropFirst(indentCount).hasPrefix("▸ ") else {
            return false
        }
        let markerStart = lineRange.location + indentCount
        guard clamped >= markerStart, clamped <= markerStart + 1 else { return false }
        let displayLine = displayLineIndex(atVisibleCharacterIndex: clamped)
        guard displayLine >= 0, displayLine < displayedSourceLines.count else { return false }
        let sourceLine = displayedSourceLines[displayLine]
        let lines = sourceLines()
        guard hasChildLine(after: sourceLine, in: lines) else { return false }
        if collapsedBlockStarts.contains(sourceLine) {
            collapsedBlockStarts.remove(sourceLine)
            renderFoldView(statusText: "Bloc déplié")
        } else {
            collapsedBlockStarts.insert(sourceLine)
            renderFoldView(statusText: "Bloc plié")
        }
        return true
    }

    private func renderFoldView(statusText: String) {
        if !isFoldView {
            sourceMarkdown = markdownWithoutFoldPresentation(textView.string)
        }
        let result = notePlanDisplayMarkdown(lines: sourceLines(), collapsed: collapsedBlockStarts)
        isFoldView = true
        displayedSourceLines = result.sourceLineIndexes
        textView.isEditable = false
        textView.string = result.text
        scheduleSyntaxHighlighting()
        setSaveButtonState(.foldView)
        status("\(statusText) - vue NotePlan, Markdown conservé")
    }

    private func notePlanDisplayMarkdown(lines: [String], collapsed: Set<Int>) -> (text: String, sourceLineIndexes: [Int]) {
        var visible: [String] = []
        var map: [Int] = []
        var hiddenUntilIndent: Int?
        for index in lines.indices {
            let line = markdownLineWithoutFoldPresentation(lines[index])
            let indent = lineIndent(line)
            if let hiddenIndent = hiddenUntilIndent {
                if line.trimmingCharacters(in: .whitespaces).isEmpty || indent > hiddenIndent {
                    continue
                }
                hiddenUntilIndent = nil
            }
            if hasChildLine(after: index, in: lines) {
                let marker = collapsed.contains(index) ? "▸ " : "▾ "
                visible.append(notePlanDisplayLine(line, marker: marker))
            } else {
                visible.append(notePlanDisplayLine(line, marker: ""))
            }
            map.append(index)
            if collapsed.contains(index) {
                hiddenUntilIndent = indent
            }
        }
        return (visible.joined(separator: "\n"), map)
    }

    private func notePlanDisplayLine(_ line: String, marker: String) -> String {
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
        let body = String(line.dropFirst(indent.count))
        let interpreted = notePlanRenderedBody(body)
        if interpreted.isEmpty {
            return ""
        }
        return indent + marker + interpreted
    }

    private func notePlanRenderedBody(_ body: String) -> String {
        var text = body.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return "" }

        if text.hasPrefix("###") {
            return text
        }
        if text.hasPrefix("##") {
            return text
        }
        if text.hasPrefix("#") {
            return text
        }

        let taskPrefixes: [(String, String)] = [
            ("- [x] ", "✓"),
            ("- [X] ", "✓"),
            ("* [x] ", "✓"),
            ("* [X] ", "✓"),
            ("- [ ] ", "○"),
            ("* [ ] ", "○"),
            ("- [x]", "✓"),
            ("- [X]", "✓"),
            ("* [x]", "✓"),
            ("* [X]", "✓"),
            ("- [ ]", "○"),
            ("* [ ]", "○")
        ]
        for (prefix, symbol) in taskPrefixes {
            let exactPrefix = prefix.trimmingCharacters(in: .whitespaces)
            if text == exactPrefix {
                return symbol
            }
            if text.hasPrefix(prefix) {
                text = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                return "\(symbol) \(text)"
            }
        }
        let listPrefixes: [(String, String)] = [
            ("- ", "○"),
            ("* ", "○"),
            ("+ ", "+")
        ]
        for (prefix, symbol) in listPrefixes where text.hasPrefix(prefix) {
            text = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            return "\(symbol) \(text)"
        }
        return text
    }

    private func markdownWithoutFoldPresentation(_ markdown: String) -> String {
        markdown
            .components(separatedBy: "\n")
            .map(markdownLineWithoutFoldPresentation)
            .joined(separator: "\n")
    }

    private func markdownLineWithoutFoldPresentation(_ line: String) -> String {
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
        var body = String(line.dropFirst(indent.count))
        var didStrip = false
        while body.hasPrefix("▾ ") || body.hasPrefix("▸ ") || body.hasPrefix("▼ ") || body.hasPrefix("▶ ") {
            body.removeFirst(2)
            didStrip = true
            while body.hasPrefix(" ") {
                body.removeFirst()
            }
        }
        return didStrip ? indent + body : line
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
        case foldView
    }

    private func setSaveButtonState(_ state: SaveButtonState) {
        switch state {
        case .clean:
            styleButton(saveButton, title: "Sauvegarder", background: .controlColor, foreground: .secondaryLabelColor, enabled: false)
        case .dirty:
            styleButton(saveButton, title: "Sauvegarder", background: .systemOrange, foreground: .white, enabled: true)
        case .saved:
            styleButton(saveButton, title: "Sauvegardé", background: .systemGreen, foreground: .white, enabled: true)
        case .foldView:
            styleButton(saveButton, title: "Vue NotePlan", background: .controlColor, foreground: .secondaryLabelColor, enabled: false)
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
        defer {
            isApplyingHighlight = false
            textView.needsDisplay = true
        }
        let selectedRanges = textView.selectedRanges
        EditorMarkdownHighlighter.apply(to: storage)
        textView.selectedRanges = selectedRanges
    }

    private func scheduleSyntaxHighlighting() {
        pendingHighlightWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.applySyntaxHighlighting()
        }
        pendingHighlightWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
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

private enum NotePlanVisualRenderer {
    private static let bodyFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
    private static let completedFont = NSFont.systemFont(ofSize: 15, weight: .medium)
    private static let headingFont = NSFont.systemFont(ofSize: 26, weight: .bold)
    private static let smallFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    private static let background = NSColor.textBackgroundColor
    private static let yellow = NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.23, alpha: 1)
    private static let orange = NSColor(calibratedRed: 1.0, green: 0.52, blue: 0.16, alpha: 1)
    private static let green = NSColor(calibratedRed: 0.45, green: 0.68, blue: 0.48, alpha: 1)
    private static let red = NSColor(calibratedRed: 0.82, green: 0.24, blue: 0.27, alpha: 1)

    static func render(_ markdown: String) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            if index > 0 {
                output.append(NSAttributedString(string: "\n", attributes: baseAttributes(indent: 0)))
            }
            output.append(renderLine(line))
        }
        return output
    }

    private static func renderLine(_ line: String) -> NSAttributedString {
        let indentText = String(line.prefix { $0 == " " || $0 == "\t" })
        let indent = indentText.reduce(0) { $0 + ($1 == "\t" ? 2 : 1) }
        var body = String(line.dropFirst(indentText.count)).trimmingCharacters(in: .whitespaces)

        guard !body.isEmpty else {
            return NSAttributedString(string: "", attributes: baseAttributes(indent: indent))
        }

        if body.hasPrefix("#") {
            let level = min(body.prefix { $0 == "#" }.count, 6)
            body = body.dropFirst(level).trimmingCharacters(in: .whitespaces)
            let rendered = NSMutableAttributedString(string: body, attributes: [
                .font: headingFont,
                .foregroundColor: orange,
                .backgroundColor: background,
                .paragraphStyle: paragraph(indent: indent, spacing: 8)
            ])
            return rendered
        }

        let task = parseTaskPrefix(body)
        body = task.body
        let text = NSMutableAttributedString()
        let attrs = lineAttributes(indent: indent, completed: task.completed, urgency: urgencyLevel(in: body))

        if let symbol = task.symbol {
            text.append(NSAttributedString(string: symbol + " ", attributes: [
                .font: NSFont.systemFont(ofSize: 17, weight: .bold),
                .foregroundColor: task.completed ? green : yellow,
                .backgroundColor: attrs.background
            ]))
        }

        text.append(renderInlineMarkdown(body, base: attrs.text))
        text.addAttributes([
            .paragraphStyle: paragraph(indent: indent, spacing: 5),
            .backgroundColor: attrs.background
        ], range: NSRange(location: 0, length: text.length))
        if task.completed {
            text.addAttributes([
                .foregroundColor: green,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ], range: NSRange(location: min(task.symbol == nil ? 0 : 2, text.length), length: max(text.length - (task.symbol == nil ? 0 : 2), 0)))
        }
        colorTokens(in: text)
        return text
    }

    private static func parseTaskPrefix(_ input: String) -> (symbol: String?, completed: Bool, body: String) {
        let completedPrefixes = ["- [x] ", "- [X] ", "* [x] ", "* [X] ", "- [x]", "- [X]", "* [x]", "* [X]"]
        for prefix in completedPrefixes where input == prefix.trimmingCharacters(in: .whitespaces) || input.hasPrefix(prefix) {
            return ("✓", true, String(input.dropFirst(min(prefix.count, input.count))).trimmingCharacters(in: .whitespaces))
        }

        let openPrefixes = ["- [ ] ", "* [ ] ", "- [ ]", "* [ ]"]
        for prefix in openPrefixes where input == prefix.trimmingCharacters(in: .whitespaces) || input.hasPrefix(prefix) {
            return ("○", false, String(input.dropFirst(min(prefix.count, input.count))).trimmingCharacters(in: .whitespaces))
        }

        if input.hasPrefix("- ") || input.hasPrefix("* ") {
            return ("○", false, String(input.dropFirst(2)).trimmingCharacters(in: .whitespaces))
        }
        if input.hasPrefix("+ ") {
            return ("+", false, String(input.dropFirst(2)).trimmingCharacters(in: .whitespaces))
        }
        return (nil, false, input)
    }

    private static func renderInlineMarkdown(_ text: String, base: [NSAttributedString.Key: Any]) -> NSAttributedString {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]\n]+)\]\(([^)\s]+)\)"#) else {
            return NSAttributedString(string: text, attributes: base)
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let result = NSMutableAttributedString()
        var cursor = 0

        regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match,
                  match.range(at: 1).location != NSNotFound,
                  match.range(at: 2).location != NSNotFound else { return }
            if match.range.location > cursor {
                result.append(NSAttributedString(
                    string: nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor)),
                    attributes: base
                ))
            }
            let title = nsText.substring(with: match.range(at: 1))
            let urlText = nsText.substring(with: match.range(at: 2))
            var linkAttrs = base
            if let url = URL(string: urlText) {
                linkAttrs[.link] = url
            }
            linkAttrs[.foregroundColor] = yellow
            linkAttrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            result.append(NSAttributedString(string: "\(title)(↗)", attributes: linkAttrs))
            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            result.append(NSAttributedString(
                string: nsText.substring(with: NSRange(location: cursor, length: nsText.length - cursor)),
                attributes: base
            ))
        }
        return result
    }

    private static func colorTokens(in text: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: text.length)
        applyRegex(#"#[\p{L}\p{N}_/-]+"#, to: text, range: fullRange, color: orange)
        applyRegex(#"(?<!\S)@[\p{L}\p{N}_/-]+"#, to: text, range: fullRange, color: NSColor.systemBlue)
        applyRegex(#"\b\d{1,2}:\d{2}\b"#, to: text, range: fullRange, color: NSColor.systemPurple)
        applyRegex(#"!!!"#, to: text, range: fullRange, color: NSColor.white, font: NSFont.systemFont(ofSize: 15, weight: .bold))
        applyRegex(#"!!"#, to: text, range: fullRange, color: red, font: NSFont.systemFont(ofSize: 15, weight: .bold))
        applyRegex(#"(?<![!])!(?![!])"#, to: text, range: fullRange, color: orange, font: NSFont.systemFont(ofSize: 15, weight: .bold))
    }

    private static func applyRegex(_ pattern: String, to text: NSMutableAttributedString, range: NSRange, color: NSColor, font: NSFont? = nil) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        regex.enumerateMatches(in: text.string, range: range) { match, _, _ in
            guard let match else { return }
            text.addAttribute(.foregroundColor, value: color, range: match.range)
            if let font {
                text.addAttribute(.font, value: font, range: match.range)
            }
        }
    }

    private static func urgencyLevel(in text: String) -> Int {
        if text.contains("!!!") { return 3 }
        if text.contains("!!") { return 2 }
        if text.contains("!") { return 1 }
        return 0
    }

    private static func lineAttributes(indent: Int, completed: Bool, urgency: Int) -> (text: [NSAttributedString.Key: Any], background: NSColor) {
        let bg: NSColor
        switch urgency {
        case 3:
            bg = red.withAlphaComponent(0.82)
        case 2:
            bg = red.withAlphaComponent(0.20)
        case 1:
            bg = orange.withAlphaComponent(0.13)
        default:
            bg = background
        }
        let color: NSColor = completed ? green : colorForIndent(indent)
        return ([
            .font: completed ? completedFont : bodyFont,
            .foregroundColor: color,
            .backgroundColor: bg
        ], bg)
    }

    private static func baseAttributes(indent: Int) -> [NSAttributedString.Key: Any] {
        [
            .font: bodyFont,
            .foregroundColor: colorForIndent(indent),
            .backgroundColor: background,
            .paragraphStyle: paragraph(indent: indent, spacing: 5)
        ]
    }

    private static func paragraph(indent: Int, spacing: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let left = CGFloat(min(indent, 24)) * 10
        style.firstLineHeadIndent = left
        style.headIndent = left + 24
        style.lineSpacing = spacing
        style.paragraphSpacing = 2
        return style
    }

    private static func colorForIndent(_ indent: Int) -> NSColor {
        let level = max(0, min(indent / 2, 5))
        switch level {
        case 1:
            return NSColor.labelColor
        case 2:
            return orange
        case 3:
            return NSColor.systemTeal
        case 4:
            return NSColor.systemBlue
        case 5:
            return NSColor.secondaryLabelColor
        default:
            return NSColor.labelColor
        }
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
        let displayTrimmed = trimmed.removingFoldGlyphPrefix()
        let indent = line.prefix { $0 == " " || $0 == "\t" }.count

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 2
        paragraph.headIndent = CGFloat(min(indent, 12)) * 12
        storage.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)

        if displayTrimmed.hasPrefix("#") {
            let level = min(displayTrimmed.prefix { $0 == "#" }.count, 4)
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: CGFloat(max(24 - level * 2, 16)), weight: .bold),
                .foregroundColor: NSColor.systemOrange
            ], range: lineRange)
            if let hashRange = line.range(of: #"^\s*(?:[▸▾]\s*)?#{1,6}\s*"#, options: .regularExpression) {
                let nsRange = NSRange(hashRange, in: line)
                storage.addAttributes(hiddenPrefixAttributes(), range: NSRange(location: lineRange.location + nsRange.location, length: nsRange.length))
            }
            return
        }

        if displayTrimmed.hasPrefix("✓ ") {
            storage.addAttribute(.foregroundColor, value: NSColor.systemGreen.withAlphaComponent(0.78), range: lineRange)
            styleLeadingGlyph(in: storage, nsText: nsText, lineRange: lineRange, glyph: "✓", color: NSColor.systemGreen)
        } else if displayTrimmed.hasPrefix("○ ") {
            storage.addAttribute(.foregroundColor, value: colorForIndent(indent), range: lineRange)
            styleLeadingGlyph(in: storage, nsText: nsText, lineRange: lineRange, glyph: "○", color: NSColor.systemYellow)
        } else if displayTrimmed.hasPrefix("+ ") {
            storage.addAttribute(.foregroundColor, value: colorForIndent(indent), range: lineRange)
            styleLeadingGlyph(in: storage, nsText: nsText, lineRange: lineRange, glyph: "+", color: NSColor.systemRed)
        } else if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("* [x]") || trimmed.hasPrefix("- [X]") || trimmed.hasPrefix("* [X]") {
            storage.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ], range: lineRange)
        } else if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("* [ ]") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            storage.addAttribute(.foregroundColor, value: colorForIndent(indent), range: lineRange)
        }

        styleUrgency(in: storage, nsText: nsText, lineRange: lineRange, line: line)
    }

    private static func styleLeadingGlyph(in storage: NSTextStorage, nsText: NSString, lineRange: NSRange, glyph: String, color: NSColor) {
        let found = nsText.range(of: glyph, options: [], range: lineRange)
        guard found.location != NSNotFound else { return }
        storage.addAttributes([
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold)
        ], range: found)
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

    private static func hiddenPrefixAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.clear,
            .font: NSFont.systemFont(ofSize: 0.1, weight: .regular)
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

private extension String {
    func removingFoldGlyphPrefix() -> String {
        var value = self
        if value.hasPrefix("▸ ") || value.hasPrefix("▾ ") {
            value.removeFirst(2)
        }
        return value.trimmingCharacters(in: .whitespaces)
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
        guard let range = line.range(
            of: #"^[-*]\s+(?:\[[ xX]\]\s*)?(?:(?:\d{1,2}:\d{2}|>\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?)\s+)?(!{1,3})(?=\s|$)"#,
            options: .regularExpression
        ) else {
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
            .replacingOccurrences(of: #"^(?:\d{1,2}:\d{2}|>\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?)\s+"#, with: "", options: .regularExpression)
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

        let noteURLString = notePlanOpenURLString(for: noteURL, fallbackNoteName: noteName)
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
            try run("/usr/bin/codesign", ["--force", "--deep", "-s", "-", finalAppPath])
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

    private static func notePlanOpenURLString(for noteURL: URL, fallbackNoteName: String) -> String {
        let standardized = noteURL.standardizedFileURL
        if let root = Settings.selectedNotesRoot()?.standardizedFileURL {
            let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
            if standardized.path.hasPrefix(rootPath) {
                let relativePath = String(standardized.path.dropFirst(rootPath.count))
                let encoded = urlEncode(relativePath)
                return "noteplan://x-callback-url/openNote?notePath=\(encoded)&fileName=\(encoded)"
            }
        }
        return "noteplan://x-callback-url/openNote?noteTitle=\(urlEncode(fallbackNoteName))"
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
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.servicesProvider = delegate

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)
let appMenu = NSMenu()
let aboutItem = NSMenuItem(title: "À propos de NoteDroppy", action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")
aboutItem.target = delegate
appMenu.addItem(aboutItem)
appMenu.addItem(NSMenuItem.separator())
let settingsMenuItem = NSMenuItem(title: "Réglages...", action: #selector(AppDelegate.showSettingsWindowFromMenu(_:)), keyEquivalent: ",")
settingsMenuItem.target = delegate
appMenu.addItem(settingsMenuItem)
let editorMenuItem = NSMenuItem(title: "Éditeur NotePlan...", action: #selector(AppDelegate.showEditorWindowFromMenu(_:)), keyEquivalent: "e")
editorMenuItem.target = delegate
appMenu.addItem(editorMenuItem)
appMenu.addItem(NSMenuItem.separator())
appMenu.addItem(withTitle: "Quitter NoteDroppy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appMenuItem.submenu = appMenu
app.mainMenu = mainMenu

let preferencesMenuItem = NSMenuItem()
mainMenu.addItem(preferencesMenuItem)
let preferencesMenu = NSMenu(title: "Préférences")

let capturePrefsItem = NSMenuItem(title: "Capture", action: nil, keyEquivalent: "")
let capturePrefsMenu = NSMenu(title: "Capture")
let serviceNamePrefsItem = NSMenuItem(title: "Nom du Service...", action: #selector(AppDelegate.editServiceNameFromMenu(_:)), keyEquivalent: "")
serviceNamePrefsItem.target = delegate
capturePrefsMenu.addItem(serviceNamePrefsItem)
let serviceTagPrefsItem = NSMenuItem(title: "Tag service...", action: #selector(AppDelegate.editServiceTagFromMenu(_:)), keyEquivalent: "")
serviceTagPrefsItem.target = delegate
capturePrefsMenu.addItem(serviceTagPrefsItem)
let notesRootPrefsItem = NSMenuItem(title: "Dossier Notes...", action: #selector(AppDelegate.chooseNotesRootFromMenu(_:)), keyEquivalent: "")
notesRootPrefsItem.target = delegate
capturePrefsMenu.addItem(notesRootPrefsItem)
capturePrefsMenu.addItem(NSMenuItem.separator())
let openNotePrefsItem = NSMenuItem(title: "Ouvrir NotePlan", action: #selector(AppDelegate.toggleOpenNoteFromMenu(_:)), keyEquivalent: "")
openNotePrefsItem.target = delegate
openNotePrefsItem.state = Settings.openNote ? .on : .off
capturePrefsMenu.addItem(openNotePrefsItem)
let autoSavePrefsItem = NSMenuItem(title: "Auto save", action: #selector(AppDelegate.toggleAutoSaveFromMenu(_:)), keyEquivalent: "")
autoSavePrefsItem.target = delegate
autoSavePrefsItem.state = Settings.autoSave ? .on : .off
capturePrefsMenu.addItem(autoSavePrefsItem)
let sourcePrefsItem = NSMenuItem(title: "Ajouter le lien", action: #selector(AppDelegate.toggleIncludeSourceFromMenu(_:)), keyEquivalent: "")
sourcePrefsItem.target = delegate
sourcePrefsItem.state = Settings.includeSource ? .on : .off
capturePrefsMenu.addItem(sourcePrefsItem)
let documentSourcePrefsItem = NSMenuItem(title: "Ajouter le doc", action: #selector(AppDelegate.toggleIncludeDocumentSourceFromMenu(_:)), keyEquivalent: "")
documentSourcePrefsItem.target = delegate
documentSourcePrefsItem.state = Settings.includeDocumentSource ? .on : .off
capturePrefsMenu.addItem(documentSourcePrefsItem)
let slot1TodayPrefsItem = NSMenuItem(title: "Ligne 1 -> NotePlan Today", action: #selector(AppDelegate.resetSlot1ToTodayFromMenu(_:)), keyEquivalent: "")
slot1TodayPrefsItem.target = delegate
capturePrefsMenu.addItem(slot1TodayPrefsItem)
preferencesMenu.setSubmenu(capturePrefsMenu, for: capturePrefsItem)
preferencesMenu.addItem(capturePrefsItem)

let shortcutPrefsItem = NSMenuItem(title: "Shortcut", action: nil, keyEquivalent: "")
let shortcutPrefsMenu = NSMenu(title: "Shortcut")
let shortcutNotePrefsItem = NSMenuItem(title: "Choisir une note .md...", action: #selector(AppDelegate.chooseShortcutMakerNoteFromMenu(_:)), keyEquivalent: "")
shortcutNotePrefsItem.target = delegate
shortcutPrefsMenu.addItem(shortcutNotePrefsItem)
let shortcutDestinationPrefsItem = NSMenuItem(title: "Choisir destination...", action: #selector(AppDelegate.chooseShortcutMakerDestinationFromMenu(_:)), keyEquivalent: "")
shortcutDestinationPrefsItem.target = delegate
shortcutPrefsMenu.addItem(shortcutDestinationPrefsItem)
let shortcutGeneratePrefsItem = NSMenuItem(title: "Créer le raccourci .app", action: #selector(AppDelegate.generateShortcutMakerAppFromMenu(_:)), keyEquivalent: "")
shortcutGeneratePrefsItem.target = delegate
shortcutPrefsMenu.addItem(shortcutGeneratePrefsItem)
let shortcutRevealPrefsItem = NSMenuItem(title: "Révéler le dernier raccourci", action: #selector(AppDelegate.revealShortcutMakerAppFromMenu(_:)), keyEquivalent: "")
shortcutRevealPrefsItem.target = delegate
shortcutPrefsMenu.addItem(shortcutRevealPrefsItem)
let shortcutRecentsPrefsItem = NSMenuItem(title: "Derniers raccourcis créés", action: #selector(AppDelegate.showShortcutMakerRecentsFromMenu(_:)), keyEquivalent: "")
shortcutRecentsPrefsItem.target = delegate
shortcutPrefsMenu.addItem(shortcutRecentsPrefsItem)
shortcutPrefsMenu.addItem(NSMenuItem.separator())
let shortcutSlot1TodayPrefsItem = NSMenuItem(title: "Ligne 1 -> NotePlan Today", action: #selector(AppDelegate.resetSlot1ToTodayFromMenu(_:)), keyEquivalent: "")
shortcutSlot1TodayPrefsItem.target = delegate
shortcutPrefsMenu.addItem(shortcutSlot1TodayPrefsItem)
preferencesMenu.setSubmenu(shortcutPrefsMenu, for: shortcutPrefsItem)
preferencesMenu.addItem(shortcutPrefsItem)

let commanderPrefsItem = NSMenuItem(title: "Commander", action: nil, keyEquivalent: "")
let commanderPrefsMenu = NSMenu(title: "Commander")
let commanderRootPrefsItem = NSMenuItem(title: "Dossier NotePlan...", action: #selector(AppDelegate.chooseCommanderRootFromMenu(_:)), keyEquivalent: "")
commanderRootPrefsItem.target = delegate
commanderPrefsMenu.addItem(commanderRootPrefsItem)
let commanderApplyRootPrefsItem = NSMenuItem(title: "Valider dossier", action: #selector(AppDelegate.applyCommanderRootFromMenu(_:)), keyEquivalent: "")
commanderApplyRootPrefsItem.target = delegate
commanderPrefsMenu.addItem(commanderApplyRootPrefsItem)
let commanderFunctionsPrefsItem = NSMenuItem(title: "Fonctions...", action: #selector(AppDelegate.showCommanderFunctionsFromMenu(_:)), keyEquivalent: "")
commanderFunctionsPrefsItem.target = delegate
commanderPrefsMenu.addItem(commanderFunctionsPrefsItem)
commanderPrefsMenu.addItem(NSMenuItem.separator())
let commanderAutoSavePrefsItem = NSMenuItem(title: "Auto save", action: #selector(AppDelegate.toggleAutoSaveFromMenu(_:)), keyEquivalent: "")
commanderAutoSavePrefsItem.target = delegate
commanderAutoSavePrefsItem.state = Settings.autoSave ? .on : .off
commanderPrefsMenu.addItem(commanderAutoSavePrefsItem)
preferencesMenu.setSubmenu(commanderPrefsMenu, for: commanderPrefsItem)
preferencesMenu.addItem(commanderPrefsItem)

preferencesMenu.addItem(NSMenuItem.separator())
let allPrefsItem = NSMenuItem(title: "Toutes les préférences...", action: #selector(AppDelegate.showSettingsWindowFromMenu(_:)), keyEquivalent: ",")
allPrefsItem.target = delegate
preferencesMenu.addItem(allPrefsItem)
preferencesMenu.addItem(NSMenuItem.separator())
let savePrefsItem = NSMenuItem(title: "Enregistrer", action: #selector(AppDelegate.savePreferencesFromMenu(_:)), keyEquivalent: "s")
savePrefsItem.target = delegate
preferencesMenu.addItem(savePrefsItem)
let editorPrefsItem = NSMenuItem(title: "Éditeur NotePlan...", action: #selector(AppDelegate.showEditorWindowFromMenu(_:)), keyEquivalent: "e")
editorPrefsItem.target = delegate
preferencesMenu.addItem(editorPrefsItem)
preferencesMenu.addItem(NSMenuItem.separator())
let exportPrefsItem = NSMenuItem(title: "Exporter JSON...", action: #selector(AppDelegate.exportPreferencesFromMenu(_:)), keyEquivalent: "")
exportPrefsItem.target = delegate
preferencesMenu.addItem(exportPrefsItem)
let importPrefsItem = NSMenuItem(title: "Importer JSON...", action: #selector(AppDelegate.importPreferencesFromMenu(_:)), keyEquivalent: "")
importPrefsItem.target = delegate
preferencesMenu.addItem(importPrefsItem)
preferencesMenu.addItem(NSMenuItem.separator())
let rulesPrefsItem = NSMenuItem(title: "Règles capture JSON", action: #selector(AppDelegate.openCaptureRulesFromMenu(_:)), keyEquivalent: "")
rulesPrefsItem.target = delegate
preferencesMenu.addItem(rulesPrefsItem)
let formatsPrefsItem = NSMenuItem(title: "Doc formats", action: #selector(AppDelegate.openCaptureRulesHelpFromMenu(_:)), keyEquivalent: "")
formatsPrefsItem.target = delegate
preferencesMenu.addItem(formatsPrefsItem)
let promptsPrefsItem = NSMenuItem(title: "Prompts JSON", action: #selector(AppDelegate.openPromptsFromMenu(_:)), keyEquivalent: "")
promptsPrefsItem.target = delegate
preferencesMenu.addItem(promptsPrefsItem)
let promptsHelpPrefsItem = NSMenuItem(title: "Doc prompts", action: #selector(AppDelegate.openPromptsHelpFromMenu(_:)), keyEquivalent: "")
promptsHelpPrefsItem.target = delegate
preferencesMenu.addItem(promptsHelpPrefsItem)
let reloadPromptsPrefsItem = NSMenuItem(title: "Recharger prompts", action: #selector(AppDelegate.reloadPromptsFromMenu(_:)), keyEquivalent: "")
reloadPromptsPrefsItem.target = delegate
preferencesMenu.addItem(reloadPromptsPrefsItem)
let accessibilityPrefsItem = NSMenuItem(title: "Autoriser Accessibilité", action: #selector(AppDelegate.openAccessibilityFromMenu(_:)), keyEquivalent: "")
accessibilityPrefsItem.target = delegate
preferencesMenu.addItem(accessibilityPrefsItem)
preferencesMenu.addItem(NSMenuItem.separator())
let helpPrefsItem = NSMenuItem(title: "Aide / Formats / Variables", action: #selector(AppDelegate.openHelp(_:)), keyEquivalent: "?")
helpPrefsItem.target = delegate
preferencesMenu.addItem(helpPrefsItem)
let githubPrefsItem = NSMenuItem(title: "GitHub / Releases", action: #selector(AppDelegate.openGitHubRepository(_:)), keyEquivalent: "")
githubPrefsItem.target = delegate
preferencesMenu.addItem(githubPrefsItem)
preferencesMenuItem.submenu = preferencesMenu

let helpMenuItem = NSMenuItem()
mainMenu.addItem(helpMenuItem)
let helpMenu = NSMenu(title: "Aide")
helpMenu.addItem(withTitle: "Aide NoteDroppy", action: #selector(AppDelegate.openHelp(_:)), keyEquivalent: "")
helpMenu.addItem(withTitle: "Help NoteDroppy English", action: #selector(AppDelegate.openEnglishHelp(_:)), keyEquivalent: "")
helpMenu.addItem(NSMenuItem.separator())
helpMenu.addItem(withTitle: "GitHub Repository", action: #selector(AppDelegate.openGitHubRepository(_:)), keyEquivalent: "")
helpMenuItem.submenu = helpMenu

app.run()
