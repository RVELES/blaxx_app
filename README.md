# Blaxx Pontos · App nativo macOS (Xcode)

App SwiftUI nativo para macOS, com backend Flask local e cache em SwiftData.
Implementa o fluxograma completo do Blaxx Pontos com o design system oficial
do PDF: paleta preto absoluto / verde neon `#59FD27` / cinzas, tipografia
Playfair Display + SF Pro.

> ✅ **Verde de marca oficial é o neon `#59FD27`** (adotado 27/06/2026).
> `Theme.swift` e este README já usam o neon oficial; o lime `#7CFF00` é legado.

## Como rodar

O app é universal — compila para **macOS** (sidebar lateral) e **iOS**
(iPhone com TabView na base, adaptado para iPhone 17 Pro Max).

### 1. Subir o backend Flask

Em um Terminal:

```sh
cd "/Users/ricardoveles/Library/CloudStorage/Dropbox/Blaxx Pontos/blaxx_app"

# (uma vez) instala dependências Python
python3 -m pip install -r backend/requirements.txt --break-system-packages

# (uma vez) cria usuários demo
cd backend && python3 seed.py && cd ..

# sobe o backend em 127.0.0.1:5050
cd backend && python3 run.py
```

Deixe esse Terminal aberto enquanto usa o app.

### 2a. Rodar no Mac (macOS)

```sh
open "/Users/ricardoveles/Library/CloudStorage/Dropbox/Blaxx Pontos/blaxx_app/BlaxxPontos/BlaxxPontos.xcodeproj"
```

1. Selecione o esquema **BlaxxPontos** + destino **My Mac**
2. **Cmd+R** para rodar
3. Login: `mariana@blaxx.com` / `123456`

### 2b. Rodar no iPhone Simulator (iPhone 17 Pro Max)

Mesmo projeto, destino diferente:

1. No Xcode, no menu superior próximo do botão Run, escolha o destino
   **iPhone 17 Pro Max** (em "iOS Simulators")
2. **Cmd+R** — o Simulator abre com o app
3. O Simulator roda no Mac, então `127.0.0.1:5050` resolve para o backend
   Flask local automaticamente. Sem configuração extra.
4. Login: `mariana@blaxx.com` / `123456`

### 2c. Rodar em iPhone físico

`127.0.0.1` no iPhone significa o próprio iPhone, então é preciso
apontar para o IP do Mac na Wi-Fi. Descubra o IP:

```sh
ipconfig getifaddr en0    # algo como 192.168.1.42
```

E rode o backend escutando em todos os IPs:

```sh
BLAXX_BACKEND_HOST=0.0.0.0 python3 run.py
```

No app, antes do login, abra o **Console do Xcode** e execute:

```swift
UserDefaults.standard.set("http://192.168.1.42:5050", forKey: "blaxx_backend_url")
```

(troque pelo IP do seu Mac). Depois reabra o app e o login funciona.

Como o backend usa HTTP (não HTTPS), o `NSAllowsLocalNetworking` no
Info.plist já libera a conexão para redes locais (Wi-Fi privada).

## Layouts adaptativos

O mesmo código alimenta as duas plataformas via `horizontalSizeClass`:

- **macOS / iPad regular**: sidebar lateral preta, layout horizontal de
  duas colunas, BalanceCard amplo
- **iPhone (compact)**: TabView na base (Início · Comprar · Enviar ·
  Resgatar · Mais), layout vertical, navegação com NavigationStack,
  formulários ocupando largura inteira

A barra inferior do iPhone vem em preto absoluto com itens em cinza
e o item ativo em verde-limão — consistente com a identidade visual
da sidebar do Mac.

## Arquitetura

```
BlaxxPontos/
├── BlaxxPontos.xcodeproj/         ← projeto Xcode (synced folder, auto-inclui .swift)
└── BlaxxPontos/
    ├── BlaxxPontosApp.swift       ← @main + SwiftData ModelContainer
    ├── ContentView.swift          ← roteia entre login e shell autenticada
    ├── Theme.swift                ← paleta + fontes + ButtonStyles
    ├── API.swift                  ← cliente HTTP para o Flask em 127.0.0.1:5050
    ├── Session.swift              ← estado de autenticação (@Observable)
    ├── Item.swift                 ← modelos SwiftData (CachedWallet, CachedTransaction)
    ├── Components.swift           ← BalanceCard, MetricCard, ActionTile, Chip, Field
    ├── Sidebar.swift              ← navegação lateral preta
    ├── LoginView.swift            ← tela de login
    ├── DashboardView.swift        ← Início (saldo + atalhos + extrato recente)
    ├── WalletView.swift           ← Carteira detalhada
    ├── BuyView.swift              ← FLUXO 1: comprar pontos via PIX
    ├── SendView.swift             ← FLUXO 2: enviar pontos P2P
    ├── RedeemView.swift           ← FLUXO 3: resgatar via PIX
    ├── SecondaryViews.swift       ← Extrato, Parceiros, Perfil
    ├── Utils.swift                ← helpers cross-platform (clipboard)
    ├── Info.plist                 ← NSAllowsLocalNetworking para HTTP em localhost
    ├── BlaxxPontos.entitlements   ← network.client habilitado
    └── Assets.xcassets/
```

## Os três fluxos do fluxograma

**Compra de pontos via PIX** (`BuyView`):

1. Lista 4 pacotes do backend (`GET /pix/packages`)
2. Clica num pacote → `POST /pix/charge` gera BR Code + txid
3. Exibe QR Code (placeholder) e copia-e-cola
4. Botão "Simular pagamento" → `POST /pix/simulate-payment` credita os pontos
5. Tela de sucesso

**Envio P2P** (`SendView`):

1. Formulário com destinatário, valor, mensagem opcional
2. Validação local (mín 100 / máx 50.000 pts)
3. Tela de confirmação + senha
4. `POST /transfer/` faz a transferência atômica
5. Comprovante com `receipt_code` (ENV-2026-XXXX-XXXX)
6. Em caso de saldo insuficiente, cai numa tela específica

**Resgate via PIX** (`RedeemView`):

1. Quantos pontos resgatar (mín 2.500 / máx 100.000)
2. Cotação ao vivo via `GET /redeem/quote` enquanto digita
3. Tela de chave PIX + senha
4. `POST /redeem/` solicita o payout
5. Chaves começando com `fail-` simulam falha do gateway e disparam
   estorno automático (Transaction REFUND) — testado direto na UI

## Cache offline (SwiftData)

A carteira do usuário é cacheada em `CachedWallet` no SwiftData. Quando o app
abre offline, o último saldo conhecido aparece imediatamente; quando o backend
fica acessível, sincroniza em background.

## Design system

Cores extraídas da seção 11.2 do PDF de projeto e definidas em `Theme.swift`:

| Token              | Hex      |
| ------------------ | -------- |
| Preto absoluto     | `#0A0A0A`|
| Preto suavizado    | `#1A1A1A`|
| Verde neon Blaxx   | `#59FD27`|
| Verde-limão escuro | `#5AB800`|
| Verde-limão claro  | `#F0FAD9`|
| Cinza 50–800       | …        |

Tipografia: **Playfair Display** (display, se instalada) com fallback para
o `serif` do sistema (New York no macOS), e **SF Pro** (system default) para
corpo. Para forçar Playfair sempre, baixe os `.otf` em
[fonts.google.com/specimen/Playfair+Display](https://fonts.google.com/specimen/Playfair+Display)
e adicione no projeto Xcode com **UIAppFonts** no Info.plist.

## Substituição do Electron

Esta versão Swift substitui o app Electron antigo. Os arquivos do Electron
ainda estão na pasta pai (`blaxx_app/`) por causa de bloqueio de sync do
Dropbox — você pode apagá-los manualmente no Finder com segurança:

```
blaxx_app/main.js
blaxx_app/preload.js
blaxx_app/package.json
blaxx_app/.gitignore
blaxx_app/renderer/
blaxx_app/node_modules/
```

O backend Flask em `blaxx_app/backend/` **permanece** — é o mesmo backend
usado pelo app Swift.

## Em produção

Veja a planilha `Blaxx_Pontos_Backlog_Tarefas.xlsx` (raiz do projeto Blaxx
Pontos) — 20 épicos, 143 sub-tarefas, ~215 dias-pessoa, distribuídos em P0/P1/P2.

Itens mínimos antes de subir para usuários reais:

- Substituir `MockPixProvider` por gateway real (Mercado Pago / Efí / Stark Bank)
- JWT em vez de Bearer = user_id no backend
- Validação HMAC dos webhooks PIX + IP whitelist
- Migrar SQLite → PostgreSQL com Alembic
- Embarcar a fonte Playfair Display no app
- Code signing + notarization da Apple antes de distribuir
- Ícone do app (atualmente AccentColor padrão)

## Troubleshooting

**"Could not connect to backend"** — o backend Flask precisa estar rodando.
Volte ao Terminal e execute `python3 run.py` dentro de `backend/`.

**Build falha com erro "ENABLE_USER_SELECTED_FILES"** — entitlements esperam
`readonly`. Já está configurado, mas se editar e remover, recoloque no
projeto: **Signing & Capabilities → App Sandbox → User Selected File ▸ Read Only**.

**App mostra a tela mas não carrega o saldo** — abra o Console
(`Cmd+Shift+C` no Xcode) e veja se aparecem mensagens "Could not connect" ou
"Connection refused". Significa que o backend não está rodando.
