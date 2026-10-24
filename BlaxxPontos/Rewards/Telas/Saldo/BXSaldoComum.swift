//
//  BXSaldoComum.swift
//  BlaxxPontos · Redesenho "Embarque" · G2 (Saldo)
//
//  Peças compartilhadas pelas telas do grupo Saldo: a página rolável padrão (chão, coluna central de
//  560 pt, puxar para atualizar, âncora de demonstração, toque duplo na aba volta ao topo), a linha
//  de lançamento usada no Início e no Extrato e o texto do nível.
//  Regra do dono: nada de valor do ponto; quando a API falha aparece estado de erro, nunca número inventado.
//

import SwiftUI

/// Página rolável padrão do grupo. Sem `NavigationStack` (a casca já tem um por aba).
struct BXPaginaSaldo<Conteudo: View, Rodape: View>: View {
    let aba: BXAba?
    let atualizar: () async -> Void
    let conteudo: Conteudo
    let rodape: Rodape

    @Environment(BXNavegacao.self) private var nav

    init(aba: BXAba? = nil,
         atualizar: @escaping () async -> Void,
         @ViewBuilder conteudo: () -> Conteudo,
         @ViewBuilder rodape: () -> Rodape) {
        self.aba = aba
        self.atualizar = atualizar
        self.conteudo = conteudo()
        self.rodape = rodape()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 0).id("bx-topo")
                    VStack(alignment: .leading, spacing: 0) { conteudo }
                        .padding(.horizontal, BXEspaco.margem)
                        .padding(.top, 24)
                        .padding(.bottom, BXEspaco.secao)
                        .frame(maxWidth: BXEspaco.colunaMax)
                        .frame(maxWidth: .infinity)
                    rodape
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BXCor.chao, in: Rectangle())
            .refreshable { await atualizar() }
            .task {
                guard let ancora = BXDemo.ancora else { return }
                try? await Task.sleep(for: .milliseconds(900))
                proxy.scrollTo(ancora, anchor: .top)
            }
            .onChange(of: aba.map { nav.retoques[$0] ?? 0 } ?? 0) { _, _ in
                withAnimation(BXMovimento.ease) { proxy.scrollTo("bx-topo", anchor: .top) }
            }
        }
    }
}

extension BXPaginaSaldo where Rodape == EmptyView {
    init(aba: BXAba? = nil, atualizar: @escaping () async -> Void, @ViewBuilder conteudo: () -> Conteudo) {
        self.init(aba: aba, atualizar: atualizar, conteudo: conteudo, rodape: { EmptyView() })
    }
}

/// Linha de lançamento: ícone neon com seta, rótulo pelo tipo, hora/data, status quando não confirmado, ±pts.
struct BXLinhaLancamento: View {
    let lancamento: BXLancamento
    /// true no Início (mostra a data); false no Extrato (a data já está no cabeçalho do dia).
    var mostrarData = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            BXIcone(lancamento.ehEntrada ? .setaCima : .setaBaixo, tamanho: .atalho)
            VStack(alignment: .leading, spacing: 4) {
                Text(lancamento.rotulo)
                    .bxFonte(.item)
                    .foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(mostrarData ? BXFormato.dataHora(lancamento.criadoEm) : BXFormato.hora(lancamento.criadoEm))
                        .font(BXFonte.fonte(.recibo, tamanho: 12))
                        .foregroundStyle(BXCor.cinza)
                    if let s = BXLinhaLancamento.status(lancamento) {
                        BXStatus(s.texto, s.tipo, ponto: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 0) {
                Text(BXFormato.pontosSinal(lancamento.pontos))
                    .font(BXFonte.fonte(.recibo, tamanho: 16).weight(.bold))
                    .foregroundStyle(lancamento.ehEntrada ? BXCor.okTexto : BXCor.perigoTexto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("pts").font(BXFonte.fonte(.recibo, tamanho: 11)).foregroundStyle(BXCor.cinza)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BXLinhaLancamento.falado(lancamento, comData: mostrarData))
        .accessibilityHint("Abre o comprovante")
    }

    static func status(_ l: BXLancamento) -> (texto: String, tipo: BXStatus.Tipo)? {
        switch l.status {
        case .pendente: return ("Em processamento", .aviso)
        case .revertido: return ("Desfeito", .perigo)
        case .confirmado, .desconhecido: return nil
        }
    }

    static func rotuloStatus(_ l: BXLancamento) -> String {
        switch l.status {
        case .pendente: return "Em processamento"
        case .revertido: return "Desfeito"
        case .confirmado: return "Confirmado"
        case .desconhecido: return "—"
        }
    }

    static func falado(_ l: BXLancamento, comData: Bool) -> String {
        let sinal = l.ehEntrada ? "entrada de" : "saída de"
        let quando = comData ? BXFormato.dataHora(l.criadoEm) : BXFormato.hora(l.criadoEm)
        var s = "\(l.rotulo), \(sinal) \(BXFormato.pontosFalados(abs(l.pontos))), \(quando)"
        if let st = status(l) { s += ", \(st.texto)" }
        return s
    }
}

/// Textos do nível a partir de `/card/` (sem `perks`, sem cor da API).
enum BXTextoNivel {
    static func nome(_ c: BXCartaoEstado?) -> String { c?.nivel?.nome ?? "—" }

    /// "Faltam 25.200 pts para Black" · "Você está no nível mais alto." · nil sem cartão.
    static func faltam(_ c: BXCartaoEstado?) -> String? {
        guard let c else { return nil }
        guard let p = c.proximoNivel, c.faltam > 0 else { return "Você está no nível mais alto." }
        return "Faltam \(BXFormato.pontosComUnidade(c.faltam)) para \(p.nome)"
    }

    static func progresso(_ c: BXCartaoEstado?) -> String {
        guard let c else { return "—" }
        return "\(Int(c.progresso.rounded())) %"
    }
}

/// Texto colorido pela paleta local do nível: no Black o texto é neon (permitido, o fundo é tinta).
struct BXCorTextoNivel: ViewModifier {
    let chave: String
    func body(content: Content) -> some View {
        if chave.lowercased() == "black" {
            content.bxTextoNeon()
        } else {
            content.foregroundStyle(BXCor.nivel(chave).texto)
        }
    }
}
