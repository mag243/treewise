#if TREEWISE_PROBE
    import Foundation

    /// A TCP socket listening on 127.0.0.1 at a free port, for the sandbox probe to try
    /// to connect to.
    struct LocalListener {
        let port: UInt16
        private let socket: Int32

        /// Opens the socket, or fails.
        init?() {
            let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            guard socket >= 0 else { return nil }
            var address = Self.loopback(port: 0)
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let bound = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(socket, $0, length) == 0 && listen(socket, 1) == 0
                        && getsockname(socket, $0, &length) == 0
                }
            }
            guard bound else {
                Darwin.close(socket)
                return nil
            }
            self.socket = socket
            self.port = UInt16(bigEndian: address.sin_port)
        }

        func close() { Darwin.close(socket) }

        /// Whether a connection to the port on 127.0.0.1 succeeds from this process.
        static func canConnect(to port: UInt16) -> Bool {
            let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            guard socket >= 0 else { return false }
            defer { Darwin.close(socket) }
            var address = loopback(port: port)
            return withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
                }
            }
        }

        private static func loopback(port: UInt16) -> sockaddr_in {
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = port.bigEndian
            address.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
            return address
        }
    }
#endif
