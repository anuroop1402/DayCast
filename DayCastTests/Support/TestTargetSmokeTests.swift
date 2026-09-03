//
//  TestTargetSmokeTests.swift
//  DayCastTests
//
//  Phase 0 placeholder. Exists so the test target is proven to build, link
//  against the app, and run before any production code is written.
//  Replaced by real domain tests in Phase 1.
//

import Testing
@testable import DayCast

struct TestTargetSmokeTests {

    @Test("Test target builds and can see the app module")
    func testTargetIsWiredUp() {
        // If this compiles, @testable import of the app target resolves,
        // which is the only thing Phase 0 needs to prove.
        #expect(Bool(true))
    }
}
