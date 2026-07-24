import AppKit

final class DropTextView: NSTextView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect, textContainer: nil)
        configure()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configure()
    }

    private func configure() {
        registerForDraggedTypes([.string, .URL, .fileURL])
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        string = ""
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            string = text
            return true
        }
        if let url = pasteboard.string(forType: .URL), !url.isEmpty {
            string = url
            return true
        }
        return false
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let textView = DropTextView(frame: .zero)
    private let statusLabel = NSTextField(labelWithString: "Pret.")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildWindow()
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotePlan Send"

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "NotePlan Send")
        title.font = .boldSystemFont(ofSize: 24)
        title.translatesAutoresizingMaskIntoConstraints = false

        let hint = NSTextField(labelWithString: "Colle ou glisse du texte ici, puis envoie vers NotePlan.")
        hint.textColor = .secondaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = NSView.AutoresizingMask.width
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView

        let pasteButton = button("Coller", #selector(pasteClipboard))
        let todoButton = button("Todo aujourd'hui", #selector(sendTodo))
        let noteButton = button("Creer note", #selector(sendNote))
        let clearButton = button("Effacer", #selector(clearText))
        let openButton = button("Ouvrir NotePlan", #selector(openNotePlan))

        let buttons = NSStackView(views: [pasteButton, todoButton, noteButton, clearButton, openButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.alignment = .centerY
        buttons.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(title)
        root.addSubview(hint)
        root.addSubview(scroll)
        root.addSubview(buttons)
        root.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),

            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -24),

            buttons.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 16),
            buttons.leadingAnchor.constraint(equalTo: title.leadingAnchor),

            scroll.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            scroll.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),

            statusLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            statusLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18)
        ])

        window.contentView = root
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func pasteClipboard() {
        let value = NSPasteboard.general.string(forType: .string) ?? ""
        textView.string = value
        status(value.isEmpty ? "Presse-papiers vide." : "Texte colle.")
    }

    @objc private func sendTodo() {
        let text = currentText()
        guard !text.isEmpty else {
            status("Rien a envoyer.")
            return
        }
        let task = "- [ ] \(text) #capture"
        openURL("noteplan://x-callback-url/addText?noteDate=today&text=\(encode(task))&mode=append&openNote=yes")
        status("Todo envoyee a NotePlan.")
    }

    @objc private func sendNote() {
        let text = currentText()
        guard !text.isEmpty else {
            status("Rien a envoyer.")
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = formatter.string(from: Date())
        let title = "Capture \(timestamp)"
        let body = """
        ## Source
        NotePlan Send - \(timestamp)

        ## Todo
        - [ ] Traiter cette capture

        ## Contenu
        \(text)
        """
        openURL("noteplan://x-callback-url/addNote?noteTitle=\(encode(title))&text=\(encode(body))&folder=Inbox&openNote=yes")
        status("Note envoyee a NotePlan.")
    }

    @objc private func clearText() {
        textView.string = ""
        status("Efface.")
    }

    @objc private func openNotePlan() {
        openURL("noteplan://x-callback-url/openNote?noteDate=today")
    }

    private func currentText() -> String {
        textView.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else {
            status("URL invalide.")
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private func status(_ value: String) {
        statusLabel.stringValue = value
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
