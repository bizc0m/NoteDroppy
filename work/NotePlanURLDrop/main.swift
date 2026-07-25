import AppKit
import Foundation

final class SettingsWindowController: NSWindowController {
    private let nameField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let onSave: (String) -> Result<String, Error>

    init(currentName: String, onSave: @escaping (String) -> Result<String, Error>) {
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 210),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotePlanURLDrop"
        window.center()

        let root = NSView(frame: window.contentView?.bounds ?? .zero)
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let titleLabel = NSTextField(labelWithString: "Nom du Service macOS")
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let helpLabel = NSTextField(labelWithString: "Nom affiche dans clic droit -> Services. Apres enregistrement, macOS peut demander de relancer l'app source.")
        helpLabel.font = .systemFont(ofSize: 12)
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.lineBreakMode = .byWordWrapping
        helpLabel.maximumNumberOfLines = 2
        helpLabel.translatesAutoresizingMaskIntoConstraints = false

        nameField.stringValue = currentName
        nameField.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: "Enregistrer", target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let quitButton = NSButton(title: "Quitter", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quitButton.bezelStyle = .rounded
        quitButton.keyEquivalent = "q"
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(titleLabel)
        root.addSubview(helpLabel)
        root.addSubview(nameField)
        root.addSubview(statusLabel)
        root.addSubview(saveButton)
        root.addSubview(quitButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),

            helpLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            helpLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            helpLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            nameField.topAnchor.constraint(equalTo: helpLabel.bottomAnchor, constant: 18),
            nameField.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            nameField.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            statusLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            saveButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            saveButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -22),
            quitButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
            quitButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ])

        super.init(window: window)

        saveButton.target = self
        saveButton.action = #selector(saveServiceName(_:))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func saveServiceName(_ sender: NSButton) {
        let proposedName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !proposedName.isEmpty else {
            statusLabel.stringValue = "Nom vide refuse."
            return
        }

        switch onSave(proposedName) {
        case .success(let message):
            statusLabel.textColor = .systemGreen
            statusLabel.stringValue = message
        case .failure(let error):
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error.localizedDescription
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didReceiveOpenEvent = false
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("launch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if !self.didReceiveOpenEvent {
                self.showSettingsWindow()
            }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        didReceiveOpenEvent = true
        log("openFiles:\(filenames.joined(separator: " | "))")
        var handled = false
        for filename in filenames {
            let fileURL = URL(fileURLWithPath: filename)
            if let droppedText = extractTodoText(from: fileURL) {
                log("openFiles:extracted:\(droppedText)")
                sendTodo(droppedText)
                handled = true
            } else {
                log("openFiles:failed-extract:\(filename)")
            }
        }
        NSApp.reply(toOpenOrPrint: handled ? .success : .failure)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        didReceiveOpenEvent = true
        log("openURLs:\(urls.map { $0.absoluteString }.joined(separator: " | "))")
        for url in urls {
            if url.isFileURL, let droppedText = extractTodoText(from: url) {
                log("openURLs:file-extracted:\(droppedText)")
                sendTodo(droppedText)
            } else {
                sendTodo(url.absoluteString)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    private func extractTodoText(from fileURL: URL) -> String? {
        let ext = fileURL.pathExtension.lowercased()

        if ext == "webloc" || ext == "url" {
            if let data = try? Data(contentsOf: fileURL),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let dict = plist as? [String: Any],
               let value = dict["URL"] as? String,
               isWebURL(value) {
                return value
            }

            if let text = try? String(contentsOf: fileURL, encoding: .utf8),
               let value = firstWebURL(in: text) {
                return value
            }
        }

        if ext == "textclipping",
           let value = shell(["/usr/bin/mdls", "-raw", "-name", "kMDItemTextContent", fileURL.path]) {
            return normalizedTodoText(value)
        }

        if ext == "rtf",
           let attributed = try? NSAttributedString(url: fileURL, options: [:], documentAttributes: nil) {
            return normalizedTodoText(attributed.string)
        }

        if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
            return normalizedTodoText(text)
        }

        return nil
    }

    private func firstWebURL(in text: String) -> String? {
        let pattern = #"https?://[^\s<>"']+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return String(text[range])
    }

    private func isWebURL(_ value: String) -> Bool {
        value.lowercased().hasPrefix("http://") || value.lowercased().hasPrefix("https://")
    }

    private func normalizedTodoText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "(null)" else { return nil }
        return firstWebURL(in: trimmed) ?? trimmed
    }

    @objc func addSelectionAsTodo(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        didReceiveOpenEvent = true
        log("service:invoked")
        guard let text = pasteboard.string(forType: .string) else {
            log("service:no-text")
            error.pointee = "Aucun texte sélectionné" as NSString
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
            return
        }
        log("service:text:\(text)")
        sendTodo(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    private func showSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        let controller = SettingsWindowController(currentName: currentServiceName()) { [weak self] name in
            guard let self else {
                return .failure(NSError(domain: "NotePlanURLDrop", code: 1, userInfo: [NSLocalizedDescriptionKey: "App indisponible."]))
            }
            return self.updateServiceName(name)
        }
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func currentServiceName() -> String {
        guard let plist = mutableInfoPlist(),
              let services = plist["NSServices"] as? [[String: Any]],
              let first = services.first,
              let menu = first["NSMenuItem"] as? [String: Any],
              let name = menu["default"] as? String else {
            return "NotePlan : ajouter en tâche"
        }
        return name
    }

    private func updateServiceName(_ serviceName: String) -> Result<String, Error> {
        let previousName = currentServiceName()

        do {
            var plist = try loadInfoPlist()
            guard var services = plist["NSServices"] as? [[String: Any]], !services.isEmpty else {
                throw appError("NSServices introuvable dans Info.plist.")
            }
            var firstService = services[0]
            var menuItem = (firstService["NSMenuItem"] as? [String: Any]) ?? [:]
            menuItem["default"] = serviceName
            firstService["NSMenuItem"] = menuItem
            services[0] = firstService
            plist["NSServices"] = services
            try writeInfoPlist(plist)

            _ = shell(["/usr/bin/codesign", "--force", "--deep", "-s", "-", Bundle.main.bundleURL.path])
            _ = shell(["/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", "-f", Bundle.main.bundleURL.path])
            _ = shell(["/System/Library/CoreServices/pbs", "-flush"])
            _ = shell(["/System/Library/CoreServices/pbs", "-update"])
            enableServicePreference(named: serviceName)
            disableServicePreference(named: previousName)
            log("settings:service-name:\(serviceName)")
            return .success("Service mis a jour. Relance l'app source si le menu ne change pas tout de suite.")
        } catch {
            log("settings:error:\(error.localizedDescription)")
            return .failure(error)
        }
    }

    private func mutableInfoPlist() -> [String: Any]? {
        try? loadInfoPlist()
    }

    private func loadInfoPlist() throws -> [String: Any] {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw appError("Info.plist invalide.")
        }
        return plist
    }

    private func writeInfoPlist(_ plist: [String: Any]) throws {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
    }

    private func enableServicePreference(named serviceName: String) {
        updateServicePreference(named: serviceName, enabled: true)
    }

    private func disableServicePreference(named serviceName: String) {
        updateServicePreference(named: serviceName, enabled: false)
    }

    private func updateServicePreference(named serviceName: String, enabled: Bool) {
        let prefsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/pbs.plist")
        let key = "local.codex.noteplanurldrop - \(serviceName) - addSelectionAsTodo"
        var prefs: [String: Any] = [:]
        if let data = try? Data(contentsOf: prefsURL),
           let existing = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            prefs = existing
        }
        var status = prefs["NSServicesStatus"] as? [String: Any] ?? [:]
        status[key] = [
            "enabled_context_menu": enabled ? 1 : 0,
            "enabled_services_menu": enabled ? 1 : 0,
            "presentation_modes": [
                "ContextMenu": enabled ? 1 : 0,
                "ServicesMenu": enabled ? 1 : 0
            ]
        ]
        prefs["NSServicesStatus"] = status
        if let data = try? PropertyListSerialization.data(fromPropertyList: prefs, format: .binary, options: 0) {
            try? data.write(to: prefsURL, options: .atomic)
        }
    }

    private func appError(_ message: String) -> Error {
        NSError(domain: "NotePlanURLDrop", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func sendTodo(_ todoText: String) {
        let trimmed = todoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "(null)" else { return }
        log("sendTodo:\(trimmed)")
        let task = "- [ ] \(trimmed) #capture"
        let target = "noteplan://x-callback-url/addText?noteDate=today&text=\(encode(task))&mode=append&openNote=yes"
        _ = shell(["/usr/bin/open", target])
    }

    private func encode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private func shell(_ args: [String]) -> String? {
        guard let executable = args.first else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(args.dropFirst())
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/NotePlanURLDrop.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.servicesProvider = delegate

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)
let appMenu = NSMenu()
appMenu.addItem(withTitle: "Quitter NotePlanURLDrop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appMenuItem.submenu = appMenu
app.mainMenu = mainMenu

app.run()
