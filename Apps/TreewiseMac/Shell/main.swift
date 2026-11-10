import AppKit

// Treewise is an AppKit app (ADR 0081): its delegate opens the windows and
// builds the menu bar.
#if TREEWISE_PROBE
    SandboxProbeRun.runIfAsked()
#endif
// Tabs are macOS's window tabs, one folder per window (ADR 0037).
NSWindow.allowsAutomaticWindowTabbing = true
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
