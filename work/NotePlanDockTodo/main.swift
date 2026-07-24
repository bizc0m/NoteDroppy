import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if ProcessInfo.processInfo.arguments.count <= 1 {
                self.sendClipboardFallback()
            }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard !filenames.isEmpty else {
            NSApp.reply(toOpenOrPrint: .failure)
            return
        }

        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            sendTodo(for: url)
        }

        NSApp.reply(toOpenOrPrint: .success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            if url.isFileURL {
                sendTodo(for: url)
            } else {
                sendTodo(text: url.absoluteString)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    private func sendClipboardFallback() {
        let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if text.isEmpty {
            showMessage("Glisse un fichier, une URL, ou copie du texte puis relance l'app.")
        } else {
            sendTodo(text: text)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSApp.terminate(nil)
        }
    }

    private func sendTodo(for fileURL: URL) {
        let text = droppedText(from: fileURL)
        if !text.isEmpty {
            sendTodo(text: text)
            return
        }

        let fileTask = "\(fileURL.lastPathComponent) - \(fileURL.absoluteString)"
        sendTodo(text: fileTask)
    }

    private func droppedText(from fileURL: URL) -> String {
        if fileURL.pathExtension.lowercased() == "webloc" {
            if let value = webLocation(from: fileURL), !value.isEmpty {
                return value
            }
        }

        if fileURL.pathExtension.lowercased() == "textclipping" {
            if let value = shell(["/usr/bin/mdls", "-raw", "-name", "kMDItemTextContent", fileURL.path]),
               !value.isEmpty,
               value != "(null)" {
                return value
            }
        }

        guard let type = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return ""
        }

        if type.conforms(to: .plainText) || type.conforms(to: .utf8PlainText) || type.conforms(to: .text) {
            return (try? String(contentsOf: fileURL, encoding: .utf8))
                ?? (try? String(contentsOf: fileURL, encoding: .isoLatin1))
                ?? ""
        }

        if type.conforms(to: .url) {
            return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? fileURL.absoluteString
        }

        return ""
    }

    private func webLocation(from fileURL: URL) -> String? {
        if let data = try? Data(contentsOf: fileURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = plist as? [String: Any],
           let value = dict["URL"] as? String {
            return value
        }

        if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
            if let range = text.range(of: #"https?://[^<\s"]+"#, options: .regularExpression) {
                return String(text[range])
            }
        }

        return nil
    }

    private func sendTodo(text rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let task = "- [ ] \(text) #capture"
        let urlString = "noteplan://x-callback-url/addText?noteDate=today&text=\(encode(task))&mode=append&openNote=yes"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private func shell(_ args: [String]) -> String? {
        guard let launchPath = args.first else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = Array(args.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func showMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "NotePlan Dock Todo"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
