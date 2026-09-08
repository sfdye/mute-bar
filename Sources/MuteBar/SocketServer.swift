import Foundation

/// Unix-domain-socket server speaking newline-delimited JSON with mutebar-host processes.
/// One connection per browser that has the MuteBar extension loaded.
final class SocketServer {
    static let shared = SocketServer()

    private var serverFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var connections: [Int32: DispatchSourceRead] = [:]
    private var buffers: [Int32: Data] = [:]
    private let queue = DispatchQueue(label: "mutebar.socket")
    var onMessage: ((Int32, [String: Any]) -> Void)?
    var onClientChange: ((Int) -> Void)?

    var socketPath: String {
        let dir = NSHomeDirectory() + "/Library/Application Support/MuteBar"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/socket"
    }

    func start() {
        let path = socketPath
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { log("socket() failed: \(errno)"); return }
        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8CString) // includes NUL
        withUnsafeMutableBytes(of: &addr.sun_path) { dst in
            dst.copyBytes(from: UnsafeRawBufferPointer(start: pathBytes, count: pathBytes.count))
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.offset(of: \.sun_path)!) + socklen_t(pathBytes.count)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, len)
            }
        }
        guard bindResult == 0, listen(fd, 8) == 0 else {
            log("bind/listen failed: \(errno)")
            close(fd)
            return
        }
        serverFD = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptClient() }
        source.resume()
        acceptSource = source
        log("listening on \(path)")
    }

    private func acceptClient() {
        var addr = sockaddr()
        var len = socklen_t(MemoryLayout<sockaddr>.size)
        let client = accept(serverFD, &addr, &len)
        guard client >= 0 else { return }
        log("client connected: \(client)")
        watch(client)
        onClientChange?(connections.count)
        // ask for current state
        sendRaw(client, ["type": "getState"])
    }

    private func watch(_ fd: Int32) {
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.read(client: fd) }
        source.setCancelHandler { [weak self] in
            close(fd)
            self?.connections[fd] = nil
            self?.buffers[fd] = nil
            self?.onClientChange?(self?.connections.count ?? 0)
        }
        source.resume()
        connections[fd] = source
    }

    private func read(client fd: Int32) {
        var chunk = [UInt8](repeating: 0, count: 65536)
        let n = recv(fd, &chunk, chunk.count, 0)
        if n <= 0 {
            connections[fd]?.cancel()
            return
        }
        buffers[fd, default: Data()].append(Data(chunk[0..<n]))
        while let idx = buffers[fd]?.firstIndex(of: UInt8(ascii: "\n")) {
            guard let lineData = buffers[fd]?.prefix(idx),
                  let json = try? JSONSerialization.jsonObject(with: Data(lineData)) as? [String: Any]
            else {
                buffers[fd]?.removeSubrange(...idx)
                continue
            }
            buffers[fd]?.removeSubrange(...idx)
            log("msg from \(fd): \(json)")
            onMessage?(fd, json)
        }
    }

    func sendRaw(_ fd: Int32, _ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        var out = data
        out.append(UInt8(ascii: "\n"))
        out.withUnsafeBytes { raw in
            var sent = 0
            while sent < raw.count {
                let n = Darwin.send(fd, raw.baseAddress!.advanced(by: sent), raw.count - sent, 0)
                if n <= 0 { return }
                sent += n
            }
        }
    }

    func broadcast(_ object: [String: Any]) {
        for fd in connections.keys { sendRaw(fd, object) }
    }

    var clientCount: Int { connections.count }

    /// Snapshot of connected client fds (thread-safe).
    var clientFDs: [Int32] {
        queue.sync { Array(connections.keys) }
    }

    private func log(_ msg: String) {
        FileHandle.standardError.write(Data(("MuteBar[socket] \(msg)\n").utf8))
    }
}
