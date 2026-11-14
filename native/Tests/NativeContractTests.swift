import Foundation
import XCTest
@testable import NativeContract

final class NativeContractTests: XCTestCase {
    struct Vector: Decodable {
        let name: String
        let request: String
        let valid: Bool
    }

    func testSharedVectors() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "contract-vectors", withExtension: "json"))
        let vectors = try JSONDecoder().decode([Vector].self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(vectors.count, 16)
        for vector in vectors {
            do {
                let request = try JSONDecoder().decode(NativeRequest.self, from: Data(vector.request.utf8))
                _ = try request.validated()
                XCTAssertTrue(vector.valid, vector.name)
            } catch {
                XCTAssertFalse(vector.valid, vector.name)
            }
        }
    }

    func testErrorDoesNotCarryText() throws {
        let reply = NativeReply.failure(id: "test-1", code: "cancelled", message: "Calcul arrêté.")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(reply)) as? [String: Any])
        XCTAssertEqual(object["version"] as? Int, 1)
        XCTAssertEqual(object["ok"] as? Bool, false)
        XCTAssertNil(object["text"])
    }
}
