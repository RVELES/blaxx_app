//
//  BXPrivacidadeTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Privacidade e dados (LGPD; o web não tem página própria, a spec pede esta tela, §2.1 linha 31):
//  Consentimentos (GET/POST/DELETE /privacy/consents; o servidor guarda o histórico, então o estado de
//  cada tipo é o registro mais recente; só ofertas e cookies podem ser revogados) · Seus dados
//  (GET /auth/account/export → arquivo JSON por compartilhamento; o conteúdo NÃO é exibido) ·
//  Documentos (site) · Zona de risco (Excluir minha conta).
//

import SwiftUI

struct BXPrivacidadeTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast

    @State private var consentimentos: BXCarga<[BXConsentimento]> = .carregando
    @State private var alterando: String?
    @State private var exportando = false
    @State private var arquivo: URL?
    @State private var erroExportar: String?
    @State private var excluir = false

    /// Tipos mostrados, na ordem da tela.
    private static let tipos = ["terms", "privacy", "lgpd", "marketing", "cookies_analytics", "cookies_marketing"]

    var body: some View {
        BXPaginaConta(atualizar: { await carregar() }) {
            BXCabecalhoPagina(eyebrow: "Sua conta", titulo: "Privacidade e dados.",
                              lead: "O que você autorizou, uma cópia dos seus dados e a exclusão da conta, conforme a LGPD.")
            cartaoConsentimentos.id("consentimentos")
            cartaoDados.id("dados")
            cartaoDocumentos
            zonaRisco.id("excluir")
        }
        .task { await carregar() }
        .sheet(isPresented: $excluir) { BXExcluirContaSheet().bxFolhaConta() }
        .onAppear { if BXDemo.subtela == "excluir" { excluir = true } }
    }

    // MARK: Consentimentos

    /// Registro mais recente por tipo (a lista do servidor vem do mais novo para o mais antigo).
    private func estadoAtual(_ lista: [BXConsentimento]) -> [String: BXConsentimento] {
        var r: [String: BXConsentimento] = [:]
        let ordenada = lista.sorted { ($0.aceitoEm ?? .distantPast) > ($1.aceitoEm ?? .distantPast) }
        for c in ordenada where r[c.tipo] == nil { r[c.tipo] = c }
        return r
    }

    private var cartaoConsentimentos: some View {
        BXCartaoConta("Consentimentos", subtitulo: "O que você autorizou e quando.") {
            switch consentimentos {
            case .ocioso, .carregando:
                VStack(spacing: 12) { ForEach(0..<4, id: \.self) { _ in BXEsqueleto(.bloco(altura: 48)) } }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Carregando consentimentos")
            case .erro(let e):
                BXEstadoErro(e) { await carregar() }
            case .vazio, .pronto:
                let atual = estadoAtual(consentimentos.valor ?? [])
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(Self.tipos.enumerated()), id: \.element) { i, tipo in
                        if i > 0 { BXDivisorConta() }
                        linhaConsentimento(tipo: tipo, registro: atual[tipo]).padding(.vertical, 12)
                    }
                }
                Text("Termos de uso, política de privacidade e LGPD sustentam a conta. Para retirar esses consentimentos, é preciso excluir a conta.")
                    .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func linhaConsentimento(tipo: String, registro: BXConsentimento?) -> some View {
        let rotulo = BXSanitizador.rotulo(consentimento: tipo)
        let ativo = registro?.ativo ?? false
        let revogavel = ["marketing", "cookies_analytics", "cookies_marketing"].contains(tipo)
        let detalhe: String = {
            guard let r = registro else { return revogavel ? "Não autorizado" : "Sem registro" }
            let quando = r.aceitoEm.map { BXFormato.data($0) } ?? "—"
            let versao = r.versao.map { "Versão \($0) · " } ?? ""
            return r.ativo ? "\(versao)aceito em \(quando)" : "Revogado em \(quando)"
        }()
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rotulo).bxFonte(.item).foregroundStyle(BXCor.tinta)
                Text(detalhe).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if revogavel {
                if alterando == tipo {
                    ProgressView().tint(BXCor.tinta).frame(width: 46)
                } else {
                    Toggle(rotulo, isOn: Binding(get: { ativo }, set: { novo in
                        Task { await alternar(tipo: tipo, ligar: novo, registro: registro) }
                    }))
                    .toggleStyle(BXInterruptorEstilo())
                    .labelsHidden()
                }
            } else {
                BXStatus(ativo ? "Ativo" : "Pendente", ativo ? .ok : .aviso)
            }
        }
        .accessibilityElement(children: revogavel ? .contain : .combine)
    }

    // MARK: Seus dados

    private var cartaoDados: some View {
        BXCartaoConta("Seus dados", subtitulo: "Leve uma cópia de tudo o que a BlaXx guarda sobre você.") {
            VStack(alignment: .leading, spacing: 14) {
                BXLinhaAcaoConta(icone: .anexo, titulo: "Exportar meus dados",
                                 texto: "Arquivo JSON com cadastro, extrato, resgates, avisos e consentimentos (LGPD, art. 18).") {
                    if let arquivo {
                        ShareLink(item: arquivo, preview: SharePreview("Meus dados BlaXx")) {
                            Text("Compartilhar arquivo →").bxFonte(.botao)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(BXEstiloBotao(estilo: .primario))
                    } else {
                        BXBotao("Preparar arquivo", estilo: .secundario, carregando: exportando) { Task { await exportar() } }
                    }
                }
                if let erroExportar { BXAvisoErroConta(texto: erroExportar) }
                if arquivo != nil {
                    Text("O arquivo fica só neste aparelho até você compartilhar. Guarde em lugar seguro: ele traz dados pessoais.")
                        .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Documentos

    private var cartaoDocumentos: some View {
        BXCartaoConta("Documentos") {
            VStack(spacing: 6) {
                BXLinhaLinkConta(icone: .documento, titulo: "Termos de uso") { nav.abrirSite("termos.html") }
                BXDivisorConta()
                BXLinhaLinkConta(icone: .seguranca, titulo: "Política de privacidade") { nav.abrirSite("privacidade.html") }
                BXDivisorConta()
                BXLinhaLinkConta(icone: .prancheta, titulo: "Regulamento do programa") { nav.abrirSite("regulamento.html") }
            }
        }
    }

    // MARK: Zona de risco

    private var zonaRisco: some View {
        BXCartaoConta("Zona de risco", perigo: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Excluir a conta apaga seus dados pessoais e encerra o acesso ao saldo de pontos. Não dá para desfazer.")
                    .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
                BXBotao("Excluir minha conta", estilo: .perigo) { excluir = true }
            }
        }
    }

    // MARK: Rede

    private func carregar() async {
        do {
            let l = try await BXAPI.shared.consentimentos()
            consentimentos = l.isEmpty ? .vazio : .pronto(l)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if consentimentos.valor != nil { return }
            consentimentos = .erro(BXErro.de(error))
        }
    }

    private func alternar(tipo: String, ligar: Bool, registro: BXConsentimento?) async {
        alterando = tipo
        defer { alterando = nil }
        do {
            if ligar {
                let versao = (try? await BXAPI.shared.versaoTermos()) ?? "1.0"
                try await BXAPI.shared.registrarConsentimento(tipo: tipo, versao: versao)
                toast.mostrar("\(BXSanitizador.rotulo(consentimento: tipo)): autorizado.", .sucesso)
            } else if let registro, registro.ativo {
                try await BXAPI.shared.revogarConsentimento(id: registro.id)
                toast.mostrar("\(BXSanitizador.rotulo(consentimento: tipo)): revogado.", .info)
            }
            BXHaptica.tocar(.selecao)
            await carregar()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            toast.mostrar(BXErro.de(error).mensagemParaUsuario, .erro)
        }
    }

    private func exportar() async {
        erroExportar = nil
        exportando = true
        defer { exportando = false }
        do {
            let dados = try await BXAPI.shared.exportarDados()
            let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("bx-exportacao", isDirectory: true)
            try? FileManager.default.removeItem(at: pasta)
            try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
            let url = pasta.appendingPathComponent("blaxx-meus-dados-\(BXFormato.data(.now).replacingOccurrences(of: "/", with: "-")).json")
            try dados.write(to: url, options: [.atomic, .completeFileProtection])
            withAnimation(BXMovimento.ease) { arquivo = url }
            BXHaptica.tocar(.sucesso)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            BXHaptica.tocar(.erro)
            erroExportar = BXErro.de(error).mensagemParaUsuario
        }
    }
}
