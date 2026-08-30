// NoteDroppy V4 — Moteur
// Copie verbatim du moteur eprouve de work/NoteDroppyV3/main.swift (lignes 1954-3162).
// Aucune modification de logique : tri, recherche, capture, generation Shorty.
// Toute evolution V4 se fait dans main.swift, pas ici.

import AppKit
import Darwin
import Foundation

enum PrioritySorter {
    struct Block {
        let originalIndex: Int
        var lines: [String]
        var main: String { lines.first ?? "" }
    }

    static func sort(_ text: String) -> String {
        let hadTrailingNewline = text.hasSuffix("\n")
        let lines = text.components(separatedBy: "\n")
        var output: [String] = []
        var finished: [Block] = []
        var i = 0

        while i < lines.count {
            if isHeading(lines[i]) {
                output.append(lines[i])
                i += 1
                continue
            }
            if isTopBullet(lines[i]) {
                var blocks: [Block] = []
                let startCount = output.count
                while i < lines.count && !isHeading(lines[i]) {
                    if lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                        flush(blocks: &blocks, into: &output, finished: &finished)
                        output.append(lines[i])
                        i += 1
                    } else if isTopBullet(lines[i]) {
                        var blockLines = [normalizeMain(lines[i])]
                        i += 1
                        while i < lines.count && !isHeading(lines[i]) && !isTopBullet(lines[i]) {
                            blockLines.append(lines[i])
                            i += 1
                        }
                        blocks.append(Block(originalIndex: blocks.count + startCount, lines: blockLines))
                    } else {
                        flush(blocks: &blocks, into: &output, finished: &finished)
                        output.append(lines[i])
                        i += 1
                    }
                }
                flush(blocks: &blocks, into: &output, finished: &finished)
            } else {
                output.append(lines[i])
                i += 1
            }
        }

        while output.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            output.removeLast()
        }
        if !finished.isEmpty {
            output.append("")
            output.append(contentsOf: finished.flatMap(\.lines))
        }
        let result = output.joined(separator: "\n")
        return hadTrailingNewline ? result + "\n" : result
    }

    private static func flush(blocks: inout [Block], into output: inout [String], finished: inout [Block]) {
        let sorted = blocks.sorted { a, b in
            let ap = priority(a.main)
            let bp = priority(b.main)
            if ap != bp { return ap > bp }
            return a.originalIndex < b.originalIndex
        }
        for block in sorted {
            if isFullyDone(block) {
                finished.append(block)
            } else {
                output.append(contentsOf: block.lines)
            }
        }
        blocks.removeAll()
    }

    private static func isHeading(_ line: String) -> Bool {
        line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil
    }

    private static func isTopBullet(_ line: String) -> Bool {
        line.range(of: #"^[-*](\s|$)"#, options: .regularExpression) != nil
    }

    private static func normalizeMain(_ line: String) -> String {
        if line.range(of: #"^\*\s+\[[ xX]\]"#, options: .regularExpression) != nil {
            return "-" + String(line.dropFirst())
        }
        if line.range(of: #"^\*\s+"#, options: .regularExpression) != nil {
            return line.replacingOccurrences(of: #"^\*\s+"#, with: "- [ ] ", options: .regularExpression)
        }
        if line.range(of: #"^-\s+(?!\[[ xX]\]).*!"#, options: .regularExpression) != nil {
            return line.replacingOccurrences(of: #"^-\s+"#, with: "- [ ] ", options: .regularExpression)
        }
        return line
    }

    private static func priority(_ line: String) -> Int {
        guard let range = line.range(of: #"^[-*]\s+(?:\[[ xX]\]\s*)?(!{1,3})(?=\s|$)"#, options: .regularExpression) else {
            return 0
        }
        return line[range].filter { $0 == "!" }.count
    }

    private static func isFullyDone(_ block: Block) -> Bool {
        guard block.main.range(of: #"^[-*]\s+\[[xX]\]"#, options: .regularExpression) != nil else {
            return false
        }
        for line in block.lines.dropFirst() {
            if line.range(of: #"^\s+[-*]\s+\[\s\]"#, options: .regularExpression) != nil {
                return false
            }
        }
        return true
    }
}

enum TaskSorter {
    enum Mode: Equatable {
        case atContext
        case hashTag
        case importance
        case minutes
    }

    struct Block {
        let originalIndex: Int
        let lines: [String]
        var main: String { lines.first ?? "" }
    }

    static func sort(_ text: String, mode: Mode) -> String {
        let hadTrailingNewline = text.hasSuffix("\n")
        let lines = text.components(separatedBy: "\n")
        var blocks: [Block] = []
        var loose: [String] = []
        var i = 0

        while i < lines.count {
            if isTopBullet(lines[i]) {
                var blockLines = [lines[i]]
                i += 1
                while i < lines.count && !isTopBullet(lines[i]) {
                    blockLines.append(lines[i])
                    i += 1
                }
                blocks.append(Block(originalIndex: blocks.count, lines: blockLines))
            } else {
                loose.append(lines[i])
                i += 1
            }
        }

        let sortableBlocks: [Block]
        let unsortedBlocks: [Block]
        if mode == .minutes {
            sortableBlocks = blocks.filter { isTask($0.main) && minutes($0.main) != Int.max }
            unsortedBlocks = blocks.filter { !(isTask($0.main) && minutes($0.main) != Int.max) }
        } else if mode == .importance {
            sortableBlocks = blocks.filter { isTask($0.main) && importance($0.main) != Int.max }
            unsortedBlocks = blocks.filter { !(isTask($0.main) && importance($0.main) != Int.max) }
        } else {
            sortableBlocks = blocks
            unsortedBlocks = []
        }

        let sorted = sortableBlocks.sorted { a, b in
            let ad = isDone(a.main)
            let bd = isDone(b.main)
            if ad != bd { return !ad && bd }

            switch mode {
            case .atContext:
                let ac = token(a.main, prefix: "@")
                let bc = token(b.main, prefix: "@")
                if ac != bc { return ac < bc }
                let am = minutes(a.main)
                let bm = minutes(b.main)
                if am != bm { return am < bm }
            case .hashTag:
                let ac = token(a.main, prefix: "#")
                let bc = token(b.main, prefix: "#")
                if ac != bc { return ac < bc }
                let am = minutes(a.main)
                let bm = minutes(b.main)
                if am != bm { return am < bm }
            case .importance:
                let ai = importance(a.main)
                let bi = importance(b.main)
                if ai != bi { return ai < bi }
                let am = minutes(a.main)
                let bm = minutes(b.main)
                if am != bm { return am < bm }
            case .minutes:
                let am = minutes(a.main)
                let bm = minutes(b.main)
                if am != bm { return am < bm }
                return a.originalIndex < b.originalIndex
            }

            let ap = priority(a.main)
            let bp = priority(b.main)
            if ap != bp { return ap > bp }
            return a.originalIndex < b.originalIndex
        }

        var output = loose.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !output.isEmpty && !sorted.isEmpty { output.append("") }
        output.append(contentsOf: sorted.flatMap(\.lines))
        if !unsortedBlocks.isEmpty {
            if !output.isEmpty { output.append("") }
            output.append(contentsOf: unsortedBlocks.sorted { $0.originalIndex < $1.originalIndex }.flatMap(\.lines))
        }
        let result = output.joined(separator: "\n")
        return hadTrailingNewline ? result + "\n" : result
    }

    static func isTask(_ line: String) -> Bool {
        line.range(of: #"^\s*[-*]\s+\[[ xX]\]"#, options: .regularExpression) != nil
    }

    static func isDone(_ line: String) -> Bool {
        line.range(of: #"^\s*[-*]\s+\[[xX]\]"#, options: .regularExpression) != nil
    }

    static func minutes(_ line: String) -> Int {
        guard let range = line.range(of: #"--\s*\d+\b"#, options: .regularExpression) else {
            return Int.max
        }
        let value = line[range].replacingOccurrences(of: #"--\s*"#, with: "", options: .regularExpression)
        return Int(value) ?? Int.max
    }

    static func importance(_ line: String) -> Int {
        guard let range = line.range(of: #"\^\^\s*[ABCabc123]\b"#, options: .regularExpression) else {
            return Int.max
        }
        let raw = line[range]
            .replacingOccurrences(of: #"^\^\^\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        switch raw {
        case "A", "1":
            return 1
        case "B", "2":
            return 2
        case "C", "3":
            return 3
        default:
            return Int.max
        }
    }

    private static func isTopBullet(_ line: String) -> Bool {
        line.range(of: #"^\s*[-*](\s|$)"#, options: .regularExpression) != nil
    }

    private static func token(_ line: String, prefix: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: prefix)
        if let range = line.range(of: "\(escaped)[A-Za-z0-9_À-ÿ-]+", options: .regularExpression) {
            return String(line[range]).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
        return "zz_sans_\(prefix)"
    }

    private static func priority(_ line: String) -> Int {
        guard let range = line.range(of: #"!{1,3}"#, options: .regularExpression) else {
            return 0
        }
        return line[range].filter { $0 == "!" }.count
    }
}

enum TaskSearch {
    enum Scope {
        case calendarOnly
        case calendarAndNotes
    }

    enum Bucket {
        case max(Int)
        case moreThan(Int)
    }

    struct Result {
        let path: String
        let line: Int
        let text: String
    }

    static func search(rootURL: URL, query: String, bucket: Bucket?, scope: Scope) throws -> [Result] {
        let files = try markdownFiles(rootURL: rootURL, scope: scope)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var results: [Result] = []

        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let rel = file.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            for (index, line) in content.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard isTaskLine(trimmed), !TaskSorter.isDone(trimmed) else { continue }
                if !normalizedQuery.isEmpty && !trimmed.lowercased().contains(normalizedQuery) { continue }
                if let bucket, !matches(bucket: bucket, minutes: TaskSorter.minutes(trimmed)) { continue }
                results.append(Result(path: rel, line: index + 1, text: trimmed))
            }
        }

        return results.sorted {
            let am = TaskSorter.minutes($0.text)
            let bm = TaskSorter.minutes($1.text)
            if am != bm { return am < bm }
            if $0.path != $1.path { return $0.path < $1.path }
            return $0.line < $1.line
        }
    }

    private static func markdownFiles(rootURL: URL, scope: Scope) throws -> [URL] {
        let rootNames: [String]
        switch scope {
        case .calendarOnly:
            rootNames = ["Calendar"]
        case .calendarAndNotes:
            rootNames = ["Calendar", "Notes"]
        }
        let roots = rootNames.map { rootURL.appendingPathComponent($0) }
        var output: [URL] = []
        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let file as URL in enumerator {
                let path = file.path
                if path.contains("/@Trash/") || path.contains("/Backups/") || path.contains("/Plugins/") || path.contains("/Logs/") {
                    continue
                }
                if file.pathExtension.lowercased() == "md" {
                    output.append(file)
                }
            }
        }
        return output
    }

    private static func isTaskLine(_ line: String) -> Bool {
        line.range(of: #"^\s*[-*]\s+"#, options: .regularExpression) != nil
    }

    private static func matches(bucket: Bucket, minutes: Int) -> Bool {
        guard minutes != Int.max else { return false }
        switch bucket {
        case .max(let value):
            return minutes <= value
        case .moreThan(let value):
            return minutes > value
        }
    }
}

enum ChapterFlattener {
    struct Item {
        let text: String
        let chapter: String
        let priority: Int
        let index: Int
    }

    static func flatten(_ text: String) -> String {
        var currentChapter: String?
        var items: [Item] = []

        for (index, rawLine) in text.components(separatedBy: "\n").enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            if let heading = headingTitle(line) {
                currentChapter = heading
                continue
            }

            let detectedPriority = priority(line)
            let item = URLLineFormatter.withHostPrefix(cleanedItem(line))
            if item.isEmpty { continue }
            let chapter = currentChapter ?? "Sans chapitre"
            items.append(Item(text: item, chapter: chapter, priority: detectedPriority, index: index))
        }

        let prioritized = items
            .filter { $0.priority > 0 }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.index < $1.index
            }
        let normal = items.filter { $0.priority == 0 }.sorted { $0.index < $1.index }
        let output = (prioritized + normal).map { item in
            if item.chapter.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == "taches prioritaires" {
                return "- \(item.text)"
            }
            return "- \(item.text) (\(item.chapter))"
        }
        return output.joined(separator: "\n") + (output.isEmpty ? "" : "\n")
    }

    private static func headingTitle(_ line: String) -> String? {
        guard let range = line.range(of: #"^#{1,6}\s+.+"#, options: .regularExpression) else {
            return nil
        }
        let heading = String(line[range])
            .replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return heading.isEmpty ? nil : heading
    }

    private static func cleanedItem(_ line: String) -> String {
        var item = line.trimmingCharacters(in: .whitespacesAndNewlines)
        item = item.replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
        item = item.replacingOccurrences(of: #"^\[[ xX]\]\s+"#, with: "", options: .regularExpression)
        item = item.replacingOccurrences(of: #"^!{1,3}\s+"#, with: "", options: .regularExpression)
        return item.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func priority(_ line: String) -> Int {
        let cleaned = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\[[ xX]\]\s+"#, with: "", options: .regularExpression)
        guard let range = cleaned.range(of: #"^!{1,3}(?=\s|$)"#, options: .regularExpression) else {
            return 0
        }
        return cleaned[range].filter { $0 == "!" }.count
    }
}

enum URLLineFormatter {
    static func normalizedWebURL(_ value: String) -> String? {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]{}\"'.,;"))
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let withScheme = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
            ? trimmed
            : "https://\(trimmed)"
        guard var components = URLComponents(string: withScheme),
              components.scheme?.hasPrefix("http") == true,
              components.host?.contains(".") == true else {
            return nil
        }
        let trackingNames = Set(["_gl", "_gs", "gclid", "gbraid", "wbraid", "fbclid", "msclkid", "yclid"])
        components.queryItems = components.queryItems?.filter { item in
            let name = item.name.lowercased()
            return !name.hasPrefix("utm_") && !trackingNames.contains(name)
        }
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }
        components.fragment = nil
        return components.url?.absoluteString
    }

    static func withHostPrefix(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let urlRange = trimmed.range(of: #"https?://[^\s)\]]+"#, options: .regularExpression) else {
            return trimmed
        }
        let urlText = String(trimmed[urlRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
        guard let url = URL(string: urlText), let host = url.host, !host.isEmpty else {
            return trimmed
        }
        let cleanHost = host.replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
        if trimmed.hasPrefix(cleanHost + " ") || trimmed.hasPrefix(cleanHost + " - ") {
            return trimmed
        }
        return "\(cleanHost) \(trimmed)"
    }
}

enum AIConversationDeeplink {
    struct Result {
        let ref: String
        let markdown: String
    }

    static func normalizedConversationURL(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("claude://") else {
            return nil
        }
        guard trimmed.contains("chatgpt.com/") || trimmed.contains("claude.ai/") || trimmed.contains("perplexity.ai/") else {
            return nil
        }
        return trimmed
    }

    static func generate(urlString: String, title: String) throws -> Result {
        guard let normalized = normalizedConversationURL(urlString) else {
            throw NSError(domain: "AIConversationDeeplink", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL ChatGPT, Claude ou Perplexity invalide"])
        }
        let ref = makeRef()
        let label = clientLabel(for: normalized)
        let base = stripHash(normalized)
        let resumeURL: String
        if label == "Claude", base.hasPrefix("https://claude.ai/chat/") {
            resumeURL = "claude://" + String(base.dropFirst("https://".count)) + "#\(ref)"
        } else {
            resumeURL = base + "#\(ref)"
        }
        let safeTitle = normalizeTitle(title)
        let markdown = "- [\(safeTitle)](\(resumeURL)) - \(ref) - \(label)\n  Ancre: `[\(ref)]`"
        return Result(ref: ref, markdown: markdown)
    }

    private static func makeRef() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let day = formatter.string(from: Date())
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var suffix = ""
        for _ in 0..<3 {
            suffix.append(letters[Int(arc4random_uniform(UInt32(letters.count)))])
        }
        return "\(day)-\(suffix)"
    }

    private static func clientLabel(for url: String) -> String {
        if url.contains("claude.ai/") || url.hasPrefix("claude://") {
            return "Claude"
        }
        if url.contains("chatgpt.com/") {
            return "ChatGPT"
        }
        if url.contains("perplexity.ai/") {
            return "Perplexity"
        }
        return "IA"
    }

    private static func stripHash(_ value: String) -> String {
        String(value.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    private static func normalizeTitle(_ value: String) -> String {
        let collapsed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return String(collapsed.prefix(60))
    }
}

enum PromptIndexSearch {
    struct Result {
        let path: String
        let line: Int
        let text: String
    }

    static func search(indexURL: URL, query: String) throws -> [Result] {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: indexURL.path, isDirectory: &isDir) else {
            throw NSError(domain: "PromptIndexSearch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Index prompts introuvable: \(indexURL.path)"])
        }
        let matcher = try BooleanQueryParser.parse(query)
        let files = isDir.boolValue ? markdownLikeFiles(in: indexURL) : [indexURL]
        var results: [Result] = []
        for file in files {
            let content = try String(contentsOf: file, encoding: .utf8)
            let relative = isDir.boolValue ? file.path.replacingOccurrences(of: indexURL.path + "/", with: "") : file.lastPathComponent
            for (idx, line) in content.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if matcher.matches(trimmed) {
                    results.append(Result(path: relative, line: idx + 1, text: trimmed))
                    if results.count >= 300 { return results }
                }
            }
        }
        return results
    }

    private static func markdownLikeFiles(in root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let allowed = Set(["md", "txt", "json", "jsonl"])
        var output: [URL] = []
        for case let file as URL in enumerator {
            let path = file.path
            if path.contains("/.git/") || path.contains("/node_modules/") || path.contains("/releases/") || path.contains("/DerivedData/") {
                continue
            }
            if allowed.contains(file.pathExtension.lowercased()) {
                output.append(file)
            }
        }
        return output.sorted { $0.path < $1.path }
    }
}

indirect enum BooleanQuery {
    case term(String)
    case not(BooleanQuery)
    case and(BooleanQuery, BooleanQuery)
    case or(BooleanQuery, BooleanQuery)

    func matches(_ text: String) -> Bool {
        let foldedText = Self.fold(text)
        switch self {
        case .term(let value):
            return foldedText.contains(Self.fold(value))
        case .not(let query):
            return !query.matches(text)
        case .and(let left, let right):
            return left.matches(text) && right.matches(text)
        case .or(let left, let right):
            return left.matches(text) || right.matches(text)
        }
    }

    private static func fold(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
    }
}

enum BooleanQueryParser {
    enum Token: Equatable {
        case word(String)
        case and
        case or
        case not
        case lparen
        case rparen
    }

    static func parse(_ raw: String) throws -> BooleanQuery {
        let tokens = tokenize(raw)
        guard !tokens.isEmpty else {
            throw NSError(domain: "BooleanQueryParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recherche vide"])
        }
        var parser = Parser(tokens: tokens)
        let query = try parser.parseExpression()
        guard parser.isAtEnd else {
            throw NSError(domain: "BooleanQueryParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expression booléenne invalide"])
        }
        return query
    }

    private static func tokenize(_ raw: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var quoted = false

        func flush() {
            let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
            current = ""
            guard !value.isEmpty else { return }
            switch value.uppercased() {
            case "AND":
                tokens.append(.and)
            case "OR":
                tokens.append(.or)
            case "NOT":
                tokens.append(.not)
            default:
                tokens.append(.word(value))
            }
        }

        for char in raw {
            if char == "\"" {
                if quoted {
                    flush()
                    quoted = false
                } else {
                    flush()
                    quoted = true
                }
            } else if quoted {
                current.append(char)
            } else if char == "(" {
                flush()
                tokens.append(.lparen)
            } else if char == ")" {
                flush()
                tokens.append(.rparen)
            } else if char.isWhitespace {
                flush()
            } else {
                current.append(char)
            }
        }
        flush()
        return insertImplicitAnd(tokens)
    }

    private static func insertImplicitAnd(_ tokens: [Token]) -> [Token] {
        var output: [Token] = []
        for token in tokens {
            if let previous = output.last, needsImplicitAnd(after: previous, before: token) {
                output.append(.and)
            }
            output.append(token)
        }
        return output
    }

    private static func needsImplicitAnd(after left: Token, before right: Token) -> Bool {
        let leftIsValue = {
            if case .word = left { return true }
            return left == .rparen
        }()
        let rightIsValue = {
            if case .word = right { return true }
            return right == .lparen || right == .not
        }()
        return leftIsValue && rightIsValue
    }

    private struct Parser {
        var tokens: [Token]
        var index = 0
        var isAtEnd: Bool { index >= tokens.count }

        mutating func parseExpression() throws -> BooleanQuery {
            try parseOr()
        }

        mutating private func parseOr() throws -> BooleanQuery {
            var expr = try parseAnd()
            while match(.or) {
                expr = .or(expr, try parseAnd())
            }
            return expr
        }

        mutating private func parseAnd() throws -> BooleanQuery {
            var expr = try parseUnary()
            while match(.and) {
                expr = .and(expr, try parseUnary())
            }
            return expr
        }

        mutating private func parseUnary() throws -> BooleanQuery {
            if match(.not) {
                return .not(try parseUnary())
            }
            return try parsePrimary()
        }

        mutating private func parsePrimary() throws -> BooleanQuery {
            if isAtEnd {
                throw NSError(domain: "BooleanQueryParser", code: 3, userInfo: [NSLocalizedDescriptionKey: "Terme manquant"])
            }
            let token = tokens[index]
            index += 1
            switch token {
            case .word(let value):
                return .term(value)
            case .lparen:
                let expr = try parseExpression()
                guard match(.rparen) else {
                    throw NSError(domain: "BooleanQueryParser", code: 4, userInfo: [NSLocalizedDescriptionKey: "Parenthèse fermante manquante"])
                }
                return expr
            default:
                throw NSError(domain: "BooleanQueryParser", code: 5, userInfo: [NSLocalizedDescriptionKey: "Terme booléen invalide"])
            }
        }

        mutating private func match(_ token: Token) -> Bool {
            guard !isAtEnd, tokens[index] == token else { return false }
            index += 1
            return true
        }
    }
}

enum NotePlanShortcutError: LocalizedError {
    case notMarkdown
    case emptyNoteName
    case cancelled
    case verificationFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notMarkdown:
            return "Le fichier choisi doit être une note .md."
        case .emptyNoteName:
            return "Le nom de la note est vide."
        case .cancelled:
            return "Opération annulée."
        case .verificationFailed(let message), .commandFailed(let message):
            return message
        }
    }
}

struct ShortcutResult {
    let noteName: String
    let noteURLString: String
    let appURL: URL
}

struct NotePlanShortcutGenerator {
    static func generate(
        noteURL: URL,
        destinationURL: URL,
        confirmReplace: (URL) -> Bool = { _ in true }
    ) throws -> ShortcutResult {
        guard noteURL.pathExtension.lowercased() == "md" else {
            throw NotePlanShortcutError.notMarkdown
        }

        let noteName = noteURL.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
        guard !noteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NotePlanShortcutError.emptyNoteName
        }

        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let appURL = destinationURL.appendingPathComponent("\(noteName).app", isDirectory: true)
        if FileManager.default.fileExists(atPath: appURL.path) {
            guard confirmReplace(appURL) else {
                throw NotePlanShortcutError.cancelled
            }
            try FileManager.default.removeItem(at: appURL)
        }

        let noteURLString = "noteplan://x-callback-url/openNote?noteTitle=\(urlEncode(noteName))"
        let finalAppPath = destinationURL.path + "/" + noteName + ".app"
        try compileShortcutApp(
            noteURLString: noteURLString,
            appName: noteName,
            finalAppPath: finalAppPath,
            destinationDir: destinationURL
        )
        try verify(appURL: appURL, noteName: noteName, noteURLString: noteURLString)

        return ShortcutResult(noteName: noteName, noteURLString: noteURLString, appURL: appURL)
    }

    static func generate(
        noteURLString: String,
        appName: String,
        destinationURL: URL,
        confirmReplace: (URL) -> Bool = { _ in true }
    ) throws -> ShortcutResult {
        guard URLComponents(string: noteURLString)?.scheme?.lowercased() == "noteplan" else {
            throw NotePlanShortcutError.commandFailed("URL NotePlan invalide.")
        }

        let noteName = sanitizedAppName(appName)
        guard !noteName.isEmpty else {
            throw NotePlanShortcutError.emptyNoteName
        }

        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let appURL = destinationURL.appendingPathComponent("\(noteName).app", isDirectory: true)
        if FileManager.default.fileExists(atPath: appURL.path) {
            guard confirmReplace(appURL) else {
                throw NotePlanShortcutError.cancelled
            }
            try FileManager.default.removeItem(at: appURL)
        }

        let finalAppPath = destinationURL.path + "/" + noteName + ".app"
        try compileShortcutApp(
            noteURLString: noteURLString,
            appName: noteName,
            finalAppPath: finalAppPath,
            destinationDir: destinationURL
        )
        try verify(appURL: appURL, noteName: noteName, noteURLString: noteURLString)

        return ShortcutResult(noteName: noteName, noteURLString: noteURLString, appURL: appURL)
    }

    private static func sanitizedAppName(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:")
        let cleaned = value
            .components(separatedBy: forbidden)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
        return cleaned.isEmpty ? "NotePlan Shortcut" : cleaned
    }

    private static func compileShortcutApp(noteURLString: String, appName: String, finalAppPath: String, destinationDir: URL) throws {
        let script = """
        tell application "NotePlan" to activate
        open location "\(noteURLString)"
        """
        let tempAppURL = destinationDir.appendingPathComponent(".nps-tmp-\(UUID().uuidString).app")

        do {
            try run("/usr/bin/osacompile", ["-o", tempAppURL.path, "-e", script])
            let plistURL = tempAppURL.appendingPathComponent("Contents/Info.plist")
            try setPlistStrings(
                [
                    "CFBundleName": appName,
                    "CFBundleDisplayName": appName,
                    "NotePlanShortcutURL": noteURLString
                ],
                plistURL: plistURL
            )
            try renamePreservingUnicode(fromPath: tempAppURL.path, toPath: finalAppPath)
        } catch {
            try? FileManager.default.removeItem(at: tempAppURL)
            throw error
        }
    }

    private static func setPlistStrings(_ values: [String: String], plistURL: URL) throws {
        let data = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NotePlanShortcutError.commandFailed("Info.plist illisible: \(plistURL.path)")
        }
        for (key, value) in values {
            plist[key] = value
        }
        let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try newData.write(to: plistURL)
    }

    private static func renamePreservingUnicode(fromPath: String, toPath: String) throws {
        let result = fromPath.withCString { src in
            toPath.withCString { dst in
                rename(src, dst)
            }
        }
        guard result == 0 else {
            throw NotePlanShortcutError.commandFailed("rename() a échoué: \(String(cString: strerror(errno)))")
        }
    }

    private static func verify(appURL: URL, noteName: String, noteURLString: String) throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: le dossier .app n'existe pas.")
        }
        guard appURL.lastPathComponent == "\(noteName).app" else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: nom .app incorrect.")
        }

        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let bundleName = try plistValue("CFBundleName", plistURL: plistURL)
        let displayName = try plistValue("CFBundleDisplayName", plistURL: plistURL)
        let storedURL = try plistValue("NotePlanShortcutURL", plistURL: plistURL)

        guard bundleName == noteName else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: CFBundleName incorrect.")
        }
        guard displayName == noteName else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: CFBundleDisplayName incorrect.")
        }
        guard storedURL == noteURLString else {
            throw NotePlanShortcutError.verificationFailed("Vérification échouée: URL NotePlan incorrecte.")
        }
    }

    private static func plistValue(_ key: String, plistURL: URL) throws -> String {
        try runAndCapture("/usr/bin/plutil", ["-extract", key, "raw", plistURL.path])
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        _ = try runAndCapture(executable, arguments)
    }

    private static func runAndCapture(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw NotePlanShortcutError.commandFailed(errorText.isEmpty ? outputText : errorText)
        }
        return outputText
    }

    static func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private enum MarkdownHighlighter {
    enum Palette: String, CaseIterable {
        case notePlan = "NotePlan"
        case contrast = "Contraste"
        case soft = "Douce"
    }

    static var palette: Palette = {
        if let value = UserDefaults.standard.string(forKey: "markdownPalette"),
           let palette = Palette(rawValue: value) {
            return palette
        }
        return .notePlan
    }()

    private static let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    static func apply(to storage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        storage.beginEditing()
        storage.setAttributes(baseAttributes(), range: fullRange)

        let text = storage.string as NSString
        text.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            styleLine(in: storage, nsText: text, lineRange: lineRange)
        }

        applyRegex(#"`[^`]+`"#, storage: storage, fullRange: fullRange, color: .secondaryLabelColor, font: codeFont)
        applyRegex(#"#[\p{L}\p{N}_/-]+"#, storage: storage, fullRange: fullRange, color: NSColor.systemOrange)
        applyRegex(#"(?<!\S)@[\p{L}\p{N}_/-]+"#, storage: storage, fullRange: fullRange, color: NSColor.systemBlue)
        applyRegex(#">\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?"#, storage: storage, fullRange: fullRange, color: NSColor.systemPurple)
        applyRegex(#"\b\d{1,2}:\d{2}\b"#, storage: storage, fullRange: fullRange, color: NSColor.systemPurple)
        applyMarkdownLinks(to: storage, fullRange: fullRange)

        storage.endEditing()
    }

    private static func styleLine(in storage: NSTextStorage, nsText: NSString, lineRange: NSRange) {
        guard lineRange.length > 0 else { return }
        let line = nsText.substring(with: lineRange)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indent = line.prefix { $0 == " " || $0 == "\t" }.count

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 1
        paragraph.headIndent = CGFloat(min(indent, 12)) * 7
        storage.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)

        if trimmed.hasPrefix("#") {
            let level = min(trimmed.prefix { $0 == "#" }.count, 4)
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: CGFloat(max(20 - level * 2, 14)), weight: .bold),
                .foregroundColor: NSColor.systemOrange
            ], range: lineRange)
            return
        }

        if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("* [x]") || trimmed.hasPrefix("- [X]") || trimmed.hasPrefix("* [X]") {
            storage.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ], range: lineRange)
        } else if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("* [ ]") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            storage.addAttribute(.foregroundColor, value: colorForIndent(indent), range: lineRange)
        }

        styleUrgency(in: storage, nsText: nsText, lineRange: lineRange, line: line)
    }

    private static func styleUrgency(in storage: NSTextStorage, nsText: NSString, lineRange: NSRange, line: String) {
        let urgency: (token: String, color: NSColor, background: NSColor)?
        if line.contains("!!!") {
            urgency = ("!!!", .white, NSColor.systemRed.withAlphaComponent(0.78))
        } else if line.contains("!!") {
            urgency = ("!!", NSColor.systemRed, NSColor.systemRed.withAlphaComponent(0.16))
        } else if line.contains("!") {
            urgency = ("!", NSColor.systemOrange, NSColor.systemOrange.withAlphaComponent(0.12))
        } else {
            urgency = nil
        }
        guard let urgency else { return }

        storage.addAttribute(.backgroundColor, value: urgency.background, range: lineRange)
        var searchStart = lineRange.location
        let lineEnd = lineRange.location + lineRange.length
        while searchStart < lineEnd {
            let found = nsText.range(of: urgency.token, options: [], range: NSRange(location: searchStart, length: lineEnd - searchStart))
            if found.location == NSNotFound { break }
            storage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold),
                .foregroundColor: urgency.color
            ], range: found)
            searchStart = found.location + max(found.length, 1)
        }
    }

    private static func applyRegex(_ pattern: String, storage: NSTextStorage, fullRange: NSRange, color: NSColor, font: NSFont? = nil) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        regex.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let range = match?.range, range.location != NSNotFound else { return }
            storage.addAttribute(.foregroundColor, value: color, range: range)
            if let font {
                storage.addAttribute(.font, value: font, range: range)
            }
        }
    }

    private static func applyMarkdownLinks(to storage: NSTextStorage, fullRange: NSRange) {
        applyLinkRegex(
            #"\[([^\]\n]+)\]\\?\(\[(https?://[^\]\n]+)\]\((https?://[^)\s]+)\)\)"#,
            storage: storage,
            fullRange: fullRange,
            titleGroup: 1,
            urlGroup: 3
        )
        applyLinkRegex(
            #"(?<!\()\[([^\]\n]+)\]\((https?://[^)\s]+)\)"#,
            storage: storage,
            fullRange: fullRange,
            titleGroup: 1,
            urlGroup: 2
        )
    }

    private static func applyLinkRegex(_ pattern: String, storage: NSTextStorage, fullRange: NSRange, titleGroup: Int, urlGroup: Int) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let text = storage.string as NSString
        regex.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let match else { return }
            let titleRange = match.range(at: titleGroup)
            let urlRange = match.range(at: urlGroup)
            guard titleRange.location != NSNotFound, urlRange.location != NSNotFound else { return }
            let urlString = text.substring(with: urlRange)
            guard let url = URL(string: urlString) else { return }

            let hiddenAttributes: [NSAttributedString.Key: Any] = [
                .link: url,
                .foregroundColor: NSColor.clear,
                .font: NSFont.monospacedSystemFont(ofSize: 0.1, weight: .regular)
            ]
            let titleStart = titleRange.location
            let titleEnd = titleRange.location + titleRange.length
            let matchEnd = match.range.location + match.range.length

            if titleStart > match.range.location {
                storage.addAttributes(hiddenAttributes, range: NSRange(location: match.range.location, length: titleStart - match.range.location))
            }
            if matchEnd > titleEnd {
                storage.addAttributes(hiddenAttributes, range: NSRange(location: titleEnd, length: matchEnd - titleEnd))
            }
            if titleEnd < matchEnd {
                storage.addAttributes(arrowAttributes(url: url), range: NSRange(location: titleEnd, length: 1))
            }
            storage.addAttributes([
                .link: url,
                .foregroundColor: NSColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
            ], range: titleRange)
        }
    }

    private static func arrowAttributes(url: URL) -> [NSAttributedString.Key: Any] {
        let attachment = NSTextAttachment()
        if let image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: "Ouvrir le lien") {
            image.isTemplate = true
            attachment.image = image
            attachment.bounds = NSRect(x: 1, y: -1, width: 10, height: 10)
        }
        return [
            .attachment: attachment,
            .link: url,
            .foregroundColor: NSColor.systemBlue,
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        ]
    }

    private static func baseAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor.textBackgroundColor
        ]
    }

    private static func colorForIndent(_ indent: Int) -> NSColor {
        let level = max(0, min(indent / 2, 5))
        switch palette {
        case .notePlan:
            let colors: [NSColor] = [.labelColor, .systemOrange, .systemTeal, .systemBlue, .systemIndigo, .secondaryLabelColor]
            return colors[level]
        case .contrast:
            let colors: [NSColor] = [.labelColor, .systemRed, .systemOrange, .systemGreen, .systemBlue, .systemPurple]
            return colors[level]
        case .soft:
            let colors: [NSColor] = [.labelColor, .systemBrown, .systemMint, .systemCyan, .systemGray, .secondaryLabelColor]
            return colors[level]
        }
    }
}

