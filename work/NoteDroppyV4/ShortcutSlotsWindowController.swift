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
    private let webSourcePopup = ShortcutTargetPopUpButton()
    private let fileSourcePopup = ShortcutTargetPopUpButton()
    private weak var activeTagConfigRow: ShortcutSlotRow?
    private let webSourceOptionKey = "v5.source.web"
    private let fileSourceOptionKey = "v5.source.file"

    static func show() {
        if retained == nil {
            retained = ShortcutSlotsWindowController()
        }
        retained?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private convenience init() {
        let window = centeredWindow("Note Droopy V5 — Capture", width: 1240, height: 820)
        self.init(window: window)
        router.onStatus = { [weak self] message in
            self?.statusLabel.stringValue = message
        }
        buildContent()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 12
        rootStack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 14, right: 24)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

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

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        rootStack.addArrangedSubview(makeHeroHeader())
        rootStack.addArrangedSubview(makeVariablesRow())
        rootStack.addArrangedSubview(makeOptionsRow())
        rootStack.addArrangedSubview(makeJsonToolsRow())
        rootStack.addArrangedSubview(makeColorsRow())
        rootStack.addArrangedSubview(scrollView)
        rootStack.addArrangedSubview(statusLabel)

        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            scrollView.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -48),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 500),
            statusLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -48),

            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            documentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 8),
            documentStack.trailingAnchor.constraint(lessThanOrEqualTo: document.trailingAnchor, constant: -8),
            documentStack.topAnchor.constraint(equalTo: document.topAnchor, constant: 8),
            documentStack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -8)
        ])
    }

    private func makeHeroHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 18

        let imageView = NSImageView()
        imageView.image = NSImage(named: "NoteDroppy") ?? NSApp.applicationIconImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 72).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let title = NSTextField(labelWithString: "Note Droopy")
        title.font = .systemFont(ofSize: 30, weight: .bold)
        title.textColor = .labelColor

        let tagline = NSTextField(labelWithString: "Time is precious.\nSpend it with those you love")
        tagline.font = .systemFont(ofSize: 17, weight: .semibold)
        tagline.textColor = .secondaryLabelColor
        tagline.maximumNumberOfLines = 2

        row.addArrangedSubview(imageView)
        row.addArrangedSubview(title)
        row.addArrangedSubview(tagline)
        return row
    }

    private func makeVariablesRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 4

        let label = NSTextField(labelWithString: "Variables :")
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .secondaryLabelColor
        row.addArrangedSubview(label)

        let variables = ["$date", "$day", "$time", "$datetime", "$month", "$year"]
        for (index, variable) in variables.enumerated() {
            let token = NSTextField(labelWithString: index == variables.count - 1 ? variable : "\(variable),")
            token.font = .systemFont(ofSize: 18, weight: .bold)
            token.textColor = .systemBlue
            row.addArrangedSubview(token)
        }
        return row
    }

    private func makeOptionsRow() -> NSView {
        [webSourcePopup, fileSourcePopup].forEach { popup in
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.removeAllItems()
            popup.addItems(withTitles: ["Global", "Slot actif", "Désactivé"])
            popup.acceptsDrop = false
            popup.target = self
            popup.action = #selector(sourceOptionChanged)
            popup.widthAnchor.constraint(equalToConstant: 170).isActive = true
        }
        webSourcePopup.selectItem(withTitle: storedSourceOption(forKey: webSourceOptionKey))
        fileSourcePopup.selectItem(withTitle: storedSourceOption(forKey: fileSourceOptionKey))

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 20
        row.addArrangedSubview(sectionLabel("Options -> Tags"))
        row.addArrangedSubview(sectionLabel("Source web"))
        row.addArrangedSubview(webSourcePopup)
        row.addArrangedSubview(sectionLabel("Source fichier"))
        row.addArrangedSubview(fileSourcePopup)
        row.addArrangedSubview(NSView())
        return row
    }

    private func makeColorsRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 18
        row.addArrangedSubview(sectionLabel("Couleurs"))
        row.addArrangedSubview(colorChip("#tag", color: .systemGreen))
        row.addArrangedSubview(colorChip("$variable", color: .systemBlue))
        row.addArrangedSubview(colorChip("!config", color: .systemIndigo))
        row.addArrangedSubview(colorChip("@contexte", color: .systemOrange))
        return row
    }

    private func makeJsonToolsRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.addArrangedSubview(sectionLabel("Comportements JSON"))
        row.addArrangedSubview(jsonButton(title: "Règles", symbol: "doc.badge.gearshape", action: #selector(openCaptureRulesJSON)))
        row.addArrangedSubview(jsonButton(title: "Prompts", symbol: "text.badge.plus", action: #selector(openPromptsJSON)))
        row.addArrangedSubview(jsonButton(title: "Recharger", symbol: "arrow.clockwise", action: #selector(reloadBehaviorJSON)))
        return row
    }

    private func jsonButton(title: String, symbol: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.toolTip = title
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }

    private func sectionLabel(_ value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .labelColor
        return label
    }

    private func colorChip(_ value: String, color: NSColor) -> NSTextField {
        let chip = NSTextField(labelWithString: value)
        chip.font = .systemFont(ofSize: 18, weight: .bold)
        chip.textColor = color
        chip.alignment = .center
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 6
        chip.layer?.backgroundColor = color.withAlphaComponent(0.18).cgColor
        chip.translatesAutoresizingMaskIntoConstraints = false
        chip.widthAnchor.constraint(equalToConstant: 166).isActive = true
        chip.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return chip
    }

    @objc private func sourceOptionChanged() {
        let web = webSourcePopup.titleOfSelectedItem ?? "Global"
        let file = fileSourcePopup.titleOfSelectedItem ?? "Global"
        UserDefaults.standard.set(web, forKey: webSourceOptionKey)
        UserDefaults.standard.set(file, forKey: fileSourceOptionKey)
        UserDefaults.standard.synchronize()
        Log.write("v5-source-options:saved:web:\(web):file:\(file)")
        statusLabel.stringValue = "Options source enregistrées."
    }

    private func storedSourceOption(forKey key: String) -> String {
        let value = UserDefaults.standard.string(forKey: key) ?? "Global"
        return ["Global", "Slot actif", "Désactivé"].contains(value) ? value : "Global"
    }

    @objc private func openCaptureRulesJSON() {
        Paths.seedIfMissing(resource: "capture-rules", destination: Paths.captureRulesFile)
        guard FileManager.default.fileExists(atPath: Paths.captureRulesFile.path) else {
            statusLabel.stringValue = "capture-rules.json absent."
            Log.write("v5-json:open-capture-rules:missing:\(Paths.captureRulesFile.path)")
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(Paths.captureRulesFile)
        statusLabel.stringValue = "Ouvert : capture-rules.json"
        Log.write("v5-json:open-capture-rules:\(Paths.captureRulesFile.path)")
    }

    @objc private func openPromptsJSON() {
        Paths.seedIfMissing(resource: "prompts", destination: Paths.promptsFile)
        guard FileManager.default.fileExists(atPath: Paths.promptsFile.path) else {
            statusLabel.stringValue = "prompts.json absent."
            Log.write("v5-json:open-prompts:missing:\(Paths.promptsFile.path)")
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(Paths.promptsFile)
        statusLabel.stringValue = "Ouvert : prompts.json"
        Log.write("v5-json:open-prompts:\(Paths.promptsFile.path)")
    }

    @objc private func reloadBehaviorJSON() {
        let promptResult = PromptStore.reload()
        let captureResult = CaptureRuleStore.reload()
        switch (promptResult, captureResult) {
        case (.success(let promptCount), .success(let ruleCount)):
            statusLabel.stringValue = "JSON rechargés : \(ruleCount) règle(s), \(promptCount) prompt(s)."
            Log.write("v5-json:reload:ok:rules:\(ruleCount):prompts:\(promptCount)")
        case (.failure(let error), _):
            statusLabel.stringValue = "Erreur prompts.json : \(error.localizedDescription)"
            Log.write("v5-json:reload-prompts:error:\(error.localizedDescription)")
            NSSound.beep()
        case (_, .failure(let error)):
            statusLabel.stringValue = "Erreur capture-rules.json : \(error.localizedDescription)"
            Log.write("v5-json:reload-capture-rules:error:\(error.localizedDescription)")
            NSSound.beep()
        }
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
