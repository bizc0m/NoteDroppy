// NoteDroppy V4 — Etape 6 (assemblage) du plan de migration V5
//
// Derniere piece : une fenetre qui montre les 20 ShortcutSlotRow (etape 3)
// dans un tableau defilant, branche a ShortcutTargetRouter (etape 5 partie
// 3) pour le drop/paste, a NoteSearchWindowController (etape 3b) pour la
// recherche, et qui installe GlobalShortcutMonitor (etape 4) avec
// CaptureTrigger.run (etape 5 partie 2) comme gestionnaire.
//
// Nouveau code d'assemblage, pas une copie verbatim -- SettingsWindowController
// dans l'original melange cette table avec des dizaines d'autres reglages
// (Capture, export/import, regles de capture, prompts...) dans une seule
// classe de plusieurs milliers de lignes ; refaire ce monolithe irait a
// l'encontre du but de la V5. Cette fenetre ne fait que le tableau de
// raccourcis, rien d'autre.
//
// PAS ENCORE BRANCHEE au lancement de l'app ni a un menu -- main.swift
// (AppDelegate/MainWindowController/le menu "FONCTIONS") est un fichier
// activement modifie par ailleurs sur cette branche ; y toucher a l'aveugle
// risquerait un conflit avec ce travail en cours. Deux lignes suffisent
// pour finir le branchement une fois pret :
//   1. Au lancement : `let monitor = GlobalShortcutMonitor(handler: CaptureTrigger.run)`
//      (garder une reference forte, sinon le monitor est desalloue).
//   2. Un bouton/item de menu quelque part : `ShortcutSlotsWindowController.show()`.

import AppKit
import Foundation

final class ShortcutSlotsWindowController: NSWindowController {
    private static var retained: ShortcutSlotsWindowController?

    private let router = ShortcutTargetRouter()
    private var rows: [ShortcutSlotRow] = []
    private let statusLabel = NSTextField(labelWithString: "Pret.")
    private weak var activeTagConfigRow: ShortcutSlotRow?

    static func show() {
        if retained == nil {
            retained = ShortcutSlotsWindowController()
        }
        retained?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private convenience init() {
        let window = centeredWindow("Raccourcis — NoteDroppy V4", width: 1180, height: 760)
        self.init(window: window)
        router.onStatus = { [weak self] message in
            self?.statusLabel.stringValue = message
        }
        buildContent()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentStack = NSStackView()
        documentStack.orientation = .vertical
        documentStack.alignment = .leading
        documentStack.spacing = 6
        documentStack.translatesAutoresizingMaskIntoConstraints = false

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(documentStack)

        documentStack.addArrangedSubview(ShortcutSlotRow.headerView())

        rows = (1...ShortcutSlotStore.shortcutSlotCount).map { index in
            let row = ShortcutSlotRow(slot: ShortcutSlotStore.shortcutSlot(index))
            row.onSearch = { [weak self] searchRow in
                self?.showNoteSearch(for: searchRow)
            }
            row.onTargetDrop = { [weak self] targetRow, target in
                self?.router.applyDroppedTarget(target, to: targetRow) ?? false
            }
            row.onPasteTarget = { [weak self] pasteRow in
                self?.router.pasteTarget(for: pasteRow)
            }
            row.onFocus = { [weak self] focusRow in
                self?.activeTagConfigRow?.setActive(false)
                self?.activeTagConfigRow = focusRow
                focusRow.setActive(true)
            }
            row.onChange = { [weak self] changedRow in
                ShortcutSlotStore.setShortcutSlot(changedRow.slot)
                NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                self?.statusLabel.stringValue = "Raccourci \(changedRow.index) enregistré."
            }
            documentStack.addArrangedSubview(row.view())
            return row
        }

        scrollView.documentView = document

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(scrollView)
        contentView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            documentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 8),
            documentStack.trailingAnchor.constraint(lessThanOrEqualTo: document.trailingAnchor, constant: -8),
            documentStack.topAnchor.constraint(equalTo: document.topAnchor, constant: 8),
            documentStack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -8)
        ])
    }

    private func showNoteSearch(for row: ShortcutSlotRow) {
        NoteSearchWindowController.show(initialQuery: "") { [weak self] selected in
            row.applySelectedNote(selected)
            ShortcutSlotStore.setShortcutSlot(row.slot)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            self?.statusLabel.stringValue = "Note sélectionnée : \(selected.relativePath)"
        }
    }
}
