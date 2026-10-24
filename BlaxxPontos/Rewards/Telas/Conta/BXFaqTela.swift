//
//  BXFaqTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Perguntas frequentes (WEB/faq.html): "PERGUNTAS FREQUENTES" / "Tira-dúvidas." · busca local sem acento ·
//  pílulas por tema · seções numeradas com perguntas que abrem e fecham. Conteúdo em `BXFaqDados`.
//  Pública (visitante também vê). Links de resposta que exigem conta levam a Entrar (BXNavegacao).
//

import SwiftUI

struct BXFaqTela: View {
    @Environment(BXNavegacao.self) private var nav

    @State private var busca = ""
    @State private var buscaAplicada = ""
    @State private var tema: BXTemaAjuda?
    @State private var abertas: Set<String> = []
    @State private var chamado = false
    @Namespace private var pilulas

    private var resultado: [BXPerguntaFaq] {
        var l = BXFaqDados.buscar(buscaAplicada)
        if let tema { l = l.filter { $0.tema == tema } }
        return l
    }

    var body: some View {
        BXPaginaConta(rodape: true) {
            BXCabecalhoPagina(eyebrow: "Perguntas frequentes", titulo: "Tira-dúvidas.",
                              lead: "As dúvidas mais comuns sobre a BlaXx. Se não encontrar o que precisa, abra um chamado.")
            BXCampoBusca(texto: $busca, placeholder: "Buscar dúvida")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    BXPilula("Todas", ativa: tema == nil, estilo: .conta, animacao: pilulas) { escolher(nil) }
                    ForEach(BXTemaAjuda.visiveis) { t in
                        BXPilula(t.titulo, ativa: tema == t, estilo: .conta, animacao: pilulas) { escolher(t) }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()

            if resultado.isEmpty {
                BXEstadoVazio(icone: .busca, titulo: "Nenhuma pergunta encontrada.",
                              texto: "Tente outras palavras ou abra um chamado.",
                              acao: (titulo: "Limpar busca", executar: { busca = ""; buscaAplicada = ""; escolher(nil) }))
            } else {
                ForEach(BXFaqDados.secoes) { secao in
                    let itens = resultado.filter { secao.temas.contains($0.tema) }
                    if !itens.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(secao.numero) · \(secao.titulo)").bxFonte(.rotuloSecao).foregroundStyle(BXCor.cinza)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(itens) { p in
                                BXPerguntaVista(pergunta: p, aberta: abertas.contains(p.id) || !buscaAplicada.isEmpty) {
                                    alternar(p.id)
                                } link: { abrir($0) }
                            }
                        }
                        .id(secao.id)
                        .padding(.top, 6)
                    }
                }
            }

            BXCartaoAbrirChamado { chamado = true }
                .padding(.top, 8)
        }
        .task(id: busca) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            withAnimation(BXMovimento.ease) { buscaAplicada = busca }
        }
        .sheet(isPresented: $chamado) { BXChamadoSheet().bxFolhaConta() }
        .onAppear {
            if let t = BXPedidosConta.temaFaq {
                tema = t
                BXPedidosConta.temaFaq = nil
            }
            if BXDemo.subtela == "aberta", let p = resultado.first { abertas.insert(p.id) }
        }
    }

    private func escolher(_ t: BXTemaAjuda?) {
        withAnimation(BXMovimento.mola) { tema = t }
        BXHaptica.tocar(.selecao)
    }

    private func alternar(_ id: String) {
        withAnimation(BXMovimento.ease) {
            if abertas.contains(id) { abertas.remove(id) } else { abertas.insert(id) }
        }
    }

    private func abrir(_ l: BXLinkFaq) {
        switch l {
        case .destino(let d, _): nav.ir(d)
        case .site(let caminho, _): nav.abrirSite(caminho)
        case .chamado: chamado = true
        }
    }
}

/// Pergunta que abre e fecha (estilo `details` do web: cartão branco, raio 14, "+" à direita).
struct BXPerguntaVista: View {
    let pergunta: BXPerguntaFaq
    let aberta: Bool
    let alternar: () -> Void
    let link: (BXLinkFaq) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduzido

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: alternar) {
                HStack(alignment: .top, spacing: 12) {
                    Text(pergunta.pergunta).bxFonte(.item).foregroundStyle(BXCor.tinta)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("+").font(BXFonte.fonte(.h2, tamanho: 22)).foregroundStyle(BXCor.tinta)
                        .rotationEffect(.degrees(aberta && !reduzido ? 45 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(BXEstiloPressao())
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(aberta ? "aberta" : "fechada")
            .accessibilityHint(aberta ? "Toque para fechar a resposta" : "Toque para ver a resposta")

            if aberta {
                VStack(alignment: .leading, spacing: 12) {
                    Text(pergunta.resposta).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                    if !pergunta.links.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(pergunta.links, id: \.self) { l in
                                BXLinkSeta(l.titulo) { link(l) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .bxSuperficie(raio: BXRaio.md, borda: BXCor.linha, sombra: .leve)
    }
}

/// Cartão neon "Abrir um chamado" (central-ajuda.html): fundo neon, texto tinta, "+" em quadrado.
struct BXCartaoAbrirChamado: View {
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            VStack(alignment: .leading, spacing: 12) {
                Text("+").font(BXFonte.fonte(.h2, tamanho: 26)).foregroundStyle(BXCor.tinta)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                Text("Abrir um chamado").bxFonte(.tituloBilhete).foregroundStyle(BXCor.tinta)
                Text("Não encontrou a resposta? Fale com nossa equipe. Resposta em até 1 dia útil.")
                    .bxFonte(.corpo).foregroundStyle(BXCor.tinta)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(BXCor.neon, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
        }
        .buttonStyle(BXEstiloPressao())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .id("chamado")
    }
}
