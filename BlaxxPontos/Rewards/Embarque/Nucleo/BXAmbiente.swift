//
//  BXAmbiente.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  URL base, versão e bandeiras de produto (BXRecursos). Cada bandeira tem dono na seção 6
//  de docs/redesenho/04-spec-redesenho.md e fica no padrão seguro até o dono decidir.
//

import Foundation

nonisolated enum BXAmbiente {
    static let urlProducao = URL(string: "https://blaxx-pontos-exe.onrender.com")!

    /// Release: sempre produção. DEBUG: `-BXBackend <url>` > UserDefaults("blaxx_backend_url") > produção.
    /// (A mesma chave do API.swift antigo; `-blaxx_backend_url <url>` no lançamento também preenche o UserDefaults.)
    static var urlBase: URL {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-BXBackend"), i + 1 < args.count, let u = URL(string: args[i + 1]) { return u }
        if let s = UserDefaults.standard.string(forKey: "blaxx_backend_url"), let u = URL(string: s) { return u }
        #endif
        return urlProducao
    }

    static var ehDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// "1.4 (27)"
    static var versaoApp: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "—"
        let b = info?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}

/// Bandeiras de produto. Padrão seguro até a decisão do dono (seção 6 da spec).
nonisolated enum BXRecursos {
    /// D02: compra por cartão (Stripe live + regra 3.1.1 da App Store).
    static let compraCartao = false
    /// D03: resgate por transferência (`/redeem/`) fica fora do app.
    static let resgateTransferencia = false
    /// D04: campanhas de produção escondidas em Release até confirmação.
    static var campanhas: Bool { BXAmbiente.ehDebug }
    /// D06: "Convidar amigos" só compartilha, sem prometer pontos.
    static let convidarAmigos = true
    /// D07: sem "% de bônus" nos pacotes.
    static let percentualBonusPacote = false
    /// D10 (decidido pelo dono em 22/10/2026): login com Google também em Release, pelo fluxo nativo do
    /// GoogleAuthService. Preparação App Store (23/10/2026): a regra 4.8 exige um login equivalente
    /// (Sign in with Apple) sempre que o Google aparece. O backend ainda não tem `POST /auth/apple`, então em
    /// Release o botão do Google só aparece quando `loginApple` for ligado. DEBUG continua com o Google.
    /// (A reautenticação Google para excluir conta só-Google continua funcionando: não depende do botão.)
    static var loginGoogle: Bool { BXAmbiente.ehDebug || loginApple }
    /// Sign in with Apple (regra 4.8). Ligar só quando o backend tiver `POST /auth/apple` e o app tiver o botão
    /// e o entitlement `com.apple.developer.applesignin` (ver docs/APP_STORE_PUBLICACAO.md).
    static let loginApple = false
    /// D11: bloqueio por Face ID ao abrir.
    static let bloqueioFaceID = false

    // MARK: Preparação App Store (23/10/2026) — ver docs/APP_STORE_PUBLICACAO.md

    /// Compra de pontos dentro do app iOS (aba Comprar, pacotes, valor livre, PIX, histórico de compras).
    /// Release: DESLIGADA para a revisão da App Store — (1) o PIX de produção está fora do ar (C6 cancelou a
    /// homologação, D01), e o revisor encontraria um fluxo que sempre falha (regra 2.1); (2) vender pontos
    /// dentro do app fora do In-App Purchase é risco da regra 3.1.1. Para religar: `compraNoAppRelease = true`.
    /// Desligada, a compra some de todas as telas, sem texto mandando comprar fora do app (anti-steering 3.1.1).
    static let compraNoAppRelease = false
    static var compraNoApp: Bool { BXAmbiente.ehDebug || compraNoAppRelease }

    /// D05: a lista de `GET /partners/` traz ~258 marcas reais copiadas como "Parceiro Livelo · …", sem contrato
    /// nem integração. Mostrar marcas de terceiros como "parceiros" na App Store é risco das regras 5.2.1/2.3.1.
    /// Release: escondidas até existir contrato. Para religar: `true`.
    static let parceirosSemContratoRelease = false
    static var parceirosSemContrato: Bool { BXAmbiente.ehDebug || parceirosSemContratoRelease }

    /// Benefícios do tipo sorteio (ex.: "Sorteio R$ 1.000"): a regra 5.3 exige regulamento oficial no app e o
    /// aviso de que a Apple não patrocina; no Brasil sorteio promocional também depende de autorização (Lei 5.768/71).
    /// Release: escondidos até essas condições existirem. Para religar: `true`.
    static let sorteiosRelease = false
    static var sorteios: Bool { BXAmbiente.ehDebug || sorteiosRelease }
}
