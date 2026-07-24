import AppKit
import Carbon
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var floatingPanel: NSPanel!
    private var hotKeyRef: EventHotKeyRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x4e504350), id: 1) // NPCP

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenu()
        setupFloatingPanel()
        requestAccessibilityIfNeeded()
        registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "NP"
        statusItem.button?.toolTip = "NotePlan Capture"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture now", action: #selector(captureNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open NotePlan", action: #selector(openNotePlan), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupFloatingPanel() {
        floatingPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 86),
            styleMask: [.titled, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        floatingPanel.title = "NotePlanCapture"
        floatingPanel.titleVisibility = .visible
        floatingPanel.titlebarAppearsTransparent = false
        floatingPanel.isFloatingPanel = true
        floatingPanel.level = .floating
        floatingPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        floatingPanel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92)
        floatingPanel.isOpaque = false
        floatingPanel.hasShadow = true
        floatingPanel.hidesOnDeactivate = false

        let stack = NSStackView(frame: NSRect(x: 14, y: 12, width: 232, height: 36))
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually

        let todo = NSButton(title: "Todo", target: self, action: #selector(captureTodoNow))
        todo.bezelStyle = .rounded
        todo.toolTip = "Ajouter la selection comme todo NotePlan"

        let note = NSButton(title: "Note", target: self, action: #selector(captureNoteNow))
        note.bezelStyle = .rounded
        note.toolTip = "Creer une note NotePlan avec la selection"

        stack.addArrangedSubview(todo)
        stack.addArrangedSubview(note)
        floatingPanel.contentView = stack
        floatingPanel.center()
        floatingPanel.orderFrontRegardless()
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            var eventID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &eventID
            )
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            if eventID.id == delegate.hotKeyID.id {
                DispatchQueue.main.async { delegate.captureNow() }
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_N), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            notify("Raccourci indisponible", "Ctrl+Option+Cmd+N est deja utilise.")
        }
    }

    @objc private func captureNow() {
        guard AXIsProcessTrusted() else {
            requestAccessibilityIfNeeded()
            notify("Autorisation requise", "Active NotePlanCapture dans Accessibilite.")
            return
        }

        guard let selected = readSelectedText(), !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notify("Aucune selection", "Selectionne du texte puis relance la capture.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "NotePlan Capture"
        alert.informativeText = "Que faire avec la selection ?"
        alert.addButton(withTitle: "Todo aujourd'hui")
        alert.addButton(withTitle: "Creer une note")
        alert.addButton(withTitle: "Annuler")
        let response = runFrontmost(alert)

        if response == .alertFirstButtonReturn {
            addTodo(selected)
        } else if response == .alertSecondButtonReturn {
            createNote(selected)
        }
    }

    @objc private func captureTodoNow() {
        guard let selected = readSelectedText(), !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notify("Aucune selection", "Selectionne du texte puis clique Todo.")
            return
        }
        addTodo(selected)
    }

    @objc private func captureNoteNow() {
        guard let selected = readSelectedText(), !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notify("Aucune selection", "Selectionne du texte puis clique Note.")
            return
        }
        createNoteWithoutPrompt(selected)
    }

    private func readSelectedText() -> String? {
        if let selected = selectedTextFromAccessibility(),
           !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selected
        }
        return copySelection()
    }

    private func selectedTextFromAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard focusedStatus == .success, let focusedElement = focusedRef else {
            return nil
        }

        var selectedRef: CFTypeRef?
        let selectedStatus = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedRef
        )
        guard selectedStatus == .success, let selected = selectedRef as? String else {
            return nil
        }
        return selected
    }

    private func copySelection() -> String? {
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []
        let changeCount = pasteboard.changeCount

        pasteboard.clearContents()
        sendCopyKeystroke()

        let deadline = Date().addingTimeInterval(0.8)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            if pasteboard.changeCount != changeCount, let value = pasteboard.string(forType: .string) {
                restorePasteboard(savedItems)
                return value
            }
        }

        let value = pasteboard.string(forType: .string)
        restorePasteboard(savedItems)
        return value
    }

    private func restorePasteboard(_ items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    private func sendCopyKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func addTodo(_ text: String) {
        let task = "- [ ] \(text) #capture"
        openURL("noteplan://x-callback-url/addText?noteDate=today&text=\(encode(task))&mode=append&openNote=no")
        notify("Todo ajoutee", "Capture envoyee a NotePlan.")
    }

    private func createNote(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = formatter.string(from: Date())

        let prompt = NSAlert()
        prompt.messageText = "Titre de la note"
        prompt.addButton(withTitle: "Creer")
        prompt.addButton(withTitle: "Annuler")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = "Capture \(timestamp)"
        prompt.accessoryView = field

        guard runFrontmost(prompt) == .alertFirstButtonReturn else { return }
        let title = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Capture \(timestamp)" : field.stringValue
        let body = """
        ## Source
        Capture clavier - \(timestamp)

        ## Todo
        - [ ] Traiter cette capture

        ## Contenu
        \(text)
        """

        openURL("noteplan://x-callback-url/addNote?noteTitle=\(encode(title))&text=\(encode(body))&folder=Inbox&openNote=yes")
        notify("Note creee", "Capture envoyee a NotePlan.")
    }

    private func createNoteWithoutPrompt(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = formatter.string(from: Date())
        let title = "Capture \(timestamp)"
        let body = """
        ## Source
        Capture flottante - \(timestamp)

        ## Todo
        - [ ] Traiter cette capture

        ## Contenu
        \(text)
        """

        openURL("noteplan://x-callback-url/addNote?noteTitle=\(encode(title))&text=\(encode(body))&folder=Inbox&openNote=yes")
        notify("Note creee", "Capture envoyee a NotePlan.")
    }

    private func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "&", with: "%26")
            .replacingOccurrences(of: "+", with: "%2B") ?? ""
    }

    private func openURL(_ value: String) {
        if let url = URL(string: value) {
            NSWorkspace.shared.open(url)
        }
    }

    private func runFrontmost(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alert.window.orderFrontRegardless()
        return alert.runModal()
    }

    @objc private func openNotePlan() {
        openURL("noteplan://x-callback-url/openNote?noteDate=today")
    }

    private func notify(_ title: String, _ body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        NSUserNotificationCenter.default.deliver(notification)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
