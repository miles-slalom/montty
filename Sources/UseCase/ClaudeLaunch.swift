// ABOUTME: What a new tab types to launch Claude, and the environment that carries the prompt
// ABOUTME: so no part of it is ever parsed by the shell it is typed into.

import Foundation

/// A line to type into a new surface's shell and run, and the environment that
/// surface starts with.
struct SurfaceLaunch: Equatable {
    let commandLine: String
    var environment: [String: String] = [:]
}

enum ClaudeLaunch {
    /// The variable the prompt travels in. It is the only way the prompt
    /// reaches the new shell, so the line typed there never has to quote it.
    static let seedVariable = "MONTTY_SEED"

    /// Claude, seeded with `prompt` as its first message; an empty prompt runs
    /// it bare.
    ///
    /// The typed line is the same for every prompt. Quoting arbitrary text for
    /// a shell is where injection lives, and a long line typed before the shell
    /// is ready can lose characters, so the text goes in the environment and the
    /// shell only ever sees `"$MONTTY_SEED"`. The `--` ends option parsing, so a
    /// prompt that starts with a dash is a message, not a flag.
    static func launch(prompt: String) -> SurfaceLaunch {
        guard !prompt.isEmpty else { return SurfaceLaunch(commandLine: "claude") }
        return SurfaceLaunch(
            commandLine: "claude -- \"$\(seedVariable)\"",
            environment: [seedVariable: prompt]
        )
    }
}
