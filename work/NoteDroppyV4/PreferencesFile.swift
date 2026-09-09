// NoteDroppy V4 — Etape 7 du plan de migration V5
//
// Export/import JSON des reglages (PreferencesFile.current/apply, sur la
// liste explicite des fonctions a preserver). Copie verbatim depuis
// NotePlanURLDrop/main.swift. Settings.X -> ShortcutSlotStore.X.
//
// Pas encore branchee a un bouton Exporter/Importer (il n'y a pas encore
// de fenetre Preferences generale en V4 ou le placer proprement) — les
// deux fonctions statiques/methodes sont pretes a l'emploi des qu'un tel
// bouton existera : PreferencesFile.current() pour exporter,
// preferences.apply() pour importer, exactement comme dans l'original.
//
// Ecart assume : le champ serviceName (integration au menu Services macOS
// de Note Droopy) est fige a "-> Today" ici — V4 n'a pas encore
// d'equivalent "Nom du Service"/enregistrement Services, ce n'etait pas
// sur la liste explicite a preserver. Le champ reste dans le JSON pour
// compatibilite du format d'export/import, juste non fonctionnel cote V4.

import Foundation

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
            openNote: ShortcutSlotStore.openNote,
            autoSave: ShortcutSlotStore.autoSave,
            includeSource: ShortcutSlotStore.includeSource,
            includeDocumentSource: ShortcutSlotStore.includeDocumentSource,
            serviceName: "-> Today",
            defaultTags: ShortcutSlotStore.taskTag,
            notesRootPath: ShortcutSlotStore.notesRootPath,
            shortcuts: ShortcutSlotStore.allShortcutSlots().map(ShortcutSlotFile.init(slot:))
        )
    }

    func apply() {
        UserDefaults.standard.set(openNote, forKey: ShortcutSlotStore.openNoteKey)
        UserDefaults.standard.set(autoSave ?? true, forKey: ShortcutSlotStore.autoSaveKey)
        UserDefaults.standard.set(includeSource ?? true, forKey: ShortcutSlotStore.includeSourceKey)
        UserDefaults.standard.set(includeDocumentSource ?? false, forKey: ShortcutSlotStore.includeDocumentSourceKey)
        UserDefaults.standard.set(defaultTags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "#capture" : defaultTags, forKey: ShortcutSlotStore.taskTagKey)
        let trimmedNotesRoot = (notesRootPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotesRoot.isEmpty {
            ShortcutSlotStore.setNotesRoot(URL(fileURLWithPath: trimmedNotesRoot))
        }
        for shortcut in shortcuts.prefix(ShortcutSlotStore.shortcutSlotCount) {
            ShortcutSlotStore.setShortcutSlot(shortcut.slot)
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
            index: max(1, min(index, ShortcutSlotStore.shortcutSlotCount)),
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
