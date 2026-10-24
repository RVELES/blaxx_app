//
//  BXVerificarEmailTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Verificação de e-mail (sheet do logado). Não bloqueia o app: abre logo após o cadastro (o backend já mandou
//  o código) e quando uma ação devolve 403 EMAIL_NOT_VERIFIED (`nav.exigirVerificacaoEmail()`).
//  "Enviar código" (POST /auth/verify-email/send) · BXCampoCodigo · reenviar com espera de 30 s ·
//  tentativas restantes · sucesso: háptica `.success` + `recarregarUsuario()`.
//

import SwiftUI

struct BXVerificarEmailTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXFluxoAcesso.self) private var fluxo
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.dismiss) private var fechar

    @State private var enviado = false
    @State private var minutos: Int?
    @State private var codigo = ""
    @State private var erro: String?
    @State private var enviando = false
    @State private var confirmando = false
    @State private var espera = 0
    @State private var relogio: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BXIcone(.email, tamanho: .marca)
                    BXTituloAcesso("Confirme seu e-mail.",
                                   sub: "Com o e-mail confirmado você pode enviar e resgatar pontos.")
                    if let email = sessao.usuario?.email {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("E-mail").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                            Text(email).bxFonte(.valorDado).foregroundStyle(BXCor.tinta)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    if enviado {
                        Text(minutos.map { "Enviamos um código de 6 dígitos para o seu e-mail. Ele vale por \($0) minutos." }
                             ?? "Enviamos um código de 6 dígitos para o seu e-mail.")
                            .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                            .fixedSize(horizontal: false, vertical: true)
                        BXCampoCodigo(codigo: $codigo)
                            .accessibilityLabel("Código de 6 dígitos")
                            .onChange(of: codigo) { _, novo in
                                if novo.count == 6, !confirmando { Task { await confirmar() } }
                            }
                        if let erro { BXErroFormulario(erro) }
                        BXBotao("Confirmar e-mail →", estilo: .preto, carregando: confirmando) {
                            Task { await confirmar() }
                        }
                        Button { Task { await enviar() } } label: {
                            Text(espera > 0 ? "Reenviar código em \(espera) s" : "Reenviar código")
                                .bxFonte(.botao)
                                .foregroundStyle(espera > 0 ? BXCor.cinza : BXCor.tinta)
                                .underline(espera == 0)
                                .contentTransition(.numericText(countsDown: true))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(espera > 0 || enviando)
                    } else {
                        if let erro { BXErroFormulario(erro) }
                        BXBotao("Enviar código →", estilo: .preto, carregando: enviando) {
                            Task { await enviar() }
                        }
                    }

                    Text("Não achou? Confira a caixa de spam. O código chega de BlaXx Pontos.")
                        .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: BXEspaco.colunaMax)
                .frame(maxWidth: .infinity)
                .animation(BXMovimento.ease, value: enviado)
                .animation(BXMovimento.ease, value: erro)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BXCor.superficie, in: Rectangle())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Agora não") { fechar() }
                        .bxFonte(.botao)
                        .foregroundStyle(BXCor.tinta)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(24)
        .presentationBackground(BXCor.superficie)
        .presentationDragIndicator(.visible)
        .onAppear {
            if fluxo.codigoEmailJaEnviado {
                fluxo.codigoEmailJaEnviado = false
                enviado = true
                iniciarEspera()
            }
        }
        .onDisappear { relogio?.cancel() }
    }

    private func iniciarEspera() { iniciarContagem(de: 30) }

    private func enviar() async {
        guard !enviando else { return }
        erro = nil
        enviando = true
        defer { enviando = false }
        do {
            minutos = try await BXAPI.shared.enviarCodigoEmail()
            enviado = true
            codigo = ""
            iniciarEspera()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            if e.tipo == .muitasTentativas, let s = e.tentarEmSegundos {
                enviado = true
                iniciarContagem(de: s)
                erro = "Aguarde \(s) s para pedir outro código."
            } else {
                erro = e.mensagemServidorSegura ?? e.mensagemParaUsuario
            }
        }
    }

    private func iniciarContagem(de s: Int) {
        espera = s
        relogio?.cancel()
        relogio = Task {
            while espera > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                withAnimation { espera -= 1 }
            }
        }
    }

    private func confirmar() async {
        guard !confirmando else { return }
        guard codigo.count == 6 else {
            erro = "Digite os 6 dígitos do código."
            return
        }
        erro = nil
        confirmando = true
        defer { confirmando = false }
        do {
            try await BXAPI.shared.verificarEmail(codigo: codigo)
            BXHaptica.tocar(.sucesso)
            await sessao.recarregarUsuario()
            toast.mostrar("E-mail confirmado.", .sucesso)
            fechar()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            codigo = ""
            if let n = e.tentativasRestantes, n > 0 {
                erro = n == 1 ? "Código incorreto. Resta 1 tentativa." : "Código incorreto. Restam \(n) tentativas."
            } else if e.tipo == .muitasTentativas {
                erro = "Muitas tentativas. Peça um novo código."
            } else {
                erro = e.mensagemServidorSegura ?? e.mensagemParaUsuario
            }
            BXHaptica.tocar(.erro)
        }
    }
}
