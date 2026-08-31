// NoteDroppy V4 — Application principale
//
// Regles de conception :
//   - une seule fenetre principale au lancement, aucune fenetre secondaire automatique
//   - la fenetre FONCTIONS ne s'ouvre que sur clic utilisateur
//   - chaque bouton visible execute une vraie fonction
//   - toute ecriture dans une note reelle passe par une confirmation explicite
//   - tout est local : aucun reseau, aucune API distante, aucune cle, aucun token
//   - le moteur eprouve (tri, recherche, capture, Shorty) vit dans Engine.swift
//
// Cles UserDefaults prefixees "v4." pour ne jamais collisionner avec V1/V2/V3.

import AppKit
import Foundation
import UniformTypeIdentifiers

// MARK: - Identite

enum V4 {
    static let version = "5.0"
    static let build = "500"
    static let bundleIdentifier = "local.codex.notedroppy.v5"
    static let displayName = "Note Droopy V5"
    static let supportDirectoryName = "Note Droopy V5"
}

// MARK: - Reglages

enum Settings {
    private static let defaults = UserDefaults.standard

    static let notesRootKey = "v4.notesRootPath"
    static let openAfterActionKey = "v4.openNotePlanAfterAction"
    static let lastShortcutDestinationKey = "v4.lastShortcutDestination"

    static var notesRootPath: String {
        get { (defaults.string(forKey: notesRootKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        set { defaults.set(newValue, forKey: notesRootKey) }
    }

    static var openNotePlanAfterAction: Bool {
        get { defaults.bool(forKey: openAfterActionKey) }
        set { defaults.set(newValue, forKey: openAfterActionKey) }
    }

    static var lastShortcutDestination: String {
        get { defaults.string(forKey: lastShortcutDestinationKey) ?? "" }
        set { defaults.set(newValue, forKey: lastShortcutDestinationKey) }
    }
}

// MARK: - Emplacements locaux

enum Paths {
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent(V4.supportDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var promptsFile: URL { supportDirectory.appendingPathComponent("prompts.json") }
    static var captureRulesFile: URL { supportDirectory.appendingPathComponent("capture-rules.json") }
    static var logFile: URL { supportDirectory.appendingPathComponent("notedroppy-v5.log") }

    /// Copie le fichier livre dans le bundle vers Application Support s'il n'existe pas encore.
    @discardableResult
    static func seedIfMissing(resource: String, destination: URL) -> Bool {
        guard !FileManager.default.fileExists(atPath: destination.path) else { return false }
        guard let bundled = Bundle.main.url(forResource: resource, withExtension: "json") else { return false }
        try? FileManager.default.copyItem(at: bundled, to: destination)
        return FileManager.default.fileExists(atPath: destination.path)
    }
}

// MARK: - Journal local

enum Log {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func write(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = Paths.logFile
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}

// MARK: - Detection du dossier NotePlan

enum NotePlanLocator {
    static let candidatePaths: [String] = [
        "~/Library/Containers/co.noteplan.NotePlan3/Data/Library/Application Support/co.noteplan.NotePlan3",
        "~/Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application Support/co.noteplan.NotePlan-setapp",
        "~/Library/Application Support/co.noteplan.NotePlan3",
        "~/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents"
    ]

    /// Un dossier NotePlan valide contient Calendar/ et Notes/.
    static func isValidRoot(_ url: URL) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let calendar = fm.fileExists(atPath: url.appendingPathComponent("Calendar").path, isDirectory: &isDir) && isDir.boolValue
        let notes = fm.fileExists(atPath: url.appendingPathComponent("Notes").path, isDirectory: &isDir) && isDir.boolValue
        return calendar && notes
    }

    /// Si l'utilisateur a designe .../Notes, on remonte au parent.
    static func normalized(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        if standardized.lastPathComponent == "Notes" || standardized.lastPathComponent == "Calendar" {
            let parent = standardized.deletingLastPathComponent()
            if isValidRoot(parent) { return parent }
        }
        return standardized
    }

    static func autodetect() -> URL? {
        for path in candidatePaths {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            if isValidRoot(url) { return url }
        }
        return nil
    }

    /// Reglage utilisateur en priorite, puis auto-detection. Jamais de chemin invente.
    static func resolvedRoot() -> URL? {
        let stored = Settings.notesRootPath
        if !stored.isEmpty {
            let url = normalized(URL(fileURLWithPath: (stored as NSString).expandingTildeInPath))
            if isValidRoot(url) { return url }
        }
        return autodetect()
    }
}

// MARK: - Ecriture dans les notes

enum NoteWriter {
    enum WriteError: LocalizedError {
        case noRoot
        case notWritable(String)

        var errorDescription: String? {
            switch self {
            case .noRoot:
                return "Aucun dossier NotePlan valide. Renseigne-le dans la fenetre principale."
            case .notWritable(let path):
                return "Ecriture impossible dans \(path)."
            }
        }
    }

    static func dayStamp(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    static func todayNoteURL(root: URL, date: Date = Date()) -> URL {
        root.appendingPathComponent("Calendar").appendingPathComponent("\(dayStamp(date)).md")
    }

    /// Ajoute des lignes a la fin de la note. Cree le fichier s'il n'existe pas.
    static func append(_ block: String, to url: URL) throws {
        let fm = FileManager.default
        let directory = url.deletingLastPathComponent()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        var existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if !existing.isEmpty && !existing.hasSuffix("\n") { existing += "\n" }
        let payload = block.hasSuffix("\n") ? block : block + "\n"
        let merged = existing + payload

        guard let data = merged.data(using: .utf8) else {
            throw WriteError.notWritable(url.path)
        }
        try data.write(to: url, options: .atomic)
        Log.write("WRITE \(url.lastPathComponent) (+\(payload.components(separatedBy: "\n").count - 1) ligne(s))")
    }

    static func openInNotePlanIfEnabled(noteURL: URL) {
        guard Settings.openNotePlanAfterAction else { return }
        let name = noteURL.deletingPathExtension().lastPathComponent
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "noteplan://x-callback-url/openNote?noteTitle=\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Dialogues

enum Dialog {
    /// Confirmation obligatoire avant toute ecriture reelle.
    static func confirmWrite(target: String, preview: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Ecrire dans \(target) ?"
        alert.informativeText = "Contenu ajoute :\n\n\(preview)"
        alert.addButton(withTitle: "Ecrire")
        alert.addButton(withTitle: "Annuler")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func confirm(title: String, message: String, okTitle: String = "Continuer") -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: okTitle)
        alert.addButton(withTitle: "Annuler")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func input(title: String, message: String, initial: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Annuler")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 24))
        field.stringValue = initial
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func info(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Texte long, selectionnable, avec bouton Copier.
    static func report(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 260))
        text.string = body
        text.isEditable = false
        text.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 260))
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        alert.accessoryView = scroll
        alert.addButton(withTitle: "Fermer")
        alert.addButton(withTitle: "Copier")
        if alert.runModal() == .alertSecondButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(body, forType: .string)
        }
    }

    static func chooseDirectory(title: String, initial: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if let initial { panel.directoryURL = initial }
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseMarkdownFile(title: String, initial: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        }
        if let initial { panel.directoryURL = initial }
        return panel.runModal() == .OK ? panel.url : nil
    }
}

// MARK: - Contexte systeme (app active, git, presse-papiers)

final class ContextProbe {
    static let shared = ContextProbe()

    /// Derniere application active autre que NoteDroppy V4, suivie en temps reel.
    private(set) var lastExternalApp: NSRunningApplication?

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.lastExternalApp = app
        }
    }

    var frontmostName: String { lastExternalApp?.localizedName ?? "inconnue" }
    var frontmostBundleId: String { lastExternalApp?.bundleIdentifier ?? "inconnu" }

    var clipboardString: String? {
        NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Execute une commande locale. Retourne nil si l'executable est absent ou echoue.
    static func shell(_ executable: String, _ arguments: [String], cwd: URL? = nil) -> String? {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let cwd { process.currentDirectoryURL = cwd }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    struct GitContext {
        let cwd: String
        let root: String
        let branch: String
        let status: String
        let detected: Bool
    }

    /// Ne devine jamais un chemin : si aucun dossier git n'est fourni ou trouve, detected = false.
    static func gitContext(at directory: URL?) -> GitContext {
        guard let directory else {
            return GitContext(cwd: "non disponible", root: "non disponible", branch: "non disponible", status: "non disponible", detected: false)
        }
        let git = "/usr/bin/git"
        let root = shell(git, ["rev-parse", "--show-toplevel"], cwd: directory)
        guard let root else {
            return GitContext(cwd: directory.path, root: "aucun depot git", branch: "-", status: "-", detected: false)
        }
        let branch = shell(git, ["branch", "--show-current"], cwd: directory) ?? "-"
        let status = shell(git, ["status", "--short", "--branch"], cwd: directory) ?? "-"
        return GitContext(cwd: directory.path, root: root, branch: branch, status: status, detected: true)
    }
}

// MARK: - Variables de substitution

struct VariableContext {
    var url: String = ""
    var title: String = ""
    var selection: String = ""
    var source: String = ""
    var app: String = ""
    var bundleId: String = ""
    var cwd: String = ""
    var gitRoot: String = ""
    var gitBranch: String = ""
    var gitStatus: String = ""
    var chatPath: String = ""

    static func now(app: String, bundleId: String) -> VariableContext {
        var context = VariableContext()
        context.app = app
        context.bundleId = bundleId
        context.source = app
        return context
    }

    /// Remplace les variables les plus longues d'abord pour eviter que $date mange $datetime.
    func expand(_ template: String) -> String {
        let date = Date()
        func formatted(_ pattern: String) -> String {
            let f = DateFormatter()
            f.dateFormat = pattern
            return f.string(from: date)
        }

        let pairs: [(String, String)] = [
            ("$datetime", formatted("yyyy-MM-dd HH:mm")),
            ("$bundleId", bundleId),
            ("$gitBranch", gitBranch),
            ("$gitStatus", gitStatus),
            ("$gitRoot", gitRoot),
            ("$chatPath", chatPath),
            ("$selection", selection),
            ("$source", source),
            ("$month", formatted("MM")),
            ("$title", title),
            ("$date", formatted("yyyy-MM-dd")),
            ("$year", formatted("yyyy")),
            ("$time", formatted("HH:mm")),
            ("$day", formatted("EEEE")),
            ("$app", app),
            ("$url", url),
            ("$cwd", cwd)
        ]

        var output = template.replacingOccurrences(of: "\\n", with: "\n")
        for (token, value) in pairs {
            output = output.replacingOccurrences(of: token, with: value)
        }
        return output
    }

    static let supportedVariables = [
        "$date", "$day", "$time", "$datetime", "$month", "$year",
        "$app", "$bundleId", "$url", "$title", "$source", "$selection",
        "$cwd", "$gitRoot", "$gitBranch", "$gitStatus", "$chatPath"
    ]
}

// MARK: - Prompts locaux

struct PromptTemplate: Codable {
    let id: String
    var enabled: Bool?
    var title: String
    var template: String
    var tags: [String]?

    var isEnabled: Bool { enabled ?? true }
}

struct PromptLibrary: Codable {
    var version: Int?
    var prompts: [PromptTemplate]
}

enum PromptStore {
    private(set) static var library = PromptLibrary(version: 1, prompts: [])

    static var activePrompts: [PromptTemplate] { library.prompts.filter { $0.isEnabled } }

    @discardableResult
    static func reload() -> Result<Int, Error> {
        Paths.seedIfMissing(resource: "prompts", destination: Paths.promptsFile)
        guard FileManager.default.fileExists(atPath: Paths.promptsFile.path) else {
            library = PromptLibrary(version: 1, prompts: [])
            return .success(0)
        }
        do {
            let data = try Data(contentsOf: Paths.promptsFile)
            library = try JSONDecoder().decode(PromptLibrary.self, from: data)
            Log.write("PROMPTS reload \(activePrompts.count) actif(s)")
            return .success(activePrompts.count)
        } catch {
            Log.write("PROMPTS erreur \(error.localizedDescription)")
            return .failure(error)
        }
    }

    static func save(_ newLibrary: PromptLibrary) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(newLibrary)
        try data.write(to: Paths.promptsFile, options: .atomic)
        library = newLibrary
    }

    static func importFrom(_ url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(PromptLibrary.self, from: data)
        try save(decoded)
        return decoded.prompts.filter { $0.isEnabled }.count
    }

    static func exportTo(_ url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(library).write(to: url, options: .atomic)
    }
}

// MARK: - Regles de capture

/// Schema V4. Les cles historiques (match/destination/format/source) restent tolerees
/// pour ne pas casser les fichiers deja en place.
struct CaptureRule: Codable {
    let id: String
    var enabled: Bool?
    var matchBundleId: [String]?
    var matchDomain: [String]?
    var tags: [String]?
    var urlStrategy: String?
    var outputFormat: String?
    var fallbackFormat: String?

    var isEnabled: Bool { enabled ?? true }

    var strategyOrder: [CaptureEngine.Source] {
        let raw = (urlStrategy ?? "frontmost-then-selection-then-clipboard").lowercased()
        return raw.components(separatedBy: "-then-").compactMap { CaptureEngine.Source(rawValue: $0) }
    }
}

struct CaptureRuleSet: Codable {
    var version: Int?
    var rules: [CaptureRule]
}

enum CaptureRuleStore {
    private(set) static var ruleSet = CaptureRuleSet(version: 4, rules: [])

    static var activeRules: [CaptureRule] { ruleSet.rules.filter { $0.isEnabled } }

    @discardableResult
    static func reload() -> Result<Int, Error> {
        Paths.seedIfMissing(resource: "capture-rules", destination: Paths.captureRulesFile)
        guard FileManager.default.fileExists(atPath: Paths.captureRulesFile.path) else {
            ruleSet = CaptureRuleSet(version: 4, rules: [])
            return .success(0)
        }
        do {
            let data = try Data(contentsOf: Paths.captureRulesFile)
            ruleSet = try JSONDecoder().decode(CaptureRuleSet.self, from: data)
            Log.write("CAPTURE reload \(activeRules.count) regle(s) active(s)")
            return .success(activeRules.count)
        } catch {
            Log.write("CAPTURE erreur \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// Premiere regle dont le bundle id ou le domaine correspond. nil si aucune.
    static func match(bundleId: String, urlString: String) -> CaptureRule? {
        let host = URLComponents(string: urlString)?.host?.lowercased() ?? ""
        for rule in activeRules {
            if let bundles = rule.matchBundleId, bundles.contains(where: { $0.lowercased() == bundleId.lowercased() }) {
                return rule
            }
            if !host.isEmpty, let domains = rule.matchDomain, domains.contains(where: { host.contains($0.lowercased()) }) {
                return rule
            }
        }
        return nil
    }
}

// MARK: - Moteur de capture

enum CaptureEngine {
    enum Source: String {
        case frontmost      // URL de l'app / du navigateur au premier plan
        case selection      // selection active
        case clipboard      // presse-papiers
        case markdown       // lien Markdown deja forme
        case plain          // texte brut
        case fallback       // app source + titre

        var label: String {
            switch self {
            case .frontmost: return "URL app/navigateur"
            case .selection: return "selection active"
            case .clipboard: return "presse-papiers"
            case .markdown: return "lien Markdown"
            case .plain: return "texte brut"
            case .fallback: return "app source + titre"
            }
        }
    }

    struct Capture {
        let text: String
        let url: String
        let title: String
        let source: Source
        let ruleId: String?
    }

    /// Lit le presse-papiers une seule fois et derive toutes les strategies dessus.
    /// Rien n'est invente : si une source est indisponible, on passe a la suivante.
    static func capture(preferredOrder: [Source]) -> Capture? {
        let raw = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let app = ContextProbe.shared.frontmostName
        let bundleId = ContextProbe.shared.frontmostBundleId

        let order = preferredOrder.isEmpty ? [.clipboard, .markdown, .plain, .fallback] : preferredOrder

        for source in order {
            switch source {
            case .markdown:
                if let parsed = markdownLink(in: raw) {
                    return Capture(text: raw, url: parsed.url, title: parsed.title, source: .markdown, ruleId: nil)
                }
            case .frontmost, .selection, .clipboard:
                if let normalized = URLLineFormatter.normalizedWebURL(raw) {
                    return Capture(text: raw, url: normalized, title: titleGuess(raw, fallback: app), source: source, ruleId: nil)
                }
            case .plain:
                if !raw.isEmpty {
                    return Capture(text: raw, url: "", title: titleGuess(raw, fallback: app), source: .plain, ruleId: nil)
                }
            case .fallback:
                return Capture(text: "", url: "", title: app, source: .fallback, ruleId: bundleId)
            }
        }
        return nil
    }

    static func markdownLink(in text: String) -> (title: String, url: String)? {
        let pattern = #"\[([^\]]+)\]\((https?://[^\s)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let titleRange = Range(match.range(at: 1), in: text),
              let urlRange = Range(match.range(at: 2), in: text) else { return nil }
        return (String(text[titleRange]), String(text[urlRange]))
    }

    static func titleGuess(_ text: String, fallback: String) -> String {
        let firstLine = text.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if firstLine.isEmpty { return fallback }
        // Une URL n'est pas un titre : on prend son domaine plutot que de repeter le lien.
        if let normalized = URLLineFormatter.normalizedWebURL(firstLine),
           let host = URLComponents(string: normalized)?.host {
            return host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
        }
        return String(firstLine.prefix(120))
    }
}

// MARK: - Recherche Calendar + Notes

/// Recherche booleenne reelle : s'appuie sur BooleanQueryParser du moteur.
/// Une requete sans operateur se comporte comme une recherche de sous-chaine.
enum NoteSearch {
    struct Hit {
        let path: String
        let line: Int
        let text: String
    }

    static func run(root: URL, query: String) throws -> [Hit] {
        let matcher = try BooleanQueryParser.parse(query)
        var hits: [Hit] = []
        for folder in ["Calendar", "Notes"] {
            let dir = root.appendingPathComponent(folder)
            guard let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension.lowercased() == "md" {
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
                for (index, line) in content.components(separatedBy: "\n").enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }
                    if matcher.matches(trimmed) {
                        hits.append(Hit(path: relative, line: index + 1, text: trimmed))
                    }
                }
            }
        }
        return hits
    }
}

// MARK: - Fabrique de controles

enum UI {
    static func symbol(_ name: String, description: String) -> NSImage? {
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: name, accessibilityDescription: description)
        }
        return nil
    }

    static func button(_ title: String, symbol name: String, target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(title: " " + title, target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        if let image = symbol(name, description: title) {
            button.image = image
            button.imagePosition = .imageLeading
        }
        return button
    }

    static func greenButton(_ title: String, symbol name: String, target: AnyObject, action: Selector) -> NSButton {
        let button = self.button(title, symbol: name, target: target, action: action)
        button.bezelColor = .systemGreen
        button.contentTintColor = .white
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        return button
    }

    static func label(_ text: String, bold: Bool = false, size: CGFloat = 12, color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = bold ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size)
        field.textColor = color
        field.lineBreakMode = .byTruncatingMiddle
        return field
    }

    static func sectionHeader(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text.uppercased())
        field.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        field.textColor = .secondaryLabelColor
        return field
    }

    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}

// MARK: - Fenetre principale

final class MainWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow

    private let rootField = NSTextField(string: "")
    private let fileField = NSTextField(labelWithString: "-")
    private let statusLabel = UI.label("Pret.", size: 11, color: .secondaryLabelColor)
    private let editor = NSTextView()
    private let scroll = NSScrollView()

    private var currentNoteURL: URL?
    private var functionsController: FunctionsWindowController?

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = "\(V4.displayName) — \(V4.version) (\(V4.build))"
        window.delegate = self
        window.isRestorable = false
        // Sans ceci, fermer la fenetre libere l'objet NSWindow et toute reouverture plante.
        window.isReleasedWhenClosed = false
        window.center()
        Log.write("PHASE buildLayout debut")
        buildLayout()
        Log.write("PHASE buildLayout fin")
        refreshRootField()
        Log.write("PHASE dossier NotePlan resolu")
    }

    // MARK: Construction

    private func buildLayout() {
        let content = NSView()

        // Ligne 1 : dossier NotePlan
        rootField.placeholderString = "Chemin du dossier NotePlan (contient Calendar/ et Notes/)"
        rootField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        rootField.target = self
        rootField.action = #selector(applyRootFromField)

        let chooseButton = UI.button("Choisir", symbol: "folder", target: self, action: #selector(chooseRoot))
        let detectButton = UI.button("Detecter", symbol: "scope", target: self, action: #selector(detectRoot))

        let rootRow = NSStackView(views: [
            UI.label("Dossier NotePlan", bold: true),
            rootField,
            chooseButton,
            detectButton
        ])
        rootRow.orientation = .horizontal
        rootRow.spacing = 8
        rootRow.setHuggingPriority(.defaultLow, for: .horizontal)
        rootField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Ligne 2 : fichier courant + barre d'actions
        fileField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        fileField.textColor = .secondaryLabelColor

        let fileRow = NSStackView(views: [
            UI.label("Fichier", bold: true),
            fileField
        ])
        fileRow.orientation = .horizontal
        fileRow.spacing = 8
        fileField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let actionRow = NSStackView(views: [
            UI.button("Charger", symbol: "arrow.down.doc", target: self, action: #selector(loadFile)),
            UI.button("Aujourd'hui", symbol: "calendar", target: self, action: #selector(loadToday)),
            UI.button("Sauvegarder", symbol: "square.and.arrow.down", target: self, action: #selector(saveFile)),
            UI.button("Recherche", symbol: "magnifyingglass", target: self, action: #selector(searchNotes)),
            UI.button("Raccourcis", symbol: "keyboard", target: self, action: #selector(openShortcutSlots)),
            NSView(),
            UI.greenButton("FONCTIONS", symbol: "square.grid.2x2.fill", target: self, action: #selector(openFunctions))
        ])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8
        actionRow.distribution = .fill

        // Editeur Markdown
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.allowsUndo = true

        scroll.documentView = editor
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [rootRow, fileRow, actionRow, UI.separator(), scroll, statusLabel])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 12, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            rootRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            fileRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            actionRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 380)
        ])

        window.contentView = content
    }

    // MARK: Etat

    func status(_ message: String) {
        statusLabel.stringValue = message
        Log.write("STATUS \(message)")
    }

    private func refreshRootField() {
        if let root = NotePlanLocator.resolvedRoot() {
            rootField.stringValue = root.path
        } else {
            rootField.stringValue = Settings.notesRootPath
        }
    }

    var resolvedRoot: URL? { NotePlanLocator.resolvedRoot() }

    // MARK: Actions de la fenetre principale

    @objc private func applyRootFromField() {
        let value = rootField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let url = NotePlanLocator.normalized(URL(fileURLWithPath: (value as NSString).expandingTildeInPath))
        guard NotePlanLocator.isValidRoot(url) else {
            status("Dossier invalide : Calendar/ et Notes/ introuvables.")
            return
        }
        Settings.notesRootPath = url.path
        rootField.stringValue = url.path
        status("Dossier NotePlan : \(url.path)")
    }

    @objc private func chooseRoot() {
        guard let url = Dialog.chooseDirectory(title: "Choisir le dossier NotePlan", initial: resolvedRoot) else { return }
        let normalized = NotePlanLocator.normalized(url)
        guard NotePlanLocator.isValidRoot(normalized) else {
            status("Dossier invalide : Calendar/ et Notes/ introuvables.")
            return
        }
        Settings.notesRootPath = normalized.path
        rootField.stringValue = normalized.path
        status("Dossier NotePlan : \(normalized.path)")
    }

    @objc private func detectRoot() {
        guard let url = NotePlanLocator.autodetect() else {
            status("Aucun dossier NotePlan detecte automatiquement.")
            return
        }
        Settings.notesRootPath = url.path
        rootField.stringValue = url.path
        status("Detecte : \(url.path)")
    }

    @objc func loadToday() {
        guard let root = resolvedRoot else {
            status("Aucun dossier NotePlan valide.")
            return
        }
        let url = NoteWriter.todayNoteURL(root: root)
        load(url: url, createIfMissing: true)
    }

    @objc private func loadFile() {
        let initial = resolvedRoot?.appendingPathComponent("Calendar")
        guard let url = Dialog.chooseMarkdownFile(title: "Charger une note", initial: initial) else { return }
        load(url: url, createIfMissing: false)
    }

    func load(url: URL, createIfMissing: Bool) {
        if !FileManager.default.fileExists(atPath: url.path) {
            guard createIfMissing else {
                status("Fichier introuvable : \(url.lastPathComponent)")
                return
            }
            editor.string = ""
            currentNoteURL = url
            fileField.stringValue = url.path
            status("Note du jour absente sur le disque — elle sera creee a la sauvegarde.")
            return
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            status("Lecture impossible : \(url.lastPathComponent)")
            return
        }
        editor.string = text
        currentNoteURL = url
        fileField.stringValue = url.path
        status("Charge : \(url.lastPathComponent) (\(text.components(separatedBy: "\n").count) lignes)")
    }

    /// Sauvegarde = ecriture reelle : confirmation obligatoire.
    @objc private func saveFile() {
        guard let url = currentNoteURL else {
            status("Aucun fichier charge.")
            return
        }
        let preview = String(editor.string.prefix(400))
        guard Dialog.confirmWrite(target: url.lastPathComponent, preview: preview.isEmpty ? "(vide)" : preview) else {
            status("Sauvegarde annulee.")
            return
        }
        do {
            try editor.string.write(to: url, atomically: true, encoding: .utf8)
            status("Sauvegarde : \(url.path)")
            Log.write("SAVE \(url.path)")
            NoteWriter.openInNotePlanIfEnabled(noteURL: url)
        } catch {
            status("Echec sauvegarde : \(error.localizedDescription)")
        }
    }

    @objc func searchNotes() {
        guard let root = resolvedRoot else {
            status("Aucun dossier NotePlan valide.")
            return
        }
        guard let query = Dialog.input(title: "Recherche", message: "Requete (AND / OR / NOT acceptes) dans Calendar + Notes.") else { return }
        do {
            let results = try NoteSearch.run(root: root, query: query)
            guard !results.isEmpty else {
                status("Aucun resultat pour « \(query) ».")
                return
            }
            let body = results.prefix(300).map { "\($0.path):\($0.line)  \($0.text)" }.joined(separator: "\n")
            Dialog.report(title: "\(results.count) resultat(s) — « \(query) »", body: body)
            status("Recherche « \(query) » : \(results.count) resultat(s).")
        } catch {
            status("Recherche impossible : \(error.localizedDescription)")
        }
    }

    @objc private func openFunctions() {
        if functionsController == nil {
            functionsController = FunctionsWindowController(main: self)
        }
        functionsController?.show()
        status("Fenetre FONCTIONS ouverte.")
    }

    @objc private func openShortcutSlots() {
        ShortcutSlotsWindowController.show()
        status("Fenetre Raccourcis ouverte.")
    }

    // MARK: Services utilises par la fenetre FONCTIONS

    /// Ecrit un bloc dans la note du jour apres confirmation. Retourne un message de statut.
    func appendToToday(_ block: String, label: String) -> String {
        guard let root = resolvedRoot else {
            return "Echec : aucun dossier NotePlan valide."
        }
        let url = NoteWriter.todayNoteURL(root: root)
        guard Dialog.confirmWrite(target: "Calendar/\(url.lastPathComponent)", preview: block) else {
            return "Annule par l'utilisateur."
        }
        do {
            try NoteWriter.append(block, to: url)
            if currentNoteURL == url { load(url: url, createIfMissing: true) }
            NoteWriter.openInNotePlanIfEnabled(noteURL: url)
            return "OK — \(label) ajoute a \(url.lastPathComponent)."
        } catch {
            return "Echec : \(error.localizedDescription)"
        }
    }

    func showWindow() {
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { true }
}

// MARK: - Zone de glisser-deposer Shorty

final class ShortyDropView: NSView {
    var onDrop: ((URL) -> Void)?
    private let caption = UI.label("Glisser-deposer une note .md ici", size: 11, color: .secondaryLabelColor)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.cornerRadius = 6
        registerForDraggedTypes([.fileURL])

        caption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(caption)
        NSLayoutConstraint.activate([
            caption.centerXAnchor.constraint(equalTo: centerXAnchor),
            caption.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non supporte") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderColor = NSColor.systemGreen.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderColor = NSColor.separatorColor.cgColor
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first else { return false }
        guard url.pathExtension.lowercased() == "md" else {
            caption.stringValue = "Refuse : seuls les fichiers .md sont acceptes"
            return false
        }
        caption.stringValue = "Recu : \(url.lastPathComponent)"
        onDrop?(url)
        return true
    }
}

// MARK: - Fenetre FONCTIONS

final class FunctionsWindowController: NSObject {
    fileprivate struct RowSpec {
        let symbol: String
        let title: String
        let detail: String
        let run: () -> String
    }

    private unowned let main: MainWindowController
    private let window: NSWindow
    private var specs: [RowSpec] = []
    private var statusLabels: [NSTextField] = []
    private var selectedPromptId: String?

    init(main: MainWindowController) {
        self.main = main
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "FONCTIONS — \(V4.displayName)"
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        buildLayout()
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Construction

    private func buildLayout() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSection(to: stack, title: "1. Note Droppy", rows: noteDroppyRows())

        addSection(to: stack, title: "2. NotePlanShorty", rows: shortyRows())
        let drop = ShortyDropView(frame: .zero)
        drop.onDrop = { [weak self] url in
            guard let self else { return }
            let message = self.generateShortcut(from: url)
            Dialog.info(title: "NotePlanShorty", message: message)
        }
        drop.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(drop)
        drop.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36).isActive = true

        addSection(to: stack, title: "3. Prompts", rows: promptRows())
        addSection(to: stack, title: "4. Capture liens", rows: captureRows())
        addSection(to: stack, title: "5. Diagnostic", rows: diagnosticRows())

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])
        scroll.documentView = documentView

        let content = NSView()
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])
        window.contentView = content
    }

    private func addSection(to stack: NSStackView, title: String, rows: [RowSpec]) {
        let header = UI.sectionHeader(title)
        stack.addArrangedSubview(header)
        stack.setCustomSpacing(8, after: header)
        for row in rows {
            let view = makeRowView(row)
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36).isActive = true
        }
        let sep = UI.separator()
        stack.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36).isActive = true
        stack.setCustomSpacing(14, after: sep)
    }

    private func makeRowView(_ spec: RowSpec) -> NSView {
        let index = specs.count
        specs.append(spec)

        let icon = NSImageView()
        icon.image = UI.symbol(spec.symbol, description: spec.title)
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let title = UI.label(spec.title, bold: true, size: 12)
        let detail = UI.label(spec.detail, size: 11, color: .secondaryLabelColor)
        let status = UI.label("", size: 10, color: .tertiaryLabelColor)
        statusLabels.append(status)

        let textStack = NSStackView(views: [title, detail, status])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1

        let launch = NSButton(title: "LANCER", target: self, action: #selector(runRow(_:)))
        launch.bezelStyle = .rounded
        launch.tag = index
        launch.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        launch.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView(views: [icon, textStack, NSView(), launch])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return row
    }

    @objc private func runRow(_ sender: NSButton) {
        let index = sender.tag
        guard specs.indices.contains(index) else { return }
        let result = specs[index].run()
        if statusLabels.indices.contains(index) {
            statusLabels[index].stringValue = result
            statusLabels[index].textColor = result.hasPrefix("Echec") ? .systemRed : .tertiaryLabelColor
        }
        main.status("\(specs[index].title) → \(result)")
        Log.write("RUN \(specs[index].title) → \(result)")
    }
}

// MARK: - Section 1 : NOTE DROPPY

extension FunctionsWindowController {
    fileprivate func noteDroppyRows() -> [RowSpec] {
        [
            RowSpec(symbol: "checkmark.circle", title: "Ajouter une tache a aujourd'hui",
                    detail: "Saisie, apercu, confirmation, puis ecriture dans Calendar/YYYYMMDD.md.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                guard let text = Dialog.input(title: "Nouvelle tache", message: "Texte de la tache (sans le tiret).") else {
                    return "Annule."
                }
                return self.main.appendToToday("* \(text)", label: "tache")
            },

            RowSpec(symbol: "link", title: "Ajouter une URL a aujourd'hui",
                    detail: "Presse-papiers si possible, sinon saisie. Domaine ajoute devant l'URL.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                let clipboard = ContextProbe.shared.clipboardString ?? ""
                var raw = URLLineFormatter.normalizedWebURL(clipboard)
                if raw == nil {
                    guard let typed = Dialog.input(title: "Ajouter une URL", message: "Aucune URL dans le presse-papiers. Colle ou saisis l'URL.") else {
                        return "Annule."
                    }
                    raw = URLLineFormatter.normalizedWebURL(typed)
                }
                guard let url = raw else { return "Echec : URL invalide." }
                let line = URLLineFormatter.withHostPrefix("* \(url)")
                return self.main.appendToToday(line, label: "URL")
            },

            RowSpec(symbol: "text.viewfinder", title: "Ajouter le texte selectionne a aujourd'hui",
                    detail: "Lit le presse-papiers (copie ta selection avec Cmd+C avant). Apercu puis confirmation.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                guard let selection = ContextProbe.shared.clipboardString, !selection.isEmpty else {
                    return "Echec : presse-papiers vide — copie ta selection avec Cmd+C."
                }
                let block = selection
                    .components(separatedBy: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    .map { "* \($0)" }
                    .joined(separator: "\n")
                return self.main.appendToToday(block, label: "selection")
            },

            RowSpec(symbol: "magnifyingglass", title: "Rechercher dans Calendar + Notes",
                    detail: "Recherche booleenne (AND / OR / NOT) sur tout le dossier NotePlan.") { [weak self] in
                self?.main.searchNotes()
                return "Recherche lancee."
            },

            RowSpec(symbol: "arrow.up.forward.app", title: "Ouvrir NotePlan apres action",
                    detail: "Bascule. Quand c'est actif, NotePlan s'ouvre sur la note apres chaque ecriture.") {
                Settings.openNotePlanAfterAction.toggle()
                return Settings.openNotePlanAfterAction ? "Active." : "Desactive."
            }
        ]
    }
}

// MARK: - Section 2 : NOTEPLANSHORTY

extension FunctionsWindowController {
    fileprivate var shortcutDestination: URL {
        let stored = Settings.lastShortcutDestination
        if !stored.isEmpty { return URL(fileURLWithPath: stored) }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications/NotePlan Shortcuts")
    }

    fileprivate func generateShortcut(from noteURL: URL) -> String {
        let destination = shortcutDestination
        do {
            let result = try NotePlanShortcutGenerator.generate(
                noteURL: noteURL,
                destinationURL: destination,
                confirmReplace: { existing in
                    Dialog.confirm(
                        title: "Remplacer le raccourci ?",
                        message: "\(existing.path)\n\nCe fichier existe deja.",
                        okTitle: "Remplacer"
                    )
                }
            )
            Settings.lastShortcutDestination = destination.path
            Log.write("SHORTY \(result.appURL.path)")
            return "OK — \(result.appURL.lastPathComponent) dans \(destination.path)"
        } catch {
            return "Echec : \(error.localizedDescription)"
        }
    }

    fileprivate func shortyRows() -> [RowSpec] {
        [
            RowSpec(symbol: "doc.text", title: "Choisir une note .md",
                    detail: "Selectionne une note NotePlan et genere son raccourci .app.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                let initial = self.main.resolvedRoot?.appendingPathComponent("Notes")
                guard let note = Dialog.chooseMarkdownFile(title: "Choisir la note", initial: initial) else {
                    return "Annule."
                }
                return self.generateShortcut(from: note)
            },

            RowSpec(symbol: "link.badge.plus", title: "Accepter un lien noteplan://",
                    detail: "Colle une URL noteplan:// et nomme le raccourci genere.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                let clipboard = ContextProbe.shared.clipboardString ?? ""
                let suggested = clipboard.hasPrefix("noteplan://") ? clipboard : ""
                guard let link = Dialog.input(title: "Lien NotePlan", message: "URL noteplan:// complete.", initial: suggested) else {
                    return "Annule."
                }
                guard let name = Dialog.input(title: "Nom du raccourci", message: "Nom du fichier .app a creer.") else {
                    return "Annule."
                }
                do {
                    let result = try NotePlanShortcutGenerator.generate(
                        noteURLString: link,
                        appName: name,
                        destinationURL: self.shortcutDestination,
                        confirmReplace: { existing in
                            Dialog.confirm(title: "Remplacer le raccourci ?", message: existing.path, okTitle: "Remplacer")
                        }
                    )
                    return "OK — \(result.appURL.lastPathComponent)"
                } catch {
                    return "Echec : \(error.localizedDescription)"
                }
            },

            RowSpec(symbol: "folder.badge.gearshape", title: "Choisir la destination",
                    detail: "Dossier ou sont ecrits les raccourcis .app generes.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                guard let dir = Dialog.chooseDirectory(title: "Destination des raccourcis", initial: self.shortcutDestination) else {
                    return "Annule."
                }
                Settings.lastShortcutDestination = dir.path
                return "Destination : \(dir.path)"
            },

            RowSpec(symbol: "magnifyingglass.circle", title: "Reveler la destination dans le Finder",
                    detail: "Ouvre le dossier des raccourcis generes.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                let dir = self.shortcutDestination
                guard FileManager.default.fileExists(atPath: dir.path) else {
                    return "Echec : \(dir.path) n'existe pas encore."
                }
                NSWorkspace.shared.activateFileViewerSelecting([dir])
                return "Ouvert : \(dir.path)"
            }
        ]
    }
}

// MARK: - Section 3 : PROMPTS

extension FunctionsWindowController {
    fileprivate func currentVariableContext() -> VariableContext {
        var context = VariableContext.now(
            app: ContextProbe.shared.frontmostName,
            bundleId: ContextProbe.shared.frontmostBundleId
        )
        let clipboard = ContextProbe.shared.clipboardString ?? ""
        context.selection = clipboard
        context.url = URLLineFormatter.normalizedWebURL(clipboard) ?? ""
        context.title = CaptureEngine.titleGuess(clipboard, fallback: context.app)
        return context
    }

    fileprivate func promptRows() -> [RowSpec] {
        [
            RowSpec(symbol: "list.bullet.rectangle", title: "Choisir un prompt",
                    detail: "Liste les prompts actifs de prompts.json et memorise le choix.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                let prompts = PromptStore.activePrompts
                guard !prompts.isEmpty else { return "Echec : aucun prompt actif dans prompts.json." }
                let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 380, height: 26))
                popup.addItems(withTitles: prompts.map { $0.title })
                let alert = NSAlert()
                alert.messageText = "Choisir un prompt"
                alert.informativeText = "\(prompts.count) prompt(s) actif(s)."
                alert.accessoryView = popup
                alert.addButton(withTitle: "Choisir")
                alert.addButton(withTitle: "Annuler")
                guard alert.runModal() == .alertFirstButtonReturn else { return "Annule." }
                let chosen = prompts[popup.indexOfSelectedItem]
                self.selectedPromptId = chosen.id
                return "Selectionne : \(chosen.title)"
            },

            RowSpec(symbol: "text.badge.plus", title: "Appliquer le prompt a aujourd'hui",
                    detail: "Substitue les variables, affiche l'apercu, puis ecrit apres confirmation.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                guard let id = self.selectedPromptId,
                      let prompt = PromptStore.activePrompts.first(where: { $0.id == id }) else {
                    return "Echec : choisis d'abord un prompt."
                }
                let rendered = self.currentVariableContext().expand(prompt.template)
                return self.main.appendToToday(rendered, label: "prompt « \(prompt.title) »")
            },

            RowSpec(symbol: "square.and.arrow.down", title: "Importer prompts.json",
                    detail: "Valide un fichier externe puis remplace la bibliotheque locale.") {
                let panel = NSOpenPanel()
                panel.title = "Importer prompts.json"
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                guard panel.runModal() == .OK, let url = panel.url else { return "Annule." }
                guard Dialog.confirm(title: "Remplacer la bibliotheque locale ?", message: url.path, okTitle: "Importer") else {
                    return "Annule."
                }
                do {
                    let count = try PromptStore.importFrom(url)
                    return "OK — \(count) prompt(s) actif(s) importe(s)."
                } catch {
                    return "Echec : \(error.localizedDescription)"
                }
            },

            RowSpec(symbol: "square.and.arrow.up", title: "Exporter prompts.json",
                    detail: "Ecrit la bibliotheque locale dans un fichier de ton choix.") {
                let panel = NSSavePanel()
                panel.title = "Exporter prompts.json"
                panel.nameFieldStringValue = "prompts.json"
                guard panel.runModal() == .OK, let url = panel.url else { return "Annule." }
                do {
                    try PromptStore.exportTo(url)
                    return "OK — exporte vers \(url.path)"
                } catch {
                    return "Echec : \(error.localizedDescription)"
                }
            },

            RowSpec(symbol: "doc.badge.gearshape", title: "Ouvrir prompts.json",
                    detail: "Ouvre le fichier local editable sans recompiler l'app.") {
                Paths.seedIfMissing(resource: "prompts", destination: Paths.promptsFile)
                guard FileManager.default.fileExists(atPath: Paths.promptsFile.path) else {
                    return "Echec : \(Paths.promptsFile.path) absent."
                }
                NSWorkspace.shared.open(Paths.promptsFile)
                return "Ouvert : \(Paths.promptsFile.path)"
            },

            RowSpec(symbol: "arrow.clockwise", title: "Recharger prompts.json",
                    detail: "Relit le JSON et affiche le nombre de prompts actifs.") {
                switch PromptStore.reload() {
                case .success(let count): return "OK — \(count) prompt(s) actif(s)."
                case .failure(let error): return "Echec : \(error.localizedDescription)"
                }
            }
        ]
    }
}

// MARK: - Section 4 : CAPTURE LIENS

extension FunctionsWindowController {
    /// Applique la strategie de la regle correspondante et renvoie le texte formate + la source utilisee.
    fileprivate func runCapture() -> (block: String, log: String)? {
        let bundleId = ContextProbe.shared.frontmostBundleId
        let clipboard = ContextProbe.shared.clipboardString ?? ""
        let candidateURL = URLLineFormatter.normalizedWebURL(clipboard) ?? ""
        let rule = CaptureRuleStore.match(bundleId: bundleId, urlString: candidateURL)

        let order = rule?.strategyOrder ?? [.frontmost, .selection, .clipboard, .markdown, .plain, .fallback]
        guard let capture = CaptureEngine.capture(preferredOrder: order) else { return nil }

        var context = currentVariableContext()
        context.url = capture.url
        context.title = capture.title
        context.selection = capture.text

        let template = rule?.outputFormat ?? rule?.fallbackFormat ?? "* [$title]($url) #capture"
        var block = context.expand(template)
        if block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            block = context.expand(rule?.fallbackFormat ?? "* $selection #capture")
        }
        if let tags = rule?.tags, !tags.isEmpty {
            let missing = tags.filter { !block.contains($0) }
            if !missing.isEmpty { block += " " + missing.joined(separator: " ") }
        }

        let log = "regle=\(rule?.id ?? "aucune") source=\(capture.source.label) app=\(context.app) [\(bundleId)]"
        Log.write("CAPTURE \(log)")
        return (block, log)
    }

    fileprivate func captureRows() -> [RowSpec] {
        [
            RowSpec(symbol: "sparkle.magnifyingglass", title: "Tester la capture (aucune ecriture)",
                    detail: "Applique les regles, affiche le resultat et la source retenue. Rien n'est ecrit.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                guard let result = self.runCapture() else {
                    return "Echec : rien a capturer (presse-papiers vide)."
                }
                Dialog.report(title: "Capture — test a blanc", body: "\(result.log)\n\n\(result.block)")
                return "OK — \(result.log)"
            },

            RowSpec(symbol: "tray.and.arrow.down", title: "Capturer vers aujourd'hui",
                    detail: "Meme strategie, mais ecriture reelle dans la note du jour apres confirmation.") { [weak self] in
                guard let self else { return "Echec : contexte perdu." }
                guard let result = self.runCapture() else {
                    return "Echec : rien a capturer (presse-papiers vide)."
                }
                return self.main.appendToToday(result.block, label: "capture (\(result.log))")
            },

            RowSpec(symbol: "doc.badge.gearshape", title: "Ouvrir capture-rules.json",
                    detail: "Fichier local editable : id, enabled, matchBundleId, matchDomain, urlStrategy, formats.") {
                Paths.seedIfMissing(resource: "capture-rules", destination: Paths.captureRulesFile)
                guard FileManager.default.fileExists(atPath: Paths.captureRulesFile.path) else {
                    return "Echec : \(Paths.captureRulesFile.path) absent."
                }
                NSWorkspace.shared.open(Paths.captureRulesFile)
                return "Ouvert : \(Paths.captureRulesFile.path)"
            },

            RowSpec(symbol: "arrow.clockwise", title: "Recharger capture-rules.json",
                    detail: "Relit le JSON et affiche le nombre de regles actives.") {
                switch CaptureRuleStore.reload() {
                case .success(let count): return "OK — \(count) regle(s) active(s)."
                case .failure(let error): return "Echec : \(error.localizedDescription)"
                }
            }
        ]
    }
}

// MARK: - Section 5 : DIAGNOSTIC

extension FunctionsWindowController {
    fileprivate static func installedVersion(at path: String) -> String {
        let plistURL = URL(fileURLWithPath: path).appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return "absente"
        }
        let short = plist["CFBundleShortVersionString"] as? String ?? "?"
        let build = plist["CFBundleVersion"] as? String ?? "?"
        let identifier = plist["CFBundleIdentifier"] as? String ?? "?"
        return "\(short) (\(build)) — \(identifier)"
    }

    fileprivate func readTest(folder: String) -> String {
        guard let root = main.resolvedRoot else { return "Echec : aucun dossier NotePlan valide." }
        let dir = root.appendingPathComponent(folder)
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            return "Echec : \(folder)/ illisible."
        }
        var count = 0
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "md" { count += 1 }
        return "OK — \(count) fichier(s) .md lisibles dans \(folder)/"
    }

    fileprivate func diagnosticRows() -> [RowSpec] {
        [
            RowSpec(symbol: "app.dashed", title: "Afficher l'app active et son bundle id",
                    detail: "Derniere application au premier plan autre que NoteDroppy V4.") {
                "\(ContextProbe.shared.frontmostName) — \(ContextProbe.shared.frontmostBundleId)"
            },

            RowSpec(symbol: "folder", title: "Afficher le dossier NotePlan detecte",
                    detail: "Reglage utilisateur en priorite, sinon auto-detection. Aucun chemin invente.") { [weak self] in
                guard let root = self?.main.resolvedRoot else { return "Echec : aucun dossier valide." }
                return root.path
            },

            RowSpec(symbol: "calendar", title: "Afficher le fichier du jour",
                    detail: "Calendar/YYYYMMDD.md et son existence reelle sur le disque.") { [weak self] in
                guard let root = self?.main.resolvedRoot else { return "Echec : aucun dossier valide." }
                let url = NoteWriter.todayNoteURL(root: root)
                let exists = FileManager.default.fileExists(atPath: url.path)
                return "\(url.path) — \(exists ? "present" : "absent")"
            },

            RowSpec(symbol: "lock.open", title: "Tester la lecture de Calendar/",
                    detail: "Compte les .md accessibles. Aucune ecriture.") { [weak self] in
                self?.readTest(folder: "Calendar") ?? "Echec."
            },

            RowSpec(symbol: "lock.open", title: "Tester la lecture de Notes/",
                    detail: "Compte les .md accessibles. Aucune ecriture.") { [weak self] in
                self?.readTest(folder: "Notes") ?? "Echec."
            },

            RowSpec(symbol: "hammer", title: "Tester la generation Shorty (note temporaire)",
                    detail: "Genere un raccourci depuis une note jetable dans /tmp, puis nettoie. Aucune note reelle touchee.") {
                let temp = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("notedroppy-v4-selftest-\(UUID().uuidString)", isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
                    let note = temp.appendingPathComponent("NoteDroppy V4 Selftest.md")
                    try "# Selftest NoteDroppy V4\n".write(to: note, atomically: true, encoding: .utf8)
                    let result = try NotePlanShortcutGenerator.generate(noteURL: note, destinationURL: temp)
                    let ok = FileManager.default.fileExists(atPath: result.appURL.path)
                    try? FileManager.default.removeItem(at: temp)
                    return ok ? "OK — raccourci genere et verifie, dossier temporaire nettoye." : "Echec : raccourci absent apres generation."
                } catch {
                    try? FileManager.default.removeItem(at: temp)
                    return "Echec : \(error.localizedDescription)"
                }
            },

            RowSpec(symbol: "doc.plaintext", title: "Ouvrir les logs locaux",
                    detail: Paths.logFile.path) {
                if !FileManager.default.fileExists(atPath: Paths.logFile.path) {
                    Log.write("Creation du journal.")
                }
                NSWorkspace.shared.open(Paths.logFile)
                return "Ouvert : \(Paths.logFile.path)"
            },

            RowSpec(symbol: "terminal", title: "Copier le contexte Codex",
                    detail: "Choisis le dossier du projet : pwd, git root, branche et status sont copies.") {
                guard let dir = Dialog.chooseDirectory(title: "Dossier du projet Codex", initial: nil) else {
                    let instruction = """
                    Chemin Codex non accessible automatiquement.
                    Copie/colle la sortie de :
                      pwd
                      git status --short --branch
                    """
                    Dialog.report(title: "Contexte Codex", body: instruction)
                    return "Chemin non fourni — instruction affichee."
                }
                let context = ContextProbe.gitContext(at: dir)
                let block = """
                CHAT/CWD: \(context.cwd)
                GIT ROOT: \(context.root)
                BRANCH: \(context.branch)
                STATUS: \(context.status)
                """
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(block, forType: .string)
                Dialog.report(title: "Contexte Codex (copie)", body: block)
                return context.detected ? "OK — contexte git copie." : "Copie — aucun depot git detecte a cet endroit."
            },

            RowSpec(symbol: "square.stack.3d.up", title: "Afficher les versions installees",
                    detail: "Compare les bundles presents dans /Applications pour expliquer les conflits.") {
                let paths = [
                    "/Applications/NoteDroppy.app",
                    "/Applications/NoteDroppy V3.app",
                    "/Applications/NoteDroppy V4.app",
                    "/Applications/Note Droopy.app"
                ]
                let lines = paths.map { "\($0)\n    \(FunctionsWindowController.installedVersion(at: $0))" }
                let running = NSWorkspace.shared.runningApplications
                    .filter { ($0.bundleIdentifier ?? "").hasPrefix("local.codex.") }
                    .map { "    \($0.localizedName ?? "?") — \($0.bundleIdentifier ?? "?")" }
                let runningBlock = running.isEmpty ? "    aucune" : running.joined(separator: "\n")
                let body = lines.joined(separator: "\n") + "\n\nEn cours d'execution :\n" + runningBlock
                Dialog.report(title: "Versions installees", body: body)
                return "Rapport affiche (aucun processus n'a ete arrete)."
            }
        ]
    }
}

// MARK: - Delegue d'application

final class AppDelegate: NSObject, NSApplicationDelegate {
    // V5 20-slot capture system (work/NoteDroppyV4/ShortcutSlotStore.swift
    // and friends) -- reference kept strong here or the hotkeys are
    // unregistered as soon as this property would otherwise deinit.
    private var shortcutMonitor: GlobalShortcutMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = ContextProbe.shared

        Paths.seedIfMissing(resource: "prompts", destination: Paths.promptsFile)
        Paths.seedIfMissing(resource: "capture-rules", destination: Paths.captureRulesFile)
        PromptStore.reload()
        CaptureRuleStore.reload()
        ShortcutSlotStore.migrateLegacyDefaultsIfNeeded()
        ShortcutSlotStore.migrateShortcutLayoutIfNeeded()
        shortcutMonitor = GlobalShortcutMonitor(handler: CaptureTrigger.run)
        Log.write("LAUNCH \(V4.displayName) \(V4.version) (\(V4.build))")

        if runV5SelfTestIfRequested() {
            NSApp.terminate(nil)
            return
        }
        if runV5CaptureSelfTestIfRequested() {
            NSApp.terminate(nil)
            return
        }

        buildMenu()
        Log.write("PHASE menu construit")

        // V5 ouvre directement la blade Capture/Slots. Les autres outils restent
        // disponibles par menu/boutons explicites, pas en fenetre automatique.
        let started = Date()
        ShortcutSlotsWindowController.show()
        Log.write(String(format: "PHASE fenetre construite en %.1f s", Date().timeIntervalSince(started)))
        Log.write(String(format: "PHASE fenetre affichee a %.1f s", Date().timeIntervalSince(started)))

        NSApp.activate(ignoringOtherApps: true)
        Log.write(String(format: "PHASE lancement complet en %.1f s", Date().timeIntervalSince(started)))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func runV5SelfTestIfRequested() -> Bool {
        let env = ProcessInfo.processInfo.environment
        guard let targetPath = env["NOTE_DROOPY_V5_SELFTEST_TARGET"], !targetPath.isEmpty else {
            return false
        }
        let slotIndex = Int(env["NOTE_DROOPY_V5_SELFTEST_SLOT"] ?? "") ?? 20
        let slot = ShortcutSlotStore.shortcutSlot(slotIndex)
        let row = ShortcutSlotRow(slot: slot)
        let router = ShortcutTargetRouter { message in
            Log.write("v5-selftest:status:\(message)")
        }
        let ok = router.applyDroppedTarget(ShortcutTarget(url: URL(fileURLWithPath: targetPath)), to: row)
        Log.write("v5-selftest:target:\(targetPath):slot:\(slotIndex):ok:\(ok)")
        return true
    }

    private func runV5CaptureSelfTestIfRequested() -> Bool {
        let env = ProcessInfo.processInfo.environment
        guard let text = env["NOTE_DROOPY_V5_SELFTEST_CAPTURE_TEXT"], !text.isEmpty else {
            return false
        }
        let noteName = env["NOTE_DROOPY_V5_SELFTEST_CAPTURE_NOTE"] ?? "NoteDroopyV5-Capture-Selftest.md"
        let sourceURL = env["NOTE_DROOPY_V5_SELFTEST_CAPTURE_URL"]
        let sourceTitle = env["NOTE_DROOPY_V5_SELFTEST_CAPTURE_TITLE"]
        let sourceApp = env["NOTE_DROOPY_V5_SELFTEST_CAPTURE_APP"]
        let sourceBundle = env["NOTE_DROOPY_V5_SELFTEST_CAPTURE_BUNDLE"]
        let slot = ShortcutSlot(
            index: 20,
            enabled: true,
            combo: ShortcutSlotStore.defaultShortcutCombo(20),
            engine: .obsidian,
            destination: .notePath,
            noteReference: noteName,
            folder: "/tmp",
            tags: "#capture, !Text"
        )
        Log.write("v5-capture-selftest:start:note:/tmp/\(noteName)")
        sendTodo(
            text,
            shortcutSlot: slot,
            sourceURL: sourceURL,
            sourceTitle: sourceTitle,
            sourceAppName: sourceApp,
            sourceBundleId: sourceBundle
        )
        Log.write("v5-capture-selftest:done:note:/tmp/\(noteName)")
        return true
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: V4.displayName)
        appMenu.addItem(withTitle: "A propos de \(V4.displayName)", action: #selector(showAbout), keyEquivalent: "")
        appMenu.items.last?.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Masquer", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edition")
        editMenu.addItem(withTitle: "Annuler", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Retablir", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Tout selectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        Dialog.info(
            title: "\(V4.displayName) \(V4.version) (\(V4.build))",
            message: """
            Bundle : \(V4.bundleIdentifier)
            Reglages : \(Paths.supportDirectory.path)

            Tout est local. Aucun reseau, aucune cle, aucun token.
            """
        )
    }
}

// MARK: - Point d'entree

@main
enum NoteDroppyV4App {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
