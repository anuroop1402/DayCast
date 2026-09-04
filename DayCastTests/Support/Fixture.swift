import Foundation

/// Loads captured API responses from `DayCastTests/Fixtures`.
///
/// Resolved from `#filePath` rather than the test bundle, so the fixtures need no resource
/// build phase and the tests do not depend on how Xcode chose to package them.
enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // Support
            .deletingLastPathComponent()          // DayCastTests
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        return try Data(contentsOf: url)
    }
}
