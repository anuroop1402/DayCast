import Testing
import Foundation

/// Makes Clean's dependency rule executable.
///
/// A diagram claiming "Domain imports nothing but Foundation" is a promise. This is a
/// guarantee: it reads the actual source files and fails the build if anyone — including a
/// future me in a hurry — reaches for SwiftUI inside the domain.
///
/// Runs with every ⌘U, so it needs no separate CI wiring.
struct ArchitectureBoundaryTests {

    /// Repo root, derived from this file's compile-time path:
    /// `<root>/DayCastTests/Domain/ArchitectureBoundaryTests.swift`
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Domain
            .deletingLastPathComponent()   // DayCastTests
            .deletingLastPathComponent()   // repo root
    }

    private func swiftFiles(under relativePath: String) throws -> [URL] {
        let directory = repoRoot.appendingPathComponent(relativePath)
        guard let walker = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: nil
        ) else {
            Issue.record("Could not enumerate \(relativePath)")
            return []
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Source with comments stripped.
    ///
    /// The first run of these tests failed on its own false positive: doc comments in
    /// `AppError` and `Repositories` *explain* that the domain avoids `URLSession` and
    /// `UserDefaults`, and a naive text search counted those explanations as violations.
    /// A guard that fires on the documentation of the rule it enforces is worse than no
    /// guard, because it trains you to ignore it.
    private func code(in file: URL) throws -> String {
        var inBlockComment = false
        return try String(contentsOf: file, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var text = String(line)
                if inBlockComment {
                    guard let end = text.range(of: "*/") else { return "" }
                    text = String(text[end.upperBound...])
                    inBlockComment = false
                }
                if let start = text.range(of: "/*") {
                    inBlockComment = true
                    text = String(text[..<start.lowerBound])
                }
                if let start = text.range(of: "//") {
                    text = String(text[..<start.lowerBound])
                }
                return text
            }
            .joined(separator: "\n")
    }

    private func imports(in file: URL) throws -> [String] {
        try code(in: file)
            .split(separator: "\n")
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { return nil }
                return String(trimmed.dropFirst("import ".count))
                    .trimmingCharacters(in: .whitespaces)
            }
    }

    @Test("Domain imports nothing but Foundation")
    func domainIsFrameworkFree() throws {
        let files = try swiftFiles(under: "DayCast/Domain")
        #expect(!files.isEmpty, "found no domain sources — has the path moved?")

        for file in files {
            for module in try imports(in: file) {
                #expect(
                    module == "Foundation",
                    "\(file.lastPathComponent) imports \(module) — the domain must stay framework-free"
                )
            }
        }
    }

    /// Catches the subtler leak: no import, but a `URLSession` or `UserDefaults` reference
    /// that drags infrastructure into the domain through Foundation's back door.
    @Test("Domain contains no infrastructure types", arguments: [
        "URLSession", "URLRequest", "UserDefaults", "FileManager", "NSManagedObject"
    ])
    func domainHasNoInfrastructure(symbol: String) throws {
        for file in try swiftFiles(under: "DayCast/Domain") {
            let source = try code(in: file)
            #expect(
                !source.contains(symbol),
                "\(file.lastPathComponent) references \(symbol) — that belongs in Data."
            )
        }
    }

    @Test("The data layer stays free of UI frameworks")
    func dataLayerHasNoUI() throws {
        for file in try swiftFiles(under: "DayCast/Data") {
            for module in try imports(in: file) {
                #expect(
                    !["SwiftUI", "UIKit"].contains(module),
                    "\(file.lastPathComponent) imports \(module)."
                )
            }
        }
    }

    /// Every rule must live in the scoring folder, so thresholds are never scattered.
    @Test("Scoring rules are confined to Domain/Scoring")
    func rulesLiveTogether() throws {
        let ruleFiles = try swiftFiles(under: "DayCast")
            .filter { $0.lastPathComponent.hasSuffix("Rule.swift") }

        #expect(ruleFiles.count >= 4)
        for file in ruleFiles {
            #expect(
                file.pathComponents.contains("Scoring"),
                "\(file.lastPathComponent) is outside Domain/Scoring."
            )
        }
    }
}
