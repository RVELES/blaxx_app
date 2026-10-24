//
//  BXCartaoBlaxxTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G2 (Saldo)
//
//  Cartão BlaXx (cartao.html, fotos 37): "SEU CARTÃO" / "Cartão BlaXx." · face na cor LOCAL do nível
//  (`BXCor.nivel`, nunca `tier.color` da API), `BXWordmark` (nunca `Text`), selo do nível, saldo Space Mono,
//  "Nome · ID", acumulado, "Faltam N p/ <próximo>", trilho · Apple Wallet nativo só quando disponível ·
//  "Programa de níveis" com nome + mínimo + "ATUAL" (sem `perks`, D09).
//  Erro → estado de erro (nunca o cartão demo "Ricardo · 16.320 · Ouro" do web).
//
//  Âncora de demonstração: niveis.
//

import SwiftUI
#if os(iOS)
import PassKit
import UIKit
#endif

struct BXCartaoBlaxxTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduzido

    @State private var carga: BXCarga<BXCartaoEstado> = .carregando
    @State private var niveisExtra: [BXNivel] = []
    @State private var passeDisponivel = false
    @State private var baixandoPasse = false
    @State private var inclinacao: CGSize = .zero
    @State private var progressoVisivel = false
    @State private var carregou = false

    var body: some View {
        BXPaginaSaldo(atualizar: { await carregar() }) {
            VStack(alignment: .leading, spacing: 14) {
                BXChip("Seu cartão", .eyebrow)
                Text("Cartão BlaXx.").bxFonte(.tituloPagina).foregroundStyle(BXCor.tinta)
                    .accessibilityAddTraits(.isHeader)
                Text("Seu nível é definido pelos pontos acumulados e nunca cai ao resgatar.")
                    .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Group {
                switch carga {
                case .ocioso, .carregando:
                    BXEsqueleto(.bloco(altura: 230))
                case .vazio:
                    EmptyView()
                case .erro(let e):
                    BXEstadoErro(e) { await carregar() }
                case .pronto(let c):
                    VStack(alignment: .leading, spacing: 16) {
                        face(c)
                        carteiraIPhone
                        programa(c).padding(.top, 24).id("niveis")
                    }
                }
            }
            .padding(.top, 24)
        } rodape: {
            BXRodapeRecibo()
        }
        .task {
            guard !carregou else { return }
            carregou = true
            await carregar()
        }
    }

    private func carregar() async {
        do {
            let c = try await BXAPI.shared.cartao()
            carga = .pronto(c)
            if c.niveis.isEmpty, let n = try? await BXAPI.shared.niveis() { niveisExtra = n }
            let disponivel = (try? await BXAPI.shared.passeDisponivel()) ?? false
            passeDisponivel = disponivel && c.passeDisponivel && Self.walletSuportada
            try? await Task.sleep(for: .milliseconds(150))
            progressoVisivel = true
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            carga = .erro(BXErro.de(error))
        }
    }

    // MARK: face do cartão

    private func face(_ c: BXCartaoEstado) -> some View {
        let chave = c.nivel?.chave ?? ""
        let cor = BXCor.nivel(chave)
        let escuro = chave == "black" || chave.contains("vip")
        let nome = c.membroNome.isEmpty ? (sessao.usuario?.nome ?? "") : c.membroNome
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                BXWordmark(escuro ? .barra : .claro, altura: 22)
                Spacer(minLength: 8)
                Text(BXTextoNivel.nome(c))
                    .bxFonte(.monoForte)
                    .foregroundStyle(escuro ? BXCor.papel : BXCor.tinta)
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background(escuro ? BXCor.tinta2 : BXCor.superficie.opacity(0.55), in: Capsule())
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(BXFormato.pontos(c.saldo))
                    .bxFonte(.saldoMono)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text("pts").bxFonte(.sufixoPontos)
            }
            .modifier(BXCorTextoNivel(chave: chave))
            Text(nome.isEmpty ? "ID \(c.membroID)" : "\(nome) · ID \(c.membroID)")
                .bxFonte(.corpo)
                .modifier(BXCorTextoNivel(chave: chave))
                .lineLimit(1).minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 6) {
                Text("Acumulado: \(BXFormato.pontosComUnidade(c.acumulado))")
                if let p = c.proximoNivel, c.faltam > 0 {
                    Text("Faltam \(BXFormato.pontosComUnidade(c.faltam)) p/ \(p.nome)")
                } else {
                    Text("Nível máximo alcançado")
                }
            }
            .font(BXFonte.fonte(.valorDado, tamanho: 14))
            .modifier(BXCorTextoNivel(chave: chave))
            BXProgresso(fracao: progressoVisivel ? c.fracaoProgresso : 0, altura: 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cor.fundo, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
        .bxSombra(.grande)
        .rotation3DEffect(.degrees(Double(inclinacao.width) / 14), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(Double(-inclinacao.height) / 14), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { v in
                    guard !reduzido else { return }
                    inclinacao = CGSize(width: max(-120, min(120, v.translation.width)),
                                        height: max(-120, min(120, v.translation.height)))
                }
                .onEnded { _ in withAnimation(BXMovimento.mola) { inclinacao = .zero } }
        )
        .contextMenu {
            Button("Copiar número") { BXCopiar.copiar(c.membroID, aviso: "Número copiado.", toast: toast) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cartão BlaXx, nível \(BXTextoNivel.nome(c)). Saldo \(BXFormato.pontosFalados(c.saldo)). \(nome). Número \(c.cartaoFormatado). Acumulado \(BXFormato.pontosFalados(c.acumulado)).")
        .accessibilityValue(c.proximoNivel.map { "Faltam \(BXFormato.pontosFalados(c.faltam)) para \($0.nome)" } ?? "Nível máximo")
        .accessibilityAction(named: "Copiar número") { BXCopiar.copiar(c.membroID, aviso: "Número copiado.", toast: toast) }
    }

    // MARK: Apple Wallet

    private static var walletSuportada: Bool {
        #if os(iOS)
        return PKAddPassesViewController.canAddPasses()
        #else
        return false
        #endif
    }

    @ViewBuilder private var carteiraIPhone: some View {
        #if os(iOS)
        if passeDisponivel {
            BXBotaoPasse(carregando: baixandoPasse) { Task { await adicionarPasse() } }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Adicionar à Carteira da Apple")
        } else if BXAmbiente.ehDebug {
            // Release (App Store): sem aviso de "em breve" (regra 2.1/2.3, nada de função anunciada que não existe).
            notaCarteira
        }
        #else
        notaCarteira
        #endif
    }

    private var notaCarteira: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Carteira do iPhone · em breve").bxFonte(.rotulo).foregroundStyle(BXCor.tinta)
            Text("O cartão na Carteira do iPhone será habilitado assim que o certificado da Apple for configurado no servidor.")
                .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BXCor.superficie2, in: RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func adicionarPasse() async {
        #if os(iOS)
        baixandoPasse = true
        defer { baixandoPasse = false }
        do {
            let dados = try await BXAPI.shared.passe()
            let passe = try PKPass(data: dados)
            guard let vc = PKAddPassesViewController(pass: passe) else { throw BXErro.servidor }
            BXApresentador.apresentar(vc)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            toast.mostrar("Não foi possível adicionar o cartão à Carteira agora.", .erro)
        }
        #endif
    }

    // MARK: programa de níveis

    private func programa(_ c: BXCartaoEstado) -> some View {
        let niveis = (c.niveis.isEmpty ? niveisExtra : c.niveis).sorted { a, b in
            if a.porConvite != b.porConvite { return !a.porConvite }
            return a.minimo < b.minimo
        }
        return VStack(alignment: .leading, spacing: 14) {
            Text("Programa de níveis").bxFonte(.h2).foregroundStyle(BXCor.tinta)
                .accessibilityAddTraits(.isHeader)
            Text("Você sobe conforme acumula pontos.").bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            if niveis.isEmpty {
                Text("A lista de níveis não está disponível agora.").bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            }
            ForEach(niveis) { n in
                let atual = n.chave == c.nivel?.chave
                HStack(spacing: 12) {
                    Circle().fill(BXCor.nivel(n.chave).fundo)
                        .overlay(Circle().strokeBorder(BXCor.linha, lineWidth: 1))
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    Text(n.nome).bxFonte(.nomeParceiro).foregroundStyle(BXCor.tinta)
                    Spacer(minLength: 8)
                    Text(n.rotuloMinimo).font(BXFonte.fonte(.recibo, tamanho: 13)).foregroundStyle(BXCor.cinza)
                    if atual { BXChip("Atual", .preto) }
                }
                .padding(14)
                .frame(minHeight: 56)
                .bxSuperficie(raio: BXRaio.md, borda: atual ? BXCor.tinta : BXCor.linha, larguraBorda: atual ? 1.5 : 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(n.nome), \(n.porConvite ? "por convite" : "a partir de \(BXFormato.pontosFalados(n.minimo))")\(atual ? ", nível atual" : "")")
            }
        }
        .padding(BXEspaco.cartao)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
    }
}

#if os(iOS)
/// `PKAddPassButton` nativo.
private struct BXBotaoPasse: UIViewRepresentable {
    let carregando: Bool
    let acao: () -> Void

    func makeCoordinator() -> Coordenador { Coordenador(acao: acao) }

    func makeUIView(context: Context) -> PKAddPassButton {
        let b = PKAddPassButton(addPassButtonStyle: .black)
        b.addTarget(context.coordinator, action: #selector(Coordenador.tocar), for: .touchUpInside)
        return b
    }

    func updateUIView(_ v: PKAddPassButton, context: Context) {
        context.coordinator.acao = acao
        v.isEnabled = !carregando
        v.alpha = carregando ? 0.45 : 1
    }

    final class Coordenador: NSObject {
        var acao: () -> Void
        init(acao: @escaping () -> Void) { self.acao = acao }
        @objc func tocar() { acao() }
    }
}

/// Apresenta um view controller por cima de tudo (PassKit não tem versão SwiftUI).
enum BXApresentador {
    static func apresentar(_ vc: UIViewController) {
        guard let cena = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let raiz = (cena.windows.first(where: { $0.isKeyWindow }) ?? cena.windows.first)?.rootViewController else { return }
        var topo = raiz
        while let p = topo.presentedViewController { topo = p }
        topo.present(vc, animated: true)
    }
}
#endif
