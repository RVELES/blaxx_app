//
//  BXCelularSheet.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Celular e verificação em duas etapas por SMS (rotas /user/phone* e /user/2fa/sms/*).
//  - Cadastrar/trocar celular: número → POST /user/phone (SMS) → código → POST /user/phone/verify.
//  - Ativar SMS: senha → POST /user/2fa/sms/enable; sem celular ou `phone_not_verified` → confirma o
//    celular primeiro e volta para a senha.
//  - Desativar SMS: senha → POST /user/2fa/sms/disable (o /auth/me não diz o método; se continuar
//    ativo, a verificação é pelo aplicativo autenticador e a tela avisa).
//  - Remover celular: senha → DELETE /user/phone (desliga o SMS se estiver ativo).
//

import SwiftUI

struct BXCelularSheet: View {
    enum Modo: Equatable { case celular, ativarSMS, desativarSMS, removerCelular }
    private enum Passo { case telefone, codigo, senha }

    let modo: Modo
    var aoConcluir: () -> Void = {}

    @Environment(BXSessao.self) private var sessao
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.dismiss) private var fechar

    @State private var passo: Passo = .telefone
    @State private var telefone = ""
    @State private var mascarado = ""
    @State private var codigo = ""
    @State private var senha = ""
    @State private var enviando = false
    @State private var erro: String?
    @State private var erroSenha: String?
    @State private var esperaReenvio = 0
    /// Depois de confirmar o celular, volta para a senha e ativa o SMS.
    @State private var seguirParaSMS = false

    private var titulo: String {
        switch modo {
        case .celular: return sessao.usuario?.celular == nil ? "Cadastrar celular." : "Trocar celular."
        case .ativarSMS: return "Ativar verificação por SMS."
        case .desativarSMS: return "Desativar verificação por SMS."
        case .removerCelular: return "Remover celular."
        }
    }

    var body: some View {
        BXCorpoFolhaConta {
            BXCabecalhoFolhaConta(rotulo: "Segurança · celular", titulo: titulo) { fechar() }
            switch passo {
            case .telefone: passoTelefone
            case .codigo: passoCodigo
            case .senha: passoSenha
            }
            if let erro { BXAvisoErroConta(texto: erro) }
        }
        .animation(BXMovimento.ease, value: passo)
        .interactiveDismissDisabled(enviando)
        .onAppear(perform: iniciar)
        .onDisappear { senha = ""; codigo = "" }
        .task(id: esperaReenvio > 0) {
            while esperaReenvio > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                esperaReenvio -= 1
            }
        }
    }

    private func iniciar() {
        switch modo {
        case .celular:
            passo = .telefone
        case .ativarSMS:
            if sessao.usuario?.celular?.isEmpty ?? true {
                seguirParaSMS = true
                passo = .telefone
            } else {
                passo = .senha
            }
        case .desativarSMS, .removerCelular:
            passo = .senha
        }
    }

    // MARK: Passos

    @ViewBuilder private var passoTelefone: some View {
        Text(seguirParaSMS
             ? "Para receber os códigos por SMS, cadastre e confirme o seu celular."
             : "Enviamos um código por SMS para confirmar que o número é seu.")
            .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            .fixedSize(horizontal: false, vertical: true)
        BXCampo("Celular", texto: $telefone, tipo: .celular, placeholder: "(11) 99999-9999")
            .onChange(of: telefone) { _, _ in erro = nil }
        BXBotao("Enviar código por SMS", estilo: .preto, carregando: enviando) { Task { await enviarCodigo(telefone) } }
            .disabled(telefone.filter(\.isNumber).count < 10)
            .opacity(telefone.filter(\.isNumber).count >= 10 || enviando ? 1 : 0.45)
    }

    @ViewBuilder private var passoCodigo: some View {
        Text("Digite o código de 6 dígitos enviado para \(mascarado.isEmpty ? "o seu celular" : mascarado).")
            .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            .fixedSize(horizontal: false, vertical: true)
        BXCampoCodigo(codigo: $codigo)
            .onChange(of: codigo) { _, novo in
                erro = nil
                if novo.count == 6 { Task { await verificar() } }
            }
        BXBotao("Confirmar celular", estilo: .preto, carregando: enviando) { Task { await verificar() } }
            .disabled(codigo.count != 6)
            .opacity(codigo.count == 6 || enviando ? 1 : 0.45)
        HStack {
            if esperaReenvio > 0 {
                Text("Reenviar em \(esperaReenvio) s").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    .contentTransition(.numericText(countsDown: true))
            } else {
                BXLinkSeta("Reenviar código") { Task { await enviarCodigo(telefone) } }
            }
            Spacer()
            Button("Trocar número") { codigo = ""; passo = .telefone }
                .bxFonte(.botao).foregroundStyle(BXCor.tinta)
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var passoSenha: some View {
        Text(textoSenha).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            .fixedSize(horizontal: false, vertical: true)
        BXCampo("Sua senha", texto: $senha, tipo: .senha, erro: erroSenha)
            .onChange(of: senha) { _, _ in erroSenha = nil; erro = nil }
        BXBotao(tituloAcaoSenha, estilo: modo == .ativarSMS ? .preto : .perigo, carregando: enviando) {
            Task { await confirmarComSenha() }
        }
        .disabled(senha.isEmpty)
        .opacity(!senha.isEmpty || enviando ? 1 : 0.45)
    }

    private var textoSenha: String {
        switch modo {
        case .ativarSMS:
            return "Com a verificação por SMS, pedimos um código enviado para \(sessao.usuario?.celularMascarado ?? "o seu celular") ao entrar. Confirme com a sua senha."
        case .desativarSMS:
            return "Sem a verificação em duas etapas, a sua conta fica protegida só pela senha. Confirme com a sua senha."
        case .removerCelular:
            return "O celular sai da conta e, se a verificação por SMS estiver ativa, ela é desligada. Confirme com a sua senha."
        case .celular:
            return ""
        }
    }

    private var tituloAcaoSenha: String {
        switch modo {
        case .ativarSMS: return "Ativar por SMS"
        case .desativarSMS: return "Desativar"
        case .removerCelular: return "Remover celular"
        case .celular: return "Confirmar"
        }
    }

    // MARK: Rede

    private func enviarCodigo(_ numero: String) async {
        erro = nil
        enviando = true
        defer { enviando = false }
        do {
            mascarado = try await BXAPI.shared.cadastrarCelular(numero)
            codigo = ""
            esperaReenvio = 30
            passo = .codigo
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            BXHaptica.tocar(.erro)
            if e.tipo == .muitasTentativas, let s = e.tentarEmSegundos {
                esperaReenvio = s
                erro = "Aguarde \(s) segundos para pedir um novo código."
                if passo == .telefone, !mascarado.isEmpty { passo = .codigo }
            } else {
                erro = e.mensagemServidorSegura ?? e.mensagemParaUsuario
            }
        }
    }

    private func verificar() async {
        guard codigo.count == 6, !enviando else { return }
        enviando = true
        defer { enviando = false }
        do {
            _ = try await BXAPI.shared.verificarCelular(codigo: codigo)
            await sessao.recarregarUsuario()
            BXHaptica.tocar(.sucesso)
            if seguirParaSMS {
                toast.mostrar("Celular confirmado.", .sucesso)
                codigo = ""
                passo = .senha
                if !senha.isEmpty { await confirmarComSenha() }
            } else {
                toast.mostrar("Celular confirmado.", .sucesso)
                aoConcluir()
                fechar()
            }
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            BXHaptica.tocar(.erro)
            let e = BXErro.de(error)
            codigo = ""
            switch e.codigo {
            case "code_expired", "no_pending_code": erro = "O código expirou. Toque em Reenviar código."
            default: erro = e.mensagemServidorSegura ?? "Código não confere. Confira o SMS e tente de novo."
            }
        }
    }

    private func confirmarComSenha() async {
        erro = nil
        erroSenha = nil
        enviando = true
        defer { enviando = false }
        do {
            switch modo {
            case .ativarSMS:
                try await BXAPI.shared.ligar2FASMS(senha: senha)
                await sessao.recarregarUsuario()
                toast.mostrar("Verificação por SMS ativada.", .sucesso)
            case .desativarSMS:
                try await BXAPI.shared.desligar2FASMS(senha: senha)
                await sessao.recarregarUsuario()
                if sessao.usuario?.mfaAtivo == true {
                    toast.mostrar("A verificação por SMS não estava ativa. A sua conta usa o aplicativo autenticador.", .info)
                } else {
                    toast.mostrar("Verificação em duas etapas desativada.", .info)
                }
            case .removerCelular:
                try await BXAPI.shared.removerCelular(senha: senha)
                await sessao.recarregarUsuario()
                toast.mostrar("Celular removido.", .info)
            case .celular:
                return
            }
            senha = ""
            BXHaptica.tocar(.sucesso)
            aoConcluir()
            fechar()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            if e.codigo == "phone_not_verified", let cel = sessao.usuario?.celular, !cel.isEmpty {
                // O celular existe mas ainda não foi confirmado: manda o código e volta para cá.
                BXHaptica.tocar(.aviso)
                seguirParaSMS = true
                telefone = BXFormato.mascaraCelular(cel)
                await enviarCodigo(cel)
                return
            }
            BXHaptica.tocar(.erro)
            switch e.codigo {
            case "invalid_password", "wrong_password": erroSenha = "Senha incorreta."
            case "password_required": erro = "Sua conta entra pelo Google. Crie uma senha em \"Esqueci a senha\" antes de ativar o SMS."
            default:
                if e.tipo == .naoAutorizado { erroSenha = "Senha incorreta." } else { erro = e.mensagemServidorSegura ?? e.mensagemParaUsuario }
            }
        }
    }
}
