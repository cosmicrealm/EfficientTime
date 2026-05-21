import Foundation

struct LocalSecretStore {
    enum StoreError: LocalizedError {
        case invalidData

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "Local secret data is invalid"
            }
        }
    }

    private let fileURL: URL

    init(filename: String = "secrets.json") {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("EfficientTime", isDirectory: true)
        let resolvedDirectory = directory ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: resolvedDirectory, withIntermediateDirectories: true)
        self.fileURL = resolvedDirectory.appendingPathComponent(filename)
    }

    func save(_ value: String, account: String) throws {
        var secrets = try loadAll()
        secrets[account] = value
        try write(secrets)
    }

    func read(account: String) throws -> String? {
        try loadAll()[account]
    }

    func delete(account: String) throws {
        var secrets = try loadAll()
        secrets.removeValue(forKey: account)
        try write(secrets)
    }

    private func loadAll() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            throw StoreError.invalidData
        }
    }

    private func write(_ secrets: [String: String]) throws {
        let data = try JSONEncoder().encode(secrets)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}
