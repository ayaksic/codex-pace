import Darwin
import Foundation

public enum CodexRateLimitClientError: LocalizedError, Sendable {
    case codexBinaryNotFound
    case launchFailed(String)
    case responseTimedOut
    case serverClosed
    case malformedResponse
    case rpcError(String)
    case weeklyWindowUnavailable

    public var errorDescription: String? {
        switch self {
        case .codexBinaryNotFound:
            "Codex was not found. Install ChatGPT/Codex or set CODEX_PACE_CODEX_PATH."
        case let .launchFailed(message):
            "Codex could not be started: \(message)"
        case .responseTimedOut:
            "Codex did not return usage data within 15 seconds."
        case .serverClosed:
            "Codex closed before returning usage data."
        case .malformedResponse:
            "Codex returned usage data in an unexpected format."
        case let .rpcError(message):
            "Codex returned an error: \(message)"
        case .weeklyWindowUnavailable:
            "Codex did not return a seven-day usage window."
        }
    }
}

public struct CodexRateLimitClient: Sendable {
    private let binaryURL: URL?
    private let timeoutSeconds: TimeInterval

    public init(binaryURL: URL? = nil, timeoutSeconds: TimeInterval = 15) {
        self.binaryURL = binaryURL
        self.timeoutSeconds = timeoutSeconds
    }

    public func fetch(now: Date = Date()) throws -> PaceSnapshot {
        guard let executable = binaryURL ?? Self.locateCodexBinary() else {
            throw CodexRateLimitClientError.codexBinaryNotFound
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw CodexRateLimitClientError.launchFailed(error.localizedDescription)
        }

        defer {
            try? inputPipe.fileHandleForWriting.close()
            try? outputPipe.fileHandleForReading.close()
            if process.isRunning {
                process.terminate()
            }
        }

        let messages: [[String: Any]] = [
            [
                "method": "initialize",
                "id": 1,
                "params": [
                    "clientInfo": [
                        "name": "codex-pace",
                        "title": "Codex Pace",
                        "version": "1.0.0",
                    ],
                    "capabilities": [
                        "experimentalApi": true,
                        "requestAttestation": false,
                    ],
                ],
            ],
            ["method": "initialized"],
            ["method": "account/rateLimits/read", "id": 2],
        ]

        do {
            for message in messages {
                var data = try JSONSerialization.data(withJSONObject: message)
                data.append(0x0A)
                try inputPipe.fileHandleForWriting.write(contentsOf: data)
            }
        } catch {
            throw CodexRateLimitClientError.launchFailed(error.localizedDescription)
        }

        let outputHandle = outputPipe.fileHandleForReading
        let outputDescriptor = outputHandle.fileDescriptor
        let existingFlags = fcntl(outputDescriptor, F_GETFL)
        guard existingFlags >= 0, fcntl(outputDescriptor, F_SETFL, existingFlags | O_NONBLOCK) >= 0 else {
            throw CodexRateLimitClientError.serverClosed
        }
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var buffer = Data()

        while Date() < deadline {
            let remainingMilliseconds = max(1, Int32(deadline.timeIntervalSinceNow * 1_000))
            var descriptor = pollfd(
                fd: outputDescriptor,
                events: Int16(POLLIN),
                revents: 0
            )
            let pollResult = Darwin.poll(&descriptor, 1, remainingMilliseconds)

            if pollResult == 0 {
                break
            }
            if pollResult < 0 {
                if errno == EINTR { continue }
                throw CodexRateLimitClientError.serverClosed
            }

            var bytes = [UInt8](repeating: 0, count: 8_192)
            let byteCount = bytes.withUnsafeMutableBytes {
                Darwin.read(outputDescriptor, $0.baseAddress, $0.count)
            }
            if byteCount < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                continue
            }
            guard byteCount > 0 else {
                throw CodexRateLimitClientError.serverClosed
            }
            buffer.append(bytes, count: byteCount)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard Self.responseID(in: line) == 2 else { continue }
                return try Self.decodeRateLimitResponse(line, fetchedAt: now)
            }
        }

        throw CodexRateLimitClientError.responseTimedOut
    }

    public static func locateCodexBinary(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let fileManager = FileManager.default
        var candidates: [String] = []

        if let override = environment["CODEX_PACE_CODEX_PATH"], !override.isEmpty {
            candidates.append(override)
        }

        candidates.append(contentsOf: [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
        ])

        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                String($0) + "/codex"
            })
        }

        return candidates.lazy
            .map { URL(fileURLWithPath: $0) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    public static func decodeRateLimitResponse(
        _ data: Data,
        fetchedAt: Date = Date()
    ) throws -> PaceSnapshot {
        let envelope: RPCEnvelope
        do {
            envelope = try JSONDecoder().decode(RPCEnvelope.self, from: data)
        } catch {
            throw CodexRateLimitClientError.malformedResponse
        }

        if let error = envelope.error {
            throw CodexRateLimitClientError.rpcError(error.message)
        }
        guard let response = envelope.result else {
            throw CodexRateLimitClientError.malformedResponse
        }

        var snapshots: [RateLimitSnapshotDTO] = []
        if let codexSnapshot = response.rateLimitsByLimitId?["codex"] {
            snapshots.append(codexSnapshot)
        }
        snapshots.append(response.rateLimits)

        let windowCandidates = snapshots.flatMap { snapshot -> [(RateLimitWindowDTO, RateLimitSnapshotDTO)] in
            [snapshot.primary, snapshot.secondary]
                .compactMap { $0 }
                .map { ($0, snapshot) }
        }

        let weeklyCandidates = windowCandidates.filter {
            ($0.0.windowDurationMins ?? 0) >= 6 * 24 * 60
        }
        guard let weeklyCandidate = weeklyCandidates.min(by: {
            abs(($0.0.windowDurationMins ?? 0) - 10_080)
                < abs(($1.0.windowDurationMins ?? 0) - 10_080)
        }), let weeklyWindow = usageWindow(from: weeklyCandidate.0) else {
            throw CodexRateLimitClientError.weeklyWindowUnavailable
        }

        let shortCandidate = windowCandidates
            .filter { ($0.0.windowDurationMins ?? .max) < 24 * 60 }
            .min(by: {
                abs(($0.0.windowDurationMins ?? 0) - 300)
                    < abs(($1.0.windowDurationMins ?? 0) - 300)
            })

        return PaceSnapshot(
            weeklyWindow: weeklyWindow,
            shortWindow: shortCandidate.flatMap { usageWindow(from: $0.0) },
            fetchedAt: fetchedAt,
            planType: weeklyCandidate.1.planType,
            creditBalance: weeklyCandidate.1.credits?.balance
        )
    }

    private static func responseID(in data: Data) -> Int? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let number = object["id"] as? NSNumber
        else {
            return nil
        }
        return number.intValue
    }

    private static func usageWindow(from dto: RateLimitWindowDTO) -> UsageWindow? {
        guard
            let duration = dto.windowDurationMins,
            let resetTimestamp = dto.resetsAt
        else {
            return nil
        }
        return UsageWindow(
            usedPercent: dto.usedPercent,
            durationMinutes: duration,
            resetsAt: Date(timeIntervalSince1970: resetTimestamp)
        )
    }
}

private struct RPCEnvelope: Decodable {
    let result: GetAccountRateLimitsResponseDTO?
    let error: RPCErrorDTO?
}

private struct RPCErrorDTO: Decodable {
    let message: String
}

private struct GetAccountRateLimitsResponseDTO: Decodable {
    let rateLimits: RateLimitSnapshotDTO
    let rateLimitsByLimitId: [String: RateLimitSnapshotDTO]?
}

private struct RateLimitSnapshotDTO: Decodable {
    let primary: RateLimitWindowDTO?
    let secondary: RateLimitWindowDTO?
    let credits: CreditsDTO?
    let planType: String?
}

private struct RateLimitWindowDTO: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: TimeInterval?
}

private struct CreditsDTO: Decodable {
    let balance: String?
}
