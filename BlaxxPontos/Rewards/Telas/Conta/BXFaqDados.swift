//
//  BXFaqDados.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Perguntas frequentes portadas de WEB/faq.html e WEB/central-ajuda.html, com as correções da spec (§5 G5.6):
//  - nada de "Quanto vale um ponto" nem de valor do ponto; a resposta sobre valor diz só que não é moeda;
//  - resgate nunca por transferência nem por meio de pagamento instantâneo (fica fora do app, D03);
//  - sem frase sobre cobrança por envio; sem acúmulo "consumindo na rede de parceiros" (o backend não tem);
//  - prazos e validades só como estão no regulamento publicado (WEB/regulamento.html v1.0, 01/08/2026),
//    com o link "Regulamento".
//

import Foundation

/// Temas da Central de ajuda (os 8 cartões de central-ajuda.html).
nonisolated enum BXTemaAjuda: String, CaseIterable, Identifiable, Hashable, Sendable {
    case acumulo, resgates, comprar, enviar, conta, seguranca, campanhas, termos

    var id: String { rawValue }

    /// Temas mostrados. "Comprar pontos" some quando a compra no app está desligada (`BXRecursos.compraNoApp`).
    static var visiveis: [BXTemaAjuda] { allCases.filter { $0 != .comprar || BXRecursos.compraNoApp } }

    var titulo: String {
        switch self {
        case .acumulo: return "Acúmulo de pontos"
        case .resgates: return "Resgates"
        case .comprar: return "Comprar pontos"
        case .enviar: return "Enviar pontos"
        case .conta: return "Conta e perfil"
        case .seguranca: return "Segurança"
        case .campanhas: return "Campanhas"
        case .termos: return "Termos e documentos"
        }
    }

    var icone: BXIconeNome {
        switch self {
        case .acumulo: return .estrela
        case .resgates: return .resgates
        case .comprar: return .comprar
        case .enviar: return .enviar
        case .conta: return .perfil
        case .seguranca: return .seguranca
        case .campanhas: return .campanhas
        case .termos: return .documento
        }
    }
}

/// Link dentro de uma resposta.
nonisolated enum BXLinkFaq: Hashable, Sendable {
    case destino(BXDestino, String)
    case site(String, String)
    case chamado

    var titulo: String {
        switch self {
        case .destino(_, let t), .site(_, let t): return t
        case .chamado: return "Abrir um chamado"
        }
    }
}

nonisolated struct BXPerguntaFaq: Identifiable, Hashable, Sendable {
    let id: String
    let tema: BXTemaAjuda
    let pergunta: String
    let resposta: String
    let links: [BXLinkFaq]
    /// Aparece em "Perguntas mais buscadas" da Central de ajuda.
    let destaque: Bool

    init(_ id: String, _ tema: BXTemaAjuda, _ pergunta: String, _ resposta: String,
         links: [BXLinkFaq] = [], destaque: Bool = false) {
        self.id = id
        self.tema = tema
        self.pergunta = pergunta
        self.resposta = resposta
        self.links = links
        self.destaque = destaque
    }

    /// Texto para a busca local (sem acento, minúsculo).
    var textoBusca: String { BXSanitizador.normalizar("\(pergunta) \(resposta) \(tema.titulo)") }
}

/// Seções da FAQ (como faq.html: "01 Sobre o programa", "02 Acúmulo", …).
nonisolated struct BXSecaoFaq: Identifiable, Hashable, Sendable {
    let id: String
    let numero: String
    let titulo: String
    let temas: [BXTemaAjuda]
}

nonisolated enum BXFaqDados {
    static let regulamento = BXLinkFaq.site("regulamento.html", "Regulamento")

    /// Seções mostradas (sem "Compra de pontos" quando a compra no app está desligada).
    static var secoes: [BXSecaoFaq] {
        BXRecursos.compraNoApp ? todasSecoes : todasSecoes.filter { !$0.temas.contains(.comprar) }
    }

    /// Perguntas mostradas: sem o tema Comprar e sem links para a compra quando ela está desligada no app.
    static var perguntas: [BXPerguntaFaq] {
        guard !BXRecursos.compraNoApp else { return todasPerguntas }
        return todasPerguntas.filter { $0.tema != .comprar }.map { p in
            let links = p.links.filter { if case .destino(let d, _) = $0 { return !d.ehCompra }; return true }
            return BXPerguntaFaq(p.id, p.tema, p.pergunta, respostasSemCompra[p.id] ?? p.resposta,
                                 links: links, destaque: p.destaque)
        }
    }

    /// Respostas que citam a tela Comprar pontos, reescritas para quando ela não existe no app.
    private static let respostasSemCompra: [String: String] = [
        "o-que-e": "Um programa de recompensas brasileiro. Você acumula pontos, envia para outras contas BlaXx e troca por benefícios. A rede de parceiros está em expansão.",
        "custo": "O cadastro e a conta são gratuitos e sem mensalidade.",
        "como-acumulo": "Participando de campanhas da BlaXx e recebendo pontos de outras contas BlaXx.",
    ]

    static let todasSecoes: [BXSecaoFaq] = [
        BXSecaoFaq(id: "programa", numero: "01", titulo: "Sobre o programa", temas: [.termos]),
        BXSecaoFaq(id: "acumulo", numero: "02", titulo: "Acúmulo", temas: [.acumulo, .campanhas]),
        BXSecaoFaq(id: "compra", numero: "03", titulo: "Compra de pontos", temas: [.comprar]),
        BXSecaoFaq(id: "envio", numero: "04", titulo: "Envio entre contas", temas: [.enviar]),
        BXSecaoFaq(id: "resgates", numero: "05", titulo: "Resgates", temas: [.resgates]),
        BXSecaoFaq(id: "conta", numero: "06", titulo: "Conta e segurança", temas: [.conta, .seguranca]),
    ]

    static let todasPerguntas: [BXPerguntaFaq] = [
        // 01 Sobre o programa
        BXPerguntaFaq("o-que-e", .termos, "O que é a BlaXx?",
                      "Um programa de recompensas brasileiro. Você compra pontos ou ganha em campanhas, envia para outras contas BlaXx e troca por benefícios em parceiros selecionados. A rede de parceiros está em expansão."),
        BXPerguntaFaq("valor-monetario", .termos, "Os pontos têm valor monetário?",
                      "Não. Os pontos BlaXx são créditos promocionais de uso restrito dentro do programa. Não são moeda, depósito, investimento, valor mobiliário ou criptoativo.",
                      links: [regulamento]),
        BXPerguntaFaq("custo", .termos, "Quanto custa participar?",
                      "O cadastro e a conta são gratuitos e sem mensalidade. Você só paga quando decide comprar pontos.",
                      links: [.destino(.comprar(), "Comprar pontos")]),

        // 02 Acúmulo
        BXPerguntaFaq("como-acumulo", .acumulo, "Como acumulo pontos?",
                      "De três formas: comprando pacotes ou um valor livre em Comprar pontos, participando de campanhas da BlaXx e recebendo pontos de outras contas BlaXx.",
                      links: [.destino(.comprar(), "Comprar pontos")]),
        BXPerguntaFaq("nao-creditados", .acumulo, "Meus pontos não foram creditados. O que fazer?",
                      "Pontos de compra entram depois da confirmação do pagamento. Quando o pagamento passa por análise antifraude, o crédito pode levar até 72 horas, como diz o regulamento. Confira o status no extrato; se o prazo passar, abra um chamado com o comprovante.",
                      links: [.destino(.extrato(), "Ver extrato"), .chamado], destaque: true),
        BXPerguntaFaq("validade", .acumulo, "Os pontos têm validade?",
                      "Sim. Pontos comprados valem 24 meses a partir do crédito e pontos bonificados (de campanhas) valem 12 meses. Você recebe um aviso por e-mail 30 dias antes. Os pontos mais antigos são usados primeiro.",
                      links: [regulamento], destaque: true),
        BXPerguntaFaq("campanhas", .campanhas, "Como funcionam as campanhas?",
                      "Campanhas são bonificações da BlaXx, sempre com regras próprias divulgadas na campanha: prazo, condição e quantidade de pontos. Pontos de campanha seguem a validade de pontos bonificados.",
                      links: [regulamento]),

        // 03 Compra de pontos
        BXPerguntaFaq("como-compro", .comprar, "Como compro pontos?",
                      "Em Comprar pontos, escolha um pacote ou um valor livre e conclua o pagamento pelo app do seu banco. Os pontos entram na conta depois da confirmação do pagamento.",
                      links: [.destino(.comprar(), "Comprar pontos")]),
        BXPerguntaFaq("compra-recusada", .comprar, "Por que minha compra de pontos foi recusada?",
                      "Recusas costumam acontecer por dados incorretos, limite ou bloqueio antifraude da instituição. Tente de novo mais tarde ou fale com o seu banco. Se o valor saiu da sua conta e os pontos não entraram, abra um chamado.",
                      links: [.chamado], destaque: true),
        BXPerguntaFaq("reembolso", .comprar, "Posso desistir de uma compra?",
                      "Compras feitas à distância têm direito de arrependimento em até 7 dias, conforme o artigo 49 do Código de Defesa do Consumidor. Para pedir, abra um chamado.",
                      links: [.chamado]),

        // 04 Envio
        BXPerguntaFaq("enviar-qualquer", .enviar, "Posso enviar pontos para qualquer pessoa?",
                      "Sim, desde que a pessoa tenha conta BlaXx. Informe o e-mail, o CPF ou o número do Cartão BlaXx dela em Enviar pontos.",
                      links: [.destino(.enviar(), "Enviar pontos")], destaque: true),
        BXPerguntaFaq("envio-limite", .enviar, "O envio tem limite?",
                      "Sim. O mínimo é de 100 pontos por envio e o limite diário é de 50.000 pontos. Pontos comprados só podem ser enviados 48 horas depois da compra.",
                      links: [regulamento]),
        BXPerguntaFaq("envio-desfazer", .enviar, "Posso desfazer um envio?",
                      "Sim, nos primeiros 60 segundos, pelo comprovante do envio ou pelo extrato. Depois disso o envio é definitivo. Confira sempre o destinatário antes de enviar."),

        // 05 Resgates
        BXPerguntaFaq("o-que-resgatar", .resgates, "O que posso resgatar?",
                      "Benefícios e experiências em parceiros selecionados, como vouchers, descontos e assinaturas, conforme a disponibilidade de cada parceiro. A rede de parceiros está em expansão.",
                      links: [.destino(.resgates(.catalogo), "Ver catálogo")]),
        BXPerguntaFaq("usar-voucher", .resgates, "Como uso meu voucher resgatado?",
                      "Abra o voucher em Meus resgates, copie o código e use no site, app ou loja do parceiro, seguindo as instruções do benefício.",
                      links: [.destino(.resgates(.meusResgates), "Meus resgates")], destaque: true),
        BXPerguntaFaq("resgate-email", .resgates, "Por que preciso confirmar o e-mail para resgatar?",
                      "A confirmação do e-mail protege a sua conta. Envios e resgates só ficam liberados depois que você confirma o código que enviamos para o seu e-mail."),

        // 06 Conta e segurança
        BXPerguntaFaq("ativar-2fa", .seguranca, "Como ativar a verificação em duas etapas?",
                      "Em Segurança, ative a verificação por aplicativo autenticador ou por SMS. Depois disso pedimos um código ao entrar e em operações sensíveis. Recomendamos fortemente.",
                      links: [.destino(.seguranca, "Abrir Segurança")], destaque: true),
        BXPerguntaFaq("alterar-dados", .conta, "Como altero meu nome ou e-mail?",
                      "Por segurança, nome, e-mail e CPF só são alterados pelo suporte. Abra um chamado na categoria Conta e acesso.",
                      links: [.chamado]),
        BXPerguntaFaq("dados-lgpd", .conta, "Como meus dados são tratados?",
                      "Conforme a LGPD (Lei 13.709/2018). Em Privacidade e dados você vê o que autorizou, pode revogar ofertas e novidades e exportar uma cópia dos seus dados.",
                      links: [.destino(.privacidade, "Privacidade e dados"), .site("privacidade.html", "Política de privacidade")]),
        BXPerguntaFaq("excluir-conta", .conta, "Como excluo minha conta?",
                      "Em Privacidade e dados, toque em Excluir minha conta. Seus dados pessoais são apagados e você perde o acesso à conta e ao saldo de pontos. O CPF e o histórico de movimentações ficam guardados pelo prazo que a lei exige.",
                      links: [.destino(.privacidade, "Privacidade e dados")]),
        BXPerguntaFaq("golpe", .seguranca, "Recebi um pedido de código. É da BlaXx?",
                      "Não. A BlaXx nunca pede código de verificação, senha ou confirmação por telefone, WhatsApp ou e-mail. Não compartilhe e abra um chamado na categoria Suspeita de fraude.",
                      links: [.chamado]),
    ]

    static var destaques: [BXPerguntaFaq] { perguntas.filter(\.destaque) }

    static func perguntas(tema: BXTemaAjuda) -> [BXPerguntaFaq] { perguntas.filter { $0.tema == tema } }

    static func perguntas(secao: BXSecaoFaq) -> [BXPerguntaFaq] {
        perguntas.filter { secao.temas.contains($0.tema) }
    }

    /// Busca sem acento por pergunta, resposta e tema (todas as palavras precisam aparecer).
    static func buscar(_ termo: String) -> [BXPerguntaFaq] {
        let palavras = BXSanitizador.normalizar(termo).split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !palavras.isEmpty else { return perguntas }
        return perguntas.filter { p in palavras.allSatisfy { p.textoBusca.contains($0) } }
    }
}

/// Pedidos entre telas do grupo (e da casca): abrir a FAQ num tema e abrir o chamado ao chegar na Ajuda.
/// A gaveta (G1) pode fazer `BXPedidosConta.abrirChamado = true; nav.ir(.ajuda)` para "Abrir chamado".
@MainActor enum BXPedidosConta {
    static var temaFaq: BXTemaAjuda?
    static var abrirChamado = false
}
