import AppKit
import ApplicationServices
import Carbon
import Foundation

private enum Settings {
    static let codeSignIdentity = "NoteDroppy Local Code Signing"
    static let repositoryURL = "https://github.com/bizc0m/NoteDroppy"
    static let taskTagKey = "taskTag"
    static let openNoteKey = "openNote"
    static let serviceNameKey = "serviceName"
    static let shortcutEnabledKey = "shortcutEnabled"
    static let shortcutKeyCodeKey = "shortcutKeyCode"
    static let shortcutModifiersKey = "shortcutModifiers"

    static var taskTag: String {
        let value = UserDefaults.standard.string(forKey: taskTagKey) ?? "#capture"
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "#capture" : trimmed
    }

    static var openNote: Bool {
        if UserDefaults.standard.object(forKey: openNoteKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: openNoteKey)
    }

    static var serviceName: String {
        let value = UserDefaults.standard.string(forKey: serviceNameKey) ?? "NotePlan : ajouter en tâche"
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "NotePlan : ajouter en tâche" : trimmed
    }

    static var shortcutEnabled: Bool {
        if UserDefaults.standard.object(forKey: shortcutEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: shortcutEnabledKey)
    }

    static var shortcutKeyCode: UInt32 {
        if UserDefaults.standard.object(forKey: shortcutKeyCodeKey) == nil {
            return UInt32(kVK_ANSI_N)
        }
        return UInt32(UserDefaults.standard.integer(forKey: shortcutKeyCodeKey))
    }

    static var shortcutModifiers: UInt32 {
        if UserDefaults.standard.object(forKey: shortcutModifiersKey) == nil {
            return UInt32(controlKey | optionKey | cmdKey)
        }
        let raw = UInt32(UserDefaults.standard.integer(forKey: shortcutModifiersKey))
        let allowedCarbon = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        if raw != 0, raw & ~allowedCarbon == 0 {
            return raw
        }

        let converted = carbonModifiers(fromRawNSEventFlags: UInt(raw))
        if converted != 0 {
            UserDefaults.standard.set(Int(converted), forKey: shortcutModifiersKey)
            return converted
        }
        return UInt32(controlKey | optionKey | cmdKey)
    }

    static var shortcutDisplay: String {
        KeyCombo(keyCode: shortcutKeyCode, carbonModifiers: shortcutModifiers).display
    }
}

fileprivate struct KeyCombo {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    var display: String {
        let parts = modifierDisplay + [keyDisplay]
        return parts.joined()
    }

    private var modifierDisplay: [String] {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        return parts
    }

    private var keyDisplay: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Espace"
        case kVK_Return: return "Retour"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        default: return "#\(keyCode)"
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    fileprivate var onChange: ((KeyCombo) -> Void)?
    private var localMonitor: Any?
    private var isRecording = false

    init() {
        super.init(frame: .zero)
        title = "Raccourci : \(Settings.shortcutDisplay)"
        bezelStyle = .rounded
        target = self
        action = #selector(beginRecording)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        stopRecording(updateTitle: false)
    }

    @objc private func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        title = "Tape le nouveau raccourci..."
        NotificationCenter.default.post(name: .shortcutRecordingBegan, object: nil)
        window?.makeFirstResponder(self)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return nil
        }
    }

    override func keyDown(with event: NSEvent) {
        record(event)
    }

    private func record(_ event: NSEvent) {
        guard isRecording else { return }
        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            NSSound.beep()
            title = "Ajoute ⌃ ⌥ ⇧ ou ⌘"
            return
        }
        guard event.keyCode != UInt16(kVK_ANSI_C) || modifiers != UInt32(cmdKey) else {
            NSSound.beep()
            title = "⌘C est réservé"
            return
        }
        guard !isReservedMenuShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers) else {
            NSSound.beep()
            title = "Raccourci réservé par l'app"
            return
        }
        let combo = KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
        UserDefaults.standard.set(Int(combo.keyCode), forKey: Settings.shortcutKeyCodeKey)
        UserDefaults.standard.set(Int(combo.carbonModifiers), forKey: Settings.shortcutModifiersKey)
        UserDefaults.standard.synchronize()
        title = "Raccourci : \(combo.display)"
        onChange?(combo)
        stopRecording(updateTitle: false)
    }

    private func stopRecording(updateTitle: Bool = true) {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if isRecording {
            NotificationCenter.default.post(name: .shortcutRecordingEnded, object: nil)
        }
        isRecording = false
        if updateTitle {
            title = "Raccourci : \(Settings.shortcutDisplay)"
        }
    }
}

private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    let normalized = flags.intersection(.deviceIndependentFlagsMask)
    var result: UInt32 = 0
    if normalized.contains(.control) { result |= UInt32(controlKey) }
    if normalized.contains(.option) { result |= UInt32(optionKey) }
    if normalized.contains(.shift) { result |= UInt32(shiftKey) }
    if normalized.contains(.command) { result |= UInt32(cmdKey) }
    return result
}

private func carbonModifiers(fromRawNSEventFlags raw: UInt) -> UInt32 {
    carbonModifiers(from: NSEvent.ModifierFlags(rawValue: raw))
}

private func isReservedMenuShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
    let commandOnly = UInt32(cmdKey)
    let commandShift = UInt32(cmdKey | shiftKey)
    let commandOption = UInt32(cmdKey | optionKey)

    if keyCode == UInt32(kVK_ANSI_Q), modifiers & UInt32(cmdKey) != 0 {
        return true
    }
    if keyCode == UInt32(kVK_ANSI_Comma), modifiers & UInt32(cmdKey) != 0 {
        return true
    }
    if keyCode == UInt32(kVK_ANSI_Slash), modifiers == commandOnly || modifiers == commandShift || modifiers == commandOption {
        return true
    }
    return false
}

final class SettingsWindowController: NSWindowController {
    private let serviceNameField = NSTextField(string: Settings.serviceName)
    private let tagField = NSTextField(string: Settings.taskTag)
    private let openNoteCheckbox = NSButton(checkboxWithTitle: "Ouvrir NotePlan après l'ajout", target: nil, action: nil)
    private let shortcutCheckbox = NSButton(checkboxWithTitle: "Raccourci global", target: nil, action: nil)
    private let shortcutRecorder = ShortcutRecorderButton()
    private let helpButton = NSButton(title: "Aide", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Autoriser Accessibilité", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Réglages NoteDroppy"
        window.center()
        self.init(window: window)
        buildContent()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let title = NSTextField(labelWithString: "NoteDroppy")
        title.font = .boldSystemFont(ofSize: 18)

        let serviceLabel = NSTextField(labelWithString: "Nom du Service")
        serviceNameField.placeholderString = "NotePlan : ajouter en tâche"
        serviceNameField.lineBreakMode = .byTruncatingTail

        let tagLabel = NSTextField(labelWithString: "Tag ajouté à la tâche")
        tagField.placeholderString = "#capture"

        openNoteCheckbox.state = Settings.openNote ? .on : .off
        shortcutCheckbox.state = Settings.shortcutEnabled ? .on : .off
        shortcutRecorder.onChange = { _ in
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.alignment = .centerY

        let saveButton = NSButton(title: "Enregistrer", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let quitButton = NSButton(title: "Quitter", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quitButton.bezelStyle = .rounded
        quitButton.keyEquivalent = "q"

        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibilitySettings)
        accessibilityButton.bezelStyle = .rounded

        helpButton.target = self
        helpButton.action = #selector(openHelp)
        helpButton.bezelStyle = .rounded

        buttons.addArrangedSubview(saveButton)
        buttons.addArrangedSubview(helpButton)
        buttons.addArrangedSubview(accessibilityButton)
        buttons.addArrangedSubview(quitButton)

        [serviceNameField, tagField].forEach { field in
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 360).isActive = true
        }
        shortcutRecorder.translatesAutoresizingMaskIntoConstraints = false
        shortcutRecorder.widthAnchor.constraint(equalToConstant: 360).isActive = true

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(serviceLabel)
        stack.addArrangedSubview(serviceNameField)
        stack.addArrangedSubview(tagLabel)
        stack.addArrangedSubview(tagField)
        stack.addArrangedSubview(openNoteCheckbox)
        stack.addArrangedSubview(shortcutCheckbox)
        stack.addArrangedSubview(shortcutRecorder)
        stack.addArrangedSubview(buttons)
        stack.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22)
        ])
        refreshAccessibilityStatus()
    }

    @objc private func saveSettings() {
        let serviceName = serviceNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = tagField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(serviceName.isEmpty ? "NotePlan : ajouter en tâche" : serviceName, forKey: Settings.serviceNameKey)
        UserDefaults.standard.set(tag.isEmpty ? "#capture" : tag, forKey: Settings.taskTagKey)
        UserDefaults.standard.set(openNoteCheckbox.state == .on, forKey: Settings.openNoteKey)
        UserDefaults.standard.set(shortcutCheckbox.state == .on, forKey: Settings.shortcutEnabledKey)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)

        if applyServiceNameToBundle(serviceName.isEmpty ? "NotePlan : ajouter en tâche" : serviceName) {
            statusLabel.stringValue = "Réglages enregistrés. Le menu Services peut demander quelques secondes pour se rafraîchir."
        } else {
            statusLabel.stringValue = "Réglages enregistrés. Nom du Service gardé pour l'app, mais macOS n'a pas pu être rafraîchi."
        }
        refreshAccessibilityStatus(append: true)
    }

    @objc private func openAccessibilitySettings() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refreshAccessibilityStatus()
    }

    @objc private func openHelp() {
        showHelpDocument(named: "HELP", title: "Aide NoteDroppy")
    }

    private func refreshAccessibilityStatus(append: Bool = false) {
        let trusted = AXIsProcessTrusted()
        accessibilityButton.isEnabled = !trusted
        let accessibilityText = trusted
            ? "Accessibilité OK. Le raccourci global peut copier la sélection."
            : "Accessibilité requise pour le raccourci global."
        statusLabel.stringValue = append && !statusLabel.stringValue.isEmpty
            ? "\(statusLabel.stringValue) \(accessibilityText)"
            : accessibilityText
    }

    private func applyServiceNameToBundle(_ serviceName: String) -> Bool {
        let plistURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              var plist = (try? PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: nil)) as? [String: Any],
              var services = plist["NSServices"] as? [[String: Any]],
              !services.isEmpty else {
            return false
        }

        var firstService = services[0]
        firstService["NSMenuItem"] = ["default": serviceName]
        services[0] = firstService
        plist["NSServices"] = services

        guard let updatedData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            return false
        }

        do {
            try updatedData.write(to: plistURL, options: .atomic)
        } catch {
            return false
        }

        _ = runProcess("/usr/bin/codesign", ["--force", "--deep", "-s", Settings.codeSignIdentity, Bundle.main.bundlePath])
        _ = runProcess("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", ["-f", Bundle.main.bundlePath])
        _ = runProcess("/System/Library/CoreServices/pbs", ["-flush"])
        _ = runProcess("/System/Library/CoreServices/pbs", ["-update"])
        return true
    }

    private func runProcess(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

final class HelpWindowController: NSWindowController {
    private static var retainedControllers: [HelpWindowController] = []

    convenience init(title: String, content: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        self.init(window: window)
        buildContent(content)
        window.delegate = self
    }

    static func show(title: String, content: String) {
        let controller = HelpWindowController(title: title, content: content)
        retainedControllers.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent(_ content: String) {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.string = content
        scrollView.documentView = textView

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        let githubButton = NSButton(title: "GitHub Repository", target: self, action: #selector(openGitHub))
        githubButton.bezelStyle = .rounded
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.bezelStyle = .rounded

        buttonRow.addArrangedSubview(githubButton)
        buttonRow.addArrangedSubview(closeButton)

        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(buttonRow)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 480)
        ])
    }

    @objc private func openGitHub() {
        openRepository()
    }

    @objc private func closeWindow() {
        close()
    }

    fileprivate static func release(_ controller: HelpWindowController) {
        retainedControllers.removeAll { $0 === controller }
    }
}

extension HelpWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        HelpWindowController.release(self)
    }
}

private func showHelpDocument(named name: String, title: String) {
    let content: String
    if let url = Bundle.main.url(forResource: name, withExtension: "md"),
       let loaded = try? String(contentsOf: url, encoding: .utf8) {
        content = loaded
    } else {
        content = "Help content is missing from the app bundle."
    }
    HelpWindowController.show(title: title, content: content)
}

private func openRepository() {
    if let url = URL(string: Settings.repositoryURL) {
        NSWorkspace.shared.open(url)
    }
}

private extension Notification.Name {
    static let settingsDidChange = Notification.Name("NoteDroppySettingsDidChange")
    static let shortcutRecordingBegan = Notification.Name("NoteDroppyShortcutRecordingBegan")
    static let shortcutRecordingEnded = Notification.Name("NoteDroppyShortcutRecordingEnded")
}

final class ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard = .general) {
        self.items = pasteboard.pasteboardItems?.map { item in
            var values: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    values[type] = data
                }
            }
            return values
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let restoredItems = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}

final class GlobalShortcutMonitor {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var lastFire = Date.distantPast
    private let handler: () -> Void
    private let hotKeySignature = fourCharCode("NDPY")
    private let hotKeyID = UInt32(1)
    private var registeredCombo = KeyCombo(keyCode: Settings.shortcutKeyCode, carbonModifiers: Settings.shortcutModifiers)

    init(handler: @escaping () -> Void) {
        self.handler = handler
        update()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .settingsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecordingBegan),
            name: .shortcutRecordingBegan,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecordingEnded),
            name: .shortcutRecordingEnded,
            object: nil
        )
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func settingsDidChange() {
        update()
    }

    @objc private func shortcutRecordingBegan() {
        stop()
    }

    @objc private func shortcutRecordingEnded() {
        update()
    }

    private func update() {
        stop()
        guard Settings.shortcutEnabled else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotKeyHandler,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            return
        }

        registeredCombo = KeyCombo(keyCode: Settings.shortcutKeyCode, carbonModifiers: Settings.shortcutModifiers)
        let carbonHotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyID)
        let registerStatus = RegisterEventHotKey(
            registeredCombo.keyCode,
            registeredCombo.carbonModifiers,
            carbonHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if registerStatus != noErr {
            stop()
        }
    }

    private func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate func fireIfMatching(signature: UInt32, id: UInt32) -> OSStatus {
        guard signature == hotKeySignature, id == hotKeyID else {
            return OSStatus(eventNotHandledErr)
        }
        guard Date().timeIntervalSince(lastFire) > 0.8 else { return noErr }
        lastFire = Date()
        DispatchQueue.main.async {
            self.handler()
        }
        return noErr
    }
}

private func fourCharCode(_ value: String) -> UInt32 {
    var result: UInt32 = 0
    for scalar in value.unicodeScalars.prefix(4) {
        result = (result << 8) + UInt32(scalar.value)
    }
    return result
}

private let globalHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else {
        return status
    }

    let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(userData).takeUnretainedValue()
    return monitor.fireIfMatching(signature: hotKeyID.signature, id: hotKeyID.id)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didReceiveOpenEvent = false
    private var settingsWindowController: SettingsWindowController?
    private var shortcutMonitor: GlobalShortcutMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("launch")
        shortcutMonitor = GlobalShortcutMonitor { [weak self] in
            self?.captureSelectedTextWithShortcut()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if !self.didReceiveOpenEvent {
                self.log("show-settings:no-open-event")
                self.showSettingsWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow()
        return true
    }

    @objc func showSettingsWindowFromMenu(_ sender: Any?) {
        showSettingsWindow()
    }

    @objc func showAbout(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "NoteDroppy"
        alert.informativeText = """
        Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")

        Ajoute rapidement des tâches dans NotePlan depuis le Dock, le Service macOS ou le raccourci global.

        Repository:
        \(Settings.repositoryURL)
        """
        alert.addButton(withTitle: "GitHub")
        alert.addButton(withTitle: "Aide")
        alert.addButton(withTitle: "OK")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openRepository()
        } else if response == .alertSecondButtonReturn {
            showHelpDocument(named: "HELP", title: "Aide NoteDroppy")
        }
    }

    @objc func openHelp(_ sender: Any?) {
        showHelpDocument(named: "HELP", title: "Aide NoteDroppy")
    }

    @objc func openEnglishHelp(_ sender: Any?) {
        showHelpDocument(named: "HELP.en", title: "NoteDroppy Help")
    }

    @objc func openGitHubRepository(_ sender: Any?) {
        openRepository()
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
            if NSApp.windows.isEmpty {
                NSApp.terminate(nil)
            }
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
            if NSApp.windows.isEmpty {
                NSApp.terminate(nil)
            }
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
            if NSApp.windows.isEmpty {
                NSApp.terminate(nil)
            }
        }
    }

    private func captureSelectedTextWithShortcut() {
        log("shortcut:invoked")
        guard canCaptureFrontmostApplication() else {
            log("shortcut:ignored-frontmost-app")
            NSSound.beep()
            return
        }
        guard isAccessibilityTrusted(prompt: true) else {
            log("shortcut:accessibility-required")
            showSettingsWindow()
            return
        }

        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot(pasteboard: pasteboard)
        let previousChangeCount = pasteboard.changeCount

        guard postCopyShortcut() else {
            log("shortcut:copy-post-failed")
            return
        }

        waitForCopiedText(pasteboard: pasteboard, previousChangeCount: previousChangeCount, attemptsRemaining: 12) { text in
            defer { snapshot.restore(to: pasteboard) }
            guard let text,
                  let normalized = self.normalizedTodoText(text) else {
                self.log("shortcut:no-selected-text")
                return
            }
            self.log("shortcut:text:\(normalized)")
            self.sendTodo(normalized)
        }
    }

    private func waitForCopiedText(
        pasteboard: NSPasteboard,
        previousChangeCount: Int,
        attemptsRemaining: Int,
        completion: @escaping (String?) -> Void
    ) {
        if pasteboard.changeCount != previousChangeCount {
            completion(pasteboard.string(forType: .string))
            return
        }
        guard attemptsRemaining > 0 else {
            completion(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.waitForCopiedText(
                pasteboard: pasteboard,
                previousChangeCount: previousChangeCount,
                attemptsRemaining: attemptsRemaining - 1,
                completion: completion
            )
        }
    }

    private func canCaptureFrontmostApplication() -> Bool {
        if NSApp.isActive {
            return false
        }

        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = frontmost.bundleIdentifier else {
            return true
        }

        let blockedIdentifiers: Set<String> = [
            Bundle.main.bundleIdentifier ?? "",
            "com.apple.systempreferences",
            "com.apple.systemsettings",
            "com.apple.SecurityAgent",
            "com.apple.loginwindow"
        ]
        return !blockedIdentifiers.contains(bundleIdentifier)
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func postCopyShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func sendTodo(_ todoText: String) {
        let trimmed = todoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "(null)" else { return }
        log("sendTodo:\(trimmed)")
        let task = "- [ ] \(trimmed) \(Settings.taskTag)"
        let openNoteValue = Settings.openNote ? "yes" : "no"
        let target = "noteplan://x-callback-url/addText?noteDate=today&text=\(encode(task))&mode=append&openNote=\(openNoteValue)"
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

    private func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
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
appMenu.addItem(withTitle: "À propos de NoteDroppy", action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")
appMenu.addItem(NSMenuItem.separator())
appMenu.addItem(withTitle: "Réglages...", action: #selector(AppDelegate.showSettingsWindowFromMenu(_:)), keyEquivalent: ",")
appMenu.addItem(NSMenuItem.separator())
appMenu.addItem(withTitle: "Quitter NoteDroppy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appMenuItem.submenu = appMenu
app.mainMenu = mainMenu

let helpMenuItem = NSMenuItem()
mainMenu.addItem(helpMenuItem)
let helpMenu = NSMenu(title: "Aide")
helpMenu.addItem(withTitle: "Aide NoteDroppy", action: #selector(AppDelegate.openHelp(_:)), keyEquivalent: "")
helpMenu.addItem(withTitle: "Help NoteDroppy English", action: #selector(AppDelegate.openEnglishHelp(_:)), keyEquivalent: "")
helpMenu.addItem(NSMenuItem.separator())
helpMenu.addItem(withTitle: "GitHub Repository", action: #selector(AppDelegate.openGitHubRepository(_:)), keyEquivalent: "")
helpMenuItem.submenu = helpMenu

app.run()
