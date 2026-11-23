import TreewiseCore
import UIKit

/// The rows' swipe actions (ADR 0146): to the left Move to Trash, which a full swipe
/// performs, and More…, an action sheet of the row's other commands; to the right Cut,
/// which a full swipe performs, and Copy. None while selecting, where a tap selects.
extension FolderCollectionCoordinator {
    func trailingSwipe(at path: IndexPath) -> UISwipeActionsConfiguration? {
        guard let commands = swipeCommands(at: path) else { return nil }
        var actions: [UIContextualAction] = []
        // Red, but not the destructive style, with which the list would take the row away
        // itself before it is in the Trash; it goes once it is.
        if let trash = commands.moveToTrash {
            actions.append(Self.action(for: trash, color: .systemRed))
        }
        if !commands.more.isEmpty {
            let more = UIContextualAction(
                style: .normal, title: String(localized: "More…")
            ) { [weak self] _, _, done in
                self?.showMore(commands.more, from: path)
                done(true)
            }
            more.image = UIImage(systemName: "ellipsis.circle")
            more.backgroundColor = .systemGray
            actions.append(more)
        }
        return actions.isEmpty ? nil : UISwipeActionsConfiguration(actions: actions)
    }

    func leadingSwipe(at path: IndexPath) -> UISwipeActionsConfiguration? {
        guard let commands = swipeCommands(at: path), !commands.leading.isEmpty else {
            return nil
        }
        let colors: [UIColor] = [.systemBlue, .systemIndigo]
        let actions = zip(commands.leading, colors).map { Self.action(for: $0, color: $1) }
        return UISwipeActionsConfiguration(actions: actions)
    }

    /// The row's commands, or nil while selecting or for a row that is gone.
    private func swipeCommands(at path: IndexPath) -> SwipeCommands? {
        guard let view, !view.isEditing, let item = item(at: path), let actions = content?.actions
        else { return nil }
        return ItemCommands.swipes(for: item, actions: actions)
    }

    private static func action(for command: ItemCommand, color: UIColor) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: command.title) { _, _, done in
            command.perform()
            done(true)
        }
        action.image = UIImage(systemName: command.symbol)
        action.backgroundColor = color
        return action
    }

    /// More…: the row's other commands as an action sheet, a popover from the row on the
    /// iPad, as Mail's More is.
    private func showMore(_ commands: [ItemCommand], from path: IndexPath) {
        guard let view, var presenter = view.window?.rootViewController else { return }
        while let presented = presenter.presentedViewController { presenter = presented }
        let sheet = UIAlertController(
            title: item(at: path)?.name, message: nil, preferredStyle: .actionSheet)
        for command in commands {
            sheet.addAction(
                UIAlertAction(title: command.title, style: .default) { _ in
                    command.perform()
                })
        }
        sheet.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        let anchor = view.cellForItem(at: path) ?? view
        sheet.popoverPresentationController?.sourceView = anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        presenter.present(sheet, animated: true)
    }
}
