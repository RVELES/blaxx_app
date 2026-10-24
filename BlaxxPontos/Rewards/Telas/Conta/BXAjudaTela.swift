//
//  BXAjudaTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Central de ajuda (WEB/central-ajuda.html, fotos 36): farelo "INÍCIO / CENTRAL DE AJUDA", título
//  "Como podemos / te ajudar?" com a segunda linha marcada em neon, busca local (que funciona, ao
//  contrário do web), 8 temas em grade 2 × 2 (1 coluna em tamanhos de acessibilidade), "Perguntas mais
//  buscadas", cartão neon "Abrir um chamado" e o rodapé-recibo. "Meus chamados" do web fica fora:
//  não há chamados no backend (o chamado sai por e-mail).
//

import SwiftUI

struct BXAjudaTela: View {
    @Environment(BXNavegacao.self) private var nav
    @Environment(\.dynamicTypeSize) private var tipo

    @State private var busca = ""
    @State private var buscaAplicada = ""
    @State private var abertas: Set<String> = []
    @State private var chamado = false

    private var colunas: [GridItem] {
        tipo.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        BXPaginaConta(rodape: true) {
            cabecalho
            BXCampoBusca(texto: $busca, placeholder: "Ex: usar voucher, alterar senha")
                .padding(.top, 8)

            if buscaAplicada.trimmingCharacters(in: .whitespaces).isEmpty {
                LazyVGrid(columns: colunas, spacing: 12) {
                    ForEach(BXTemaAjuda.visiveis) { t in
                        cartaoTema(t)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Perguntas mais buscadas").bxFonte(.h2).foregroundStyle(BXCor.tinta)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 12)
                    ForEach(BXFaqDados.destaques) { p in
                        BXPerguntaVista(pergunta: p, aberta: abertas.contains(p.id)) { alternar(p.id) } link: { abrir($0) }
                    }
                    BXLinkSeta("Ver todas as perguntas") { nav.ir(.faq) }
                        .padding(.top, 4)
                }
                .id("perguntas")
            } else {
                resultadosBusca
            }

            BXCartaoAbrirChamado { chamado = true }
                .padding(.top, 12)
        }
        .task(id: busca) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            withAnimation(BXMovimento.ease) { buscaAplicada = busca }
        }
        .sheet(isPresented: $chamado) { BXChamadoSheet().bxFolhaConta() }
        .onAppear {
            if BXPedidosConta.abrirChamado || BXDemo.subtela == "chamado" || BXDemo.subtela == "chamado-preenchido" {
                BXPedidosConta.abrirChamado = false
                chamado = true
            }
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Início  /  Central de ajuda").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Como podemos").bxFonte(.tituloPagina).foregroundStyle(BXCor.tinta)
                Text("te ajudar?").bxFonte(.tituloPagina).foregroundStyle(BXCor.tinta)
                    .padding(.horizontal, 4)
                    .background(BXCor.neon, in: Rectangle())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Como podemos te ajudar?")
            .accessibilityAddTraits(.isHeader)
            Text("Pesquise por dúvida ou navegue pelos temas.")
                .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cartaoTema(_ t: BXTemaAjuda) -> some View {
        let pagina = destinoPagina(t)
        return BXCartaoClaro(icone: t.icone, titulo: t.titulo,
                             texto: pagina == nil ? "Ver perguntas frequentes" : "Ver página") {
            BXHaptica.tocar(.selecao)
            if let pagina {
                pagina()
            } else {
                BXPedidosConta.temaFaq = t
                nav.ir(.faq)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Temas que, como no web, abrem a página da funcionalidade em vez da FAQ.
    private func destinoPagina(_ t: BXTemaAjuda) -> (() -> Void)? {
        switch t {
        case .comprar: return { nav.ir(.comprar()) }
        case .campanhas where BXRecursos.campanhas: return { nav.ir(.campanhas) }
        case .termos: return { nav.abrirSite("documentos-termos.html") }
        default: return nil
        }
    }

    @ViewBuilder private var resultadosBusca: some View {
        let r = BXFaqDados.buscar(buscaAplicada)
        VStack(alignment: .leading, spacing: 12) {
            Text(r.isEmpty ? "Nenhum resultado" : "\(r.count) \(r.count == 1 ? "resultado" : "resultados")")
                .bxFonte(.rotuloSecao).foregroundStyle(BXCor.cinza)
            if r.isEmpty {
                BXEstadoVazio(icone: .busca, titulo: "Nenhuma pergunta encontrada.",
                              texto: "Tente outras palavras ou abra um chamado.",
                              acao: (titulo: "Limpar busca", executar: { busca = ""; buscaAplicada = "" }))
            } else {
                ForEach(r) { p in
                    BXPerguntaVista(pergunta: p, aberta: true) {} link: { abrir($0) }
                }
            }
        }
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
