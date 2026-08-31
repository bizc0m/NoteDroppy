// NoteDroppy V4 — Etape 3c du plan de migration V5
//
// Bouton "enregistreur de raccourci" (clique -> tape la combinaison ->
// valide) utilise par ShortcutSlotRow (etape 3d, pas encore portee), plus
// les garde-fous associes (raccourcis reserves par l'app/le systeme,
// detection de conflit). Copie verbatim depuis NotePlanURLDrop/main.swift.
// Settings.defaultShortcutCombo -> ShortcutSlotStore.defaultShortcutCombo
// (etape 1).

import AppKit
import Carbon
import Foundation

struct ShortcutConflict {
    let title: String
    let detail: String
}

private func fourCharCode(_ value: String) -> UInt32 {
    var result: UInt32 = 0
    for scalar in value.unicodeScalars.prefix(4) {
        result = (result << 8) + UInt32(scalar.value)
    }
    return result
}

/// Verifie qu'un KeyCombo peut effectivement s'enregistrer comme hotkey
/// systeme (RegisterEventHotKey), en l'enregistrant puis en le
/// desenregistrant aussitot — juste une sonde, pas un enregistrement
/// durable.
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

final class ShortcutRecorderButton: NSButton {
    fileprivate var onChange: ((KeyCombo) -> Void)?
    fileprivate var onValidate: ((KeyCombo) -> ShortcutConflict?)?
    private var localMonitor: Any?
    private var isRecording = false
    private var combo: KeyCombo

    init(combo: KeyCombo = ShortcutSlotStore.defaultShortcutCombo(1)) {
        self.combo = combo
        super.init(frame: .zero)
        title = combo.display
        bezelStyle = .rounded
        target = self
        action = #selector(beginRecording)
    }

    required init?(coder: NSCoder) {
        self.combo = ShortcutSlotStore.defaultShortcutCombo(1)
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

    func setCombo(_ combo: KeyCombo) {
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
