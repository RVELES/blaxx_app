//
//  BXModelos.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  DTOs sanitizados (§1.7.4 da spec): cada modelo decodifica SÓ os campos permitidos; os proibidos
//  (valor do ponto, accrual_rule, emojis, mechanic, target_brl…) ficam fora do CodingKeys.
//  Decodificação tolerante: campo opcional ausente não derruba a lista; item malformado é descartado
//  (com log em DEBUG) por `BXListaTolerante`. Datas por `BXFormato.iso8601` (o backend manda ISO sem fuso = UTC).
//  Pedidos (corpo de POST) no fim do arquivo: `BXCadastro`, `BXPedidoEnvio`, `BXPedidoCartao`.
//

import Foundation

// MARK: - Pacote (GET /pix/packages)

nonisolated struct BXPacote: Decodable, Sendable, Identifiable, Hashable {
    /// Chave do objeto na resposta: start, plus, prime, black.
    let chave: String
    let rotulo: String
    let pontos: Int
    /// Tarifa do pacote em reais (preço que o cliente paga; não é valor do ponto).
    let preco: Decimal

    var id: String { chave }

    init(chave: String, rotulo: String, pontos: Int, preco: Decimal) {
        self.chave = chave
        self.rotulo = rotulo
        self.pontos = pontos
        self.preco = preco
    }

    private enum CodingKeys: String, CodingKey { case key, label, points, price_brl }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // A resposta é um objeto { "plus": {…} }: a chave vem do caminho de decodificação.
        chave = (try? c.decode(String.self, forKey: .key)) ?? decoder.codingPath.last?.stringValue ?? ""
        rotulo = (try? c.decode(String.self, forKey: .label)) ?? chave.capitalized
        pontos = try c.decode(Int.self, forKey: .points)
        if let d = try? c.decode(Decimal.self, forKey: .price_brl) {
            preco = d
        } else if let s = try? c.decode(String.self, forKey: .price_brl),
                  let d = Decimal(string: s.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) {
            preco = d
        } else {
            preco = 0
        }
    }

    /// Ordem fixa da vitrine: start, plus, prime, black (desconhecidos no fim, por pontos).
    static func ordenar(_ pacotes: [BXPacote]) -> [BXPacote] {
        let ordem = ["start", "plus", "prime", "black"]
        return pacotes.sorted { a, b in
            let ia = ordem.firstIndex(of: a.chave) ?? Int.max
            let ib = ordem.firstIndex(of: b.chave) ?? Int.max
            return ia == ib ? a.pontos < b.pontos : ia < ib
        }
    }
}

// MARK: - Campanha (GET /campaigns/)

nonisolated struct BXCampanha: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let nome: String
    let descricao: String?
    let pontosRecompensa: Int
    let inicio: Date?
    let fim: Date?
    let participando: Bool
    /// 0…100. Só percentual: nunca meta ou progresso em R$.
    let progresso: Double
    let concluidaEm: Date?

    init(id: String, nome: String, descricao: String?, pontosRecompensa: Int, inicio: Date? = nil, fim: Date? = nil,
         participando: Bool = false, progresso: Double = 0, concluidaEm: Date? = nil) {
        self.id = id
        self.nome = nome
        self.descricao = descricao
        self.pontosRecompensa = pontosRecompensa
        self.inicio = inicio
        self.fim = fim
        self.participando = participando
        self.progresso = progresso
        self.concluidaEm = concluidaEm
    }

    // `mechanic`, `target_brl` e `progress_brl` NÃO são decodificados (regra do dono).
    private enum CodingKeys: String, CodingKey {
        case id, name, description, reward_pts, period_start, period_end, joined, progress_pct, completed_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) { id = s } else { id = String(try c.decode(Int.self, forKey: .id)) }
        nome = try c.decode(String.self, forKey: .name)
        descricao = try? c.decodeIfPresent(String.self, forKey: .description)
        pontosRecompensa = (try? c.decode(Int.self, forKey: .reward_pts)) ?? 0
        inicio = (try? c.decodeIfPresent(String.self, forKey: .period_start)).flatMap { $0 }.flatMap(BXFormato.iso8601)
        fim = (try? c.decodeIfPresent(String.self, forKey: .period_end)).flatMap { $0 }.flatMap(BXFormato.iso8601)
        participando = (try? c.decode(Bool.self, forKey: .joined)) ?? false
        progresso = (try? c.decode(Double.self, forKey: .progress_pct)) ?? 0
        concluidaEm = (try? c.decodeIfPresent(String.self, forKey: .completed_at)).flatMap { $0 }.flatMap(BXFormato.iso8601)
    }

    /// Nome sem valor em reais nem PIX; se o nome cair no filtro, um rótulo neutro.
    var nomeSeguro: String { BXSanitizador.textoCampanhaSeguro(nome) ?? "Campanha BlaXx" }
    /// Descrição só se passar no filtro de campanha.
    var descricaoSegura: String? { BXSanitizador.textoCampanhaSeguro(descricao) }
    /// Dias até o fim (0 = último dia); nil sem data de fim.
    func diasRestantes(agora: Date = .now) -> Int? {
        guard let fim else { return nil }
        let cal = Calendar(identifier: .gregorian)
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: agora), to: cal.startOfDay(for: fim)).day ?? 0)
    }
    var concluida: Bool { concluidaEm != nil }
}

// MARK: - Ajudantes de decodificação

/// Chave dinâmica (objetos cujas chaves são dados, como `/pix/packages`).
nonisolated struct BXChaveDinamica: CodingKey, Sendable {
    let stringValue: String
    let intValue: Int?
    init(_ s: String) { stringValue = s; intValue = nil }
    init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
    init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}

/// Item que só serve para avançar o contêiner quando um elemento da lista é malformado.
nonisolated private struct BXIgnorado: Decodable {
    init(from decoder: Decoder) throws {}
}

/// Lista que descarta itens malformados em vez de falhar inteira.
nonisolated struct BXListaTolerante<T: Decodable & Sendable>: Decodable, Sendable {
    let itens: [T]
    init(_ itens: [T]) { self.itens = itens }
    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        var r: [T] = []
        while !c.isAtEnd {
            do {
                r.append(try c.decode(T.self))
            } catch {
                #if DEBUG
                print("[BXModelos] item de \(T.self) descartado: \(error)")
                #endif
                _ = try? c.decode(BXIgnorado.self)
            }
        }
        itens = r
    }
}

/// `{ "items": [...] }` (a forma da maioria das listas do backend).
nonisolated struct BXEnvelopeItens<T: Decodable & Sendable>: Decodable, Sendable {
    let itens: [T]
    private enum CodingKeys: String, CodingKey { case items }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itens = (try? c.decode(BXListaTolerante<T>.self, forKey: .items))?.itens ?? []
    }
}

nonisolated extension KeyedDecodingContainer {
    /// Texto (aceita número, para ids inteiros).
    func bxTexto(_ k: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: k) { return s }
        if let i = try? decodeIfPresent(Int.self, forKey: k) { return String(i) }
        return nil
    }
    /// Id obrigatório (texto ou número).
    func bxID(_ k: Key) throws -> String {
        if let s = bxTexto(k), !s.isEmpty { return s }
        throw DecodingError.keyNotFound(k, .init(codingPath: codingPath, debugDescription: "id ausente"))
    }
    func bxInt(_ k: Key) -> Int? {
        if let i = try? decodeIfPresent(Int.self, forKey: k) { return i }
        if let d = try? decodeIfPresent(Double.self, forKey: k) { return Int(d.rounded()) }
        if let s = try? decodeIfPresent(String.self, forKey: k) { return Int(s) }
        return nil
    }
    func bxDouble(_ k: Key) -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: k) { return d }
        if let s = try? decodeIfPresent(String.self, forKey: k) { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
    func bxBool(_ k: Key) -> Bool? {
        if let b = try? decodeIfPresent(Bool.self, forKey: k) { return b }
        if let i = try? decodeIfPresent(Int.self, forKey: k) { return i != 0 }
        return nil
    }
    func bxData(_ k: Key) -> Date? {
        guard let s = try? decodeIfPresent(String.self, forKey: k) else { return nil }
        return BXFormato.iso8601(s)
    }
    /// Reais (preço de pacote, valor de cobrança). Nunca usar para valor do ponto.
    func bxDecimal(_ k: Key) -> Decimal? {
        if let s = try? decodeIfPresent(String.self, forKey: k) {
            return Decimal(string: s.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
        }
        if let d = try? decodeIfPresent(Double.self, forKey: k) {
            // Passa pelo texto com 2 casas: evita 469.99999… de Double → Decimal.
            return Decimal(string: String(format: "%.2f", d), locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }
}

/// `/pix/packages`: objeto `{ "plus": {…}, … }` → pacotes na ordem da vitrine.
nonisolated struct BXMapaPacotes: Decodable, Sendable {
    let pacotes: [BXPacote]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: BXChaveDinamica.self)
        var r: [BXPacote] = []
        for k in c.allKeys {
            if let p = try? c.decode(BXPacote.self, forKey: k), p.pontos > 0 { r.append(p) }
        }
        pacotes = BXPacote.ordenar(r)
    }
}

// MARK: - Usuário (GET /auth/me, `user` do login)

nonisolated struct BXUsuario: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let nome: String
    let email: String
    /// CPF cru (só dígitos) ou "G:<sub>" em conta Google sem CPF. A tela usa `cpfMascarado`.
    let cpf: String?
    let celular: String?
    let emailVerificadoEm: Date?
    let ehVIP: Bool
    let mfaAtivo: Bool
    let temSenha: Bool
    let googleVinculado: Bool
    /// "password", "google", …
    let provedor: String?
    // `pix_key`, `avatar_url`, `role`, `status` NÃO são decodificados (D03; nada de chave de transferência na tela).

    private enum CodingKeys: String, CodingKey {
        case id, name, email, cpf, phone, email_verified_at, is_vip, mfa_enabled, has_password, google_linked, auth_provider
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        nome = BXSanitizador.semSimbolos(c.bxTexto(.name) ?? "").trimmingCharacters(in: .whitespaces)
        email = c.bxTexto(.email) ?? ""
        cpf = c.bxTexto(.cpf)
        celular = c.bxTexto(.phone)
        emailVerificadoEm = c.bxData(.email_verified_at)
        ehVIP = c.bxBool(.is_vip) ?? false
        mfaAtivo = c.bxBool(.mfa_enabled) ?? false
        temSenha = c.bxBool(.has_password) ?? true
        googleVinculado = c.bxBool(.google_linked) ?? false
        provedor = c.bxTexto(.auth_provider)
    }

    /// Cartão BlaXx: 8 primeiros hex do id, maiúsculos (igual ao `member.id` de `/card/`). "DE0A11C2".
    var cartaoID: String {
        String(id.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    }
    /// "DE0A 11C2"
    var cartaoFormatado: String { BXFormato.cartao(id) }
    var primeiroNome: String? {
        nome.split(separator: " ").first.map(String.init).flatMap { $0.isEmpty ? nil : $0 }
    }
    var inicial: String? { primeiroNome.map { String($0.prefix(1)).uppercased() } }
    var emailVerificado: Bool { emailVerificadoEm != nil }
    /// Conta criada pelo Google, sem CPF real ("G:<sub>").
    var contaGoogleSemCPF: Bool { cpf?.hasPrefix("G:") ?? false }
    /// "***.***.789-**"; nil sem CPF real.
    var cpfMascarado: String? {
        guard let cpf, !contaGoogleSemCPF, !cpf.isEmpty else { return nil }
        return BXFormato.cpfMascarado(cpf)
    }
    /// "+55 (••) •••••-1234"; nil sem celular.
    var celularMascarado: String? {
        guard let celular, !celular.isEmpty else { return nil }
        return BXFormato.celularMascarado(celular)
    }
}

// MARK: - Carteira (GET /wallet/)

nonisolated struct BXCarteira: Codable, Sendable, Hashable {
    /// `balance_pts`. É o saldo; NÃO subtrair `emProcessamento` (já saiu do saldo no envio).
    let saldo: Int
    /// `pending_pts`: envios ainda na janela de 60 s.
    let emProcessamento: Int
    // `balance_brl_equiv` NÃO é decodificado (valor do ponto).

    init(saldo: Int, emProcessamento: Int) {
        self.saldo = saldo
        self.emProcessamento = emProcessamento
    }

    private enum ChavesAPI: String, CodingKey { case balance_pts, pending_pts }
    private enum ChavesCache: String, CodingKey { case saldo, emProcessamento }

    init(from decoder: Decoder) throws {
        if let c = try? decoder.container(keyedBy: ChavesCache.self), let s = c.bxInt(.saldo) {
            saldo = s
            emProcessamento = c.bxInt(.emProcessamento) ?? 0
            return
        }
        let c = try decoder.container(keyedBy: ChavesAPI.self)
        guard let s = c.bxInt(.balance_pts) else {
            throw DecodingError.keyNotFound(ChavesAPI.balance_pts, .init(codingPath: c.codingPath, debugDescription: "saldo ausente"))
        }
        saldo = s
        emProcessamento = c.bxInt(.pending_pts) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ChavesCache.self)
        try c.encode(saldo, forKey: .saldo)
        try c.encode(emProcessamento, forKey: .emProcessamento)
    }
}

// MARK: - Extrato (GET /wallet/transactions)

nonisolated enum BXTipoLancamento: String, Sendable, Hashable, CaseIterable {
    case purchase, transferOut = "transfer_out", transferIn = "transfer_in", redeem, refund, bonus, expire, accrual
    case desconhecido
}

nonisolated enum BXStatusLancamento: String, Sendable, Hashable {
    case pendente = "pending", confirmado = "confirmed", revertido = "reversed", desconhecido
}

nonisolated struct BXLancamento: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let tipo: BXTipoLancamento
    let status: BXStatusLancamento
    /// Com sinal: entrada positiva, saída negativa.
    let pontos: Int
    /// `reference`: id do envio (transfer_out/in), da cobrança, do voucher…
    let referencia: String?
    let criadoEm: Date
    /// Descrição crua do servidor: fica privada (pode ter "Resgate via PIX → chave", "Envio (pending)…").
    private let descricaoServidor: String?

    private enum CodingKeys: String, CodingKey { case id, type, status, amount_pts, description, reference, created_at }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        tipo = BXTipoLancamento(rawValue: c.bxTexto(.type) ?? "") ?? .desconhecido
        status = BXStatusLancamento(rawValue: c.bxTexto(.status) ?? "") ?? .desconhecido
        pontos = c.bxInt(.amount_pts) ?? 0
        referencia = c.bxTexto(.reference)
        criadoEm = c.bxData(.created_at) ?? .distantPast
        descricaoServidor = c.bxTexto(.description)
    }

    /// "Compra de pontos", "Pontos enviados", "Envio desfeito"…
    var rotulo: String { BXSanitizador.rotulo(tipo: tipo, descricao: descricaoServidor) }
    /// Complemento seguro (nil quando a descrição não pode ir para a tela).
    var detalhe: String? { BXSanitizador.detalheLancamento(descricaoServidor) }
    var ehEntrada: Bool { pontos > 0 }
    /// Envio que ainda pode ser desfeito (60 s a partir de `criadoEm`; o servidor decide no fim).
    func envioDesfazivel(agora: Date = .now) -> Bool {
        tipo == .transferOut && status == .pendente && referencia != nil && agora.timeIntervalSince(criadoEm) < 60
    }
}

// MARK: - Cartão BlaXx e níveis (GET /card/, /card/tiers)

nonisolated struct BXNivel: Decodable, Sendable, Identifiable, Hashable {
    /// bronze, prata, ouro, black, vip
    let chave: String
    let nome: String
    let minimo: Int
    let porConvite: Bool
    // `perks`, `color`, `text_color` NÃO são decodificados (D09; cores pela paleta local `BXCor.nivel`).
    var id: String { chave }

    private enum CodingKeys: String, CodingKey { case key, label, min_points, invite_only }

    init(chave: String, nome: String, minimo: Int, porConvite: Bool = false) {
        self.chave = chave; self.nome = nome; self.minimo = minimo; self.porConvite = porConvite
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chave = (c.bxTexto(.key) ?? "").lowercased()
        nome = BXSanitizador.semSimbolos(c.bxTexto(.label) ?? chave.capitalized)
        minimo = c.bxInt(.min_points) ?? 0
        porConvite = (c.bxBool(.invite_only) ?? false) || chave == "vip"
    }

    /// "0+ pts", "20.000+ pts", "Por convite".
    var rotuloMinimo: String { porConvite ? "Por convite" : "\(BXFormato.pontos(minimo))+ pts" }
}

nonisolated struct BXCartaoEstado: Decodable, Sendable, Hashable {
    /// "DE0A11C2"
    let membroID: String
    let membroNome: String
    let saldo: Int
    /// Pontos acumulados na vida (definem o nível; não caem ao resgatar).
    let acumulado: Int
    let nivel: BXNivel?
    let proximoNivel: BXNivel?
    let faltam: Int
    /// 0…100
    let progresso: Double
    let niveis: [BXNivel]
    let passeDisponivel: Bool

    private enum CodingKeys: String, CodingKey {
        case member, balance_pts, lifetime_points, tier, next_tier, points_to_next, progress_pct, tiers, wallet_pass_available
    }
    private enum ChavesMembro: String, CodingKey { case id, name }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let m = try? c.nestedContainer(keyedBy: ChavesMembro.self, forKey: .member) {
            membroID = (m.bxTexto(.id) ?? "").uppercased()
            membroNome = BXSanitizador.semSimbolos(m.bxTexto(.name) ?? "")
        } else {
            membroID = ""; membroNome = ""
        }
        saldo = c.bxInt(.balance_pts) ?? 0
        acumulado = c.bxInt(.lifetime_points) ?? 0
        nivel = try? c.decodeIfPresent(BXNivel.self, forKey: .tier)
        proximoNivel = try? c.decodeIfPresent(BXNivel.self, forKey: .next_tier)
        faltam = c.bxInt(.points_to_next) ?? 0
        progresso = min(100, max(0, c.bxDouble(.progress_pct) ?? 0))
        niveis = (try? c.decode(BXListaTolerante<BXNivel>.self, forKey: .tiers))?.itens ?? []
        passeDisponivel = c.bxBool(.wallet_pass_available) ?? false
    }

    var fracaoProgresso: Double { progresso / 100 }
    /// "DE0A 11C2"
    var cartaoFormatado: String { BXFormato.cartao(membroID) }
}

/// `/card/tiers` → `{ "tiers": [...] }`
nonisolated struct BXEnvelopeNiveis: Decodable, Sendable {
    let niveis: [BXNivel]
    private enum CodingKeys: String, CodingKey { case tiers }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        niveis = (try? c.decode(BXListaTolerante<BXNivel>.self, forKey: .tiers))?.itens ?? []
    }
}

// MARK: - Compra por PIX (/pix/*)

nonisolated struct BXProvedorPix: Decodable, Sendable, Hashable {
    let nome: String
    let ehMock: Bool
    private enum CodingKeys: String, CodingKey { case name, is_mock }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nome = c.bxTexto(.name) ?? ""
        ehMock = c.bxBool(.is_mock) ?? false
    }
}

nonisolated enum BXStatusCobranca: String, Sendable, Hashable {
    case pendente = "pending", aguardandoConfirmacao = "pending_confirmation", paga = "paid"
    case expirada = "expired", estornada = "refunded", recusada = "rejected", desconhecido
    /// Ainda pode ser paga (polling continua).
    var emAberto: Bool { self == .pendente || self == .aguardandoConfirmacao }
}

nonisolated struct BXCobrancaPix: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    /// Valor da cobrança que o cliente vai pagar (`amount_brl`).
    let valor: Decimal
    /// Pontos que entram na conta, calculados pelo servidor (`points_to_credit`).
    let pontos: Int
    /// "copia e cola"
    let brCode: String?
    /// PNG do QR quando o servidor manda (`qr_code_image` data URI); senão o app gera pelo `brCode`.
    let qrImagem: Data?
    let status: BXStatusCobranca
    let expiraEm: Date?
    let pagaEm: Date?
    /// Chave do pacote ou "custom" (valor livre).
    let pacote: String?

    private enum CodingKeys: String, CodingKey {
        case id, amount_brl, points_to_credit, br_code, qr_code_image, status, expires_at, paid_at, package
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        valor = c.bxDecimal(.amount_brl) ?? 0
        pontos = c.bxInt(.points_to_credit) ?? 0
        brCode = c.bxTexto(.br_code).flatMap { $0.isEmpty ? nil : $0 }
        qrImagem = c.bxTexto(.qr_code_image).flatMap(BXCobrancaPix.dadosDeDataURI)
        status = BXStatusCobranca(rawValue: c.bxTexto(.status) ?? "") ?? .desconhecido
        expiraEm = c.bxData(.expires_at)
        pagaEm = c.bxData(.paid_at)
        pacote = c.bxTexto(.package)
    }

    /// Segundos até expirar (0 quando já passou; nil sem data).
    func segundosParaExpirar(agora: Date = .now) -> Int? {
        expiraEm.map { max(0, Int($0.timeIntervalSince(agora).rounded(.down))) }
    }
    /// Valor livre (sem pacote).
    var ehValorLivre: Bool { pacote == nil || pacote == "custom" }
    /// Data para ordenar o histórico (o backend não manda `created_at`): paga em, ou 30 min antes de expirar.
    var dataReferencia: Date { pagaEm ?? expiraEm?.addingTimeInterval(-30 * 60) ?? .distantPast }

    static func dadosDeDataURI(_ s: String) -> Data? {
        guard s.hasPrefix("data:"), let virgula = s.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(s[s.index(after: virgula)...]), options: .ignoreUnknownCharacters)
    }
}

// MARK: - Compra por cartão (/payments/card/*, atrás de BXRecursos.compraCartao)

nonisolated struct BXConfigCartao: Decodable, Sendable, Hashable {
    let habilitado: Bool
    let provedor: String?
    let chavePublica: String?
    let parcelasMaximas: Int
    private enum CodingKeys: String, CodingKey { case enabled, provider, public_key, max_installments }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        habilitado = c.bxBool(.enabled) ?? false
        provedor = c.bxTexto(.provider)
        chavePublica = c.bxTexto(.public_key)
        parcelasMaximas = c.bxInt(.max_installments) ?? 1
    }
}

nonisolated struct BXCobrancaCartao: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let valor: Decimal
    let pontos: Int
    /// approved, in_process, rejected, …
    let status: String
    let detalheStatus: String?
    let bandeira: String?
    let finalCartao: String?
    let criadaEm: Date?
    private enum CodingKeys: String, CodingKey {
        case id, amount_brl, points_to_credit, status, status_detail, card_brand, card_last4, created_at
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        valor = c.bxDecimal(.amount_brl) ?? 0
        pontos = c.bxInt(.points_to_credit) ?? 0
        status = c.bxTexto(.status) ?? ""
        detalheStatus = c.bxTexto(.status_detail)
        bandeira = c.bxTexto(.card_brand)
        finalCartao = c.bxTexto(.card_last4)
        criadaEm = c.bxData(.created_at)
    }
    var aprovada: Bool { status == "approved" }
    var emProcessamento: Bool { status == "in_process" || status == "pending" }
}

// MARK: - Envio (/transfer/)

nonisolated struct BXEnvio: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let pontos: Int
    let mensagem: String?
    /// "ENV-2026-XXXX-XXXXXXXX"
    let comprovante: String
    let criadoEm: Date
    /// pending, committed, cancelled
    let status: String
    /// Quando o envio se efetiva (criação + 60 s).
    let efetivaEm: Date?
    let canceladoEm: Date?
    let cancelavel: Bool

    private enum CodingKeys: String, CodingKey {
        case id, amount_pts, message, receipt_code, created_at, status, committed_at, cancelled_at, is_cancellable
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        pontos = abs(c.bxInt(.amount_pts) ?? 0)
        mensagem = BXSanitizador.textoSeguro(c.bxTexto(.message))
        comprovante = c.bxTexto(.receipt_code) ?? ""
        criadoEm = c.bxData(.created_at) ?? .now
        status = c.bxTexto(.status) ?? "pending"
        efetivaEm = c.bxData(.committed_at)
        canceladoEm = c.bxData(.cancelled_at)
        cancelavel = c.bxBool(.is_cancellable) ?? false
    }

    var cancelado: Bool { status == "cancelled" || canceladoEm != nil }
    var pendente: Bool { status == "pending" && !cancelado }
    /// Segundos até efetivar (0 quando já passou). Sem `committed_at`, 60 s a partir da criação.
    func segundosParaEfetivar(agora: Date = .now) -> Int {
        let alvo = efetivaEm ?? criadoEm.addingTimeInterval(60)
        return max(0, Int(alvo.timeIntervalSince(agora).rounded(.up)))
    }
}

// MARK: - Parceiros (/partners/*)

nonisolated struct BXParceiro: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let nome: String
    /// Categoria original do banco (o cartão mostra esta; a pílula usa `categoriaCanonica`).
    let categoria: String
    let cidade: String?
    private let descricaoServidor: String?
    // `logo_emoji` e `accrual_rule` NÃO são decodificados.

    private enum CodingKeys: String, CodingKey { case id, name, category, description, city }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        nome = BXSanitizador.semSimbolos(c.bxTexto(.name) ?? "").trimmingCharacters(in: .whitespaces)
        categoria = (c.bxTexto(.category) ?? "").trimmingCharacters(in: .whitespaces)
        cidade = c.bxTexto(.city).flatMap { $0.isEmpty ? nil : $0 }
        descricaoServidor = c.bxTexto(.description)
    }

    var categoriaCanonica: String { BXSanitizador.categoriaCanonica(categoria) }
    var icone: BXIconeNome { BXSanitizador.icone(categoriaParceiro: categoria, nome: nome) }
    /// nil se a descrição casar com a regra do dono ("Parceiro Livelo", "fictícia", PIX, valor do ponto).
    var descricaoSegura: String? { BXSanitizador.textoSeguro(descricaoServidor) }
    /// Parceiro de exemplo: escondido em TODAS as builds (o `BXAPI` já filtra as listas).
    var ehFicticio: Bool { BXSanitizador.ehFicticio(descricao: descricaoServidor) }
    /// Marca de terceiro sem contrato ("Parceiro Livelo · …", D05).
    var ehSemContrato: Bool { BXSanitizador.ehSemContrato(descricao: descricaoServidor) }
    /// Fica fora das listas do app: exemplo (sempre) ou marca sem contrato (Release, `BXRecursos.parceirosSemContrato`).
    var escondidoNoApp: Bool { ehFicticio || (ehSemContrato && !BXRecursos.parceirosSemContrato) }
    /// Texto normalizado para a busca local (nome + categoria, sem acento).
    var textoBusca: String { BXSanitizador.normalizar("\(nome) \(categoria) \(categoriaCanonica)") }
}

nonisolated struct BXParceiroDetalhe: Decodable, Sendable, Hashable {
    let parceiro: BXParceiro
    /// Só benefícios ativos, ordenados por custo.
    let beneficios: [BXBeneficio]
    private enum CodingKeys: String, CodingKey { case benefits }
    init(parceiro: BXParceiro, beneficios: [BXBeneficio]) {
        self.parceiro = parceiro
        self.beneficios = beneficios
    }
    init(from decoder: Decoder) throws {
        parceiro = try BXParceiro(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lista = (try? c.decode(BXListaTolerante<BXBeneficio>.self, forKey: .benefits))?.itens ?? []
        beneficios = lista.filter(\.ativo).sorted { $0.custo < $1.custo }
    }
    /// Menor custo entre os benefícios ("A partir de X pts").
    var aPartirDe: Int? { beneficios.map(\.custo).min() }
}

// MARK: - Benefícios e vouchers (/benefits/*, /vouchers/*)

nonisolated struct BXBeneficio: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let parceiroID: String?
    let nomeParceiro: String?
    let nome: String
    /// Categoria crua do servidor ("educacao"); a tela usa `rotuloCategoria`.
    let categoria: String
    let custo: Int
    /// -1 = ilimitado
    let estoque: Int
    let validadeDias: Int?
    let tag: String?
    let ativo: Bool
    private let descricaoServidor: String?
    // `image_emoji` NÃO é decodificado.

    private enum CodingKeys: String, CodingKey {
        case id, partner_id, partner_name, name, description, category, cost_pts, stock, expires_in_days, tag, is_active
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        parceiroID = c.bxTexto(.partner_id)
        nomeParceiro = c.bxTexto(.partner_name).map { BXSanitizador.semSimbolos($0) }
        nome = BXSanitizador.semSimbolos(c.bxTexto(.name) ?? "").trimmingCharacters(in: .whitespaces)
        categoria = (c.bxTexto(.category) ?? "").lowercased()
        custo = c.bxInt(.cost_pts) ?? 0
        estoque = c.bxInt(.stock) ?? -1
        validadeDias = c.bxInt(.expires_in_days)
        tag = c.bxTexto(.tag).flatMap { BXSanitizador.textoSeguro($0) }
        ativo = c.bxBool(.is_active) ?? true
        descricaoServidor = c.bxTexto(.description)
    }

    var descricaoSegura: String? { BXSanitizador.textoSeguro(descricaoServidor) }
    var rotuloCategoria: String { BXSanitizador.rotulo(categoriaBeneficio: categoria) }
    var icone: BXIconeNome { BXSanitizador.icone(categoriaBeneficio: categoria) }
    var esgotado: Bool { estoque == 0 }
    /// Sorteio fica fora do app em Release até ter regulamento e autorização (`BXRecursos.sorteios`, regra 5.3).
    var escondidoNoApp: Bool { categoria == "sorteio" && !BXRecursos.sorteios }
    var estoqueIlimitado: Bool { estoque < 0 }
    /// Benefício da própria BlaXx (sem parceiro).
    var daBlaxx: Bool { parceiroID == nil }
    /// Quanto falta para resgatar com o saldo dado (0 = dá para resgatar).
    func faltam(saldo: Int) -> Int { max(0, custo - saldo) }
}

nonisolated enum BXStatusVoucher: String, Sendable, Hashable {
    case ativo = "active", usado = "used", expirado = "expired", desconhecido
}

nonisolated struct BXVoucher: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let beneficioID: String?
    let nomeBeneficio: String
    let codigo: String
    let pontosGastos: Int
    let expiraEm: Date?
    let usadoEm: Date?
    let status: BXStatusVoucher
    let criadoEm: Date?

    private enum CodingKeys: String, CodingKey {
        case id, benefit_id, benefit_name, code, points_spent, expires_at, used_at, status, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        beneficioID = c.bxTexto(.benefit_id)
        nomeBeneficio = BXSanitizador.semSimbolos(c.bxTexto(.benefit_name) ?? "Benefício")
        codigo = c.bxTexto(.code) ?? ""
        pontosGastos = c.bxInt(.points_spent) ?? 0
        expiraEm = c.bxData(.expires_at)
        usadoEm = c.bxData(.used_at)
        let bruto = BXStatusVoucher(rawValue: c.bxTexto(.status) ?? "") ?? .desconhecido
        // Ativo com validade vencida aparece como expirado (o servidor só muda quando consultado).
        if bruto == .ativo, let e = expiraEm, e < .now { status = .expirado } else { status = bruto }
        criadoEm = c.bxData(.created_at)
    }
}

// MARK: - Notificações (/notifications/*)

nonisolated struct BXNotificacao: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    /// system, voucher, campaign, transfer, purchase, expiration, …
    let tipo: String
    let referencia: String?
    let lida: Bool
    let criadaEm: Date
    private let tituloServidor: String?
    private let corpoServidor: String?
    // `icon` NÃO é decodificado (glifos e emoji do servidor).

    private enum CodingKeys: String, CodingKey { case id, type, title, body, reference, is_read, read_at, created_at }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        tipo = (c.bxTexto(.type) ?? "system").lowercased()
        referencia = c.bxTexto(.reference)
        lida = c.bxBool(.is_read) ?? (c.bxData(.read_at) != nil)
        criadaEm = c.bxData(.created_at) ?? .distantPast
        tituloServidor = c.bxTexto(.title)
        corpoServidor = c.bxTexto(.body)
    }

    private init(copiaDe n: BXNotificacao, lida: Bool) {
        id = n.id; tipo = n.tipo; referencia = n.referencia; self.lida = lida; criadaEm = n.criadaEm
        tituloServidor = n.tituloServidor; corpoServidor = n.corpoServidor
    }
    /// Cópia marcada como lida (atualização otimista da lista).
    func marcadaComoLida() -> BXNotificacao { BXNotificacao(copiaDe: self, lida: true) }

    var icone: BXIconeNome { BXSanitizador.icone(tipoNotificacao: tipo) }
    var titulo: String {
        BXSanitizador.textoSeguro(tituloServidor).flatMap { BXSanitizador.textoCampanhaSeguro($0) }
            ?? BXSanitizador.tituloPadrao(tipoNotificacao: tipo)
    }
    /// Corpo só se passar no filtro (sem PIX, sem R$ de campanha). nil = a linha mostra só o título.
    var corpoSeguro: String? {
        BXSanitizador.textoSeguro(corpoServidor).flatMap { BXSanitizador.textoCampanhaSeguro($0) }
    }
}

/// `/notifications/` → `{ items, unread_count }`
nonisolated struct BXEnvelopeNotificacoes: Decodable, Sendable {
    let itens: [BXNotificacao]
    let naoLidas: Int
    private enum CodingKeys: String, CodingKey { case items, unread_count }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itens = (try? c.decode(BXListaTolerante<BXNotificacao>.self, forKey: .items))?.itens ?? []
        naoLidas = c.bxInt(.unread_count) ?? itens.filter { !$0.lida }.count
    }
}

// MARK: - Segurança (/user/*)

nonisolated struct BXSessaoDispositivo: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let nomeDispositivo: String
    let criadaEm: Date?
    let ultimoUso: Date?
    let atual: Bool
    private let ip: String?
    private let userAgent: String?

    private enum CodingKeys: String, CodingKey { case id, device_name, ip_address, user_agent, created_at, last_used_at, current }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        nomeDispositivo = BXSanitizador.semSimbolos(c.bxTexto(.device_name) ?? "Dispositivo")
        ip = c.bxTexto(.ip_address)
        userAgent = c.bxTexto(.user_agent)
        criadaEm = c.bxData(.created_at)
        ultimoUso = c.bxData(.last_used_at) ?? criadaEm
        atual = c.bxBool(.current) ?? false
    }
    var ipMascarado: String? { BXSanitizador.ipMascarado(ip) }
}

/// `/user/sessions` → `{ sessions: [...] }`
nonisolated struct BXEnvelopeSessoes: Decodable, Sendable {
    let sessoes: [BXSessaoDispositivo]
    private enum CodingKeys: String, CodingKey { case sessions }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessoes = (try? c.decode(BXListaTolerante<BXSessaoDispositivo>.self, forKey: .sessions))?.itens ?? []
    }
}

nonisolated struct BXEventoAcesso: Decodable, Sendable, Identifiable, Hashable {
    let evento: String
    let dispositivo: String?
    /// ok, warn, fail
    let status: String?
    let em: Date?
    private let ipServidor: String?
    var id: String { "\(evento)-\(em?.timeIntervalSince1970 ?? 0)-\(dispositivo ?? "")" }

    private enum CodingKeys: String, CodingKey { case event, ip, device, status, at }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        evento = c.bxTexto(.event) ?? ""
        ipServidor = c.bxTexto(.ip)
        dispositivo = c.bxTexto(.device).map { BXSanitizador.semSimbolos($0) }
        status = c.bxTexto(.status)
        em = c.bxData(.at)
    }
    var rotulo: String { BXSanitizador.rotulo(eventoAcesso: evento) }
    var ipMascarado: String? { BXSanitizador.ipMascarado(ipServidor) }
    var falhou: Bool { status == "fail" || status == "warn" || evento.hasSuffix("_fail") }
}

// MARK: - Privacidade (/privacy/consents)

nonisolated struct BXConsentimento: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    /// terms, privacy, lgpd, marketing, cookies_analytics, cookies_marketing
    let tipo: String
    let versao: String?
    let aceitoEm: Date?
    /// accepted, revoked, …
    let status: String
    private enum CodingKeys: String, CodingKey { case id, type, version, accepted_at, status }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.bxID(.id)
        tipo = c.bxTexto(.type) ?? ""
        versao = c.bxTexto(.version)
        aceitoEm = c.bxData(.accepted_at)
        status = c.bxTexto(.status) ?? ""
    }
    var rotuloTipo: String { BXSanitizador.rotulo(consentimento: tipo) }
    var ativo: Bool { status != "revoked" && status != "revocation" }
    /// Só marketing e cookies podem ser revogados pelo app (termos, privacidade e LGPD sustentam a conta).
    var revogavel: Bool { ["marketing", "cookies_analytics", "cookies_marketing"].contains(tipo) }
}

// MARK: - Login (resultado de POST /auth/login)

nonisolated enum BXRespostaLogin: Sendable {
    case ok(BXTokens, BXUsuario)
    /// 2FA por SMS: completar com `entrar2FA(desafio:codigo:)`.
    case mfaSMS(desafio: String, dica: String?)
    /// 2FA por aplicativo: repetir `entrar(login:senha:mfa:)` com o código.
    case mfaTOTP
}

// MARK: - Pedidos (corpo de POST). `description` nunca mostra senha.

nonisolated struct BXCadastro: Encodable, Sendable, CustomStringConvertible {
    var nome: String
    var email: String
    /// Só dígitos.
    var cpf: String
    var senha: String
    /// Opcional: "(11) 98765-4321" ou E.164.
    var celular: String?
    /// Opcional: "AAAA-MM-DD".
    var nascimento: String?

    init(nome: String, email: String, cpf: String, senha: String, celular: String? = nil, nascimento: String? = nil) {
        self.nome = nome; self.email = email; self.cpf = cpf; self.senha = senha
        self.celular = celular; self.nascimento = nascimento
    }

    private enum CodingKeys: String, CodingKey {
        case name, email, cpf, password, phone, birth_date, accept_terms, accept_privacy, accept_lgpd
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(nome.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .name)
        try c.encode(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), forKey: .email)
        try c.encode(cpf.filter(\.isNumber), forKey: .cpf)
        try c.encode(senha, forKey: .password)
        if let celular, !celular.isEmpty { try c.encode(celular, forKey: .phone) }
        if let nascimento, !nascimento.isEmpty { try c.encode(nascimento, forKey: .birth_date) }
        // Os três aceites são obrigatórios no backend: a tela só chama `cadastrar` depois do aceite explícito.
        try c.encode(true, forKey: .accept_terms)
        try c.encode(true, forKey: .accept_privacy)
        try c.encode(true, forKey: .accept_lgpd)
    }
    var description: String { "BXCadastro(email: \(email), senha: •••)" }
}

nonisolated struct BXPedidoEnvio: Encodable, Sendable, CustomStringConvertible {
    /// E-mail, CPF ou Cartão BlaXx (8 hex).
    var para: String
    var pontos: Int
    /// Digitada na hora; nunca guardada.
    var senha: String
    var mensagem: String?
    /// TOTP quando o servidor pede (envio ≥ 20.000 pts com 2FA ativo).
    var codigoMFA: String?

    init(para: String, pontos: Int, senha: String, mensagem: String? = nil, codigoMFA: String? = nil) {
        self.para = para; self.pontos = pontos; self.senha = senha; self.mensagem = mensagem; self.codigoMFA = codigoMFA
    }

    private enum CodingKeys: String, CodingKey { case to, amount_pts, password, message, mfa_code }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(para.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .to)
        try c.encode(pontos, forKey: .amount_pts)
        try c.encode(senha, forKey: .password)
        if let m = mensagem?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { try c.encode(m, forKey: .message) }
        if let codigoMFA, !codigoMFA.isEmpty { try c.encode(codigoMFA, forKey: .mfa_code) }
    }
    var description: String { "BXPedidoEnvio(para: \(para), pontos: \(pontos), senha: •••)" }
}

/// Compra por cartão (D02 desligado). Nunca leva número, CVV ou validade: só o token do Stripe.
nonisolated struct BXPedidoCartao: Encodable, Sendable {
    var pacote: String?
    var valor: Decimal?
    /// `pm_…` do Stripe.
    var tokenCartao: String
    var bandeira: String
    init(pacote: String? = nil, valor: Decimal? = nil, tokenCartao: String, bandeira: String) {
        self.pacote = pacote; self.valor = valor; self.tokenCartao = tokenCartao; self.bandeira = bandeira
    }
    private enum CodingKeys: String, CodingKey { case package, amount_brl, card_token, payment_method_id, installments, issuer_id }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let pacote { try c.encode(pacote, forKey: .package) }
        if let valor { try c.encode(NSDecimalNumber(decimal: valor).doubleValue, forKey: .amount_brl) }
        try c.encode(tokenCartao, forKey: .card_token)
        try c.encode(bandeira, forKey: .payment_method_id)
        try c.encode(1, forKey: .installments)
        try c.encode("", forKey: .issuer_id)
    }
}
