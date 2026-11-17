import UIKit

/// Whether Treewise runs on an iPhone, for the few texts that name the device, as the
/// device's own files are On My iPhone there and On My iPad on an iPad (ADR 0132).
enum DeviceKind {
    @MainActor static var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
}
