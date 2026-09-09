// NoteDroppy V4 — Shortcut slot data layer
//
// Etape 1 du plan de migration V5 : port de la couche donnees pure du
// systeme a 20 slots de raccourcis de Note Droopy (work/NotePlanURLDrop/main.swift),
// sans UI, sans hotkeys globaux (Carbon RegisterEventHotKey), sans drag & drop.
//
// Compatibilite : les cles UserDefaults ci-dessous sont VOLONTAIREMENT non
// prefixees "v4." — ce sont exactement les memes cles que Note Droopy lit et
// ecrit deja ("shortcutSlot1.destination", "taskTag", etc.), pour que ce
// store lise/ecrive le meme reglage utilisateur, pas un doublon isole.
// Verifiable sans lancer l'app :
//   defaults read local.codex.notedroopy shortcutSlot1.destination
//
// Code copie verbatim depuis NotePlanURLDrop/main.swift (Settings enum,
// ShortcutSlot, ShortcutEngine, ShortcutDestination, KeyCombo, et les
// fonctions de conversion Carbon<->NSEvent qu'ils utilisent) — aucune
// logique modifiee, seulement deplacee et renommee `Settings` ->
// `ShortcutSlotStore` pour ne pas entrer en collision avec le `Settings`
// existant de NoteDroppyV4 (qui gere d'autres cles, prefixees "v4.").

import AppKit
import Carbon
import Foundation

// MARK: - Modeles

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

// MARK: - Conversion Carbon <-> NSEvent (identique a NotePlanURLDrop/main.swift)

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

func normalizedCarbonModifiers(_ raw: UInt32) -> UInt32 {
    let allowedCarbon = UInt32(controlKey | optionKey | shiftKey | cmdKey)
    if raw != 0, raw & ~allowedCarbon == 0 {
        return raw
    }
    let converted = carbonModifiers(fromRawNSEventFlags: UInt(raw))
    return converted == 0 ? UInt32(controlKey | optionKey | cmdKey) : converted
}

// MARK: - Store

/// Lit/ecrit les memes cles UserDefaults que Note Droopy (NotePlanURLDrop) —
/// volontairement PAS nomme `Settings` pour ne pas entrer en collision avec
/// le `Settings` (prefixe "v4.") deja present dans NoteDroppyV4/main.swift.
enum ShortcutSlotStore {
    static let taskTagKey = "taskTag"
    static let notesRootPathKey = "notesRootPath"
    static let notesRootBookmarkKey = "notesRootBookmark"
    static let shortcutLayoutVersionKey = "shortcutLayoutVersion"
    static let shortcutSlotCount = 20
    static let currentShortcutLayoutVersion = 3

    static let openNoteKey = "openNote"
    static let autoSaveKey = "autoSave"
    static let includeSourceKey = "includeSource"
    static let includeDocumentSourceKey = "includeDocumentSource"

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

    /// Meme dossier NotePlan que Note Droopy — clef "notesRootPath" /
    /// "notesRootBookmark" non prefixees, distinctes du "v4.notesRootPath"
    /// deja utilise par MainWindowController pour son propre picker.
    /// Les deux coexistent volontairement : ce store lit le reglage legacy,
    /// il ne remplace pas le picker v4 existant.
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
                return normalizedNotesRoot(url)
            }
        }

        let path = notesRootPath
        return path.isEmpty ? nil : normalizedNotesRoot(URL(fileURLWithPath: path))
    }

    static func setNotesRoot(_ url: URL) {
        let normalized = normalizedNotesRoot(url)
        UserDefaults.standard.set(normalized.path, forKey: notesRootPathKey)
        if let data = try? normalized.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: notesRootBookmarkKey)
        }
        UserDefaults.standard.synchronize()
    }

    static func normalizedNotesRoot(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        if standardized.lastPathComponent == "Notes" {
            let parent = standardized.deletingLastPathComponent()
            let hasCalendar = FileManager.default.fileExists(atPath: parent.appendingPathComponent("Calendar").path)
            let hasNotes = FileManager.default.fileExists(atPath: parent.appendingPathComponent("Notes").path)
            if hasCalendar && hasNotes {
                return parent
            }
        }
        return standardized
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
            enabled = index == 1
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
        let destination = validDestination(savedDestination ?? (index == 1 ? .today : .standard), for: index)
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
        let destination = validDestination(slot.destination, for: slot.index)
        UserDefaults.standard.set(destination.rawValue, forKey: "shortcutSlot\(slot.index).destination")
        UserDefaults.standard.set(slot.noteReference, forKey: "shortcutSlot\(slot.index).note")
        UserDefaults.standard.set(slot.folder, forKey: "shortcutSlot\(slot.index).folder")
        UserDefaults.standard.set(slot.tags, forKey: "shortcutSlot\(slot.index).tags")
        if slot.index == 1 {
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

    /// Migration de layout historique (P + 1..9 -> 1..0) — copiee telle
    /// quelle depuis NotePlanURLDrop/main.swift pour que les utilisateurs
    /// dont les defaults viennent de Note Droopy n'aient pas leurs raccourcis
    /// silencieusement changes en passant par ce store.
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
        defaults.set(currentShortcutLayoutVersion, forKey: shortcutLayoutVersionKey)
    }
}
