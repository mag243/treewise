import Testing

/// The suites that register file presenters, run one after another. Presenters belong to
/// the whole test process, and one suite's presenter may hold the system's messages up for
/// another's: `CoordinatedStopTests` holds a reader off for up to ten seconds, the time
/// `FolderPresenterTests` waits to hear of a write (ADR 0120).
@Suite(.serialized) enum FilePresenterSuites {}
