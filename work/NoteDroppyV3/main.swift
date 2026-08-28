import AppKit
import Darwin
import Foundation
import UniformTypeIdentifiers

private enum Settings {
    static let notesRootPathKey = "notesRootPath"
    static let notesRootBookmarkKey = "notesRootBookmark"

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
}

private let shortcutDropPasteboardTypes: [NSPasteboard.PasteboardType] = [
    .fileURL,
    .URL,
    .string,
    NSPasteboard.PasteboardType("public.file-url"),
    NSPasteboard.PasteboardType("public.url"),
    NSPasteboard.PasteboardType("public.text"),
    NSPasteboard.PasteboardType("public.utf8-plain-text"),
    NSPasteboard.PasteboardType("NSFilenamesPboardType"),
    NSPasteboard.PasteboardType("com.apple.finder.node"),
    NSPasteboard.PasteboardType("co.noteplan.notecard")
]

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

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.isSelectable = false
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.alignment = .center
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 2
        detailLabel.isSelectable = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 140),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard shortcutTarget(from: sender.draggingPasteboard) != nil else { return NSDragOperation() }
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        return preferredDragOperation(from: sender.draggingSourceOperationMask)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        shortcutTarget(from: sender.draggingPasteboard) == nil ? NSDragOperation() : preferredDragOperation(from: sender.draggingSourceOperationMask)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        resetDropStyle()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        shortcutTarget(from: sender.draggingPasteboard) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
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

private func preferredDragOperation(from mask: NSDragOperation) -> NSDragOperation {
    for operation in [NSDragOperation.copy, .link, .generic, .move] {
        if mask.contains(operation) { return operation }
    }
    return .copy
}

private func shortcutTarget(from pasteboard: NSPasteboard) -> ShortcutTarget? {
    let strings = pasteboardStrings(from: pasteboard)
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
       let url = objects.first(where: { !$0.path.hasPrefix("/.file/id=") }) {
        return ShortcutTarget(url: url)
    }
    if let existingPath = strings.lazy.compactMap({ existingFinderPath(from: $0) }).first {
        return ShortcutTarget(url: URL(fileURLWithPath: existingPath))
    }
    if let notePlanText = strings.first(where: { $0.range(of: "noteplan://", options: .caseInsensitive) != nil }) {
        return ShortcutTarget(rawText: notePlanText)
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
    else { return [] }
    return strings(fromPropertyList: plist).filter { FileManager.default.fileExists(atPath: $0) }
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
            for encoding in [String.Encoding.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .macOSRoman] {
                if let value = String(data: data, encoding: encoding)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                    values.append(value)
                }
            }
        }
    }
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
}

private func strings(fromPropertyList value: Any) -> [String] {
    if let string = value as? String {
        return [string.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
    }
    if let array = value as? [Any] {
        return array.flatMap { strings(fromPropertyList: $0) }
    }
    if let dictionary = value as? [AnyHashable: Any] {
        return dictionary.flatMap { strings(fromPropertyList: $0.key) + strings(fromPropertyList: $0.value) }
    }
    return []
}

private func existingFinderPath(from text: String) -> String? {
    let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }
    let decoded = raw.removingPercentEncoding ?? raw
    let path: String
    if let url = URL(string: decoded), url.isFileURL {
        guard !url.path.hasPrefix("/.file/id=") else { return nil }
        path = url.path
    } else {
        path = decoded
    }
    if path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) {
        return path
    }
    let patterns = [
        #"file:///(?:Users|Volumes)/[^\s<>"']+?\.md"#,
        #"/(?:Users|Volumes)/[^\n\r<>"']+?\.md"#
    ]
    for pattern in patterns {
        if let range = decoded.range(of: pattern, options: .regularExpression) {
            let candidate = String(decoded[range]).removingPercentEncoding ?? String(decoded[range])
            if let url = URL(string: candidate), url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
                return url.path
            }
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
    }
    return nil
}

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
    private var functionsWindow: NSWindow?
    private var openAfterFunctionCheckbox: NSButton?
    private var functionsStatusLabel: NSTextField?
    private var generatedShortcutURL: URL?
    private let shortcutMakerNotePathKey = "noteplanShortcutMaker.notePath"
    private let shortcutMakerNoteURLKey = "noteplanShortcutMaker.noteURL"
    private let shortcutMakerNoteDisplayKey = "noteplanShortcutMaker.noteDisplay"
    private let shortcutMakerDestinationPathKey = "noteplanShortcutMaker.destinationPath"

    private var rootURL: URL
    private var currentFileURL: URL?
    private var loadedContent = ""
    private var sourceMarkdown = ""
    private var collapsedBlockStarts = Set<Int>()
    private var initialCollapsedBlockStarts = Set<Int>()
    private var displayedSourceLines: [Int] = []
    private var isFoldView = false
    private var isApplyingHighlight = false

    private struct LoadedFile {
        let relativePath: String
        let fileURL: URL
        let content: String
    }

    override init() {
        let defaultRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application Support/co.noteplan.NotePlan-setapp")
        rootURL = Settings.selectedNotesRoot().map(Self.normalizedNotePlanRoot)
            ?? UserDefaults.standard.string(forKey: "noteplanRoot").map(URL.init(fileURLWithPath:))
            ?? defaultRoot
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildUI()
        loadTodayDirect(reason: "démarrage")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showMainWindow()
            self.loadTodayDirect(reason: "fenêtre prête")
            self.window.makeFirstResponder(self.textView)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        loadTodayDirect(reason: "reopen")
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Note Commander")
        appMenu.addItem(NSMenuItem(title: "About Note Commander", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "Changelog", action: #selector(showChangelog), keyEquivalent: ""))
        let functionsItem = NSMenuItem(title: "Fonctions Note Commander", action: #selector(showFunctionsWindow), keyEquivalent: "")
        functionsItem.target = self
        appMenu.addItem(functionsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quitter Note Commander", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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
        window.title = "Note Commander"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
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
        let applyButton = NSButton(title: "Valider dossier", target: self, action: #selector(applyRootFromField))
        let loadButton = NSButton(title: "Charger", target: self, action: #selector(loadFileFromField))
        let previousDayButton = NSButton(title: "← Jour", target: self, action: #selector(loadPreviousDay))
        let todayButton = NSButton(title: "Aujourd'hui", target: self, action: #selector(loadTodayAction))
        let nextDayButton = NSButton(title: "Jour →", target: self, action: #selector(loadNextDay))
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(reloadFile))
        reloadButton.target = self
        reloadButton.action = #selector(reloadFile)
        saveButton.target = self
        saveButton.action = #selector(saveFile)
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
        palettePopup.addItems(withTitles: MarkdownHighlighter.Palette.allCases.map(\.rawValue))
        palettePopup.selectItem(withTitle: MarkdownHighlighter.palette.rawValue)
        palettePopup.target = self
        palettePopup.action = #selector(changeMarkdownPalette(_:))
        let foldBlockButton = NSButton(title: "Plier bloc", target: self, action: #selector(foldCurrentBlock))
        let unfoldBlockButton = NSButton(title: "Déplier bloc", target: self, action: #selector(unfoldCurrentBlock))
        let foldAllButton = NSButton(title: "Tout plier", target: self, action: #selector(foldAllBlocks))
        let unfoldAllButton = NSButton(title: "Tout déplier", target: self, action: #selector(unfoldAllBlocks))
        let restoreFoldButton = NSButton(title: "État initial", target: self, action: #selector(restoreInitialFoldState))
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
        let functionsButton = NSButton(title: "FONCTIONS", target: self, action: #selector(showFunctionsWindow))
        functionsButton.bezelStyle = .rounded
        functionsButton.isBordered = false
        functionsButton.font = .systemFont(ofSize: 13, weight: .bold)
        functionsButton.wantsLayer = true
        functionsButton.layer?.backgroundColor = NSColor.systemGreen.cgColor
        functionsButton.layer?.cornerRadius = 6
        functionsButton.attributedTitle = NSAttributedString(
            string: "FONCTIONS",
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 13, weight: .bold)
            ]
        )

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
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = self
        textView.string = ""
        applySyntaxHighlighting()

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .bezelBorder

        let topRow = NSStackView(views: [rootLabel, rootField, chooseButton, applyButton, functionsButton])
        topRow.orientation = .horizontal
        topRow.spacing = 8
        topRow.alignment = .centerY

        let fileRow = NSStackView(views: [fileLabel, fileField, loadButton])
        fileRow.orientation = .horizontal
        fileRow.spacing = 8
        fileRow.alignment = .centerY

        let fileActionRow = NSStackView(views: [fileActionsLabel, previousDayButton, todayButton, nextDayButton, reloadButton, refreshButton, saveButton])
        fileActionRow.orientation = .horizontal
        fileActionRow.spacing = 8
        fileActionRow.alignment = .centerY

        let sortRow = NSStackView(views: [sortLabel, sortButton, sortAtButton, sortHashButton, sortImportanceButton, sortMinutesButton, flattenButton])
        sortRow.orientation = .horizontal
        sortRow.spacing = 8
        sortRow.alignment = .centerY

        let viewRow = NSStackView(views: [paletteLabel, palettePopup, foldBlockButton, unfoldBlockButton, foldAllButton, unfoldAllButton, restoreFoldButton])
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

        let header = NSStackView(views: [topRow, fileRow, fileActionRow, sortRow, viewRow, searchRow, rangeRow, pathLabel, statusLabel])
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
            functionsButton.widthAnchor.constraint(equalToConstant: 112),
            functionsButton.heightAnchor.constraint(equalToConstant: 28),
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

    @objc private func loadPreviousDay() {
        loadRelativeDay(offset: -1)
    }

    @objc private func loadNextDay() {
        loadRelativeDay(offset: 1)
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
                    self.applyLoadedFile(loaded, statusText: "Aujourd'hui chargé")
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
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notedroppy-\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/cp")
        process.arguments = [url.path, tempURL.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        guard wait(process: process, timeout: 4.0) else {
            process.terminate()
            throw NSError(domain: "NotePlanText", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Lecture NotePlan bloquee par macOS"
            ])
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

    private static func wait(process: Process, timeout: TimeInterval) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        return semaphore.wait(timeout: .now() + timeout) == .success
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
        currentFileURL = loaded.fileURL
        loadedContent = loaded.content
        sourceMarkdown = loaded.content
        collapsedBlockStarts.removeAll()
        initialCollapsedBlockStarts.removeAll()
        isFoldView = false
        displayedSourceLines = Array(0..<loaded.content.components(separatedBy: "\n").count)
        textView.isEditable = true
        textView.string = loaded.content
        applySyntaxHighlighting()
        pathLabel.stringValue = loaded.relativePath
        fileField.stringValue = loaded.relativePath
        window.title = "Note Commander - \(loaded.relativePath)"
        window.makeFirstResponder(textView)
        setSaveButtonState(.clean)
        status(statusText)
    }

    @objc private func reloadFile() {
        guard let currentFileURL else { return }
        open(pathString: currentFileURL.path.replacingOccurrences(of: rootURL.path + "/", with: ""), createIfMissing: false)
    }

    @objc private func saveFile() {
        guard let fileURL = currentFileURL else { return }
        do {
            if isFoldView {
                status("Déplie avant de sauvegarder: le pliage est un affichage.")
                return
            }
            let disk = try String(contentsOf: fileURL, encoding: .utf8)
            guard disk == loadedContent else {
                status("Le fichier a changé sur disque. Recharge avant de sauvegarder.")
                return
            }
            try backup(fileURL: fileURL, content: disk)
            let markdown = currentEditorMarkdown()
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            loadedContent = markdown
            sourceMarkdown = markdown
            setSaveButtonState(.saved)
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
        alert.messageText = "Note Commander"
        alert.informativeText = """
        Version 3.7

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

    @objc private func showFunctionsWindow() {
        if let functionsWindow {
            functionsWindow.makeKeyAndOrderFront(nil)
            functionsWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let infoWindow = NSWindow(
            contentRect: NSRect(x: 220, y: 160, width: 820, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        infoWindow.isReleasedWhenClosed = false
        infoWindow.title = "Fonctions Note Commander"

        let titleLabel = NSTextField(labelWithString: "Fonctions")
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)

        let subtitleLabel = NSTextField(labelWithString: "Actions locales. Les écritures NotePlan demandent une validation avant modification.")
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping

        let openCheckbox = NSButton(checkboxWithTitle: "Ouvrir NotePlan après action", target: self, action: #selector(toggleOpenAfterFunction))
        openCheckbox.state = UserDefaults.standard.bool(forKey: "functionsOpenNotePlanAfterAction") ? .on : .off
        openAfterFunctionCheckbox = openCheckbox

        let dropView = ShortcutMakerDropView()
        dropView.translatesAutoresizingMaskIntoConstraints = false
        dropView.onDropTarget = { [weak self] target in
            self?.applyFunctionShortcutDrop(target) ?? false
        }
        dropView.widthAnchor.constraint(equalToConstant: 760).isActive = true

        let functionStatus = NSTextField(labelWithString: "Prêt.")
        functionStatus.textColor = .secondaryLabelColor
        functionStatus.lineBreakMode = .byWordWrapping
        functionStatus.maximumNumberOfLines = 3
        functionsStatusLabel = functionStatus

        let noteDroppyRows = [
            functionRow(title: "Ajouter une tâche à aujourd’hui", detail: "Demande le texte, confirme, puis ajoute dans Calendar/\(todayStamp()).md.", action: #selector(addTaskToToday)),
            functionRow(title: "Ajouter une URL à aujourd’hui", detail: "Demande une URL et écrit le serveur avant le lien.", action: #selector(addURLToToday)),
            functionRow(title: "Ajouter du texte sélectionné à aujourd’hui", detail: "Récupère le texte du presse-papiers courant, demande validation, puis ajoute.", action: #selector(addSelectedTextToToday)),
            functionRow(title: "Rechercher dans les notes", detail: "Cherche localement dans Calendar et Notes.", action: #selector(searchNotesFromFunctions))
        ]

        let promptRows = [
            functionRow(title: "Créer un deeplink IA", detail: "Prend une URL ChatGPT, Claude ou Perplexity, génère une ref et copie le Markdown NotePlan.", action: #selector(generateAIDeeplink)),
            functionRow(title: "Choisir l’index prompts", detail: "Définit le fichier ou dossier d’index utilisé par la recherche prompts.", action: #selector(choosePromptIndexPath)),
            functionRow(title: "Recherche booléenne prompts", detail: "Cherche dans l’index prompts avec AND, OR, NOT, guillemets et parenthèses.", action: #selector(booleanSearchPromptIndex))
        ]

        let shortyRows = [
            functionRow(title: "Choisir une note `.md`", detail: "Sélectionne une note Markdown source.", action: #selector(chooseShortcutNote)),
            functionRow(title: "Choisir une destination", detail: "Sélectionne un dossier destination pour le raccourci.", action: #selector(chooseShortcutDestination)),
            functionRow(title: "Générer un raccourci `.app`", detail: "Choisit note et destination, confirme le remplacement, puis génère le .app.", action: #selector(generateShortcutApp)),
            functionRow(title: "Confirmer avant remplacement", detail: "Intégré au générateur: aucun remplacement sans accord.", action: #selector(generateShortcutApp)),
            functionRow(title: "Révéler le raccourci généré dans Finder", detail: "Sélectionne le dernier .app généré dans Finder.", action: #selector(revealGeneratedShortcut))
        ]

        let noteDroppySection = section(title: "NOTE DROPPY", rows: noteDroppyRows + [openCheckbox])
        let promptSection = section(title: "DEEPLINK / PROMPTS", rows: promptRows)
        let shortySection = section(title: "NOTEPLANSHORTY", rows: [dropView] + shortyRows)

        let stack = NSStackView(views: [titleLabel, subtitleLabel, functionStatus, noteDroppySection, promptSection, shortySection])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        infoWindow.contentView = content
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
            subtitleLabel.widthAnchor.constraint(equalToConstant: 760)
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
        let pasteboardURL = NSPasteboard.general.string(forType: .string).flatMap { URLLineFormatter.normalizedWebURL($0) } ?? ""
        guard let text = promptText(title: "Ajouter une URL", message: "URL", defaultValue: pasteboardURL) else {
            status("Ajout URL annulé")
            return
        }
        guard let normalized = URLLineFormatter.normalizedWebURL(text) else {
            status("URL invalide")
            return
        }
        let task = "- [ ] \(URLLineFormatter.withHostPrefix(normalized))"
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
            let results = try TaskSearch.search(rootURL: rootURL, query: query, bucket: nil, scope: .calendarAndNotes)
            showSearchResults(results, title: "Recherche Calendar + Notes")
        } catch {
            status("Erreur recherche: \(error.localizedDescription)")
        }
    }

    @objc private func generateAIDeeplink() {
        let clipboardURL = NSPasteboard.general.string(forType: .string).flatMap { AIConversationDeeplink.normalizedConversationURL($0) } ?? ""
        guard let url = promptText(title: "Créer un deeplink IA", message: "URL ChatGPT, Claude ou Perplexity", defaultValue: clipboardURL) else {
            status("Deeplink annulé")
            return
        }
        guard let title = promptText(title: "Titre NotePlan", message: "Titre du lien", defaultValue: "Conversation IA") else {
            status("Deeplink annulé")
            return
        }
        do {
            let deeplink = try AIConversationDeeplink.generate(urlString: url, title: title)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(deeplink.markdown, forType: .string)
            showPlainText(title: "Deeplink copié", text: "\(deeplink.markdown)\n\nAncre à coller dans la conversation:\n[\(deeplink.ref)]")
            status("Deeplink copié: \(deeplink.ref)")
        } catch {
            status("Erreur deeplink: \(error.localizedDescription)")
        }
    }

    @objc private func choosePromptIndexPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = promptIndexURL().deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: "promptIndexPath")
            status("Index prompts: \(url.path)")
        }
    }

    @objc private func booleanSearchPromptIndex() {
        guard let query = promptText(title: "Recherche booléenne prompts", message: "Exemple: claude AND (noteplan OR deeplink) NOT archive", defaultValue: searchField.stringValue) else {
            status("Recherche prompts annulée")
            return
        }
        searchField.stringValue = query
        do {
            let indexURL = promptIndexURL()
            let results = try PromptIndexSearch.search(indexURL: indexURL, query: query)
            showPromptSearchResults(results, title: "Recherche prompts", indexURL: indexURL)
        } catch {
            status("Erreur recherche prompts: \(error.localizedDescription)")
        }
    }

    @objc private func chooseShortcutNote() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }
        panel.directoryURL = rootURL.appendingPathComponent("Notes")
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: shortcutMakerNotePathKey)
            UserDefaults.standard.removeObject(forKey: shortcutMakerNoteURLKey)
            UserDefaults.standard.set(url.path, forKey: shortcutMakerNoteDisplayKey)
            UserDefaults.standard.synchronize()
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
            UserDefaults.standard.set(url.path, forKey: shortcutMakerDestinationPathKey)
            UserDefaults.standard.synchronize()
            status("Destination choisie: \(url.path)")
        }
    }

    @objc private func generateShortcutApp() {
        let notePlanURL = UserDefaults.standard.string(forKey: shortcutMakerNoteURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let notePath = UserDefaults.standard.string(forKey: shortcutMakerNotePathKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if notePlanURL.isEmpty && !FileManager.default.fileExists(atPath: notePath) {
            chooseShortcutNote()
        }
        let refreshedNotePlanURL = UserDefaults.standard.string(forKey: shortcutMakerNoteURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let refreshedNotePath = UserDefaults.standard.string(forKey: shortcutMakerNotePathKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !refreshedNotePlanURL.isEmpty || FileManager.default.fileExists(atPath: refreshedNotePath) else {
            status("Aucune note choisie")
            return
        }

        let destinationURL: URL
        if let saved = UserDefaults.standard.string(forKey: shortcutMakerDestinationPathKey) {
            destinationURL = URL(fileURLWithPath: saved)
        } else {
            chooseShortcutDestination()
            guard let saved = UserDefaults.standard.string(forKey: shortcutMakerDestinationPathKey) else { return }
            destinationURL = URL(fileURLWithPath: saved)
        }

        do {
            let result: ShortcutResult
            if !refreshedNotePlanURL.isEmpty {
                result = try NotePlanShortcutGenerator.generate(
                    noteURLString: refreshedNotePlanURL,
                    appName: shortcutMakerAppName(fromNotePlanURL: refreshedNotePlanURL),
                    destinationURL: destinationURL,
                    confirmReplace: confirmShortcutReplacement(appURL:)
                )
            } else {
                result = try NotePlanShortcutGenerator.generate(
                    noteURL: URL(fileURLWithPath: refreshedNotePath),
                    destinationURL: destinationURL,
                    confirmReplace: confirmShortcutReplacement(appURL:)
                )
            }
            generatedShortcutURL = result.appURL
            status("Raccourci généré: \(result.appURL.path)")
            askRevealShortcut(result.appURL)
        } catch NotePlanShortcutError.cancelled {
            status("Génération annulée")
        } catch {
            status("Erreur raccourci: \(error.localizedDescription)")
        }
    }

    private func applyFunctionShortcutDrop(_ target: ShortcutTarget) -> Bool {
        if let url = target.url {
            if url.scheme?.lowercased() == "noteplan" {
                let urlString = url.absoluteString
                UserDefaults.standard.set(urlString, forKey: shortcutMakerNoteURLKey)
                UserDefaults.standard.removeObject(forKey: shortcutMakerNotePathKey)
                UserDefaults.standard.set("NotePlan : \(shortcutMakerAppName(fromNotePlanURL: urlString))", forKey: shortcutMakerNoteDisplayKey)
                UserDefaults.standard.synchronize()
                status("NotePlan enregistré: \(shortcutMakerAppName(fromNotePlanURL: urlString))")
                generateShortcutApp()
                return true
            }
            if url.isFileURL, url.pathExtension.lowercased() == "md" {
                UserDefaults.standard.set(url.standardizedFileURL.path, forKey: shortcutMakerNotePathKey)
                UserDefaults.standard.removeObject(forKey: shortcutMakerNoteURLKey)
                UserDefaults.standard.set(url.standardizedFileURL.path, forKey: shortcutMakerNoteDisplayKey)
                UserDefaults.standard.synchronize()
                status("Note choisie: \(url.lastPathComponent)")
                generateShortcutApp()
                return true
            }
        }

        if let text = target.rawText {
            if let notePlanURL = notePlanURLCandidate(from: text) {
                UserDefaults.standard.set(notePlanURL, forKey: shortcutMakerNoteURLKey)
                UserDefaults.standard.removeObject(forKey: shortcutMakerNotePathKey)
                UserDefaults.standard.set("NotePlan : \(shortcutMakerAppName(fromNotePlanURL: notePlanURL))", forKey: shortcutMakerNoteDisplayKey)
                UserDefaults.standard.synchronize()
                status("NotePlan enregistré: \(shortcutMakerAppName(fromNotePlanURL: notePlanURL))")
                generateShortcutApp()
                return true
            }
            if let path = existingFinderPath(from: text), path.lowercased().hasSuffix(".md") {
                UserDefaults.standard.set(path, forKey: shortcutMakerNotePathKey)
                UserDefaults.standard.removeObject(forKey: shortcutMakerNoteURLKey)
                UserDefaults.standard.set(path, forKey: shortcutMakerNoteDisplayKey)
                UserDefaults.standard.synchronize()
                status("Note choisie: \(URL(fileURLWithPath: path).lastPathComponent)")
                generateShortcutApp()
                return true
            }
        }

        status("Dépose une note .md ou un lien noteplan://")
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

    private func promptIndexURL() -> URL {
        if let saved = UserDefaults.standard.string(forKey: "promptIndexPath"), !saved.isEmpty {
            return URL(fileURLWithPath: saved)
        }
        return URL(fileURLWithPath: "/Users/JOB/#DEV/prompt-index.md")
    }

    private func showPlainText(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

    private func functionsSummaryText() -> String {
        """
        NOTE DROPPY
        Repository:
        https://github.com/bizc0m/NoteDroppy

        Version integree:
        - NoteDroppy V3
        - version: 3.7
        - build: 370
        - bundle id: local.codex.notedroppy.v3
        - source: work/NoteDroppyV3/main.swift
        - commit integre: d7f1a2f puis correctifs V3

        Fonctions historiques NoteDroppy conservees/documentees:
        - App macOS AppKit locale.
        - Ajout rapide de tache dans la note du jour NotePlan.
        - Format d'envoi historique: - [ ] <contenu> #capture.
        - URL NotePlan historique: noteplan://x-callback-url/addText?noteDate=today.
        - Drag & drop Dock:
          - URL web.
          - fichier .webloc ou .url.
          - fichier texte, .md, .rtf ou .textclipping.
        - Texte selectionne:
          - Service macOS NotePlan : ajouter en tache.
          - raccourci global configurable.
        - Reglages historiques:
          - nom du Service macOS.
          - tag ajoute a la tache.
          - ouverture de NotePlan apres ajout.
          - 10 raccourcis globaux configurables.
          - destinations NotePlan: Aujourd'hui, note nommee, chemin de note.
          - destination Obsidian beta par ecriture directe dans un vault.
          - recherche directe dans les notes NotePlan depuis les lignes de raccourci.
          - bouton vers Accessibilite macOS.

        Fonctions NoteDroppy V3 ajoutees:
        - Ouverture automatique de Calendar/YYYYMMDD.md.
        - Choix du dossier NotePlan.
        - Chargement manuel d'un fichier .md.
        - Edition texte native.
        - Sauvegarde avec backup local dans .codex-backups.
        - Refresh / Recharger.
        - Undo / Redo via menu Edition.
        - About / Changelog.
        - Aplatir chapitres.
        - Aplatir plage de jours.
        - Trier priorites: !!! puis !! puis !.
        - Trier par contexte @.
        - Trier par tag #.
        - Trier par importance ^^ A/B/C ou ^^ 1/2/3.
        - Trier par duree -- minutes.
        - Recherche texte limitee a l'agenda Calendar.
        - Recherche de taches par tranches dans Calendar + Notes:
          <=15, <=30, <=60, >60.
        - Format URL: nom du serveur puis lien.
          Exemple: poney.com https://poney.com/page


        NOTEPLANSHORTY
        Repository:
        https://github.com/bizc0m/NoteplanShorty

        Versions detectees:
        - main: d290111a67f24411be45bcb5a267cd5ae7c59a82
        - v1 branch: d290111a67f24411be45bcb5a267cd5ae7c59a82
        - v2 branch: a67d50adde5b0f5d6abbbeb2a807e2eb64f86186
        - v3 branch: 18e188afe6e16aee4a46a608ec9744aa9cf5d930

        Source active documentee:
        - Sources/NotePlanShortcutMaker/main_v2.0.swift
        - version source: v2.0
        - fichier archive: main_v1.0.swift
        - bundle genere: NotePlan Shortcut Maker.app
        - bundle id: dev.local.noteplan-shortcut-maker

        Fonctions NoteplanShorty v2.0:
        - App macOS SwiftUI minimale.
        - Cree un raccourci .app depuis une note NotePlan .md.
        - Une note deposee cree un raccourci du meme nom.
        - Exemple:
          TODO Suisse.md -> DESTINATION/TODO Suisse.app
        - URL generee:
          noteplan://x-callback-url/openNote?noteTitle=<nom encode>
        - La note .md n'est jamais modifiee, copiee ou deplacee.
        - Choisir destination.
        - Drop Finder robuste via NSView AppKit native.
        - registerForDraggedTypes + NSPasteboard.readObjects.
        - Evite SwiftUI .onDrop / NSItemProvider juge fragile.
        - Bouton Choisir une note .md.
        - Confirmation avant remplacement si Nom.app existe.
        - Bouton Reveler le raccourci.
        - Mode CLI cache:
          --cli-generate note.md dest/
        - Meme generateur pour drop, bouton et CLI.
        - Gestion Unicode NFC pour noms accentues.
        - Ecriture plist via PropertyListSerialization.
        - Renommage final via syscall rename() pour conserver les octets NFC.

        Verification NoteplanShorty documentee:
        - swift build -c release OK.
        - test-generation.sh OK.
        - verifie TODO Suisse.app.
        - verifie absence de TODO Suisse 2.app en regeneration.
        - verifie CFBundleName.
        - verifie CFBundleDisplayName.
        - verifie NotePlanShortcutURL.
        - verifie cas accentue: Ete & idees / Été & idées.
        - drag Finder reel teste manuellement/GUI dans la version documentee.
        - non verifie dans la source: ouverture finale dans NotePlan.app.
        """
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
        replaceEditorText(PrioritySorter.sort(currentEditorMarkdown()))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortMinutes() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(TaskSorter.sort(currentEditorMarkdown(), mode: .minutes))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri -- appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortAtContext() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(TaskSorter.sort(currentEditorMarkdown(), mode: .atContext))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri @ appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortHashContext() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(TaskSorter.sort(currentEditorMarkdown(), mode: .hashTag))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri # appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func sortImportance() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(TaskSorter.sort(currentEditorMarkdown(), mode: .importance))
        textDidChange(Notification(name: NSText.didChangeNotification))
        status("Tri ^^ appliqué en mémoire. Clique Sauvegarder pour écrire.")
    }

    @objc private func flattenChapters() {
        guard ensureEditableMarkdownView() else { return }
        replaceEditorText(ChapterFlattener.flatten(currentEditorMarkdown()))
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
        let lines = results.map { "- \(URLLineFormatter.withHostPrefix($0.text)) [\($0.path):\($0.line)]" }
        let output = "# \(title)\n\n" + (lines.isEmpty ? "Aucun résultat\n" : lines.joined(separator: "\n") + "\n")
        replaceEditorText(output)
        currentFileURL = nil
        loadedContent = output
        setSaveButtonState(.clean)
        pathLabel.stringValue = "Résultats de recherche non sauvegardables"
        window.title = "Note Commander - \(title)"
        status("\(results.count) résultat(s)")
    }

    private func showPromptSearchResults(_ results: [PromptIndexSearch.Result], title: String, indexURL: URL) {
        let lines = results.map { "- \($0.text) [\($0.path):\($0.line)]" }
        let output = "# \(title)\n\nIndex: \(indexURL.path)\n\n" + (lines.isEmpty ? "Aucun résultat\n" : lines.joined(separator: "\n") + "\n")
        replaceEditorText(output)
        currentFileURL = nil
        loadedContent = output
        setSaveButtonState(.clean)
        pathLabel.stringValue = "Résultats prompts non sauvegardables"
        window.title = "Note Commander - \(title)"
        status("\(results.count) résultat(s) prompts")
    }

    private func replaceEditorText(_ newText: String) {
        guard ensureEditableMarkdownView() else { return }
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
        sourceMarkdown = newText
        applySyntaxHighlighting()
    }

    func textDidChange(_ notification: Notification) {
        if !isApplyingHighlight && !isFoldView {
            sourceMarkdown = textView.string
        }
        applySyntaxHighlighting()
        setSaveButtonState(currentFileURL != nil && currentEditorMarkdown() != loadedContent ? .dirty : .clean)
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        NSWorkspace.shared.open(url)
        status("Lien ouvert: \(url.absoluteString)")
        return true
    }

    @objc private func changeMarkdownPalette(_ sender: NSPopUpButton) {
        if let title = sender.selectedItem?.title, let palette = MarkdownHighlighter.Palette(rawValue: title) {
            MarkdownHighlighter.palette = palette
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
        applySyntaxHighlighting()
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
        if isFoldView {
            status("Déplie avant modification: le Markdown complet est protégé.")
            return false
        }
        return true
    }

    private func currentEditorMarkdown() -> String {
        isFoldView ? sourceMarkdown : textView.string
    }

    private func sourceLines() -> [String] {
        sourceMarkdown.components(separatedBy: "\n")
    }

    private func currentSourceLineIndex() -> Int {
        let selected = textView.selectedRange().location
        let visible = textView.string as NSString
        let clamped = min(max(selected, 0), visible.length)
        let prefix = visible.substring(with: NSRange(location: 0, length: clamped))
        let displayLine = prefix.reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
        guard displayLine >= 0, displayLine < displayedSourceLines.count else {
            return min(displayLine, max(sourceLines().count - 1, 0))
        }
        return displayedSourceLines[displayLine]
    }

    private func renderFoldView(statusText: String) {
        sourceMarkdown = currentEditorMarkdown()
        let result = foldedMarkdown(lines: sourceLines(), collapsed: collapsedBlockStarts)
        isFoldView = !collapsedBlockStarts.isEmpty
        displayedSourceLines = result.sourceLineIndexes
        textView.isEditable = !isFoldView
        textView.string = result.text
        applySyntaxHighlighting()
        setSaveButtonState(currentFileURL != nil && sourceMarkdown != loadedContent ? .dirty : .clean)
        status(isFoldView ? "\(statusText) - affichage seul, Markdown conservé" : statusText)
    }

    private func foldedMarkdown(lines: [String], collapsed: Set<Int>) -> (text: String, sourceLineIndexes: [Int]) {
        var visible: [String] = []
        var map: [Int] = []
        var hiddenUntilIndent: Int?
        for index in lines.indices {
            let indent = lineIndent(lines[index])
            if let hiddenIndent = hiddenUntilIndent {
                if lines[index].trimmingCharacters(in: .whitespaces).isEmpty || indent > hiddenIndent {
                    continue
                }
                hiddenUntilIndent = nil
            }
            let marker: String
            if hasChildLine(after: index, in: lines) {
                marker = collapsed.contains(index) ? "▸ " : "▾ "
            } else {
                marker = ""
            }
            visible.append(marker + lines[index])
            map.append(index)
            if collapsed.contains(index) {
                hiddenUntilIndent = indent
            }
        }
        return (visible.joined(separator: "\n"), map)
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
    }

    private func setSaveButtonState(_ state: SaveButtonState) {
        switch state {
        case .clean:
            styleButton(saveButton, title: "Sauvegarder", background: .controlColor, foreground: .secondaryLabelColor, enabled: false)
        case .dirty:
            styleButton(saveButton, title: "Sauvegarder", background: .systemOrange, foreground: .white, enabled: true)
        case .saved:
            styleButton(saveButton, title: "Sauvegardé", background: .systemGreen, foreground: .white, enabled: true)
        }
    }

    private func styleButton(_ button: NSButton, title: String, background: NSColor, foreground: NSColor, enabled: Bool) {
        button.isEnabled = enabled
        button.bezelStyle = .rounded
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
        let selectedRanges = textView.selectedRanges
        MarkdownHighlighter.apply(to: storage)
        textView.selectedRanges = selectedRanges
        isApplyingHighlight = false
    }

    private func status(_ text: String) {
        statusLabel.stringValue = text
        functionsStatusLabel?.stringValue = text
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
            let item = URLLineFormatter.withHostPrefix(cleanedItem(line))
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

enum URLLineFormatter {
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

enum AIConversationDeeplink {
    struct Result {
        let ref: String
        let markdown: String
    }

    static func normalizedConversationURL(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("claude://") else {
            return nil
        }
        guard trimmed.contains("chatgpt.com/") || trimmed.contains("claude.ai/") || trimmed.contains("perplexity.ai/") else {
            return nil
        }
        return trimmed
    }

    static func generate(urlString: String, title: String) throws -> Result {
        guard let normalized = normalizedConversationURL(urlString) else {
            throw NSError(domain: "AIConversationDeeplink", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL ChatGPT, Claude ou Perplexity invalide"])
        }
        let ref = makeRef()
        let label = clientLabel(for: normalized)
        let base = stripHash(normalized)
        let resumeURL: String
        if label == "Claude", base.hasPrefix("https://claude.ai/chat/") {
            resumeURL = "claude://" + String(base.dropFirst("https://".count)) + "#\(ref)"
        } else {
            resumeURL = base + "#\(ref)"
        }
        let safeTitle = normalizeTitle(title)
        let markdown = "- [\(safeTitle)](\(resumeURL)) - \(ref) - \(label)\n  Ancre: `[\(ref)]`"
        return Result(ref: ref, markdown: markdown)
    }

    private static func makeRef() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let day = formatter.string(from: Date())
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var suffix = ""
        for _ in 0..<3 {
            suffix.append(letters[Int(arc4random_uniform(UInt32(letters.count)))])
        }
        return "\(day)-\(suffix)"
    }

    private static func clientLabel(for url: String) -> String {
        if url.contains("claude.ai/") || url.hasPrefix("claude://") {
            return "Claude"
        }
        if url.contains("chatgpt.com/") {
            return "ChatGPT"
        }
        if url.contains("perplexity.ai/") {
            return "Perplexity"
        }
        return "IA"
    }

    private static func stripHash(_ value: String) -> String {
        String(value.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    private static func normalizeTitle(_ value: String) -> String {
        let collapsed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return String(collapsed.prefix(60))
    }
}

enum PromptIndexSearch {
    struct Result {
        let path: String
        let line: Int
        let text: String
    }

    static func search(indexURL: URL, query: String) throws -> [Result] {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: indexURL.path, isDirectory: &isDir) else {
            throw NSError(domain: "PromptIndexSearch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Index prompts introuvable: \(indexURL.path)"])
        }
        let matcher = try BooleanQueryParser.parse(query)
        let files = isDir.boolValue ? markdownLikeFiles(in: indexURL) : [indexURL]
        var results: [Result] = []
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let relative = isDir.boolValue ? file.path.replacingOccurrences(of: indexURL.path + "/", with: "") : file.lastPathComponent
            for (idx, line) in content.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if matcher.matches(trimmed) {
                    results.append(Result(path: relative, line: idx + 1, text: trimmed))
                    if results.count >= 300 { return results }
                }
            }
        }
        return results
    }

    private static func markdownLikeFiles(in root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let allowed = Set(["md", "txt", "json", "jsonl"])
        var output: [URL] = []
        for case let file as URL in enumerator {
            let path = file.path
            if path.contains("/.git/") || path.contains("/node_modules/") || path.contains("/releases/") || path.contains("/DerivedData/") {
                continue
            }
            if allowed.contains(file.pathExtension.lowercased()) {
                output.append(file)
            }
        }
        return output.sorted { $0.path < $1.path }
    }
}

indirect enum BooleanQuery {
    case term(String)
    case not(BooleanQuery)
    case and(BooleanQuery, BooleanQuery)
    case or(BooleanQuery, BooleanQuery)

    func matches(_ text: String) -> Bool {
        let foldedText = Self.fold(text)
        switch self {
        case .term(let value):
            return foldedText.contains(Self.fold(value))
        case .not(let query):
            return !query.matches(text)
        case .and(let left, let right):
            return left.matches(text) && right.matches(text)
        case .or(let left, let right):
            return left.matches(text) || right.matches(text)
        }
    }

    private static func fold(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
    }
}

enum BooleanQueryParser {
    enum Token: Equatable {
        case word(String)
        case and
        case or
        case not
        case lparen
        case rparen
    }

    static func parse(_ raw: String) throws -> BooleanQuery {
        let tokens = tokenize(raw)
        guard !tokens.isEmpty else {
            throw NSError(domain: "BooleanQueryParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recherche vide"])
        }
        var parser = Parser(tokens: tokens)
        let query = try parser.parseExpression()
        guard parser.isAtEnd else {
            throw NSError(domain: "BooleanQueryParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expression booléenne invalide"])
        }
        return query
    }

    private static func tokenize(_ raw: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var quoted = false

        func flush() {
            let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
            current = ""
            guard !value.isEmpty else { return }
            switch value.uppercased() {
            case "AND":
                tokens.append(.and)
            case "OR":
                tokens.append(.or)
            case "NOT":
                tokens.append(.not)
            default:
                tokens.append(.word(value))
            }
        }

        for char in raw {
            if char == "\"" {
                if quoted {
                    flush()
                    quoted = false
                } else {
                    flush()
                    quoted = true
                }
            } else if quoted {
                current.append(char)
            } else if char == "(" {
                flush()
                tokens.append(.lparen)
            } else if char == ")" {
                flush()
                tokens.append(.rparen)
            } else if char.isWhitespace {
                flush()
            } else {
                current.append(char)
            }
        }
        flush()
        return insertImplicitAnd(tokens)
    }

    private static func insertImplicitAnd(_ tokens: [Token]) -> [Token] {
        var output: [Token] = []
        for token in tokens {
            if let previous = output.last, needsImplicitAnd(after: previous, before: token) {
                output.append(.and)
            }
            output.append(token)
        }
        return output
    }

    private static func needsImplicitAnd(after left: Token, before right: Token) -> Bool {
        let leftIsValue = {
            if case .word = left { return true }
            return left == .rparen
        }()
        let rightIsValue = {
            if case .word = right { return true }
            return right == .lparen || right == .not
        }()
        return leftIsValue && rightIsValue
    }

    private struct Parser {
        var tokens: [Token]
        var index = 0
        var isAtEnd: Bool { index >= tokens.count }

        mutating func parseExpression() throws -> BooleanQuery {
            try parseOr()
        }

        mutating private func parseOr() throws -> BooleanQuery {
            var expr = try parseAnd()
            while match(.or) {
                expr = .or(expr, try parseAnd())
            }
            return expr
        }

        mutating private func parseAnd() throws -> BooleanQuery {
            var expr = try parseUnary()
            while match(.and) {
                expr = .and(expr, try parseUnary())
            }
            return expr
        }

        mutating private func parseUnary() throws -> BooleanQuery {
            if match(.not) {
                return .not(try parseUnary())
            }
            return try parsePrimary()
        }

        mutating private func parsePrimary() throws -> BooleanQuery {
            if isAtEnd {
                throw NSError(domain: "BooleanQueryParser", code: 3, userInfo: [NSLocalizedDescriptionKey: "Terme manquant"])
            }
            let token = tokens[index]
            index += 1
            switch token {
            case .word(let value):
                return .term(value)
            case .lparen:
                let expr = try parseExpression()
                guard match(.rparen) else {
                    throw NSError(domain: "BooleanQueryParser", code: 4, userInfo: [NSLocalizedDescriptionKey: "Parenthèse fermante manquante"])
                }
                return expr
            default:
                throw NSError(domain: "BooleanQueryParser", code: 5, userInfo: [NSLocalizedDescriptionKey: "Terme booléen invalide"])
            }
        }

        mutating private func match(_ token: Token) -> Bool {
            guard !isAtEnd, tokens[index] == token else { return false }
            index += 1
            return true
        }
    }
}

enum NotePlanShortcutError: LocalizedError {
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

struct ShortcutResult {
    let noteName: String
    let noteURLString: String
    let appURL: URL
}

struct NotePlanShortcutGenerator {
    static func generate(
        noteURL: URL,
        destinationURL: URL,
        confirmReplace: (URL) -> Bool = { _ in true }
    ) throws -> ShortcutResult {
        guard noteURL.pathExtension.lowercased() == "md" else {
            throw NotePlanShortcutError.notMarkdown
        }

        let noteName = noteURL.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
        guard !noteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NotePlanShortcutError.emptyNoteName
        }

        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let appURL = destinationURL.appendingPathComponent("\(noteName).app", isDirectory: true)
        if FileManager.default.fileExists(atPath: appURL.path) {
            guard confirmReplace(appURL) else {
                throw NotePlanShortcutError.cancelled
            }
            try FileManager.default.removeItem(at: appURL)
        }

        let noteURLString = "noteplan://x-callback-url/openNote?noteTitle=\(urlEncode(noteName))"
        let finalAppPath = destinationURL.path + "/" + noteName + ".app"
        try compileShortcutApp(
            noteURLString: noteURLString,
            appName: noteName,
            finalAppPath: finalAppPath,
            destinationDir: destinationURL
        )
        try verify(appURL: appURL, noteName: noteName, noteURLString: noteURLString)

        return ShortcutResult(noteName: noteName, noteURLString: noteURLString, appURL: appURL)
    }

    static func generate(
        noteURLString: String,
        appName: String,
        destinationURL: URL,
        confirmReplace: (URL) -> Bool = { _ in true }
    ) throws -> ShortcutResult {
        guard URLComponents(string: noteURLString)?.scheme?.lowercased() == "noteplan" else {
            throw NotePlanShortcutError.commandFailed("URL NotePlan invalide.")
        }

        let noteName = sanitizedAppName(appName)
        guard !noteName.isEmpty else {
            throw NotePlanShortcutError.emptyNoteName
        }

        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let appURL = destinationURL.appendingPathComponent("\(noteName).app", isDirectory: true)
        if FileManager.default.fileExists(atPath: appURL.path) {
            guard confirmReplace(appURL) else {
                throw NotePlanShortcutError.cancelled
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

        return ShortcutResult(noteName: noteName, noteURLString: noteURLString, appURL: appURL)
    }

    private static func sanitizedAppName(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:")
        let cleaned = value
            .components(separatedBy: forbidden)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
        return cleaned.isEmpty ? "NotePlan Shortcut" : cleaned
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
        } catch {
            try? FileManager.default.removeItem(at: tempAppURL)
            throw error
        }
    }

    private static func setPlistStrings(_ values: [String: String], plistURL: URL) throws {
        let data = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NotePlanShortcutError.commandFailed("Info.plist illisible: \(plistURL.path)")
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
            throw NotePlanShortcutError.commandFailed("rename() a échoué: \(String(cString: strerror(errno)))")
        }
    }

    private static func verify(appURL: URL, noteName: String, noteURLString: String) throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: le dossier .app n'existe pas.")
        }
        guard appURL.lastPathComponent == "\(noteName).app" else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: nom .app incorrect.")
        }

        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let bundleName = try plistValue("CFBundleName", plistURL: plistURL)
        let displayName = try plistValue("CFBundleDisplayName", plistURL: plistURL)
        let storedURL = try plistValue("NotePlanShortcutURL", plistURL: plistURL)

        guard bundleName == noteName else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: CFBundleName incorrect.")
        }
        guard displayName == noteName else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: CFBundleDisplayName incorrect.")
        }
        guard storedURL == noteURLString else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: URL NotePlan incorrecte.")
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
            throw NotePlanShortcutError.commandFailed(errorText.isEmpty ? outputText : errorText)
        }
        return outputText
    }

    static func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private enum MarkdownHighlighter {
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
        let indent = line.prefix { $0 == " " || $0 == "\t" }.count

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 1
        paragraph.headIndent = CGFloat(min(indent, 12)) * 7
        storage.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)

        if trimmed.hasPrefix("#") {
            let level = min(trimmed.prefix { $0 == "#" }.count, 4)
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: CGFloat(max(20 - level * 2, 14)), weight: .bold),
                .foregroundColor: NSColor.systemOrange
            ], range: lineRange)
            return
        }

        if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("* [x]") || trimmed.hasPrefix("- [X]") || trimmed.hasPrefix("* [X]") {
            storage.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ], range: lineRange)
        } else if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("* [ ]") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            storage.addAttribute(.foregroundColor, value: colorForIndent(indent), range: lineRange)
        }

        styleUrgency(in: storage, nsText: nsText, lineRange: lineRange, line: line)
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

@main
enum NoteDroppyV3App {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
