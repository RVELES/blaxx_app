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
    /// MANTER 2+ entradas, todas da cadeia real do servidor.
    ///
    /// Atualizados em 2026-10-28 (o leaf de 06/29 já tinha rotacionado).
    /// O leaf não é mais fixado: o Render o troca a cada ~90 dias. Fica o
    /// intermediário em uso + as quatro raízes da Google Trust Services
    /// (válidas até 2036), para sobreviver à troca de intermediário ou de
    /// algoritmo (WE1 → WR1 etc.). A validação aceita qualquer certificado
    /// da cadeia, então basta um bater.
    ///
    /// Extração: `openssl x509 -pubkey -noout | openssl pkey -pubin -outform der
    /// | openssl dgst -sha256 -binary | base64` (SPKI completa).
    static let pinnedKeyHashes: [String] = [
        "kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=",  // GTS WE1 (intermediário atual)
        "hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=",  // GTS Root R1 (RSA 4096)
        "Vfd95BwDeSQo+NUYxVEEIlvkOlWY2SalKK1lPhzOx78=",  // GTS Root R2 (RSA 4096)
        "QXnt2YHvdHR3tJYmQIr0Paosp6t/nggsEGD4QJZ3Q0g=",  // GTS Root R3 (EC P-384)
        "mEflZT5enoR1FuXLgYYGqnVEoZvmf9c2bVBpiOjYQ0c=",  // GTS Root R4 (EC P-384)
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
            if let hash = PinningDelegate.spkiHashSHA256(of: cert),
               SSLPinning.pinnedKeyHashes.contains(hash) {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }

        // Nenhum certificado da cadeia bate com nossa allow-list → MITM.
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    /// SHA-256(base64) da SubjectPublicKeyInfo do certificado.
    ///
    /// `SecKeyCopyExternalRepresentation` devolve a chave CRUA (ponto EC ou
    /// PKCS#1 RSA), sem o cabeçalho ASN.1 da SPKI. Os pins acima vêm do
    /// `openssl pkey -outform der`, que é a SPKI completa — sem recolocar o
    /// cabeçalho o hash nunca bate e toda request em Release é cancelada
    /// (foi o que impediu o login do revisor da Apple no build 6).
    static func spkiHashSHA256(of cert: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(cert),
              let attrs = SecKeyCopyAttributes(key) as? [CFString: Any],
              let tipo = attrs[kSecAttrKeyType] as? String,
              let bits = attrs[kSecAttrKeySizeInBits] as? Int else { return nil }
        var error: Unmanaged<CFError>?
        guard let raw = SecKeyCopyExternalRepresentation(key, &error) as Data?,
              let cabecalho = spkiCabecalho(tipo: tipo, bits: bits) else { return nil }
        return sha256Base64(of: cabecalho + raw)
    }

    /// Prefixos ASN.1 da SPKI por tipo/tamanho de chave.
    private static func spkiCabecalho(tipo: String, bits: Int) -> Data? {
        let ec = kSecAttrKeyTypeECSECPrimeRandom as String
        let rsa = kSecAttrKeyTypeRSA as String
        let hex: String
        if tipo == ec && bits == 256 {
            hex = "3059301306072a8648ce3d020106082a8648ce3d030107034200"
        } else if tipo == ec && bits == 384 {
            hex = "3076301006072a8648ce3d020106052b81040022036200"
        } else if tipo == rsa && bits == 2048 {
            hex = "30820122300d06092a864886f70d01010105000382010f00"
        } else if tipo == rsa && bits == 4096 {
            hex = "30820222300d06092a864886f70d01010105000382020f00"
        } else {
            return nil
        }
        var d = Data()
        var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            d.append(UInt8(hex[i..<j], radix: 16)!)
            i = j
        }
        return d
    }

    private static func sha256Base64(of data: Data) -> String {
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
