//
//  BXPerfilTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Perfil (WEB/perfil.html, fotos 33): "SUA CONTA" / "Perfil." · cartão do usuário (avatar 86, nome,
//  e-mail, CLIENTE/CLIENTE VIP, Saldo · Em processamento · Nível, "Configurações de segurança →") ·
//  Dados pessoais (só leitura: o backend não tem edição de perfil) · links da conta · Zona de risco
//  (Sair da conta de verdade, Excluir minha conta) · versão do app.
//  Fora, por regra do dono: "Chave para resgates" (pix_key), interruptores de preferência sem endpoint.
//

import SwiftUI

struct BXPerfilTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast

    @State private var cartao: BXCartaoEstado?
    @State private var erroUsuario: BXErro?
    @State private var confirmarSair = false
    @State private var excluir = false
    @State private var chamado = false

    var body: some View {
        BXPaginaConta(atualizar: { await recarregar(forcar: true) }) {
            BXCabecalhoPagina(eyebrow: "Sua conta", titulo: "Perfil.",
                              lead: "Seus dados, sua segurança e a sua privacidade, em um lugar só.")
            if let u = sessao.usuario {
                cartaoUsuario(u)
                dadosPessoais(u).id("dados")
                links
                zonaRisco.id("risco")
            } else if let erroUsuario {
                BXEstadoErro(erroUsuario) { await recarregar(forcar: true) }
            } else {
                VStack(spacing: 16) {
                    BXEsqueleto(.bloco(altura: 330))
                    BXEsqueleto(.bloco(altura: 360))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Carregando")
            }
            Text("BlaXx Pontos para iOS · versão \(BXInfoAppConta.versao)")
                .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .task { await recarregar(forcar: false) }
        .confirmationDialog("Sair da conta?", isPresented: $confirmarSair, titleVisibility: .visible) {
            Button("Sair", role: .destructive) { Task { await sessao.sair() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Você vai precisar entrar de novo neste aparelho.")
        }
        .sheet(isPresented: $excluir) { BXExcluirContaSheet().bxFolhaConta() }
        .sheet(isPresented: $chamado) { BXChamadoSheet(categoria: .conta).bxFolhaConta() }
        .onAppear {
            switch BXDemo.subtela {
            case "excluir": excluir = true
            case "chamado": chamado = true
            case "sair": confirmarSair = true
            default: break
            }
        }
    }

    // MARK: Cartão do usuário

    private func cartaoUsuario(_ u: BXUsuario) -> some View {
        VStack(spacing: 14) {
            BXAvatar(inicial: u.inicial, tamanho: 86, anel: false)
            VStack(spacing: 6) {
                Text(u.nome.isEmpty ? "Sua conta" : u.nome)
                    .bxFonte(.tituloConvite).foregroundStyle(BXCor.tinta)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(u.email).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            BXChip(u.ehVIP ? "Cliente VIP" : "Cliente", .preto)
            BXDivisorConta().padding(.vertical, 4)
            numeros
            BXBotao("Configurações de segurança →", estilo: .secundario) { nav.ir(.seguranca) }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BXEspaco.cartao)
        .padding(.vertical, 24)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha, sombra: .leve)
    }

    @ViewBuilder private var numeros: some View {
        let saldo = sessao.carteira.map { BXFormato.pontos($0.saldo) } ?? "—"
        let pendente = sessao.carteira.map { BXFormato.pontos($0.emProcessamento) } ?? "—"
        let grade = Group {
            BXNumeroConta(valor: saldo, rotulo: "Saldo",
                          falado: sessao.carteira.map { BXFormato.pontosFalados($0.saldo) })
            BXNumeroConta(valor: pendente, rotulo: "Em processamento",
                          falado: sessao.carteira.map { BXFormato.pontosFalados($0.emProcessamento) })
            BXNumeroConta(valor: cartao?.nivel?.nome ?? "—", rotulo: "Nível")
        }
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 8) { grade }
            VStack(spacing: 14) { grade }
        }
    }

    // MARK: Dados pessoais

    private func dadosPessoais(_ u: BXUsuario) -> some View {
        BXCartaoConta("Dados pessoais") {
            VStack(alignment: .leading, spacing: 14) {
                BXLinhaDadoConta("Nome completo", u.nome.isEmpty ? "Não informado" : u.nome)
                BXDivisorConta()
                BXLinhaDadoConta("E-mail", u.email) {
                    if u.emailVerificado {
                        BXStatus("Verificado", .ok)
                    } else {
                        Button { nav.exigirVerificacaoEmail() } label: {
                            BXStatus("Pendente · confirmar agora", .aviso)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Abre a confirmação do e-mail")
                    }
                }
                BXDivisorConta()
                BXLinhaDadoConta("Celular", u.celularMascarado ?? "Não cadastrado")
                BXDivisorConta()
                BXLinhaDadoConta("CPF", u.cpfMascarado ?? "Não informado")
                BXDivisorConta()
                BXLinhaDadoConta("Cartão BlaXx", u.cartaoFormatado)
                    .contextMenu {
                        Button("Copiar número") {
                            BXCopiar.copiar(u.cartaoID, aviso: "Número do Cartão BlaXx copiado.", toast: toast)
                        }
                    }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Para alterar seus dados, fale com o suporte.")
                        .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                    BXLinkSeta("Abrir chamado") { chamado = true }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BXCor.superficie2, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
            }
        }
    }

    // MARK: Links

    private var links: some View {
        BXCartaoConta("Configurações") {
            VStack(spacing: 6) {
                BXLinhaLinkConta(icone: .seguranca, titulo: "Segurança",
                                 texto: "Senha, verificação em duas etapas e sessões.") { nav.ir(.seguranca) }
                BXDivisorConta()
                BXLinhaLinkConta(icone: .documento, titulo: "Privacidade e dados",
                                 texto: "Consentimentos, cópia dos seus dados e exclusão da conta.") { nav.ir(.privacidade) }
                BXDivisorConta()
                BXLinhaLinkConta(icone: .notificacoes, titulo: "Notificações",
                                 texto: "Tudo que aconteceu na sua conta.") { nav.ir(.notificacoes) }
                if BXRecursos.convidarAmigos {
                    BXDivisorConta()
                    BXLinhaLinkConta(icone: .indique, titulo: "Convidar amigos",
                                     texto: "Compartilhe o convite da BlaXx.") { nav.ir(.convidar) }
                }
                BXDivisorConta()
                BXLinhaLinkConta(icone: .ajuda, titulo: "Central de ajuda",
                                 texto: "Perguntas frequentes e chamados.") { nav.ir(.ajuda) }
            }
        }
    }

    // MARK: Zona de risco

    private var zonaRisco: some View {
        BXCartaoConta("Zona de risco", perigo: true) {
            VStack(alignment: .leading, spacing: 16) {
                linhaRisco(titulo: "Sair da conta", texto: "Encerra a sessão neste aparelho.") {
                    BXBotao("Sair", estilo: .secundario, carregando: sessao.saindo, larguraTotal: false) {
                        confirmarSair = true
                    }
                }
                BXDivisorConta()
                linhaRisco(titulo: "Excluir minha conta",
                           texto: "Apaga seus dados pessoais conforme a LGPD. Você perde o acesso ao saldo de pontos.") {
                    BXBotao("Excluir", estilo: .perigo, larguraTotal: false) { excluir = true }
                }
            }
        }
    }

    private func linhaRisco<B: View>(titulo: String, texto: String, @ViewBuilder botao: () -> B) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                textoRisco(titulo, texto).frame(maxWidth: .infinity, alignment: .leading)
                botao()
            }
            VStack(alignment: .leading, spacing: 10) {
                textoRisco(titulo, texto)
                botao()
            }
        }
    }

    private func textoRisco(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).bxFonte(.item).foregroundStyle(BXCor.tinta)
            Text(texto).bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Carga

    private func recarregar(forcar: Bool) async {
        if sessao.usuario == nil || forcar {
            erroUsuario = nil
            do {
                _ = try await BXAPI.shared.eu()
                await sessao.recarregarUsuario()
            } catch {
                guard !BXErro.ehCancelamento(error) else { return }
                if sessao.usuario == nil { erroUsuario = BXErro.de(error) }
            }
        }
        if forcar || sessao.carteira == nil { await sessao.recarregarCarteira() }
        if let c = try? await BXAPI.shared.cartao() { cartao = c }
    }
}
