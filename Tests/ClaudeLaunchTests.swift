// ABOUTME: Verifies the line a new tab types to launch Claude: fixed text that never carries
// ABOUTME: the prompt, which travels in the environment where it cannot be parsed as shell.

import Testing
@testable import montty_unit

struct ClaudeLaunchTests {
    @Test func aPromptIsHandedOverInTheEnvironment() {
        let launch = ClaudeLaunch.launch(prompt: "fix the build")

        #expect(launch.environment == [ClaudeLaunch.seedVariable: "fix the build"])
    }

    @Test func theTypedLineIsFixedWhateverThePrompt() {
        let plain = ClaudeLaunch.launch(prompt: "fix the build").commandLine
        let hostile = ClaudeLaunch.launch(prompt: "x\"; rm -rf ~; echo \"").commandLine

        #expect(plain == hostile)
    }

    /// Whatever is in the prompt, none of it is in the line the shell parses.
    @Test func noPartOfThePromptReachesTheTypedLine() {
        let prompt = "$(whoami) `id` ; \\ ' \" \n --dangerously-skip-permissions"

        let line = ClaudeLaunch.launch(prompt: prompt).commandLine

        #expect(!line.contains("whoami"))
        #expect(!line.contains("dangerously"))
        #expect(!line.contains("\n"))
    }

    /// A prompt that starts with a dash must be a message to Claude, never one
    /// of its flags.
    @Test func optionParsingEndsBeforeThePrompt() {
        let line = ClaudeLaunch.launch(prompt: "--dangerously-skip-permissions").commandLine

        #expect(line == "claude -- \"$\(ClaudeLaunch.seedVariable)\"")
    }

    @Test func anEmptyPromptLaunchesClaudeBare() {
        let launch = ClaudeLaunch.launch(prompt: "")

        #expect(launch.commandLine == "claude")
        #expect(launch.environment.isEmpty)
    }

    /// Multi-line briefs are ordinary, and the environment holds them as they are.
    @Test func aMultiLinePromptIsKeptVerbatim() {
        let prompt = "first line\nsecond line\n\n  indented \"quoted\""

        #expect(ClaudeLaunch.launch(prompt: prompt).environment[ClaudeLaunch.seedVariable] == prompt)
    }
}
