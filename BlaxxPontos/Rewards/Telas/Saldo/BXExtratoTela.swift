//
//  BXExtratoTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G2 (Saldo)
//
//  Extrato (extrato.html, fotos 12): "EXTRATO" / "Cada ponto, rastreado." · Entradas e Saídas somadas dos
//  lançamentos carregados (rótulo honesto: "no período") e Saldo atual · abas Tudo/Entradas/Saídas ·
//  busca com espera · seções por dia com cabeçalho fixo · linha → comprovante (sheet) · rodapé
//  "Mostrando os últimos 100 movimentos." (o backend não pagina).
//  Rótulo pelo TIPO (nunca a descrição crua do servidor: descrição com meio de pagamento, "Envio (pending)").
//

import SwiftUI

struct BXExtratoTela: View {
    let filtroInicial: BXFiltroExtrato

    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(\.dynamicTypeSize) private var dts

    @State private var carga: BXCarga<[BXLancamento]> = .carregando
    @State private var filtro: BXFiltroExtrato
    @State private var busca = ""
    @State private var buscaAplicada = ""
    @State private var detalhe: BXLancamento?
    @State private var carregou = false

    init(filtroInicial: BXFiltroExtrato = .tudo) {
        self.filtroInicial = filtroInicial
        _filtro = State(initialValue: filtroInicial)
    }

    var body: some View {
        BXPaginaSaldo(atualizar: { await carregar(saldo: true) }) {
            BXCabecalhoPagina(eyebrow: "Extrato", titulo: "Cada ponto, rastreado.")
            numeros.padding(.top, 20)
            BXAbas(selecao: $filtro, opcoes: [(.tudo, "Tudo"), (.entradas, "Entradas"), (.saidas, "Saídas")])
                .padding(.top, 20)
            BXCampoBusca(texto: $busca, placeholder: "Buscar movimento")
                .padding(.top, 12)
            lista.padding(.top, 18).id("lista")
        } rodape: {
            BXRodapeRecibo()
        }
        .bxSheetLancamento($detalhe) { await carregar(saldo: false) }
        .task(id: busca) {
            if busca.isEmpty { buscaAplicada = ""; return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            buscaAplicada = busca
        }
        .task {
            guard !carregou else { return }
            carregou = true
            await carregar(saldo: sessao.carteira == nil)
            #if DEBUG
            if BXDemo.subtela == "lancamento", let itens = carga.valor {
                detalhe = itens.first(where: { $0.envioDesfazivel() }) ?? itens.sorted { $0.criadoEm > $1.criadoEm }.first
            }
            #endif
        }
    }

    private func carregar(saldo: Bool) async {
        async let s: Void = saldo ? sessao.recarregarCarteira() : ()
        async let l: Void = carregarLista()
        _ = await (s, l)
    }

    private func carregarLista() async {
        do {
            let itens = try await BXAPI.shared.lancamentos(limite: 100)
            carga = itens.isEmpty ? .vazio : .pronto(itens)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            carga = .erro(BXErro.de(error))
        }
    }

    // MARK: números

    private var numeros: some View {
        let itens = carga.valor ?? []
        let entradas = itens.filter { $0.pontos > 0 && $0.status != .revertido }.reduce(0) { $0 + $1.pontos }
        let saidas = itens.filter { $0.pontos < 0 && $0.status != .revertido }.reduce(0) { $0 + $1.pontos }
        let temDados = carga.valor != nil
        let l = dts.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: BXEspaco.grade)) : AnyLayout(HStackLayout(spacing: BXEspaco.grade))
        return VStack(spacing: BXEspaco.grade) {
            l {
                cartaoNumero("Entradas no período", temDados ? BXFormato.pontosSinal(entradas) : "—", cor: BXCor.okTexto)
                cartaoNumero("Saídas no período", temDados ? BXFormato.pontosSinal(saidas) : "—", cor: BXCor.perigoTexto)
            }
            VStack(alignment: .leading, spacing: 10) {
                BXRotulo("Saldo atual")
                BXNumeroAnimado(sessao.carteira?.saldo, estilo: .saldoMono, sufixo: "pts",
                                contarNaEntrada: false, corSufixo: BXCor.cinza)
                    .foregroundStyle(BXCor.tinta)
            }
            .padding(BXEspaco.cartao)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
            .accessibilityElement(children: .combine)
        }
    }

    private func cartaoNumero(_ rotulo: String, _ valor: String, cor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BXRotulo(rotulo)
            Text(valor)
                .font(BXFonte.fonte(.saldoMono, tamanho: 22))
                .foregroundStyle(cor)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(BXEspaco.cartao)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rotulo), \(valor) pontos")
    }

    // MARK: lista

    private func filtrar(_ itens: [BXLancamento]) -> [BXLancamento] {
        let q = BXSanitizador.normalizar(buscaAplicada.trimmingCharacters(in: .whitespaces))
        return itens.filter { l in
            switch filtro {
            case .tudo: break
            case .entradas: if l.pontos <= 0 { return false }
            case .saidas: if l.pontos >= 0 { return false }
            }
            guard !q.isEmpty else { return true }
            let alvo = BXSanitizador.normalizar("\(l.rotulo) \(l.detalhe ?? "") \(l.referencia ?? "") \(BXFormato.pontos(abs(l.pontos))) \(BXFormato.dia(l.criadoEm))")
            return alvo.contains(q)
        }
    }

    @ViewBuilder private var lista: some View {
        BXConteudo(carga,
                   vazio: BXEstadoVazio(icone: .extrato, titulo: "Nenhum movimento ainda.",
                                        texto: BXRecursos.compraNoApp
                                            ? "Quando você comprar, enviar, receber ou resgatar, aparece aqui."
                                            : "Quando você enviar, receber ou resgatar, aparece aqui.",
                                        acao: BXRecursos.compraNoApp
                                            ? (titulo: "Comprar pontos", executar: { nav.ir(.comprar()) })
                                            : (titulo: "Receber pontos", executar: { nav.ir(.receber) })),
                   tentarDeNovo: { await carregarLista() }) {
            VStack(spacing: 0) { ForEach(0..<6, id: \.self) { _ in BXEsqueleto(.linhaExtrato) } }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
        } pronto: { itens in
            let filtrados = filtrar(itens)
            if filtrados.isEmpty {
                if !buscaAplicada.isEmpty {
                    BXEstadoVazio(icone: .busca, titulo: "Nenhum movimento encontrado.",
                                  texto: "Nada com \"\(buscaAplicada)\".",
                                  acao: (titulo: "Limpar busca", executar: { busca = "" }))
                } else {
                    BXEstadoVazio(icone: .extrato,
                                  titulo: filtro == .entradas ? "Nenhuma entrada ainda." : "Nenhuma saída ainda.")
                }
            } else {
                grupos(filtrados, total: itens.count)
            }
        }
    }

    private func grupos(_ itens: [BXLancamento], total: Int) -> some View {
        let dias = BXFormato.agruparPorDia(itens, data: \.criadoEm)
        return LazyVStack(alignment: .leading, spacing: 14, pinnedViews: .sectionHeaders) {
            ForEach(dias, id: \.rotulo) { dia in
                Section {
                    VStack(spacing: 0) {
                        ForEach(Array(dia.itens.enumerated()), id: \.element.id) { i, l in
                            Button { detalhe = l } label: { BXLinhaLancamento(lancamento: l) }
                                .buttonStyle(BXEstiloPressao())
                                .contextMenu {
                                    if let r = l.referencia {
                                        Button("Copiar comprovante") { BXCopiaSilenciosa.copiar(r) }
                                    }
                                }
                            if i < dia.itens.count - 1 {
                                Rectangle().fill(BXCor.linha).frame(height: 1).padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
                } header: {
                    Text(dia.rotulo)
                        .bxFonte(.rotuloMedio)
                        .foregroundStyle(BXCor.tinta)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BXCor.chao, in: Rectangle())
                        .accessibilityAddTraits(.isHeader)
                }
            }
            if total >= 100 {
                Text("Mostrando os últimos 100 movimentos.")
                    .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
    }
}
