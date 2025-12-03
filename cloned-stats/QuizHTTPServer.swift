/**
 * Quiz HTTP Server
 * Receives animation commands from the backend server
 * Runs on localhost:8080 and listens for quiz display requests
 */

import Foundation

protocol QuizHTTPServerDelegate: AnyObject {
    func didReceiveAnswers(_ answers: [Int])
}

class QuizHTTPServer: NSObject {

    weak var delegate: QuizHTTPServerDelegate?

    private let port: UInt16 = 8080
    private var server: HTTPServer?
    private let queue = DispatchQueue(label: "com.stats.quiz.http")

    // MARK: - Public Methods

    /**
     * Start the HTTP server
     */
    func startServer() {
        queue.async { [weak self] in
            self?.server = HTTPServer(port: self?.port ?? 8080, delegate: self)
            if self?.server?.start() ?? false {
                print("✓ Quiz HTTP Server started on port 8080")
            } else {
                print("❌ Failed to start HTTP Server")
            }
        }
    }

    /**
     * Stop the HTTP server
     */
    func stopServer() {
        queue.async { [weak self] in
            self?.server?.stop()
            print("✓ Quiz HTTP Server stopped")
        }
    }

    deinit {
        stopServer()
    }
}

// MARK: - HTTPServer Delegate
extension QuizHTTPServer: HTTPServerDelegate {
    func handleRequest(_ request: HTTPRequest) -> HTTPResponse {
        // Only handle POST /display-answers
        guard request.method == "POST", request.path == "/display-answers" else {
            return HTTPResponse(statusCode: 404, body: "Not Found")
        }

        do {
            // Parse JSON body
            if let bodyData = request.body?.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
               let answers = json["answers"] as? [Int] {

                print("📥 HTTP Server received answers: \(answers)")

                // Notify delegate on main thread
                DispatchQueue.main.async {
                    self.delegate?.didReceiveAnswers(answers)
                }

                return HTTPResponse(
                    statusCode: 200,
                    body: """
                    {"status": "success", "message": "Answers received and animation started"}
                    """
                )
            }

        } catch {
            print("❌ Error parsing request: \(error.localizedDescription)")
        }

        return HTTPResponse(statusCode: 400, body: "Invalid request format")
    }
}

// MARK: - HTTP Server Implementation
protocol HTTPServerDelegate: AnyObject {
    func handleRequest(_ request: HTTPRequest) -> HTTPResponse
}

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: String?
}

struct HTTPResponse {
    let statusCode: Int
    let body: String
    let headers: [String: String]

    init(statusCode: Int, body: String, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.body = body
        var combinedHeaders = ["Content-Type": "application/json"]
        for (key, value) in headers {
            combinedHeaders[key] = value
        }
        self.headers = combinedHeaders
    }
}

class HTTPServer: NSObject, StreamDelegate {

    weak var delegate: HTTPServerDelegate?
    let port: UInt16
    private var listeningSocket: CFSocket?
    private let queue = DispatchQueue(label: "com.stats.quiz.http.server")

    init(port: UInt16, delegate: HTTPServerDelegate?) {
        self.port = port
        self.delegate = delegate
    }

    func start() -> Bool {
        var context = CFSocketContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)

        listeningSocket = CFSocketCreate(
            nil,
            AF_INET,
            SOCK_STREAM,
            IPPROTO_TCP,
            CFSocketCallBackType.acceptCallBack.rawValue,
            { socket, callbackType, address, data, info in
                guard let info = info else { return }
                let `self` = Unmanaged<HTTPServer>.fromOpaque(info).takeUnretainedValue()

                if callbackType == .acceptCallBack {
                    if let data = data {
                        var nativeSocket: CFSocketNativeHandle = 0
                        let nsData = NSData(bytes: data, length: MemoryLayout<CFSocketNativeHandle>.size)
                        nsData.getBytes(&nativeSocket, length: MemoryLayout<CFSocketNativeHandle>.size)
                        self.handleConnection(nativeSocket)
                    }
                }
            },
            &context
        )

        guard let socket = listeningSocket else {
            print("❌ Failed to create socket")
            return false
        }

        // Set socket options
        var reuse = 1
        setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int>.size))

        // Bind to port
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

        let address = NSData(bytes: &addr, length: MemoryLayout<sockaddr_in>.size)
        guard CFSocketSetAddress(socket, address as CFData) == .success else {
            print("❌ Failed to bind to port \(port)")
            return false
        }

        // Create run loop source
        let runLoopSource = CFSocketCreateRunLoopSource(nil, socket, 0)!
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)

        print("✓ HTTP Server listening on port \(port)")
        return true
    }

    func stop() {
        if let socket = listeningSocket {
            CFSocketInvalidate(socket)
            listeningSocket = nil
        }
    }

    private func handleConnection(_ nativeSocket: CFSocketNativeHandle) {
        queue.async { [weak self] in
            let fileHandle = FileHandle(fileDescriptor: nativeSocket)

            do {
                // Read request - use a buffer and read until we have the full request
                var buffer = Data()
                var contentLength: Int? = nil
                var headerEndIndex: Int? = nil

                // First, read in chunks until we find the header end
                var attempts = 0
                while attempts < 20 {
                    usleep(10000) // 10ms wait
                    let chunk = fileHandle.availableData

                    if !chunk.isEmpty {
                        buffer.append(chunk)

                        // Check if we've found the end of headers
                        if headerEndIndex == nil {
                            if let requestString = String(data: buffer, encoding: .utf8) {
                                // Look for header/body separator
                                if let range = requestString.range(of: "\r\n\r\n") {
                                    headerEndIndex = requestString.distance(from: requestString.startIndex, to: range.upperBound)

                                    // Try to extract Content-Length from headers
                                    let headerSection = String(requestString[..<range.lowerBound])
                                    let lines = headerSection.components(separatedBy: "\r\n")
                                    for line in lines {
                                        if line.lowercased().hasPrefix("content-length:") {
                                            let parts = line.split(separator: ":", maxSplits: 1)
                                            if parts.count == 2 {
                                                contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces))
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // If we know the content length, check if we have all the data
                        if let headerEnd = headerEndIndex, let expectedLength = contentLength {
                            let currentBodyLength = buffer.count - headerEnd
                            if currentBodyLength >= expectedLength {
                                print("📦 Received complete request: headers + \(currentBodyLength) bytes body")
                                break
                            }
                        }
                    } else if buffer.count > 0 {
                        // No more data available
                        break
                    }

                    attempts += 1
                }

                guard let requestString = String(data: buffer, encoding: .utf8) else {
                    print("❌ Failed to decode request data")
                    fileHandle.closeFile()
                    return
                }

                print("📨 Received HTTP request (\(buffer.count) bytes total)")
                let request = self?.parseRequest(requestString)

                // Debug: print what we parsed
                if let req = request {
                    print("🔍 Parsed - Method: \(req.method), Path: \(req.path), Body length: \(req.body?.count ?? 0)")
                }

                let response = self?.delegate?.handleRequest(request ?? HTTPRequest(method: "GET", path: "/", headers: [:], body: nil)) ?? HTTPResponse(statusCode: 500, body: "Internal Server Error")

                // Send response
                let responseString = "HTTP/1.1 \(response.statusCode) OK\r\n"
                    + "Content-Type: application/json\r\n"
                    + "Content-Length: \(response.body.count)\r\n"
                    + "Connection: close\r\n"
                    + "\r\n"
                    + response.body

                fileHandle.write(responseString.data(using: .utf8)!)
                fileHandle.closeFile()

            } catch {
                print("❌ Error handling connection: \(error)")
                try? fileHandle.closeFile()
            }
        }
    }

    private func parseRequest(_ requestString: String) -> HTTPRequest {
        // Split on double CRLF or double LF to separate headers from body
        let parts = requestString.components(separatedBy: "\r\n\r\n")
        if parts.count < 2 {
            // Try single LF
            let lfParts = requestString.components(separatedBy: "\n\n")
            if lfParts.count >= 2 {
                return parseHTTPParts(headerSection: lfParts[0], body: lfParts[1...].joined(separator: "\n\n"))
            }
        } else {
            return parseHTTPParts(headerSection: parts[0], body: parts[1...].joined(separator: "\r\n\r\n"))
        }

        // Fallback
        return HTTPRequest(method: "GET", path: "/", headers: [:], body: nil)
    }

    private func parseHTTPParts(headerSection: String, body: String?) -> HTTPRequest {
        let lines = headerSection.split(separator: "\n")
        guard let firstLine = lines.first?.split(separator: " ", maxSplits: 2) else {
            return HTTPRequest(method: "GET", path: "/", headers: [:], body: nil)
        }

        let method = String(firstLine[0])
        let path = String(firstLine[1])

        var headers: [String: String] = [:]
        for i in 1..<lines.count {
            let line = String(lines[i]).trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        let finalBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📋 Parsed request - Method: \(method), Path: \(path), Body: \(finalBody ?? "nil")")
        return HTTPRequest(method: method, path: path, headers: headers, body: finalBody)
    }
}
