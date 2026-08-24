import Foundation

public struct AppBuildInfo: Equatable, Sendable {
    public let version: String
    public let build: String
    public let sourceRevision: String
    public let sourceState: String

    public init(
        version: String,
        build: String,
        sourceRevision: String,
        sourceState: String
    ) {
        self.version = version
        self.build = build
        self.sourceRevision = sourceRevision
        self.sourceState = sourceState
    }

    public init(bundle: Bundle = .main) {
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "unknown"
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? "unknown"
        sourceRevision = bundle.object(forInfoDictionaryKey: "CodexPaceSourceRevision")
            as? String ?? "unknown"
        sourceState = bundle.object(forInfoDictionaryKey: "CodexPaceSourceState")
            as? String ?? "unknown"
    }

    public var versionText: String {
        "\(version) (\(build))"
    }

    public var shortRevision: String {
        String(sourceRevision.prefix(7))
    }

    public var canCheckLatestRevision: Bool {
        sourceState == "clean" && sourceRevision.count == 40
    }
}

public actor GitHubLatestRevisionClient {
    public static let shared = GitHubLatestRevisionClient()

    private let endpoint = URL(
        string: "https://api.github.com/repos/ayaksic/codex-pace/commits/main"
    )!

    public func latestRevision() async throws -> String {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Codex-Pace", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LatestRevisionError.unexpectedResponse
        }

        let commit = try JSONDecoder().decode(Commit.self, from: data)
        guard commit.sha.count == 40 else {
            throw LatestRevisionError.invalidRevision
        }
        return commit.sha
    }

    private struct Commit: Decodable {
        let sha: String
    }

    private enum LatestRevisionError: Error {
        case unexpectedResponse
        case invalidRevision
    }
}
