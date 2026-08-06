import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
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

    private var rootURL: URL
    private var currentFileURL: URL?
    private var loadedContent = ""

    override init() {
        let defaultRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application Support/co.noteplan.NotePlan-setapp")
        rootURL = UserDefaults.standard.string(forKey: "noteplanRoot").map(URL.init(fileURLWithPath:)) ?? defaultRoot
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildUI()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        loadToday()
        window.makeFirstResponder(textView)
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "NoteDroppy V3")
        appMenu.addItem(NSMenuItem(title: "About NoteDroppy V3", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "Changelog", action: #selector(showChangelog), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quitter NoteDroppy V3", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

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
        mainMenu.addItem(editMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "Fichier")
        fileMenu.addItem(NSMenuItem(title: "Ouvrir aujourd'hui", action: #selector(loadTodayAction), keyEquivalent: "t"))
        fileMenu.addItem(NSMenuItem(title: "Recharger", action: #selector(reloadFile), keyEquivalent: "r"))
        fileMenu.addItem(NSMenuItem(title: "Sauvegarder", action: #selector(saveFile), keyEquivalent: "s"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func buildUI() {
        window.title = "NoteDroppy V3"
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

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
        let applyButton = NSButton(title: "Appliquer", target: self, action: #selector(applyRootFromField))
        let loadButton = NSButton(title: "Charger", target: self, action: #selector(loadFileFromField))
        let todayButton = NSButton(title: "Aujourd'hui", target: self, action: #selector(loadTodayAction))
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(reloadFile))
        reloadButton.target = self
        reloadButton.action = #selector(reloadFile)
        saveButton.target = self
        saveButton.action = #selector(saveFile)
        saveButton.isEnabled = false
        let sortButton = NSButton(title: "Trier priorités", target: self, action: #selector(sortPriorities))
        let sortAtButton = NSButton(title: "Trier @", target: self, action: #selector(sortAtContext))
        let sortHashButton = NSButton(title: "Trier #", target: self, action: #selector(sortHashContext))
        let sortImportanceButton = NSButton(title: "Trier ^^", target: self, action: #selector(sortImportance))
        let sortMinutesButton = NSButton(title: "Trier --", target: self, action: #selector(sortMinutes))
        let flattenButton = NSButton(title: "Aplatir chapitres", target: self, action: #selector(flattenChapters))
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
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .controlAccentColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = self
        textView.string = ""

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .bezelBorder

        let topRow = NSStackView(views: [rootLabel, rootField, chooseButton, applyButton])
        topRow.orientation = .horizontal
        topRow.spacing = 8
        topRow.alignment = .centerY

        let fileRow = NSStackView(views: [fileLabel, fileField, loadButton])
        fileRow.orientation = .horizontal
        fileRow.spacing = 8
        fileRow.alignment = .centerY

        let actionRow = NSStackView(views: [todayButton, reloadButton, refreshButton, sortButton, sortAtButton, sortHashButton, sortImportanceButton, sortMinutesButton, flattenButton, saveButton])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8
        actionRow.alignment = .centerY

        let searchRow = NSStackView(views: [searchLabel, searchField, searchButton, time15Button, time30Button, time60Button, timeMoreButton])
        searchRow.orientation = .horizontal
        searchRow.spacing = 8
        searchRow.alignment = .centerY

        let rangeRow = NSStackView(views: [rangeStartLabel, rangeStartField, rangeEndLabel, rangeEndField, flattenRangeButton])
        rangeRow.orientation = .horizontal
        rangeRow.spacing = 8
        rangeRow.alignment = .centerY

        let header = NSStackView(views: [topRow, fileRow, actionRow, searchRow, rangeRow, pathLabel, statusLabel])
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
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14)
        ])
    }

    private func todayPath() -> String {
        "Calendar/\(todayStamp()).md"
    }

    private func todayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
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
            try validateRoot(url)
            rootURL = url
            UserDefaults.standard.set(url.path, forKey: "noteplanRoot")
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
        let path = todayPath()
        fileField.stringValue = path
        open(pathString: path, createIfMissing: true)
    }

    @objc private func loadFileFromField() {
        open(pathString: fileField.stringValue, createIfMissing: false)
    }

    private func open(pathString: String, createIfMissing: Bool) {
        do {
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
                relativePath = pathString.trimmingCharacters(in: .whitespacesAndNewlines)
                fileURL = rootURL.appendingPathComponent(relativePath)
            }
            if createIfMissing && !FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try "".write(to: fileURL, atomically: true, encoding: .utf8)
            }
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            currentFileURL = fileURL
            loadedContent = content
            textView.string = content
            pathLabel.stringValue = relativePath
            fileField.stringValue = relativePath
            window.title = "NoteDroppy V3 - \(relativePath)"
            window.makeFirstResponder(textView)
            saveButton.isEnabled = false
            status("Fichier chargé et éditable")
        } catch {
            status("Erreur ouverture: \(error.localizedDescription)")
        }
    }

    @objc private func reloadFile() {
        guard let currentFileURL else { return }
        open(pathString: currentFileURL.path.replacingOccurrences(of: rootURL.path + "/", with: ""), createIfMissing: false)
    }

    @objc private func saveFile() {
        guard let fileURL = currentFileURL else { return }
        do {
            let disk = try String(contentsOf: fileURL, encoding: .utf8)
            guard disk == loadedContent else {
                status("Le fichier a changé sur disque. Recharge avant de sauvegarder.")
                return
            }
            try backup(fileURL: fileURL, content: disk)
            try textView.string.write(to: fileURL, atomically: true, encoding: .utf8)
            loadedContent = textView.string
            saveButton.isEnabled = false
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
        alert.messageText = "NoteDroppy V3"
        alert.informativeText = """
        Version 1.0

        App macOS locale pour éditer directement les fichiers Markdown NotePlan.

        Aucun cloud. Aucune API distante. Sauvegardes locales avant écriture.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func showChangelog() {
        let changelog = """
        Changelog

        1.0
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
        - Menu About et Changelog.
        - Barre de tri: @, #, ^^, --.
        - Recherche agenda avec tranches de temps <=15, <=30, <=60, >60.
        """
        let alert = NSAlert()
        alert.messageText = "Changelog"
        alert.informativeText = changelog
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func backup(fileURL: URL, content: String) throws {
        let backupDir = rootURL.appendingPathComponent(".codex-backups")
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let relative = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "").replacingOccurrences(of: "/", with: "__")
        try content.write(to: backupDir.appendingPathComponent("\(stamp)__\(relative)"), atomically: true, encoding: .utf8)
    }

    @objc private func sortPriorities() {
        replaceEditorText(PrioritySorter.sort(textView.string))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortMinutes() {
        replaceEditorText(TaskSorter.sort(textView.string, mode: .minutes))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri -- appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortAtContext() {
        replaceEditorText(TaskSorter.sort(textView.string, mode: .atContext))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri @ appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortHashContext() {
        replaceEditorText(TaskSorter.sort(textView.string, mode: .hashTag))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri # appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortImportance() {
        replaceEditorText(TaskSorter.sort(textView.string, mode: .importance))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri ^^ appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func flattenChapters() {
        replaceEditorText(ChapterFlattener.flatten(textView.string))
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
                let flattened = ChapterFlattener.flatten(original)
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
            let results = try TaskSearch.search(rootURL: rootURL, query: searchField.stringValue, bucket: nil, scope: .calendarOnly)
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

    private func searchTimeBucket(_ bucket: TaskSearch.Bucket, label: String) {
        do {
            let results = try TaskSearch.search(rootURL: rootURL, query: searchField.stringValue, bucket: bucket, scope: .calendarAndNotes)
            showSearchResults(results, title: label)
        } catch {
            status("Erreur recherche: \(error.localizedDescription)")
        }
    }

    private func showSearchResults(_ results: [TaskSearch.Result], title: String) {
        let lines = results.map { "- \($0.text) [\($0.path):\($0.line)]" }
        let output = "# \(title)\n\n" + (lines.isEmpty ? "Aucun résultat\n" : lines.joined(separator: "\n") + "\n")
        replaceEditorText(output)
        currentFileURL = nil
        loadedContent = output
        saveButton.isEnabled = false
        pathLabel.stringValue = "Résultats de recherche non sauvegardables"
        window.title = "NoteDroppy V3 - \(title)"
        status("\(results.count) résultat(s)")
    }

    private func replaceEditorText(_ newText: String) {
        guard let storage = textView.textStorage else {
            textView.string = newText
            return
        }
        let oldText = textView.string
        let range = NSRange(location: 0, length: storage.length)
        textView.undoManager?.registerUndo(withTarget: self) { target in
            target.replaceEditorText(oldText)
        }
        storage.replaceCharacters(in: range, with: newText)
    }

    func textDidChange(_ notification: Notification) {
        saveButton.isEnabled = currentFileURL != nil && textView.string != loadedContent
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

enum PrioritySorter {
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

enum TaskSorter {
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

enum TaskSearch {
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
                guard isTaskLine(trimmed), !TaskSorter.isDone(trimmed) else { continue }
                if !normalizedQuery.isEmpty && !trimmed.lowercased().contains(normalizedQuery) { continue }
                if let bucket, !matches(bucket: bucket, minutes: TaskSorter.minutes(trimmed)) { continue }
                results.append(Result(path: rel, line: index + 1, text: trimmed))
            }
        }

        return results.sorted {
            let am = TaskSorter.minutes($0.text)
            let bm = TaskSorter.minutes($1.text)
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

enum ChapterFlattener {
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
            let item = cleanedItem(line)
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
