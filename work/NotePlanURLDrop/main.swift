import AppKit
import Foundation

final class TextDropView: NSView {
    var onTextDrop: ((String) -> Void)?
    var onFileDrop: ((URL) -> Void)?
    private let titleLabel = NSTextField(labelWithString: "Glisse du texte ici")
    private let hintLabel = NSTextField(labelWithString: "URL sur l'icone Dock: direct. Texte selectionne: glisse dans cette zone.")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.cornerRadius = 12
        layer?.borderColor = NSColor.systemBlue.cgColor
        layer?.borderWidth = 2
        registerForDraggedTypes([.string, .URL, .fileURL])
        setupLabels()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLabels() {
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 2
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -14),
            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            hintLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let pasteboard = sender.draggingPasteboard

        if let fileText = pasteboard.string(forType: .fileURL),
           let fileURL = URL(string: fileText) {
            onFileDrop?(fileURL)
            return true
        }

        if let urlText = pasteboard.string(forType: .URL),
           let url = URL(string: urlText),
           url.isFileURL {
            onFileDrop?(url)
            return true
        }

        if let text = normalizedDragString(pasteboard.string(forType: .string)) {
            onTextDrop?(text)
            return true
        }

        if let urlText = normalizedDragString(pasteboard.string(forType: .URL)) {
            onTextDrop?(urlText)
            return true
        }

        return false
    }

    private func normalizedDragString(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed != "(null)" else { return nil }
        return trimmed
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var didReceiveOpenEvent = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if !self.didReceiveOpenEvent {
                self.showTextDropWindow()
            }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        didReceiveOpenEvent = true
        var handled = false
        for filename in filenames {
            let fileURL = URL(fileURLWithPath: filename)
            if let droppedText = extractTodoText(from: fileURL) {
                sendTodo(droppedText)
                handled = true
            }
        }
        NSApp.reply(toOpenOrPrint: handled ? .success : .failure)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        didReceiveOpenEvent = true
        for url in urls {
            if url.isFileURL, let droppedText = extractTodoText(from: url) {
                sendTodo(droppedText)
            } else {
                sendTodo(url.absoluteString)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    private func showTextDropWindow() {
        NSApp.setActivationPolicy(.regular)
        let dropView = TextDropView(frame: NSRect(x: 0, y: 0, width: 460, height: 220))
        dropView.onTextDrop = { [weak self] text in
            self?.sendTodo(text)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NSApp.terminate(nil)
            }
        }
        dropView.onFileDrop = { [weak self] url in
            if let droppedText = self?.extractTodoText(from: url) {
                self?.sendTodo(droppedText)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NSApp.terminate(nil)
                }
            }
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 220),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotePlan Text Drop"
        window.contentView = dropView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
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

    private func sendTodo(_ todoText: String) {
        let trimmed = todoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "(null)" else { return }
        let task = "- [ ] \(trimmed) #capture"
        let target = "noteplan://x-callback-url/addText?noteDate=today&text=\(encode(task))&mode=append&openNote=yes"
        if let url = URL(string: target) {
            NSWorkspace.shared.open(url)
        }
    }

    private func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
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
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
