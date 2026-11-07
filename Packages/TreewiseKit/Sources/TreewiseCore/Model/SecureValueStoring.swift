/// Where small values are kept beyond the app's settings, so resetting those does not
/// remove them: the keychain on a device, memory in tests (ADR 0071).
public protocol SecureValueStoring: AnyObject {
    /// The value kept under `key`, if any.
    func value(for key: String) -> String?
    /// Keeps `value` under `key`; nil removes it.
    func setValue(_ value: String?, for key: String)
}
