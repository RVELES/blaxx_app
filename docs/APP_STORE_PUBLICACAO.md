# Publicação do BlaXx Pontos na App Store (iOS)

Preparado em 23/10/2026 sobre a branch `redesenho-embarque-ios` (app "Embarque", raiz `BXRaiz`).
Empresa: BLAXX REWARDS LTDA · CNPJ 68.260.588/0001-56 · suporte: suporte@blaxxpontos.com.br /
WhatsApp (11) 92470-6095 · site https://blaxxpontos.com.br · backend https://blaxx-pontos-exe.onrender.com

---

## 1. O que já foi corrigido no código

| # | Item | Onde | Situação |
|---|------|------|----------|
| 1 | Ícone 1024×1024 **sem canal alfa** (o anterior era RGBA → erro ITMS-90717 no envio), verde oficial `#59FD27` sobre preto oficial `#0A0B0E`; variantes escura e "tinted" refeitas também sem alfa | `Assets.xcassets/AppIcon.appiconset/ios-marketing-1024*.png` | feito |
| 2 | `ITSAppUsesNonExemptEncryption = NO` (só HTTPS do sistema e hash do CryptoKit) — a pergunta de exportação não aparece a cada envio | `Info.plist` | feito |
| 3 | Textos de permissão em pt-BR e específicos: câmera (QR do Cartão BlaXx), Face ID (o código antigo `BiometricGate` ainda é compilado; a tela nova não pede Face ID — D11 desligado) e **Fotos – só gravação** (o "Salvar imagem" do compartilhar comprovante derrubava o app sem essa chave) | `Info.plist` | feito |
| 4 | Idioma principal do app = Português (Brasil) (`developmentRegion = pt-BR`, `CFBundleDevelopmentRegion`, `CFBundleLocalizations`) | `project.pbxproj`, `Info.plist` | feito |
| 5 | iPhone: **só retrato** (o layout é de celular em pé); app **só para iPhone** no iOS (`TARGETED_DEVICE_FAMILY[sdk=iphone*] = 1`) — evita exigir telas de iPad e revisão em iPad. Para voltar a ter iPad: apagar essa linha e testar o layout no iPad | `project.pbxproj` | feito |
| 6 | Entitlements separados para iOS (`BlaxxPontos-iOS.entitlements`) com `aps-environment` (push, D12). As chaves de sandbox do macOS não vão mais para o build iOS | `project.pbxproj`, `BlaxxPontos-iOS.entitlements` | feito |
| 7 | Manifesto de privacidade completado: além de e-mail, nome, telefone, ID de usuário, CPF e chave, agora declara **histórico de compras** e **ID do aparelho** (token de push). APIs de motivo obrigatório: UserDefaults (CA92.1) e data de arquivo (C617.1). Sem rastreamento | `PrivacyInfo.xcprivacy` | feito |
| 8 | Endpoint de desenvolvimento `/auth/dev/verify-email` só existe em DEBUG (o código antigo de `API.swift` ainda o compilava no Release) | `API.swift` | feito |
| 9 | URL de produção fixa em Release (`BXAmbiente.urlBase`); troca de servidor e modo demonstração (`-BXDemo`, galeria, teste do núcleo, "Simular pagamento") só em DEBUG | já estava correto, conferido |
| 10 | ATS: sem `NSAllowsArbitraryLoads`. Só `NSAllowsLocalNetworking` (aceito pela Apple, usado no desenvolvimento local) | `Info.plist` | conferido |
| 11 | Exclusão de conta dentro do app (regra 5.1.1(v)): Menu → Perfil → Privacidade e dados → **Excluir minha conta** → `DELETE /auth/account` (existe no backend, `app/api/auth.py`). Conta só-Google reautentica no Google | `BXExcluirContaSheet.swift` | já existia, conferido |
| 12 | Links de Termos, Privacidade, Regulamento e Contato abrem no app (SFSafariViewController) e respondem 200 no site; chamado de suporte por e-mail | `BXNavegacao.abrirSite` | conferido |
| 13 | Aviso "Carteira do iPhone · em breve" escondido em Release (função anunciada que não existe = regra 2.1/2.3) | `BXCartaoBlaxxTela.swift` | feito |
| 14 | Bandeiras de App Store em `BXRecursos` (seção 2) | `Rewards/Embarque/Nucleo/BXAmbiente.swift` | feito |

Build: `xcodebuild -configuration Release` para **generic iOS** e **iOS Simulator** — BUILD SUCCEEDED (Xcode 27.1, SDK iOS 27.1).

---

## 2. Bandeiras de App Store (uma linha cada, em `BXAmbiente.swift`)

Em DEBUG tudo continua ligado (para testar). Em Release valem os valores abaixo.

| Bandeira | Release | Por quê | Para religar |
|----------|---------|---------|--------------|
| `compraNoAppRelease` | `false` | (1) o PIX de produção está fora do ar (C6 cancelou a homologação, D01): o revisor encontraria uma compra que sempre falha → recusa 2.1; (2) venda de pontos fora do In-App Purchase é risco 3.1.1 (seção 3). Some: aba Comprar, botões "+ Comprar pontos", pacotes da boas-vindas, itens da gaveta, tema e perguntas de compra da Ajuda/FAQ; textos reescritos sem mandar comprar fora do app | `compraNoAppRelease = true` |
| `loginApple` / `loginGoogle` | Google **escondido** | Regra 4.8: com Google é obrigatório oferecer login equivalente (Sign in with Apple). O backend não tem `POST /auth/apple`. Quem criou conta pelo Google entra com "Esqueci a senha" (o backend define a primeira senha) | implementar a seção 4.2 e `loginApple = true` |
| `parceirosSemContratoRelease` | `false` | ~258 marcas reais (Booking.com, C&A, Bradesco, AliExpress…) vêm de `GET /partners/` como "Parceiro Livelo · …", sem contrato nem integração (D05). Mostrá-las como "parceiros" é risco de recusa (5.2.1 marcas de terceiros, 2.3.1 informação enganosa) e risco jurídico | `true` depois de ter contrato com as marcas listadas |
| `sorteiosRelease` | `false` | "Sorteio R$ 1.000": a regra 5.3 exige regulamento oficial no app e aviso de que a Apple não patrocina; no Brasil sorteio promocional precisa de autorização (Lei 5.768/71) | `true` com regulamento + autorização |

---

## 3. Recomendação sobre a regra 3.1.1 (compra de pontos)

**O que o app faz:** vende pontos (pacotes e valor livre) por PIX (e cartão, desligado — D02). Os pontos são
"créditos promocionais de uso restrito" (regulamento): servem para resgatar benefícios, enviar a outras contas
e participar de campanhas; vencem em 24 meses; o site ainda tem resgate em dinheiro (D03, fora do app).

**Leitura das regras:**
- 3.1.1 exige In-App Purchase para conteúdo digital, "moedas" e créditos usados dentro do app.
- 3.1.3(e)/3.1.5(a) permitem pagamento por fora quando o que se compra são bens ou serviços **consumidos fora
  do app** (é o argumento usado por programas de milhas/pontos que trocam por passagens e produtos).
- Hoje, em Release, o catálogo real tem só "Doação Instituto BlaXx" (e o sorteio). Não há rede de parceiros
  com contrato. Sem resgate em bens/serviços reais, a tese da 3.1.3(e) não se sustenta.
- In-App Purchase também **não serve** ao modelo atual: crédito comprado por IAP não pode vencer (3.1.1) e não
  pode virar dinheiro; os pontos vencem em 24 meses e o site permite resgate em dinheiro.

**Recomendação:** publicar a primeira versão **sem compra dentro do app** (já implementado, reversível com
`compraNoAppRelease`). Não colocar no app texto ou botão do tipo "compre no site" (anti-steering), a menos que a
Apple libere para a loja brasileira.

**Caminhos depois:**
1. Ter parceiros reais (bens/serviços consumidos fora do app) e o PIX de produção funcionando → religar a compra
   e explicar nas notas de revisão que os pontos são trocados por bens e serviços físicos de parceiros (3.1.3(e)).
2. Conferir em developer.apple.com o estado atual das regras para o **Brasil** (acordo da Apple com o CADE sobre
   links e pagamentos externos). Se existir o entitlement de link externo para a loja brasileira, um botão
   "Comprar no site" passa a ser permitido nas condições (e comissão) da Apple. Não ativar sem confirmar.
3. Só considerar IAP se o regulamento mudar (pontos comprados sem validade e sem resgate em dinheiro).

---

## 4. Bloqueadores e decisões que dependem do dono

1. **Conta de revisão (obrigatória):** criar no banco de produção uma conta só para a Apple, com e-mail
   verificado, **sem 2FA**, com saldo para testar envio/resgate. Informar usuário e senha **só** no campo
   "Sign-in information" do App Store Connect (nunca no repositório). Desativar a conta demo antiga cujas
   credenciais estão em `Rewards/RewardsBackend.swift` (D15) e trocar a senha.
2. **Sign in with Apple (se quiser o Google no iOS):** backend precisa de `POST /auth/apple`
   (recebe `identity_token`, `authorization_code`, `nonce`, nome no primeiro login; valida o JWT com as chaves
   públicas da Apple, `aud` = bundle id; cria/vincula conta como o `/auth/google`; aceitar e-mail
   privaterelay). Exclusão de conta Apple precisa revogar o token (`/auth/revoke` da Apple). No app: botão
   `SignInWithAppleButton`, entitlement `com.apple.developer.applesignin`, `loginApple = true`.
3. **Catálogo de resgates em Release:** sobra apenas "Doação Instituto BlaXx". Confirmar se o Instituto existe
   como entidade sem fins lucrativos (se não, a doação também é dado fictício e deve sair). Um catálogo vazio pode
   gerar recusa por funcionalidade mínima (4.2) — ideal ter ao menos alguns benefícios reais antes do envio.
4. **Push:** cadastrar a chave APNs (.p8) no backend (`APNS_*`) e ligar Push Notifications no App ID (a
   assinatura automática do Xcode faz isso no primeiro Archive).
5. **suporte@blaxxpontos.com.br** precisa receber e-mails (é o canal de chamado do app).
6. **Alvo mínimo iOS 26.5:** só aparelhos atualizados instalam. Baixar o alvo amplia o público, mas exige testar.
7. **Bundle ID atual** `Blaxx-Pontos-Inc.BlaxxPontos` (time `UW4MAAC995`). Se a conta da empresa usar outro
   time/Bundle ID (ex.: `br.com.blaxxpontos.app`), criar também um **novo Client ID iOS do Google** para o novo
   bundle e atualizar `GoogleAuthService.defaultClientID` e o URL scheme no `Info.plist`.

---

## 5. Passos que só você pode fazer

### 5.1 Apple Developer Program como empresa

**Dados oficiais da empresa** (Receita Federal, conferidos em 24/10/2026). Use exatamente
estes na D&B e na Apple: diferença de grafia entre o D-U-N-S e a inscrição trava a aprovação.

| Campo | Valor |
|---|---|
| Razão social (Legal Entity Name) | BLAXX REWARDS LTDA |
| Nome fantasia | Blaxx Pontos |
| CNPJ | 68.260.588/0001-56 (matriz, situação ativa) |
| D-U-N-S | 320887228 |
| Abertura | 28/07/2026 |
| Natureza jurídica | Sociedade Empresária Limitada · Microempresa · Simples Nacional |
| Endereço | Avenida Marquês de São Vicente, 405, Conj. 1804, Várzea da Barra Funda, São Paulo/SP, CEP 01139-001 |
| Telefone | +55 11 92470-6095 |
| E-mail / site | rveles@blaxxpontos.com.br · https://blaxxpontos.com.br |
| CNAE principal | 63.11-9-00 (tratamento de dados, provedores de aplicação e hospedagem) |

Na Receita o logradouro aparece abreviado ("Avenida Marq de Sao Vicente"). Se a D&B
devolver o cadastro com essa grafia, use a mesma na Apple.

O nome que aparece na loja como vendedor é a razão social (**BLAXX REWARDS LTDA**).
Empresa aberta há menos de 3 meses costuma não ter D-U-N-S ainda: peça um novo na D&B
(gratuito, prazo de até ~5 dias úteis, às vezes 14).

1. Obter o **D-U-N-S** da BLAXX REWARDS LTDA (gratuito pela Dun & Bradstreet; consulta em
   developer.apple.com/enroll/duns-lookup). Pode levar alguns dias.
2. Ter domínio e e-mail da empresa (ex.: rveles@blaxxpontos.com.br) e site público (blaxxpontos.com.br).
3. Inscrever-se em developer.apple.com/programs/enroll como **Organization**, com Apple ID de e-mail da empresa,
   autoridade legal para assinar pela empresa, D-U-N-S, CNPJ e endereço (Av. Marquês de São Vicente 405 cj 1804).
   Anuidade de US$ 99. A Apple pode ligar para confirmar.
4. Em App Store Connect → Business: aceitar o **Paid Apps Agreement** só se um dia houver IAP (para app gratuito
   basta o Free Apps Agreement padrão); preencher dados fiscais e bancários quando necessário.

### 5.2 Certificados, identificadores e assinatura
1. No Xcode (Settings → Accounts) entrar com o Apple ID da empresa.
2. Target BlaxxPontos → Signing & Capabilities: selecionar o **Team** da empresa, manter
   "Automatically manage signing". Conferir o Bundle Identifier (seção 4, item 7).
3. Capabilities: **Push Notifications** (já está no entitlement). Sign in with Apple só quando a seção 4.2 existir.

### 5.3 Registro do app no App Store Connect
- Novo app → Plataforma **iOS** · Nome **BlaXx Pontos** · Idioma principal **Português (Brasil)** ·
  Bundle ID do passo 5.2 · SKU `blaxx-pontos-ios`.
- Categoria primária: **Finanças** (ou Estilo de vida). Preço: **Gratuito**.
- Disponibilidade: Brasil. Em "Disponibilidade em Mac e Apple Vision Pro", **desmarcar** (o app é de iPhone e não
  foi testado nesses aparelhos).
- URLs: Política de privacidade `https://blaxxpontos.com.br/privacidade.html` · Suporte
  `https://blaxxpontos.com.br/contato.html` · Marketing `https://blaxxpontos.com.br`.
- Copyright: `2026 BLAXX REWARDS LTDA`.

### 5.4 Capturas de tela
- Obrigatório: **iPhone 6,9"** — 1320 × 2868 px (ou 1290 × 2796), retrato, de 1 a 10 imagens.
  Com o simulador "iPhone 17 Pro Max": `xcrun simctl io booted screenshot tela.png`.
- iPad: não precisa (app só iPhone).
- Mostrar só o que existe no build de Release: boas-vindas, entrar, início com saldo, carteira, enviar,
  receber (QR), resgates, perfil/segurança. **Não** mostrar compra de pontos, marcas de terceiros nem sorteio.

### 5.5 Questionário "Privacidade do app" (App Store Connect)
Rastreamento: **Não**. Todos os itens abaixo: vinculados à identidade, finalidade **Funcionalidade do app**,
sem rastreamento.
- Informações de contato: Nome, E-mail, Telefone, Outras informações de contato (chave PIX).
- Identificadores: ID do usuário, ID do aparelho (token de push).
- Informações financeiras: Outras informações financeiras (CPF / dados de pagamento do PIX quando houver).
- Compras: Histórico de compras.
- Não coletados: localização, contatos, fotos (o app só **grava** o comprovante quando você pede), dados de
  saúde, diagnóstico/analytics, conteúdo do usuário, histórico de navegação.

### 5.6 Classificação etária
Responder "Nenhum" para violência, conteúdo sexual, linguagem, drogas, terror etc.; **Jogos de azar/concursos:
Nenhum** (sorteio escondido em Release); sem conteúdo gerado por usuário nem navegador aberto.
Resultado esperado: **4+**. Se o sorteio for religado, revisar (concursos/sorteios).

### 5.7 Notas para a revisão (modelo)
> A BlaXx é um programa de pontos promocionais (créditos de uso restrito, sem valor monetário). Nesta versão
> para iOS não há venda de pontos nem qualquer compra dentro do app. Conta de teste: (preencher no campo
> Sign-in). Ela já tem pontos para testar: Menu → Enviar pontos (para outra conta BlaXx) e Resgates.
> Exclusão de conta: Menu → Perfil → Privacidade e dados → Excluir minha conta.
> Suporte: suporte@blaxxpontos.com.br · WhatsApp (11) 92470-6095.

### 5.8 Gerar e enviar o build
1. Em cada envio, aumentar o **Build** (`CURRENT_PROJECT_VERSION`, hoje 1). Versão (`MARKETING_VERSION`) = 1.0.
2. Xcode → esquema BlaxxPontos → destino **Any iOS Device (arm64)** → Product → **Archive**.
3. Organizer → **Distribute App** → App Store Connect → Upload (ou exportar e enviar pelo **Transporter**).
4. Esperar o processamento (e-mail da Apple), testar pelo **TestFlight** num iPhone real (login, envio, QR,
   push, exclusão de conta com uma conta descartável).
5. App Store Connect → versão 1.0 → escolher o build → preencher descrição, palavras-chave, capturas, notas
   de revisão → **Enviar para revisão**.

### 5.9 Texto sugerido (descrição)
> BlaXx Pontos é o seu cartão de pontos. Veja o saldo e o extrato, envie pontos para outras contas BlaXx pelo
> e-mail, CPF ou QR Code do Cartão BlaXx, receba pontos e troque por benefícios. Conta gratuita e sem
> mensalidade, com verificação em duas etapas e exclusão de conta pelo app.

(Não citar marcas de terceiros, compra de pontos, sorteio nem "em breve".)
