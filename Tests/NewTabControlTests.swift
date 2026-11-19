// ABOUTME: Verifies `montty tab new` end to end up to the socket: the grammar that parses it,
// ABOUTME: the wire format that carries it, and the directory a relative --dir resolves to.

import Foundation
import Testing
@testable import montty_unit

@Suite struct NewTabControlTests {
    private func newTab(_ args: [String]) -> NewTab? {
        guard case .success(.control(.newTab(let spec))) = ControlArgs.parse(["tab", "new"] + args)
        else { return nil }
        return spec
    }

    private func failure(_ args: [String]) -> ControlArgs.UsageError? {
        guard case .failure(let error) = ControlArgs.parse(["tab", "new"] + args) else { return nil }
        return error
    }

    // MARK: - Grammar

    @Test func bareTabNewOpensAPlainBackgroundTab() {
        #expect(newTab([]) == NewTab())
        #expect(NewTab().focus == false)
        #expect(NewTab().claudePrompt == nil)
    }

    @Test func parsesEveryFlagInAnyOrder() {
        let expected = NewTab(
            directory: "work/montty", name: "review", claudePrompt: "fix the build", focus: true
        )

        #expect(newTab(["--dir", "work/montty", "--name", "review",
                        "--claude", "fix the build", "--focus"]) == expected)
        #expect(newTab(["--focus", "--claude", "fix the build",
                        "--name", "review", "--dir", "work/montty"]) == expected)
    }

    /// A prompt is free text, so one that starts with a dash is still a prompt.
    @Test func aFlagsValueIsTheNextArgumentWhateverItLooksLike() {
        #expect(newTab(["--claude", "--focus"])?.claudePrompt == "--focus")
        #expect(newTab(["--claude", "--focus"])?.focus == false)
    }

    @Test func anEmptyPromptLaunchesClaudeUnseeded() {
        #expect(newTab(["--claude", ""])?.claudePrompt == "")
    }

    @Test func aFlagWithNoValueNamesTheFlag() {
        #expect(failure(["--dir"]) == .missingValue("--dir"))
        #expect(failure(["--name"]) == .missingValue("--name"))
        #expect(failure(["--claude"]) == .missingValue("--claude"))
    }

    @Test func anUnknownFlagIsRefused() {
        #expect(failure(["--bogus"]) == .unknownFlag("--bogus"))
    }

    /// An unquoted prompt splits into words, and applying the first would run a
    /// different command than the one typed.
    @Test func aStrayArgumentIsRefusedNotSwallowed() {
        #expect(failure(["--claude", "fix", "the", "build"]) == .unexpectedArgument("the"))
    }

    @Test func repeatingAFlagIsRefused() {
        #expect(failure(["--name", "a", "--name", "b"]) == .unexpectedArgument("--name"))
    }

    // MARK: - Wire

    private func roundTrip(_ spec: NewTab) throws -> NewTab? {
        let data = try ControlRequest(surface: "M1", command: .newTab(spec)).encoded()
        guard case .newTab(let decoded) = try ControlRequest.decode(data).command else { return nil }
        return decoded
    }

    @Test func aFullRequestRoundTrips() throws {
        let spec = NewTab(
            directory: "/Users/dev/work/montty", name: "review",
            claudePrompt: "line one\nline \"two\" $(whoami)", focus: true
        )

        #expect(try roundTrip(spec) == spec)
    }

    @Test func aBareRequestRoundTrips() throws {
        #expect(try roundTrip(NewTab()) == NewTab())
    }

    @Test func anEmptyPromptSurvivesTheWire() throws {
        #expect(try roundTrip(NewTab(claudePrompt: ""))?.claudePrompt == "")
    }

    @Test func aMissingFocusKeyMeansBackground() throws {
        let json = Data(#"{"v":1,"cmd":"new-tab","surface":"M1"}"#.utf8)

        guard case .newTab(let spec) = try ControlRequest.decode(json).command else {
            Issue.record("not a new-tab command"); return
        }
        #expect(spec == NewTab())
    }

    @Test func aRelativeDirectoryIsRefused() {
        let json = Data(#"{"v":1,"cmd":"new-tab","surface":"M1","dir":"work/montty"}"#.utf8)

        #expect(throws: ControlRequest.DecodeFailure.invalidNewTab) {
            try ControlRequest.decode(json)
        }
    }

    @Test func aPromptWithANulByteIsRefused() {
        let json = Data(#"{"v":1,"cmd":"new-tab","surface":"M1","claude":"a\u0000b"}"#.utf8)

        #expect(throws: ControlRequest.DecodeFailure.invalidNewTab) {
            try ControlRequest.decode(json)
        }
    }

    @Test func aPromptPastTheLimitIsRefused() throws {
        let long = String(repeating: "x", count: NewTab.maxPromptCharacters + 1)
        let data = try ControlRequest(
            surface: "M1", command: .newTab(NewTab(claudePrompt: long))
        ).encoded()

        #expect(throws: ControlRequest.DecodeFailure.invalidNewTab) {
            try ControlRequest.decode(data)
        }
    }

    @Test func aNamePastTheLimitIsRefusedLikeAnyOtherName() throws {
        let long = String(repeating: "n", count: ControlWire.maxNameCharacters + 1)
        let data = try ControlRequest(
            surface: "M1", command: .newTab(NewTab(name: long))
        ).encoded()

        #expect(throws: ControlRequest.DecodeFailure.nameTooLong) {
            try ControlRequest.decode(data)
        }
    }

    // MARK: - Directory resolution

    @Test func aRelativeDirectoryResolvesAgainstTheCallersWorkingDirectory() {
        let resolved = NewTab(directory: "work/montty")
            .resolvingDirectory(cwd: "/Users/dev", home: "/Users/dev")

        #expect(resolved.directory == "/Users/dev/work/montty")
    }

    @Test func dotAndDotDotAreResolved() {
        #expect(NewTab(directory: ".").resolvingDirectory(cwd: "/a/b", home: "/h").directory == "/a/b")
        #expect(NewTab(directory: "../c").resolvingDirectory(cwd: "/a/b", home: "/h").directory == "/a/c")
    }

    @Test func aLeadingTildeIsTheHomeDirectory() {
        #expect(NewTab(directory: "~").resolvingDirectory(cwd: "/a", home: "/h").directory == "/h")
        #expect(NewTab(directory: "~/code").resolvingDirectory(cwd: "/a", home: "/h").directory == "/h/code")
    }

    @Test func anAbsoluteDirectoryIsLeftAlone() {
        #expect(NewTab(directory: "/opt/x").resolvingDirectory(cwd: "/a", home: "/h").directory == "/opt/x")
    }

    @Test func noDirectoryStaysNone() {
        #expect(NewTab().resolvingDirectory(cwd: "/a", home: "/h").directory == nil)
    }
}
