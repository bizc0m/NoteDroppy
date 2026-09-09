// NoteDroppy V4 — Etape 3d (partie 1) du plan de migration V5
//
// Controles AppKit "conscients du drop" utilises par ShortcutSlotRow : un
// champ texte, une pile horizontale, un menu deroulant, chacun capable
// d'accepter un depot Finder/NotePlan/Obsidian via shortcutTarget(from:)
// (etape 2). Copie verbatim depuis NotePlanURLDrop/main.swift.
// writeDebugLog(...) -> Log.write(...).

import AppKit
import Foundation

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
        Log.write("shortcut-target:paste-field:\(pasteboardPreview(from: NSPasteboard.general))")
        onPasteTarget?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Log.write("shortcut-drop:field:entered:\(pasteboardDebugDescription(sender.draggingPasteboard))")
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
        Log.write("shortcut-drop:field:perform:\(pasteboardDebugDescription(sender.draggingPasteboard))")
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
        Log.write("shortcut-drop:row:entered:\(pasteboardDebugDescription(sender.draggingPasteboard))")
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
        Log.write("shortcut-drop:row:perform:\(pasteboardDebugDescription(sender.draggingPasteboard))")
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
        Log.write("shortcut-drop:popup:entered:\(pasteboardDebugDescription(sender.draggingPasteboard))")
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
        Log.write("shortcut-drop:popup:perform:\(pasteboardDebugDescription(sender.draggingPasteboard))")
        guard acceptsDrop, let target = shortcutTarget(from: sender.draggingPasteboard) else {
            NSSound.beep()
            return false
        }
        return onDropTarget?(target) ?? false
    }
}
