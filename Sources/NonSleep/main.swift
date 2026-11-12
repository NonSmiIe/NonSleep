import Foundation

/// `NonSleep --snapshot <folder>` renders the README screenshots and exits.
if let flag = CommandLine.arguments.firstIndex(of: "--snapshot"),
   CommandLine.arguments.indices.contains(flag + 1) {
    let folder = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
    MainActor.assumeIsolated { Snapshot.render(to: folder) }
    exit(0)
}

NonSleepApp.main()
