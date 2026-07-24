import AppKit

final class DropView: NSView {
    var onDrop: ((String) -> Void)?
    private let title = NSTextField(labelWithString: "Glisse du texte ici")
    private let subtitle = NSTextField(labelWithString: "Todo ou note NotePlan, sans raccourci ni autorisation Accessibilite.")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.systemBlue.cgColor
        registerForDraggedTypes([.string, .URL, .fileURL])
        setupLabels()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLabels() {
        title.font = .boldSystemFont(ofSize: 28)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        addSubview(title)
        addSubview(subtitle)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: centerXAnchor),
            title.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -18),
            subtitle.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            subtitle.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            subtitle.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
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

        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onDrop?(text)
            return true
        }

        if let urlText = pasteboard.string(forType: .URL), !urlText.isEmpty {
            onDrop?(urlText)
            return true
        }

        if let files = pasteboard.propertyList(forType: .fileURL) as? [String], !files.isEmpty {
            onDrop?(files.joined(separator: "\n"))
            return true
        }

        return false
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        createWindow()
    }

    private func createWindow() {
        let view = DropView(frame: NSRect(x: 0, y: 0, width: 520, height: 280))
        view.onDrop = { [weak self] text in
            self?.handleDrop(text)
        }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 280),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotePlan Drop"
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleDrop(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Envoyer a NotePlan"
        alert.informativeText = clipped(text)
        alert.addButton(withTitle: "Todo aujourd'hui")
        alert.addButton(withTitle: "Creer une note")
        alert.addButton(withTitle: "Annuler")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            addTodo(text)
        } else if response == .alertSecondButtonReturn {
            createNote(text)
        }
    }

    private func addTodo(_ text: String) {
        openNotePlanURL("noteplan://x-callback-url/addText?noteDate=today&text=\(encode("- [ ] \(text) #capture"))&mode=append&openNote=yes")
    }

    private func createNote(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = formatter.string(from: Date())
        let title = "Capture \(timestamp)"
        let body = """
        ## Source
        Drop app - \(timestamp)

        ## Todo
        - [ ] Traiter cette capture

        ## Contenu
        \(text)
        """
        openNotePlanURL("noteplan://x-callback-url/addNote?noteTitle=\(encode(title))&text=\(encode(body))&folder=Inbox&openNote=yes")
    }

    private func openNotePlanURL(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }

    private func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private func clipped(_ value: String) -> String {
        if value.count <= 240 { return value }
        return String(value.prefix(240)) + "..."
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
