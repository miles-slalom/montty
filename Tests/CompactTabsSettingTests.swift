// ABOUTME: Verifies the compact-tabs setting survives a save and restore, and that a
// ABOUTME: session written before the setting existed opens with the full tab rows.

import Foundation
import Testing
@testable import montty_unit

struct CompactTabsSettingTests {
    private func decode(_ json: String) throws -> SessionSnapshot {
        try JSONDecoder().decode(SessionSnapshot.self, from: Data(json.utf8))
    }

    @Test func aNewSnapshotIsNotCompact() {
        #expect(SessionSnapshot().compactTabs == false)
    }

    /// Every session written before this setting existed.
    @Test func aSessionWithoutTheKeyOpensWithFullRows() throws {
        let snapshot = try decode(#"{"version": 4, "windows": [], "surfaceTintEnabled": true}"#)

        #expect(snapshot.compactTabs == false)
    }

    @Test func theSettingRoundTripsThroughJSON() throws {
        var snapshot = SessionSnapshot()
        snapshot.compactTabs = true

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: data)

        #expect(decoded.compactTabs == true)
    }

    @Test func restoringHandsTheSettingToTheShell() {
        let useCases = WindowUseCases(registry: WindowRegistry())
        var saved = SessionSnapshot()
        saved.compactTabs = true

        let outcome = useCases.restore(saved)

        #expect(outcome.applySettings?.compactTabs == true)
    }

    @Test func aSnapshotCarriesTheSetting() {
        let useCases = WindowUseCases(registry: WindowRegistry())

        let snapshot = useCases.snapshot(
            surfaceTint: SurfaceTintSettings(enabled: true, strength: SurfaceTintStrength.default),
            compactTabs: true,
            repoColorOverrides: [:],
            frames: [:],
            directories: [:]
        )

        #expect(snapshot.compactTabs == true)
    }
}
