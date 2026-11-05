import TreewiseCore
import TreewiseTestSupport

/// Plans a drag of fixture items onto a fixture target.
///
/// Precondition: every identity is in `Fixture.standard`.
func planDrag(
    _ ids: [FileItem.ID], onto target: FileItem.ID, _ modifiers: DropModifiers = []
) -> TransferMode? {
    let fileSystem = Fixture.standard
    let items = ids.map { id in
        guard let item = fileSystem[id] else { preconditionFailure("\(id) is in the fixture") }
        return item
    }
    guard let targetItem = fileSystem[target] else {
        preconditionFailure("\(target) is in the fixture")
    }
    return TransferPlanner.plan(
        items: items, target: targetItem, modifiers: modifiers, ancestry: fileSystem.ancestry)
}
