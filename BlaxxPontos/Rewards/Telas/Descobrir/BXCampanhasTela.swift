//
//  BXCampanhasTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G4 (Descobrir e resgatar)
//
//  Campanhas (`GET /campaigns/`, `POST /campaigns/<id>/join`), como `blaxx/campanhas.html` (fotos web 31),
//  mas o progresso é SÓ percentual: nada de "Meta R$ 2.142" (`target_brl`/`progress_brl`/`mechanic` nem são
//  decodificados). D04: em Release as campanhas de produção ficam escondidas (`BXRecursos.campanhas`); a tela
//  então mostra o vazio honesto, sem chamar a API.
//

import SwiftUI

struct BXCampanhasTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduzir

    @State private var carga: BXCarga<[BXCampanha]> = .carregando
    @State private var entrando: String?
    @State private var participou = 0
    @State private var falhou = 0

    var body: some View {
        ScrollView {
            BXColunaDescobrir {
                BXCabecalhoPagina(eyebrow: "Campanhas", titulo: "Metas que valem pontos.",
                                  lead: "Participe das campanhas ativas e receba pontos extras ao cumprir as metas.")
                    .padding(.bottom, 24)
                switch carga {
                case .ocioso, .carregando:
                    VStack(spacing: 12) { ForEach(0..<3, id: \.self) { _ in BXEsqueleto(.bilhete) } }
                case .erro(let e):
                    BXEstadoErro(e) { await carregar() }
                case .vazio:
                    BXEstadoVazio(icone: .campanhas, titulo: "Nenhuma campanha ativa no momento.",
                                  texto: "Quando uma campanha começar, ela aparece aqui.",
                                  acao: (titulo: "Ver parceiros", executar: { nav.ir(.parceiros()) }))
                case .pronto(let lista):
                    LazyVStack(spacing: 12) {
                        ForEach(lista) { c in bilhete(c) }
                    }
                }
            }
        }
        .background(BXCor.chao, in: Rectangle())
        .refreshable { await carregar() }
        .task { if carga.valor == nil { await carregar() } }
        .sensoryFeedback(.success, trigger: participou)
        .sensoryFeedback(.error, trigger: falhou)
    }

    private func bilhete(_ c: BXCampanha) -> some View {
        let pct = Int(c.progresso.rounded())
        return BXBilhete(canhoto: .icone(c.concluida ? .visto : .campanhas)) {
            HStack(alignment: .firstTextBaseline) {
                Text("BX · Campanha")
                Spacer(minLength: 8)
                Text(prazo(c))
            }
            .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            Text(c.nomeSeguro).bxFonte(.tituloBilhete)
                .fixedSize(horizontal: false, vertical: true)
            if let d = c.descricaoSegura {
                Text(d).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
            BXChip("+\(BXFormato.pontos(c.pontosRecompensa)) pts", .neon)
            if c.participando || c.concluida {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Progresso").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                        Spacer()
                        Text("\(pct)%").bxFonte(.rotulo).foregroundStyle(BXCor.tinta)
                            .contentTransition(.numericText(value: Double(pct)))
                    }
                    BXProgresso(fracao: c.progresso / 100, altura: 10)
                        .animation(BXMovimento.ou(BXMovimento.ease, reduzido: reduzir), value: c.progresso)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Progresso, \(pct) por cento")
            }
            acao(c).padding(.top, 4)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func acao(_ c: BXCampanha) -> some View {
        if c.concluida {
            BXStatus("Concluída", .ok)
        } else if c.participando {
            BXChip("Em andamento", .preto)
                .transition(.scale.combined(with: .opacity))
        } else {
            BXBotao("Participar →", carregando: entrando == c.id, larguraTotal: false) {
                Task { await participar(c) }
            }
            .disabled(entrando != nil)
        }
    }

    private func prazo(_ c: BXCampanha) -> String {
        if c.concluida { return "Encerrada para você" }
        guard let d = c.diasRestantes() else { return "Sem data de fim" }
        return d == 0 ? "Último dia" : "Faltam \(d) \(d == 1 ? "dia" : "dias")"
    }

    private func participar(_ c: BXCampanha) async {
        guard sessao.logado else { nav.pedirEntrada(depois: .campanhas); return }
        entrando = c.id
        defer { entrando = nil }
        do {
            try await BXAPI.shared.participar(campanha: c.id)
            participou += 1
            toast.mostrar("Você entrou na campanha.")
            if var lista = carga.valor, let i = lista.firstIndex(where: { $0.id == c.id }) {
                let antiga = lista[i]
                withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzir)) {
                    lista[i] = BXCampanha(id: antiga.id, nome: antiga.nome, descricao: antiga.descricao,
                                          pontosRecompensa: antiga.pontosRecompensa, inicio: antiga.inicio, fim: antiga.fim,
                                          participando: true, progresso: antiga.progresso, concluidaEm: antiga.concluidaEm)
                    carga = .pronto(lista)
                }
            }
            await carregar()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            if e.tipo == .emailNaoVerificado { nav.exigirVerificacaoEmail(); return }
            if e.tipo == .sessaoExpirada { return }
            falhou += 1
            toast.mostrar(e.mensagemParaUsuario, .erro)
        }
    }

    private func carregar() async {
        guard BXRecursos.campanhas else { carga = .vazio; return }
        do {
            let l = try await BXAPI.shared.campanhas()
            carga = l.isEmpty ? .vazio : .pronto(l)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if carga.valor != nil { return }
            carga = .erro(BXErro.de(error))
        }
    }
}
