//
//  GoogleAuthService.swift
//  BlaxxPontos
//
//  Login com Google usando ASWebAuthenticationSession (Apple-native, sem SDK
//  pesado da Google) + Authorization Code Flow com PKCE.
//
//  Por que PKCE? Em 2023 o Google descontinuou o implicit flow
//  (response_type=id_token) para clients do tipo iOS — retorna
//  Error 400: unsupported_response_type. O fluxo moderno aceito é:
//
//    1. App gera code_verifier (random 64 chars) e code_challenge = SHA256(verifier)
//    2. Abre OAuth URL com response_type=code + code_challenge_method=S256
//    3. Usuário autoriza no Google
//    4. Google redireciona pro custom scheme com ?code=<auth_code>
//    5. App troca o code por id_token via POST /token + code_verifier
//    6. Manda o id_token pro backend Blaxx pra validar e fazer login
//

import Foundation
import AuthenticationServices
import CryptoKit

/// Erros possíveis no fluxo Google.
enum GoogleAuthError: LocalizedError {
    case missingClientID
    case userCancelled
    case noCodeReturned
    case tokenExchangeFailed(String)
    case networkFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Login Google não configurado neste app."
        case .userCancelled:
            return "Login Google cancelado."
        case .noCodeReturned:
            return "Google não devolveu código de autorização. Tente novamente."
        case .tokenExchangeFailed(let msg):
            return "Falha ao trocar código por token: \(msg)"
        case .networkFailure(let msg):
            return msg
        }
    }
}

/// Resposta do endpoint /token do Google após troca do authorization code.
private struct GoogleTokenResponse: Decodable {
    let id_token: String
    let access_token: String?
    let token_type: String?
    let expires_in: Int?
}

/// Serviço que orquestra Authorization Code Flow com PKCE contra o Google.
/// Custom URL scheme reverso registrado no Info.plist:
///   com.googleusercontent.apps.105341431878-3msc2p3tjk3p5ro6i34d0b0qks3nf9dj
@MainActor
final class GoogleAuthService: NSObject {
    static let shared = GoogleAuthService()

    /// Client ID iOS do projeto "Blaxx Pontos" no Google Cloud Console.
    /// Project ID: project-153116d6-6ca7-4755-bc6
    /// Pode ser sobrescrito via UserDefaults("blaxx_google_client_id") em testes.
    static let defaultClientID =
        "105341431878-3msc2p3tjk3p5ro6i34d0b0qks3nf9dj.apps.googleusercontent.com"

    var clientID: String {
        UserDefaults.standard.string(forKey: "blaxx_google_client_id")
            ?? Self.defaultClientID
    }

    /// Custom URL scheme reverso (formato exigido pelo Google iOS Client).
    /// Calculado a partir do client ID. Tem que casar com CFBundleURLSchemes
    /// no Info.plist.
    var redirectScheme: String {
        let parts = clientID.components(separatedBy: ".apps.googleusercontent.com")
        guard parts.count == 2 else { return "" }
        return "com.googleusercontent.apps." + parts[0]
    }

    /// Redirect URI exata enviada ao Google. iOS clients usam path "/oauth2redirect".
    private var redirectURI: String { redirectScheme + ":/oauth2redirect" }

    /// Resultado do sign-in: id_token assinado pelo Google + nonce gerado
    /// localmente. O backend Blaxx valida que o id_token.nonce bate com este
    /// valor (anti-replay).
    struct SignInResult {
        let idToken: String
        let nonce: String
    }

    /// Abre o popup do Google, troca o auth code por id_token, retorna o JWT
    /// junto com o nonce gerado pra validação anti-replay no backend.
    func signIn() async throws -> SignInResult {
        guard !clientID.isEmpty else { throw GoogleAuthError.missingClientID }

        // 1) PKCE + state CSRF + nonce anti-replay.
        let verifier = Self.codeVerifier()
        let challenge = Self.codeChallenge(from: verifier)
        let state = Self.randomString(length: 16)
        let nonce = Self.randomString(length: 32)

        // 2) Monta a URL de autorização (response_type=code + PKCE S256 + nonce).
        var comp = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comp.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),     // anti-replay
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let authURL = comp.url else { throw GoogleAuthError.noCodeReturned }

        // 3) Abre janela ASWebAuthenticationSession e aguarda callback.
        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: redirectScheme
            ) { url, err in
                if let err {
                    let nserr = err as NSError
                    if nserr.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        cont.resume(throwing: GoogleAuthError.userCancelled)
                    } else {
                        cont.resume(throwing: GoogleAuthError.networkFailure(err.localizedDescription))
                    }
                    return
                }
                guard let url else {
                    cont.resume(throwing: GoogleAuthError.noCodeReturned)
                    return
                }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                cont.resume(throwing: GoogleAuthError.networkFailure(
                    "Não foi possível abrir a janela do Google"
                ))
            }
        }

        // 4) Parseia o `code` e `state` do query string do callback.
        let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value
        }

        if let oauthErr = params["error"] {
            throw GoogleAuthError.networkFailure("Google: \(oauthErr)")
        }
        if let returnedState = params["state"], returnedState != state {
            throw GoogleAuthError.networkFailure("State mismatch — possível tampering")
        }
        guard let code = params["code"], !code.isEmpty else {
            throw GoogleAuthError.noCodeReturned
        }

        // 5) Troca o code por tokens via POST /token (com code_verifier).
        let idToken = try await exchangeCodeForIDToken(code: code, verifier: verifier)
        return SignInResult(idToken: idToken, nonce: nonce)
    }

    // MARK: - Token exchange

    private func exchangeCodeForIDToken(code: String, verifier: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15

        // iOS clients no Google NÃO têm client_secret — PKCE substitui o secret.
        let body = [
            "code": code,
            "client_id": clientID,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ].map { k, v in
            let ev = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
            return "\(k)=\(ev)"
        }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleAuthError.tokenExchangeFailed("resposta inválida do Google")
        }
        if !(200..<300).contains(http.statusCode) {
            let bodyStr = String(data: data, encoding: .utf8) ?? "\(http.statusCode)"
            throw GoogleAuthError.tokenExchangeFailed(bodyStr)
        }
        let tokens = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        return tokens.id_token
    }

    // MARK: - PKCE helpers

    /// Gera um code_verifier URL-safe entre 43 e 128 caracteres (RFC 7636).
    private static func codeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    /// SHA-256 do verifier, codificado em base64url. É o code_challenge.
    private static func codeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    private static func randomString(length: Int) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var s = ""
        for _ in 0..<length {
            s.append(charset.randomElement()!)
        }
        return s
    }
}

// MARK: - Data → base64url

private extension Data {
    /// Base64URL sem padding (RFC 4648 §5). Usado em PKCE e JWT.
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #else
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return window
        }
        return ASPresentationAnchor()
        #endif
    }
}

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
