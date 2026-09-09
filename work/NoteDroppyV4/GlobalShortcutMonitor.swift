// NoteDroppy V4 — Etape 4 du plan de migration V5
//
// Raccourcis clavier globaux (Carbon RegisterEventHotKey) pour les 20
// slots. Copie verbatim depuis NotePlanURLDrop/main.swift. Settings.X ->
// ShortcutSlotStore.X (etape 1). fourCharCode duplique en file-private ici
// (deja present pareillement en file-private dans HotkeyRecorder.swift —
// meme pattern que carbonModifiers duplique entre fichiers, cf. etape 3c).
//
// Pas encore instanciee depuis AppDelegate/MainWindowController — ce
// commit porte la classe, pas son branchement (etape suivante).

import AppKit
import Carbon
import Foundation

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

        for slot in ShortcutSlotStore.allShortcutSlots() where slot.enabled {
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

        let slot1 = ShortcutSlotStore.shortcutSlot(1)
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
                Log.write("shortcut:legacy-slot1-slash:registered")
            } else {
                Log.write("shortcut:legacy-slot1-slash:register-failed:\(registerStatus)")
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
