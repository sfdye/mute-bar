import Foundation

// mutebar-host: Chrome native messaging host.
// Bridge between the extension (framed JSON on stdin/stdout) and the MuteBar
// menu bar app (newline-delimited JSON on a unix domain socket).

let socketPath = NSHomeDirectory() + "/Library/Application Support/MuteBar/socket"

func log(_ msg: String) {
    FileHandle.standardError.write(Data(("mutebar-host: \(msg)\n").utf8))
}

// MARK: - Connect to app socket (launching the app if needed)

func launchApp() {
    let bundleURL = Bundle.main.bundleURL
    let target = (bundleURL.pathExtension == "app") ? bundleURL : URL(fileURLWithPath: "/Applications/MuteBar.app")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = [target.path]
    do { try task.run() } catch { log("failed to launch app: \(error)") }
}

func connectSocket(retries: Int = 20) -> Int32 {
    for attempt in 0...retries {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        if fd >= 0 {
            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            let pathBytes = Array(socketPath.utf8CString) // includes NUL
            withUnsafeMutableBytes(of: &addr.sun_path) { dst in
                dst.copyBytes(from: UnsafeRawBufferPointer(start: pathBytes, count: pathBytes.count))
            }
            let len = socklen_t(MemoryLayout<sockaddr_un>.offset(of: \.sun_path)!) + socklen_t(pathBytes.count)
            let result = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, len)
                }
            }
            if result == 0 { log("connected to app (attempt \(attempt))"); return fd }
            close(fd)
        }
        if attempt == 0 { launchApp() }
        usleep(300_000)
    }
    return -1
}

// MARK: - stdio framing (Chrome native messaging: 4-byte LE length + JSON)

var stdinBuffer = Data()

func readStdinFrame() -> Data? {
    let stdin = FileHandle.standardInput
    while true {
        if stdinBuffer.count >= 4 {
            let length = Int(stdinBuffer[3]) << 24 | Int(stdinBuffer[2]) << 16
                | Int(stdinBuffer[1]) << 8 | Int(stdinBuffer[0])
            if length > 1_000_000 { return nil } // garbage guard
            if stdinBuffer.count >= 4 + length {
                let payload = stdinBuffer.subdata(in: 4..<(4 + length))
                stdinBuffer.removeSubrange(0..<(4 + length))
                return payload
            }
        }
        let chunk = stdin.availableData
        if chunk.isEmpty { return nil } // EOF -> browser disconnected
        stdinBuffer.append(chunk)
    }
}

func writeStdoutFrame(_ data: Data) {
    var length = UInt32(data.count).littleEndian
    var out = Data(bytes: &length, count: 4)
    out.append(data)
    FileHandle.standardOutput.write(out)
}

// MARK: - Main loop

let sock = connectSocket()
guard sock >= 0 else {
    log("cannot connect to MuteBar app; exiting")
    exit(1)
}

let queue = DispatchQueue(label: "mutebar-host")
let group = DispatchGroup()

// socket -> stdout
group.enter()
queue.async {
    var buffer = Data()
    while true {
        var chunk = [UInt8](repeating: 0, count: 65536)
        let n = recv(sock, &chunk, chunk.count, 0)
        if n <= 0 { break }
        buffer.append(Data(chunk[0..<n]))
        while let idx = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer.prefix(idx)
            buffer.removeSubrange(...idx)
            if !line.isEmpty { writeStdoutFrame(Data(line)) }
        }
    }
    // app gone or socket closed: exit so the browser relaunches us later
    exit(0)
}

// stdin -> socket (blocking; exit on EOF)
while let frame = readStdinFrame() {
    guard let json = try? JSONSerialization.jsonObject(with: frame) as? [String: Any],
          let type = json["type"] as? String
    else { continue }
    if type == "ping" {
        writeStdoutFrame(#"{"type":"pong"}"#.data(using: .utf8)!)
        continue
    }
    var line = frame
    line.append(UInt8(ascii: "\n"))
    line.withUnsafeBytes { raw in
        var sent = 0
        while sent < raw.count {
            let n = send(sock, raw.baseAddress!.advanced(by: sent), raw.count - sent, 0)
            if n <= 0 { exit(0) }
            sent += n
        }
    }
    log("relayed to app: \(type)")
}

// Browser closed the port
exit(0)
