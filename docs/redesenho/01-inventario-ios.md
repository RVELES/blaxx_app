# 01 · Inventário do app iOS vivo (estado "antes" do redesenho)

Data: 22/10/2026 · Escopo: árvore viva `BlaxxPontos/Rewards/` e o que ela usa
(`API.swift`, `Session.swift`, `TokenStore.swift`, `Theme.swift`, `Components.swift`,
`GoogleAuthService.swift`, `Util/`, `Cache/`, `Push/`, `Resources/Fonts`, `Assets.xcassets`,
`Info.plist`, `BlaxxPontosApp.swift`, `ContentView.swift`).

Repositório iOS: `blaxx_app/BlaxxPontos` (git limpo, HEAD `0d73534` "WIP anterior ao redesenho
Embarque do app iOS (estado de 22/10)").

Como as fotos foram tiradas (sem tocar a produção): build DEBUG instalado no iPhone 17 Pro
(simulador `29702B3D…`), lançado com o argumento `-blaxx_backend_url http://127.0.0.1:59999`
(argumento de linha de comando, não persiste; porta sem nada escutando). Assim o login silencioso
de DEBUG e todas as chamadas da API falharam localmente, e as telas mostram o estado "sem sessão"
mais o mundo mock. Nenhum POST/PUT/DELETE foi feito na produção e nenhuma senha foi digitada.
Os únicos acessos à produção foram GET públicos: `/partners/` (266 parceiros), `/campaigns/`
(3 campanhas) e `/pix/packages` (start, plus, prime, black).

Legenda de caminhos: salvo indicação, `Rewards/X.swift` = `BlaxxPontos/BlaxxPontos/Rewards/X.swift`.

---

## 1. Mapa de navegação

```
BlaxxPontosApp (WindowGroup)
├─ .task → PushService.requestAuthorizationAndRegister()      (BlaxxPontosApp.swift:52-56)
├─ .protectedSnapshot() → overlay "BlaXx Pontos / Conteúdo protegido" fora de .active (:61-63)
├─ .onOpenURL blaxxpontos://redefinir-senha?token=… → sheet ResetPasswordView (:42-50, :75-85)
└─ ContentView.body → RewardsRoot()                            (ContentView.swift:32-38)
   │   (legacyBody: MobileShell/HomeView/LoginView/BuyView/RedeemView = código morto)
   │
   ├─ [loggedIn == false] RewardsLoginView  ← TELA INICIAL (gate MOCK)
   │      "Entrar" / "Entrar com Face ID" / "Criar conta" → todos chamam onLogin
   │      (Rewards/RewardsLoginView.swift:135, :147, :171) — não autentica nada
   │
   └─ [loggedIn == true] RewardsShell                          (Rewards/RewardsShell.swift)
        .task → backend.start()  (DEBUG: login silencioso com conta demo; RELEASE: só token já salvo)
        │
        ├─ Tab bar própria RWTabBar (:229-281): Home · Carteira · [FAB Trocar] · Enviar · Parceiros
        │   ├─ .home      → RewardsHomeView
        │   │     sino     → área logada em .notificacoes
        │   │     avatar   → área logada em .menu
        │   │     Comprar  → sheet .buy        (RewardsBuySheet — REAL)
        │   │     Vender   → sheet .sell       (RewardsSellSheet — REAL)
        │   │     Trocar   → sheet .trade      (RewardsTradeSheet — MOCK)
        │   │     Enviar   → sheet .transfer   (RewardsTransferSheet — REAL)
        │   │     Campanhas "Ver todas"/card → área logada em .campanhas
        │   ├─ .carteira  → RewardsWalletView (MOCK + cartão real)
        │   │     card de programa → sheet .program(id) (RewardsProgramSheet — MOCK)
        │   │         "Trocar pontos da X" → sheet .trade (MOCK)
        │   ├─ FAB ⇄      → sheet .trade (MOCK)
        │   ├─ .enviar    → RewardsSendView (fluxo MOCK de 4 passos; ≠ do sheet .transfer real)
        │   └─ .parceiros → RewardsPartnersView (MOCK) — "Trocar" → sheet .trade (MOCK)
        │
        ├─ Sheet .offer(id) → RewardsOfferSheet — INALCANÇÁVEL (ninguém atribui `.offer`)
        │
        ├─ Área logada (overlay tela cheia, zIndex 15) RewardsAccountView — roteador próprio com pilha
        │   (Rewards/RewardsAccountViews.swift:42-117)
        │   .menu "Minha conta"
        │     Conta:     Carteira (→ aba Carteira) · Extrato · Cartão BlaXx · Perfil · Notificações
        │     Pontos:    Comprar pontos (→ sheet .buy) · Enviar pontos (→ sheet .transfer)
        │                Resgatar em dinheiro (→ sheet .sell) · Resgatar com pontos · Indique e ganhe
        │     Descobrir: Parceiros (→ aba Parceiros) · Campanhas
        │     Ajuda:     Central de ajuda (→ FAQ, Chamado) · Perguntas frequentes · Abrir chamado · Segurança
        │   .perfil · .extrato · .cartao · .notificacoes · .campanhas · .resgates · .indique
        │   .seguranca · .ajuda · .faq · .chamado
        │   "voltar" desempilha; pilha vazia fecha a área (entrada pelo sino fecha direto)
        │
        └─ EmailVerifyGate (só RELEASE, zIndex 20) quando ready && user != nil && !emailVerified
           (Rewards/RewardsShell.swift:111-117)
```

Telas que NÃO existem na árvore viva (existem só no web ou no código morto): cadastro real,
login real (e-mail/senha ou Google), "esqueci a senha", compra por cartão (`/payments/card`,
web `comprar-livre.html`), detalhe/lista real de parceiros (`/partners/`), comprovante de envio,
cancelamento de envio (`POST /transfer/<id>/cancel`), Apple Wallet (`/card/pass`).

---

## 2. Telas: o que mostram, ações, endpoints, estados, mocks

Endpoints listados como chamados pelo app via `BlaxxAPI` (`API.swift`). Base:
`https://blaxx-pontos-exe.onrender.com` (`API.swift:304`); em DEBUG pode ser sobrescrita por
`UserDefaults("blaxx_backend_url")` (`API.swift:314-325`). GET tem 3 tentativas com backoff;
POST/PATCH/DELETE uma tentativa (`API.swift:358-363`).

### 2.1 RewardsLoginView (tela inicial) — foto `01-login-gate.png`
- Mostra: fundo gradiente escuro, `BlaxxLockup` (B + "BlaXx" + "REWARDS"), slogan
  "Troque seus pontos. Multiplique vantagens." (`RewardsLoginView.swift:75`), campos E-mail/Senha,
  "Entrar", "Entrar com Face ID", "Novo na BlaXx? Criar conta".
- Ações: as três ações só abrem a shell; os campos são ignorados (`:135`, `:147`, `:171`).
- Endpoints: nenhum.
- Estados: não há carregando/erro (não há chamada).
- Observação: com `.preferredColorScheme(.light)` a barra de status fica preta sobre o fundo
  escuro (ilegível na foto).

### 2.2 RewardsShell + RWTabBar
- Tab bar branca com 4 abas (SF Symbols `house`, `creditcard`, `paperplane`, `square.grid.2x2`)
  e FAB circular neon com `arrow.left.arrow.right` (`RewardsShell.swift:229-281`). Ativo em
  `RWColor.greenLight` (#2BA014), inativo `RWColor.muted`.
- Sheets: container próprio `RWSheetContainer` (scrim + cartão branco, raio 28, altura máx 720)
  (`:207-225`), não usa `.sheet` do sistema.
- Endpoints: `backend.start()` (ver 2.21).

### 2.3 RewardsHomeView — foto `02-home.png`
- Mostra: header com `BlaxxSymbol` neon num quadrado preto + `BlaxxWordmarkClaro` (com "REWARDS")
  (`RewardsHomeView.swift:60-79`); sino; avatar com a inicial do usuário (fallback "R", `:93`).
  Hero escuro "Seu saldo" com valor em R$ (`balance_brl_equiv`) e linha "N pontos BlaXx"/
  "N pontos · M a confirmar" (`:113-164`), selo "Saldo do último acesso" quando o número veio do
  cache (`:169-171`), sparkline decorativa fixa (`:141-143`, `:257-293`).
  4 ações rápidas (`:175-202`), lista "Campanhas" (até 3) com "Ver todas" (`:206-252`).
- Endpoints: `GET /campaigns/` → `items[].{id,name,reward_pts,joined,progress_pct,completed_at}`
  (`:52-55`); saldo vem de `backend.wallet` (`GET /wallet/` → `balance_pts`, `pending_pts`,
  `balance_brl_equiv`).
- Estados: carregando ("Carregando campanhas…"), vazio ("Nenhuma campanha ativa agora…").
  Erro de rede vira vazio (`try?` → `[]`, `:53`). Hero sem sessão: "—" e "Entre na sua conta
  para ver o saldo".
- Mock: sparkline com pontos fixos (`:259-263`); inicial "R" (`:93`).

### 2.4 RewardsWalletView (aba Carteira) — fotos `03-carteira.png`, `04-carteira-programas.png`
- Mostra: título "Carteira" + ícone de filtro que não faz nada (`RewardsWalletView.swift:34-40`,
  não é botão); cartão BlaXx escuro (nome, nº = 8 primeiros hex do `user.id`, saldo real,
  "Copiar") (`:123-202`); "Patrimônio total R$ 25.350,00 / 1.250.000 pontos BlaXx" (MOCK,
  `:47-62`); segmentado Mês/6 meses/Ano + gráfico de área (MOCK, `:20-24`, `:65-80`);
  "Seus programas" com Smiles, TudoAzul, LATAM Pass, Livelo, Esfera, saldo e R$ por programa
  (MOCK, `:86-113`).
- Ações: copiar nº do cartão (`UIPasteboard`), tocar programa → RewardsProgramSheet.
- Endpoints: nenhum próprio (usa `backend.user`, `backend.wallet`).
- Estados: sem sessão o cartão mostra "—— —— —— ——" e "—"; o resto é sempre mock.
- Mock: `RewardsModel.swift:57-63` (programas, saldos, `brlPerK`), `:97` (`totalBRL`),
  `RewardsWalletView.swift:20-24` (séries do gráfico).

### 2.5 RewardsProgramSheet — foto `05-sheet-programa-smiles.png`
- Mostra: logo-letra do programa, "420.000 pts · R$ 8.820", CTA "Trocar pontos da Smiles",
  "Histórico" com 1-3 lançamentos inventados.
- Endpoints: nenhum. Mock: histórico `RewardsModel.swift:72-92`, R$ `RewardsProgramSheet.swift:36`.

### 2.6 RewardsTradeSheet (Trocar, 3 passos) — foto `06-sheet-trocar.png`
- Passo 0: chips De/Para (5 programas mock), inverter, "Quanto trocar" + slider + 25/50/Máx,
  cartão "Você recebe 155.520 Livelo · 1.000 Smiles ≈ 1.200 Livelo · +8% bônus".
- Passo 1: revisão com "Taxa de conversão", "Bônus BlaXx", "Taxa de serviço: Grátis"
  (`RewardsTradeSheet.swift:104-122`).
- Passo 2: "Troca concluída! … Os pontos já estão na sua carteira BlaXx." (`:126-148`).
- Endpoints: nenhum; `confirm()` só altera o store local (`:211-217`).
- Mock: tudo. Config padrão `RWTradeConfig` (`:12-18`, bônus 8% e 120.000 pts),
  cálculo `RewardsModel.swift:123-148`.

### 2.7 RewardsOfferSheet — sem foto (inalcançável)
- Oferta "+120% de bônus", contagem "Termina em 2d 14h", simulador, termos
  (`RewardsOfferSheet.swift:38-109`). Nenhum código atribui `sheet = .offer(...)`.

### 2.8 RewardsPartnersView (aba Parceiros) — foto `08-parceiros-aba.png`
- Mostra: "Parceiros" + "Troque seus pontos BlaXx entre os principais programas de fidelidade."
  (`RewardsPartnersView.swift:39`); 5 cartões mock com selo "+120% bônus" etc. (`:57-64`),
  "420.000 pts · R$ 8.820" (`:66`) e botão "Trocar" (`:71-79`).
- Endpoints: nenhum. A produção tem 266 parceiros em `GET /partners/` (com `logo_emoji` e
  `accrual_rule`), que o app vivo não consome.

### 2.9 RewardsSendView (aba Enviar, 4 passos) — foto `07-enviar-aba.png`
- Passo 0: "Enviar pontos", campo de busca que é um `Text` estático (`RewardsSendView.swift:57-66`),
  "Contatos recentes" (Marina Alves, Rafael Costa, Júlia Santos, Bruno Lima — `RewardsModel.swift:65-70`),
  "Enviar por link / QR" sem ação (`:82-103`).
- Passo 1: chips de programa (mock), slider, mensagem, cartão "Destinatário recebe … Sem taxa".
- Passo 2: revisão ("Taxa de serviço: Grátis", "Confirme com Face ID para enviar" — mas não
  pede biometria) (`:199-227`).
- Passo 3: "Pontos enviados! … A transferência foi concluída na hora." + "Ver comprovante"
  que só reinicia (`:231-248`).
- Endpoints: nenhum; `confirm()` só decrementa o mock (`:250-256`).

### 2.10 RewardsBuySheet (Comprar) — foto `12-sheet-comprar.png`
- Passo select: "Pacotes" (lista), "Ou valor personalizado" (R$), CTA "Gerar PIX", selo de
  homologação (`RewardsFinanceSheets.swift:195-221`).
- Passo pix: "Você vai pagar R$ X / Crédito de N pontos", QR (imagem do provider ou gerado do
  `br_code`), "PIX copia e cola", "Copiar código", "Já paguei" (polling 4×1,5 s),
  "Simular pagamento" só em DEBUG e com provider mock (`:257-341`).
- Passo done: "Pontos creditados!" (`:344-359`).
- Endpoints:
  - `GET /pix/packages` → dict `{key: {label, points, price_brl}}` (`API.swift:741-764`;
    não verifica status HTTP nem usa o `request()` com retry).
  - `GET /pix/provider` → `{name, is_mock}` (só DEBUG, `RewardsFinanceSheets.swift:186-190`).
  - `POST /pix/charge` body `{"package": key}` ou `{"amount_brl": v}` → `PixChargeDTO`
    (`id, amount_brl, points_to_credit, br_code, qr_code_image, status`).
  - `GET /pix/charge/<id>` → `status == "paid"` (polling).
  - `POST /pix/simulate-payment` body `{"charge_id"}` (DEBUG + mock).
  - Depois do sucesso: `GET /wallet/` (refresh).
- Estados: botão "Gerando PIX…", erro em chip âmbar (`RWSheetError`). Falha de
  `/pix/packages` = lista vazia sem mensagem (foto 12: título "Pacotes" sem nada embaixo).

### 2.11 RewardsSellSheet (Vender / "Resgatar em dinheiro") — foto `11-sheet-vender.png`
- Form: "Vender pontos", "Quanto resgatar" + slider + 25/50/Máx, cartão "Você recebe via PIX
  R$ X / N pontos", CTA "Resgatar via PIX", selo (`RewardsFinanceSheets.swift:454-483`).
- Vazio (saldo < 1.000 ou sem sessão): "Saldo insuficiente para resgate / É preciso ao menos
  1.000 pontos para resgatar via PIX." (`:485-502`).
- Done: textos por status `paid` / `processing|requested` / `failed` / outro (`:537-585`).
- Endpoints: `GET /redeem/quote?points=N` → `{points, amount_brl, rate}` (debounce 350 ms,
  `:447-451`); `POST /redeem/` body `{points, pix_key, password}` → `RedeemResponse.status,
  failure_reason` (`API.swift:809-812`). Biometria antes (`:589`). Em RELEASE `redeem` lança
  "Operação indisponível nesta build." (`RewardsBackend.swift:173-182`).

### 2.12 RewardsTransferSheet (Enviar real)
- Form: "Para (Cartão BlaXx, e-mail ou CPF)", quantidade (slider step 1.000), mensagem, CTA
  "Enviar pontos", selo (`RewardsFinanceSheets.swift:640-666`). Done "Pontos enviados!".
- Endpoint: `POST /transfer/` body `{to, amount_pts, message, password}` → `TransferResponse`
  (`API.swift:798-801`); biometria antes (`:720`). Em RELEASE lança "Operação indisponível
  nesta build." (`RewardsBackend.swift:185-192`).
- O backend já aceita `Idempotency-Key` em `/transfer/` e `/redeem/`
  (`blaxx_exe/backend/app/api/transfer.py`, `redeem.py`); o app não envia e o comentário em
  `API.swift:358-361` diz o contrário (desatualizado).

### 2.13 Área logada · Menu "Minha conta" — fotos `09-conta-menu.png`, `10-conta-menu-fim.png`
- Cartão de identidade escuro (inicial, nome ou "Visitante", "Cartão XXXX XXXX" ou "Sem sessão
  ativa", saldo) (`RewardsAccountViews.swift:372-404`), grupos Conta/Pontos/Descobrir/Ajuda
  (`:332-362`), selo de homologação no fim (`:364`).
- Diferença do web (`blaxx/assets/blaxx-nav.js:103-126`): web tem "Início" e "Resgatar
  benefícios"; iOS tem "Notificações", "Resgatar em dinheiro", "Resgatar com pontos" e
  "Segurança" (em Ajuda).

### 2.14 Perfil (`RWProfileView`, `:409-519`)
- Nome, e-mail, CPF mascarado (`:501-505`), chave PIX, nº do cartão, e-mail verificado;
  "Sair da conta"; zona de risco com exclusão (senha).
- Endpoints: `DELETE /auth/account` body `{password}` com fallback `POST /auth/account/delete`
  (`API.swift:542-555`). Sem sessão: "Entre na sua conta para ver o perfil."
- "Sair" chama `backend.signOut()` e fecha a área, mas o usuário volta para a shell (não para o
  gate), não chama `POST /auth/logout` nem limpa o `WalletCache` (`RewardsBackend.swift:258-264`).

### 2.15 Segurança (`RWSecurityView`, `:523-611`)
- Senha atual / nova / repetir (mín. 8), sucesso "Senha alterada".
- Endpoint: `POST /auth/change-password` body `{old_password, new_password}`.

### 2.16 Extrato (`RWStatementView`, `RewardsActivityViews.swift:18-191`) — foto `13-extrato-erro.png`
- Busca, segmentado Tudo/Entradas/Saídas, grupos por dia (Hoje/Ontem/"12 ago"), linhas com
  seta, descrição, hora, status ≠ confirmed, valor ±pts.
- Endpoint: `GET /wallet/transactions?limit=100` → `items[].{id,type,status,amount_pts,
  description,created_at}`.
- Estados: carregando, erro ("Não foi possível carregar o extrato." — sem botão de tentar de
  novo), vazio ("Nenhum movimento ainda. Compre pontos para começar." / "Nada encontrado…").

### 2.17 Notificações (`RWNotificationsView`, `:195-313`)
- Lista com bolinha neon de não lida, título, corpo, data; "Marcar todas como lidas".
- Endpoints: `GET /notifications/` → `items[].{id,title,body,is_read,created_at}`;
  `PATCH /notifications/<id>/read`; `POST /notifications/read-all`.
- Estados: carregando, erro, vazio.

### 2.18 Cartão BlaXx (`RWCardView`, `RewardsCatalogViews.swift:16-165`)
- Face do cartão (wordmark em Text "Bla"+"Xx", selo do nível, nº, titular, saldo), progresso
  para o próximo nível, lista de níveis.
- Endpoint: `GET /card/` → `member.name, balance_pts, lifetime_points, tier{key,label},
  next_tier, points_to_next, progress_pct, tiers[]{key,label,min_points}`.
- Estados: carregando, erro (também quando `state == nil`).

### 2.19 Campanhas (`RWCampaignsView`, `:169-274`)
- Cartões com nome, "+N pts", descrição, barra de progresso "x% de R$ alvo" ou "Participar".
- Endpoints: `GET /campaigns/`; `POST /campaigns/<id>/join`.
- Estados: carregando, erro, vazio, erro de join em chip.

### 2.20 Resgatar com pontos (`RWBenefitsView`, `:278-471`)
- Abas Catálogo / Meus vouchers; cartão de benefício com emoji, nome, parceiro, custo em pts,
  descrição, CTA Resgatar/Esgotado/Saldo insuficiente; destaque do voucher recém-resgatado.
- Endpoints: `GET /benefits/` → `items[].{id,name,partner_name,description,cost_pts,image_emoji,stock}`;
  `GET /vouchers/` → `items[].{benefit_name,code,status,expires_at}`;
  `POST /benefits/<id>/redeem` → `VoucherDTO`; depois `GET /wallet/`.
- Estados: carregando, erro (só se as duas chamadas falharem), vazios por aba.

### 2.21 Indique e ganhe / Central de ajuda / FAQ / Abrir chamado
- Indique (`RewardsAccountViews.swift:615-686`): código = nº do cartão (fallback "BLAXX"),
  link `https://blaxxpontos.com.br/cadastro?ref=<código>` (`:625`), copiar, `ShareLink`, aviso de
  que o backend não credita indicação. Sem endpoint.
- Ajuda (`:690-735`), FAQ (6 perguntas fixas, `:742-755`), Chamado (`mailto:suporte@blaxxpontos.com.br`,
  `:825`). Sem endpoint.

### 2.22 RewardsBackend.start() (sessão "por trás" do mock)
- Lê `WalletCache` (UserDefaults, validade 1 h) (`RewardsBackend.swift:64-66`).
- DEBUG: se não há token → `GET /health` (warm-up) → `POST /auth/login` com a conta demo embutida
  (`:67-77`, credenciais em `:266-271`) → senão `GET /auth/me`; se e-mail não verificado,
  `POST /auth/dev/verify-email` (`:84-88`); depois `GET /wallet/`.
- RELEASE: só `GET /auth/me` se já houver token no Keychain (`:95-113`). Como a árvore viva não
  tem tela de login real, um usuário novo em RELEASE nunca obtém token.

### 2.23 EmailVerifyGate (só RELEASE, `Rewards/EmailVerifyGate.swift`)
- "Verificação obrigatória / Confirme seu e-mail", "Enviar código por e-mail", campo de 6 dígitos,
  "Confirmar e-mail", "Reenviar código" (cooldown 30 s), "Sair".
- Endpoints: `POST /auth/verify-email/send`, `POST /auth/verify-email` body `{code}`, `GET /auth/me`.
- "Sair" (`:92-96`) limpa o Keychain mas não chama `backend.signOut()`; `refreshUserAndEmailStatus`
  falha sem token e o `user` continua preenchido, então o gate não some.

### 2.24 ResetPasswordView (deep link, legado mas vivo) e Push
- `POST /auth/reset-password` body `{token, password}` (`ResetPasswordView.swift:128`). Visual
  antigo (`BlaxxColor.gray50`, `BlaxxColor.black`).
- Push: permissão pedida no lançamento; token APNs seria enviado em `POST /push/devices/register`
  `{token, platform:"ios"}` (`API.swift:602-609`), mas o entitlement `aps-environment` foi removido
  (`BlaxxPontos.entitlements:11-26`) e `rebindAfterLogin()` nunca é chamado (`Push/PushService.swift:89-92`).

### 2.25 Tabela de mocks e dados fixos visíveis

| O quê | Arquivo:linha | Visível em |
|---|---|---|
| 5 programas (Smiles, TudoAzul, LATAM Pass, Livelo, Esfera), saldos, R$/mil, expirações, bônus 120/80/60% | `RewardsModel.swift:57-63` | Carteira, Parceiros, Trocar, Enviar (aba), sheet de programa — DEBUG e RELEASE |
| Contatos Marina Alves, Rafael Costa, Júlia Santos, Bruno Lima | `RewardsModel.swift:65-70` | Aba Enviar |
| Histórico por programa (12 jun · 2026 etc.) | `RewardsModel.swift:72-92` | Sheet de programa |
| Prazos de oferta "2d 14h" etc. | `RewardsModel.swift:103-104` | Offer sheet (inalcançável) |
| Patrimônio total = soma mock em R$ | `RewardsModel.swift:96-97`, `RewardsWalletView.swift:47-62` | Carteira |
| Séries do gráfico Mês/6m/Ano | `RewardsWalletView.swift:20-24` | Carteira |
| Sparkline do hero | `RewardsHomeView.swift:257-263` | Home |
| Bônus padrão 8% e 120.000 pts | `RewardsTradeSheet.swift:12-18`, `RewardsShell.swift:142-149`, `:185-192` | Trocar |
| Inicial "R" no avatar sem sessão | `RewardsHomeView.swift:93` | Home |
| FAQ, textos de ajuda | `RewardsAccountViews.swift:707-714`, `:742-755` | Ajuda/FAQ |
| Conta demo de homologação (e-mail e senha em claro no fonte, só DEBUG) | `RewardsBackend.swift:266-271` | — (código) |

---

## 3. Tema, componentes, fontes e marca

### 3.1 Tokens `RWColor` (`Rewards/RewardsTheme.swift:12-51`)
| Token | Valor | Uso |
|---|---|---|
| neon | #59FD27 | acento, texto sobre preto, chips selecionados (traço) |
| neonA / neonB | #6BFF3D / #34D60F | gradiente do FAB e do "Entrar"; slider e gráfico (neonB) |
| ink, ink2 | #0A0B0E | texto, bordas, fundo de CTA |
| screenBg | #E8E6DD | fundo papel |
| greenLight | #2BA014 | aba ativa, "Ver todas", ícones das ações rápidas |
| bonus | #2BA516 | valores positivos |
| muted | #9AA092 | ícones/labels inativos |
| amber | #E8A317 | erros, expiração |
| cardShadow | #0A0B0E @ 0.9 | sombra dura |
| heroSub/heroNum/rowBrl/rowExpiry/fieldLabel/chipPts/segFg/breakdownK | cinzas #7B8278…#B9BDB5 | textos secundários |
| chipBorder/chipSelBg/pctBg/pctFg/simBg/searchBg/txDivider | neutros claros | superfícies |
| countdownBg/countdownFg | #FFF4DE / #9A6B00 | selo de homologação, "saldo do último acesso" |
| heroGradient | #16181A → #0A0B0C | hero, cartões escuros |
| fabGradient | neonA → neonB | FAB, "Entrar", selo de sucesso |

Modificadores: `rwCardShadow()` = `.shadow(radius:0, x:5, y:5)` (`:83-85`); `rwBrutalCard(corner:16,
border:3)` = borda tinta + `rwCardShadow` (`:89-96`). Na prática a sombra do `.shadow` copia o
contorno e aparece como "contorno duplo" (fotos 09, 10, 13), diferente do `BrutalCardModifier`
de `Theme.swift:188-213`, que desenha um bloco sólido.
Formatação: `RWFormat.n` (pt-BR, sem decimais) (`:64-78`).

### 3.2 Tokens legados ainda usados pela árvore viva (`Theme.swift`)
- `BlaxxColor` (`:16-64`): `black` #0A0A0A (legado), `lime` #59FD27, `limeDark` #5AB800, cinzas,
  `paper`, `ink`, `brutal*`. Usados em `EmailVerifyGate` (via `Eyebrow`), `ProtectedSnapshot`
  (`black`, `lime`), `ResetPasswordView`.
- `BlaxxFont` (`:66-106`): `display()` resolve "Space Grotesk" / "SpaceGrotesk-Light"; `body`,
  `eyebrow` e `mono` são fontes do sistema (SF Pro / SF Mono).
- `Components.swift`: só `Eyebrow` é usado pela árvore viva (`EmailVerifyGate.swift:36`).
  `BlaxxCard`, `BalanceCard` (com "+8,42%" fixo, `Components.swift:104`), `TileRow` (emoji) etc.
  servem só ao código morto.

### 3.3 Componentes `RW*`
`RewardsComponents.swift`: `RWProgramLogo` (letra em badge colorido, `:13-28`), `RWProgramChip`
(`:32-69`), `RWFieldLabel` (`:73-82`), `RWCTA` primário/ghost/disabled (`:86-111`), `RWPctRow`
(`:115-136`), `RWGrabber`, `RWSheetHeader`, `RWBackHeader` (`:140-187`), `RWSuccessBadge`
(`:191-210`), `RWSlider` (step padrão 1.000, `:214-224`), `RWReceiveCard` (`:228-265`),
`RWBreakdownRow` (`:269-290`).
`RewardsFinanceSheets.swift`: `RWHomologBadge` (`:49-68`), `RWSheetError` (`:71-87`),
`RWSheetInput` (`:90-107`), `RWAmountCard` (privado, `:110-142`).
`RewardsAccountViews.swift`: `RWScreenHeader` (`:122-149`), `RWGroupLabel` (`:152-163`),
`RWNavRow` (`:166-212`), `RWListState` loading/empty/failed (`:215-243`), `RWDate` (`:248-294`).
`RewardsShell.swift`: `RWSheetContainer` (`:207-225`), `RWTabBar` (`:229-281`).
`RewardsHomeView.swift`: `RWSparkline`; `RewardsWalletView.swift`: `RWAreaChart`;
`RewardsTradeSheet.swift`: `RWSwapCard`.

### 3.4 Fontes embarcadas e registro
- Arquivo: `BlaxxPontos/Resources/Fonts/SpaceGrotesk.ttf` (137 KB, fonte variável; instâncias
  Light, Regular, Medium, Bold — família "Space Grotesk"). Pasta sincronizada → entra no target.
- Registro: `Info.plist` (custom, mesclado com `GENERATE_INFOPLIST_FILE = YES`) tem
  `UIAppFonts = [SpaceGrotesk.ttf]` e `ATSApplicationFontsPath = .` (`Info.plist:8-13`).
  Conferido no build: o `.app` contém `SpaceGrotesk.ttf` e o `Info.plist` final tem `UIAppFonts`.
- Uso: só títulos e números (`BlaxxFont.display`). O resto do texto do Rewards é
  `.system(size:)` (SF Pro). Pesos `.black`/`.heavy` pedidos em `display` não existem na fonte
  (máximo Bold 700).
- Divergência com o web "Embarque": a camada `blaxx/assets/blaxx-embarque.css:31-38, 58-59` usa
  **Archivo** (variável, wght 400-900, wdth 62-125; título 900 com largura 80%) e **Space Mono**
  nos rótulos. Nenhuma das duas está embarcada no iOS.

### 3.5 Assets de marca (`Assets.xcassets`)
| Asset | Conteúdo | Uso vivo |
|---|---|---|
| BlaxxSymbol | B neon #59FD27 (SVG) | header da Home (template, recolorido neon), cartão da Carteira |
| BlaxxWordmarkClaro | "Bla" #0A0B0E + "Xx" #5AB800 + linha "REWARDS" | header da Home, EmailVerifyGate |
| BlaxxWordmark | "Bla" branco + "Xx" #59FD27 + "REWARDS" | não usado pela árvore viva |
| BlaxxLockup | B + "BlaXx" + "REWARDS", branco/neon | login gate |
| BlaxxIcon | PNG | não usado pela árvore viva |
| AppIcon | 1024 claro/escuro/tinted + mac | ícone |
| AccentColor | **#C6F432** (lima legado) | tint do sistema (cursor, ProgressView sem tint etc.) |

Faltam no iOS os SVGs do web usados na barra do tema Embarque:
`blaxx/assets/marca/blaxx-wordmark-barra.svg` (só "BlaXx", Bla branco + Xx neon, para a barra
preta) e `blaxx-wordmark-barra-claro.svg` (Bla tinta + Xx neon com contorno tinta).

### 3.6 Tokens do web "Embarque" para comparação (`blaxx/assets/blaxx-embarque.css:42-64`)
Fundo #E4E1D9 (iOS #E8E6DD), superfície #FBFAF7 (iOS branco), linha #D9D6CE, cinza de texto
#555860, tinta #0A0B0E, neon #59FD27, verde do wordmark #5AB800 ("nunca texto"), raios 28/18/14/12/10/8,
sombras macias `0 18px 40px rgba(10,11,14,.08)` (iOS usa sombra dura Neo-Brutal deslocada).

---

## 4. Violações das regras do dono (arquivo:linha)

### 4.1 Valor do ponto / R$ do saldo
1. Hero da Home mostra o saldo convertido em reais (`balance_brl_equiv`) como número principal
   "Seu saldo R$ …": `Rewards/RewardsHomeView.swift:116-123`, `:150-156`.
2. "Patrimônio total R$ 25.350,00" (soma em R$ de pontos mock): `Rewards/RewardsWalletView.swift:48-53`.
3. R$ por programa: `Rewards/RewardsWalletView.swift:103`, `Rewards/RewardsPartnersView.swift:66`,
   `Rewards/RewardsProgramSheet.swift:36`; base do cálculo `Rewards/RewardsModel.swift:23,28,97`.
4. Taxa de conversão com "≈": `Rewards/RewardsModel.swift:145-147` exibida em
   `Rewards/RewardsTradeSheet.swift:94,111`.
5. Cotação de resgate em R$ ("Você recebe via PIX R$ X" a partir de `/redeem/quote`):
   `Rewards/RewardsFinanceSheets.swift:466-470`.
6. Linhas "Taxa de serviço / Grátis" e "Sem taxa" (o web tirou as linhas "Taxa" no commit b7b8dcd):
   `Rewards/RewardsTradeSheet.swift:113`, `Rewards/RewardsSendView.swift:182,208`.
7. Atenção (não é valor do ponto, mas é R$ na UI de pontos): progresso de campanha "x% de R$ alvo"
   `Rewards/RewardsCatalogViews.swift:235`; FAQ "Quanto vale um ponto BlaXx?"
   `Rewards/RewardsAccountViews.swift:743` (a resposta não dá valor).

### 4.2 Resgate apresentado como PIX (PIX só pode aparecer como pagamento da compra)
1. Sheet "Vender pontos" / "Você recebe via PIX" / "Resgatar via PIX" / "resgatar via PIX":
   `Rewards/RewardsFinanceSheets.swift:456,467,475,493`.
2. Textos finais "enviado para a sua chave PIX" / "O PIX sai em até 1 dia útil":
   `Rewards/RewardsFinanceSheets.swift:541,544`.
3. Menu "Resgatar em dinheiro": `Rewards/RewardsAccountViews.swift:345` (web: "Resgatar benefícios").
4. Ajuda "O valor sai por PIX…", "Prazo do resgate — O PIX pode sair…":
   `Rewards/RewardsAccountViews.swift:711-714`.
5. Perfil mostra "Chave PIX" (dado de resgate via PIX): `Rewards/RewardsAccountViews.swift:429`.
6. Ação rápida "Vender": `Rewards/RewardsHomeView.swift:178`.
   Vocabulário pedido: "benefícios em parceiros selecionados", "cartão ou transferência".

### 4.3 Parceiros, campanhas e saldos inventados visíveis em RELEASE
O mundo mock não tem gate de `#if DEBUG`; aparece igual em build Release:
1. Programas/saldos/bônus de companhias reais (Smiles, TudoAzul, LATAM Pass, Livelo, Esfera):
   `Rewards/RewardsModel.swift:57-63`; telas `RewardsWalletView.swift:86-113`,
   `RewardsPartnersView.swift:21-23,57-66`, `RewardsTradeSheet.swift:186-194`, `RewardsSendView.swift:136-145`.
   Inclui "Livelo" como parceiro visível (regra: nada de "Parceiro Livelo").
2. Ofertas "+120% / +80% / +60% bônus" (campanhas inventadas): `RewardsModel.swift:58-60`,
   `RewardsPartnersView.swift:57-64`; bônus "+8%": `RewardsShell.swift:148-149,191-192`,
   `RewardsTradeSheet.swift:16-17`.
3. Contatos inventados: `RewardsModel.swift:65-70` (aba Enviar).
4. Histórico inventado: `RewardsModel.swift:72-92`.
5. Gráficos/sparkline sugerindo evolução de patrimônio: `RewardsWalletView.swift:20-24`,
   `RewardsHomeView.swift:257-263`.
6. Confirmações falsas de operação: "Troca concluída! Os pontos já estão na sua carteira BlaXx."
   `RewardsTradeSheet.swift:129-142`; "Pontos enviados! A transferência foi concluída na hora."
   `RewardsSendView.swift:234-242`.
7. Login gate que "entra" sem credencial: `RewardsLoginView.swift:135,147,171`.

### 4.4 "fictícia"/homologação visível
- `RWHomologBadge` "Ambiente de homologação · PIX simulado · dados fictícios":
  `Rewards/RewardsFinanceSheets.swift:57`, exibido em `:219,338,480,664` e
  `RewardsAccountViews.swift:364`. Oculto em RELEASE (`BuildConfig.isProduction`), visível em
  DEBUG/TestFlight de desenvolvimento.

### 4.5 Ícones (regra: quadrado neon #59FD27 com desenho preto em traço; sem emoji)
1. Ações rápidas: SF Symbol verde #2BA014 sobre cartão branco: `RewardsHomeView.swift:187-189`
   (Trocar: neon sobre preto, `:189-196`).
2. Linhas do menu: ícone tinta sobre quadrado cinza #F1F3ED: `RewardsAccountViews.swift:176-181`.
3. Extrato: setas verde/tinta sobre fundo verde-claro/cinza: `RewardsActivityViews.swift:142-147`.
4. Histórico do programa: tinta sobre cinza: `RewardsProgramSheet.swift:66-71`.
5. "Enviar por link / QR": verde sobre círculo verde-claro: `RewardsSendView.swift:84-89`.
6. Campanhas: `megaphone.fill` (preenchido, não traço) sobre neon: `RewardsHomeView.swift:218-223`.
7. Emoji como ícone de benefício (fallback "🎁" e `image_emoji` do backend):
   `RewardsCatalogViews.swift:356`. Emoji/símbolo em texto de botão "Código copiado ✓":
   `RewardsAccountViews.swift:656`.
8. "Logos" de terceiros desenhados como letras em badges coloridos: `RewardsComponents.swift:13-28`,
   `RewardsProgramSheet.swift:26-31`, `RewardsOfferSheet.swift:39-44`, chips `RewardsComponents.swift:40-45`.
9. Estados vazios/erro com ícone cinza/âmbar solto: `RewardsAccountViews.swift:224-233`,
   `RewardsFinanceSheets.swift:487-489`. Tab bar e FAB fora do padrão (decidir se a regra vale para
   navegação): `RewardsShell.swift:256-280`.

### 4.6 Neon como texto sobre fundo claro
- Não há texto neon direto sobre fundo claro no estado normal. Exceção: `RWCTA` desabilitado aplica
  `opacity(0.4)` no botão inteiro; o texto neon fica sobre cinza claro e ilegível (foto 12,
  "Gerar PIX"): `RewardsComponents.swift:96-109`.
- Traço neon sobre branco (borda de chip selecionado, borda de pacote): `RewardsComponents.swift:63`,
  `RewardsFinanceSheets.swift:251` (não é texto, mas tem contraste baixo).

### 4.7 Marca
1. Wordmark montado como texto ("Bla" + "Xx" em Space Grotesk) em vez do asset:
   `RewardsWalletView.swift:135-137`, `RewardsCatalogViews.swift:49-51`.
2. Header da Home usa símbolo B + wordmark com "REWARDS", e não o wordmark "BlaXx" sozinho da barra
   do web: `RewardsHomeView.swift:63-79`. Assets de barra do web ausentes no xcassets.
3. `AccentColor` = #C6F432 (lima legado), não #59FD27: `Assets.xcassets/AccentColor.colorset/Contents.json`.
4. Overlay de snapshot usa preto legado #0A0A0A e texto "BlaXx Pontos" em vez do wordmark:
   `Util/ProtectedSnapshot.swift:34-42`. Nome de exibição do app "BlaXx Pontos"
   (`project.pbxproj`, `INFOPLIST_KEY_CFBundleDisplayName`).

---

## 5. Build de base

Comando (derivedData no scratchpad):
```
xcodebuild -project BlaxxPontos.xcodeproj -scheme BlaxxPontos \
  -destination 'platform=iOS Simulator,id=29702B3D-53FF-44C6-810D-D665C7C7636A' \
  -derivedDataPath <scratchpad>/dd-inventario build
```
Ambiente: Xcode 27.1 (27A9275), SDK iPhoneSimulator 27.1, `IPHONEOS_DEPLOYMENT_TARGET = 26.5`,
`SWIFT_VERSION = 5.0`, plataformas iOS/macOS/visionOS, bundle `Blaxx-Pontos-Inc.BlaxxPontos`.

Resultado: **`** BUILD SUCCEEDED **`** (exit 0), 0 erros, 51 avisos únicos:
- `API.swift` 27 (conformidades `Decodable/Encodable` isoladas no MainActor usadas no `actor BlaxxAPI`
  e `TokenStore.get()` em contexto de actor — viram erro no modo Swift 6);
- `GoogleAuthService.swift` 7 (isolamento de MainActor);
- `Text + Text` deprecado no iOS 26: `RewardsTradeSheet.swift:133-135`, `RewardsSendView.swift:237-239`,
  `RewardsWalletView.swift:136`, `RewardsFinanceSheets.swift:707`, `RewardsCatalogViews.swift:50`;
- código morto: `HomeView.swift` 2, `BuyView.swift` 2, `BenefitsView.swift` 1; `Theme.swift` 2;
  `Util/SSLPinning.swift` 1 (resultado de `withUnsafeBytes` não usado).

## 6. Fotos "antes" (iPhone 17 Pro, DEBUG, backend redirecionado para porta local morta)

Pasta: `docs/redesenho/fotos-ios-antes/` (PNG 1206×2622)
| Arquivo | Tela |
|---|---|
| 01-login-gate.png | tela inicial (gate mock) |
| 02-home.png | Home sem sessão (hero "—", campanhas vazias) |
| 03-carteira.png | Carteira (cartão sem sessão + patrimônio mock R$ 25.350) |
| 04-carteira-programas.png | Carteira rolada: 5 programas mock com R$ (conteúdo passa por baixo da barra de status) |
| 05-sheet-programa-smiles.png | sheet de programa com histórico mock |
| 06-sheet-trocar.png | sheet Trocar (≈, +8% bônus) |
| 07-enviar-aba.png | aba Enviar (contatos inventados) |
| 08-parceiros-aba.png | aba Parceiros (bônus e R$ mock) |
| 09-conta-menu.png | "Minha conta" (Visitante; contorno duplo nos cartões) |
| 10-conta-menu-fim.png | fim do menu + selo de homologação |
| 11-sheet-vender.png | Vender sem saldo ("resgatar via PIX") |
| 12-sheet-comprar.png | Comprar com `/pix/packages` falhando (lista vazia sem aviso; CTA desabilitado ilegível) |
| 13-extrato-erro.png | Extrato em erro (sem "tentar de novo") |

---

## 7. Outros achados (bugs, segurança, paridade)

1. RELEASE não tem login: `RewardsRoot` é mock e `RewardsBackend.start()` em Release só reaproveita
   token existente (`RewardsBackend.swift:95-113`). Redeem e transfer lançam erro em Release
   (`:173-192`). Login/cadastro/Google/esqueci-senha existem só no código morto (`LoginView`,
   `RegisterView`, `ForgotPasswordView`; `Session.loginWithGoogle` → `GoogleAuthService`).
2. Duas versões de "Enviar": aba Enviar = mock (`RewardsSendView`), ação rápida/menu = real
   (`RewardsTransferSheet`). Duas versões de "Trocar" (FAB e ação rápida) só mock; o próprio código
   diz que a troca entre programas ficou fora "por decisão do produto" (`RewardsAccountViews.swift:14`).
3. Credenciais da conta demo em claro no fonte (só DEBUG) e login silencioso automático contra a
   produção ao abrir a shell em DEBUG (`RewardsBackend.swift:67-94`, `:266-271`).
4. `signOut` não revoga token (`POST /auth/logout`) nem limpa `WalletCache`/perfil; depois de sair,
   a Home volta a mostrar "Saldo do último acesso" por até 1 h (`RewardsBackend.swift:258-264`,
   `Cache/WalletCache.swift`). "Sair da conta" leva à shell, não ao login.
5. `EmailVerifyGate` "Sair" não sai (`EmailVerifyGate.swift:92-96`).
6. `GET /pix/packages` sem checagem de status/erro (`API.swift:741-764`) → lista vazia muda.
7. Erros de campanhas na Home viram "nenhuma campanha" (`RewardsHomeView.swift:53`).
8. Elementos que parecem interativos e não fazem nada: filtro da Carteira (`RewardsWalletView.swift:34-40`),
   busca e "Enviar por link / QR" da aba Enviar (`RewardsSendView.swift:57-66,82-103`),
   "Ver comprovante" (`:244`), texto de Face ID sem biometria (`:217-223`).
9. `Idempotency-Key` não enviado em `/transfer/` e `/redeem/` (backend já suporta).
10. `RWSlider` com step 1.000 também no envio real: não dá para enviar valores fora de múltiplos de
    1.000 pelo slider (`RewardsComponents.swift:217`, `RewardsFinanceSheets.swift:690-693`).
11. Push: registra sem login e `rebindAfterLogin()` nunca é chamado; sem `aps-environment`.
12. Layout: conteúdo rolável passa por baixo da barra de status (foto 04); barra de status escura
    sobre o login escuro (foto 01).
13. Paridade com o web que falta no iOS: compra por cartão (`/payments/card`, web
    `comprar-livre.html`), lista real de parceiros (`/partners/`, 266 itens), "Início"/dashboard,
    cancelamento de envio, comprovante, cadastro e login reais, wordmark da barra, fontes Archivo +
    Space Mono, paleta e sombras do tema Embarque.
