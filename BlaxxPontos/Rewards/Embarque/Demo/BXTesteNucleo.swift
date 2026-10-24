//
//  BXTesteNucleo.swift
//  BlaxxPontos · Teste do núcleo de rede e sessão · SÓ DEBUG
//
//  Prova login real + carteira + leituras principais contra o backend LOCAL (nunca produção):
//    xcrun simctl launch --console-pty <sim> Blaxx-Pontos-Inc.BlaxxPontos -BXGaleria YES -BXTesteNucleo YES \
//      -blaxx_backend_url http://127.0.0.1:5050 -BXTesteLogin <e-mail de seed.py> -BXTesteSenha <senha de seed.py>
//  Recusa qualquer URL que não seja 127.0.0.1/localhost. Credenciais só por argumento (nada no código).
//  Linhas "[BXTesteNucleo] …" no console e em Library/Caches/bx-teste-nucleo.log do app.
//  Quem chama: a galeria (`.task`). A casca (G1) pode chamar também: `await BXTesteNucleo.rodarSePedido()`.
//

#if DEBUG
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor enum BXTesteNucleo {
    private static var rodou = false
    private static var linhas: [String] = []
    private static var falhas = 0

    static func rodarSePedido() async {
        guard BXDemo.testeNucleo, !rodou else { return }
        rodou = true
        await rodar()
    }

    private static func log(_ s: String) {
        let l = "[BXTesteNucleo] \(s)"
        print(l)
        linhas.append(l)
    }

    private static func confere(_ ok: Bool, _ s: String) {
        if !ok { falhas += 1 }
        log((ok ? "ok    " : "FALHOU ") + s)
    }

    private static func argumento(_ k: String) -> String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: k), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    private static func rodar() async {
        if BXDemo.ativo { await rodarDemo(); return }
        if ProcessInfo.processInfo.arguments.contains("-BXTesteGoogle") { await rodarGoogle(); return }
        let base = BXAmbiente.urlBase
        log("backend: \(base.absoluteString)")
        guard ["127.0.0.1", "localhost", "::1"].contains(base.host ?? ""), !BXDemo.ativo, !BXDemo.visitante else {
            log("RECUSADO: o teste só roda contra o backend local, fora do modo demonstração.")
            return
        }
        guard let login = argumento("-BXTesteLogin"), let senha = argumento("-BXTesteSenha") else {
            log("RECUSADO: passe -BXTesteLogin e -BXTesteSenha (conta de seed.py).")
            return
        }
        let api = BXAPI.shared
        await api.esquecerSessao()

        // 1. Sessão nasce visitante sem tokens.
        let sessao = BXSessao()
        await sessao.iniciar()
        confere(sessao.estado == .visitante, "iniciar sem tokens → visitante")

        // 2. Credencial inválida: 401 sem derrubar nada (conta inexistente, não mexe no bloqueio de ninguém).
        switch await sessao.entrar(login: "naoexiste.teste-nucleo@exemplo.test", senha: "x", mfa: nil) {
        case .failure(let e): confere(e.tipo == .naoAutorizado, "login inválido → .naoAutorizado (\(e.status)) “\(e.mensagemParaUsuario)”")
        case .success: confere(false, "login inválido deveria falhar")
        }

        // 3. Login real.
        switch await sessao.entrar(login: login, senha: senha, mfa: nil) {
        case .success(.ok(_, let u)):
            confere(sessao.estado == .logado, "login real → logado como \(u.primeiroNome ?? "?") · cartão \(u.cartaoID) · e-mail verificado: \(u.emailVerificado)")
        case .success(let outro): confere(false, "login pediu 2FA: \(outro)"); return
        case .failure(let e): confere(false, "login real falhou: \(e.tipo) \(e.status) \(e.mensagemParaUsuario)"); return
        }

        // 4. Carteira (via sessão e direto).
        if let c = sessao.carteira {
            confere(true, "carteira (sessão): saldo \(BXFormato.pontos(c.saldo)) pts · em processamento \(BXFormato.pontos(c.emProcessamento))")
        } else {
            confere(false, "carteira (sessão) vazia: \(String(describing: sessao.erroCarteira))")
        }
        do {
            let c = try await api.carteira()
            confere(true, "GET /wallet/ → saldo \(BXFormato.pontos(c.saldo)) pts")
        } catch { confere(false, "GET /wallet/ → \(BXErro.de(error).tipo)") }

        // 5. Leituras autenticadas e públicas.
        await passo("GET /wallet/transactions") { let l = try await api.lancamentos(limite: 5); return "\(l.count) itens: " + l.map { "\($0.rotulo) \(BXFormato.pontosSinal($0.pontos))" }.joined(separator: ", ") }
        await passo("GET /card/") { let c = try await api.cartao(); return "\(c.cartaoFormatado) · nível \(c.nivel?.nome ?? "—") · próximo \(c.proximoNivel?.nome ?? "—") · \(Int(c.progresso)) %" }
        await passo("GET /card/tiers") { "\(try await api.niveis().map(\.rotuloMinimo).joined(separator: " | "))" }
        await passo("GET /pix/packages") { try await api.pacotes().map { "\($0.rotulo) \(BXFormato.pontos($0.pontos))" }.joined(separator: ", ") }
        await passo("GET /pix/provider") { let p = try await api.provedorPix(); return "\(p.nome) mock=\(p.ehMock)" }
        await passo("GET /partners/") { let p = try await api.parceiros(); return "\(p.count) parceiros visíveis; com descrição segura: \(p.filter { $0.descricaoSegura != nil }.count)" }
        await passo("GET /partners/categories") { "\(try await api.categoriasParceiros().count) categorias" }
        await passo("GET /benefits/") { let b = try await api.beneficios(); return "\(b.count) benefícios visíveis: " + b.prefix(4).map(\.nome).joined(separator: ", ") }
        await passo("GET /vouchers/") { "\(try await api.vouchers().count) vouchers" }
        await passo("GET /campaigns/") { "\(try await api.campanhas().count) campanhas" }
        await passo("GET /notifications/") { let n = try await api.notificacoes(); return "\(n.itens.count) itens, \(n.naoLidas) não lidas" }
        await passo("GET /pix/my-charges") { "\(try await api.minhasCobrancasPix().count) cobranças" }
        await passo("GET /user/sessions") { "\(try await api.sessoes().count) sessões" }
        await passo("GET /user/access-log") { "\(try await api.historicoAcesso(limite: 10).count) eventos" }
        await passo("GET /privacy/consents") { "\(try await api.consentimentos().count) consentimentos" }

        // 6. 401 que NÃO é sessão: senha atual errada mantém o login.
        do {
            try await api.trocarSenha(atual: "senha-errada-teste-nucleo", nova: "OutraSenha!2026x")
            confere(false, "trocar senha com a atual errada deveria falhar")
        } catch {
            let e = BXErro.de(error)
            let aindaTem = await api.temSessao()
            confere(e.tipo == .naoAutorizado && aindaTem && sessao.estado == .logado,
                    "senha atual errada → \(e.tipo) (\(e.status)) e sessão mantida: \(aindaTem)")
        }

        // 7. Renovação (rotação do refresh) e uso do token novo.
        do {
            try await api.renovar()
            let u = try await api.eu()
            confere(true, "POST /auth/refresh + GET /auth/me com o token novo → \(u.primeiroNome ?? "?")")
        } catch { confere(false, "renovação → \(BXErro.de(error).tipo)") }

        // 8. Sair de verdade.
        await sessao.sair()
        let restou = await api.temSessao()
        confere(sessao.estado == .visitante && !restou, "sair → visitante, cofre limpo")
        do {
            _ = try await api.carteira()
            confere(false, "carteira depois de sair deveria falhar")
        } catch { confere(BXErro.de(error).tipo == .sessaoExpirada, "carteira depois de sair → \(BXErro.de(error).tipo)") }

        // 9. Tokens inválidos: renovação falha → cofre limpo (sessão expirada).
        await api.guardar(BXTokens(acesso: "invalido", renovacao: "invalido"))
        do {
            _ = try await api.eu()
            confere(false, "tokens inválidos deveriam falhar")
        } catch {
            let limpo = !(await api.temSessao())
            confere(BXErro.de(error).tipo == .sessaoExpirada && limpo, "tokens inválidos → \(BXErro.de(error).tipo), cofre limpo: \(limpo)")
        }

        log(falhas == 0 ? "RESULTADO: OK" : "RESULTADO: \(falhas) FALHA(S)")
        gravarArquivo()
    }

    /// Com `-BXTesteGoogle`: abre a folha do Google (ASWebAuthenticationSession + PKCE) e registra o desfecho.
    /// O login Google real exige a conta do dono: o teste só vai até abrir a folha e cancelar.
    private static func rodarGoogle() async {
        log("login com Google: abrindo a folha (cancele para concluir o teste)")
        #if canImport(UIKit)
        // A folha só abre com a cena ativa (no `.task` da abertura ela ainda está entrando).
        for _ in 0..<50 where UIApplication.shared.applicationState != .active {
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .seconds(1))
        #endif
        let sessao = BXSessao()
        await sessao.iniciar()
        do {
            try await sessao.entrarComGoogle()
            log("ok    Google concluído (inesperado neste teste) → \(sessao.estado)")
        } catch is CancellationError {
            confere(sessao.estado != .logado && !sessao.entrando, "cancelado pelo usuário → CancellationError (a tela não mostra erro), estado \(sessao.estado)")
        } catch {
            let e = BXErro.de(error)
            confere(false, "Google → \(e.tipo) “\(e.mensagemParaUsuario)”")
        }
        log(falhas == 0 ? "RESULTADO: OK" : "RESULTADO: \(falhas) FALHA(S)")
        gravarArquivo()
    }

    /// Com `-BXDemo YES`: prova o transporte de demonstração (zero rede) e as armadilhas do sanitizador (§4.3).
    private static func rodarDemo() async {
        log("modo demonstração (transporte falso, zero rede)")
        let api = BXAPI.shared
        let sessao = BXSessao()
        await sessao.iniciar()
        confere(sessao.estado == .logado && sessao.usuario?.cartaoID == "DE0A11C2", "sessão demo → logado, cartão \(sessao.usuario?.cartaoFormatado ?? "?")")
        confere(sessao.carteira?.saldo == 32_480 && sessao.carteira?.emProcessamento == 1_000, "carteira demo 32.480 / 1.000")
        confere(sessao.naoLidas == 2, "não lidas = 2")
        await passo("parceiros sem o de exemplo") {
            let p = try await api.parceiros()
            guard !p.contains(where: { $0.nome == "Loja Exemplo" }) else { throw BXErro(tipo: .validacao) }
            guard let teste = p.first(where: { $0.nome == "Mercado Teste" }), teste.descricaoSegura == nil else { throw BXErro(tipo: .validacao) }
            return "\(p.count) parceiros; parceiro de exemplo escondido; descrição proibida apagada"
        }
        await passo("benefícios sem o do parceiro de exemplo") {
            let b = try await api.beneficios()
            guard !b.contains(where: { $0.parceiroID == "loja-exemplo" }) else { throw BXErro(tipo: .validacao) }
            return "\(b.count) benefícios; esgotado: \(b.filter(\.esgotado).map(\.nome).joined())"
        }
        await passo("parceiro de exemplo → não encontrado") {
            do { _ = try await api.parceiro(id: "loja-exemplo"); throw BXErro(tipo: .validacao) }
            catch let e as BXErro where e.tipo == .naoEncontrado { return "ok" }
        }
        await passo("extrato sem descrição crua") {
            let l = try await api.lancamentos()
            let crus = l.compactMap(\.detalhe).filter { $0.localizedCaseInsensitiveContains("pix") || $0.contains("(pending)") }
            guard crus.isEmpty else { throw BXErro(tipo: .validacao) }
            return "\(l.count) lançamentos; rótulos: " + Set(l.map(\.rotulo)).sorted().joined(separator: ", ")
        }
        await passo("notificações filtradas") {
            let n = try await api.notificacoes()
            let corpos = n.itens.compactMap(\.corpoSeguro)
            guard !corpos.contains(where: { $0.localizedCaseInsensitiveContains("pix") || $0.contains("R$") }) else { throw BXErro(tipo: .validacao) }
            return "\(n.itens.count) itens, \(n.naoLidas) não lidas, \(corpos.count) corpos seguros"
        }
        await passo("campanhas sem R$") {
            let c = try await api.campanhas()
            guard !c.contains(where: { ($0.descricaoSegura ?? "").contains("R$") }) else { throw BXErro(tipo: .validacao) }
            return c.map { "\($0.nomeSeguro) +\(BXFormato.pontos($0.pontosRecompensa))" }.joined(separator: ", ")
        }
        if BXDemo.estado == "pixIndisponivel" {
            await passo("compra PIX com provedor fora (D01)") {
                do { _ = try await api.criarCobrancaPix(pacote: "plus"); throw BXErro(tipo: .validacao) }
                catch let e as BXErro where e.tipo == .pagamentoIndisponivel { return "“\(e.mensagemParaUsuario)”" }
            }
            log(falhas == 0 ? "RESULTADO: OK" : "RESULTADO: \(falhas) FALHA(S)")
            gravarArquivo()
            return
        }
        await passo("compra PIX demo (pendente → paga na 3ª consulta)") {
            let c = try await api.criarCobrancaPix(pacote: "plus")
            _ = try await api.cobrancaPix(id: c.id); _ = try await api.cobrancaPix(id: c.id)
            let paga = try await api.cobrancaPix(id: c.id)
            guard paga.status == .paga else { throw BXErro(tipo: .validacao) }
            return "\(BXFormato.dinheiro(c.valor)) → \(BXFormato.pontos(c.pontos)) pts"
        }
        await passo("envio + desfazer") {
            let chave = BXChaveIdempotencia()
            let e = try await api.enviar(BXPedidoEnvio(para: "amigo@exemplo.test", pontos: 500, senha: "x"), chave: chave)
            let replay = try await api.enviar(BXPedidoEnvio(para: "amigo@exemplo.test", pontos: 500, senha: "x"), chave: chave)
            guard replay.id == e.id else { throw BXErro(tipo: .validacao) }
            let cancelado = try await api.cancelarEnvio(id: e.id)
            return "\(e.comprovante) cancelável \(e.cancelavel), mesma chave → mesmo envio, cancelado: \(cancelado.cancelado)"
        }
        await passo("envio repetido → 409 conflito") {
            do { _ = try await api.enviar(BXPedidoEnvio(para: "repetido@exemplo.test", pontos: 500, senha: "x"), chave: .init()); throw BXErro(tipo: .validacao) }
            catch let e as BXErro where e.tipo == .conflito { return e.extras["previous_transfer_id"] ?? "" }
        }
        await passo("resgate idempotente") {
            let k = BXChaveIdempotencia()
            let v = try await api.resgatarBeneficio(id: "b-cafe-expresso", chave: k)
            let v2 = try await api.resgatarBeneficio(id: "b-cafe-expresso", chave: k)
            guard v.id == v2.id else { throw BXErro(tipo: .validacao) }
            return "voucher \(v.codigo)"
        }
        await passo("esgotado → 409 semEstoque") {
            do { _ = try await api.resgatarBeneficio(id: "b-escalada", chave: .init()); throw BXErro(tipo: .validacao) }
            catch let e as BXErro where e.tipo == .semEstoque { return e.mensagemParaUsuario }
        }
        await passo("cartão BlaXx sem perks/cores da API") {
            let c = try await api.cartao()
            return "\(c.nivel?.nome ?? "—") → \(c.proximoNivel?.nome ?? "—"), faltam \(BXFormato.pontos(c.faltam)), \(c.niveis.count) níveis"
        }
        log(falhas == 0 ? "RESULTADO: OK" : "RESULTADO: \(falhas) FALHA(S)")
        gravarArquivo()
    }

    private static func passo(_ nome: String, _ f: () async throws -> String) async {
        do { confere(true, "\(nome) → \(try await f())") }
        catch { let e = BXErro.de(error); confere(false, "\(nome) → \(e.tipo) (\(e.status))") }
    }

    private static func gravarArquivo() {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        try? (linhas.joined(separator: "\n") + "\n").write(to: dir.appendingPathComponent("bx-teste-nucleo.log"), atomically: true, encoding: .utf8)
    }
}
#endif
