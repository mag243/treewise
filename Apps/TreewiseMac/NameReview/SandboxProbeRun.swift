#if TREEWISE_PROBE
    import Foundation
    import TreewiseCore
    import TreewiseModuleInterface
    import TreewiseModuleXPC

    /// Runs the sandbox probe of the probe build (`tools/build.sh probe`) and quits, before
    /// any window opens. The app first does each try itself, so a path or address that is
    /// wrong fails the probe; the service must then meet the sandbox's denial, `EPERM`, in
    /// every try.
    enum SandboxProbeRun {
        private static let argument = "-TreewiseProbe"
        private static let probeID = "me.m-domain.treewise.sandbox-probe"
        private static let denied = "errno \(EPERM)"
        private static let ok = "ok"
        /// An address on the internet, for an outgoing connection.
        private static let farAddress = "1.1.1.1:443"

        /// Runs the probe when the app was started with `-TreewiseProbe <file>`; the file is
        /// one the service must not read.
        static func runIfAsked() {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count
            else { return }
            let file = arguments[index + 1]
            Task.detached { exit(await run(file: file) ? EXIT_SUCCESS : EXIT_FAILURE) }
            while true { RunLoop.main.run() }
        }

        private static func run(file: String) async -> Bool {
            guard let listener = LocalListener() else { return report("no listener", false) }
            defer { listener.close() }
            let home = NSHomeDirectory()
            let near = "127.0.0.1:\(listener.port)"
            let tries = [
                ("read", file, FileManager.default.isReadableFile(atPath: file)),
                ("list", home, (try? FileManager.default.contentsOfDirectory(atPath: home)) != nil),
                ("connect0", near, LocalListener.canConnect(to: listener.port)),
                ("connect1", farAddress, true),
            ]
            guard tries.allSatisfy(\.2) else {
                return report("the app itself fails a try: \(tries.filter { !$0.2 })", false)
            }
            let request = NameRequest(
                id: "probe", name: file, contentType: "public.data", byteCount: nil, created: nil,
                modified: nil, siblingNames: [home, near, farAddress], content: ModuleContent())
            guard
                let answer = try? await XPCModuleHost().fieldValues(
                    moduleID: probeID, request: request
                ).first
            else { return report("the service gave no answer", false) }
            var passed = true
            for (key, target, _) in tries {
                let result = answer[key].map { "\($0)" } ?? "none"
                let isDenied = answer[key] == .text(denied)
                passed = passed && isDenied
                _ = report("\(key) \(target): \(result)", isDenied)
            }
            return passed
        }

        @discardableResult
        private static func report(_ line: String, _ passed: Bool) -> Bool {
            let text = (passed ? "denied  " : "FAILED  ") + line + "\n"
            FileHandle.standardOutput.write(Data(text.utf8))
            return passed
        }
    }
#endif
