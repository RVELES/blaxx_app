//
//  BXSegurancaTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Segurança (WEB/seguranca.html, fotos 34), com os dados reais do backend no lugar dos números fixos do
//  web: "SUA CONTA" / "Segurança." · Autenticação (Senha, Verificação em duas etapas por aplicativo e por
//  SMS, Celular, Confirmação por e-mail) · Sessões ativas (GET /user/sessions; encerrar uma; encerrar
//  todas → POST /auth/sessions/revoke-all) · Histórico de acesso (GET /user/access-log) · Boas práticas.
//  Fora: "iPhone 15 · São Paulo", "ativa desde 12/03/2026", "Nível de proteção 92/100", resgate por transferência.
//

import SwiftUI

struct BXSegurancaTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast

    @State private var sessoes: BXCarga<[BXSessaoDispositivo]> = .carregando
    @State private var historico: BXCarga<[BXEventoAcesso]> = .carregando
    @State private var verHistoricoTodo = false
    @State private var encerrando: String?
    @State private var confirmarEncerrar: BXSessaoDispositivo?
    @State private var confirmarTodas = false
    @State private var encerrandoTodas = false
    /// O backend marca "current" por IP + navegador, então várias sessões do mesmo aparelho podem vir
    /// marcadas. Só a usada por último recebe o chip "ATUAL"; as outras podem ser encerradas.
    @State private var atualID: String?

    @State private var folhaSenha = false
    @State private var folhaTOTP: BXTOTPSheet.Modo?
    @State private var folhaCelular: BXCelularSheet.Modo?
    @State private var chamado = false

    var body: some View {
        BXPaginaConta(rodape: false, atualizar: { await carregar() }) {
            BXCabecalhoPagina(eyebrow: "Sua conta", titulo: "Segurança.",
                              lead: "Proteja seus pontos e benefícios: senha, verificação em duas etapas e sessões.")
            autenticacao.id("autenticacao")
            cartaoSessoes.id("sessoes")
            cartaoHistorico.id("historico")
            boasPraticas.id("praticas")
        }
        .task { await carregar() }
        .sheet(isPresented: $folhaSenha) { BXTrocarSenhaSheet().bxFolhaConta() }
        .sheet(item: $folhaTOTP) { m in BXTOTPSheet(modo: m) { Task { await recarregarHistorico() } }.bxFolhaConta() }
        .sheet(item: $folhaCelular) { m in BXCelularSheet(modo: m) { Task { await recarregarHistorico() } }.bxFolhaConta() }
        .sheet(isPresented: $chamado) { BXChamadoSheet(categoria: .fraude).bxFolhaConta() }
        .confirmationDialog("Encerrar esta sessão?", isPresented: Binding(
            get: { confirmarEncerrar != nil }, set: { if !$0 { confirmarEncerrar = nil } }
        ), titleVisibility: .visible, presenting: confirmarEncerrar) { s in
            Button("Encerrar sessão", role: .destructive) { Task { await encerrar(s) } }
            Button("Cancelar", role: .cancel) {}
        } message: { s in
            Text("\(s.nomeDispositivo) vai precisar entrar de novo.")
        }
        .confirmationDialog("Encerrar todas as sessões?", isPresented: $confirmarTodas, titleVisibility: .visible) {
            Button("Encerrar todas", role: .destructive) { Task { await encerrarTodas() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Todos os aparelhos saem da conta, inclusive este. Você vai precisar entrar de novo.")
        }
        .onAppear {
            switch BXDemo.subtela {
            case "senha": folhaSenha = true
            case "totp": folhaTOTP = sessao.usuario?.mfaAtivo == true ? .desativar : .ativar
            case "2fa", "sms": folhaCelular = .ativarSMS
            case "celular": folhaCelular = .celular
            case "todas": confirmarTodas = true
            default: break
            }
        }
    }

    // MARK: Autenticação

    private var autenticacao: some View {
        let u = sessao.usuario
        return BXCartaoConta("Autenticação", subtitulo: "Camadas extras de proteção no acesso à sua conta.") {
            VStack(alignment: .leading, spacing: 18) {
                // Senha
                if u?.temSenha == false {
                    BXLinhaAcaoConta(icone: .chave, titulo: "Senha",
                                     texto: "Sua conta entra pelo Google. Para criar uma senha, use \"Esqueci a senha\" na tela de entrada.") {
                        EmptyView()
                    }
                } else {
                    BXLinhaAcaoConta(icone: .chave, titulo: "Senha", texto: "Mantenha uma senha forte e exclusiva.") {
                        BXBotao("Alterar senha", estilo: .secundario, larguraTotal: false) { folhaSenha = true }
                    }
                }
                BXDivisorConta()

                // 2FA
                BXLinhaAcaoConta(icone: .celular, titulo: "Verificação em duas etapas (2FA)",
                                 texto: u?.mfaAtivo == true
                                    ? "Ativa. Pedimos um código ao entrar e em operações sensíveis."
                                    : "Desligada. Ative por aplicativo autenticador ou por SMS.") {
                    BXStatus(u?.mfaAtivo == true ? "Ativa" : "Inativa", u?.mfaAtivo == true ? .ok : .aviso)
                }
                VStack(spacing: 10) {
                    metodo2FA(titulo: "Aplicativo autenticador", texto: "Código gerado no seu aparelho, sem depender de sinal.",
                              acao: u?.mfaAtivo == true ? "Desativar" : "Ativar") {
                        folhaTOTP = u?.mfaAtivo == true ? .desativar : .ativar
                    }
                    metodo2FA(titulo: "SMS", texto: "Código enviado para o seu celular.",
                              acao: u?.mfaAtivo == true ? "Desativar" : "Ativar") {
                        folhaCelular = u?.mfaAtivo == true ? .desativarSMS : .ativarSMS
                    }
                }
                .padding(.leading, 54)
                BXDivisorConta()

                // Celular
                BXLinhaAcaoConta(icone: .celular, titulo: "Celular",
                                 texto: u?.celularMascarado.map { "\($0). Usado para a verificação por SMS." }
                                    ?? "Nenhum celular cadastrado.") {
                    HStack(spacing: 10) {
                        if u?.celularMascarado != nil {
                            BXBotao("Remover", estilo: .secundario, larguraTotal: false) { folhaCelular = .removerCelular }
                        }
                        BXBotao(u?.celularMascarado == nil ? "Cadastrar" : "Trocar", estilo: .secundario, larguraTotal: false) {
                            folhaCelular = .celular
                        }
                    }
                }
                BXDivisorConta()

                // E-mail
                BXLinhaAcaoConta(icone: .email, titulo: "Confirmação por e-mail",
                                 texto: "Exigida para envios e resgates.") {
                    if u?.emailVerificado == true {
                        BXStatus("Verificado", .ok)
                    } else {
                        HStack(spacing: 10) {
                            BXStatus("Pendente", .aviso)
                            BXBotao("Confirmar", estilo: .secundario, larguraTotal: false) { nav.exigirVerificacaoEmail() }
                        }
                    }
                }
            }
        }
    }

    private func metodo2FA(titulo: String, texto: String, acao: String, executar: @escaping () -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                textoMetodo(titulo, texto).frame(maxWidth: .infinity, alignment: .leading)
                BXBotao(acao, estilo: .secundario, larguraTotal: false, acao: executar)
            }
            VStack(alignment: .leading, spacing: 8) {
                textoMetodo(titulo, texto)
                BXBotao(acao, estilo: .secundario, larguraTotal: false, acao: executar)
            }
        }
        .padding(12)
        .background(BXCor.superficie2, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
    }

    private func textoMetodo(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo).bxFonte(.valorDado).foregroundStyle(BXCor.tinta)
            Text(texto).bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Sessões

    private var cartaoSessoes: some View {
        BXCartaoConta("Sessões ativas", subtitulo: "Aparelhos conectados à sua conta agora.") {
            switch sessoes {
            case .ocioso, .carregando:
                VStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { _ in BXEsqueleto(.bloco(altura: 54)) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Carregando sessões")
            case .erro(let e):
                BXEstadoErro(e) { await recarregarSessoes() }
            case .vazio:
                Text("Nenhuma outra sessão ativa.").bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            case .pronto(let lista):
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lista.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { BXDivisorConta() }
                        linhaSessao(s).padding(.vertical, 14)
                    }
                }
                BXBotao("Encerrar todas as sessões", estilo: .preto, carregando: encerrandoTodas) { confirmarTodas = true }
                    .padding(.top, 4)
            }
        }
    }

    private func linhaSessao(_ s: BXSessaoDispositivo) -> some View {
        let quando: String = ehAtual(s) ? "Este aparelho · agora"
            : "Último acesso · \(s.ultimoUso.map { BXFormato.relativo($0) } ?? "—")"
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                textoSessao(s, quando).frame(maxWidth: .infinity, alignment: .leading)
                controleSessao(s)
            }
            VStack(alignment: .leading, spacing: 10) {
                textoSessao(s, quando)
                controleSessao(s)
            }
        }
        .contextMenu {
            if !ehAtual(s) {
                Button("Encerrar sessão", role: .destructive) { confirmarEncerrar = s }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Encerrar sessão") { if !ehAtual(s) { confirmarEncerrar = s } }
    }

    private func textoSessao(_ s: BXSessaoDispositivo, _ quando: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.nomeDispositivo).bxFonte(.item).foregroundStyle(BXCor.tinta)
                .fixedSize(horizontal: false, vertical: true)
            Text([quando, s.ipMascarado.map { "IP \($0)" }].compactMap { $0 }.joined(separator: " · "))
                .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ehAtual(_ s: BXSessaoDispositivo) -> Bool { s.id == atualID }

    @ViewBuilder private func controleSessao(_ s: BXSessaoDispositivo) -> some View {
        if ehAtual(s) {
            BXChip("● Atual", .neon)
        } else {
            BXBotao("Encerrar", estilo: .secundario, carregando: encerrando == s.id, larguraTotal: false) {
                confirmarEncerrar = s
            }
        }
    }

    // MARK: Histórico

    private var cartaoHistorico: some View {
        BXCartaoConta("Histórico de acesso", subtitulo: "Entradas e mudanças de segurança na sua conta.") {
            switch historico {
            case .ocioso, .carregando:
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in BXEsqueleto(.linhaExtrato) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Carregando histórico")
            case .erro(let e):
                BXEstadoErro(e) { await recarregarHistorico() }
            case .vazio:
                Text("Nenhum acesso registrado ainda.").bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            case .pronto(let lista):
                let visiveis = verHistoricoTodo ? lista : Array(lista.prefix(8))
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visiveis.enumerated()), id: \.offset) { i, ev in
                        if i > 0 { BXDivisorConta() }
                        linhaEvento(ev).padding(.vertical, 12)
                    }
                }
                if lista.count > 8 {
                    BXLinkSeta(verHistoricoTodo ? "Mostrar menos" : "Ver todos (\(lista.count))") {
                        withAnimation(BXMovimento.ease) { verHistoricoTodo.toggle() }
                    }
                }
                Text("Não reconhece algum acesso? Troque a senha e encerre todas as sessões.")
                    .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func linhaEvento(_ ev: BXEventoAcesso) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BXIcone(ev.falhou ? .alerta : .check, tamanho: .atalho)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(ev.rotulo).bxFonte(.valorDado).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                let detalhe = [ev.dispositivo, ev.ipMascarado.map { "IP \($0)" }].compactMap { $0 }.filter { !$0.isEmpty }
                if !detalhe.isEmpty {
                    Text(detalhe.joined(separator: " · ")).bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 4) {
                Text(ev.em.map { BXFormato.relativo($0) } ?? "—").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                if ev.falhou { BXStatus("Atenção", .perigo, ponto: false) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Boas práticas

    private var boasPraticas: some View {
        BXCartaoConta("Boas práticas") {
            VStack(alignment: .leading, spacing: 0) {
                pratica("Nunca compartilhe códigos", "A BlaXx nunca pede o código de verificação por telefone, WhatsApp ou e-mail.")
                BXDivisorConta()
                pratica("Use uma senha só sua", "Não repita a senha de outros serviços. Se desconfiar de algo, troque a senha.")
                BXDivisorConta()
                VStack(alignment: .leading, spacing: 8) {
                    pratica("Desconfie de links", "Suspeita de fraude? Abra um chamado imediatamente.")
                    BXLinkSeta("Abrir um chamado") { chamado = true }
                        .padding(.leading, 54)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private func pratica(_ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            BXIcone(.visto, tamanho: .cartao).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo).bxFonte(.item).foregroundStyle(BXCor.tinta)
                Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rede

    private func carregar() async {
        async let a: Void = recarregarSessoes()
        async let b: Void = recarregarHistorico()
        async let c: Void = sessao.recarregarUsuario()
        _ = await (a, b, c)
    }

    private func recarregarSessoes() async {
        do {
            let l = try await BXAPI.shared.sessoes()
            let ordenada = l.sorted { ($0.atual ? 1 : 0, $0.ultimoUso ?? .distantPast) > ($1.atual ? 1 : 0, $1.ultimoUso ?? .distantPast) }
            atualID = ordenada.first(where: \.atual)?.id
            sessoes = ordenada.isEmpty ? .vazio : .pronto(ordenada)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if case .pronto = sessoes { return }
            sessoes = .erro(BXErro.de(error))
        }
    }

    private func recarregarHistorico() async {
        do {
            let l = try await BXAPI.shared.historicoAcesso(limite: 50)
            historico = l.isEmpty ? .vazio : .pronto(l)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if case .pronto = historico { return }
            historico = .erro(BXErro.de(error))
        }
    }

    private func encerrar(_ s: BXSessaoDispositivo) async {
        encerrando = s.id
        defer { encerrando = nil }
        do {
            try await BXAPI.shared.encerrarSessao(id: s.id)
            BXHaptica.tocar(.sucesso)
            if case .pronto(let l) = sessoes {
                let resto = l.filter { $0.id != s.id }
                withAnimation(BXMovimento.ease) { sessoes = resto.isEmpty ? .vazio : .pronto(resto) }
            }
            toast.mostrar("Sessão encerrada.", .sucesso)
            await recarregarHistorico()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            if e.tipo == .naoEncontrado { await recarregarSessoes(); return }
            toast.mostrar(e.mensagemParaUsuario, .erro)
        }
    }

    private func encerrarTodas() async {
        encerrandoTodas = true
        defer { encerrandoTodas = false }
        do {
            try await BXAPI.shared.encerrarTodasAsSessoes()
            BXHaptica.tocar(.sucesso)
            sessao.sessaoRevogada(motivo: "Todas as sessões foram encerradas. Entre de novo.")
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            toast.mostrar(BXErro.de(error).mensagemParaUsuario, .erro)
        }
    }
}

extension BXTOTPSheet.Modo: Identifiable { var id: Self { self } }
extension BXCelularSheet.Modo: Identifiable { var id: Self { self } }
