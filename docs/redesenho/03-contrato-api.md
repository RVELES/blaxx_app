# 03 · Contrato da API para o app iOS

Levantamento feito em 22/10/2026, só leitura. Fontes:

- backend: `blaxx_exe/backend/app/api/*.py`, `services/*.py`, `models.py`, `config.py`, `__init__.py`;
- app: `BlaxxPontos/API.swift` e `BlaxxPontos/Rewards/RewardsBackend.swift`, mais as telas da árvore viva `Rewards/` para saber o que de fato é chamado;
- web: `blaxx/*.html` e `blaxx/assets/blaxx-app.js`, para ver como o Web Mobile consome cada rota;
- produção: só GET público em `https://blaxx-pontos-exe.onrender.com` (`/card/tiers`, `/partners/`, `/partners/<id>`, `/partners/categories`, `/benefits/`, `/campaigns/`, `/campaigns/<id>`, `/pix/packages`, `/pix/provider`, `/payments/card/config`, `/auth/terms/current`, `/health`). Nenhum POST, PUT ou DELETE foi feito. Nenhum login.

Legenda de autenticação: **público** (sem token), **Bearer** (`Authorization: Bearer <access_token>`), **Bearer+e-mail** (Bearer + e-mail verificado; sem isso volta 403 `EMAIL_NOT_VERIFIED`), **refresh** (Bearer com o `refresh_token`).

---

## 0. O que importa primeiro

1. **O PIX de compra em produção depende do C6, e o C6 cancelou a homologação.** Hoje `/pix/provider` responde `{"name":"c6","is_mock":false}`. Segundo o e-mail do C6 colado nesta conversa, a solicitação de homologação foi cancelada e só volta com um cadastro novo e credenciais novas. Com credenciais inválidas, `POST /pix/charge` cai no `except Exception` de `services/purchase.py:241` e responde **400** `"Não foi possível gerar a cobrança PIX agora. Tente de novo em alguns minutos."`, o que para o cliente parece uma falha passageira. Isso vale para a compra por pacote e para a compra livre por PIX, no app e no site. O Asaas já tinha caído antes. O único meio de compra que funciona em produção hoje é o cartão.
2. **O cartão em produção está em modo live.** `GET /payments/card/config` devolve `enabled:true`, `provider:"stripe"` e uma chave publicável `pk_live_…`. Uma compra por cartão feita contra produção cobra de verdade. O app não tem nenhuma chamada a `/payments/card/*` nem o SDK do Stripe.
3. **Na build Release o app não consegue entrar em conta.** `RewardsLoginView` é um portão de mentira: qualquer toque em "Entrar" abre o shell. `RewardsBackend.start()` em Release só usa um token que já esteja no Keychain, e nenhuma tela viva consegue emitir esse token. Não há login, Google, cadastro nem "esqueci a senha" ligados na árvore viva. Resultado: em Release o usuário vê só o mundo de mentira.
4. **A sessão não se renova.** O access token dura 30 min (`BLAXX_JWT_ACCESS_MIN`, padrão 30) e o refresh dura 30 dias, mas o app descarta o `refresh_token` e não chama `/auth/refresh`. Depois de 30 min, todas as rotas autenticadas voltam 401, sem reação.
5. **Duas chamadas do app estão erradas e falham sempre:**
   - `register` não manda `accept_terms`, `accept_privacy` e `accept_lgpd`, que são obrigatórios → 400 sempre;
   - `deleteAccount` não manda `confirm: "EXCLUIR MINHA CONTA"` → 400 sempre (o fallback `POST /auth/account/delete` não existe).
6. **Login com 2FA quebra o decode.** Com 2FA por SMS, `/auth/login` responde **200 sem `token`**, e `LoginResponse` falha com "campo ausente: 'token'". Com TOTP, a resposta é 401 `mfa_required`. O app não trata nenhum dos dois casos.
7. **Risco provável de cookie + CSRF nas escritas (PLAUSÍVEL, não reproduzido).** O login devolve `Set-Cookie blaxx_session`, e o `URLSession` do app guarda cookies. O backend procura o JWT primeiro no cookie (`JWT_TOKEN_LOCATION = ["cookies","headers"]`, `JWT_COOKIE_CSRF_PROTECT = True`). Na mesma execução em que houve login, um POST, PATCH ou DELETE com o cookie e sem `X-CSRF-TOKEN` levanta `CSRFError`. O `_bearer_user` engole esse erro e a resposta vira 401 `unauthorized`, mesmo com um Bearer válido. Conferi o comportamento no código do flask-jwt-extended 4.7.4: só `NoAuthorizationError` passa para a próxima localização. A correção no app é uma linha: `req.httpShouldHandleCookies = false`, ou `httpCookieStorage = nil` na configuração da sessão.
8. **A produção devolve dados que as regras do dono proíbem mostrar.** São 266 parceiros: 258 com descrição "Parceiro Livelo · …", 8 "fictícia usada nos exemplos", todos com `accrual_rule` ("2 pts/R$", "1 pt a cada R$ 3,00…") e `logo_emoji`. Os 10 benefícios ou são da BlaXx ou ficam nesses 8 parceiros fictícios. `wallet.balance_brl_equiv` e `redeem/quote.amount_brl/rate` expõem o valor do ponto. A descrição de extrato do resgate é "Resgate via PIX → chave", e várias mensagens de erro falam "PIX" no resgate. O web já filtra tudo isso (`detalhe-parceiro.html:370`). O app precisa filtrar também (ver §6).
9. **Faltam no backend (o app não tem como fazer sem mudança no servidor):**
   - edição de perfil (nome, chave de destino, CPF real de conta Google);
   - "indique e ganhe" (o `referral_code` do cadastro é ignorado, e `/auth/me` não traz código);
   - pré-visualização do destinatário de um envio;
   - lista de envios;
   - paginação do extrato;
   - chamados de suporte;
   - um sinal de "PIX disponível".
10. **"Venda de pontos" tem dois sentidos no web:**
    - `venda-pontos.html` é a landing B2B ("Solicitar proposta" → `contato.html`, cujo formulário não envia para lugar nenhum). Não tem endpoint, e o card de "Dashboard parceiro" traz números inventados (GMV R$ 2,8M, 18.420 usuários). Não deve ir para o app de cliente.
    - `vender-pontos.html` é o "Resgate por transferência" do cliente: `POST /redeem/`.

---

## 1. Regras que valem para todas as rotas

| Tema | Como é no backend | O que o app deve fazer |
|---|---|---|
| Base | `https://blaxx-pontos-exe.onrender.com`. O Render dorme, e a primeira chamada pode levar de 30 a 60 s. | Manter o `warmUp()` em `/health` antes de um POST sensível. |
| Token | O login devolve `token` = `access_token` (30 min), `refresh_token` (30 dias), `token_type:"Bearer"` e `user`. | Guardar **os dois** no Keychain. |
| Renovação | `POST /auth/refresh` com Bearer = refresh. É **rotação com reuse-detection**: reapresentar um refresh já usado mata a família inteira (`password_changed_at` sobe). | Renovar em single-flight, como o web faz (`blaxx-app.js:271`): N chamadas com 401 esperam a mesma renovação. |
| Revogação em massa | Troca de senha, reset, `sessions/revoke-all` e exclusão sobem `password_changed_at`. Todo token com `iat` anterior morre, inclusive o da sessão atual. | Depois de trocar a senha, pedir login de novo. |
| Formato de erro | Rotas próprias: `{"error": "...", "code"?: "...", ...}`. Rotas `@jwt_required` (`/auth/logout`, `/auth/refresh`): `{"msg": "..."}` com 401 (ou 422 se o token estiver malformado). 404, 405 e 429 do Werkzeug e do Flask-Limiter vêm em **HTML**. | Ler `error`, `code`, `msg`, `issues`, `mfa_required`, `attempts_left`, `retry_in`, `locked_until`. Mapear status sem corpo JSON. |
| 401 tem vários sentidos | Sessão inválida = 401 `{"error":"unauthorized"}`. Mas também é 401: senha atual errada (`change-password`), credenciais inválidas (login), `mfa_required` (login TOTP e step-up de envio/resgate), reauth Google falhou (exclusão), código MFA inválido. | Só tratar como "sessão expirada" quando `error == "unauthorized"` ou vier `msg` do JWT. |
| E-mail verificado | `@email_verified_required` responde 403 `{"error":"E-mail não verificado","code":"EMAIL_NOT_VERIFIED","action":"..."}`. Vale para `/transfer/`, `/redeem/` e `/benefits/<id>/redeem`. A compra **não** exige mais. | Mostrar o portão de verificação. |
| Idempotência | `Idempotency-Key` (header) é aceito em `/transfer/`, `/redeem/`, `/benefits/<id>/redeem` e `/payments/card/charge`. Sem ele: o envio cai na trava de 15 s (409 `DUPLICATE_SUSPECTED`), o resgate de benefício deduplica por minuto e o resgate por transferência não tem dedupe. | Gerar um UUID por intenção, repetir a mesma chave em retry de rede e rotacionar depois de uma resposta definitiva. |
| Step-up 2FA | Envio ou resgate ≥ 20.000 pts (`BLAXX_SENSITIVE_OP_THRESHOLD_PTS`), só para quem tem TOTP ativo: 401 `{"error":"código 2FA necessário…","mfa_required":true}`. Reenviar com `mfa_code`. | Tratar como pedido de código, não como logout. |
| Rate limit | Padrão de 200/min. Limites específicos aparecem em cada rota abaixo. O 429 vem em HTML. | Mensagem própria de "muitas tentativas". |
| Cookies | A resposta de auth seta `blaxx_session` + `csrf_access_token` (`SameSite=Strict`, `Secure`, `HttpOnly`). | **Desligar cookies no URLSession** (ver §0.7). |

---

## 2. Endpoints de cliente, por área

### 2.1 Autenticação (`/auth`)

| Método e path | Auth / limite | Corpo | Resposta 2xx | Erros |
|---|---|---|---|---|
| `POST /auth/register` | público · 5/min, 20/h | Obrigatórios: `name` (≥ 2 palavras), `email`, `cpf` (dígito verificador), `password` (política forte), `accept_terms`, `accept_privacy`, `accept_lgpd` (todos `true`). Opcionais: `phone` (BR → E.164), `birth_date` (`AAAA-MM-DD`, ≥ 18 anos), `pix_key`, `consent_text_hashes {terms,privacy,lgpd}`. `referral_code` aparece na docstring mas **não é lido**. | **201** com tokens + `user` + cookies. Efeitos: carteira zerada, notificação de boas-vindas, código de e-mail (30 min) enviado no e-mail de adesão, KYC do CPF (BrasilAPI). | 400 `{error}` (nome, e-mail, CPF, celular, data, idade, aceites; senha → `issues[{code,message}]`) · 409 "Este e-mail já está cadastrado" · 409 mensagem ambígua para CPF ou celular já usados (anti-enumeração) · 429 |
| `POST /auth/login` | público · 10/min, 60/h | `{email, password, mfa_code?}`. `email` aceita e-mail **ou** CPF; `cpf` também funciona. | 200 com tokens + `user`. **2FA SMS: 200** `{mfa_required:true, mfa_method:"sms", mfa_challenge_token, mfa_phone_hint, expires_in}`, sem token. | 401 "Credenciais inválidas" · 401 `{mfa_required:true, mfa_method:"totp", error:"Código MFA necessário"}` · 401 "Código MFA inválido" · 423 `{error, locked_until}` (5 falhas → 15 min; 10 → 1 h) · 429 `{code:"IP_RATE_LIMITED"}` (20 falhas por IP em 15 min) · 403 "Conta indisponível" · 500 MFA mal configurado |
| `POST /auth/login/2fa` | público · 10/min | `{challenge_token, code}` (6 dígitos) | 200 com tokens + `user` | 400 `code` ∈ `missing_challenge`, `invalid_code`, `challenge_expired`, `otp_not_found`, `code_expired`, `wrong_code` · 403 `account_inactive` |
| `POST /auth/google` | público · 20/min, 100/h | `{id_token, nonce?}`. O audience iOS `105341431878-…` está aceito (`config.py:372`). | 200 com tokens + `user`. Conta nova: `cpf = "G:<sub>"`, sem senha, e-mail já verificado. | 400 `id_token ausente` · 401 token, issuer, nonce, e-mail não verificado no Google · 503 não configurado |
| `POST /auth/refresh` | **refresh** | — | 200 `{access_token, token, refresh_token, token_type}` | 401/422 `{"msg"}` · 404 `user not found` |
| `GET /auth/me` | Bearer | — | 200 `{id, name, email, cpf, phone, pix_key, avatar_url, auth_provider, email_verified_at, role, is_vip, mfa_enabled, status, has_password, google_linked}` | 401 `unauthorized` |
| `POST /auth/logout` | Bearer (`@jwt_required`) · 30/min | `{}` | 200 `{ok:true, revoked:true}` | 401/422 `{"msg"}` · 400 token inválido |
| `POST /auth/forgot-password` | público · 3/min, 15/h | `{email}` | sempre 200 `{ok:true}`. O link do e-mail é `FRONTEND_URL/redefinir-senha?token=…` (site, não o app). | — |
| `POST /auth/reset-password` | público · 5/min, 20/h | `{token, password}` | 200 `{ok:true}`. Derruba todas as sessões. | 400 obrigatórios / política (`issues`) / "Token inválido" / "já utilizado" / "expirado" (30 min) · 404 |
| `POST /auth/change-password` | Bearer · 10/h | `{old_password, new_password}` | 200 `{ok:true}`. **Derruba a sessão atual também.** | 400 conta só Google ("Defina uma senha em 'Esqueci a senha'") · **401 "Senha atual incorreta"** · 400 política + `issues` |
| `POST /auth/verify-email/send` | Bearer · 3/min, 10/h | `{}` | 200 `{ok, expires_in_min:10, _dev_code?}` (`_dev_code` só fora de produção) | 400 "E-mail já verificado" |
| `POST /auth/verify-email` | Bearer · 5/min | `{code}` | 200 `{ok, verified_at}` ou `{ok, already_verified:true}` | 400 obrigatório / nenhum pendente / expirado / "Código incorreto" + `attempts_left` · 429 ao passar de 3 tentativas |
| `POST /auth/dev/verify-email` | Bearer | `{}` | 200 `{ok, verified_at}` | **404 em produção**, a não ser que `ENABLE_DEV_ENDPOINTS=1` |
| `POST /auth/mfa/setup` | Bearer · 5/h | `{}` | 200 `{secret, uri}` (otpauth para QR) | 400 "MFA já está ativado" |
| `POST /auth/mfa/enable` | Bearer · 5/h | `{code}` | 200 `{ok, mfa_enabled:true}` | 400 código ausente ou setup não iniciado · 401 código inválido |
| `POST /auth/mfa/disable` | Bearer · 5/h | `{password, code}` | 200 `{ok, mfa_enabled:false}` | 401 senha ou código |
| `POST /auth/sessions/revoke-all` | Bearer | `{}` | 200 `{ok:true}` (derruba a sessão atual também) | — |
| `DELETE /auth/account` | Bearer · 3/dia | Com senha: `{password, confirm:"EXCLUIR MINHA CONTA"}`. Conta só Google: `{google_id_token, confirm}`. | 200 `{ok, message}`. Anonimiza os dados pessoais, mantém o ledger, retém o CPF por 5 anos e revoga tudo. | 400 "Confirmacao invalida" · 400 `code:"google_reauth_required"` · 401 "Senha incorreta" / "Reautenticação Google falhou" |
| `GET /auth/account/export` | Bearer · 3/dia | — | 200 JSON (attachment) com perfil, carteira, transações, vouchers, notificações, logs e consentimentos. Traz `balance_brl_equiv`, que não deve aparecer em tela. | — |
| `GET /auth/terms/current` | público | — | 200 `{version:"1.0"}` | — |
| `POST /auth/terms/reaccept` | Bearer | `{accept_terms, accept_privacy, accept_lgpd}` | 200 `{ok, version}` | 400 |

### 2.2 Segurança da conta (`/user`)

| Método e path | Auth / limite | Corpo | Resposta | Erros |
|---|---|---|---|---|
| `POST /user/phone` | Bearer · 5/min, 30/h | `{phone}` | 200 `{message, phone_masked}` (envia OTP por SMS) | 400 `invalid_phone` · 429 `cooldown` + `retry_in` · 409 `phone_in_use` |
| `POST /user/phone/verify` | Bearer · 10/min | `{code}` | 200 `{message, user}` | 400 `invalid_code`, `no_pending_code`, `code_expired`, `wrong_code` |
| `DELETE /user/phone` | Bearer | `{password}` | 200 `{user}` (desliga o 2FA por SMS se estiver ativo) | 400 `wrong_password` |
| `POST /user/2fa/sms/enable` | Bearer · 5/h | `{password}` | 200 `{message, user}` | 400 `password_required`, `phone_not_verified` · 403 `invalid_password` |
| `POST /user/2fa/sms/disable` | Bearer · 5/h | `{password}` | 200 `{message, user}` | 400 `wrong_password` |
| `GET /user/sessions` | Bearer | — | 200 `{sessions:[{id, device_name, ip_address, user_agent, created_at, last_used_at, expires_at, current}]}` | — |
| `DELETE /user/sessions/<id>` | Bearer | — | 200 `{ok:true}` ou `{message:"Sessão já revogada"}` | 404 `session_not_found` |
| `GET /user/access-log?limit=50` | Bearer | — | 200 `{items:[{event, ip (mascarado), user_agent, device, status, reason, metadata, at}]}` (limit de 1 a 200) | — |

Observação: `/auth/me` não traz `phone_verified` nem `mfa_method`, então a tela de segurança não sabe se o celular foi verificado nem qual 2FA está ligado. O web tem o mesmo problema.

### 2.3 Carteira e extrato (`/wallet`)

| Método e path | Auth | Resposta | Observações |
|---|---|---|---|
| `GET /wallet/` | Bearer | `{id, user_id, balance_pts, pending_pts, balance_brl_equiv}` | `pending_pts` = envio retido na janela de 60 s. **`balance_brl_equiv` é o valor do ponto: nunca exibir.** A leitura também promove envios pendentes cuja janela já passou. |
| `GET /wallet/transactions?limit=20` | Bearer | `{items:[{id, type, status, amount_pts, description, reference, created_at}]}` | `limit` ≤ 100 e **sem paginação**. `type` ∈ `purchase`, `transfer_out`, `transfer_in`, `redeem`, `refund`, `bonus`, `expire`, `accrual`. `status` ∈ `pending`, `confirmed`, `reversed`. Débito vem negativo. Descrições do servidor: "Resgate via PIX → <chave>", "Envio (pending) para <nome>" (o texto não muda depois de efetivado), "Recebido (cód. ENV-…)", "Reversão de envio cancelado #…" (tipo `transfer_in`), "Compra de pontos — pacote plus", "Compra de pontos no cartão — …", "Compra em <rede>", "Expiracao automatica · …". **O app precisa montar o rótulo pelo `type` e não mostrar `description` cru.** |

### 2.4 Cartão BlaXx e nível (`/card`)

| Método e path | Auth | Resposta |
|---|---|---|
| `GET /card/` | Bearer | `{member:{id (8 hex maiúsculo), name}, balance_pts, lifetime_points, tier, next_tier, points_to_next, progress_pct, tiers[], wallet_pass_available}`. `tier` tem a forma `{key, label, min_points, color, text_color, perks, invite_only?}`. |
| `GET /card/tiers` | público | `{tiers:[…]}`. Em produção: Bronze 0, Prata 5.000, Ouro 20.000, Black 50.000, BlaXx VIP (por convite). Os `perks` do Bronze dizem "…catálogo de benefícios e PIX." e o `text_color` do Black é `#C6FF00` (lime legado). **Não usar `perks` nem as cores da API como estão.** |
| `GET /card/pass/status` | Bearer | `{available}` |
| `GET /card/pass` | Bearer | `.pkpass` (`application/vnd.apple.pkpass`) · 503 `{error:"wallet_not_configured"}` · 500 `pass_generation_failed` |

### 2.5 Parceiros (`/partners`), todos públicos

| Método e path | Filtros | Resposta |
|---|---|---|
| `GET /partners/` | `?category=` (exato), `?q=` (nome ou descrição) | `{items:[{id, name, category, description, logo_emoji, accrual_rule, city, is_active}]}` |
| `GET /partners/<id>` | — | parceiro + `benefits:[Benefit]` · 404 "Parceiro não encontrado" |
| `GET /partners/categories` | — | `{items:[string]}`. Em produção são 45 categorias, com duplicatas como "Farmácia"/"Farmácias" e "Casa"/"Casa & Decoração". |

Para o app: **nunca** exibir `accrual_rule`, `logo_emoji` nem `description` quando ela casar com `/parceiro\s+livelo|fict[ií]ci|\bpix\b|a\s+cada\s+R\$|pts?\s*\/\s*R\$/i` (mesma regra do `textoValido` do web). O ícone sai da categoria, como no `icoCategoria` do web.

### 2.6 Benefícios, resgate e vouchers

| Método e path | Auth / limite | Corpo | Resposta | Erros |
|---|---|---|---|---|
| `GET /benefits/` | público | `?category=`, `?partner_id=`, `?max_pts=` | `{items:[{id, partner_id, partner_name, name, description, category, cost_pts, image_emoji, stock (-1 = ilimitado), expires_in_days, is_active, tag}]}` | — |
| `GET /benefits/<id>` | público | — | Benefit | 404 |
| `POST /benefits/<id>/redeem` | Bearer+e-mail · 20/h por usuário | `{}` + header `Idempotency-Key` opcional | **201** Voucher. Replay com a mesma chave → 200 com o mesmo voucher. | 404 · 409 "Sem estoque disponível" · **402** "Saldo insuficiente" · 403 `EMAIL_NOT_VERIFIED` |
| `GET /vouchers/` | Bearer | — | `{items:[{id, user_id, benefit_id, benefit_name, code, points_spent, expires_at, used_at, status (active, used, expired), created_at}]}` | — |
| `GET /vouchers/<id>` | Bearer | — | Voucher | 404 |

Categorias de benefício em produção: `sorteio`, `desconto`, `social`, `voucher`, `assinatura`, `educacao`, `experiencia`, `viagem`. O web tem um mapa de ícone e rótulo para elas (`detalhe-parceiro.html`, `BENEFICIO` e `ROTULO`).

### 2.7 Campanhas (`/campaigns`)

| Método e path | Auth | Resposta | Erros |
|---|---|---|---|
| `GET /campaigns/` | público; com Bearer válido acrescenta adesão | `{items:[{id, name, description, mechanic, target_brl, reward_pts, period_start, period_end, is_active, joined, progress_brl, progress_pct, completed_at}]}` | — |
| `GET /campaigns/<id>` | público | Campaign, sem os campos de adesão | 404 |
| `POST /campaigns/<id>/join` | Bearer | 201 `UserCampaign {id, user_id, campaign_id, campaign, progress_brl, progress_pct, completed_at, joined_at}`. Se já aderiu, 200. | 404 |
| `GET /campaigns/mine` | Bearer | `{items:[UserCampaign]}` (confirmado em produção: 401 sem token, então a rota existe) | — |
| `POST /campaigns/<id>/progress` | **admin** | — | não é de cliente |

O que está em produção hoje: "Pacote Premium", "Família engajada" ("Convide 3 amigos…", que depende de indicação, e indicação não existe) e "Maio em dobro" ("Gaste R$ 500 em parceiros elegíveis", sem integração de parceiro; o progresso só anda se um admin lançar). Os `mechanic` trazem "A cada R$ 100 movimentados…", texto proibido. **Não exibir `mechanic` cru.** Decidir com o dono se essas campanhas aparecem em Release.

### 2.8 Compra de pontos por PIX (`/pix`)

| Método e path | Auth / limite | Corpo | Resposta | Erros |
|---|---|---|---|---|
| `GET /pix/packages` | público | — | **objeto** `{start:{label,points,price_brl}, plus:{…}, prime:{…}, black:{…}}`. Em produção: Start 2.000 / R$ 180; Plus 5.500 / R$ 470; Prime 12.000 / R$ 972; Black 28.000 / R$ 2.142. | — |
| `GET /pix/provider` | público | — | `{name, is_mock}`. Produção: `c6`, `false`. | — |
| `POST /pix/charge` | Bearer · 10/h por usuário | `{package}` **ou** `{amount_brl}` (R$ 10 a 100.000; VIP sem teto). E-mail verificado não é exigido. | **201** `PixCharge {id, user_id, package (= "custom" na compra livre), amount_brl, points_to_credit, txid, br_code, qr_code_image (data URI ou null), status, flow, expires_at (30 min), paid_at, claimed_paid_at}` | **400** `{error}`: pacote desconhecido, ambos/nenhum, valor mínimo ou máximo, limite mensal (100.000 pts, "restam N pts"), sanções, CPF ou e-mail inválido para cobrança (conta Google com `G:`), **provider indisponível**. Este último é o caso permanente agora que o C6 cancelou. |
| `GET /pix/charge/<id>` | Bearer | — | PixCharge. Para o C6, consulta o provedor quando está pendente e credita se já foi pago. Também expira por TTL. | 404 `{error:"not found"}` |
| `GET /pix/charge/<id>/events` | Bearer · 2/min | — | SSE (`event: status`), 3 min no máximo | não recomendado no app; usar polling |
| `GET /pix/my-charges` | Bearer | — | `{items:[PixCharge]}` (50) | — |
| `POST /pix/custom-charge` | Bearer · 10/h | `{amount_brl}` | 201 PixCharge + `qr_image_url:"/static/pix-qr-blaxx.png"` + `instructions` (QR estático, confirmação manual pelo admin) | 400 · **503 `BRCODE_NOT_CONFIGURED`** |
| `POST /pix/custom-charge/<id>/claim-paid` | Bearer | `{}` | 200 `{ok, status:"pending_confirmation"}` | 404 · 400 |
| `POST /pix/simulate-payment` | Bearer | `{charge_id}` | 200 `{ok, charge}` | **404 em produção** · 403 se o provider não for mock |

Status de `PixCharge`: `pending`, `pending_confirmation`, `paid`, `expired`, `refunded`, `rejected`.

### 2.9 Compra por cartão (`/payments/card`); não confundir com `/card`, que é o cartão-fidelidade

| Método e path | Auth / limite | Corpo | Resposta | Erros |
|---|---|---|---|---|
| `GET /payments/card/config` | público | — | `{enabled, provider:"stripe", public_key, max_installments:1, currency:"brl"}`. **Produção: `enabled:true`, chave `pk_live_…`.** | — |
| `POST /payments/card/charge` | Bearer · 10/h | `{package}` ou `{amount_brl}`, mais `card_token` (= `pm_…` do Stripe), `payment_method_id` (bandeira), `installments:1`, `issuer_id:""`. Header `Idempotency-Key`. **Proibido mandar** número, CVV ou validade (varredura recursiva). | 201 `CardCharge {id, method:"card", package_key, amount_cents, amount_brl, points_to_credit, status (approved, in_process, …), status_detail, installments, card_brand, card_last4, paid_at, created_at}` | 503 `CARD_DISABLED` · 400 `RAW_CARD_DATA` · 400 `{error}` (token ausente, bandeira, pacote, valor, limite mensal, "compra duplicada", **recusado pelo emissor**, gateway fora do ar: "se o valor for cobrado, os pontos serão creditados automaticamente") |
| `GET /payments/card/charge/<id>` | Bearer | — | CardCharge (polling do `in_process`) | 404 |
| `GET /payments/card/my-charges` | Bearer | — | `{items:[CardCharge]}` | — |

Cartão no iOS: tokenizar com o SDK do Stripe (`STPAPIClient.createPaymentMethod`) usando a `public_key` do `/config`. O backend confirma o PaymentIntent com `allow_redirects=never`, então um cartão que exija 3DS com redirect volta recusado. Antes de investir nisso, vale avaliar a App Store Review Guideline 3.1.1: compra de "pontos" fora da compra in-app é risco de revisão, a confirmar com o dono.

### 2.10 Compra livre

Não tem endpoint próprio. Usa `POST /pix/charge {amount_brl}` ou `POST /payments/card/charge {amount_brl,…}` (web: `comprar-livre.html` e `assets/comprar-livre.js`). Os limites são os mesmos: mínimo R$ 10, máximo R$ 100.000 por compra e 100.000 pts por mês.

### 2.11 Envio P2P (`/transfer`)

| Método e path | Auth / limite | Corpo | Resposta | Erros |
|---|---|---|---|---|
| `POST /transfer/` | Bearer+e-mail · 20/h | `{to, amount_pts, password, message? (≤ 140), mfa_code?}`. `to` aceita e-mail, CPF ou **Cartão BlaXx** (8 hex, com ou sem espaço ou hífen). Headers opcionais: `Idempotency-Key`, `X-Device-Id`, `X-Platform`. | **201** `Transfer {id, sender_id, recipient_id, amount_pts, message, receipt_code ("ENV-2026-XXXX-XXXXXXXX"), created_at, status:"pending", committed_at (= agora + 60 s), cancelled_at, is_cancellable}` | 400 `{error}`: "senha incorreta" (**400, não 401**), "valor mínimo é 100 pts", "destinatário não encontrado", "não é possível enviar pontos para si mesmo", limite diário ou mensal (50.000 pts, "restam N"), mensagem > 140, sanções · 401 `mfa_required` (≥ 20.000 com TOTP) · 403 `EMAIL_NOT_VERIFIED` · **409 `DUPLICATE_SUSPECTED`** + `previous_transfer_id` + `hint` (mesmo valor e destinatário em 15 s sem chave) · **429 `RECIPIENT_PROBE_BLOCKED`** (varredura de destinatários) |
| `POST /transfer/<id>/cancel` | Bearer · 60/h | `{}` | 200 Transfer com `status:"cancelled"` | 404 · 403 "apenas o remetente" · 400 "já efetivada (janela de 60s expirada)" |

**Janela e confirmação.** Não existe endpoint de "confirmar". O valor sai do saldo, fica em `pending_pts` do remetente e é efetivado depois de 60 s **de forma preguiçosa**: só quando o remetente ou o destinatário chamam `GET /wallet/` ou `GET /wallet/transactions`. Não há cron. É só na efetivação que o destinatário recebe crédito e notificação. O app deve: (a) mostrar um "Desfazer" por 60 s com `/transfer/<id>/cancel`; (b) reler `/wallet/` uns 61 s depois do envio, para efetivar e disparar a notificação do destinatário.

Também não existem: pré-visualização do nome do destinatário, lista de envios e contatos recentes (dá para derivar do extrato via `reference` = id do envio).

### 2.12 Receber / QR

Não tem endpoint. O backend aceita o **Cartão BlaXx** (os 8 primeiros hex do `user.id`, que é o `member.id` de `/card/`) como destino de `/transfer/`, então o QR de receber pode ser gerado no aparelho com esse código ou com o e-mail. `receber-pontos.html` no web é estático, com dados inventados ("Lucas enviou 2.000 pts para Mariana", Starbucks, Carrefour). **Não portar.**

### 2.13 Venda de pontos e resgate por transferência (`/redeem`)

- **B2B (`venda-pontos.html`)**: landing comercial. Sem endpoint. O CTA vai para `contato.html`, cujo `<form>` faz GET para `venda-pontos.html` e não envia nada. Os números do card "Dashboard parceiro" são inventados. **Fora do app de cliente.**
- **Cliente (`vender-pontos.html`, "Resgate por transferência")**:

| Método e path | Auth / limite | Corpo | Resposta | Erros |
|---|---|---|---|---|
| `GET /redeem/quote?points=N` | Bearer | — | `{points, amount_cents, amount_brl, rate, cents_per_point}` | 400. **Não exibir**: é o valor do ponto. O web parou de mostrar R$ em 15/10. |
| `POST /redeem/` | Bearer+e-mail · 10/h | `{points, pix_key, password, mfa_code?}`. Header `Idempotency-Key` (≤ 64). O web manda a chave do perfil (`/auth/me.pix_key`, ou o e-mail como fallback) e exige no mínimo 1.000 pts no front. O backend aceita a partir de `REDEEM_MIN_POINTS` (1). | **201** `PixPayout {id, user_id, points_debited, amount_brl, pix_key, txid, end_to_end_id, status (requested, processing, paid, failed), failure_reason, paid_at, created_at}`. Replay → 200. Com `PAYOUT_MODE` manual fica `processing` até o admin pagar. | 400 `{error}`: "senha incorreta", "Para resgatar via PIX, complete seu CPF real…" (conta Google: **não tem como resolver no app, porque não existe endpoint de CPF**), KYC indisponível ou inválido, mínimo, "chave PIX inválida", limites (valores padrão do `config.py`, que o ambiente pode mudar: diário 1.111.111; mensal 100.000), saldo, duplicado · 401 `mfa_required` · 403 `EMAIL_NOT_VERIFIED` |
| `GET /redeem/<id>` | Bearer | — | PixPayout (acompanhamento) | 404 |

Vocabulário: as mensagens do servidor dizem "PIX". O app precisa traduzir para "transferência" (regra do dono).

### 2.14 Indique e ganhe

**Sem backend.** `POST /auth/register` ignora `referral_code`. `UserProfile.referral_code` existe no modelo, mas nada escreve nem lê esse campo. `/auth/me` não traz código. O web (`indique.html:225`) monta um código no cliente (primeiro nome + 4 últimos caracteres do id) e um link `/cadastro?ref=`, mas esse código não credita nada. No app, ou fica de fora, ou só como "compartilhar o app" sem prometer bônus, até o backend existir.

### 2.15 Notificações (`/notifications`)

| Método e path | Auth | Resposta | Erros |
|---|---|---|---|
| `GET /notifications/` | Bearer | `{items:[{id, user_id, type, title, body, icon, reference, read_at, is_read, created_at}], unread_count}` (100 no máximo) | — |
| `GET /notifications/unread-count` | Bearer | `{count}` | — |
| `PATCH /notifications/<id>/read` | Bearer | a notificação atualizada | 404 |
| `POST /notifications/read-all` | Bearer | `{updated}` | — |

`icon` vem com glifo do servidor ("★", "✓", "✦", "💸"). **Não exibir como ícone.** Mapear `type` (`system`, `voucher`, `campaign`, `transfer`, `purchase`, `expiration`) para os ícones da marca. Alguns `body` vêm com texto proibido, por exemplo "…Complete seu CPF no Perfil para liberar resgates PIX." no boas-vindas do Google, e "Meta: R$ … Bônus: … pts" na adesão a campanha.

### 2.16 Perfil

Só leitura via `GET /auth/me`. **Não existe endpoint para editar** nome, chave de destino, CPF, avatar ou endereço. O web chama `PATCH /user/profile` e `PATCH /user/password`, que **não existem** e dão 404 (`blaxx-app.js:3014` e `:3088`). Também chama `/auth/logout-all` e `/auth/resend-verification`, que não existem. Nada disso deve ser copiado para o app.

### 2.17 Privacidade e push

| Método e path | Auth | Corpo | Resposta |
|---|---|---|---|
| `GET /privacy/consents` | Bearer | — | `{items:[{id, type, version, accepted_at, status, ip, user_agent, text_hash, revokes_consent_id}]}` |
| `POST /privacy/consents` | Bearer | `{type ∈ terms, privacy, lgpd, marketing, cookies_analytics, cookies_marketing; version; text_hash? (sha256)}` | 201 consentimento · 400 |
| `DELETE /privacy/consents/<id>` | Bearer | — | 200 `{original, revocation}` · 404 · 400 já revogado |
| `POST /push/devices/register` | Bearer | `{token, platform:"ios", app_version?}` | 201 `{id, platform, app_version, registered_at, last_used_at, revoked}` · 400 |
| `DELETE /push/devices/<id>` | Bearer | — | `{ok}` · 404 |
| `GET /push/devices` · `GET /push/status` | Bearer | — | `{items}` · status do provedor |

### 2.18 Exclusão de conta

Ver `DELETE /auth/account` em §2.1.

---

## 3. O que o app chama hoje

"Viva" = chamado a partir de `RewardsRoot` → `RewardsShell`. "Morta" = só existe em `API.swift` ou em telas mortas.

| Método em `API.swift` | Rota | Na árvore viva? | Situação |
|---|---|---|---|
| `warmUp` | GET `/health` | sim (DEBUG) | ok |
| `login` | POST `/auth/login` | só DEBUG (login silencioso com a conta demo) | sem `mfa_code`. O decode quebra no 2FA por SMS. O `refresh_token` é descartado. |
| `register` | POST `/auth/register` | não | **errado**: faltam os 3 aceites → 400 sempre |
| `me` | GET `/auth/me` | sim | `BlaxxUser` sem `has_password` e `google_linked` |
| `loginWithGoogle` | POST `/auth/google` | não | contrato certo; falta ligar na tela |
| `logout` | POST `/auth/logout` | não | `signOut()` só limpa o Keychain |
| `forgotPassword` / `resetPassword` | `/auth/forgot-password`, `/auth/reset-password` | reset só por deep link `blaxxpontos://` (`BlaxxPontosApp.swift:46`) | o e-mail aponta para o site, e não há Universal Link |
| `changePassword` | POST `/auth/change-password` | sim (`RWSecurityView`) | contrato certo. Não trata o 401 de senha errada como algo diferente de sessão, nem a revogação da sessão depois do sucesso. |
| `deleteAccount` | DELETE `/auth/account` → fallback POST `/auth/account/delete` | sim | **errado**: falta `confirm`, conta Google sem `google_id_token`, e o fallback não existe |
| `resendEmailVerification` / `verifyEmail` | `/auth/verify-email/send`, `/auth/verify-email` | sim (`EmailVerifyGate`, só Release) | ok |
| `devVerifyEmail` | POST `/auth/dev/verify-email` | DEBUG, **contra produção** | depende de `ENABLE_DEV_ENDPOINTS=1` em produção |
| `registerDevice` | POST `/push/devices/register` | sim, na abertura do app | roda antes de existir sessão → 401. `rebindAfterLogin()` nunca é chamado. |
| `notifications` / `markNotificationRead` / `markAllNotificationsRead` | `/notifications/*` | sim | ok. Mostra o `icon` do servidor? Conferir no redesenho. |
| `partners` / `partnerCategories` / `partner` | `/partners/*` | **não** | as telas Carteira e Parceiros usam programas de mentira |
| `benefits` / `redeemBenefit` / `myVouchers` | `/benefits/`, `/benefits/<id>/redeem`, `/vouchers/` | sim | sem `Idempotency-Key`. Usa `image_emoji` como ícone (`RewardsCatalogViews.swift:356`). Mostra `partner_name` de parceiros fictícios. 402 e 409 não têm mensagem própria. |
| `benefit(id)` | GET `/benefits/<id>` | não | — |
| `campaigns` / `joinCampaign` | `/campaigns/`, `/campaigns/<id>/join` | sim (Início e Campanhas) | ok |
| `wallet` | GET `/wallet/` | sim | **mostra `balance_brl_equiv` como número principal do Início** (`RewardsHomeView.swift:155`), o que é proibido |
| `transactions` | GET `/wallet/transactions?limit=50` | sim | mostra `description` cru (`RewardsActivityViews.swift:149`), com "Resgate via PIX → chave" e "Envio (pending)…" |
| `card` | GET `/card/` | sim | ok |
| `tiers` / `walletPass` | `/card/tiers`, `/card/pass` | não | não tem botão "Adicionar à Carteira" |
| `packages` | GET `/pix/packages` | sim | usa `URLSession` direto, **sem olhar o status HTTP** e sem retry |
| `createCharge(package:)` / `createCharge(amountBRL:)` / `getCharge` | `/pix/charge`, `/pix/charge/<id>` | sim | contrato certo. O 400 do provedor fora do ar vira "Não foi possível gerar o PIX" (`RewardsFinanceSheets.swift:381`), sem diferenciar o caso permanente. |
| `providerInfo` / `simulatePayment` | `/pix/provider`, `/pix/simulate-payment` | sim, simular só em DEBUG | em produção `is_mock` é false e a rota dá 404, então o botão não aparece. Ok. |
| `createCustomCharge` / `claimChargePaid` / `myCharges` | `/pix/custom-charge*`, `/pix/my-charges` | não | — |
| `transfer` | POST `/transfer/` | sim, mas só pela folha "transfer". Em Release lança "Operação indisponível nesta build." | sem `Idempotency-Key`, `mfa_code` e `X-Platform`. Ignora `status` e `is_cancellable`. Sem cancelar. |
| `redeemQuote` / `redeem` | `/redeem/quote`, POST `/redeem/` | sim. Em DEBUG usa a senha demo; em Release lança erro. | **mostra o R$ da cotação e o texto "Você recebe via PIX" / "Resgatar via PIX"** (`RewardsFinanceSheets.swift:467,475`), proibido. Sem `Idempotency-Key`. Sem `GET /redeem/<id>`. |
| `admin*` | `/admin/*` | não (`AdminView` é morta) | fora do escopo de cliente |

Detalhes da camada HTTP (`BlaxxAPI.request`):

- o erro lê só `error`, e perde `code`, `issues`, `msg`, `mfa_required`, `attempts_left`, `retry_in`, `locked_until`;
- a dica de rede manda "Suba o Flask em outro Terminal…", texto de desenvolvedor que aparece também em Release (`API.swift:391`);
- retry só em GET, certo;
- cookies ligados (ver §0.7).

`RewardsBackend` em DEBUG tem e-mail e senha de uma conta demo **escritos no código** e faz login nela **em produção**. Isso não vai para Release (fica atrás de `#if DEBUG`), mas é uma credencial no repositório e uma conta de teste no banco de produção.

---

## 4. O que é mock hoje na árvore viva

| Tela ou folha | Fonte | Observação |
|---|---|---|
| `RewardsLoginView` / `RewardsRoot` | nenhuma | qualquer toque entra; não autentica |
| Aba **Carteira** (`RewardsWalletView`) | `RewardsStore.programs` | Smiles, TudoAzul, LATAM Pass, Livelo e Esfera com saldos inventados e **R$ por programa** (`brlPerK`). O total em R$ é mock. |
| Aba **Parceiros** (`RewardsPartnersView`) | `RewardsStore.programs` | "pts · R$" por programa. Não chama `/partners/`. |
| Aba **Enviar** (`RewardsSendView`) | `RewardsStore.contacts` + `programs` | contatos inventados (Marina Alves, Rafael Costa…). `applySend` só mexe no saldo local. O envio real fica na folha `RewardsTransferSheet`. |
| Folhas **Trocar / Oferta / Programa** (`RewardsTradeSheet`, `RewardsOfferSheet`, `RewardsProgramSheet`) | `RewardsStore` | câmbio entre companhias aéreas que o produto não tem (ver memória "home anuncia parceiros fake"), bônus de +120%/+80%/+60%, contagens regressivas e histórico inventados |
| Início (`RewardsHomeView`) | misto | saldo real (mas em R$), campanhas reais, `RWSparkline` decorativo |
| Comprar / Vender / Transferir (folhas) | real | ressalvas de §3 |
| Extrato, notificações, cartão/nível, campanhas, benefícios/vouchers, perfil, segurança, exclusão | real | ressalvas de §3 |

---

## 5. O que falta no app (com backend pronto)

Em ordem de dependência:

1. Login real com e-mail/CPF + senha, incluindo 2FA: SMS por `/auth/login/2fa` e TOTP com `mfa_code`.
2. Login com Google: `GoogleAuthService` já gera `id_token` + `nonce`.
3. Cadastro com os 3 aceites, celular e data de nascimento.
4. Esqueci a senha. O reset no app depende de Universal Link, ou de abrir o site.
5. Guardar o `refresh_token` e renovar em single-flight. Chamar `/auth/logout` ao sair.
6. Portão de e-mail também em DEBUG, sem `dev/verify-email` contra produção.
7. Parceiros reais (`/partners/`, `/partners/<id>`, `/partners/categories`) com sanitização (§6).
8. Detalhe de benefício (`/benefits/<id>`) e de voucher (`/vouchers/<id>`).
9. Envio com senha digitada (hoje Release lança erro), `Idempotency-Key`, desfazer em 60 s (`/transfer/<id>/cancel`), tratamento de 409 e 429, e step-up `mfa_code`.
10. Resgate por transferência com senha digitada, `Idempotency-Key`, acompanhamento por `GET /redeem/<id>` e sem R$ na tela.
11. Compra por cartão (`/payments/card/*` + Stripe SDK). **Hoje é o único meio de compra vivo em produção, e cobra de verdade.**
12. Histórico de compras (`/pix/my-charges`, `/payments/card/my-charges`).
13. Segurança: sessões (`/user/sessions`), histórico de acesso (`/user/access-log`), celular + 2FA SMS (`/user/phone*`, `/user/2fa/sms/*`), TOTP (`/auth/mfa/*`), sair de todos (`/auth/sessions/revoke-all`).
14. Exclusão de conta correta (`confirm`; conta Google com `google_id_token`). Exportação LGPD (`/auth/account/export`).
15. Badge de notificações (`/notifications/unread-count`). Push registrado **depois** do login (`rebindAfterLogin`).
16. Apple Wallet (`/card/pass/status` + `/card/pass`).
17. Termos: `/auth/terms/current` + `/auth/terms/reaccept` quando a versão mudar.
18. Receber/QR com o Cartão BlaXx, gerado no aparelho.

## 6. Sanitização obrigatória do que vem da produção (regras do dono)

| Campo | Regra no app |
|---|---|
| `wallet.balance_brl_equiv`, `redeem/quote.amount_brl/rate/cents_per_point`, `PixPayout.amount_brl` | não exibir. O ideal é nem decodificar (tirar do DTO). |
| `partner.accrual_rule` | nunca exibir |
| `partner.description` | descartar se casar com `/parceiro\s+livelo|fict[ií]ci|\bpix\b|a\s+cada\s+R\$|pts?\s*\/\s*R\$/i`; no lugar, mostrar a categoria |
| `partner.logo_emoji`, `benefit.image_emoji`, `notification.icon` | nunca como ícone. Usar o ícone da marca (quadrado neon com traço preto) por categoria ou tipo. |
| parceiros e benefícios de seed (os 8 "fictícia" e os 258 "Parceiro Livelo") | em Release, decidir com o dono: esconder, ou mostrar só a rede real quando existir. Hoje **todo** o catálogo de benefícios fica em parceiro fictício. |
| `campaign.mechanic` | não exibir cru (traz "A cada R$…") |
| `tier.perks`, `tier.color`, `tier.text_color` | não usar como vêm ("…e PIX", `#C6FF00` legado) |
| `transaction.description` | montar o rótulo pelo `type`/`reference`. Nunca "Resgate via PIX". |
| mensagens de erro do servidor sobre resgate | trocar "PIX" por "transferência" |
| `notification.body` | filtrar a mesma regex de texto proibido |

## 7. O e-mail do C6

A mensagem colada nesta conversa é o aviso do C6 Bank: a homologação da API foi cancelada por falta do roteiro de testes preenchido, e voltar exige um cadastro novo no portal Developers, com credenciais novas. O que muda no contrato:

- `PIX_PROVIDER=c6` em produção. Sem credencial válida, todo `POST /pix/charge` responde 400 com a mensagem de falha "passageira", e o polling de `GET /pix/charge/<id>` falha em silêncio (`_reconsultar_c6_se_pendente` só registra no log).
- O app não tem como saber que o PIX está fora de vez. `/pix/provider` continua dizendo `c6`. **Sugestão de backend:** expor `available` em `/pix/provider` (ou um `code` como `PIX_PROVIDER_UNAVAILABLE` no 400), para o app esconder a opção PIX e oferecer cartão.
- O resgate por transferência não depende do C6 para sair (o pagamento é manual), mas continua dependendo de KYC e de CPF real.
- Nada foi feito em relação ao e-mail (nenhum cadastro, nenhum contato com o C6). Retomar a homologação é decisão do dono.

## 8. Recomendações para a camada de rede do redesenho

1. Um cliente só, com `httpShouldHandleCookies = false`, Bearer, refresh em single-flight, e erro tipado `{status, error, code, issues, msg, extras}`.
2. Um `enum` de resultado de login: `.ok(tokens,user)`, `.mfaSMS(challenge, hint)`, `.mfaTOTP`, `.locked(until)`, `.rateLimited`.
3. Um `Idempotency-Key` por intenção em envio, resgate, resgate de benefício e cartão.
4. DTOs sem `balance_brl_equiv`, `accrual_rule`, `logo_emoji` e `image_emoji` (ou marcados como "não exibir"), e um sanitizador de texto central.
5. Em DEBUG, apontar para um backend local ou de homologação, e não para produção com conta demo. Em Release, nada de mock: estados vazios honestos quando não houver dados.
6. Pedir ao backend, em ordem de impacto:
   - sinal de disponibilidade do PIX;
   - `PATCH` de perfil (nome, chave, CPF de conta Google);
   - `phone_verified` e `mfa_method` no `/auth/me`;
   - paginação do extrato;
   - efetivação de envios por cron (hoje é preguiçosa);
   - indicação de verdade, ou a retirada da campanha "Família engajada";
   - JSON nos 404 e 429.
