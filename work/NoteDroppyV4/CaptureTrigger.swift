// NoteDroppy V4 — Etape 5 (partie 2) du plan de migration V5
//
// Ce qui se passe quand un raccourci clavier global est declenche : capturer
// le texte selectionne (Accessibilite, avec repli presse-papiers via un
// Cmd+C simule), retrouver l'URL/le document source si possible, puis
// appeler sendTodo (CaptureWriter.swift). Copie depuis les methodes privees
// d'AppDelegate dans NotePlanURLDrop/main.swift, converties en fonctions
// libres regroupees dans l'enum CaptureTrigger (le debounce
// lastShortcutCaptureAt devient un static var prive de cet enum — un seul
// declencheur global existe dans l'app, pas besoin d'instance).
//
// Point d'entree a brancher sur GlobalShortcutMonitor (etape suivante,
// assemblage fenetre) : CaptureTrigger.run(slotIndex:).
//
// Non porte ici (deference volontaire, meme raison que CaptureWriter) :
// la reouverture de la fenetre Reglages quand l'Accessibilite n'est pas
// autorisee (showSettingsWindow() dans l'original) — il n'y a pas encore
// de fenetre equivalente en V4. Remplace par un simple log ; a relier une
// fois la fenetre du tableau de slots assemblee.

import AppKit
import ApplicationServices
import Foundation

struct CaptureSource {
    var url: String
    var title: String?
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

enum CaptureTrigger {
    private static var lastShortcutCaptureAt = Date.distantPast

    static func run(slotIndex: Int) {
        guard Date().timeIntervalSince(lastShortcutCaptureAt) > 0.8 else {
            Log.write("shortcut:debounced:slot:\(slotIndex)")
            return
        }
        lastShortcutCaptureAt = Date()
        let slot = ShortcutSlotStore.shortcutSlot(slotIndex)
        guard slot.enabled else {
            Log.write("shortcut:disabled-slot:\(slotIndex)")
            return
        }
        Log.write("shortcut:invoked:slot:\(slotIndex)")
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if let frontmost = frontmostApplication {
            Log.write("shortcut:frontmost:\(frontmost.localizedName ?? "?"):\(frontmost.bundleIdentifier ?? "?")")
        } else {
            Log.write("shortcut:frontmost:none")
        }
        guard canCaptureFrontmostApplication() else {
            Log.write("shortcut:ignored-frontmost-app")
            NSSound.beep()
            return
        }
        let accessibilityTrusted = isAccessibilityTrusted(prompt: false)
        if !accessibilityTrusted {
            Log.write("shortcut:accessibility-not-trusted:clipboard-only")
            _ = isAccessibilityTrusted(prompt: true)
        }
        let pageSource = sourceWebPage(for: frontmostApplication)
        let documentSource = accessibilityTrusted ? sourceDocumentFileURL(for: frontmostApplication) : nil

        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot(pasteboard: pasteboard)
        let previousChangeCount = pasteboard.changeCount

        guard postCopyShortcut() else {
            Log.write("shortcut:copy-post-failed")
            return
        }

        waitForCopiedText(pasteboard: pasteboard, previousChangeCount: previousChangeCount, attemptsRemaining: 30) { text, pastedSourceURL in
            defer { snapshot.restore(to: pasteboard) }
            let clipboardText = text.flatMap { normalizedTodoText($0) }
            let axText = accessibilityTrusted
                ? selectedTextFromAccessibility().flatMap { normalizedTodoText($0) }
                : nil
            if let normalized = bestShortcutText(clipboardText: clipboardText, axText: axText) {
                Log.write("shortcut:text:\(normalized)")
                let source = pastedSourceURL.map { CaptureSource(url: $0, title: pageSource?.title) } ?? pageSource ?? documentSource
                sendTodo(
                    normalized,
                    shortcutSlot: slot,
                    sourceURL: source?.url,
                    sourceTitle: source?.title,
                    sourceAppName: frontmostApplication?.localizedName,
                    sourceBundleId: frontmostApplication?.bundleIdentifier
                )
                return
            }
            Log.write("shortcut:no-selected-text")
            if !accessibilityTrusted {
                // Original ouvrait la fenetre Reglages ici (Accessibilite
                // pas autorisee -> montrer comment l'accorder). Pas encore
                // de fenetre equivalente en V4 -- a relier une fois le
                // tableau de slots assemble dans une fenetre.
                Log.write("shortcut:accessibility-not-trusted:no-settings-window-yet")
            }
        }
    }
}

private func bestShortcutText(clipboardText: String?, axText: String?) -> String? {
    guard let clipboardText else { return axText }
    guard let axText else { return clipboardText }
    if clipboardText == axText { return clipboardText }
    if clipboardText.hasSuffix(axText) { return axText }
    if axText.hasSuffix(clipboardText) { return clipboardText }
    if clipboardText.contains(axText) { return axText }
    if axText.contains(clipboardText) { return clipboardText }
    return axText
}

private func selectedTextFromAccessibility() -> String? {
    guard let frontmost = NSWorkspace.shared.frontmostApplication else {
        Log.write("shortcut:ax:no-frontmost-app")
        return nil
    }

    let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
    var focusedValue: CFTypeRef?
    let focusedStatus = AXUIElementCopyAttributeValue(
        appElement,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    )
    guard focusedStatus == .success, let focusedValue else {
        Log.write("shortcut:ax:no-focused-element:\(focusedStatus.rawValue)")
        return nil
    }

    let focusedElement = focusedValue as! AXUIElement
    var selectedValue: CFTypeRef?
    let selectedStatus = AXUIElementCopyAttributeValue(
        focusedElement,
        kAXSelectedTextAttribute as CFString,
        &selectedValue
    )
    guard selectedStatus == .success, let selectedText = selectedValue as? String else {
        Log.write("shortcut:ax:no-selected-text:\(selectedStatus.rawValue)")
        return nil
    }

    return selectedText
}

private func sourceWebPage(for application: NSRunningApplication?) -> CaptureSource? {
    guard let appName = application?.localizedName else { return nil }
    let escapedAppName = appName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let script = """
    set frontApp to "\(escapedAppName)"
    set chromiumApps to {"Google Chrome", "Google Chrome Canary", "Brave Browser", "Microsoft Edge", "Arc", "Chromium", "Comet", "Dia", "Vivaldi", "Opera"}
    if frontApp is "Safari" then
        tell application "Safari"
            if (count of windows) > 0 then return (URL of current tab of front window) & linefeed & (name of current tab of front window)
        end tell
    else if chromiumApps contains frontApp then
        using terms from application "Google Chrome"
            tell application frontApp
                if (count of windows) > 0 then return (URL of active tab of front window) & linefeed & (title of active tab of front window)
            end tell
        end using terms from
    end if
    return ""
    """
    guard let output = shell(["/usr/bin/osascript", "-e", script], timeout: 1.0)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        Log.write("source-url:none-or-timeout:\(appName)")
        return nil
    }
    let lines = output.components(separatedBy: .newlines)
    guard let url = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
          isWebURL(url) else {
        Log.write("source-url:none-or-timeout:\(appName)")
        return nil
    }
    let title = cleanSourceTitle(lines.dropFirst().joined(separator: " "))
    Log.write("source-url:\(url)")
    return CaptureSource(url: url, title: title)
}

private func sourceWebURL(from pasteboard: NSPasteboard) -> String? {
    for candidate in pasteboardStrings(from: pasteboard) {
        if isWebURL(candidate), let url = URL(string: candidate), url.host != nil {
            Log.write("source-url:pasteboard:\(candidate)")
            return candidate
        }
    }
    return nil
}

private func sourceDocumentFileURL(for application: NSRunningApplication?) -> CaptureSource? {
    guard ShortcutSlotStore.includeDocumentSource,
          let application,
          let bundleIdentifier = application.bundleIdentifier else {
        return nil
    }
    let blockedIdentifiers: Set<String> = [
        Bundle.main.bundleIdentifier ?? "",
        "com.apple.finder",
        "com.apple.systempreferences",
        "com.apple.systemsettings",
        "com.apple.SecurityAgent",
        "com.apple.loginwindow"
    ]
    guard !blockedIdentifiers.contains(bundleIdentifier) else { return nil }

    let appElement = AXUIElementCreateApplication(application.processIdentifier)
    let focusedWindow = axElementAttribute(appElement, kAXFocusedWindowAttribute)
    let focusedElement = axElementAttribute(appElement, kAXFocusedUIElementAttribute)
    let candidates = [focusedElement, focusedWindow, appElement].compactMap { $0 }
    for element in candidates {
        if let rawDocument = axStringAttribute(element, kAXDocumentAttribute),
           let fileURL = standaloneFileURL(from: rawDocument) {
            let title = axStringAttribute(element, kAXTitleAttribute)
                ?? focusedWindow.flatMap { axStringAttribute($0, kAXTitleAttribute) }
                ?? application.localizedName
            Log.write("source-document:\(fileURL.absoluteString)")
            return CaptureSource(url: fileURL.absoluteString, title: title)
        }
    }
    return nil
}

private func axElementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let value else {
        return nil
    }
    return (value as! AXUIElement)
}

private func axStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let string = value as? String else {
        return nil
    }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func waitForCopiedText(
    pasteboard: NSPasteboard,
    previousChangeCount: Int,
    attemptsRemaining: Int,
    attemptedAppleScriptFallback: Bool = false,
    completion: @escaping (String?, String?) -> Void
) {
    if pasteboard.changeCount != previousChangeCount {
        completion(pasteboard.string(forType: .string), sourceWebURL(from: pasteboard))
        return
    }
    if attemptsRemaining == 15, !attemptedAppleScriptFallback {
        Log.write("shortcut:copy-applescript-fallback:start")
        if postCopyShortcutViaSystemEvents() {
            Log.write("shortcut:copy-applescript-fallback:posted")
        } else {
            Log.write("shortcut:copy-applescript-fallback:failed")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            waitForCopiedText(
                pasteboard: pasteboard,
                previousChangeCount: previousChangeCount,
                attemptsRemaining: attemptsRemaining - 1,
                attemptedAppleScriptFallback: true,
                completion: completion
            )
        }
        return
    }
    guard attemptsRemaining > 0 else {
        Log.write("shortcut:clipboard-unchanged:no-capture")
        completion(nil, nil)
        return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        waitForCopiedText(
            pasteboard: pasteboard,
            previousChangeCount: previousChangeCount,
            attemptsRemaining: attemptsRemaining - 1,
            attemptedAppleScriptFallback: attemptedAppleScriptFallback,
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

func isAccessibilityTrusted(prompt: Bool) -> Bool {
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

private func postCopyShortcutViaSystemEvents() -> Bool {
    let script = """
    tell application "System Events"
      keystroke "c" using command down
    end tell
    """
    var error: NSDictionary?
    guard let appleScript = NSAppleScript(source: script) else { return false }
    appleScript.executeAndReturnError(&error)
    if let error {
        Log.write("shortcut:copy-applescript-fallback:error:\(error)")
        return false
    }
    return true
}

private func isWebURL(_ value: String) -> Bool {
    normalizedWebURL(value) != nil
}

private func normalizedTodoText(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != "(null)" else { return nil }
    return trimmed
}

private func shell(_ args: [String], timeout: TimeInterval? = nil) -> String? {
    guard let executable = args.first else { return nil }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = Array(args.dropFirst())
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        if let timeout {
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                semaphore.signal()
            }
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
                return nil
            }
        } else {
            process.waitUntilExit()
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    } catch {
        return nil
    }
}
