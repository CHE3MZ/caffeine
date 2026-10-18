import CryptoKit
import Foundation

struct UpdateRelease {
    let version: String
    let zipURL: URL
    let checksumURL: URL
}

struct PreparedUpdate {
    let app: URL
    let staging: URL
}

enum UpdateError: LocalizedError {
    case noReleases
    case invalidResponse
    case httpStatus(Int)
    case missingAssets
    case downloadFailed
    case checksumMismatch
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .noReleases:
            return "No releases have been published yet."
        case .invalidResponse:
            return "GitHub returned an unexpected response."
        case .httpStatus(let code):
            return "Couldn't check for updates (HTTP \(code))."
        case .missingAssets:
            return "The latest release is missing its update files."
        case .downloadFailed:
            return "The update download failed."
        case .checksumMismatch:
            return "The downloaded update failed its integrity check."
        case .extractionFailed:
            return "The downloaded update could not be unpacked."
        }
    }
}

enum UpdateChecker {
    static let repository = "CHE3MZ/caffeine"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static func availableRelease() async throws -> UpdateRelease? {
        let release = try await latestRelease()
        guard isNewer(release.version, than: currentVersion) else { return nil }
        return release
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = versionComponents(candidate)
        let currentParts = versionComponents(current)
        for index in 0..<max(candidateParts.count, currentParts.count) {
            let candidatePart = index < candidateParts.count ? candidateParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0
            if candidatePart != currentPart {
                return candidatePart > currentPart
            }
        }
        return false
    }

    static func download(_ release: UpdateRelease) async throws -> PreparedUpdate {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaffeineUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

        let (downloadedArchive, response) = try await URLSession.shared.download(from: release.zipURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw UpdateError.downloadFailed
        }
        let archive = staging.appendingPathComponent("Caffeine.zip")
        try FileManager.default.moveItem(at: downloadedArchive, to: archive)

        let (checksumData, _) = try await URLSession.shared.data(from: release.checksumURL)
        guard let checksumText = String(bytes: checksumData, encoding: .utf8),
            let expected = checksumText.split(whereSeparator: \.isWhitespace).first.map(String.init)?
                .lowercased()
        else {
            throw UpdateError.checksumMismatch
        }

        guard try sha256(ofFileAt: archive) == expected else {
            throw UpdateError.checksumMismatch
        }

        let app = try extract(archive, into: staging)
        return PreparedUpdate(app: app, staging: staging)
    }

    private static func latestRelease() async throws -> UpdateRelease {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            break
        case 404:
            throw UpdateError.noReleases
        default:
            throw UpdateError.httpStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: data)
        guard let zip = release.assets.first(where: { $0.name == "Caffeine.zip" }),
            let checksum = release.assets.first(where: { $0.name == "Caffeine.zip.sha256" })
        else {
            throw UpdateError.missingAssets
        }

        return UpdateRelease(
            version: release.tagName,
            zipURL: zip.browserDownloadUrl,
            checksumURL: checksum.browserDownloadUrl
        )
    }

    private static var apiURL: URL {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            preconditionFailure("invalid GitHub API URL")
        }
        return url
    }

    private static func versionComponents(_ version: String) -> [Int] {
        var trimmed = version
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        trimmed = trimmed.split(separator: "-", maxSplits: 1).first.map(String.init) ?? trimmed
        trimmed = trimmed.split(separator: "+", maxSplits: 1).first.map(String.init) ?? trimmed
        return trimmed.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }

    private static func sha256(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func extract(_ archive: URL, into staging: URL) throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, staging.path]
        try process.run()
        process.waitUntilExit()

        let app = staging.appendingPathComponent("Caffeine.app", isDirectory: true)
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: app.path) else {
            throw UpdateError.extractionFailed
        }
        return app
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [GitHubAsset]
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadUrl: URL
}
