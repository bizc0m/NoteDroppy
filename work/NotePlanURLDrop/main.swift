import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didReceiveOpenEvent = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("launch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if !self.didReceiveOpenEvent {
                self.log("quit:no-open-event")
                NSApp.terminate(nil)
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

    private func sendTodo(_ todoText: String) {
        let trimmed = todoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "(null)" else { return }
        log("sendTodo:\(trimmed)")
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
app.run()
