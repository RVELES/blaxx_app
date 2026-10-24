//
//  BXEnvioConcluidoTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Envio concluído (spec §5 G3 item 9; web `envio-concluido.html`, fotos 28): recibo "COMPROVANTE DE ENVIO"
//  (Comprovante ENV-…, Para, Pontos, Data, Status "Em processamento" → "Efetivado"), "Desfazer (59 s)" →
//  `POST /transfer/<id>/cancel`, aos 61 s recarrega a carteira (o backend efetiva o envio na leitura e
//  avisa quem recebe), compartilhar o comprovante como imagem, "Enviar mais" e "Ver extrato".
//  Nada de "concluída na hora": o envio fica 60 s em processamento.
//

import SwiftUI

struct BXEnvioConcluido: View {
    let para: String
    let aoEnviarMais: () -> Void
    let aoVerExtrato: () -> Void

    @Environment(BXSessao.self) private var sessao
    @Environment(BXToastCentral.self) private var toast

    @State private var envio: BXEnvio
    @State private var agora = Date.now
    @State private var desfazendo = false
    @State private var recarregouAoEfetivar = false
    @State private var imagem: Image?

    init(envio: BXEnvio, para: String, aoEnviarMais: @escaping () -> Void, aoVerExtrato: @escaping () -> Void) {
        _envio = State(initialValue: envio)
        self.para = para
        self.aoEnviarMais = aoEnviarMais
        self.aoVerExtrato = aoVerExtrato
    }

    private var segundos: Int { envio.segundosParaEfetivar(agora: agora) }
    private var podeDesfazer: Bool { envio.pendente && envio.cancelavel && segundos > 0 }

    private var status: (texto: String, tipo: BXStatus.Tipo) {
        if envio.cancelado { return ("Desfeito", .info) }
        if envio.pendente && segundos > 0 { return ("Em processamento", .aviso) }
        return ("Efetivado", .ok)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .center, spacing: 12) {
                BXIcone(envio.cancelado ? .trocar : .visto, tamanho: .marca)
                Text(envio.cancelado ? "Envio desfeito." : "Pontos enviados.")
                    .bxFonte(.tituloPagina).foregroundStyle(BXCor.tinta)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(textoApoio)
                    .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            comprovante

            if podeDesfazer {
                BXBotao("Desfazer (\(segundos) s)", estilo: .secundario, icone: .trocar, carregando: desfazendo) {
                    Task { await desfazer() }
                }
                .contentTransition(.numericText(countsDown: true))
                .accessibilityLabel("Desfazer envio, \(segundos) segundos restantes")
            }

            if let imagem {
                ShareLink(item: imagem, preview: SharePreview("Comprovante de envio BlaXx", image: imagem)) {
                    Label { Text("Compartilhar comprovante") } icon: { BXIcone(.anexo, tamanho: .livre(lado: 26, raio: 7)) }
                        .bxFonte(.botao)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BXEstiloBotao(estilo: .secundario))
            }

            BXBotao("Enviar mais", acao: aoEnviarMais)
            BXLinkSeta("Ver extrato", acao: aoVerExtrato)
                .frame(maxWidth: .infinity)
        }
        .task {
            // Relógio da janela de 60 s (para sozinho quando o envio efetiva ou é desfeito).
            while !Task.isCancelled {
                agora = .now
                if !envio.pendente || segundos == 0 { break }
                try? await Task.sleep(for: .seconds(1))
            }
            agora = .now
            await efetivouSePreciso()
        }
        .task(id: status.texto) { gerarImagem() }
    }

    private var textoApoio: String {
        if envio.cancelado { return "Os \(BXFormato.pontosComUnidade(envio.pontos)) voltaram para a sua conta." }
        if envio.pendente && segundos > 0 {
            return "O envio fica em processamento por 60 segundos. Até lá, você pode desfazer."
        }
        return "Os pontos já estão com quem recebeu."
    }

    private var comprovante: some View {
        BXRecibo(cabeca: "Comprovante de envio") {
            BXReciboTracejo()
            BXReciboLinha("Comprovante", envio.comprovante.isEmpty ? "—" : envio.comprovante)
            BXReciboLinha("Para", para)
            BXReciboLinha("Pontos", BXFormato.pontos(envio.pontos))
            BXReciboLinha("Data", BXFormato.dataHora(envio.criadoEm))
            BXReciboLinha("Status", status.texto)
            if let m = envio.mensagem, !m.isEmpty {
                BXReciboLinha("Mensagem", m)
            }
            BXReciboTracejo()
            BXReciboFaixa(envio.cancelado ? "Pontos devolvidos" : "Pontos enviados", BXFormato.pontos(envio.pontos))
            BXReciboVia()
        }
    }

    private func desfazer() async {
        desfazendo = true
        defer { desfazendo = false }
        do {
            let novo = try await BXAPI.shared.cancelarEnvio(id: envio.id)
            withAnimation(BXMovimento.mola) { envio = novo }
            BXHaptica.tocar(.sucesso)
            toast.mostrar("Envio desfeito. Os pontos voltaram para a sua conta.", .sucesso)
            await sessao.recarregarCarteira()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            let servidor = (e.mensagemServidorSegura ?? "").lowercased()
            if servidor.contains("efetivad") || servidor.contains("janela") {
                toast.mostrar("O prazo para desfazer terminou. O envio foi efetivado.", .aviso)
                agora = .now.addingTimeInterval(120)
            } else {
                toast.mostrar(e.mensagemParaUsuario, .erro)
            }
        }
    }

    /// Aos 61 s a leitura da carteira efetiva o envio no backend e dispara a notificação de quem recebe.
    private func efetivouSePreciso() async {
        guard !recarregouAoEfetivar, !envio.cancelado else { return }
        recarregouAoEfetivar = true
        try? await Task.sleep(for: .seconds(1))
        await sessao.recarregarCarteira()
    }

    private func gerarImagem() {
        imagem = BXCompartilharImagem.imagem(de: comprovante)
    }
}
