import Foundation

#if os(iOS)
import AuthenticationServices
import CryptoKit
import UIKit

struct GmailOAuthConfiguration {
    let clientID: String
    let redirectURI: String
    let callbackScheme: String

    static func fromInfoPlist() -> GmailOAuthConfiguration? {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GMAIL_OAUTH_CLIENT_ID") as? String,
              !clientID.isEmpty,
              let redirectURI = Bundle.main.object(forInfoDictionaryKey: "GMAIL_OAUTH_REDIRECT_URI") as? String,
              let callbackScheme = URL(string: redirectURI)?.scheme,
              !callbackScheme.isEmpty else { return nil }
        return GmailOAuthConfiguration(clientID: clientID, redirectURI: redirectURI, callbackScheme: callbackScheme)
    }
}

@MainActor
final class GmailOAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func connect(configuration: GmailOAuthConfiguration? = nil) async throws -> GmailProfile {
        guard let configuration = configuration ?? GmailOAuthConfiguration.fromInfoPlist() else {
            throw GmailServiceError.notConfigured
        }
        let pkce = makePKCE()
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/gmail.readonly"),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        guard let authorizationURL = components.url else { throw GmailServiceError.notConfigured }
        let callbackURL = try await authenticate(url: authorizationURL, scheme: configuration.callbackScheme)
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GmailServiceError.cancelled
        }
        let tokens = try await exchange(code: code, pkce: pkce, configuration: configuration)
        let profile = try await LiveGmailAPIClient().profile(accessToken: tokens.accessToken)
        try KeychainStore.saveString(tokens.accessToken, for: .gmailAccessToken)
        if let refreshToken = tokens.refreshToken { try KeychainStore.saveString(refreshToken, for: .gmailRefreshToken) }
        try KeychainStore.saveString(String(Date().addingTimeInterval(TimeInterval(tokens.expiresIn)).timeIntervalSince1970), for: .gmailTokenExpiry)
        try KeychainStore.saveString("https://www.googleapis.com/auth/gmail.readonly", for: .gmailGrantedScopes)
        return profile
    }

    func validAccessToken() async throws -> String {
        guard let accessToken = try KeychainStore.loadString(.gmailAccessToken), !accessToken.isEmpty else {
            throw GmailServiceError.reauthorizationRequired
        }
        let expiry = (try KeychainStore.loadString(.gmailTokenExpiry)).flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
        if let expiry, expiry > Date().addingTimeInterval(60) { return accessToken }
        return try await refreshAccessToken()
    }

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = try KeychainStore.loadString(.gmailRefreshToken), !refreshToken.isEmpty,
              let configuration = GmailOAuthConfiguration.fromInfoPlist() else {
            throw GmailServiceError.reauthorizationRequired
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let values = ["client_id": configuration.clientID, "refresh_token": refreshToken, "grant_type": "refresh_token"]
        request.httpBody = values.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GmailServiceError.reauthorizationRequired
        }
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        try KeychainStore.saveString(tokens.accessToken, for: .gmailAccessToken)
        try KeychainStore.saveString(String(Date().addingTimeInterval(TimeInterval(tokens.expiresIn)).timeIntervalSince1970), for: .gmailTokenExpiry)
        return tokens.accessToken
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int
        enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in" }
    }

    private struct PKCEValue { let verifier: String; let challenge: String }

    private func makePKCE() -> PKCEValue {
        let verifier = Data((0..<32).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return PKCEValue(verifier: verifier, challenge: challenge)
    }

    private func authenticate(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                if let callback { continuation.resume(returning: callback) }
                else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin { continuation.resume(throwing: GmailServiceError.cancelled) }
                else { continuation.resume(throwing: error ?? GmailServiceError.authorizationRequired) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            session.start()
        }
    }

    private func exchange(code: String, pkce: PKCEValue, configuration: GmailOAuthConfiguration) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let values = [
            "client_id": configuration.clientID,
            "code": code,
            "code_verifier": pkce.verifier,
            "grant_type": "authorization_code",
            "redirect_uri": configuration.redirectURI
        ]
        request.httpBody = values.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw GmailServiceError.authorizationRequired }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow) ?? UIWindow()
    }
}
#else
@MainActor
final class GmailOAuthService {
    func connect() async throws -> GmailProfile { throw GmailServiceError.notConfigured }
    func validAccessToken() async throws -> String { throw GmailServiceError.notConfigured }
}
#endif
