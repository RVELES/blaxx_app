//
//  SSLPinning.swift
//  BlaxxPontos
//
//  SSL public-key pinning para `blaxx-pontos-exe.onrender.com`. Quando
//  ativado, qualquer certificado servido com chave pública diferente do
//  conjunto pré-aprovado fará a request falhar — bloqueando interceptação
//  por proxies (Burp/Charles/mitmproxy) e CAs maliciosos.
//
//  ⚠️  ESTADO ATUAL: estrutura criada mas pinning DESLIGADO (`isEnabled`
//  = false) porque o array `pinnedKeyHashes` está VAZIO. Render rotaciona
//  certificados periodicamente, e fixar um hash errado quebra o app
//  imediatamente. Para ativar:
//
//  1. Extrair o hash atual do servidor:
//
//     echo | openssl s_client -servername blaxx-pontos-exe.onrender.com \
//       -connect blaxx-pontos-exe.onrender.com:443 2>/dev/null \
//       | openssl x509 -pubkey -noout \
//       | openssl pkey -pubin -outform der \
//       | openssl dgst -sha256 -binary \
//       | base64
//
//  2. Extrair o hash do certificado da CA intermediária (Render usa Let's
//     Encrypt — pinar o intermediário sobrevive a rotações de leaf):
//
//     openssl s_client -servername blaxx-pontos-exe.onrender.com \
//       -connect blaxx-pontos-exe.onrender.com:443 -showcerts < /dev/null \
//       2>/dev/null > /tmp/chain.pem
//     # Pegar o 2º bloco BEGIN CERTIFICATE em /tmp/chain.pem, salvar como
//     # /tmp/intermediate.pem, depois:
//     openssl x509 -in /tmp/intermediate.pem -pubkey -noout \
//       | openssl pkey -pubin -outform der \
//       | openssl dgst -sha256 -binary | base64
//
//  3. Colar os dois hashes em `pinnedKeyHashes` (sempre 2+ para sobreviver
//     a rotação) e setar `isEnabled = true`.
//
//  4. Re-substituir `URLSession.shared` em API.swift por `SSLPinning.session`
//     (já existe um shim abaixo — basta usar).
//
//  5. Testar com um proxy MITM: a request DEVE falhar com NSURLErrorCancelled
//     (-999) ou serverTrustEvaluationFailed (-1202).
//

import Foundation

enum SSLPinning {
    /// Hashes SHA-256 (base64) das chaves públicas autorizadas.
    /// MANTER 2+ entradas: leaf em uso + intermediário (backup).
    ///
    /// Extraídos em 2026-06-29:
    /// - [0] leaf: CN=onrender.com — rotaciona ~90 dias (curto prazo)
    /// - [1] intermediate: Google Trust Services WE1 — estável (anos)
    ///
    /// Re-extraia o leaf antes de cada release; o intermediário é safe pin
    /// de longo prazo (Onrender usa GTS desde 2024).
    static let pinnedKeyHashes: [String] = [
        "NnfKqDbhvUeabxD97xg7r9JvWoGY7BJjg8XThNJxVbk=",  // leaf onrender.com
        "kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=",  // Google Trust Services WE1
    ]

    /// Liga/desliga o pinning. Ativo em RELEASE; desligado em DEBUG pra
    /// facilitar inspeção via Charles/mitmproxy durante o desenvolvimento.
    /// Em release, request com proxy MITM falha com -999 / -1202.
    #if DEBUG
    static let isEnabled = false
    #else
    static let isEnabled = true
    #endif

    /// URLSession com pinning aplicado (delegate verifica `serverTrust`).
    /// Quando `isEnabled` é false retorna `URLSession.shared` para não
    /// quebrar o app antes do pinning estar configurado.
    static let session: URLSession = {
        guard isEnabled, !pinnedKeyHashes.isEmpty else { return .shared }
        let cfg = URLSessionConfiguration.default
        cfg.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(configuration: cfg,
                          delegate: PinningDelegate(),
                          delegateQueue: nil)
    }()
}

/// Delegate `URLSessionDelegate` que extrai a chave pública do certificado
/// servido, calcula SHA-256, compara com a allow-list e aceita/recusa.
private final class PinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                  URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Avalia a cadeia normalmente antes de validar nosso pin (não
        // confiamos em certificados expirados/mal formados nem com pin).
        var trustError: CFError?
        guard SecTrustEvaluateWithError(trust, &trustError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Itera cada cert da cadeia e procura por uma chave pública que
        // bata com a allow-list. Pinning de chave > pinning de cert
        // porque a chave costuma sobreviver à renovação.
        let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] ?? []
        for cert in chain {
            if let hash = publicKeyHashSHA256(of: cert),
               SSLPinning.pinnedKeyHashes.contains(hash) {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }

        // Nenhum certificado da cadeia bate com nossa allow-list → MITM.
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    /// SHA-256(base64) da SubjectPublicKeyInfo do certificado.
    private func publicKeyHashSHA256(of cert: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(cert) else { return nil }
        var error: Unmanaged<CFError>?
        guard let derKey = SecKeyCopyExternalRepresentation(key, &error) as Data? else { return nil }
        return sha256Base64(of: derKey)
    }

    private func sha256Base64(of data: Data) -> String {
        // CommonCrypto via inline import; evita dependência externa.
        // Implementação simples — não dependemos de CryptoKit para manter
        // a compatibilidade com versões antigas.
        var digest = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { ptr in
            CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest).base64EncodedString()
    }
}

// MARK: - CommonCrypto shim (sem precisar de bridging header)
@_silgen_name("CC_SHA256")
private func CC_SHA256(_ data: UnsafeRawPointer?, _ len: CC_LONG, _ md: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<UInt8>?
private typealias CC_LONG = UInt32
