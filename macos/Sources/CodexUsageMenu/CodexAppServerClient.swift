import Foundation

final class CodexAppServerClient {
    enum ClientError: LocalizedError {
        case codexNotFound
        case failedToLaunch(String)
        case disconnected
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .codexNotFound:
                return "ไม่พบ Codex CLI กรุณาติดตั้งหรือตั้งค่า CODEX_CLI_PATH"
            case let .failedToLaunch(message):
                return "เปิด Codex App Server ไม่สำเร็จ: \(message)"
            case .disconnected:
                return "การเชื่อมต่อกับ Codex App Server หลุด"
            case .invalidResponse:
                return "Codex App Server ส่งข้อมูลที่อ่านไม่ได้"
            case let .server(message):
                return message
            }
        }
    }

    typealias JSON = [String: Any]

    private let queue = DispatchQueue(label: "com.sunday.mycodex-meter.app-server")
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var outputBuffer = Data()
    private var nextRequestID = 1
    private var isInitialized = false
    private var initializationWaiters: [(Result<Void, Error>) -> Void] = []
    private var pendingRequests: [Int: (Result<JSON, Error>) -> Void] = [:]

    var onRateLimitsUpdated: (() -> Void)?

    func fetchRateLimits(completion: @escaping (Result<UsageSnapshot, Error>) -> Void) {
        queue.async {
            self.connectIfNeeded { connectionResult in
                switch connectionResult {
                case .success:
                    self.sendRequest(method: "account/rateLimits/read", params: nil) { result in
                        switch result {
                        case let .success(response):
                            do {
                                completion(.success(try UsageParser.parse(response: response)))
                            } catch {
                                completion(.failure(error))
                            }
                        case let .failure(error):
                            completion(.failure(error))
                        }
                    }
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func stop() {
        queue.sync {
            tearDown(error: ClientError.disconnected, terminateProcess: true)
        }
    }

    private func connectIfNeeded(completion: @escaping (Result<Void, Error>) -> Void) {
        if isInitialized, process?.isRunning == true {
            completion(.success(()))
            return
        }

        initializationWaiters.append(completion)
        guard initializationWaiters.count == 1 else { return }

        do {
            let codexURL = try findCodexExecutable()
            let process = Process()
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = codexURL
            process.arguments = ["app-server", "--stdio"]
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                self?.queue.async {
                    self?.consumeOutput(data)
                }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                // Drain stderr so the child process cannot block on a full pipe.
                _ = handle.availableData
            }

            process.terminationHandler = { [weak self] _ in
                self?.queue.async {
                    self?.tearDown(error: ClientError.disconnected, terminateProcess: false)
                }
            }

            try process.run()

            self.process = process
            self.inputPipe = inputPipe
            self.outputPipe = outputPipe

            sendMessage([
                "method": "initialize",
                "id": 0,
                "params": [
                    "clientInfo": [
                        "name": "mycodex_meter",
                        "title": "myCodex Meter",
                        "version": "1.0.0",
                    ],
                ],
            ])

            pendingRequests[0] = { [weak self] result in
                guard let self else { return }

                switch result {
                case .success:
                    self.sendMessage([
                        "method": "initialized",
                        "params": [:] as JSON,
                    ])
                    self.isInitialized = true
                    let waiters = self.initializationWaiters
                    self.initializationWaiters.removeAll()
                    waiters.forEach { $0(.success(())) }
                case let .failure(error):
                    let waiters = self.initializationWaiters
                    self.initializationWaiters.removeAll()
                    waiters.forEach { $0(.failure(error)) }
                }
            }
        } catch {
            let waiters = initializationWaiters
            initializationWaiters.removeAll()
            waiters.forEach { $0(.failure(error)) }
        }
    }

    private func sendRequest(
        method: String,
        params: JSON?,
        completion: @escaping (Result<JSON, Error>) -> Void
    ) {
        let requestID = nextRequestID
        nextRequestID += 1

        var message: JSON = [
            "method": method,
            "id": requestID,
        ]

        if let params {
            message["params"] = params
        }

        pendingRequests[requestID] = completion
        sendMessage(message)
    }

    private func sendMessage(_ message: JSON) {
        guard let inputPipe else { return }

        do {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(0x0A)
            try inputPipe.fileHandleForWriting.write(contentsOf: data)
        } catch {
            tearDown(error: error, terminateProcess: true)
        }
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)

        while let newlineRange = outputBuffer.firstRange(of: Data([0x0A])) {
            let line = outputBuffer[..<newlineRange.lowerBound]
            outputBuffer.removeSubrange(...newlineRange.lowerBound)

            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line),
                  let message = object as? JSON
            else {
                continue
            }

            handleMessage(message)
        }
    }

    private func handleMessage(_ message: JSON) {
        if let requestID = (message["id"] as? NSNumber)?.intValue,
           let completion = pendingRequests.removeValue(forKey: requestID) {
            if let error = message["error"] as? JSON {
                let serverMessage = error["message"] as? String ?? "Codex App Server เกิดข้อผิดพลาด"
                completion(.failure(ClientError.server(serverMessage)))
            } else {
                completion(.success(message))
            }
            return
        }

        if message["method"] as? String == "account/rateLimits/updated" {
            onRateLimitsUpdated?()
        }
    }

    private func tearDown(error: Error, terminateProcess: Bool) {
        let runningProcess = process

        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminationHandler = nil
        process = nil
        inputPipe = nil
        outputPipe = nil
        outputBuffer.removeAll(keepingCapacity: true)
        isInitialized = false

        let pending = pendingRequests.values
        pendingRequests.removeAll()
        pending.forEach { $0(.failure(error)) }

        let waiters = initializationWaiters
        initializationWaiters.removeAll()
        waiters.forEach { $0(.failure(error)) }

        if terminateProcess, runningProcess?.isRunning == true {
            runningProcess?.terminate()
        }
    }

    private func findCodexExecutable() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default

        var candidates: [String] = []

        if let override = environment["CODEX_CLI_PATH"], !override.isEmpty {
            candidates.append(override)
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(fileManager.homeDirectoryForCurrentUser.path)/.local/bin/codex",
            "\(fileManager.homeDirectoryForCurrentUser.path)/.npm-global/bin/codex",
        ])

        if let path = environment["PATH"] {
            candidates.append(contentsOf: path
                .split(separator: ":")
                .map { "\($0)/codex" })
        }

        guard let executable = candidates.first(where: {
            fileManager.isExecutableFile(atPath: $0)
        }) else {
            throw ClientError.codexNotFound
        }

        return URL(fileURLWithPath: executable)
    }
}
