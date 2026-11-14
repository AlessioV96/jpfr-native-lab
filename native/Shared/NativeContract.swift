import Foundation

enum NativeStrategy: String, Codable, CaseIterable, Hashable {
    case highFidelity, lowLatency
}

enum NativeMethod: String, Codable, Hashable {
    case status, translate, cancel
}

enum ContractError: String, Error {
    case invalidVersion, invalidID, invalidText, invalidStrategy, invalidCancellation
}

struct NativeRequest: Codable {
    let version: Int
    let id: String
    let method: NativeMethod
    let strategy: NativeStrategy?
    let text: String?
    let targetRequestID: String?

    static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 80 &&
        value.unicodeScalars.allSatisfy {
            (48...57).contains($0.value) || (65...90).contains($0.value) ||
            (97...122).contains($0.value) || $0.value == 45 || $0.value == 95
        }
    }

    func validated() throws -> Self {
        guard version == 1 else { throw ContractError.invalidVersion }
        guard Self.validID(id) else { throw ContractError.invalidID }
        switch method {
        case .translate:
            guard strategy != nil else { throw ContractError.invalidStrategy }
            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.utf8.count <= 4096, text.unicodeScalars.count <= 600,
                  targetRequestID == nil else { throw ContractError.invalidText }
        case .status:
            guard strategy != nil, text == nil, targetRequestID == nil else {
                throw ContractError.invalidStrategy
            }
        case .cancel:
            guard let targetRequestID, Self.validID(targetRequestID),
                  strategy == nil, text == nil else { throw ContractError.invalidCancellation }
        }
        return self
    }
}

struct NativeReply: Encodable {
    let version = 1
    let provider = "AppleTranslation"
    let id: String
    let ok: Bool
    let sourceLanguage = "ja"
    let targetLanguage = "fr"
    var requestedStrategy: NativeStrategy?
    var text: String?
    var elapsedMs: Double?
    var sessionReady: Bool?
    var canRequestDownloads: Bool?
    let effectiveModelMeasured = false
    var errorCode: String?
    var message: String?

    static func failure(id: String, code: String, message: String) -> Self {
        Self(id: id, ok: false, errorCode: code, message: message)
    }
}
