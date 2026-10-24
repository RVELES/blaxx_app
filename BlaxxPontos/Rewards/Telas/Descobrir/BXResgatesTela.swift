//
//  BXResgatesTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G4 (Descobrir e resgatar)
//
//  Resgates (raiz da aba), como `blaxx/resgates.html` + `meus-resgates.html` (fotos web 15 e 19):
//  "RESGATES" / "Troque por benefícios e experiências." + saldo em chip preto, abas Catálogo · Meus resgates.
//  Catálogo: pílulas com o rótulo ACENTUADO da categoria (nunca "educacao" cru), bilhetes com o ícone da
//  categoria, custo, "Você pode resgatar" ou "Faltam N pts" + trilho, "ESGOTADO".
//  Meus resgates: filtros Todos/Ativos/Usados/Expirados, voucher com status, código + Copiar e validade.
//  Nada do conteúdo fixo de demonstração do web (Netflix, Starbucks…); tudo vem de /benefits/ e /vouchers/.
//

import SwiftUI

struct BXResgatesTela: View {
    let abaInicial: BXAbaResgates

    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduzir

    @State private var aba: BXAbaResgates
    @State private var catalogo: BXCarga<[BXBeneficio]> = .carregando
    @State private var vouchers: BXCarga<[BXVoucher]> = .ocioso
    @State private var categoria = ""
    @State private var filtroVoucher: FiltroVoucher = .todos
    @Namespace private var zoom
    @Namespace private var pilulasCat
    @Namespace private var pilulasVoucher

    enum FiltroVoucher: Hashable { case todos, ativos, usados, expirados }

    init(aba: BXAbaResgates) {
        self.abaInicial = aba
        _aba = State(initialValue: aba)
    }

    var body: some View {
        ScrollView {
            BXColunaDescobrir {
                cabecalho.padding(.bottom, 24)
                BXAbas(selecao: vinculoAba, opcoes: [(.catalogo, "Catálogo"), (.meusResgates, "Meus resgates")], ativo: .neon)
                    .padding(.bottom, 20)
                switch aba {
                case .catalogo: abaCatalogo
                case .meusResgates: abaMeusResgates
                }
            }
        }
        .background(BXCor.chao, in: Rectangle())
        .refreshable { await recarregar() }
        .task { await carregarCatalogo() }
        .task(id: aba) { if aba == .meusResgates, vouchers.valor == nil { await carregarVouchers() } }
        .onAppear { BXZoomDescobrir.ns = zoom }
    }

    /// Visitante tocando em "Meus resgates" → Entrar e volta para a aba.
    private var vinculoAba: Binding<BXAbaResgates> {
        Binding(get: { aba }, set: { nova in
            if nova == .meusResgates && !sessao.logado {
                nav.pedirEntrada(depois: .resgates(.meusResgates))
                return
            }
            withAnimation(BXMovimento.ou(BXMovimento.ease, reduzido: reduzir)) { aba = nova }
        })
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 18) {
            BXCabecalhoPagina(eyebrow: "Resgates", titulo: "Troque por benefícios e experiências.")
            if sessao.logado {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Seus pontos").bxFonte(.rotulo).foregroundStyle(BXCor.tintaApagada)
                    if let s = sessao.carteira?.saldo {
                        BXNumeroAnimado(s, estilo: .saldoMono, sufixo: "pts", contarNaEntrada: false)
                            .bxTextoNeon()
                    } else {
                        Text("—").bxFonte(.saldoMono).bxTextoNeon()
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(sessao.carteira.map { "Seus pontos, \(BXFormato.pontosFalados($0.saldo))" } ?? "Seus pontos, indisponível")
            }
        }
    }

    // MARK: - Catálogo

    private var beneficios: [BXBeneficio] { catalogo.valor ?? [] }

    private var categorias: [(chave: String, rotulo: String)] {
        var vistas: [String] = []
        for b in beneficios where !vistas.contains(b.categoria) { vistas.append(b.categoria) }
        return vistas.map { ($0, BXSanitizador.rotulo(categoriaBeneficio: $0)) }
            .sorted { $0.rotulo.localizedStandardCompare($1.rotulo) == .orderedAscending }
    }

    @ViewBuilder private var abaCatalogo: some View {
        switch catalogo {
        case .ocioso, .carregando:
            VStack(spacing: 12) { ForEach(0..<4, id: \.self) { _ in BXEsqueleto(.bilhete) } }
        case .erro(let e):
            BXEstadoErro(e) { await carregarCatalogo() }
        case .vazio:
            BXEstadoVazio(icone: .resgates, titulo: "Nenhum benefício disponível agora.",
                          texto: "Os benefícios entram conforme a disponibilidade dos parceiros selecionados.",
                          acao: (titulo: "Ver parceiros", executar: { nav.ir(.parceiros()) }))
        case .pronto:
            VStack(alignment: .leading, spacing: 16) {
                BXFluxoDescobrir(espaco: 8, espacoLinha: 8) {
                    BXPilula("Todos", ativa: categoria.isEmpty, estilo: .conta, animacao: pilulasCat) { escolherCategoria("") }
                    ForEach(categorias, id: \.chave) { c in
                        BXPilula(c.rotulo, ativa: categoria == c.chave, estilo: .conta, animacao: pilulasCat) {
                            escolherCategoria(c.chave)
                        }
                    }
                }
                .padding(.bottom, 4)
                let lista = categoria.isEmpty ? beneficios : beneficios.filter { $0.categoria == categoria }
                LazyVStack(spacing: 12) {
                    ForEach(lista) { b in bilheteCatalogo(b) }
                }
            }
        }
    }

    private func escolherCategoria(_ c: String) {
        withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzir)) { categoria = c }
    }

    private func bilheteCatalogo(_ b: BXBeneficio) -> some View {
        let saldo = sessao.carteira?.saldo
        let faltam = saldo.map { b.faltam(saldo: $0) }
        return BXBilhete(canhoto: .icone(b.icone), acao: { nav.ir(.beneficio(id: b.id)) }) {
            HStack(alignment: .firstTextBaseline) {
                Text("BX · \(b.rotuloCategoria)")
                Spacer(minLength: 8)
                Text(b.daBlaxx ? "BlaXx" : (b.nomeParceiro ?? "")).lineLimit(1)
            }
            .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            Text(b.nome).bxFonte(.tituloBilhete)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(BXFormato.pontos(b.custo)).bxFonte(.pontosBilhete)
                Text("pts").bxFonte(.sufixoPontos).foregroundStyle(BXCor.cinza)
                Spacer(minLength: 0)
                if b.esgotado { BXStatus("Esgotado", .perigo) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            if !b.esgotado, let faltam, let saldo {
                if faltam == 0 {
                    BXStatus("Você pode resgatar", .ok)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Faltam \(BXFormato.pontos(faltam)) pts").bxFonte(.monoForte).foregroundStyle(BXCor.perigoTexto)
                        BXProgresso(fracao: b.custo > 0 ? min(1, Double(saldo) / Double(b.custo)) : 0, altura: 8)
                    }
                }
            }
        }
        .matchedTransitionSource(id: "beneficio-\(b.id)", in: zoom)
        .accessibilityLabel(rotuloAcessivel(b, faltam: faltam))
        .accessibilityHint("Abre o benefício")
    }

    private func rotuloAcessivel(_ b: BXBeneficio, faltam: Int?) -> String {
        var t = "\(b.rotuloCategoria). \(b.nome). \(BXFormato.pontosFalados(b.custo))"
        if b.esgotado { t += ". Esgotado" }
        else if let f = faltam { t += f == 0 ? ". Você pode resgatar" : ". Faltam \(BXFormato.pontosFalados(f))" }
        return t
    }

    // MARK: - Meus resgates

    private func passa(_ v: BXVoucher) -> Bool {
        switch filtroVoucher {
        case .todos: return true
        case .ativos: return v.status == .ativo
        case .usados: return v.status == .usado
        case .expirados: return v.status == .expirado
        }
    }

    @ViewBuilder private var abaMeusResgates: some View {
        switch vouchers {
        case .ocioso, .carregando:
            VStack(spacing: 12) { ForEach(0..<3, id: \.self) { _ in BXEsqueleto(.bilhete) } }
        case .erro(let e):
            BXEstadoErro(e) { await carregarVouchers() }
        case .vazio:
            vazioVouchers
        case .pronto(let lista):
            VStack(alignment: .leading, spacing: 16) {
                BXFluxoDescobrir(espaco: 8, espacoLinha: 8) {
                    pilulaVoucher("Todos", .todos, lista.count)
                    pilulaVoucher("Ativos", .ativos, lista.filter { $0.status == .ativo }.count)
                    pilulaVoucher("Usados", .usados, lista.filter { $0.status == .usado }.count)
                    pilulaVoucher("Expirados", .expirados, lista.filter { $0.status == .expirado }.count)
                }
                .padding(.bottom, 4)
                let filtrados = lista.filter(passa)
                if filtrados.isEmpty {
                    BXEstadoVazio(icone: .voucher, titulo: "Nenhum resgate neste filtro.",
                                  acao: (titulo: "Ver todos", executar: { filtroVoucher = .todos }))
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filtrados) { v in BXCartaoVoucher(voucher: v, zoom: zoom) { nav.ir(.voucher(id: v.id)) } }
                    }
                }
            }
        }
    }

    private func pilulaVoucher(_ t: String, _ f: FiltroVoucher, _ n: Int) -> some View {
        BXPilula(t, contador: n, ativa: filtroVoucher == f, estilo: .conta, animacao: pilulasVoucher) {
            withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzir)) { filtroVoucher = f }
        }
    }

    private var vazioVouchers: some View {
        BXEstadoVazio(icone: .voucher, titulo: "Você ainda não tem resgates.",
                      texto: "Os vouchers dos benefícios que você resgatar aparecem aqui.",
                      acao: (titulo: "Ver catálogo", executar: {
                          withAnimation(BXMovimento.ou(BXMovimento.ease, reduzido: reduzir)) { aba = .catalogo }
                      }))
    }

    // MARK: - Carga

    private func recarregar() async {
        await sessao.recarregarCarteira()
        if aba == .catalogo { await carregarCatalogo() } else { await carregarVouchers() }
    }

    private func carregarCatalogo() async {
        if catalogo.valor == nil { catalogo = .carregando }
        do {
            let l = try await BXAPI.shared.beneficios()
            catalogo = l.isEmpty ? .vazio : .pronto(l)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if catalogo.valor != nil { return }
            catalogo = .erro(BXErro.de(error))
        }
    }

    private func carregarVouchers() async {
        guard sessao.logado else { return }
        if vouchers.valor == nil { vouchers = .carregando }
        do {
            let l = try await BXAPI.shared.vouchers()
            vouchers = l.isEmpty ? .vazio : .pronto(l)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if vouchers.valor != nil { return }
            vouchers = .erro(BXErro.de(error))
        }
    }
}

// MARK: - Cartão de voucher (Meus resgates)

struct BXCartaoVoucher: View {
    let voucher: BXVoucher
    let zoom: Namespace.ID
    let abrir: () -> Void
    @Environment(BXToastCentral.self) private var toast

    var body: some View {
        let v = voucher
        BXBilhete(canhoto: .icone(.voucher), acao: abrir) {
            HStack(alignment: .center) {
                BXStatusVoucherVista(status: v.status)
                Spacer(minLength: 8)
                if let c = v.criadoEm { Text(BXFormato.data(c)).bxFonte(.rotulo).foregroundStyle(BXCor.cinza) }
            }
            Text(v.nomeBeneficio).bxFonte(.tituloBilhete)
                .fixedSize(horizontal: false, vertical: true)
            if !v.codigo.isEmpty {
                HStack(spacing: 10) {
                    Text(v.codigo).font(BXFonte.fonte(.recibo, tamanho: 15)).fontWeight(.bold)
                        .foregroundStyle(BXCor.tinta)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                    if v.status == .ativo {
                        Button {
                            BXCopiar.copiar(v.codigo, aviso: "Código copiado.", toast: toast)
                        } label: {
                            Text("Copiar").bxFonte(.botao).foregroundStyle(BXCor.tinta)
                                .padding(.horizontal, 14).frame(minHeight: 36)
                                .background(BXCor.superficie, in: RoundedRectangle(cornerRadius: BXRaio.xs, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: BXRaio.xs, style: .continuous).strokeBorder(BXCor.linha, lineWidth: 1))
                        }
                        .buttonStyle(BXEstiloPressao())
                        .accessibilityLabel("Copiar código")
                    }
                }
                .padding(12)
                .background(BXCor.superficie2, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
            }
            Text(linhaRodape).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
        }
        .matchedTransitionSource(id: "voucher-\(v.id)", in: zoom)
        .contextMenu {
            if !v.codigo.isEmpty {
                Button("Copiar código") { BXCopiar.copiar(v.codigo, aviso: "Código copiado.", toast: toast) }
            }
        }
        .accessibilityLabel("\(v.nomeBeneficio). \(BXStatusVoucherVista.texto(v.status)). \(linhaRodape)")
        .accessibilityAction(named: "Copiar código") { BXCopiar.copiar(v.codigo, aviso: "Código copiado.", toast: toast) }
        .accessibilityHint("Abre o voucher")
    }

    private var linhaRodape: String {
        let pts = "\(BXFormato.pontos(voucher.pontosGastos)) pts"
        switch voucher.status {
        case .usado:
            return voucher.usadoEm.map { "\(pts) · usado em \(BXFormato.data($0))" } ?? "\(pts) · usado"
        case .expirado:
            return voucher.expiraEm.map { "\(pts) · venceu em \(BXFormato.data($0))" } ?? "\(pts) · expirado"
        default:
            return voucher.expiraEm.map { "\(pts) · válido até \(BXFormato.data($0))" } ?? pts
        }
    }
}

struct BXStatusVoucherVista: View {
    let status: BXStatusVoucher
    static func texto(_ s: BXStatusVoucher) -> String {
        switch s {
        case .ativo: return "Ativo"
        case .usado: return "Usado"
        case .expirado: return "Expirado"
        case .desconhecido: return "Em análise"
        }
    }
    var body: some View {
        switch status {
        case .ativo: BXStatus(Self.texto(status), .ok)
        case .usado: BXStatus(Self.texto(status), .info)
        case .expirado: BXStatus(Self.texto(status), .perigo)
        case .desconhecido: BXStatus(Self.texto(status), .aviso)
        }
    }
}
