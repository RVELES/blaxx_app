//
//  BXCadastroTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Criar conta (cadastro.html, fotos web 03): barra de 3 passos, "PASSO N DE 3".
//  1 "Quem é você?": Nome completo + CPF (dígito verificador no aparelho) · OU · Google.
//  2 "Como te encontramos?": E-mail + Celular (opcional).
//  3 "Crie seu acesso.": Senha (checklist com os `issues` do servidor) + aceite dos termos, regras de pontos e
//    política de privacidade (LGPD) → POST /auth/register com os 3 aceites.
//  Erro de nome/CPF volta ao passo 1; de e-mail/celular ao passo 2. Sucesso → logado + verificação de e-mail.
//  Diferença do web, de propósito: o chip "PONTOS DE BOAS-VINDAS" virou "CADASTRO SEM MENSALIDADE", porque o
//  backend não dá pontos no cadastro (regra "nada inventado").
//

import SwiftUI

struct BXCadastroTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXFluxoAcesso.self) private var fluxo
    @Environment(\.accessibilityReduceMotion) private var reduzido

    @State private var passo = 1
    @State private var nome = ""
    @State private var cpf = ""
    @State private var email = ""
    @State private var celular = ""
    @State private var senha = ""
    @State private var aceite = false

    @State private var erroNome: String?
    @State private var erroCPF: String?
    @State private var erroEmail: String?
    @State private var erroCelular: String?
    @State private var erroSenha: String?
    @State private var erro: String?
    @State private var problemas: [String] = []
    @State private var criando = false
    @State private var googleCarregando = false

    var body: some View {
        BXPaginaAcesso {
            BXCartaoAcesso {
                barraPassos
                BXChipCadastro()
                Group {
                    switch passo {
                    case 1: passo1
                    case 2: passo2
                    default: passo3
                    }
                }
                .id(passo)
                .transition(reduzido ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                              removal: .opacity))
                if let erro { BXErroFormulario(erro) }
            }
            .animation(BXMovimento.ou(BXMovimento.ease, reduzido: reduzido), value: passo)
            .animation(BXMovimento.ease, value: erro)
        }
        .sensoryFeedback(.selection, trigger: passo)
        .onDisappear { senha = "" }
        .onAppear(perform: demonstracao)
    }

    // MARK: - Barra de passos

    private var barraPassos: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= passo ? BXCor.neon : BXCor.linha)
                    .frame(height: 6)
            }
        }
        .animation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido), value: passo)
        .accessibilityElement()
        .accessibilityLabel("Passo \(passo) de 3")
    }

    // MARK: - Passos

    private var passo1: some View {
        VStack(alignment: .leading, spacing: 18) {
            BXTituloAcesso("Quem é você?", sub: "Vamos começar pelo básico.", passo: "Passo 1 de 3")
            BXCampo("Nome completo", texto: $nome, tipo: .nome, placeholder: "Nome e sobrenome", erro: erroNome)
                .submitLabel(.next)
            BXCampo("CPF", texto: $cpf, tipo: .cpf, placeholder: "000.000.000-00", erro: erroCPF)
                .submitLabel(.next)
                .onSubmit(avancar1)
            BXBotao("Continuar →", estilo: .preto, acao: avancar1)
            if BXRecursos.loginGoogle {
                BXDivisorOu()
                BXBotaoGoogle("Inscrever-se no Google", carregando: googleCarregando) {
                    Task { await google() }
                }
                Text("Com o Google, a conta é criada com o nome e o e-mail da sua conta Google. Ao continuar, você aceita os termos de uso, as regras de pontos e a política de privacidade.")
                    .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Text("Já tem conta?").bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                Button { nav.ir(.entrar) } label: {
                    Text("Entrar →").bxFonte(.botao).foregroundStyle(BXCor.tinta).underline()
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var passo2: some View {
        VStack(alignment: .leading, spacing: 18) {
            BXTituloAcesso("Como te encontramos?", sub: "Usamos para login, avisos e segurança.", passo: "Passo 2 de 3")
            BXCampo("E-mail", texto: $email, tipo: .email, placeholder: "voce@email.com", erro: erroEmail)
                .submitLabel(.next)
            BXCampo("Celular (opcional)", texto: $celular, tipo: .celular, placeholder: "(11) 99999-9999",
                    erro: erroCelular)
                .submitLabel(.next)
                .onSubmit(avancar2)
            HStack(spacing: 12) {
                BXBotao("← Voltar", estilo: .secundario) { irPara(1) }
                BXBotao("Continuar →", estilo: .preto, acao: avancar2)
            }
        }
    }

    private var passo3: some View {
        VStack(alignment: .leading, spacing: 18) {
            BXTituloAcesso("Crie seu acesso.", sub: "Último passo. Defina sua senha e confirme os termos.",
                           passo: "Passo 3 de 3")
            BXCampo("Senha", texto: $senha, tipo: .novaSenha, placeholder: "Mínimo 7 caracteres", erro: erroSenha)
                .submitLabel(.done)
            if !problemas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A senha precisa").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    ForEach(problemas, id: \.self) { p in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(BXCor.perigoTexto).frame(width: 6, height: 6).padding(.top, 7)
                            Text(p).bxFonte(.corpo).foregroundStyle(BXCor.tinta)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BXCor.superficie2, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
            }
            aceiteTermos
            BXBotao("Criar conta grátis →", estilo: .preto, carregando: criando) {
                Task { await criar() }
            }
            BXBotao("← Voltar", estilo: .secundario) { irPara(2) }
                .disabled(criando)
        }
    }

    private var aceiteTermos: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { aceite.toggle(); BXHaptica.tocar(.selecao) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(aceite ? BXCor.tinta : BXCor.superficie)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(aceite ? BXCor.tinta : BXCor.cinza, lineWidth: 1.5)
                    if aceite {
                        BXDesenhoVisto().stroke(BXCor.neon, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            .padding(5)
                    }
                }
                .frame(width: 22, height: 22)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, -11)
            .padding(.top, -10)
            .accessibilityLabel("Li e aceito os termos de uso, as regras de pontos e a política de privacidade (LGPD)")
            .accessibilityAddTraits(aceite ? [.isButton, .isSelected] : .isButton)

            VStack(alignment: .leading, spacing: 6) {
                Text("Li e aceito os termos de uso, as regras de pontos e a política de privacidade (LGPD).")
                    .bxFonte(.corpo).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture { aceite.toggle(); BXHaptica.tocar(.selecao) }
                    .accessibilityHidden(true)
                HStack(spacing: 14) {
                    linkSite("Termos de uso", "termos.html")
                    linkSite("Regras de pontos", "regras-pontos.html")
                    linkSite("Privacidade", "privacidade.html")
                }
                .font(BXFonte.fonte(.legenda, tamanho: 13))
            }
        }
    }

    private func linkSite(_ titulo: String, _ caminho: String) -> some View {
        Button { nav.abrirSite(caminho) } label: {
            Text(titulo).underline().foregroundStyle(BXCor.tinta)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(minHeight: 32)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Validação e envio

    private func irPara(_ n: Int) {
        erro = nil
        withAnimation(BXMovimento.ou(BXMovimento.ease, reduzido: reduzido)) { passo = n }
    }

    private func avancar1() {
        erroNome = BXValidaAcesso.nomeCompleto(nome) ? nil : "Informe nome e sobrenome."
        let d = cpf.filter(\.isNumber)
        erroCPF = d.isEmpty ? "Informe seu CPF." : (BXValidaAcesso.cpf(d) ? nil : "CPF inválido. Confira os números.")
        guard erroNome == nil, erroCPF == nil else { return }
        irPara(2)
    }

    private func avancar2() {
        erroEmail = BXValidaAcesso.email(email) ? nil : "Informe um e-mail válido."
        let c = celular.filter(\.isNumber)
        erroCelular = (c.isEmpty || c.count == 10 || c.count == 11) ? nil : "Celular incompleto. Use (11) 99999-9999."
        guard erroEmail == nil, erroCelular == nil else { return }
        irPara(3)
    }

    private func criar() async {
        guard !criando else { return }
        erro = nil
        problemas = []
        erroSenha = BXValidaAcesso.senha(senha) ? nil : "A senha precisa ter pelo menos 7 caracteres."
        guard erroSenha == nil else { return }
        guard aceite else {
            erro = "Você precisa aceitar os termos e a LGPD."
            BXHaptica.tocar(.erro)
            return
        }
        criando = true
        defer { criando = false }
        let c = BXCadastro(nome: nome, email: email, cpf: cpf, senha: senha,
                           celular: celular.filter(\.isNumber).isEmpty ? nil : celular)
        do {
            try await sessao.cadastrar(c)
            senha = ""
            fluxo.codigoEmailJaEnviado = true
            nav.exigirVerificacaoEmail()
            BXHaptica.tocar(.sucesso)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            tratar(BXErro.de(error))
        }
    }

    private func tratar(_ e: BXErro) {
        let msg = e.mensagemServidorSegura ?? e.mensagemParaUsuario
        let m = BXSanitizador.normalizar(msg)
        if !e.problemasSeguros.isEmpty {
            problemas = e.problemasSeguros
            erroSenha = "Escolha uma senha mais forte."
            return
        }
        if m.contains("cpf") || m.contains("nome") || m.contains("18 anos") {
            if m.contains("cpf") { erroCPF = msg } else { erroNome = msg }
            irPara(1)
            erro = msg
        } else if m.contains("e-mail") || m.contains("email") || m.contains("celular") {
            if m.contains("celular") { erroCelular = msg } else { erroEmail = msg }
            irPara(2)
            erro = msg
        } else if m.contains("senha") {
            erroSenha = msg
        } else {
            erro = msg
        }
        BXHaptica.tocar(.erro)
    }

    private func google() async {
        guard !googleCarregando else { return }
        erro = nil
        googleCarregando = true
        defer { googleCarregando = false }
        do {
            try await sessao.entrarComGoogle()
            BXHaptica.tocar(.sucesso)
            // A tela diz "Ao continuar, você aceita…": registra os 3 aceites (o POST /auth/google não registra).
            // Melhor esforço: falhar aqui não desfaz o login.
            try? await BXAPI.shared.reaceitarTermos()
        } catch {
            if BXErro.ehCancelamento(error) { return }
            erro = BXErro.de(error).mensagemParaUsuario
        }
    }

    /// Modo demonstração: `-BXSubtela passo2|passo3` abre o passo para foto (dados de exemplo só em DEBUG).
    private func demonstracao() {
        #if DEBUG
        guard BXDemo.visitante || BXDemo.ativo, let s = BXDemo.subtela, passo == 1 else { return }
        if s == "passo2" || s == "passo3" {
            nome = "Cliente Exemplo"
            cpf = "000.000.001-91"
            passo = 2
        }
        if s == "passo3" {
            email = "cliente@exemplo.test"
            passo = 3
        }
        #endif
    }
}

/// Chip neon do topo do cadastro.
private struct BXChipCadastro: View {
    var body: some View {
        HStack(spacing: 8) {
            BXIcone(.semMensalidade, tamanho: .livre(lado: 22, raio: 6), contorno: true)
            Text("Cadastro sem mensalidade").bxFonte(.monoForte).foregroundStyle(BXCor.tinta)
        }
        .padding(.vertical, 6)
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .background(BXCor.neon, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Visto do aceite (traço neon sobre o quadrado preto).
struct BXDesenhoVisto: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY - r.height * 0.1))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.1))
        return p
    }
}
