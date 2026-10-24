# 06 · Núcleo de rede e sessão, modo demonstração e esqueletos (G0, parte 2)

Data: 22/10/2026 · Base: `04-spec-redesenho.md` §1.7, §1.8, §4 e §6 · Complementa `05-fundacao.md` (design system).
Build Debug e Release verdes (iPhone 17 Pro, iOS 27, `SCRATCH/dd-nucleo` e `dd-nucleo-rel`), **zero aviso** em
`R/Embarque/` e `R/Telas/`. Release sem nada de demonstração (`strings` = 0). Teste real contra o backend
**local** passou (§7). Nenhum POST/PUT/DELETE em produção, nenhum commit/push.

Caminhos: `R/` = `blaxx_app/BlaxxPontos/BlaxxPontos/Rewards/`.

---

## 1. Arquivos

```
R/Embarque/Nucleo/BXAmbiente.swift      URL base (Release = produção; DEBUG: -BXBackend > UserDefaults "blaxx_backend_url"), BXRecursos
R/Embarque/Nucleo/BXCofre.swift         BXTokens + actor BXCofre (Keychain "com.blaxx.pontos.sessao.v2"; memória em demo)
R/Embarque/Nucleo/BXErro.swift          BXErro (+ contexto, ehSessao, problemasSeguros, BXErro.de(_:), ehCancelamento)
R/Embarque/Nucleo/BXAPI.swift           actor BXAPI, BXRequisicao, BXChaveIdempotencia, BXTransporte(Real), mapa de erros
R/Embarque/Nucleo/BXAPI+Rotas.swift     todas as rotas (§3)
R/Embarque/Nucleo/BXModelos.swift       DTOs sanitizados + pedidos (BXCadastro, BXPedidoEnvio, BXPedidoCartao)
R/Embarque/Nucleo/BXSanitizador.swift   filtros de texto, contextos, mapas de categoria/ícone/rótulo, cidades
R/Embarque/Nucleo/BXSessao.swift        @Observable BXSessao + BXPushRegistro
R/Embarque/Nucleo/BXNavegacao.swift     BXAba, BXGrupo, BXDestino (+ deLink), BXNavegacao (@Observable)
R/Embarque/Nucleo/BXConectividade.swift @Observable: NWPathMonitor + 3 falhas seguidas → faixa offline
R/Embarque/Nucleo/BXCacheCarteira.swift "saldo do último acesso" (1 h), limpo no sair
R/Embarque/Demo/BXDemo.swift            argumentos de lançamento (Release: constantes desligadas) + BXTelaDemo (-BXTela)
R/Embarque/Demo/BXTransporteDemo.swift  (#if DEBUG) transporte falso com estado em memória
R/Embarque/Demo/BXDemoDados.swift       (#if DEBUG) dados de exemplo com armadilhas (§4.3)
R/Embarque/Demo/BXTesteNucleo.swift     (#if DEBUG) teste do núcleo (backend local / demo / folha do Google)
R/Telas/Acesso/BXTelasAcesso.swift      ESQUELETO → dono G1
R/Telas/Saldo/BXTelasSaldo.swift        ESQUELETO → dono G2
R/Telas/Movimentar/BXTelasMovimentar.swift ESQUELETO → dono G3
R/Telas/Descobrir/BXTelasDescobrir.swift   ESQUELETO → dono G4
R/Telas/Conta/BXTelasConta.swift        ESQUELETO → dono G5
```

Arquivos existentes tocados: `Demo/BXGaleria.swift` (G0: `.task { await BXTesteNucleo.rodarSePedido() }`) e
`APP/GoogleAuthService.swift` (sem dono na §5; correção de travamento, ver §6). `BXRecursos.loginGoogle` agora é
`true` (D10 decidido pelo dono em 22/10).

---

## 2. Como as telas usam o núcleo (padrão)

```swift
@Environment(BXSessao.self) private var sessao
@Environment(BXNavegacao.self) private var nav
@Environment(BXToastCentral.self) private var toast
@State private var carga: BXCarga<[BXLancamento]> = .carregando

func carregar() async {
    do {
        let itens = try await BXAPI.shared.lancamentos()
        carga = itens.isEmpty ? .vazio : .pronto(itens)
    } catch {
        guard !BXErro.ehCancelamento(error) else { return }      // tela fechou / Google cancelado
        let e = BXErro.de(error)
        if e.tipo == .emailNaoVerificado { nav.exigirVerificacaoEmail() }
        carga = .erro(e)                                         // .sessaoExpirada: a casca já virou visitante
    }
}
```

- **Nunca** criar outro `BXAPI` (single-flight da renovação depende de um só). Use `BXAPI.shared`.
- Escritas idempotentes: crie `BXChaveIdempotencia()` **uma vez por intenção** (`@State`), repita a mesma no
  "Tentar de novo" e troque só depois de uma resposta definitiva (sucesso ou erro que não seja rede).
- `e.mensagemParaUsuario` já vem filtrado (sem PIX fora da compra, sem valor do ponto, sem texto técnico).
  `e.mensagemServidorSegura` dá o texto do servidor filtrado (nil se proibido); `e.problemasSeguros` dá a
  checklist da política de senha; `e.tentativasRestantes`, `e.tentarEmSegundos`, `e.bloqueadoAte`, `e.codigo`,
  `e.extras["previous_transfer_id" | "hint" | "mfa_method"]`.
- Senha só em `@State` local; passe direto para a rota e limpe ao sair da tela.

---

## 3. `BXAPI` (actor) e rotas

Cliente: `BXAPI.shared` (transporte real; em DEBUG com `-BXDemo`/`-BXDemoVisitante`, `BXTransporteDemo`).
Toda requisição: sem cookies, timeout 30 s, JSON, `Authorization: Bearer`, `X-Platform: ios`, `X-Device-Id`,
`X-App-Version`, `Idempotency-Key` quando houver. GET: 3 tentativas (0,3 s / 0,6 s + jitter) em erro transitório
e 5xx. Escrita: 1 tentativa. 401/422 com `error == "unauthorized"` ou `msg` do JWT → uma renovação
single-flight (`POST /auth/refresh`, rotação gravada no cofre) e repete; renovação recusada → cofre limpo +
`BXSessao` vira visitante com toast "Sua sessão expirou. Entre de novo.". Os outros 401 (senha errada, credencial
inválida, MFA, reautenticação Google) voltam como erro comum e **não** derrubam a sessão. Corpo HTML ignorado.

Infra: `requisitar(_:como:)`, `requisitarSemCorpo(_:)`, `requisitarDados(_:)`, `renovar()`,
`renovarSeNecessario(idadeMaxima:)`, `saude()` (GET /health), `temSessao()`, `guardar(_:)`, `esquecerSessao()`,
`registrar(aoExpirarSessao:)`, `registrar(observadorRede:)`. Utilidades estáticas: `mapearErro`, `consulta`, `segmento`.

| Grupo | Função | Rota | Notas |
|---|---|---|---|
| Acesso | `entrar(login:senha:mfa:) -> BXRespostaLogin` | POST /auth/login | `.ok(tokens, usuario)` · `.mfaSMS(desafio:dica:)` · `.mfaTOTP` (repetir com `mfa`). 401/423/429/403 lançam. Aquece. |
| | `entrar2FA(desafio:codigo:)` | POST /auth/login/2fa | `codigo` do erro: invalid_code, challenge_expired, wrong_code, code_expired |
| | `entrarGoogle(idToken:nonce:)` | POST /auth/google | usar `BXSessao.entrarComGoogle()` |
| | `cadastrar(_ BXCadastro)` | POST /auth/register | 3 aceites = true no corpo; `problemas` = política de senha; 409 e-mail/CPF |
| | `eu()` · `sair()` | GET /auth/me · POST /auth/logout | |
| | `esqueciSenha(email:)` · `redefinirSenha(token:senha:)` | /auth/forgot-password · /auth/reset-password | reset manda `password_confirm` |
| | `trocarSenha(atual:nova:)` | POST /auth/change-password | 401 = senha atual errada (não desloga); sucesso → `sessao.sessaoRevogada("Senha alterada. Entre de novo.")` |
| | `enviarCodigoEmail() -> Int` · `verificarEmail(codigo:)` | /auth/verify-email/send · /auth/verify-email | minutos de validade; `tentativasRestantes` |
| | `versaoTermos()` · `reaceitarTermos()` | /auth/terms/current · /auth/terms/reaccept | |
| Segurança | `sessoes()` · `encerrarSessao(id:)` · `encerrarTodasAsSessoes()` | /user/sessions · DELETE /user/sessions/<id> · POST /auth/sessions/revoke-all | revoke-all → `sessaoRevogada` |
| | `historicoAcesso(limite:)` | GET /user/access-log | |
| | `cadastrarCelular(_:) -> String` · `verificarCelular(codigo:) -> BXUsuario` · `removerCelular(senha:)` | /user/phone* | 429 `cooldown` + `tentarEmSegundos` |
| | `ligar2FASMS(senha:)` · `desligar2FASMS(senha:)` | /user/2fa/sms/* | `codigo == "phone_not_verified"` |
| | `prepararTOTP() -> (segredo, uri)` · `ligarTOTP(codigo:)` · `desligarTOTP(senha:codigo:)` | /auth/mfa/* | |
| Privacidade | `consentimentos()` · `registrarConsentimento(tipo:versao:)` · `revogarConsentimento(id:)` | /privacy/consents | |
| | `exportarDados() -> Data` | GET /auth/account/export | arquivo para ShareLink; **não exibir** (traz campos proibidos) |
| | `excluirConta(senha:googleIdToken:)` | DELETE /auth/account | manda `confirm: "EXCLUIR MINHA CONTA"`; conta só Google: `sessao.reautenticarGoogle()` |
| Saldo | `carteira()` · `lancamentos(limite:)` | GET /wallet/ · /wallet/transactions | máx. 100, sem paginação |
| | `cartao()` · `niveis()` · `passeDisponivel()` · `passe() -> Data` | /card/, /card/tiers, /card/pass/status, /card/pass | 503 `wallet_not_configured` |
| Compra | `pacotes()` · `provedorPix()` | GET /pix/packages · /pix/provider | 4 pacotes ordenados |
| | `criarCobrancaPix(pacote:)` · `criarCobrancaPix(valor:)` | POST /pix/charge | provedor fora → `.pagamentoIndisponivel` ("O pagamento por PIX está indisponível no momento.") |
| | `cobrancaPix(id:)` · `minhasCobrancasPix()` | GET /pix/charge/<id> · /pix/my-charges | |
| | `configCartao()` · `cobrarCartao(_:chave:)` · `cobrancaCartao(id:)` · `minhasCobrancasCartao()` | /payments/card/* | só com `BXRecursos.compraCartao` (D02, desligado) |
| | `simularPagamento(cobranca:)` | POST /pix/simulate-payment | **só DEBUG** (provedor mock) |
| Envio | `enviar(_ BXPedidoEnvio, chave:) -> BXEnvio` | POST /transfer/ | 400 senha (validação, não desloga), 401 `.mfaNecessario`, 403 e-mail, 409 `.conflito`, 429 `codigo == "RECIPIENT_PROBE_BLOCKED"` |
| | `cancelarEnvio(id:)` | POST /transfer/<id>/cancel | |
| Descobrir | `parceiros(categoria:busca:)` · `categoriasParceiros()` · `parceiro(id:) -> BXParceiroDetalhe` | /partners/* | parceiros de exemplo nunca voltam; detalhe de um deles → `.naoEncontrado` |
| | `beneficios(categoria:parceiroID:)` · `beneficio(id:)` | /benefits/* | sem benefícios de parceiro de exemplo nem inativos |
| | `resgatarBeneficio(id:chave:) -> BXVoucher` | POST /benefits/<id>/redeem | 402 `.saldoInsuficiente`, 409 `.semEstoque`, 403 e-mail |
| | `vouchers()` · `voucher(id:)` | /vouchers/* | |
| | `campanhas()` · `participar(campanha:)` | /campaigns/ · /campaigns/<id>/join | Bearer opcional; esconder em Release com `BXRecursos.campanhas` (D04) |
| Avisos | `notificacoes() -> (itens, naoLidas)` · `contagemNaoLidas()` · `marcarLida(id:)` · `marcarTodasLidas()` | /notifications/* | depois de marcar, `sessao.definirNaoLidas(_:)` |
| | `registrarDispositivo(token:)` · `removerDispositivo(id:)` | /push/devices/* | usar `BXPushRegistro` |

Não existem e não são chamados: PATCH /user/profile, PATCH /user/password, /auth/logout-all, /auth/resend-verification,
POST /auth/account/delete, POST /auth/dev/verify-email, POST /campaigns/<id>/progress, /redeem/* (D03).

### 3.1 `BXErro.Tipo` por status

400 → `.validacao` (POST /pix/* com mensagem de provedor → `.pagamentoIndisponivel`) · 401 → `.sessaoExpirada` (só
"unauthorized"/`msg`, depois de tentar renovar) / `.mfaNecessario` / `.naoAutorizado` · 402 `.saldoInsuficiente` ·
403 `EMAIL_NOT_VERIFIED` → `.emailNaoVerificado`, senão `.naoAutorizado` · 404 `.naoEncontrado` · 409
`DUPLICATE_SUSPECTED` → `.conflito`, "estoque" → `.semEstoque` · 423 `.bloqueado` (`bloqueadoAte`) · 429
`.muitasTentativas` · 5xx `.servidor` (compra PIX → `.pagamentoIndisponivel`) · rede `.semConexao` · timeout `.tempoEsgotado`.

---

## 4. Modelos (BXModelos.swift)

Todos `nonisolated struct … Decodable, Sendable, Hashable`; campos proibidos **fora** do `CodingKeys`; listas
tolerantes (`BXListaTolerante`: item malformado é descartado).

| Modelo | Campos para a tela | Derivados |
|---|---|---|
| `BXUsuario` | id, nome, email, cpf, celular, emailVerificadoEm, ehVIP, mfaAtivo, temSenha, googleVinculado, provedor | `cartaoID` "DE0A11C2", `cartaoFormatado` "DE0A 11C2", `primeiroNome`, `inicial`, `emailVerificado`, `contaGoogleSemCPF`, `cpfMascarado`, `celularMascarado` (sem `pix_key`) |
| `BXCarteira` | saldo, emProcessamento | Saldo = `balance_pts` (NÃO subtrair o pendente); sem `balance_brl_equiv` |
| `BXLancamento` | id, tipo (`BXTipoLancamento`), status (`BXStatusLancamento`), pontos (com sinal), referencia, criadoEm | `rotulo` pelo tipo, `detalhe` seguro, `ehEntrada`, `envioDesfazivel()` |
| `BXCartaoEstado` | membroID, membroNome, saldo, acumulado, nivel, proximoNivel, faltam, progresso (0–100), niveis, passeDisponivel | `fracaoProgresso`, `cartaoFormatado` · cores só por `BXCor.nivel(nivel.chave)` |
| `BXNivel` | chave, nome, minimo, porConvite | `rotuloMinimo` ("0+ pts", "Por convite"); sem `perks`/cores |
| `BXPacote` | chave, rotulo, pontos, preco | `BXPacote.ordenar` |
| `BXProvedorPix` | nome, ehMock | |
| `BXCobrancaPix` | id, valor, pontos, brCode, qrImagem, status (`BXStatusCobranca`, `.emAberto`), expiraEm, pagaEm, pacote | `segundosParaExpirar()`, `ehValorLivre`, `dataReferencia` |
| `BXConfigCartao` · `BXCobrancaCartao` | (D02) | `aprovada`, `emProcessamento` |
| `BXEnvio` | id, pontos, mensagem, comprovante, criadoEm, status, efetivaEm, canceladoEm, cancelavel | `pendente`, `cancelado`, `segundosParaEfetivar()` |
| `BXParceiro` | id, nome, categoria, cidade | `categoriaCanonica`, `icone`, `descricaoSegura`, `ehFicticio`, `textoBusca` |
| `BXParceiroDetalhe` | parceiro, beneficios (ativos, por custo) | `aPartirDe` |
| `BXBeneficio` | id, parceiroID, nomeParceiro, nome, categoria, custo, estoque, validadeDias, tag, ativo | `descricaoSegura`, `rotuloCategoria`, `icone`, `esgotado`, `estoqueIlimitado`, `daBlaxx`, `faltam(saldo:)` |
| `BXVoucher` | id, beneficioID, nomeBeneficio, codigo, pontosGastos, expiraEm, usadoEm, status (`BXStatusVoucher`), criadoEm | ativo vencido aparece como expirado |
| `BXCampanha` | (da fundação) | `nomeSeguro`, `descricaoSegura`, `diasRestantes()`, `concluida` |
| `BXNotificacao` | id, tipo, referencia, lida, criadaEm | `icone`, `titulo` (seguro ou padrão do tipo), `corpoSeguro`, `marcadaComoLida()` |
| `BXSessaoDispositivo` | id, nomeDispositivo, criadaEm, ultimoUso, atual | `ipMascarado` |
| `BXEventoAcesso` | evento, dispositivo, status, em | `rotulo`, `ipMascarado`, `falhou` |
| `BXConsentimento` | id, tipo, versao, aceitoEm, status | `rotuloTipo`, `ativo`, `revogavel` (só marketing/cookies) |
| `BXRespostaLogin` | `.ok(BXTokens, BXUsuario)`, `.mfaSMS(desafio:dica:)`, `.mfaTOTP` | |
| Pedidos | `BXCadastro(nome:email:cpf:senha:celular:nascimento:)`, `BXPedidoEnvio(para:pontos:senha:mensagem:codigoMFA:)`, `BXPedidoCartao` | `description` nunca mostra senha |

Sanitizador (todas as builds): `textoSeguro` (regra do dono + "R$ … em pontos"), `textoCampanhaSeguro`,
`mensagemServidorSegura(_:contexto:)` (contextos `.geral .acesso .compra .envio .resgate .conta`; só `.compra`
mantém "PIX"; nos outros vira "transferência"), `ehFicticio`, `categoriaCanonica`, `categoriasPrincipais`,
`icone(categoriaParceiro:nome:)`, `icone(categoriaBeneficio:)`, `rotulo(categoriaBeneficio:)`,
`icone(tipoNotificacao:)`, `tituloPadrao(tipoNotificacao:)`, `rotulo(tipo:descricao:)`, `detalheLancamento`,
`cidade(daBusca:)`, `ipMascarado`, `rotulo(eventoAcesso:)`, `rotulo(consentimento:)`, `normalizar`, `semSimbolos`.

---

## 5. Sessão, navegação, conectividade (o que a casca G1 liga)

```swift
@State private var sessao = BXSessao()
@State private var nav = BXNavegacao()
@State private var toast = BXToastCentral()
@State private var conectividade = BXConectividade()

raiz
  .environment(sessao).environment(nav).environment(toast).environment(conectividade)
  .environment(\.colorScheme, .light)                       // NÃO .preferredColorScheme (05 §2.1)
  .tint(BXCor.tinta)
  .bxToastHost(toast)
  .task { sessao.toast = toast; await sessao.iniciar(); await BXTesteNucleo.rodarSePedido() /* só DEBUG */ }
  .onChange(of: sessao.estado) { _, e in nav.sessaoMudou(logado: e == .logado) }
  .onChange(of: scenePhase) { _, f in if f == .active { Task { await sessao.aoVoltarPrimeiroPlano() } } }
  .onOpenURL { url in if let d = BXDestino.deLink(url) { nav.ir(d) } }
```

**BXSessao**: `estado` (`.iniciando` · `.visitante` · `.logado`), `transicao` (`.nenhuma` · `.entrando` · `.saindo`;
atalhos `entrando`, `saindo`), `usuario`, `carteira`, `carteiraDoCache` (selo "SALDO DO ÚLTIMO ACESSO"),
`erroCarteira`, `naoLidas`, `emailVerificado`, `cartaoID`. Métodos: `iniciar()`, `entrar(login:senha:mfa:)
-> Result<BXRespostaLogin, BXErro>`, `concluir2FASMS(desafio:codigo:)`, `entrarComGoogle()` (cancelado →
`CancellationError`, não mostrar erro), `reautenticarGoogle() -> idToken`, `cadastrar(_:)`, `recarregarCarteira()`,
`recarregarUsuario()`, `atualizarNaoLidas()`, `definirNaoLidas(_:)`, `aoVoltarPrimeiroPlano()`, `sair()`,
`sessaoRevogada(motivo:)`. Sem conta demo, sem login silencioso. Abertura sem rede com tokens: entra logado com o
saldo do cache e `usuario == nil` (telas tratam nil; o perfil volta em `aoVoltarPrimeiroPlano`).

**BXPushRegistro** (D12): `registrar(token:)` (só logado, guarda o id), `remover()` (o `sair()` já chama). O
PushService (G1) chama `await BXPushRegistro.registrar(token: hex)` depois do login.

**BXNavegacao**: `aba`, `pilhas[aba]`, `raizes[aba]` (raiz com parâmetro), `pilhaVisitante`, `gavetaAberta`,
`pedidoVerificacaoEmail`, `destinoAposEntrar`, `logado`, `retoques[aba]` (toque repetido na aba; a raiz rola ao
topo). `ir(_:)`, `voltar()`, `voltarParaRaiz()`, `retocar(_:)`, `abrirGaveta()`, `fecharGaveta()`,
`exigirVerificacaoEmail()`, `pedirEntrada(depois:)`, `sessaoMudou(logado:)`, `abrirSite(_:)`
(SFSafariViewController em `https://blaxxpontos.com.br/<caminho>`). Bindings: `vinculo(pilha:)`,
`vinculoVisitante`, `vinculoAba`. A raiz de cada aba é `nav.raiz(da: aba)`; aplique `.id(nav.raiz(da: aba))`
para a raiz reiniciar quando o parâmetro muda (ex.: `.comprar(pacote: "black")`, `.resgates(.meusResgates)`).

**BXConectividade**: `mostrarFaixa`, `verificando`, `verificar()` → `BXFaixaOffline(verificando:verificar:)`.

### 5.1 Destinos (`BXDestino`)

| Grupo | Destinos | Tela que resolve |
|---|---|---|
| G1 acesso | `.boasVindas`, `.entrar`, `.cadastro`, `.recuperarSenha`, `.redefinirSenha(token:)`, `.verificarEmail` | `BXTelasAcesso.tela(_:)` (`.verificarEmail` logado vira `nav.exigirVerificacaoEmail()`) |
| G2 saldo | `.inicio`*, `.carteira`*, `.extrato(.tudo/.entradas/.saidas)`, `.cartaoBlaxx`, `.notificacoes` | `BXTelasSaldo.tela(_:)` |
| G3 movimentar | `.comprar(pacote:)`*, `.historicoCompras`, `.enviar(para:)`, `.receber` | `BXTelasMovimentar.tela(_:)` |
| G4 descobrir | `.parceiros(busca:)`, `.parceiro(id:)`, `.resgates(.catalogo/.meusResgates)`*, `.beneficio(id:)`, `.voucher(id:)`, `.campanhas` | `BXTelasDescobrir.tela(_:)` |
| G5 conta | `.perfil`, `.seguranca`, `.privacidade`, `.convidar`, `.ajuda`, `.faq` | `BXTelasConta.tela(_:)` |

\* troca de aba (`destino.aba`). Públicos (`exigeLogin == false`): acesso (menos verificarEmail), parceiros,
parceiro, resgates(.catalogo), beneficio, campanhas, ajuda, faq. Deep links: `blaxxpontos://redefinir-senha?token=…`
e `blaxxpontos://enviar?para=<CARTAO>` (`BXDestino.deLink`).

### 5.2 Esqueletos (§1.8)

```swift
@MainActor enum BXTelasSaldo { @ViewBuilder static func tela(_ destino: BXDestino) -> some View; static func titulo(_:) -> String }
// idem BXTelasMovimentar, BXTelasDescobrir, BXTelasConta, BXTelasAcesso
```
Hoje mostram `BXEstadoVazio(icone: .info, titulo: "Em construção", texto: "<Tela>: esta tela do novo app ainda está
sendo construída.")`. Cada grupo reescreve o seu, mantendo a assinatura `tela(_:)`; sem `NavigationStack` próprio
e sem barra de topo.

---

## 6. Modo demonstração (só DEBUG)

| Argumento | Efeito |
|---|---|
| `-BXDemo YES` | logado "Cliente Demo" (Cartão DE0A 11C2, saldo 32.480, em processamento 1.000, 2 não lidas); zero rede |
| `-BXDemoVisitante YES` | visitante; rotas públicas de exemplo; login de exemplo funciona |
| `-BXDemoEstado carregando\|vazio\|erro\|offline\|pixIndisponivel` | nunca termina / listas vazias / 500 (a compra devolve o 400 do provedor) / falha de rede (faixa offline) / só a compra PIX falha. `/auth/me` responde sempre |
| `-BXDemoEmailPendente YES` | usuário com e-mail não verificado (envio e resgate devolvem 403; código de verificação `123456`) |
| `-BXTela <id>` | `BXDemo.telaInicial: BXTelaDemo?` → `.destino(BXDestino)`, `.gaveta`, `.galeria(pagina:)` |
| `-BXSubtela <nome>` | `BXDemo.subtela` (cada grupo abre o passo: valorLivre pix pago confirmar concluido lancamento totp senha excluir 2fa maisCategorias). `pago`: a cobrança já nasce paga |
| `-BXAncora <id>` | `BXDemo.ancora` (cada grupo rola até `.id(…)`) |
| `-BXLogRede` | uma linha por requisição no console (método, caminho, status; nunca corpo/token) |

Ids de `-BXTela`: `inicio carteira extrato[:entradas|saidas] cartao notificacoes comprar[:start|plus|prime|black]
historico enviar[:<para>] receber parceiros[:<busca>] parceiro[:<id>] resgates meusResgates beneficio[:<id>]
voucher[:<id>] campanhas perfil seguranca privacidade convidar ajuda faq boasVindas entrar cadastro recuperar
redefinir[:<token>] verificarEmail gaveta icones componentes[:<página>]`.

Ids de exemplo: parceiros `cafe-ponto-doce` (2 benefícios), `hotel-vila-serena` (1), `volt-eletronicos` (0);
benefícios `b-cafe-expresso`, `b-escalada` (esgotado), `b-pousada` (40.000, saldo insuficiente); vouchers
`v-ativo` (`BX-7F3K-92QA`), `v-usado`, `v-expirado`; cobrança pendente `demo-pix-pendente`.

Fluxos de exemplo: login qualquer e-mail + senha não vazia ("errada" recusa); `2fa@exemplo.test` (SMS, código
123456), `totp@exemplo.test` (código 123456), `bloqueado@exemplo.test` (423); cadastro `existe@exemplo.test` (409),
senha `fraca` (política). Compra: pendente nas 2 primeiras consultas, paga na 3ª (credita). Envio: `amigo@exemplo.test`
ou `AB12CD34`; `repetido@exemplo.test` → 409; ≥ 20.000 pts → 2FA; desfazer em 60 s; senha `errada` → 400.
Resgate debita e cria voucher; mesma `Idempotency-Key` devolve a mesma resposta.

Armadilhas (têm de ficar invisíveis em toda foto): "Loja Exemplo" (some, com o seu benefício), "Mercado Teste"
(aparece sem descrição), `accrual_rule`, `logo_emoji`, `image_emoji`, `balance_brl_equiv`, "Resgate via PIX → chave"
no extrato, `perks` com PIX e `text_color #C6FF00`, `mechanic`/`target_brl`, notificação "…resgates PIX" e "Meta: R$".

Garantia de Release: `BXDemoDados`, `BXTransporteDemo` e `BXTesteNucleo` inteiros em `#if DEBUG` (no Release os
`.o` desses três arquivos só têm os símbolos padrão do Swift, nenhum dado); `strings` do binário Release para
`BXTransporteDemo|BXDemoDados|Mercado Aurora|cliente.demo@exemplo.test|BXTesteNucleo|demo-acesso` = **0**.
Atenção G1: hoje o Release ainda abre o mundo antigo, então o linker descarta todo o código Embarque; refaça a
checagem de `strings` depois de ligar `BXRaiz` no `ContentView`.

---

## 7. Teste do núcleo (`-BXTesteNucleo`, só DEBUG)

```
SIM=29702B3D-53FF-44C6-810D-D665C7C7636A
xcrun simctl launch --terminate-running-process $SIM Blaxx-Pontos-Inc.BlaxxPontos -BXGaleria YES -BXTesteNucleo YES \
  -blaxx_backend_url http://127.0.0.1:5050 -BXTesteLogin <e-mail de seed.py> -BXTesteSenha <senha de seed.py>
cat "$(xcrun simctl get_app_container $SIM Blaxx-Pontos-Inc.BlaxxPontos data)/Library/Caches/bx-teste-nucleo.log"
```

Recusa qualquer backend que não seja 127.0.0.1/localhost. Resultado de 22/10 (backend local, conta de seed):
visitante sem tokens · login inválido → `.naoAutorizado` · login real → logado (Cartão E9F5 5C1F) · carteira 84.750
pts (sessão e GET /wallet/) · 15 GETs (extrato, cartão, níveis, pacotes, provedor, 266 parceiros, 45 categorias,
benefícios, vouchers, campanhas, notificações, cobranças, sessões, histórico, consentimentos) · senha atual errada →
401 sem derrubar a sessão · refresh com rotação + /auth/me com o token novo · sair → visitante e cofre limpo ·
tokens inválidos → renovação recusada → `.sessaoExpirada` e cofre limpo · **RESULTADO: OK**.

Variantes: `-BXDemo YES -BXTesteNucleo YES` prova o transporte de demonstração e as armadilhas (16 checagens, OK);
`-BXTesteNucleo YES -BXTesteGoogle` abre a folha do Google (fotos `fotos-telas/nucleo/N-01`, `N-02`) e, ao cancelar,
confere `CancellationError` sem mudar a sessão (OK). O login Google real exige a conta do dono e não foi completado.

---

## 8. Achados e pendências

1. **GoogleAuthService travava o app** (corrigido): no iOS 26+, quando `ASWebAuthenticationSession.start()` devolve
   false o sistema também chama o completion com erro, e a continuação era retomada duas vezes ("SWIFT TASK
   CONTINUATION MISUSE", reproduzido ao abrir a folha antes da cena ficar ativa). Agora: retomada única, sessão
   guardada enquanto aberta, segunda chamada simultânea recusada, âncora pela cena ativa em `MainActor.assumeIsolated`
   (6 dos 7 avisos antigos do arquivo sumiram; resta 1 de `UIWindow()` no ramo inalcançável).
2. Backend: `/auth/logout` revoga só o token de acesso; o refresh continua válido até expirar (30 dias) mesmo
   depois do sair (o app apaga localmente). Sugestão: revogar o refresh no logout (pedido D18).
3. No backend local os 8 parceiros de exemplo não têm "fictícia" na descrição (em produção têm), então aparecem
   localmente (ex.: "AeroFly · …resgate de milhas"). Em produção somem pelo filtro.
4. Produção: o benefício da BlaXx "Sorteio R$ 1.000 — Blaxx" tem a descrição "R$ 1.000 em pontos extras" (cai no
   filtro novo), mas o **nome** traz "R$ 1.000". Decidir se o nome fica (decisão do dono, junto de D05/D09).
5. Sign in with Apple continua pendente para antes da App Store (D10, regra 4.8).
