//
//  BXChamadoSheet.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  "Abrir um chamado" (WEB/abrir-chamado.html): categoria, assunto e descrição. O backend não tem
//  chamados (§2.2), então o pedido sai por e-mail para suporte@blaxxpontos.com.br pelo
//  MFMailComposeViewController (ou `mailto:`), já com a versão do app, do iOS e o Cartão BlaXx.
//  Nunca senha, nunca código.
//

import SwiftUI
#if os(iOS)
import MessageUI
#endif

nonisolated enum BXCategoriaChamado: String, CaseIterable, Identifiable, Sendable {
    case pontos = "Pontos não creditados"
    case compra = "Compra de pontos ou pagamento"
    case resgate = "Resgate ou voucher"
    case envio = "Envio entre contas"
    case conta = "Conta e acesso"
    case privacidade = "Privacidade e LGPD"
    case fraude = "Suspeita de fraude"
    case outro = "Outro assunto"
    var id: String { rawValue }
}

struct BXChamadoSheet: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.dismiss) private var fechar
    @Environment(\.openURL) private var abrirURL

    @State private var categoria: BXCategoriaChamado?
    @State private var assunto = ""
    @State private var descricao = ""
    @State private var erroCategoria: String?
    @State private var erroDescricao: String?
    @State private var compondo = false
    @State private var semApp = false
    @Namespace private var pilulas

    static let emailSuporte = "suporte@blaxxpontos.com.br"

    init(categoria: BXCategoriaChamado? = nil) {
        _categoria = State(initialValue: categoria)
    }

    var body: some View {
        BXCorpoFolhaConta {
            BXCabecalhoFolhaConta(rotulo: "Suporte · resposta em até 1 dia útil", titulo: "Abrir um chamado.") { fechar() }
            Text("Conte o que aconteceu. Quanto mais detalhes, mais rápida a solução.")
                .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Categoria").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    .accessibilityHidden(true)
                BXFluxoConta(espaco: 8) {
                    ForEach(BXCategoriaChamado.allCases) { c in
                        BXPilula(c.rawValue, ativa: categoria == c, estilo: .conta, animacao: pilulas) {
                            withAnimation(BXMovimento.mola) { categoria = c }
                            erroCategoria = nil
                            BXHaptica.tocar(.selecao)
                        }
                    }
                }
                if let erroCategoria {
                    Text(erroCategoria).bxFonte(.legenda).foregroundStyle(BXCor.perigoTexto)
                }
            }

            BXCampo("Assunto", texto: $assunto, placeholder: "Resumo em uma linha")
            BXCampo("Descrição", texto: $descricao, tipo: .mensagem(limite: 1000),
                    placeholder: "O que aconteceu, quando e o que você já tentou.", erro: erroDescricao)
                .onChange(of: descricao) { _, _ in erroDescricao = nil }

            if categoria == .fraude {
                BXNotaConta(texto: "Chamados de suspeita de fraude têm prioridade máxima. Enquanto isso, revise a sua segurança e encerre sessões que você não reconhece.")
            }

            BXBotao("Enviar chamado por e-mail →", estilo: .preto) { enviar() }

            if semApp {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Não encontramos um app de e-mail neste aparelho. Escreva para:")
                        .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Text(Self.emailSuporte).bxFonte(.item).foregroundStyle(BXCor.tinta)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        BXBotao("Copiar", estilo: .secundario, larguraTotal: false) {
                            BXCopiar.copiar(Self.emailSuporte, aviso: "E-mail do suporte copiado.", toast: toast)
                        }
                    }
                }
                .padding(14)
                .bxSuperficie(raio: BXRaio.md, cor: BXCor.superficie2)
                .transition(.opacity)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Antes de abrir").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                Text("→ Consulte o extrato para ver o status de cada movimento.\n→ Dúvidas comuns estão nas perguntas frequentes.\n→ Nunca envie sua senha ou códigos de verificação no chamado.")
                    .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .sheet(isPresented: $compondo) {
            #if os(iOS)
            BXCompositorEmail(destinatario: Self.emailSuporte, assunto: assuntoFinal, corpo: corpoFinal) { enviado in
                compondo = false
                if enviado {
                    BXHaptica.tocar(.sucesso)
                    toast.mostrar("Chamado enviado. Respondemos em até 1 dia útil.", .sucesso)
                    fechar()
                }
            }
            .ignoresSafeArea()
            #endif
        }
        .onAppear {
            if BXDemo.subtela == "chamado-preenchido" {
                categoria = .pontos
                assunto = "Pontos da compra de ontem"
                descricao = "Paguei o pacote Plus e os pontos ainda não apareceram no extrato."
            }
        }
    }

    private var assuntoFinal: String {
        let a = assunto.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = categoria?.rawValue ?? "Chamado"
        return a.isEmpty ? "[BlaXx iOS] \(c)" : "[BlaXx iOS] \(c): \(a)"
    }

    private var corpoFinal: String {
        var linhas = [descricao.trimmingCharacters(in: .whitespacesAndNewlines), "", "---",
                      "Categoria: \(categoria?.rawValue ?? "—")",
                      "App BlaXx iOS \(BXInfoAppConta.versao)",
                      BXInfoAppConta.sistema]
        if let u = sessao.usuario {
            linhas.append("Cartão BlaXx: \(u.cartaoFormatado)")
            linhas.append("E-mail da conta: \(u.email)")
        }
        return linhas.joined(separator: "\n")
    }

    private func enviar() {
        guard categoria != nil else {
            erroCategoria = "Escolha a categoria do chamado."
            BXHaptica.tocar(.erro)
            return
        }
        guard descricao.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
            erroDescricao = "Conte com um pouco mais de detalhe (pelo menos 10 caracteres)."
            return
        }
        #if os(iOS)
        if MFMailComposeViewController.canSendMail() {
            compondo = true
            return
        }
        #endif
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = Self.emailSuporte
        c.queryItems = [URLQueryItem(name: "subject", value: assuntoFinal), URLQueryItem(name: "body", value: corpoFinal)]
        guard let url = c.url else { withAnimation { semApp = true }; return }
        abrirURL(url) { aceito in
            if !aceito { withAnimation { semApp = true } }
        }
    }
}

#if os(iOS)
/// MFMailComposeViewController em SwiftUI.
struct BXCompositorEmail: UIViewControllerRepresentable {
    let destinatario: String
    let assunto: String
    let corpo: String
    let concluir: (Bool) -> Void

    func makeCoordinator() -> Coordenador { Coordenador(concluir: concluir) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([destinatario])
        vc.setSubject(assunto)
        vc.setMessageBody(corpo, isHTML: false)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    final class Coordenador: NSObject, MFMailComposeViewControllerDelegate {
        let concluir: (Bool) -> Void
        init(concluir: @escaping (Bool) -> Void) { self.concluir = concluir }

        nonisolated func mailComposeController(_ controller: MFMailComposeViewController,
                                               didFinishWith result: MFMailComposeResult, error: Error?) {
            let enviado = result == .sent || result == .saved
            MainActor.assumeIsolated { concluir(enviado) }
        }
    }
}
#endif

/// Disposição em linhas que quebram (pílulas de categoria).
struct BXFluxoConta: Layout {
    var espaco: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largura = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, alturaLinha: CGFloat = 0, maiorX: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(ProposedViewSize(width: largura, height: nil))
            if x > 0, x + t.width > largura {
                x = 0
                y += alturaLinha + espaco
                alturaLinha = 0
            }
            x += t.width + espaco
            maiorX = max(maiorX, x - espaco)
            alturaLinha = max(alturaLinha, t.height)
        }
        return CGSize(width: min(maiorX, largura), height: y + alturaLinha)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, alturaLinha: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX, x + t.width > bounds.maxX {
                x = bounds.minX
                y += alturaLinha + espaco
                alturaLinha = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(t.width, bounds.width), height: t.height))
            x += t.width + espaco
            alturaLinha = max(alturaLinha, t.height)
        }
    }
}
