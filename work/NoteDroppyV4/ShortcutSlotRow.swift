// NoteDroppy V4 — Etape 3d (partie 2) du plan de migration V5
//
// Une ligne du tableau "Actif / Raccourci / Sortie / Cible / Tag & Config"
// — la piece centrale du systeme a 20 slots. Copiee verbatim depuis
// NotePlanURLDrop/main.swift (classe ShortcutSlotRow). Settings.X ->
// ShortcutSlotStore.X (etape 1) pour les appels lies aux destinations.
//
// Pas encore branchee dans une fenetre : cette etape porte la ligne et sa
// logique, pas encore l'assemblage du tableau complet (qui vivra dans
// MainWindowController ou une fenetre dediee — etape suivante, hors de ce
// commit).

import AppKit
import Foundation

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
        ShortcutSlotStore.destinations(forShortcut: slot.index).forEach { destinationPopup.addItem(withTitle: $0.title) }
        destinationPopup.selectItem(withTitle: ShortcutSlotStore.validDestination(slot.destination, for: slot.index).title)
        destinationPopup.target = self
        destinationPopup.action = #selector(destinationChanged)
        Self.outputOptions.forEach { outputPopup.addItem(withTitle: $0.title) }
        outputPopup.selectItem(withTitle: outputTitle(engine: slot.engine, destination: ShortcutSlotStore.validDestination(slot.destination, for: slot.index)))
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
        let destination = ShortcutSlotStore.validDestination(slot.destination, for: index)
        enabledCheckbox.state = slot.enabled ? .on : .off
        enabledCheckbox.title = displayIndex
        setCombo(slot.combo)
        enginePopup.selectItem(withTitle: slot.engine.title)
        destinationPopup.removeAllItems()
        ShortcutSlotStore.destinations(forShortcut: index).forEach { destinationPopup.addItem(withTitle: $0.title) }
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
        destinationPopup.selectItem(withTitle: ShortcutSlotStore.validDestination(option.destination, for: index).title)
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
        ShortcutSlotStore.validDestination(selectedOutputOption().destination, for: index)
    }

    private func selectedOutputOption() -> OutputOption {
        let selectedTitle = outputPopup.titleOfSelectedItem ?? ""
        if let option = Self.outputOptions.first(where: { $0.title == selectedTitle }) {
            let validDestination = ShortcutSlotStore.validDestination(option.destination, for: index)
            if validDestination == option.destination {
                return option
            }
            return OutputOption(title: outputTitle(engine: option.engine, destination: validDestination), engine: option.engine, destination: validDestination)
        }
        let fallbackEngine = ShortcutEngine.allCases.first { $0.title == enginePopup.titleOfSelectedItem } ?? .notePlan
        let fallbackDestination = ShortcutDestination.allCases.first { $0.title == destinationPopup.titleOfSelectedItem } ?? (index == 1 ? .today : .standard)
        let validDestination = ShortcutSlotStore.validDestination(fallbackDestination, for: index)
        return OutputOption(title: outputTitle(engine: fallbackEngine, destination: validDestination), engine: fallbackEngine, destination: validDestination)
    }

    private func outputTitle(engine: ShortcutEngine, destination: ShortcutDestination) -> String {
        if engine == .obsidian { return "Obsidian .md" }
        switch ShortcutSlotStore.validDestination(destination, for: index) {
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
