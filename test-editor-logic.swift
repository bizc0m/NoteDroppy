#!/usr/bin/env swift

// Test des fonctions Editor* de NoteDroppy 3.0A
// Ce script teste la logique de tri sans interface GUI

import Foundation

struct TestPrioritySorter {
    static func sort(_ text: String) -> String {
        let hadTrailingNewline = text.hasSuffix("\n")
        let lines = text.components(separatedBy: "\n")
        var output: [String] = []
        var finished: [(originalIndex: Int, lines: [String])] = []
        var i = 0

        func isHeading(_ line: String) -> Bool {
            line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil
        }

        func isTopBullet(_ line: String) -> Bool {
            line.range(of: #"^[-*](\s|$)"#, options: .regularExpression) != nil
        }

        func normalizeMain(_ line: String) -> String {
            if line.range(of: #"^\*\s+\[[ xX]\]"#, options: .regularExpression) != nil {
                return "-" + String(line.dropFirst())
            }
            if line.range(of: #"^\*\s+"#, options: .regularExpression) != nil {
                return line.replacingOccurrences(of: #"^\*\s+"#, with: "- [ ] ", options: .regularExpression)
            }
            return line
        }

        func priority(_ line: String) -> Int {
            guard let range = line.range(of: #"^[-*]\s+(?:\[[ xX]\]\s*)?(!{1,3})(?=\s|$)"#, options: .regularExpression) else {
                return 0
            }
            return line[range].filter { $0 == "!" }.count
        }

        func isFullyDone(_ blockLines: [String]) -> Bool {
            guard let main = blockLines.first,
                  main.range(of: #"^[-*]\s+\[[xX]\]"#, options: .regularExpression) != nil else {
                return false
            }
            for line in blockLines.dropFirst() {
                if line.range(of: #"^\s+[-*]\s+\[\s\]"#, options: .regularExpression) != nil {
                    return false
                }
            }
            return true
        }

        func flush(blocks: inout [(originalIndex: Int, lines: [String])]) {
            let sorted = blocks.sorted { a, b in
                let ap = priority(a.lines.first ?? "")
                let bp = priority(b.lines.first ?? "")
                if ap != bp { return ap > bp }
                return a.originalIndex < b.originalIndex
            }
            for block in sorted {
                if isFullyDone(block.lines) {
                    finished.append(block)
                } else {
                    output.append(contentsOf: block.lines)
                }
            }
            blocks.removeAll()
        }

        while i < lines.count {
            if isHeading(lines[i]) {
                output.append(lines[i])
                i += 1
                continue
            }
            if isTopBullet(lines[i]) {
                var blocks: [(originalIndex: Int, lines: [String])] = []
                let startCount = output.count
                while i < lines.count && !isHeading(lines[i]) {
                    if lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                        flush(blocks: &blocks)
                        output.append(lines[i])
                        i += 1
                    } else if isTopBullet(lines[i]) {
                        var blockLines = [normalizeMain(lines[i])]
                        i += 1
                        while i < lines.count && !isHeading(lines[i]) && !isTopBullet(lines[i]) {
                            blockLines.append(lines[i])
                            i += 1
                        }
                        blocks.append((originalIndex: blocks.count + startCount, lines: blockLines))
                    } else {
                        flush(blocks: &blocks)
                        output.append(lines[i])
                        i += 1
                    }
                }
                flush(blocks: &blocks)
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
            output.append(contentsOf: finished.map { $0.lines }.flatMap { $0 })
        }
        let result = output.joined(separator: "\n")
        return hadTrailingNewline ? result + "\n" : result
    }
}

// MARK: - Tests

func testSortPriorities() {
    print("=== Test 1: Sort Priorities ===")
    
    let input = "# Projet\n- [ ] Tache normale\n- !!! Tache haute priorite\n- !! Tache moyenne priorite\n- ! Tache basse priorite\n- [x] Tache terminee\n"
    
    let result = TestPrioritySorter.sort(input)
    print("INPUT:")
    print(input)
    print("\nOUTPUT:")
    print(result)
    
    let lines = result.components(separatedBy: "\n")
    let taskLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }
    
    // La première tâche non terminée devrait être !!!
    if let firstUnfinished = taskLines.first(where: { !$0.contains("[x]") }) {
        if firstUnfinished.contains("!!!") {
            print("✅ PASS: !!! est en premier")
        } else {
            print("❌ FAIL: !!! n'est pas en premier, trouvé: \(firstUnfinished)")
        }
    }
    
    // Vérifier que [x] est à la fin
    if let lastTask = taskLines.last, lastTask.contains("[x]") {
        print("✅ PASS: [x] est en dernier")
    } else {
        print("❌ FAIL: [x] n'est pas en dernier")
    }
    
    print()
}

// MARK: - Run Tests

print("🧪 NoteDroppy 3.0A — Editor Functions Test Suite")
print("Date: \(Date())")
print(String(repeating: "=", count: 60))
print()

testSortPriorities()

print(String(repeating: "=", count: 60))
print("✅ Tests terminés")
