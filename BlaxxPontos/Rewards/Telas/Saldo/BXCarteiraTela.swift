//
//  BXCarteiraTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G2 (Saldo)
//
//  Carteira (carteira.html, fotos 11): cabeçalho · cartão preto com o saldo em Space Mono NEON SOBRE TINTA
//  e o nível real de /card/ · botões · "EM PROCESSAMENTO" (envios dos últimos 60 s) · mini cartão do nível
//  → Cartão BlaXx · "Ver extrato completo →".
//  Fora (inventado no web): "Plano Plus", gráfico "Acúmulo · 6 meses", "A expirar 12 dias", "Pontos a
//  expirar", "Disponíveis = saldo − pendentes" e números de demonstração quando a API falha.
//
//  Âncoras de demonstração: processamento, nivel.
//

import SwiftUI

struct BXCarteiraTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(\.dynamicTypeSize) private var dts

    @State private var cartao: BXCarga<BXCartaoEstado> = .carregando
    @State private var carregou = false

    var body: some View {
        BXPaginaSaldo(aba: .carteira, atualizar: { await carregar(saldo: true) }) {
            BXCabecalhoPagina(eyebrow: "Carteira BlaXx", titulo: "Sua carteira.",
                              lead: "Tudo que entra e sai, em um lugar só.")
            cartaoPreto.padding(.top, 24)
            if sessao.carteira == nil, let e = sessao.erroCarteira {
                BXEstadoErro(e) { await sessao.recarregarCarteira() }.padding(.top, 16)
            }
            processamento.padding(.top, 16).id("processamento")
            nivel.padding(.top, 16).id("nivel")
            BXLinkSeta("Ver extrato completo") { nav.ir(.extrato()) }
                .padding(.top, 24)
        } rodape: {
            BXRodapeRecibo()
        }
        .task {
            guard !carregou else { return }
            carregou = true
            await carregar(saldo: sessao.carteira == nil || sessao.carteiraDoCache)
        }
    }

    private func carregar(saldo: Bool) async {
        async let s: Void = saldo ? sessao.recarregarCarteira() : ()
        async let c: Void = carregarCartao()
        _ = await (s, c)
    }

    private func carregarCartao() async {
        do { cartao = .pronto(try await BXAPI.shared.cartao()) } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            cartao = .erro(BXErro.de(error))
        }
    }

    // MARK: cartão preto

    private var cartaoPreto: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    BXRotulo("Saldo", cor: BXCor.barraTexto)
                    if sessao.carteiraDoCache {
                        Text("Saldo do último acesso").bxFonte(.rotulo).foregroundStyle(BXCor.tintaApagada)
                    }
                }
                BXNumeroAnimado(sessao.carteira?.saldo, estilo: .saldoMono, sufixo: "pts",
                                contarNaEntrada: !sessao.carteiraDoCache, corSufixo: BXCor.tintaApagada)
                    .bxTextoNeon()
                Group {
                    if let c = cartao.valor {
                        Text("Nível \(BXTextoNivel.nome(c))" + (BXTextoNivel.faltam(c).map { " · \($0.prefix(1).lowercased())\($0.dropFirst())" } ?? ""))
                    } else if case .erro = cartao {
                        Text("Nível indisponível agora.")
                    } else {
                        Text(" ").redacted(reason: .placeholder)
                    }
                }
                .bxFonte(.corpo)
                .foregroundStyle(BXCor.papel)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 10) {
                if BXRecursos.compraNoApp { BXBotao("+ Comprar pontos") { nav.ir(.comprar()) } }
                let l = dts.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                l {
                    BXBotao("Enviar pontos", estilo: .vazadoSobrePreto) { nav.ir(.enviar()) }
                    BXBotao("Receber", estilo: .vazadoSobrePreto) { nav.ir(.receber) }
                }
                BXBotao("Resgatar →", estilo: .vazadoSobrePreto) { nav.ir(.resgates(.catalogo)) }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
        .bxSombra(.padrao)
    }

    // MARK: em processamento

    private var processamento: some View {
        let n = sessao.carteira?.emProcessamento
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                BXRotulo("Em processamento")
                Spacer(minLength: 8)
                BXChip((n ?? 0) > 0 ? "Pode desfazer" : "Nada pendente", .preto)
            }
            Text(n.map(BXFormato.pontos) ?? "—")
                .font(BXFonte.fonte(.saldoMono, tamanho: 30))
                .foregroundStyle(BXCor.tinta)
                .contentTransition(.numericText())
            Text("Envios dos últimos 60 segundos. Você pode desfazer pelo extrato.")
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BXEspaco.cartao)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
        .accessibilityElement(children: .combine)
    }

    // MARK: mini cartão do nível

    @ViewBuilder private var nivel: some View {
        switch cartao {
        case .ocioso, .carregando:
            BXEsqueleto(.bloco(altura: 120))
        case .vazio:
            EmptyView()
        case .erro(let e):
            BXEstadoErro(e) { await carregarCartao() }
        case .pronto(let c):
            let chave = c.nivel?.chave ?? ""
            let cor = BXCor.nivel(chave)
            Button { nav.ir(.cartaoBlaxx) } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        BXWordmark(chave == "black" || chave.contains("vip") ? .barra : .claro, altura: 20)
                        Spacer(minLength: 8)
                        Text("Nível \(BXTextoNivel.nome(c))").bxFonte(.monoForte).modifier(BXCorTextoNivel(chave: chave))
                    }
                    Text(c.cartaoFormatado).font(BXFonte.fonte(.saldoMono, tamanho: 20)).modifier(BXCorTextoNivel(chave: chave))
                    BXProgresso(fracao: c.fracaoProgresso, altura: 8)
                    HStack {
                        Text(BXTextoNivel.faltam(c) ?? "").bxFonte(.legenda).modifier(BXCorTextoNivel(chave: chave))
                        Spacer(minLength: 8)
                        Text("Ver cartão →").bxFonte(.botao).modifier(BXCorTextoNivel(chave: chave))
                    }
                }
                .padding(BXEspaco.cartao)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cor.fundo, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
                .bxSombra(.leve)
            }
            .buttonStyle(BXEstiloPressao())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cartão BlaXx, nível \(BXTextoNivel.nome(c)). \(BXTextoNivel.faltam(c) ?? "")")
            .accessibilityHint("Abre o Cartão BlaXx")
            .accessibilityAddTraits(.isButton)
        }
    }
}
