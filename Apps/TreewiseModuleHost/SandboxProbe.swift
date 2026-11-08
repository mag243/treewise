#if TREEWISE_PROBE
    import Foundation

    /// The tries of the sandbox probe, each giving `ok` or the POSIX error it met, as
    /// `errno <number>`, so a denial (`EPERM`) differs from a missing path.
    enum SandboxProbe {
        static let readKey = "read"
        static let listKey = "list"
        static let okAnswer = "ok"

        static func connectKey(_ index: Int) -> String { "connect\(index)" }

        /// Opens a file for reading.
        static func read(_ path: String) -> String {
            let descriptor = open(path, O_RDONLY)
            guard descriptor >= 0 else { return failure() }
            close(descriptor)
            return okAnswer
        }

        /// Opens a folder for listing.
        static func list(_ path: String) -> String {
            guard let folder = opendir(path) else { return failure() }
            closedir(folder)
            return okAnswer
        }

        /// Starts a TCP connection to an IPv4 `host:port`; one that is under way counts as
        /// allowed, so a far address needs no answer.
        static func connect(_ address: String) -> String {
            let parts = address.split(separator: ":")
            guard parts.count == 2, let port = UInt16(parts[1]) else { return "bad address" }
            let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            guard socket >= 0 else { return failure() }
            defer { close(socket) }
            _ = fcntl(socket, F_SETFL, O_NONBLOCK)
            var target = sockaddr_in()
            target.sin_family = sa_family_t(AF_INET)
            target.sin_port = port.bigEndian
            inet_pton(AF_INET, String(parts[0]), &target.sin_addr)
            let result = withUnsafePointer(to: &target) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            return result == 0 || errno == EINPROGRESS ? okAnswer : failure()
        }

        private static func failure() -> String { "errno \(errno)" }
    }
#endif
