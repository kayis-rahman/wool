import Foundation

struct PKCE: Codable {
    let verifier: String
    let challenge: String
    let method: String = "S256"

    enum CodingKeys: String, CodingKey {
        case verifier
        case challenge
        case method
    }
}
