//
//  BXErro.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  Erro tipado do app novo (§1.7.3 da spec) e a mensagem pt-BR mostrada ao usuário.
//  Sem PIX em contexto de resgate, sem jargão, sem mensagem de desenvolvedor.
//  O mapeamento HTTP → BXErro mora no cliente (`BXAPI.mapearErro`); `BXErro.de(_:)` converte
//  qualquer erro (URLError, decodificação, Google) para as telas.
//

import Foundation

nonisolated struct BXErro: Error, Sendable, Equatable {
    enum Tipo: Sendable, Equatable {
        case semConexao, tempoEsgotado, servidor, sessaoExpirada, naoAutorizado, emailNaoVerificado,
             mfaNecessario, muitasTentativas, bloqueado, conflito, saldoInsuficiente, semEstoque,
             pagamentoIndisponivel, validacao, naoEncontrado, desconhecido
    }

    let status: Int
    let tipo: Tipo
    let codigo: String?
    let mensagemServidor: String?
    /// `issues[].message` (política de senha).
    let problemas: [String]
    let tentativasRestantes: Int?
    let tentarEmSegundos: Int?
    let bloqueadoAte: Date?
    /// previous_transfer_id, hint, mfa_method, …
    let extras: [String: String]
    /// Onde a mensagem do servidor vai aparecer (só `.compra` pode dizer "PIX").
    let contexto: BXSanitizador.Contexto

    init(status: Int = 0, tipo: Tipo, codigo: String? = nil, mensagemServidor: String? = nil,
         problemas: [String] = [], tentativasRestantes: Int? = nil, tentarEmSegundos: Int? = nil,
         bloqueadoAte: Date? = nil, extras: [String: String] = [:],
         contexto: BXSanitizador.Contexto = .geral) {
        self.status = status
        self.tipo = tipo
        self.codigo = codigo
        self.mensagemServidor = mensagemServidor
        self.problemas = problemas
        self.tentativasRestantes = tentativasRestantes
        self.tentarEmSegundos = tentarEmSegundos
        self.bloqueadoAte = bloqueadoAte
        self.extras = extras
        self.contexto = contexto
    }

    static let semConexao = BXErro(tipo: .semConexao)
    static let tempoEsgotado = BXErro(tipo: .tempoEsgotado)
    static let servidor = BXErro(status: 500, tipo: .servidor)

    /// Texto pt-BR para a tela.
    var mensagemParaUsuario: String {
        switch tipo {
        case .semConexao:
            return "Sem conexão. Verifique a internet e tente de novo."
        case .tempoEsgotado:
            return "O servidor está demorando para responder. Tente de novo em alguns segundos."
        case .servidor:
            return "Algo deu errado do nosso lado. Tente de novo."
        case .sessaoExpirada:
            return "Sua sessão expirou. Entre de novo."
        case .naoAutorizado:
            return mensagemServidorSegura ?? "Não foi possível confirmar seus dados. Confira e tente de novo."
        case .emailNaoVerificado:
            return "Confirme seu e-mail para continuar."
        case .mfaNecessario:
            return "Digite o código de verificação para continuar."
        case .muitasTentativas:
            return "Muitas tentativas. Aguarde um pouco e tente de novo."
        case .bloqueado:
            if let ate = bloqueadoAte {
                return "Conta bloqueada temporariamente. Tente de novo depois de \(BXFormato.hora(ate))."
            }
            return "Conta bloqueada temporariamente. Tente de novo mais tarde."
        case .conflito:
            return mensagemServidorSegura ?? "Parece uma operação repetida. Confira antes de tentar de novo."
        case .saldoInsuficiente:
            return "Pontos insuficientes."
        case .semEstoque:
            return "Este benefício esgotou."
        case .pagamentoIndisponivel:
            // Só ocorre na compra (POST /pix/charge): PIX aqui é meio de pagamento, nunca resgate (§1.7.3).
            return "O pagamento por PIX está indisponível no momento."
        case .validacao:
            return mensagemServidorSegura ?? "Confira os dados e tente de novo."
        case .naoEncontrado:
            return "Não encontramos o que você procurou."
        case .desconhecido:
            return "Algo deu errado. Tente de novo."
        }
    }

    /// Mensagem do servidor só se passar no filtro do contexto (sem PIX fora da compra, sem valor do ponto,
    /// sem dica técnica). Útil para mostrar o texto do servidor numa linha de erro de campo.
    var mensagemServidorSegura: String? {
        BXSanitizador.mensagemServidorSegura(mensagemServidor, contexto: contexto)
    }

    /// Erro que derruba a sessão (a casca já foi avisada pelo `BXAPI`).
    var ehSessao: Bool { tipo == .sessaoExpirada }

    /// Problemas da política de senha já filtrados, prontos para a checklist.
    var problemasSeguros: [String] {
        problemas.compactMap { BXSanitizador.mensagemServidorSegura($0, contexto: .acesso) }
    }

    /// Converte qualquer erro em `BXErro` para a tela.
    static func de(_ erro: Error) -> BXErro {
        if let e = erro as? BXErro { return e }
        if let u = erro as? URLError {
            switch u.code {
            case .timedOut: return .tempoEsgotado
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
                 .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff, .secureConnectionFailed,
                 .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid,
                 .serverCertificateHasUnknownRoot, .cancelled:
                return .semConexao
            default: return BXErro(tipo: .semConexao)
            }
        }
        if erro is DecodingError { return BXErro(status: 200, tipo: .desconhecido) }
        return BXErro(tipo: .desconhecido)
    }

    /// Cancelamento (tarefa da tela cancelada, Google fechado pelo usuário): a tela não mostra erro.
    static func ehCancelamento(_ erro: Error) -> Bool {
        if erro is CancellationError { return true }
        if let u = erro as? URLError, u.code == .cancelled, Task.isCancelled { return true }
        return false
    }
}
