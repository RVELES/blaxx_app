# 04 · Especificação do redesenho "Embarque" do app iOS

Data: 22/10/2026 · Base: `01-inventario-ios.md`, `02-inventario-web-mobile.md`, `03-contrato-api.md`,
fotos em `fotos-web/` e `fotos-ios-antes/`, código de `blaxx_app/BlaxxPontos` (HEAD `0d73534`) e do backend.

Pedido: "Monte o APP IOS com o mesmo design e funcionalidades do Web Mobile, incremente o design do APP IOS".
Este documento é o que os implementadores seguem. Onde ele e um inventário divergirem, vale este documento.

Abreviações de caminho (sempre absolutos no disco):

- `APP/` = `/Users/ricardoveles/Library/CloudStorage/Dropbox/Blaxx Pontos/blaxx_app/BlaxxPontos/BlaxxPontos/`
- `R/` = `APP/Rewards/`
- `DOCS/` = `/Users/ricardoveles/Library/CloudStorage/Dropbox/Blaxx Pontos/blaxx_app/BlaxxPontos/docs/redesenho/`
- `WEB/` = `/Users/ricardoveles/Library/CloudStorage/Dropbox/Blaxx Pontos/blaxx/`
- `SCRATCH/` = `/private/tmp/claude-501/-Users-ricardoveles-Library-CloudStorage-Dropbox-Blaxx-Pontos/f9884c78-fe31-47e5-ab03-250a8ffa497c/scratchpad/`

---

## 0. Leia antes de tudo

### 0.1 Regras do dono (todas as telas, todos os grupos)

| Regra | Como o código garante |
|---|---|
| Nunca mostrar valor do ponto: nada de "pts/R$", "1 pt = R$", "a cada R$", "≈ R$", saldo em R$, `accrual_rule`, cotação de resgate | Os DTOs novos (§1.7.4) **não decodificam** `balance_brl_equiv`, `accrual_rule`, `amount_brl`/`rate`/`cents_per_point` da cotação, `target_brl`/`progress_brl` de campanha. Valor livre não mostra prévia de pontos calculada no cliente. Preço em R$ só aparece como **tarifa do pacote** e **valor da cobrança** que o cliente vai pagar. |
| PIX só como meio de **pagamento** na compra (QR Code). Resgate nunca é "PIX" | A palavra "PIX" só pode aparecer em arquivos de `R/Telas/Movimentar/` ligados à compra. Mensagens do servidor passam por `BXSanitizador.mensagemServidor(_:contexto:)`. |
| Vocabulário: "benefícios em parceiros selecionados", "cartão ou transferência", "rede em expansão" | Textos de tela escritos com esse vocabulário; nada de "câmbio", "milhas", "trocar entre programas". |
| Nada de parceiros, campanhas ou saldos inventados em Release; nada de "Parceiro Livelo"/"fictícia" visível | Sem mundo mock. Dados de exemplo só em `#if DEBUG` com `-BXDemo` (§4). Sanitizador descarta descrições proibidas e esconde parceiros fictícios e seus benefícios em **todas** as builds. Quando a API falha, aparece estado de erro, nunca número de demonstração. |
| Ícones: quadrado neon `#59FD27` com desenho preto de traço. Nada de emoji como ícone ou logo | Um único componente `BXIcone` (§1.4). `logo_emoji`, `image_emoji` e `notification.icon` nunca são decodificados. |
| Neon nunca como cor de **texto** sobre fundo claro | Texto neon só via `.bxTextoNeon()` (§1.6.12), que só deve ser usado dentro de superfície `BXCor.tinta`. Botão desabilitado nunca deixa texto neon sobre cinza. |
| Marca: wordmark "BlaXx" | `BXWordmark` desenhado a partir dos SVG do web (§1.5). Nunca montar "Bla" + "Xx" com `Text`. |
| Segurança: não digitar senha, não criar conta, não fazer POST/PUT/DELETE em produção, não rodar git commit/push, não apagar arquivo que você não criou | Todo teste visual roda em `-BXDemo` (transporte falso, zero rede). Arquivos antigos são **desativados** com `#if BX_LEGADO_REWARDS`, nunca apagados (§5.6). |

### 0.2 Regras de engenharia

1. **Ninguém edita `BlaxxPontos.xcodeproj/project.pbxproj`.** As pastas são sincronizadas: arquivo `.swift` novo dentro de `APP/` entra no target sozinho.
2. **Código novo não referencia nada do mundo antigo**: `RW*`, `Rewards*`, `RewardsBackend`, `RewardsStore`, `BlaxxAPI`, `Session`, `TokenStore`, `WalletCache`, `BlaxxColor`, `BlaxxFont`, `Eyebrow`, `Color(hex:)`, `Color(blaxxHex:)`. Exceções nomeadas: `BXSessao.sair()` (G0) chama `TokenStore.clear()`, `TokenStore.clearProfile()` e `WalletCache.clear()` para limpar restos da versão antiga; `PushService` (G1) passa a usar `BXAPI`. Isso permite desativar o mundo antigo de uma vez (§5.6) sem quebrar nada.
3. **Isolamento padrão é MainActor** (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_VERSION = 5.0`). DTOs, parser de SVG, sanitizador e formatadores são `nonisolated` e `Sendable`; o cliente HTTP é um `actor`. Isso evita repetir os 27 avisos de `API.swift`.
4. **Só iOS.** O target também lista macOS e visionOS. Código com UIKit, PassKit, VisionKit, SafariServices fica sob `#if os(iOS)`. `ContentView` mostra `BXRaiz()` em iOS e mantém `legacyBody` nas outras plataformas.
5. **Zero aviso novo** nos arquivos de cada grupo. Sem `Text + Text` (deprecado no iOS 26): usar `Text("\(a)\(b)")` com `AttributedString` ou `HStack`.
6. Textos em pt-BR, números com separador de milhar pt-BR (`32.480`), datas pt-BR. Sem emoji em nenhum texto (nem "✓", "→" pode, é seta tipográfica usada pelo web).
7. Cada grupo usa o próprio derivedData: `SCRATCH/dd-<grupo>` (ex.: `dd-g3`). Nunca derivedData dentro do Dropbox.
8. Layout em retrato primeiro; em paisagem, iPad e visionOS o conteúdo fica numa coluna central de no máximo 560 pt (`.frame(maxWidth: 560)` centralizado). Nenhum overflow horizontal.

### 0.3 Fatos novos que mudam o plano (conferidos hoje)

1. **A única mensagem do usuário nesta tarefa é o e-mail do C6 Bank** cancelando a homologação da API (falta do roteiro de testes; exige novo cadastro no portal Developers). Nada foi feito sobre ele. Efeito no app: `POST /pix/charge` em produção responde 400 permanente (03 §0.1). A compra por PIX vai mostrar estado de "pagamento indisponível" até o dono decidir (D01).
2. **As fontes do web já estão no disco**, ao contrário do que diz o pedido: `APP/Resources/Fonts/Archivo-Variable.ttf` (família "Archivo", eixos `wght` 100–900 e `wdth` 62–125), `SpaceMono-Regular.ttf` e `SpaceMono-Bold.ttf` (PostScript `SpaceMono-Regular`/`SpaceMono-Bold`), com as licenças OFL, criados hoje às 16:23 e **ainda não versionados**. `APP/Info.plist` já foi alterado (não commitado) para registrá-las em `UIAppFonts`. Seguindo o pedido, `BXFonte` nasce em modo **sistema**, com um único ponto de troca (§1.3). A troca para `.embarcada` é uma linha, depois que o dono confirmar a família oficial (D16).
3. **`pending_pts` não é para subtrair do saldo.** No backend o envio sai de `balance_pts` e entra em `pending_pts` (`services/transfer.py:331-344`). O web calcula "Disponíveis = saldo − pendentes" e subtrai duas vezes. No app: **Saldo = `balance_pts`**; **Em processamento = `pending_pts`** (envios ainda na janela de 60 s).
4. **Barra de status**: o build setting é `UIStatusBarStyleDefault`. Em vez de mexer no projeto, toda tela fica dentro de um `NavigationStack` com barra preta visível e `.toolbarColorScheme(.dark, for: .navigationBar)`, o que deixa os ícones da barra de status claros. Corrige as fotos 01 e 04 do "antes".
5. **Os SVG do wordmark são só `<path>` com coordenadas absolutas** (`blaxx-wordmark-barra.svg`, `-barra-claro.svg`, `blaxx-logo-completo-justo.svg`, sem `transform`). O mesmo parser de SVG dos ícones desenha a marca. Não é preciso tocar no `Assets.xcassets`.
6. `AccentColor` do catálogo é o lima legado `#C6F432`. Em vez de mexer no asset, a raiz aplica `.tint(BXCor.tinta)` (G1). Neon como tint deixaria texto de sistema neon sobre claro.

---

## 1. Fundação · G0 (roda antes, sozinho)

### 1.0 Escopo e arquivos

O G0 entrega três coisas, todas antes dos grupos de tela começarem:

- **1.A Design system "Embarque" nativo**: `R/Embarque/DS/`.
- **1.B Núcleo** (rede, sessão, erros, modelos sanitizados, navegação, recursos, conectividade): `R/Embarque/Nucleo/`.
- **1.C Modo demonstração** (só DEBUG, §4) e **esqueletos** dos pontos de entrada de cada grupo (§1.8): `R/Embarque/Demo/` e quatro arquivos-esqueleto.

Motivo de o núcleo ficar na fundação: sem um cliente HTTP, uma sessão e um enum de destinos únicos, os grupos G1–G5 teriam de editar arquivos em comum. Com eles prontos antes, os donos de arquivo ficam disjuntos e cada grupo compila sozinho.

Arquivos do G0 (todos novos):

```
R/Embarque/DS/BXCor.swift              tokens de cor + Color(bxHex:)
R/Embarque/DS/BXMedidas.swift          BXRaio, BXEspaco, BXSombra, BXMovimento, BXToque
R/Embarque/DS/BXFonte.swift            tipografia + ponto único de troca de família
R/Embarque/DS/BXSVG.swift              parser de SVG (path/rect/circle/ellipse, arcos) → Path
R/Embarque/DS/BXIconesDados.swift      os 51 desenhos de icones.json + 6 extras
R/Embarque/DS/BXIcone.swift            BXIcone (quadrado/círculo neon), BXGlifo, BXSino, BXAvatar
R/Embarque/DS/BXMarca.swift            BXWordmark (barra, claro, logo completo) + dados dos paths
R/Embarque/DS/BXFormas.swift           BXPicote, BXSerrilha, BXCodigoBarras, BXTracejado
R/Embarque/DS/BXCartaoEmbarque.swift   BXCartaoEmbarque, BXTituloCapa, BXLetreiro, BXGradeDados, BXDado
R/Embarque/DS/BXBilhete.swift          BXBilhete, BXBilhetePacote, BXBilheteCampanha
R/Embarque/DS/BXRecibo.swift           BXRecibo e linhas
R/Embarque/DS/BXRotaEscalas.swift      BXRotaEscalas, BXEscala
R/Embarque/DS/BXPainel.swift           BXPainel, BXNumeroDestaque, BXQuadroPreto
R/Embarque/DS/BXRotulos.swift          BXRotulo, BXChip, BXStatus, BXPilula, BXAbas, BXProgresso
R/Embarque/DS/BXBotoes.swift           BXBotao, BXBotaoEstilo, BXLinkSeta
R/Embarque/DS/BXCampos.swift           BXCampo, BXCampoBusca, BXCampoCodigo, BXInterruptorEstilo
R/Embarque/DS/BXEstados.swift          BXCarga, BXConteudo, BXEsqueleto, BXEstadoVazio/Erro, BXCarregando,
                                       BXFaixaOffline, BXToast, BXToastCentral
R/Embarque/DS/BXChrome.swift           BXTabBar, BXBarraUtilitaria, .bxBarraTopo, BXGavetaConteiner,
                                       BXCabecalhoPagina, BXSecao, BXCartaoClaro, BXRodapeRecibo
R/Embarque/DS/BXInteracao.swift        BXHaptica, BXCopiar, BXQRCode, BXNumeroAnimado,
                                       BXCompartilharImagem, .bxTextoNeon()
R/Embarque/DS/BXFormato.swift          pontos, datas, relativo, agrupamento por dia, máscaras, dinheiro
R/Embarque/Nucleo/BXAmbiente.swift     URL base, versão, BXRecursos (bandeiras)
R/Embarque/Nucleo/BXCofre.swift        Keychain de acesso+renovação (memória em demo)
R/Embarque/Nucleo/BXErro.swift         erro tipado e mensagens ao usuário
R/Embarque/Nucleo/BXAPI.swift          actor, transporte, renovação single-flight, idempotência
R/Embarque/Nucleo/BXAPI+Rotas.swift    todas as funções de endpoint (§1.7.5)
R/Embarque/Nucleo/BXModelos.swift      DTOs sanitizados
R/Embarque/Nucleo/BXSanitizador.swift  regex, rótulos, ícones por categoria/tipo, categorias canônicas
R/Embarque/Nucleo/BXSessao.swift       estado de sessão observável
R/Embarque/Nucleo/BXNavegacao.swift    BXAba, BXDestino, BXGrupo, BXNavegacao
R/Embarque/Nucleo/BXConectividade.swift NWPathMonitor + falhas seguidas → faixa offline
R/Embarque/Nucleo/BXCacheCarteira.swift "saldo do último acesso" (1 h)
R/Embarque/Demo/BXDemo.swift           (#if DEBUG) argumentos -BXDemo, -BXTela, ...
R/Embarque/Demo/BXTransporteDemo.swift (#if DEBUG) roteador de respostas + estado em memória
R/Embarque/Demo/BXDemoDados.swift      (#if DEBUG) dados de exemplo
R/Embarque/Demo/BXCatalogoDS.swift     (#if DEBUG) telas "componentes" e "icones" para foto
```

Esqueletos que o G0 cria e **entrega** (depois disso o dono é o grupo, §1.8):
`R/Telas/Saldo/BXTelasSaldo.swift`, `R/Telas/Movimentar/BXTelasMovimentar.swift`,
`R/Telas/Descobrir/BXTelasDescobrir.swift`, `R/Telas/Conta/BXTelasConta.swift`.

O G0 **não** toca em nenhum arquivo existente.

### 1.1 Cores (`BXCor`, valores exatos de `WEB/assets/blaxx-embarque.css:42-64` e das medidas computadas)

```swift
extension Color { init(bxHex: UInt32, opacidade: Double = 1) }   // nome novo: não colide com Color(hex:) antigo

enum BXCor {
    // superfícies
    static let chao        = Color(bxHex: 0xE4E1D9)  // --bx-bg, fundo de toda tela
    static let superficie  = Color(bxHex: 0xFBFAF7)  // cartões, gaveta, campos, recibo
    static let superficie2 = Color(bxHex: 0xF4F2EC)  // campo de busca, trilho, toque
    static let linha       = Color(bxHex: 0xD9D6CE)  // contorno 1 pt, picote
    static let pontilhado  = Color(bxHex: 0xB9B6AE)  // pontilhado do recibo, "Mais categorias"
    // texto
    static let cinza       = Color(bxHex: 0x555860)  // texto secundário (AA no chão e no cartão)
    static let cinzaIcone  = Color(bxHex: 0x5F6168)  // só decoração, nunca texto
    static let tinta       = Color(bxHex: 0x0A0B0E)  // preto da marca
    static let tinta2      = Color(bxHex: 0x2A2D35)  // linha sobre preto
    static let tinta3      = Color(bxHex: 0x3A3D46)  // tracejado sobre preto
    static let tintaApagada = Color(bxHex: 0x8A8D96) // texto secundário sobre preto; rótulo inativo da aba
    static let barraTexto  = Color(bxHex: 0xC9CBD1)  // barra utilitária, legenda da cabeça do recibo
    static let papel       = Color(bxHex: 0xF4F2EC)  // texto principal sobre preto
    // marca
    static let neon            = Color(bxHex: 0x59FD27) // só preenchimento sobre claro; texto só sobre tinta
    static let neonPressionado = Color(bxHex: 0x4FE81F)
    static let neonProfundo    = Color(bxHex: 0x5AB800) // estado ativo do botão neon; nunca texto
    static let limaSuave       = Color(bxHex: 0xEEF7E2) // chip "OLÁ, …"
    static let halo            = Color(bxHex: 0x59FD27, opacidade: 0.35) // foco de campo
    // status (fundo, texto)
    static let okFundo = Color(bxHex: 0xE4F5DA),     okTexto = Color(bxHex: 0x1F6B14)
    static let avisoFundo = Color(bxHex: 0xF7EFD6),  avisoTexto = Color(bxHex: 0x7A5A00)
    static let perigoFundo = Color(bxHex: 0xF6DFD6), perigoTexto = Color(bxHex: 0x9A2F15)
    static let infoFundo = Color(bxHex: 0xDCE8F3),   infoTexto = Color(bxHex: 0x1B4A80)
    // quadro preto
    static let quadroLinha = Color(bxHex: 0x1C1F25), quadroToque = Color(bxHex: 0x15171C)
    static let quadroRodape = Color(bxHex: 0x111318), quadroChip = Color(bxHex: 0x1A1D23)
    static let quadroApagado = Color(bxHex: 0x4A4D55)
    static let scrim = Color(bxHex: 0x0A0B0E, opacidade: 0.45)
    // níveis do Cartão BlaXx: paleta LOCAL (nunca tier.color/text_color da API; o Black da API é #C6FF00 legado)
    static func nivel(_ chave: String) -> (fundo: Color, texto: Color)
    //   bronze #CD7F32/tinta · prata #9AA0A6/tinta · ouro #D4AF37/tinta · black #0A0B0E/neon · vip #0A0B0E/papel
}
```

**Modo escuro: decidido, o app fica claro**, como o web (que não tem `prefers-color-scheme`). A linguagem Embarque depende do contraste papel × tinta e da regra "neon só como texto sobre preto"; um tema escuro inverteria onde o neon pode ser texto e precisaria de outra validação de marca. A raiz mantém `.preferredColorScheme(.light)`. Os tokens são semânticos (`chao`, `superficie`, `tinta`), então um tema escuro futuro troca só `BXCor`.

### 1.2 Medidas (`BXMedidas.swift`)

```swift
enum BXRaio { static let xl: CGFloat = 24      // cartão de embarque e painel no celular (28 no web desktop)
              static let lg: CGFloat = 18      // cartões, bilhetes, quadro, recibo, convite
              static let md: CGFloat = 14      // FAQ, toast
              static let sm: CGFloat = 12      // botão, campo, ícone 44, CTA do cartão
              static let xs: CGFloat = 10      // item da gaveta, item da aba, ícone 36
              static let xxs: CGFloat = 8      // pílula do kit, ícone da aba (30)
              static let pilula: CGFloat = 999 }
enum BXEspaco { static let margem: CGFloat = 16      // margem lateral única (o web varia 16/22/40; o app usa 16)
                static let secao: CGFloat = 40        // espaço entre seções
                static let cabecalhoSecao: CGFloat = 24
                static let cartao: CGFloat = 18       // padding interno de cartão
                static let grade: CGFloat = 12        // gap de grade de cartões
                static let colunaMax: CGFloat = 560 }
enum BXToque { static let botao: CGFloat = 48; static let chip: CGFloat = 44
               static let itemGaveta: CGFloat = 48; static let itemAba: CGFloat = 52 }
enum BXSombra { case padrao   // 0 18 40 rgba(10,11,14,.08) → .shadow(color: tinta.opacity(0.08), radius: 20, y: 18)
                case grande   // 0 24 48 .12 → radius 24, y 24
                case leve     // 0 6 16 .05 → radius 8, y 6
                case recibo } // drop-shadow 0 18 30 .12 → radius 15, y 18
extension View { func bxSombra(_ s: BXSombra) -> some View }
enum BXMovimento {
    static let ease = Animation.timingCurve(0.2, 0.75, 0.2, 1, duration: 0.22)   // --bx-ease
    static let gaveta = Animation.easeOut(duration: 0.2)
    static let letreiro = Animation.timingCurve(0.2, 0.75, 0.2, 1, duration: 0.55)
    static let mola = Animation.spring(response: 0.36, dampingFraction: 0.82)
    static func ou(_ a: Animation, reduzido: Bool) -> Animation?   // nil (sem animação) com Reduzir Movimento
}
```

Nada de sombra dura deslocada (Neo-Brutal antigo, "contorno duplo" das fotos 09/10/13 do antes): o tema Embarque usa sombra macia.

### 1.3 Tipografia (`BXFonte.swift`)

Ponto único de troca:

```swift
enum BXFonte {
    enum Modo { case sistema, embarcada }
    static let modo: Modo = .sistema        // ← ÚNICA linha a trocar para Archivo + Space Mono (D16)

    enum Estilo { case capa, linhaMarcada, tituloPagina, tituloSecao, h2, numeroGrande, numeroDestaque,
                       saldoMono, pontosBilhete, totalRecibo, tituloBilhete, nomeParceiro, valorDado,
                       corpo, corpoKit, lead, botao, botaoCartao, acaoRecibo, campo,
                       rotulo, rotuloSecao, rotuloAba, recibo, legenda }
}
extension View { func bxFonte(_ e: BXFonte.Estilo) -> some View }   // fonte + tracking + caixa + escala
```

| Estilo | pt base | Sistema (hoje) | Embarcada (troca) | Tracking | Caixa | Escala com |
|---|---|---|---|---|---|---|
| capa | 54 | SF Pro `.black` `.width(.condensed)` | Archivo wght 900 wdth 80 | −0,03 em | — | `.largeTitle` |
| linhaMarcada (fundo neon) | 0,66 × capa | idem | idem | −0,03 em | — | `.largeTitle` |
| tituloPagina | 30 | `.heavy` `.condensed` | wght 800 wdth 88 | −0,03 em | — | `.title` |
| tituloSecao | 32 | `.heavy` | wght 800 wdth 100 | −0,03 em | — | `.title` |
| h2 (páginas de conta) | 22 | `.heavy` | wght 800 | −0,02 em | — | `.title2` |
| numeroGrande (saldo no Início) | 40 | `.heavy` | wght 800 | −0,04 em | — | `.largeTitle` |
| numeroDestaque (fundo neon) | 44 | `.black` | wght 900 | −0,02 em | — | `.largeTitle` |
| saldoMono (carteira, cartão) | 44 | SF Mono `.bold` | Space Mono Bold | 0 | — | `.largeTitle` |
| pontosBilhete | 34 | `.heavy` | wght 800 | −0,02 em | — | `.title` |
| totalRecibo | 36 | `.black` | wght 900 | −0,03 em | — | `.title` |
| tituloBilhete | 19 | `.heavy` | wght 800 | −0,01 em | — | `.headline` |
| nomeParceiro | 17 | `.heavy` | wght 800 | 0 | — | `.headline` |
| valorDado | 14 | `.bold` | wght 700 | 0 | — | `.subheadline` |
| corpo / corpoKit / lead | 15 / 16 / 16 | `.regular` | wght 400 | 0 | — | `.body` |
| botao / botaoCartao | 15 / 16 | `.bold` | wght 700 | 0 | — | `.body` |
| acaoRecibo | 17 | `.bold` | wght 700 | 0,02 em | MAIÚSC | `.body` |
| campo | 16 | `.medium` | wght 500 | 0 | — | `.body` (16 evita zoom) |
| rotulo | 11 | SF Mono `.regular` | Space Mono Regular | 0,10 em | MAIÚSC | `.caption2` |
| rotuloSecao | 13 | SF Mono `.regular` | Space Mono Regular | 0,08 em | MAIÚSC | `.footnote` |
| rotuloAba | 11 | SF Mono `.regular` | Space Mono Regular | 0,04 em | MAIÚSC | fixo (máx. `.xxLarge`) |
| recibo | 13 | SF Mono `.regular` | Space Mono Regular | 0 | — | `.footnote` |
| legenda | 12 | `.regular` | wght 400 | 0 | — | `.caption` |

Implementação:

- `bxFonte` é um `ViewModifier` com `@ScaledMetric(relativeTo:)` inicializado com o pt base, então tudo acompanha o Dynamic Type.
- Modo `.embarcada`: Archivo é variável. Montar `UIFontDescriptor(fontAttributes: [.family: "Archivo", kCTFontVariationAttribute: [0x77676874 /*wght*/: peso, 0x77647468 /*wdth*/: largura]])` → `Font(UIFont(descriptor:size:))`. Space Mono: `Font.custom("SpaceMono-Regular" | "SpaceMono-Bold", size:, relativeTo:)`. Se `UIFont(name:)` vier nil, cair no modo sistema (sem crash).
- Altura de linha: o título de capa tem `line-height .9`. SwiftUI não aceita entrelinha menor que 1, então `BXTituloCapa` desenha **uma linha por `Text`** num `VStack(spacing: -0.12 × tamanho)` (o web também faz uma linha por `<span>`).
- Cada linha de título usa `.lineLimit(1).minimumScaleFactor(0.6)` em tamanhos normais e libera a quebra (`lineLimit(nil)`) em tamanhos de acessibilidade. Isso evita o "Favori/te" quebrado do web (foto 13-08).

### 1.4 Ícones (`BXSVG.swift`, `BXIconesDados.swift`, `BXIcone.swift`)

Fonte: `DOCS/icones.json` (51 entradas: as 50 de `ICONES` em `WEB/assets/blaxx-nav.js` + `menu`) e os 6 desenhos inline listados no Anexo A de 02: `setaCima`, `setaBaixo`, `visto`, `chave`, `semMensalidade`, `prancheta`. Total: 57.

Parser (`nonisolated enum BXSVG`):

- Elementos: `<path d>`, `<rect x y width height rx>`, `<circle cx cy r>`, `<ellipse cx cy rx ry>`.
- Comandos de path: `M m L l H h V v C c S s Q q T t A a Z z`, números colados (`.5.5`, `-1.4-2`), comandos implícitos repetidos. Arco `A/a` convertido de parametrização de ponto final para centro e aproximado por cúbicas (vários ícones usam arcos: `voucher`, `indique`, `favorito`, `celular`, `sair`, `seguranca`).
- Atributos por elemento: `fill="currentColor" stroke="none"` → elemento preenchido (pontos de `carteira`, `ajuda`, `info`, `alerta`, `campanhas`); `stroke-dasharray="2 2.4"` → tracejado (`voucher`); `fill`, `fill-rule="evenodd"` e `viewBox` para a marca (§1.5).
- Saída: `[BXSVG.Elemento]` com `path: Path`, `preenchido: Bool`, `tracejado: [CGFloat]?`, `cor: Color?`. Resultado em cache por nome (`static let` lazy).
- Desenho: `viewBox 0 0 24 24`, traço 1,8 (o `menu` usa 2), `lineCap`/`lineJoin` `.round`, cor `BXCor.tinta`.

API:

```swift
enum BXIconeNome: String, CaseIterable, Sendable {
    case inicio, carteira, extrato, parceiros, resgates, voucher, campanhas, comprar, enviar, receber,
         indique, perfil, seguranca, ajuda, sair, notificacoes, cartao, check, alerta, erro, info, estrela,
         email, chat, documento, anexo, festa, raio, carrinho, aviao, hotel, posto, farmacia, supermercado,
         filme, moda, local, loja, mais, seta, grafico, relogio, calendario, tag, favorito, celular, busca,
         configuracoes, trocar, usuarioMais = "usuario_mais", menu,
         setaCima, setaBaixo, visto, chave, semMensalidade, prancheta
}

struct BXIcone: View {
    enum Tamanho { case aba        // 30, raio 8, desenho 20 (padding 5)
                   case lateral    // 28, raio 8, desenho 18
                   case atalho     // 36, raio 10, desenho 20
                   case cartao     // 40, raio 12, desenho 22 (cartão de parceiro, lupa do campo)
                   case padrao     // 44, raio 12, desenho 24,6 (56 %)
                   case marca      // 52, raio 14, desenho 29 (categoria no detalhe do parceiro)
                   case livre(lado: CGFloat, raio: CGFloat) }
    enum Forma { case quadrado, circulo }          // círculo só para o sino da barra
    init(_ nome: BXIconeNome, tamanho: Tamanho = .padrao, forma: Forma = .quadrado)
    // fundo SEMPRE BXCor.neon, desenho SEMPRE BXCor.tinta. Não há parâmetro de cor: a regra do dono fica no tipo.
    // .accessibilityHidden(true) por padrão: o rótulo vem do controle que contém o ícone.
}

/// Exceção controlada: glifos de CONTROLE do chrome (não são ícones de conteúdo).
/// voltar (chevron do sistema), fechar "×", hambúrguer da barra de visitante. Cor papel sobre tinta ou tinta sobre claro.
struct BXGlifo: View { enum Tipo { case fechar, menu }; init(_ t: Tipo, cor: Color) }
struct BXSino: View  { init(naoLidas: Int) }        // círculo neon 42 com sino preto + selo de contagem tinta/papel
struct BXAvatar: View { init(inicial: String?, tamanho: CGFloat = 42) }   // anel tinta2 + círculo neon com a inicial em tinta
```

O G0 entrega a tela DEBUG `-BXTela icones` (`BXCatalogoDS.swift`) com os 57 desenhos no quadrado neon 44, para conferir lado a lado com `DOCS/fotos-web/95-icones-folha.png`.

### 1.5 Marca (`BXMarca.swift`)

```swift
struct BXWordmark: View {
    enum Variante { case barra          // "Bla" branco + "Xx" neon (blaxx-wordmark-barra.svg, viewBox 40 28 817 158)
                    case claro          // "Bla" tinta + "Xx" neon com contorno tinta (…-barra-claro.svg, viewBox 36 24 825 166)
                    case logoCompleto } // B + BlaXx + REWARDS, fundo escuro (blaxx-logo-completo-justo.svg, viewBox 35 24 540 445)
    init(_ v: Variante = .barra, altura: CGFloat = 22)   // barra: 114 × 22; cabeça do recibo: altura 30; rodapé: 80
    // .accessibilityLabel("BlaXx")
}
```

Os `d=` dos três SVG de `WEB/assets/marca/` vão como literais em `BXMarca.swift` e passam pelo `BXSVG` (preenchimento com as cores do próprio arquivo, `fill-rule` evenodd, escala pelo `viewBox`). Os assets antigos `BlaxxWordmark`, `BlaxxWordmarkClaro` (com "REWARDS") e `BlaxxLockup` deixam de ser usados.

### 1.6 Componentes (API Swift)

Assinaturas são contrato: os grupos programam contra elas. O G0 pode acrescentar parâmetros com valor padrão, nunca mudar os existentes.

#### 1.6.1 Cartão de embarque (`.bx-cartao`, fotos web 01-01/02, 13-01, 14b-02)

```swift
struct BXCartaoEmbarque<Miolo: View, Canhoto: View>: View {
    init(topo: (esquerda: String, direita: String)? = nil,     // mono 11 MAIÚSC cinza: "CARTÃO DE EMBARQUE · BLAXX PONTOS" | "BRASIL · 2026"
         codigoDeBarras: Bool = true,
         @ViewBuilder miolo: () -> Miolo,
         @ViewBuilder canhoto: () -> Canhoto)
    // superfície, raio 24, .bxSombra(.padrao), largura total menos 16+16.
    // miolo padding 22/16/24, gap 20 · picote horizontal · canhoto padding 20/20/22, gap 18 · código de barras 36.
}
struct BXTituloCapa: View {
    init(linhas: [String], marcadas: [String] = [], estilo: BXFonte.Estilo = .capa)  // marcadas = linhas com fundo neon (padding .05em .18em)
}
struct BXLetreiro: View {          // 2ª linha alternando ("Novos destinos / sonhos / aventuras") a cada 2,6 s
    init(prefixo: String, palavras: [String], intervalo: Double = 2.6)
    // .contentTransition(.push(from: .bottom)) com BXMovimento.letreiro; para com Reduzir Movimento,
    // fora da tela (onDisappear) e enquanto o usuário rola (scrollPhase != .idle)
}
struct BXDado: Hashable { let rotulo: String; let valor: String }
struct BXGradeDados: View { init(_ dados: [BXDado], colunas: Int = 2) }    // border-top 1 pt linha, padding-top 18, gap 16/14
// Em tamanhos de acessibilidade a grade vira 1 coluna (ViewThatFits / dynamicTypeSize.isAccessibilitySize).
```

#### 1.6.2 Formas (`BXFormas.swift`)

```swift
struct BXPicote: View {
    enum Orientacao { case horizontal, vertical }
    init(_ o: Orientacao, recorte: CGFloat = 28)
    // linha tracejada 2 pt BXCor.linha + dois recortes de 28 pt nas pontas.
    // Recortes são FUROS de verdade (compositingGroup + blendMode(.destinationOut)), não círculos pintados com a cor do chão:
    // o cartão pode estar sobre chão, superfície ou sheet.
}
struct BXSerrilha: Shape { init(periodo: CGFloat = 12, borda: Edge) }   // zigue-zague do recibo
struct BXCodigoBarras: View { init(altura: CGFloat = 36, cor: Color = BXCor.tinta) }
// padrão repetido de 14 pt: 2 cheio, 2 vazio, 3 cheio, 2 vazio, 1 cheio, 4 vazio. Decorativo: accessibilityHidden.
struct BXTracejado: View { init(cor: Color = BXCor.tinta, espessura: CGFloat = 2) }
```

#### 1.6.3 Bilhete com canhoto (`.bx-bilhete`, fotos 01-04, 14b-02)

```swift
struct BXBilhete<Miolo: View>: View {
    enum Canhoto { case selo                         // círculo 30, borda 2 tinta; selecionado: canhoto neon + selo tinta com visto neon
                   case icone(BXIconeNome)           // ícone 30 no canhoto
                   case seta                         // canhoto neon com seta (campanha)
                   case favorito(Bool, alternar: () -> Void) }   // coração em quadrado neon 30
    init(selecionado: Bool = false, canhoto: Canhoto = .selo, acao: (() -> Void)? = nil,
         @ViewBuilder miolo: () -> Miolo)
    // linha: miolo (padding 16/16/14, gap 8) + picote vertical + canhoto 56 pt.
    // superfície, raio 18, borda 2 pt transparente → tinta quando selecionado.
    // Acessibilidade: um único elemento-botão, traits .isButton (+ .isSelected), .sensoryFeedback(.selection).
}
struct BXBilhetePacote: View {          // usado por G1 (visitante) e G3 (Comprar)
    init(pacote: BXPacote, selecionado: Bool, mostrarBonus: Bool = BXRecursos.percentualBonusPacote, acao: @escaping () -> Void)
    // cabeçalho mono "BX · PLUS" · pontos 34/800 + "pts" 18 cinza · "TARIFA" + preço 22/700.
    // Sem linha de bônus enquanto BXRecursos.percentualBonusPacote == false (D07).
}
struct BXBilheteCampanha: View {        // usado por G2 (Início) e G4 (Parceiros, Campanhas)
    init(campanha: BXCampanha, indice: Int, total: Int, acao: @escaping () -> Void)
    // "BX · CAMPANHA ATIVA" · "01 de 03" · nome · chip "+5.000 pts ao concluir" · descrição segura · canhoto .seta
}
```

#### 1.6.4 Recibo com serrilhado e cabeça preta (`.bx-recibo`, fotos 01-04/05, 14b-03)

```swift
struct BXRecibo<Corpo: View>: View {
    struct Acao { let titulo: String; let executar: () -> Void }   // botão preto, sem raio, 56, acaoRecibo MAIÚSC
    init(cabeca: String? = nil,          // legenda mono 12 barraTexto sob o BXWordmark(.barra, altura: 30); nil = sem cabeça preta
         acao: Acao? = nil,
         @ViewBuilder corpo: () -> Corpo)
    // serrilhado 12 em cima (preto se houver cabeça) e embaixo; corpo superfície, fonte .recibo, padding 22/16, gap 14;
    // .bxSombra(.recibo). Regra do CSS: nunca linha de valor do ponto, nunca linha de "taxa".
}
struct BXReciboLinha: View  { init(_ rotulo: String, _ valor: String) }      // RÓTULO ……… valor (pontilhado 2 pt BXCor.pontilhado)
struct BXReciboTotal: View  { init(_ rotulo: String = "TOTAL", _ valor: String) }   // valor em .totalRecibo
struct BXReciboFaixa: View  { init(_ rotulo: String, _ valor: String) }      // faixa neon que sangra 12 pt para os lados
struct BXReciboTracejo: View { init() }                                     // linha tracejada tinta 2 pt
struct BXReciboVia: View    { init(_ texto: String = "VIA DO PASSAGEIRO") }
struct BXReciboNota: View   { init(_ texto: String) }                       // 12 cinza
// Acessibilidade: cada BXReciboLinha é um elemento "Rótulo, valor" (o pontilhado fica oculto).
```

`BXCompartilharImagem` (§1.6.12) renderiza qualquer `BXRecibo` em PNG via `ImageRenderer` para os comprovantes.

#### 1.6.5 Rota com escalas (`.bx-escala`, fotos 01-02, 13-08)

```swift
struct BXEscala: Identifiable { let id: Int; let rotulo: String; let palavra: String; let texto: String }
// rotulo "ESCALA 01 · COMPRAR", palavra "Compre", texto 15 cinza
struct BXRotaEscalas: View { init(_ escalas: [BXEscala]) }
// linha do tempo vertical: ponto 24 tinta (o último neon com borda tinta), tracejado 2 pt tinta em x = 11,
// palavra 34/800 com minimumScaleFactor (não quebra no meio). Acessibilidade: lista ordenada.
```

#### 1.6.6 Painel de partidas e quadro preto (fotos 01-05/07)

```swift
struct BXPainel<Conteudo: View>: View { init(rotulo: String, titulo: String, @ViewBuilder conteudo: () -> Conteudo) }
struct BXNumeroDestaque: View { init(_ numero: String, legenda: String) }       // número 44/900 sobre neon + legenda
struct BXQuadroLinha: Identifiable, Hashable { let id: String; let destino: String; let pais: String; let ativa: Bool /*Em implantação*/ }
struct BXQuadroPreto<Rodape: View>: View {
    init(cabecalho: [String] = ["DESTINO", "PAÍS", "SITUAÇÃO"], linhas: [BXQuadroLinha],
         selecionada: Binding<String?>, @ViewBuilder rodape: (BXQuadroLinha?) -> Rodape)
    // raio 18, mono 14, linhas MAIÚSC 13 padding 12/16 divisória quadroLinha, bolinha 8 (neon = em implantação,
    // quadroApagado = em expansão), linha selecionada toda neon com texto tinta. Rola por dentro (máx. 300).
}
```

#### 1.6.7 Rótulos, chips, status, pílulas, abas, progresso (`BXRotulos.swift`)

```swift
struct BXRotulo: View { enum Nivel { case dado, secao, aba }; init(_ texto: String, _ nivel: Nivel = .dado, cor: Color = BXCor.cinza) }
struct BXChip: View {
    enum Estilo { case eyebrow    // mono 11, fundo superficie2, borda linha, pílula, padding 5/12 ("CARTEIRA BLAXX")
                  case saudacao   // mono 11/700, fundo limaSuave, borda neon, padding 8/14 ("OLÁ, CLIENTE")
                  case preto      // fundo tinta, texto NEON (permitido) ("EM PROCESSAMENTO", "CLIENTE", "ATUAL")
                  case neon }     // fundo neon, texto tinta ("+5.000 pts")
    init(_ texto: String, _ estilo: Estilo)
}
struct BXStatus: View { enum Tipo { case ok, aviso, perigo, info }; init(_ texto: String, _ tipo: Tipo, ponto: Bool = true) }
struct BXPilula: View {
    enum Estilo { case kit /*raio 8, h 40, mono 11 MAIÚSC, contador na pílula*/, conta /*raio 999, h 44, 13/700*/ }
    init(_ texto: String, contador: Int? = nil, ativa: Bool, tracejada: Bool = false, estilo: Estilo = .kit, acao: @escaping () -> Void)
    // ativa = fundo neon + texto tinta. .sensoryFeedback(.selection). traits .isSelected.
}
struct BXAbas<Valor: Hashable>: View {
    enum Ativo { case papel /*texto papel sobre tinta*/, neon /*texto neon sobre tinta*/ }
    init(selecao: Binding<Valor>, opcoes: [(Valor, String)], ativo: Ativo = .papel)
    // trilho superfície com borda, padding 5, gap 6; aba ativa tinta 44 pt;
    // o fundo ativo desliza com matchedGeometryEffect (sem animação com Reduzir Movimento).
}
struct BXProgresso: View { init(fracao: Double, altura: CGFloat = 12) }   // trilho superficie2 + borda linha, preenchimento neon
```

#### 1.6.8 Botões (`BXBotoes.swift`)

```swift
struct BXBotao: View {
    enum Estilo { case primario        // neon, texto tinta, 15/700, raio 12, padding 13/20, mín. 48; pressionado neonPressionado
                  case preto           // tinta, texto superficie ("Entrar →", "Continuar →")
                  case secundario      // superficie, borda 1 linha, texto tinta
                  case vazadoSobrePreto// transparente, borda papel 35 %, texto papel
                  case cartao          // CTA do cartão de embarque: neon, raio 12, padding 16, 16/700
                  case perigo }        // superficie, borda perigoTexto, texto perigoTexto (excluir conta)
    init(_ titulo: String, estilo: Estilo = .primario, icone: BXIconeNome? = nil,
         carregando: Bool = false, larguraTotal: Bool = true, acao: @escaping () -> Void)
    // desabilitado (.disabled): opacidade 0,45 no botão inteiro; como o texto do primário é tinta, nunca vira neon sobre claro.
    // carregando: ProgressView tinta no lugar do texto, mantém a largura, accessibilityLabel "<título>, carregando".
}
struct BXLinkSeta: View { init(_ titulo: String, acao: @escaping () -> Void) }   // texto tinta 15/700 sublinhado + " →"
```

#### 1.6.9 Campos (`BXCampos.swift`)

```swift
struct BXCampo: View {
    enum Tipo { case texto, nome, email, emailOuCPF, cpf, celular, senha, novaSenha, pontos, dinheiro, mensagem(limite: Int) }
    init(_ rotulo: String, texto: Binding<String>, tipo: Tipo = .texto, placeholder: String = "",
         dica: String? = nil, erro: String? = nil)
    // rótulo mono 11 MAIÚSC cinza acima; superfície, borda 1 linha, raio 12, padding 13/14, 48, fonte .campo.
    // foco: borda tinta + halo neon 35 % de 3 pt. erro: borda perigoTexto + texto 12 perigoTexto (accessibilityValue).
    // Cada Tipo define textContentType, keyboardType, autocapitalização e máscara:
    //   email → .emailAddress; emailOuCPF → máscara de CPF só se for tudo dígito; cpf → 000.000.000-00;
    //   celular → (00) 00000-0000; senha → .password (SecureField + "Mostrar"); novaSenha → .newPassword;
    //   pontos → .numberPad com milhar; dinheiro → R$ com centavos; mensagem → contador "n/140".
}
struct BXCampoBusca: View { init(texto: Binding<String>, placeholder: String) }   // 56, 18/600, fundo superficie2, lupa BXIcone(.busca, .cartao) dentro
struct BXCampoCodigo: View { init(codigo: Binding<String>, digitos: Int = 6) }     // 6 caixas, .oneTimeCode, colar inteiro
struct BXInterruptorEstilo: ToggleStyle { }                                        // 46 × 26, pílula, ligado neon
```

#### 1.6.10 Estados (`BXEstados.swift`)

```swift
enum BXCarga<Valor> { case ocioso, carregando, pronto(Valor), vazio, erro(BXErro) }

struct BXConteudo<Valor, Pronto: View, Esqueleto: View>: View {
    init(_ carga: BXCarga<Valor>,
         vazio: BXEstadoVazio,
         tentarDeNovo: @escaping () async -> Void,
         @ViewBuilder esqueleto: () -> Esqueleto,
         @ViewBuilder pronto: @escaping (Valor) -> Pronto)
}
struct BXEsqueleto: View {
    enum Forma { case linha(largura: CGFloat), bloco(altura: CGFloat), cartaoParceiro, bilhete, linhaExtrato, cartaoEmbarque }
    init(_ f: Forma)   // blocos superficie2 com brilho que corre; estático com Reduzir Movimento; accessibilityLabel "Carregando"
}
struct BXEstadoVazio: View { init(icone: BXIconeNome, titulo: String, texto: String? = nil, acao: (titulo: String, executar: () -> Void)? = nil) }
// cartão com borda TRACEJADA BXCor.pontilhado, texto cinza centralizado
struct BXEstadoErro: View { init(_ erro: BXErro, tentarDeNovo: @escaping () async -> Void) }
// ícone .alerta no quadrado neon, título "Não foi possível carregar.", erro.mensagemParaUsuario, botão secundário "Tentar de novo"
struct BXCarregando: View { init(_ texto: String = "Carregando…") }
struct BXFaixaOffline: View { init(verificando: Bool, verificar: @escaping () -> Void) }
// fundo avisoFundo, raio 12, 12 das bordas, acima da barra de abas: "Conexão instável com o servidor. Tentando reconectar…" + "Verificar agora"
@MainActor @Observable final class BXToastCentral {
    enum Tipo { case sucesso, info, aviso, erro }
    func mostrar(_ texto: String, _ tipo: Tipo = .sucesso)   // 4 s; erro = anúncio VoiceOver + háptica .error
}
extension View { func bxToastHost(_ central: BXToastCentral) -> some View }   // cápsula no topo, sob a barra preta, raio 14, 14/600
```

#### 1.6.11 Chrome (`BXChrome.swift`)

```swift
enum BXAba: String, CaseIterable, Hashable, Sendable { case inicio, carteira, comprar, resgates }   // definida no Núcleo (§1.7.7)
struct BXTabBar: View {
    init(selecionada: Binding<BXAba>, aoTocarMenu: @escaping () -> Void, aoRetocar: @escaping (BXAba) -> Void)
    // preta, borda superior tinta2, padding 6/4 + área segura, 5 colunas iguais (Início, Carteira, Comprar, Resgates, Menu);
    // item coluna gap 4, mín. 52, raio 10; ícone BXIcone(.aba) (inicio, carteira, comprar, resgates, menu);
    // rótulo .rotuloAba: ativo NEON (sobre preto, permitido), inativo tintaApagada.
    // .accessibilityShowsLargeContentViewer() em cada item; .dynamicTypeSize(...DynamicTypeSize.xxLarge) na barra.
}
struct BXBarraUtilitaria: View { init(texto: String = "Rede em expansão") }   // preta 28, mono 11, bolinha + texto neon
extension View {
    /// Barra preta do topo aplicada pela casca (G1) em toda tela: fundo tinta visível, toolbarColorScheme(.dark),
    /// raiz: wordmark 114×22 à esquerda; empilhada: voltar do sistema (papel) + wordmark 96×18 no centro;
    /// direita logado: BXSino + BXAvatar; direita visitante: "Entrar" (texto papel) + hambúrguer.
    func bxBarraTopo(_ modo: BXBarraTopoModo, naoLidas: Int, inicial: String?,
                     aoSino: @escaping () -> Void, aoAvatar: @escaping () -> Void,
                     aoEntrar: @escaping () -> Void, aoMenu: @escaping () -> Void) -> some View
}
enum BXBarraTopoModo { case raizLogado, empilhadaLogado, raizVisitante, empilhadaVisitante }
struct BXGavetaConteiner<Conteudo: View>: View {
    enum Lado { case esquerda /*logado*/, direita /*visitante*/ }
    init(aberta: Binding<Bool>, lado: Lado, @ViewBuilder conteudo: () -> Conteudo)
    // largura min(88 % da tela, 360), superfície, scrim 45 %, "×" 44; fecha no scrim, no ×, arrastando para fora
    // e com o gesto de escape do VoiceOver (accessibilityAction(.escape)); foco preso (.accessibilityAddTraits(.isModal)).
}
struct BXCabecalhoPagina: View { init(eyebrow: String, titulo: String, lead: String? = nil) }   // chip eyebrow + h1 .tituloPagina + lead
struct BXSecao<Conteudo: View>: View {
    init(rotulo: String, titulo: String? = nil, link: (String, () -> Void)? = nil, @ViewBuilder conteudo: () -> Conteudo)
    // "ROTA · COMO FUNCIONA" (.rotuloSecao) + h2 (.tituloSecao) + BXLinkSeta; padding-bottom 40
}
struct BXCartaoClaro: View { init(icone: BXIconeNome, titulo: String, texto: String, acao: (() -> Void)? = nil) }
// superfície, borda 1 linha, raio 18, padding 16; ícone .atalho; usado em atalhos e convite
struct BXRodapeRecibo: View { init() }
// preto de borda a borda: BXWordmark(.logoCompleto, altura: 80), frase da marca, aviso legal
// "Os pontos BlaXx não são moeda, depósito, investimento, valor mobiliário ou criptoativo. São créditos promocionais
//  de uso restrito dentro da plataforma BlaXx.", "© 2026 BlaXx Pontos", código de barras papel 200 × 28.
```

#### 1.6.12 Interação e utilidades (`BXInteracao.swift`, `BXFormato.swift`)

```swift
enum BXHaptica { case selecao, sucesso, aviso, erro, leve
                 static func tocar(_ h: BXHaptica) }     // para resultados assíncronos; em gestos, preferir .sensoryFeedback
struct BXNumeroAnimado: View {
    init(_ valor: Int?, estilo: BXFonte.Estilo, sufixo: String? = nil)   // nil → "—"
    // Text com .contentTransition(.numericText(value:)) + .animation(.snappy, value:);
    // primeira aparição conta de 0 até o valor em 0,6 s, só sem Reduzir Movimento e só se não veio do cache.
    // accessibilityLabel "32.480 pontos" (nunca "pts").
}
enum BXCopiar { static func copiar(_ texto: String, aviso: String, toast: BXToastCentral) }   // UIPasteboard + toast + .leve
struct BXQRCode: View { init(_ conteudo: String, lado: CGFloat = 220) }    // CIQRCodeGenerator, interpolação .none, nítido
enum BXCompartilharImagem { @MainActor static func imagem<V: View>(de view: V, largura: CGFloat = 375) -> Image? }   // ImageRenderer, scale 3
extension View { func bxTextoNeon() -> some View }   // ÚNICA forma de pintar texto neon; só usar sobre BXCor.tinta
nonisolated enum BXFormato {
    static func pontos(_ n: Int) -> String                 // "32.480"
    static func pontosComUnidade(_ n: Int) -> String       // "32.480 pts"
    static func pontosSinal(_ n: Int) -> String            // "+1.234" / "−353" (sinal de menos tipográfico)
    static func dinheiro(_ v: Decimal) -> String           // "R$ 470,00" — SÓ tarifa de pacote e valor de cobrança
    static func data(_ d: Date) -> String                  // "22/10/2026"
    static func dataHora(_ d: Date) -> String              // "22 out · 14:05"
    static func relativo(_ d: Date, agora: Date = .now) -> String   // "agora", "há 5 min", "há 2 h", "há 3 d"
    static func dia(_ d: Date, agora: Date = .now) -> String        // "Hoje", "Ontem", "12 out"
    static func cartao(_ id: String) -> String             // "DE0A 11C2"
    static func cpfMascarado(_ cpf: String) -> String      // "***.***.789-**"
    static func celularMascarado(_ tel: String) -> String  // "+55 (••) •••••-1234"
    static func iso8601(_ s: String) -> Date?              // aceita com e sem fração e fuso
}
```

#### 1.6.13 Proibido nos grupos

- Cor literal (`Color(red:…)`, `Color(bxHex:)`) fora de `BXCor`; fonte literal (`.font(.system(size:))`) fora de `BXFonte`; SF Symbol como ícone de conteúdo (só o chevron do sistema na navegação).
- `.foregroundStyle(BXCor.neon)` direto: usar `.bxTextoNeon()` e só sobre tinta.
- Sombra deslocada sem desfoque (`radius: 0`).
- Qualquer `Image(systemName:)` dentro de `R/Telas/` sem justificativa no código.

### 1.7 Núcleo (`R/Embarque/Nucleo/`)

#### 1.7.1 Ambiente e recursos (`BXAmbiente.swift`)

```swift
nonisolated enum BXAmbiente {
    static let urlProducao = URL(string: "https://blaxx-pontos-exe.onrender.com")!
    static var urlBase: URL       // Release: sempre produção. DEBUG: -BXBackend <url> > UserDefaults("blaxx_backend_url") > produção
    static var ehDebug: Bool
    static var versaoApp: String  // CFBundleShortVersionString (build)
}
nonisolated enum BXRecursos {     // bandeiras de produto. Cada uma tem dono na seção 6.
    static let compraCartao = false              // D02: cartão (Stripe live + regra 3.1.1)
    static let resgateTransferencia = false      // D03: /redeem/ fica fora do app
    static var campanhas: Bool { BXAmbiente.ehDebug }   // D04: campanhas de produção escondidas em Release até confirmação
    static let convidarAmigos = true             // D06: só compartilhar, sem prometer pontos
    static let percentualBonusPacote = false     // D07: sem "% de bônus" nos pacotes
    static var loginGoogle: Bool { true }  // D10 decidido pelo dono (22/10): Google também em Release; Sign in with Apple fica pendente para antes da App Store (regra 4.8)
    static let bloqueioFaceID = false            // D11
}
```

#### 1.7.2 Cofre (`BXCofre.swift`)

```swift
nonisolated struct BXTokens: Codable, Sendable { let acesso: String; let renovacao: String; let emitidoEm: Date }
actor BXCofre {
    static let shared: BXCofre
    func ler() -> BXTokens?; func gravar(_ t: BXTokens); func limpar()
    // Keychain, serviço NOVO "com.blaxx.pontos.sessao.v2", kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.
    // Em demo: só memória, nunca Keychain.
}
```

#### 1.7.3 Cliente HTTP (`BXAPI.swift`, `BXErro.swift`)

```swift
nonisolated struct BXChaveIdempotencia: Sendable, Hashable { let valor: String; init() }   // UUID por INTENÇÃO
nonisolated struct BXRequisicao: Sendable {
    enum Metodo: String, Sendable { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }
    var metodo: Metodo
    var caminho: String                    // "/wallet/transactions?limit=100" (concatenado cru, nunca appendingPathComponent)
    var corpo: Data? = nil
    var autenticada = true
    var renovacao = false                  // usa o refresh token como Bearer (só /auth/refresh)
    var idempotencia: BXChaveIdempotencia? = nil
    var aquecer = false                    // GET /health antes (cold start do Render) se a última resposta tem > 10 min
}
nonisolated protocol BXTransporte: Sendable { func executar(_ r: URLRequest) async throws -> (Data, HTTPURLResponse) }

actor BXAPI {
    static let shared: BXAPI               // transporte real; em DEBUG com -BXDemo, BXTransporteDemo
    func requisitar<T: Decodable & Sendable>(_ r: BXRequisicao, como: T.Type) async throws -> T
    func requisitarSemCorpo(_ r: BXRequisicao) async throws
    func requisitarDados(_ r: BXRequisicao) async throws -> Data          // .pkpass, exportação LGPD
    var aoExpirarSessao: (@MainActor () -> Void)?                         // a sessão registra
}
```

Comportamento obrigatório:

1. Transporte real usa `SSLPinning.session` (pinning em Release) e **em toda `URLRequest`**: `httpShouldHandleCookies = false` (03 §0.7: cookie `blaxx_session` + CSRF derruba escritas com 401), `timeoutInterval = 30`, headers `Content-Type: application/json`, `Authorization: Bearer …` quando autenticada, `X-Platform: ios`, `X-Device-Id: identifierForVendor`, `X-App-Version`, `Idempotency-Key` quando houver.
2. GET: até 3 tentativas com backoff (0,3 s, 0,6 s + jitter) em erro transitório e 5xx. POST/PATCH/DELETE: 1 tentativa; o "Tentar de novo" da tela reaproveita a **mesma** `BXChaveIdempotencia` até uma resposta definitiva.
3. Renovação **single-flight**: 401 com `error == "unauthorized"` ou corpo `{"msg": …}` → uma única `POST /auth/refresh` por vez (demais chamadas esperam a mesma `Task`) → grava os dois tokens (rotação) → repete a requisição uma vez. Refresh falhou → limpa o cofre e chama `aoExpirarSessao`. Renovação proativa ao voltar para primeiro plano se o access tem mais de 25 min.
4. **401 não é sempre sessão**: senha atual errada, credenciais inválidas, `mfa_required`, código MFA inválido e reautenticação Google voltam 401 e **não** derrubam a sessão (03 §1).
5. Corpo de erro HTML (404/405/429 do Werkzeug/Limiter) é ignorado; a mensagem vem do mapa de status.
6. Nada de mensagem de desenvolvedor ("Suba o Flask…", `API.swift:391`).

```swift
nonisolated struct BXErro: Error, Sendable, Equatable {
    enum Tipo: Sendable { case semConexao, tempoEsgotado, servidor, sessaoExpirada, naoAutorizado, emailNaoVerificado,
                          mfaNecessario, muitasTentativas, bloqueado, conflito, saldoInsuficiente, semEstoque,
                          pagamentoIndisponivel, validacao, naoEncontrado, desconhecido }
    let status: Int; let tipo: Tipo; let codigo: String?; let mensagemServidor: String?
    let problemas: [String]            // issues[].message (política de senha)
    let tentativasRestantes: Int?; let tentarEmSegundos: Int?; let bloqueadoAte: Date?
    let extras: [String: String]       // previous_transfer_id, hint, mfa_method, …
    var mensagemParaUsuario: String    // pt-BR, sem PIX em contexto de resgate, sem jargão
}
```

Mapa mínimo de `mensagemParaUsuario`: sem conexão → "Sem conexão. Verifique a internet e tente de novo."; tempo esgotado → "O servidor está demorando para responder. Tente de novo em alguns segundos."; 429 → "Muitas tentativas. Aguarde um pouco e tente de novo."; 5xx → "Algo deu errado do nosso lado. Tente de novo."; 423 → "Conta bloqueada temporariamente. Tente de novo depois de HH:MM."; 400 do provedor PIX fora ("Não foi possível gerar a cobrança PIX…") → tipo `.pagamentoIndisponivel`, "O pagamento por PIX está indisponível no momento."; 402 → `.saldoInsuficiente`; 409 "Sem estoque" → `.semEstoque`; 409 `DUPLICATE_SUSPECTED` → `.conflito`; 403 `EMAIL_NOT_VERIFIED` → `.emailNaoVerificado`.

#### 1.7.4 Modelos sanitizados (`BXModelos.swift`, todos `nonisolated struct … : Decodable, Sendable, Identifiable, Hashable`)

Cada DTO decodifica **só** os campos abaixo (os proibidos ficam fora do `CodingKeys`) e já traz os campos derivados prontos para tela.

| Modelo | Campos (da API → Swift) | Derivados / regras |
|---|---|---|
| `BXUsuario` | id, name, email, cpf, phone, email_verified_at, is_vip, mfa_enabled, has_password, google_linked, auth_provider | `cartaoID` (8 hex maiúsculos do id), `primeiroNome`, `inicial`, `cpfMascarado`, `celularMascarado`, `emailVerificado`, `contaGoogleSemCPF` (cpf começa com "G:"). **`pix_key` não é decodificado** enquanto D03 estiver desligado. |
| `BXCarteira` | balance_pts → `saldo`, pending_pts → `emProcessamento` | **sem** `balance_brl_equiv` |
| `BXLancamento` | id, type, status, amount_pts, description, reference, created_at | `tipo: BXTipoLancamento` (purchase, transfer_out, transfer_in, redeem, refund, bonus, expire, accrual, desconhecido); `rotulo` montado pelo tipo (§1.7.6); `detalhe` = description só se passar no sanitizador e sem "(pending)"/"via PIX"; `ehEntrada` |
| `BXCartaoEstado` | member{id,name}, balance_pts, lifetime_points, tier, next_tier, points_to_next, progress_pct, tiers[], wallet_pass_available | `BXNivel {chave, nome, minimo, porConvite}`; **sem** `perks`, `color`, `text_color` |
| `BXPacote` | chave (key do objeto), label, points, price_brl | ordenado start, plus, prime, black |
| `BXProvedorPix` | name, is_mock | — |
| `BXCobrancaPix` | id, amount_brl → `valor: Decimal`, points_to_credit → `pontos`, br_code, qr_code_image, status, expires_at, package | `qrImagem: Data?` (data URI decodificado); `BXStatusCobranca` (pending, pending_confirmation, paid, expired, refunded, rejected) |
| `BXConfigCartao` | enabled, provider, public_key, max_installments | — |
| `BXCobrancaCartao` | id, amount_brl, points_to_credit, status, status_detail, card_brand, card_last4, created_at | — |
| `BXEnvio` | id, amount_pts, message, receipt_code, created_at, status, committed_at, cancelled_at, is_cancellable | `segundosParaEfetivar` |
| `BXParceiro` | id, name, category, description, city | `categoriaCanonica`, `icone`, `descricaoSegura` (nil se casar com a regex), `ehFicticio`; **sem** `logo_emoji`, `accrual_rule` |
| `BXParceiroDetalhe` | parceiro + benefits[] | — |
| `BXBeneficio` | id, partner_id, partner_name, name, description, category, cost_pts, stock, expires_in_days, tag | `descricaoSegura`, `rotuloCategoria` ("educacao" → "Educação"), `icone`, `esgotado`; **sem** `image_emoji` |
| `BXVoucher` | id, benefit_id, benefit_name, code, points_spent, expires_at, used_at, status, created_at | `BXStatusVoucher` (active, used, expired) |
| `BXCampanha` | id, name, description, reward_pts, period_start, period_end, joined, progress_pct, completed_at | `nomeSeguro`, `descricaoSegura` (regex de campanha), `diasRestantes`; **sem** `mechanic`, `target_brl`, `progress_brl` |
| `BXNotificacao` | id, type, title, body, reference, is_read, created_at | `icone` pelo tipo, `corpoSeguro`; **sem** `icon` |
| `BXSessaoDispositivo` | id, device_name, ip_address, user_agent, created_at, last_used_at, current | `ipMascarado` |
| `BXEventoAcesso` | event, ip, device, status, reason, at | `rotulo` legível |
| `BXConsentimento` | id, type, version, accepted_at, status | `rotuloTipo` |
| `BXRespostaLogin` | — | `enum { case ok(BXTokens, BXUsuario), mfaSMS(desafio: String, dica: String?), mfaTOTP }` |

Datas: `BXFormato.iso8601`. Decodificação tolerante (campo opcional ausente não derruba a lista; item malformado é descartado com log em DEBUG).

#### 1.7.5 Rotas (`BXAPI+Rotas.swift`): a superfície completa

```swift
extension BXAPI {
    // Acesso
    func entrar(login: String, senha: String, mfa: String? = nil) async throws -> BXRespostaLogin   // POST /auth/login (aquecer)
    func entrar2FA(desafio: String, codigo: String) async throws -> (BXTokens, BXUsuario)          // POST /auth/login/2fa
    func entrarGoogle(idToken: String, nonce: String?) async throws -> (BXTokens, BXUsuario)       // POST /auth/google
    func cadastrar(_ c: BXCadastro) async throws -> (BXTokens, BXUsuario)  // POST /auth/register com accept_terms/privacy/lgpd = true
    func eu() async throws -> BXUsuario                                    // GET /auth/me
    func sair() async throws                                               // POST /auth/logout
    func esqueciSenha(email: String) async throws                          // POST /auth/forgot-password
    func redefinirSenha(token: String, senha: String) async throws         // POST /auth/reset-password {token, password, password_confirm}
    func trocarSenha(atual: String, nova: String) async throws             // POST /auth/change-password
    func enviarCodigoEmail() async throws -> Int                           // POST /auth/verify-email/send → expires_in_min
    func verificarEmail(codigo: String) async throws                       // POST /auth/verify-email
    // Segurança
    func sessoes() async throws -> [BXSessaoDispositivo]                   // GET /user/sessions
    func encerrarSessao(id: String) async throws                           // DELETE /user/sessions/<id>
    func encerrarTodasAsSessoes() async throws                             // POST /auth/sessions/revoke-all
    func historicoAcesso(limite: Int = 50) async throws -> [BXEventoAcesso]// GET /user/access-log?limit=
    func cadastrarCelular(_ tel: String) async throws -> String            // POST /user/phone → phone_masked
    func verificarCelular(codigo: String) async throws -> BXUsuario        // POST /user/phone/verify
    func removerCelular(senha: String) async throws                        // DELETE /user/phone
    func ligar2FASMS(senha: String) async throws; func desligar2FASMS(senha: String) async throws   // POST /user/2fa/sms/enable|disable
    func prepararTOTP() async throws -> (segredo: String, uri: String)     // POST /auth/mfa/setup
    func ligarTOTP(codigo: String) async throws                            // POST /auth/mfa/enable
    func desligarTOTP(senha: String, codigo: String) async throws          // POST /auth/mfa/disable
    // Privacidade
    func consentimentos() async throws -> [BXConsentimento]                // GET /privacy/consents
    func registrarConsentimento(tipo: String, versao: String) async throws // POST /privacy/consents
    func revogarConsentimento(id: String) async throws                     // DELETE /privacy/consents/<id>
    func exportarDados() async throws -> Data                              // GET /auth/account/export
    func excluirConta(senha: String?, googleIdToken: String?) async throws // DELETE /auth/account {…, confirm: "EXCLUIR MINHA CONTA"}
    // Carteira e cartão
    func carteira() async throws -> BXCarteira                             // GET /wallet/
    func lancamentos(limite: Int = 100) async throws -> [BXLancamento]     // GET /wallet/transactions?limit= (máx. 100, sem paginação)
    func cartao() async throws -> BXCartaoEstado                           // GET /card/
    func niveis() async throws -> [BXNivel]                                // GET /card/tiers
    func passeDisponivel() async throws -> Bool                            // GET /card/pass/status
    func passe() async throws -> Data                                      // GET /card/pass
    // Compra
    func pacotes() async throws -> [BXPacote]                              // GET /pix/packages (checa status!)
    func provedorPix() async throws -> BXProvedorPix                       // GET /pix/provider
    func criarCobrancaPix(pacote: String) async throws -> BXCobrancaPix    // POST /pix/charge {package} (aquecer)
    func criarCobrancaPix(valor: Decimal) async throws -> BXCobrancaPix    // POST /pix/charge {amount_brl}
    func cobrancaPix(id: String) async throws -> BXCobrancaPix             // GET /pix/charge/<id>
    func minhasCobrancasPix() async throws -> [BXCobrancaPix]              // GET /pix/my-charges
    func configCartao() async throws -> BXConfigCartao                     // GET /payments/card/config
    func cobrarCartao(_ p: BXPedidoCartao, chave: BXChaveIdempotencia) async throws -> BXCobrancaCartao   // POST /payments/card/charge
    func cobrancaCartao(id: String) async throws -> BXCobrancaCartao       // GET /payments/card/charge/<id>
    func minhasCobrancasCartao() async throws -> [BXCobrancaCartao]        // GET /payments/card/my-charges
    // Envio
    func enviar(_ p: BXPedidoEnvio, chave: BXChaveIdempotencia) async throws -> BXEnvio   // POST /transfer/ {to, amount_pts, password, message?, mfa_code?}
    func cancelarEnvio(id: String) async throws -> BXEnvio                 // POST /transfer/<id>/cancel
    // Descobrir
    func parceiros(categoria: String? = nil, busca: String? = nil) async throws -> [BXParceiro]   // GET /partners/
    func categoriasParceiros() async throws -> [String]                    // GET /partners/categories
    func parceiro(id: String) async throws -> BXParceiroDetalhe            // GET /partners/<id>
    func beneficios(categoria: String? = nil, parceiroID: String? = nil) async throws -> [BXBeneficio]   // GET /benefits/
    func beneficio(id: String) async throws -> BXBeneficio                 // GET /benefits/<id>
    func resgatarBeneficio(id: String, chave: BXChaveIdempotencia) async throws -> BXVoucher   // POST /benefits/<id>/redeem
    func vouchers() async throws -> [BXVoucher]                            // GET /vouchers/
    func voucher(id: String) async throws -> BXVoucher                     // GET /vouchers/<id>
    func campanhas() async throws -> [BXCampanha]                          // GET /campaigns/
    func participar(campanha id: String) async throws                      // POST /campaigns/<id>/join
    // Notificações e push
    func notificacoes() async throws -> (itens: [BXNotificacao], naoLidas: Int)   // GET /notifications/
    func contagemNaoLidas() async throws -> Int                            // GET /notifications/unread-count
    func marcarLida(id: String) async throws                               // PATCH /notifications/<id>/read
    func marcarTodasLidas() async throws                                   // POST /notifications/read-all
    func registrarDispositivo(token: String) async throws -> String        // POST /push/devices/register {token, platform:"ios", app_version}
    func removerDispositivo(id: String) async throws                       // DELETE /push/devices/<id>
    // Só DEBUG
    func simularPagamento(cobranca id: String) async throws                // POST /pix/simulate-payment (404 em produção)
}
```

Não existem e **não devem ser chamados**: `PATCH /user/profile`, `PATCH /user/password`, `/auth/logout-all`, `/auth/resend-verification`, `POST /auth/account/delete`, `POST /auth/dev/verify-email`, `POST /campaigns/<id>/progress`, `/redeem/*` (D03).

#### 1.7.6 Sanitizador (`BXSanitizador.swift`, `nonisolated enum`)

```swift
static func textoSeguro(_ s: String?) -> String?          // nil se casar com /parceiro\s+livelo|fict[ií]ci|\bpix\b|a\s+cada\s+R\$|pts?\s*\/\s*R\$/i,
                                                          // ou vazio; tira emoji e símbolos (★ ✓ ✦ 💸 …)
static func textoCampanhaSeguro(_ s: String?) -> String?  // nil se casar com /R\$|\/\s*R\$|\bpix\b/i
static func ehFicticio(descricao: String?) -> Bool        // /fict[ií]ci/i  → parceiro escondido em TODAS as builds
static func categoriaCanonica(_ c: String?) -> String     // mapa CANON de WEB/parceiros.html:420-433
static func icone(categoriaParceiro: String, nome: String) -> BXIconeNome   // ICONE_CAT de WEB/parceiros.html:435-452 (+ regra do hotel)
static func icone(categoriaBeneficio: String) -> BXIconeNome   // voucher→voucher, desconto→tag, assinatura→filme, sorteio→estrela,
                                                               // social→indique, educacao→documento, experiencia→festa, viagem→aviao, produto→resgates
static func rotulo(categoriaBeneficio: String) -> String  // Voucher, Desconto, Assinatura, Sorteio, Social, Educação, Experiência, Viagem, Produto
static func icone(tipoNotificacao: String) -> BXIconeNome // purchase→comprar, transfer→trocar, expiration→relogio, campaign→campanhas,
                                                          // system→info, redeem→resgates, voucher→voucher, outro→notificacoes
static func rotulo(tipo: BXTipoLancamento, descricao: String?) -> String
//   purchase "Compra de pontos" · transfer_out "Pontos enviados" · transfer_in "Pontos recebidos"
//   (descrição começando com "Reversão de envio" → "Envio desfeito") · redeem "Resgate de benefício" · refund "Estorno"
//   bonus "Bônus" · expire "Pontos expirados" · accrual "Pontos acumulados"
static func mensagemServidor(_ s: String, contexto: Contexto) -> String   // resgate: "PIX" → "transferência"; tira dica técnica
static func normalizar(_ s: String) -> String             // minúsculas, sem acento (busca)
static func cidade(daBusca q: String) -> String?          // mapa CIDADES de WEB/parceiros.html (aviso "Rede em expansão nesta cidade")
```

#### 1.7.7 Navegação (`BXNavegacao.swift`)

```swift
enum BXAba: String, CaseIterable, Hashable, Sendable { case inicio, carteira, comprar, resgates }   // "Menu" não é aba: abre a gaveta
enum BXGrupo { case acesso, saldo, movimentar, descobrir, conta }
enum BXFiltroExtrato: Hashable { case tudo, entradas, saidas }
enum BXAbaResgates: Hashable { case catalogo, meusResgates }

enum BXDestino: Hashable {
    // G2 Saldo
    case inicio, carteira, extrato(BXFiltroExtrato = .tudo), cartaoBlaxx, notificacoes
    // G3 Movimentar
    case comprar(pacote: String? = nil), historicoCompras, enviar(para: String? = nil), receber
    // G4 Descobrir
    case parceiros(busca: String? = nil), parceiro(id: String), resgates(BXAbaResgates = .catalogo),
         beneficio(id: String), voucher(id: String), campanhas
    // G5 Conta
    case perfil, seguranca, privacidade, convidar, ajuda, faq
    var grupo: BXGrupo { get }
    var aba: BXAba? { get }          // inicio, carteira, comprar, resgates → troca de aba; o resto empilha
    var exigeLogin: Bool { get }     // públicos: parceiros, parceiro, resgates(.catalogo), beneficio, campanhas, ajuda, faq
}

@MainActor @Observable final class BXNavegacao {
    var aba: BXAba = .inicio
    var pilhas: [BXAba: [BXDestino]] = [:]          // a casca liga NavigationStack(path:) a pilhas[aba]
    var pilhaVisitante: [BXDestino] = []
    var gavetaAberta = false
    var pedidoVerificacaoEmail = false              // a casca apresenta a verificação (G1)
    var destinoAposEntrar: BXDestino?               // deep link ou ação de visitante que exige login
    func ir(_ d: BXDestino)                         // com aba: troca e volta à raiz (e empilha se não for a raiz); sem aba: empilha
    func voltar(); func voltarParaRaiz(); func abrirGaveta(); func fecharGaveta()
    func exigirVerificacaoEmail()                   // chamar ao receber BXErro.tipo == .emailNaoVerificado
    func pedirEntrada(depois d: BXDestino?)         // visitante tocou em algo que exige conta
    func abrirSite(_ caminho: String)               // SFSafariViewController para https://blaxxpontos.com.br/<caminho>
}
```

Injeção: a casca cria uma `BXNavegacao`, uma `BXSessao`, um `BXToastCentral` e um `BXConectividade`, e os põe no ambiente com `.environment(_:)`. Telas leem com `@Environment(BXNavegacao.self)` etc.

#### 1.7.8 Sessão (`BXSessao.swift`)

```swift
@MainActor @Observable final class BXSessao {
    enum Estado: Equatable { case iniciando, visitante, logado }
    private(set) var estado: Estado = .iniciando
    private(set) var usuario: BXUsuario?
    private(set) var carteira: BXCarteira?
    private(set) var carteiraDoCache = false        // selo "SALDO DO ÚLTIMO ACESSO"
    private(set) var naoLidas = 0
    var emailVerificado: Bool { get }
    func iniciar() async                            // cofre → GET /auth/me → carteira; demo → usuário de exemplo
    func entrar(login: String, senha: String, mfa: String?) async -> Result<BXRespostaLogin, BXErro>
    func concluir2FASMS(desafio: String, codigo: String) async throws
    func entrarComGoogle() async throws             // GoogleAuthService.shared.signIn() → POST /auth/google
    func cadastrar(_ c: BXCadastro) async throws
    func recarregarCarteira() async; func recarregarUsuario() async; func atualizarNaoLidas() async
    func sair() async                               // POST /auth/logout (best effort), remove dispositivo de push, limpa cofre,
                                                    // BXCacheCarteira, TokenStore/WalletCache antigos, favoritos NÃO (são do aparelho)
    func sessaoRevogada(motivo: String)             // depois de trocar senha / encerrar todas / excluir conta → visitante + toast
}
```

Sem login silencioso, sem conta demo embutida (a de `RewardsBackend.swift:266-271` não é portada), sem `/auth/dev/verify-email`.

#### 1.7.9 Conectividade (`BXConectividade.swift`)

`@Observable` com `NWPathMonitor` + contador de falhas seguidas que o `BXAPI` alimenta. Faixa offline aparece depois de 3 falhas seguidas ou sem caminho de rede; `verificar()` faz `GET /health`; tenta a cada 30 s por até 5 min (igual ao web).

### 1.8 Esqueletos entregues aos grupos

O G0 cria estes quatro arquivos com o conteúdo mínimo abaixo. Daí em diante cada um pertence ao grupo indicado, que o reescreve. Assim a casca (G1) compila desde o primeiro dia e cada grupo compila sem esperar os outros.

```swift
// R/Telas/Saldo/BXTelasSaldo.swift            → dono G2
@MainActor enum BXTelasSaldo {
    @ViewBuilder static func tela(_ destino: BXDestino) -> some View { BXEstadoVazio(icone: .info, titulo: "Em construção") }
}
// R/Telas/Movimentar/BXTelasMovimentar.swift  → dono G3   (mesma forma: enum BXTelasMovimentar)
// R/Telas/Descobrir/BXTelasDescobrir.swift    → dono G4   (enum BXTelasDescobrir)
// R/Telas/Conta/BXTelasConta.swift            → dono G5   (enum BXTelasConta)
```

Se a fundação tiver ficado restrita a `R/Embarque/` e algum esqueleto não existir, **o grupo dono cria o seu como primeira ação**, antes de qualquer outra coisa, exatamente com a forma acima (o G1 depende dos quatro para compilar a casca).

Contrato: cada `tela(_:)` resolve todos os destinos do seu grupo (§1.7.7) e devolve a view **sem** `NavigationStack` próprio (a casca já tem um por aba) e **sem** barra de topo (a casca aplica `.bxBarraTopo`). Telas internas do grupo (sheets, passos) ficam dentro do grupo.

### 1.9 Pronto quando (G0)

- Build Debug ok em `SCRATCH/dd-g0`, zero aviso nos arquivos novos.
- Build Release ok (`-configuration Release`, `SCRATCH/dd-g0-rel`) e `strings` do binário sem `BXTransporteDemo`, sem nomes dos dados de exemplo (§4.2).
- Fotos `DOCS/fotos-ios-depois/G0-01-icones.png` e `G0-02..n-componentes-*.png` (`-BXDemo YES -BXTela icones|componentes`), comparadas com `fotos-web/90-tabbar-logado.png`, `93-topo-logado.png`, `95-icones-folha.png`, `01-home-visitante-01/04/05.png`.
- App continua abrindo o mundo antigo (o G0 não mexe em `ContentView`).

---

## 2. Paridade tela a tela

### 2.1 Tabela web mobile → app

Legenda de situação: **igual** (existe e já serve), **diferente** (existe, muda), **falta** (não existe no app vivo), **não levar**.

| # | Web mobile (arquivo) | App hoje (árvore viva) | Situação | No app novo | O que muda |
|---|---|---|---|---|---|
| 1 | `home-embarque.html` (visitante) | `RewardsLoginView` (portão de mentira) | diferente | G1 · `BXBoasVindasTela` | Cartão de embarque com letreiro, rota "Como funciona", pacotes em bilhetes + recibo (`GET /pix/packages`, 4 pacotes), painel de partidas com quadro preto, convite, rodapé-recibo. Botões levam a Entrar/Criar conta de verdade. |
| 2 | `login.html` | campos ignorados (`RewardsLoginView.swift:135,147,171`) | diferente | G1 · `BXEntrarTela` + `BXCodigo2FATela` | Login real e-mail/CPF + senha, 2FA SMS (`/auth/login/2fa`) e TOTP (`mfa_code`), 423/429 tratados, "Esqueci a senha", Google (D10). Some o "Entrar com Face ID" falso. |
| 3 | `cadastro.html` (3 passos) | não há | falta | G1 · `BXCadastroTela` | `POST /auth/register` com os 3 aceites (hoje o `register` do app falha sempre). |
| 4 | `recuperar-senha.html` | não há | falta | G1 · `BXRecuperarSenhaTela` | `POST /auth/forgot-password`, resposta sempre genérica. |
| 5 | `redefinir-senha.html` | `ResetPasswordView` (deep link, visual antigo) | diferente | G1 · `BXRedefinirSenhaTela` | Mesmo deep link `blaxxpontos://redefinir-senha?token=`, visual Embarque, `password_confirm`. |
| 6 | modal de verificação de e-mail | `EmailVerifyGate` (só Release, "Sair" não sai) | diferente | G1 · `BXVerificarEmailTela` | Não bloqueia o app inteiro: faixa no Início + sheet quando uma ação devolve 403 `EMAIL_NOT_VERIFIED` e logo após o cadastro. Vale em Debug e Release. |
| 7 | barra do topo, barra de abas, gaveta | `RWTabBar` (4 abas SF Symbols + FAB Trocar), área logada própria | diferente | G1 · `BXCasca`, `BXGavetaMenu` | Barra preta com wordmark, sino neon e avatar; abas Início · Carteira · Comprar · Resgates · Menu com quadrados neon; gaveta pela esquerda. Sem hambúrguer no topo do logado (a aba Menu já faz isso; diferente de propósito). |
| 8 | faixa offline, toast | não há | falta | G1 hospeda (`BXFaixaOffline`, `bxToastHost` do G0) | — |
| 9 | `dashboard.html` | `RewardsHomeView` (saldo em R$, sparkline) | diferente | G2 · `BXInicioTela` | Saldo em pontos (nunca R$), nível real de `/card/`, atalhos, campanhas (D04), últimas movimentações em recibo. Nada de "Plano Plus/Prime", meta 100.000 ou campanhas fixas do web. |
| 10 | `carteira.html` | `RewardsWalletView` (5 programas mock, patrimônio R$, gráfico) | diferente | G2 · `BXCarteiraTela` | Saldo Space Mono neon sobre preto, em processamento, nível; sem gráfico, sem "a expirar" inventado. |
| 11 | `extrato.html` | `RWStatementView` (descrição crua) | diferente | G2 · `BXExtratoTela` | Rótulo pelo tipo, ícone neon com seta, grupos por dia, Tudo/Entradas/Saídas, busca, erro com "Tentar de novo". |
| 12 | `detalhe-transacao.html` (fixa) | não há | falta | G2 · `BXLancamentoSheet` | Detalhe real do lançamento (sheet), "Desfazer envio" dentro de 60 s. |
| 13 | `cartao.html` | `RWCardView` (wordmark em `Text`) | diferente | G2 · `BXCartaoBlaxxTela` | Paleta local de nível, Apple Wallet nativo (`/card/pass`), lista de níveis sem `perks`. |
| 14 | `central-notificacoes.html` | `RWNotificationsView` | diferente | G2 · `BXNotificacoesTela` | Ícone pelo tipo, corpo filtrado, Todas/Não lidas, badge no sino. |
| 15 | `comprar-pontos.html`, `comprar.html`, `comprar-livre.html` | `RewardsBuySheet` | diferente | G3 · `BXComprarTela`, `BXValorLivreSheet`, `BXPagamentoPixSheet`, `BXCompraConcluidaTela` | Uma tela só: bilhetes + recibo; valor livre sem prévia de pontos; QR + copia e cola + contagem de expiração; "PIX indisponível" honesto (D01); cartão atrás de D02. |
| 16 | `checkout`, `pagamento-pix`, `pagamento-cartao`, `compra-aprovada` | — | não levar | — | Conteúdo fixo; o fluxo real é o da linha 15. |
| 17 | (sem página) | não há | falta | G3 · `BXHistoricoComprasTela` | `GET /pix/my-charges` (+ cartão se D02); reabrir QR pendente. |
| 18 | `enviar.html`, `enviar-pontos.html`, `confirmar-envio.html`, `envio-concluido.html` | `RewardsTransferSheet` (real, falha em Release) + aba `RewardsSendView` (mock) | diferente | G3 · `BXEnviarTela`, `BXConfirmarEnvioSheet`, `BXEnvioConcluidoTela` | Senha digitada na hora (nunca guardada), atalhos 500/1.000/5.000/10.000/Tudo, `Idempotency-Key`, desfazer em 60 s, 409/429/2FA, comprovante compartilhável, leitura de QR do Cartão BlaXx. Sem linha de taxa. |
| 19 | `receber-pontos.html` (fixa, inventada) | não há | falta | G3 · `BXReceberTela` | QR e código do Cartão BlaXx gerados no aparelho (aceito por `/transfer/`). Nada do conteúdo fixo do web. |
| 20 | `venda-pontos.html` (B2B) | não há | não levar | — | Landing comercial sem backend (D17). |
| 21 | `vender-pontos.html` / `resgate-pix.html` (resgate por transferência) | `RewardsSellSheet` ("Resgatar via PIX", R$) | não levar (por ora) | — | Viola as regras; D03. |
| 22 | `parceiros.html` | `RewardsPartnersView` (mock, "+120% bônus", R$) | diferente | G4 · `BXParceirosTela` | 266 reais sanitizados, busca sem acento, pílulas de categoria canônica, favoritos no aparelho, campanhas (D04), rota "Como usar". |
| 23 | `detalhe-parceiro.html` | não há | falta | G4 · `BXParceiroTela` | Cartão do parceiro, bilhetes de benefício, ficha em recibo. |
| 24 | `resgates.html` | `RWBenefitsView` (emoji, parceiro fictício) | diferente | G4 · `BXResgatesTela` | Abas Catálogo · Meus resgates, categorias com acento, ícone por categoria. |
| 25 | `beneficio-detalhe`, `confirmar-resgate`, `resgate-concluido` (fixas) | resgate direto no cartão | falta (fluxo) | G4 · `BXBeneficioTela`, `BXConfirmarResgateSheet`, `BXResgateConcluidoTela` | Fluxo detalhe → confirmar → concluído com dados reais e `Idempotency-Key`. |
| 26 | `meus-resgates.html`, `detalhe-voucher.html` (fixas) | aba "Meus vouchers" | diferente | G4 · aba de `BXResgatesTela` + `BXVoucherTela` | `GET /vouchers/` e `/vouchers/<id>`; filtros Ativos/Usados/Expirados. |
| 27 | `saldo-insuficiente.html` | texto no botão | diferente | G4 · estado dentro de `BXBeneficioTela` | "Faltam N pts" + barra + "Comprar pontos" → `.comprar()`. |
| 28 | `campanhas.html` | `RWCampaignsView` ("x% de R$ alvo") | diferente | G4 · `BXCampanhasTela` | Só percentual (sem meta em R$), sem `mechanic`; D04. |
| 29 | `perfil.html` | `RWProfileView` ("Chave PIX", exclusão quebrada) | diferente | G5 · `BXPerfilTela` | Só leitura (não existe edição no backend), sem chave PIX, sair de verdade. |
| 30 | `seguranca.html` | `RWSecurityView` (só troca de senha) | diferente | G5 · `BXSegurancaTela` (+ sheets) | Sessões e histórico reais, 2FA TOTP e SMS, encerrar todas. Nada dos números fixos do web. |
| 31 | (exclusão/LGPD) | exclusão no Perfil sem `confirm` | diferente | G5 · `BXPrivacidadeTela` | Consentimentos, exportar dados, excluir conta correto (exigência da App Store 5.1.1(v)). |
| 32 | `indique.html`, `indique-ganhe.html` | `RWReferralView` | diferente | G5 · `BXConvidarTela` | Só compartilhar convite, sem prometer pontos (D06). |
| 33 | `central-ajuda.html`, FAQ, abrir chamado | `RWHelpView`, `RWFaqView`, `RWTicketView` | diferente | G5 · `BXAjudaTela`, `BXFaqTela`, `BXChamadoSheet` | Sem PIX no resgate, sem "Quanto vale um ponto". |
| 34 | — | Trocar, Oferta, Programa, aba Enviar mock | não levar | — | Mundo de câmbio entre companhias que o produto não tem. Desativado no §5.6. |

### 2.2 Funcionalidades que o app ganha (todas com backend real)

| Funcionalidade | Endpoint | Grupo |
|---|---|---|
| Login real + 2FA SMS/TOTP | `POST /auth/login`, `POST /auth/login/2fa` | G1 |
| Login com Google (D10) | `POST /auth/google` | G1 |
| Cadastro | `POST /auth/register` | G1 |
| Esqueci / redefinir senha | `POST /auth/forgot-password`, `POST /auth/reset-password` | G1 |
| Verificação de e-mail | `POST /auth/verify-email/send`, `POST /auth/verify-email` | G1 |
| Sessão que se renova e sair de verdade | `POST /auth/refresh`, `POST /auth/logout` | G0 |
| Badge de notificações | `GET /notifications/unread-count` | G0 + G1 |
| Push só depois do login (D12) | `POST /push/devices/register`, `DELETE /push/devices/<id>` | G1 |
| Nível real + Apple Wallet | `GET /card/`, `/card/tiers`, `/card/pass/status`, `/card/pass` | G2 |
| Detalhe de lançamento + desfazer envio | `GET /wallet/transactions`, `POST /transfer/<id>/cancel` | G2 |
| Compra livre | `POST /pix/charge {amount_brl}` | G3 |
| Compra por cartão (D02) | `GET /payments/card/config`, `POST /payments/card/charge`, `GET /payments/card/charge/<id>` | G3 |
| Histórico de compras | `GET /pix/my-charges` (+ `/payments/card/my-charges`) | G3 |
| Envio com idempotência, desfazer, 2FA | `POST /transfer/`, `POST /transfer/<id>/cancel` | G3 |
| Receber por QR | sem endpoint (Cartão BlaXx é destino aceito por `/transfer/`) | G3 |
| Parceiros reais, detalhe, categorias | `GET /partners/`, `/partners/<id>`, `/partners/categories` | G4 |
| Favoritos de parceiros | local (UserDefaults), como no web | G4 |
| Detalhe de benefício, resgate idempotente, voucher | `GET /benefits/<id>`, `POST /benefits/<id>/redeem`, `GET /vouchers/<id>` | G4 |
| Campanhas e participação (D04) | `GET /campaigns/`, `POST /campaigns/<id>/join` | G4 |
| Sessões, histórico de acesso, encerrar todas | `GET /user/sessions`, `DELETE /user/sessions/<id>`, `GET /user/access-log`, `POST /auth/sessions/revoke-all` | G5 |
| Celular + 2FA por SMS | `POST /user/phone`, `/user/phone/verify`, `DELETE /user/phone`, `POST /user/2fa/sms/enable|disable` | G5 |
| 2FA por aplicativo (TOTP) | `POST /auth/mfa/setup|enable|disable` | G5 |
| Consentimentos, exportação, exclusão | `GET/POST/DELETE /privacy/consents`, `GET /auth/account/export`, `DELETE /auth/account` | G5 |

**Sem backend, ficam fora ou como texto honesto:** edição de perfil (Perfil diz "Para alterar seus dados, fale com o suporte"), prévia do nome do destinatário, lista de envios, paginação do extrato (máx. 100), chamados de suporte (vira e-mail), indicação com recompensa, sinal de "PIX disponível" (pedidos ao backend em D18).

### 2.3 Mapa de navegação do app novo

```
BlaxxPontosApp → ContentView → BXRaiz (G1)
├─ sessao.estado == .iniciando → tela de abertura (wordmark sobre tinta)
├─ .visitante → BXVisitanteCasca: NavigationStack(pilhaVisitante) raiz BXBoasVindasTela
│    topo: wordmark · "Entrar" · hambúrguer → gaveta pela DIREITA
│    gaveta: [Criar conta] [Entrar] · CONHEÇA Comprar pontos (→ Entrar) · Como funciona · Parceiros · Regulamento (site)
│            · AJUDA Central de ajuda · Perguntas frequentes · Fale conosco
│    destinos públicos empilham; os que exigem login → Entrar → segue para o destino
└─ .logado → BXCasca: TabView(selection) com barra do sistema escondida + BXTabBar
     Início(G2) · Carteira(G2) · Comprar(G3) · Resgates(G4) · Menu → gaveta pela ESQUERDA
     cada aba: NavigationStack(path: pilhas[aba]) · navigationDestination(BXDestino) → BXRoteador → BXTelas<Grupo>.tela
     topo: wordmark/voltar · BXSino (→ .notificacoes) · BXAvatar (→ .perfil)
     gaveta: CONTA Início, Carteira, Extrato, Cartão BlaXx, Perfil · PONTOS Comprar pontos, Enviar pontos,
             Receber pontos, Resgatar benefícios, Convidar amigos (D06) · DESCOBRIR Parceiros, Campanhas (D04)
             · AJUDA Central de ajuda, Perguntas frequentes, Abrir chamado · [Sair]
     sheets globais: BXVerificarEmailTela (pedidoVerificacaoEmail)
     sobreposições: BXFaixaOffline acima da barra de abas, toasts no topo
Deep links (G1): blaxxpontos://redefinir-senha?token=… · blaxxpontos://enviar?para=<CARTAO>
```

---

## 3. "Incremente o design": o iOS acima do web, dentro da marca

### 3.1 Regras gerais (todas as telas)

1. **Háptica** (via `.sensoryFeedback` ou `BXHaptica`): `.selection` em troca de aba, pílula, aba segmentada e bilhete; `.success` em compra paga, envio feito, resgate feito, e-mail verificado, senha alterada, participação em campanha; `.warning` em saldo insuficiente, envio repetido (409) e 2FA pedido; `.error` em falha definitiva; `.impact(.light)` ao copiar código e ao favoritar. Nunca em rolagem, nunca em carregamento.
2. **Transições**: empilhamentos que partem de um cartão usam `.navigationTransition(.zoom(sourceID:in:))` + `.matchedTransitionSource(id:in:)` (cartão de parceiro → detalhe; bilhete de benefício → detalhe; voucher → detalhe; cartão de saldo da Carteira → Cartão BlaXx). Dentro da mesma tela, `matchedGeometryEffect` no fundo ativo de `BXAbas`, nas pílulas e no visto do bilhete selecionado. Tudo cai para `.opacity` com Reduzir Movimento.
3. **Puxar para atualizar** (`.refreshable`) em Início, Carteira, Extrato, Cartão, Notificações, Parceiros, Resgates (as duas abas), Campanhas, Histórico de compras, Segurança. Toque duplo na aba ativa volta para a raiz e rola para o topo.
4. **Esqueletos** no primeiro carregamento (nunca spinner solto de tela inteira); recarregar mantém o conteúdo e mostra só o indicador do `refreshable`.
5. **Números**: saldo, pontos do recibo e contadores com `BXNumeroAnimado` (`numericText`). Mudança de seleção de pacote anima "PONTOS NA CONTA".
6. **Sheets com detents** (`.presentationDetents`, `.presentationCornerRadius(24)`, `.presentationBackground(BXCor.superficie)`, `.presentationDragIndicator(.visible)`) para passos curtos: detalhe de lançamento `[.medium, .large]`, "Mais categorias" `[.medium]`, confirmar envio `[.medium]`, confirmar resgate `[.medium]`, valor livre `[.medium, .large]`, pagamento PIX `[.large]` com `interactiveDismissDisabled` enquanto pendente (fechar pede confirmação), troca de senha e TOTP `[.large]`.
7. **Dynamic Type** até AX5: todas as fontes por `bxFonte`; grades 2 × 2 viram 1 coluna em tamanhos de acessibilidade; canhoto do bilhete mantém 56 pt e o miolo cresce; barra de abas limitada a `.xxLarge` com Large Content Viewer. Uma foto em `accessibility-extra-extra-extra-large` por grupo.
8. **VoiceOver**: cartão de embarque, bilhete e recibo agrupados em elementos com rótulo natural ("Saldo, 32.480 pontos"; "Pacote Plus, 5.500 pontos, tarifa 470 reais, selecionado"); decorativos (código de barras, picote, serrilha, pontilhado) ocultos; rótulos MAIÚSCULOS com `accessibilityLabel` em caixa normal; "pts" lido como "pontos"; ações extras por `accessibilityAction(named:)` (Favoritar, Copiar código, Desfazer envio); toasts anunciados; títulos de tela com `.accessibilityAddTraits(.isHeader)`.
9. **Área segura**: barra preta do topo cobre a status bar (ícones claros); barra de abas inclui a área inferior; CTAs fixos com `.safeAreaInset(edge: .bottom)`; teclado com `.scrollDismissesKeyboard(.interactively)` e CTA acima do teclado.
10. **Movimento reduzido**: letreiro parado, brilho de esqueleto parado, contagem de saldo sem rolar, transições em opacidade.
11. **Teclado e preenchimento automático**: `textContentType` certo em todo campo (§1.6.9), `submitLabel` e `@FocusState` encadeando campos, código de 6 dígitos com `.oneTimeCode`.
12. **Menus de contexto** (toque longo): cartão de parceiro (Favoritar, Ver benefícios), voucher (Copiar código), lançamento (Copiar comprovante), Cartão BlaXx (Copiar número).
13. **Modo escuro**: não (decidido em §1.1).

### 3.2 Por tela

| Tela | Incremento concreto |
|---|---|
| Boas-vindas (G1) | Letreiro "Novos destinos / sonhos / aventuras" com `.push(from: .bottom)`; tocar num bilhete reescreve o recibo com `numericText` e háptica `.selection`; quadro preto rola por dentro e a linha tocada vira neon; rodapé-recibo no fim. Opcional (se sobrar tempo, nunca com marca de terceiro): globo `Map` com `.mapStyle(.imagery(elevation: .realistic))` e alfinetes neon das cidades do quadro, girando devagar sem Reduzir Movimento. |
| Entrar / Cadastro (G1) | Barra de 3 passos animada; erro do campo com `.sensoryFeedback(.error)` e foco no campo; senha com checklist da política vindo de `issues`; código 2FA colado de uma vez; "Mostrar senha". |
| Casca (G1) | Troca de aba com `.selection`; toque duplo volta à raiz; gaveta arrastável com scrim que escurece proporcional ao arrasto; sino com contagem animada. |
| Início (G2) | Saldo com contagem; selo "SALDO DO ÚLTIMO ACESSO" quando veio do cache; cartão de saldo como cartão de embarque com picote; campanhas em carrossel `.scrollTargetBehavior(.viewAligned)` com páginas; faixa "Confirme seu e-mail" que some com animação ao verificar. |
| Carteira (G2) | Cartão de saldo preto com saldo Space Mono neon; toque no nível → Cartão BlaXx com zoom. |
| Extrato (G2) | Cabeçalhos de dia fixos (`pinnedViews: .sectionHeaders`); busca com debounce; linha → sheet de detalhe; "Desfazer envio" com contagem regressiva. |
| Cartão BlaXx (G2) | Face do cartão com leve inclinação 3D ao arrastar (`rotation3DEffect`, sem Reduzir Movimento); `PKAddPassButton` nativo; trilho de progresso animado na entrada. |
| Notificações (G2) | Deslizar para marcar como lida (`swipeActions`); bolinha de não lida some com `.scale`; toque abre o destino da notificação. |
| Comprar (G3) | Bilhete selecionado com borda e canhoto neon em `matchedGeometryEffect`; recibo atualiza com `numericText`; QR em sheet `.large` com brilho da tela no máximo enquanto aberto (restaurado ao fechar); contagem de expiração "29:41"; polling pausado em segundo plano; pago → háptica `.success` e recibo "PONTOS NA CONTA". |
| Enviar (G3) | Atalhos de pontos com `.selection`; botão "Ler QR" (VisionKit `DataScannerViewController`) para o Cartão BlaXx; confirmação em sheet `.medium`; concluído com contagem "Desfazer (59 s)" e depois "Efetivado"; compartilhar comprovante como imagem. |
| Receber (G3) | QR grande nítido, brilho máximo, `ShareLink` do código, copiar com háptica. |
| Parceiros (G4) | Busca sem acento com debounce 200 ms; carga contínua ao chegar no fim (o botão "Mostrar mais" fica para VoiceOver); coração com `.impact(.light)` e animação de escala; zoom para o detalhe. |
| Detalhe do parceiro (G4) | Título encolhe para caber (`minimumScaleFactor`); "Ver benefícios" rola até os bilhetes; bilhete → benefício com zoom. |
| Resgates / Benefício / Voucher (G4) | Barra "Faltam N pts"; confirmação em sheet; concluído com o código grande em mono, copiar com háptica; voucher com zoom a partir do cartão. |
| Campanhas (G4) | "Participar" com `.success` e troca animada para "EM ANDAMENTO"; barra de progresso animada. |
| Perfil / Segurança / Privacidade (G5) | Encerrar sessão com `swipeActions` + confirmação; TOTP com QR do `otpauth://` e botão "Abrir no app autenticador"; exclusão com digitação de "EXCLUIR" e botão perigo; exportação via `ShareLink`/`fileExporter`. |
| Ajuda (G5) | Busca local nas perguntas; perguntas em `DisclosureGroup` com estilo Embarque; chamado por `MFMailComposeViewController` (ou `mailto:`) já com versão do app e do iOS. |

---

## 4. Modo demonstração (só DEBUG)

### 4.1 Argumentos de lançamento

| Argumento | Efeito |
|---|---|
| `-BXDemo YES` | Sessão logada como "Cliente Demo", tudo respondido por `BXTransporteDemo` (zero rede). |
| `-BXDemoVisitante YES` | Visitante, com respostas públicas de exemplo (pacotes, parceiros, benefícios). |
| `-BXDemoEstado carregando\|vazio\|erro\|offline` | Força o estado: requisições nunca terminam / listas vazias / 500 / falha de rede (mostra a faixa offline). |
| `-BXTela <id>` | Abre direto num destino. Ids: `inicio carteira extrato cartao notificacoes comprar historico enviar receber parceiros parceiro:<id> resgates meusResgates beneficio:<id> voucher:<id> campanhas perfil seguranca privacidade convidar ajuda faq boasVindas entrar cadastro recuperar redefinir verificarEmail gaveta icones componentes`. |
| `-BXSubtela <nome>` | Abre um passo interno: `valorLivre pix pago confirmar concluido lancamento totp senha excluir 2fa maisCategorias`. Cada grupo lê `BXDemo.subtela` e abre o sheet/passo correspondente. |
| `-BXAncora <id>` | Rola até uma âncora (`.id("…")`) para fotografar a parte de baixo de telas longas. Cada grupo define as âncoras das suas telas. |

### 4.2 Arquitetura e garantias de Release

- `BXDemo.swift`, `BXTransporteDemo.swift`, `BXDemoDados.swift` e `BXCatalogoDS.swift` têm o arquivo inteiro dentro de `#if DEBUG … #endif`.
- `BXDemo.ativo` existe nas duas builds: em DEBUG lê `ProcessInfo.processInfo.arguments`; em Release é a constante `false`. Nenhum outro arquivo usa `#if DEBUG` para dados de exemplo; telas só leem `BXDemo.subtela`/`BXDemo.ancora` (que em Release são `nil`).
- `BXAPI.shared` escolhe `BXTransporteDemo` só em DEBUG com `-BXDemo`/`-BXDemoVisitante`. O transporte de demonstração **nunca** abre conexão: qualquer rota sem resposta definida devolve 404 local e loga em DEBUG.
- Em demo: `BXCofre` só em memória; push não registra; Google não abre; Apple Wallet devolve "indisponível".
- Estado em memória para os fluxos funcionarem nas fotos: compra paga credita o saldo; envio tira do saldo e põe em "em processamento", "Desfazer" devolve, depois de 60 s efetiva; resgate cria voucher e debita; marcar como lida zera a bolinha; participar muda a campanha.
- Verificação (G0 e G1, no fim): build Release em `SCRATCH/dd-<g>-rel`, depois
  `strings "<…>/Release-iphonesimulator/BlaxxPontos.app/BlaxxPontos" | grep -ciE "BXTransporteDemo|BXDemoDados|Mercado Aurora|cliente.demo@exemplo.test"` → **0**.

### 4.3 Dados de exemplo (`BXDemoDados.swift`)

Nomes inventados genéricos, sem marca real, sem "fictícia", sem "Livelo" visíveis. Algumas entradas são **armadilhas** de propósito (texto proibido) para provar que o sanitizador funciona: elas não podem aparecer em nenhuma foto.

| Endpoint | Conteúdo |
|---|---|
| `/auth/me` | id `de0a11c2-…` (Cartão `DE0A 11C2`), "Cliente Demo", `cliente.demo@exemplo.test`, CPF `00000000191` (mostra `***.***.001-**`), celular `+5511900000000`, e-mail verificado, `mfa_enabled:false`, `has_password:true`, `google_linked:false`, `is_vip:false`. Variante `-BXDemoEstado` não muda o usuário. |
| `/wallet/` | `balance_pts 32480`, `pending_pts 1000` (+ `balance_brl_equiv 2923.2` **armadilha**). |
| `/wallet/transactions` | 14 lançamentos em 10 dias cobrindo os 8 tipos e os 3 status: compra +5.500 (pacote plus), envio −1.000 pendente, recebido +2.000, resgate −353, bônus +500, estorno +120, expirados −200, acumulados +80, "Reversão de envio cancelado" +300; uma descrição "Resgate via PIX → chave" (**armadilha**). |
| `/card/`, `/card/tiers` | Ouro, acumulado 24.800, próximo Black, faltam 25.200, 49 %; níveis Bronze 0, Prata 5.000, Ouro 20.000, Black 50.000, BlaXx VIP (convite); `perks` com "PIX" e `text_color #C6FF00` (**armadilhas**); `wallet_pass_available:false`. |
| `/pix/packages` | Start 2.000 / R$ 180,00 · Plus 5.500 / R$ 470,00 · Prime 12.000 / R$ 972,00 · Black 28.000 / R$ 2.142,00 (valores atuais de produção). |
| `/pix/provider`, `/pix/charge`, `/pix/charge/<id>` | provider `demo`, `is_mock:true`; cobrança `demo-pix-1`, `br_code` de exemplo, `qr_code_image:null` (o app gera o QR), expira em 30 min; `pending` nas duas primeiras consultas e `paid` na terceira (`-BXSubtela pago` já começa pago). Com `-BXDemoEstado erro`, `POST /pix/charge` devolve o 400 do provedor indisponível. |
| `/payments/card/config` | `enabled:false`. |
| `/pix/my-charges` | 3 cobranças: paga, expirada, pendente. |
| `/transfer/`, `/transfer/<id>/cancel` | `ENV-2026-DEMO-00000001`, `status:pending`, `is_cancellable:true`, `committed_at` = agora + 60 s; destinatário `amigo@exemplo.test` ou `AB12CD34` aceito; senha qualquer não vazia; `to` = "repetido@exemplo.test" devolve 409 `DUPLICATE_SUSPECTED`; ≥ 20.000 pts devolve 401 `mfa_required`. |
| `/partners/` (24) | Mercado Aurora (Supermercado), Posto Rota Sul (Combustível), Farmácia Bem Viver (Farmácia), Drogaria Centro (Farmácias), Café Ponto Doce (Café), Padaria Trigo Bom (Alimentação), Cine Lumen (Streaming), Hotel Vila Serena (Viagens → ícone hotel), Rumo Viagens (Viagens), Ateliê Linha (Moda Plus → Moda), Passo Firme (Calçados), Studio Brilho (Beleza), Volt Eletrônicos (Tech → Eletrônicos), Conecta Telecom (Telecom), Casa Clara (Casa & Decoração → Casa), Pet Amigo (Pet), Livraria Página 9 (Educação), Energia Viva (Energia), Seguro Certo (Seguros), Loja Ponto Net (E-commerce), Sabor da Vila (Restaurantes), Ótica Clara (Acessórios), **"Loja Exemplo" com descrição "Loja fictícia usada nos exemplos"** (armadilha: tem de sumir da lista), **"Mercado Teste" com descrição "Parceiro Livelo · mercado-teste"** (armadilha: aparece, sem descrição). Todos com `accrual_rule` "2 pts/R$" e `logo_emoji` (armadilhas). |
| `/partners/<id>` | Café Ponto Doce com 2 benefícios; Hotel Vila Serena com 1; Volt Eletrônicos com 0 (estado "sem bilhete"). |
| `/benefits/` (9) | Café expresso duplo (Café Ponto Doce, voucher, 353, popular) · Desconto de 15 % em óculos (Ótica Clara, desconto, 1.200) · Mês de séries (Cine Lumen, assinatura, 2.400) · Sorteio de fim de ano (BlaXx, sorteio, 100) · Doação para projeto social (BlaXx, social, 500) · Curso online de fotografia (Livraria Página 9, educacao, 6.000) · Aula de escalada (Studio Brilho, experiencia, 4.500, **estoque 0**) · Diária em pousada (Hotel Vila Serena, viagem, **40.000**, saldo insuficiente) · um benefício da "Loja Exemplo" (armadilha: some junto com o parceiro). Todos com `image_emoji` (armadilha). |
| `/vouchers/` | 3: ativo `BX-7F3K-92QA` (Café expresso duplo, vence em 60 dias), usado, expirado. |
| `/campaigns/` | Boas-vindas BlaXx (+500, participando, 40 %) · Desafio de 3 compras (+1.000, não participando, faltam 12 dias) · Semana dos parceiros (+800, concluída). Uma com `mechanic` "A cada R$ 100 movimentados…" e `target_brl` (armadilhas). |
| `/notifications/` | 6 (purchase, transfer, voucher, campaign, system, expiration), 2 não lidas; uma com corpo "…liberar resgates PIX." (armadilha: corpo some) e `icon` "💸" (armadilha). |
| `/user/sessions` | iPhone · BlaXx iOS (atual), Safari · macOS (há 2 d), Chrome · Android (há 9 d); IP mascarado. |
| `/user/access-log` | 6 eventos: login ok, senha errada, troca de senha, novo dispositivo, logout, 2FA. |
| `/privacy/consents` | termos 1.0, privacidade 1.0, LGPD 1.0, marketing revogado. |

### 4.4 Roteiro de fotos

```
DD=SCRATCH/dd-<grupo>; SIM=29702B3D-53FF-44C6-810D-D665C7C7636A; BID=Blaxx-Pontos-Inc.BlaxxPontos
xcodebuild -project "<…>/BlaxxPontos.xcodeproj" -scheme BlaxxPontos -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD" build
xcrun simctl boot $SIM 2>/dev/null; xcrun simctl install $SIM "$DD/Build/Products/Debug-iphonesimulator/BlaxxPontos.app"
xcrun simctl launch --terminate-running-process $SIM $BID -BXDemo YES -BXTela parceiros [-BXAncora lista]
# aguardar ~2 s (Monitor/until, nunca sleep solto)
xcrun simctl io $SIM screenshot "DOCS/fotos-ios-depois/G4-01-parceiros.png"
# Dynamic Type: xcrun simctl ui $SIM content_size accessibility-extra-extra-extra-large … e voltar com: content_size large
```

Nome: `DOCS/fotos-ios-depois/<G>-<nn>-<tela>[-<estado>].png`. Cada grupo fotografa cada tela sua nos estados pronto, carregando, vazio e erro, mais uma foto em tamanho de acessibilidade, e compara com a foto web equivalente.

---

## 5. Grupos e donos de arquivo

### 5.0 Ordem

1. **G0** sozinho (fundação, §1). Termina com build Debug e Release verdes.
2. **G1, G2, G3, G4, G5 em paralelo.** Cada um só cria/edita arquivos da sua lista. Comunicação entre grupos só por `BXDestino`/`BXNavegacao` e pelos componentes do G0. Se um grupo precisar de algo no G0 (componente, campo de DTO, rota), anota no relatório final dele; ninguém edita o G0.
3. **G1 fecha**: troca `ContentView` para `BXRaiz` (pode ser cedo) e faz a desativação atômica do mundo antigo (§5.6), depois build Debug + Release + checagem de `strings`.

Pastas: o dono de uma pasta é dono de tudo o que estiver dentro dela, inclusive arquivos novos que criar ali.

### G1 · Acesso, casca e integração

**Arquivos (dono):** `R/Telas/Acesso/` (pasta), `R/Telas/Casca/` (pasta), `APP/ContentView.swift`, `APP/BlaxxPontosApp.swift`, `APP/Info.plist` (só acrescentar; preservar as fontes já registradas), `APP/Util/ProtectedSnapshot.swift`, `APP/Push/PushService.swift`, e os 18 arquivos antigos de `R/` (só para a desativação do §5.6): `EmailVerifyGate.swift`, `RewardsAccountViews.swift`, `RewardsActivityViews.swift`, `RewardsBackend.swift`, `RewardsCatalogViews.swift`, `RewardsComponents.swift`, `RewardsFinanceSheets.swift`, `RewardsHomeView.swift`, `RewardsLoginView.swift`, `RewardsModel.swift`, `RewardsOfferSheet.swift`, `RewardsPartnersView.swift`, `RewardsProgramSheet.swift`, `RewardsSendView.swift`, `RewardsShell.swift`, `RewardsTheme.swift`, `RewardsTradeSheet.swift`, `RewardsWalletView.swift`. Fotos `DOCS/fotos-ios-depois/G1-*`.

Arquivos novos sugeridos: `Acesso/BXBoasVindasTela.swift`, `BXPainelPartidasDados.swift` (lista do quadro portada de `WEB/home-embarque.html` e `WEB/assets/blaxx-globo.js`), `BXEntrarTela.swift`, `BXCodigo2FATela.swift`, `BXCadastroTela.swift`, `BXRecuperarSenhaTela.swift`, `BXRedefinirSenhaTela.swift`, `BXVerificarEmailTela.swift`; `Casca/BXRaiz.swift`, `BXCasca.swift`, `BXVisitanteCasca.swift`, `BXRoteador.swift`, `BXGavetaMenu.swift`.

**Telas**

1. **Boas-vindas** (foto web 01): barra utilitária (rola junto) · cartão de embarque ("CARTÃO DE EMBARQUE · BLAXX PONTOS" | "BRASIL · 2026"; capa "Seus pontos." + letreiro "Novos destinos/sonhos/aventuras." + marcadas "Compre. Ganhe." "Envie. Troque."; grade De Pontos · Para Benefícios · Pagamento Cartão ou transferência · Mensalidade Nenhuma; lead; canhoto Passageiro Você · Portão Cadastro · Assento Livre; CTA "Começar agora" → Cadastro; "Já tenho conta · Entrar →") · rota "ROTA · COMO FUNCIONA" (Compre, Ganhe, Envie, Troque, textos do web) · "Escolha o seu ponto de partida." com `BXBilhetePacote` × 4 de `GET /pix/packages` + recibo "EXTRATO DA SUA COMPRA" (Pacote, Pontos, Pagamento, Mensalidade nenhuma, TOTAL, faixa PONTOS NA CONTA, nota, via, ação "COMPRAR N PTS →" → `pedirEntrada(depois: .comprar(pacote:))`) · painel de partidas com `BXNumeroDestaque` + `BXQuadroPreto` (cidades do web; tocar mostra "Rede em expansão: ainda não há parceiros nesta cidade." ou "Ver parceiros →") · convite "CRIAR CONTA · SEM MENSALIDADE" (4 `BXCartaoClaro` + bloco preto "Pronto para embarcar?") · `BXRodapeRecibo`. Erro de pacotes: esqueleto → estado de erro com "Tentar de novo" (nunca lista vazia muda).
2. **Entrar**: cartão único "Bem-vindo de volta." · "E-MAIL OU CPF" · "SENHA" · "Esqueci a senha" · botão preto "Entrar →" · "OU" · Google (D10) · "Criar conta". Resultados de `BXSessao.entrar`: ok → destino pendente ou Início; `mfaSMS` → `BXCodigo2FATela` (dica do celular, código de 6 dígitos, `/auth/login/2fa`, erros `invalid_code`/`challenge_expired`); `mfaTOTP` → campo de código na mesma tela e reenvio com `mfa_code`; 401 "Credenciais inválidas" inline; 423 com horário; 429. Nunca guardar senha.
3. **Cadastro** (3 passos, barra de passos, "PASSO N DE 3"): Nome completo (2 palavras) + CPF (dígito verificador no aparelho) · E-mail + Celular opcional · Senha (checklist pelos `issues` do servidor) + aceite "Li e aceito os termos de uso, as regras de pontos e a política de privacidade (LGPD)" com os 3 links (site) → `accept_terms/privacy/lgpd = true`. Erro de CPF volta ao passo 1, de e-mail ao passo 2. Sucesso → logado + sheet de verificação de e-mail (o backend já mandou o código).
4. **Recuperar senha**: e-mail → sempre "Se este e-mail estiver cadastrado, enviamos as instruções de redefinição…".
5. **Redefinir senha** (deep link): nova senha + confirmação → `POST /auth/reset-password` → toast + Entrar.
6. **Verificar e-mail** (sheet): "Enviar código" (`/auth/verify-email/send`), `BXCampoCodigo`, reenviar com espera de 30 s, `attempts_left`, sucesso `.success` + `recarregarUsuario()`.
7. **Casca**: §2.3. `BXRaiz` aplica `.preferredColorScheme(.light)`, `.tint(BXCor.tinta)`, injeta ambiente, instala toasts e faixa offline, trata `BXDemo.telaInicial` e deep links (`redefinir-senha`, `enviar?para=`). `BXRoteador` resolve `BXDestino` por grupo (`BXTelasSaldo.tela`, …) e aplica `.bxBarraTopo`. Sino → `.notificacoes`; avatar → `.perfil`. Sessão expirada → visitante + toast "Sua sessão expirou. Entre de novo.".
8. **Gaveta** (logado e visitante, §2.3): grupos mono, itens 48 pt, item atual preto com texto superfície, "Sair" neon 50 pt com confirmação.
9. **Integração**: `ContentView.body` = `#if os(iOS) BXRaiz() #else legacyBody #endif`. `BlaxxPontosApp`: deep links acima; não pedir push no lançamento; `.protectedSnapshot()` mantido. `ProtectedSnapshot`: fundo `BXCor.tinta`, `BXWordmark(.barra, altura: 30)`, "Conteúdo protegido" papel, sem SF Symbol. `PushService`: pedir permissão e registrar só depois do login (`BXAPI.registrarDispositivo`), remover no sair. `Info.plist`: acrescentar `NSCameraUsageDescription` = "Ler o QR Code de um Cartão BlaXx para enviar pontos." (usado pelo G3).

**Violações do "antes" que o G1 remove** (refs de 01 §4/§7):
login que entra sem credencial (`RewardsLoginView.swift:135,147,171`) e "Entrar com Face ID" falso; header com símbolo + "REWARDS" em vez do wordmark da barra (`RewardsHomeView.swift:63-79`); tab bar com SF Symbols e FAB "Trocar" (`RewardsShell.swift:229-281`); folhas Trocar/Oferta/Programa e aba Enviar mock (mundo de câmbio, bônus +120 %/+8 %, contatos inventados, "Troca concluída!"); selo "Ambiente de homologação · PIX simulado · dados fictícios" (`RewardsFinanceSheets.swift:57` e usos); menu "Resgatar em dinheiro" (`RewardsAccountViews.swift:345`) e ícones cinza do menu (`:176-181`); conta demo com senha no código e login silencioso contra produção (`RewardsBackend.swift:67-94,266-271`); sair que não revoga nem limpa (`:258-264`) e "Sair" do portão que não sai (`EmailVerifyGate.swift:92-96`); status bar escura sobre fundo escuro e conteúdo sob a status bar (fotos 01 e 04); snapshot com preto legado `#0A0A0A` e texto "BlaXx Pontos" (`Util/ProtectedSnapshot.swift:34-42`); push registrado antes do login. Do web, não copiar: três pacotes só (a API tem quatro), "Entrar"/"Criar conta" que somem da barra sem alternativa.

**Pronto quando:** build Debug ok (`dd-g1`) sem aviso em arquivos do G1; fotos G1 de todas as telas acima (pronto/erro/carregando) + gaveta logada e visitante + uma em AX; fluxo demo visitante → Entrar → Início funciona; §5.6 concluído; build Release ok e `strings` = 0.

### G2 · Saldo: Início, Carteira, Extrato, Cartão BlaXx, Notificações

**Arquivos (dono):** `R/Telas/Saldo/` (pasta, inclui `BXTelasSaldo.swift`). Fotos `DOCS/fotos-ios-depois/G2-*`.
Sugeridos: `BXInicioTela.swift`, `BXCarteiraTela.swift`, `BXExtratoTela.swift`, `BXLancamentoSheet.swift`, `BXCartaoBlaxxTela.swift`, `BXAppleWallet.swift`, `BXNotificacoesTela.swift`, modelos `BX…Modelo.swift`.

**Destinos que resolve:** `.inicio`, `.carteira`, `.extrato`, `.cartaoBlaxx`, `.notificacoes`.

1. **Início** (`GET /wallet/` via `BXSessao`, `GET /card/`, `GET /wallet/transactions?limit=5`, `GET /campaigns/` se D04):
   chip `saudacao` "OLÁ, <PRIMEIRO NOME>" + "Bom te ver de volta." · faixa "Confirme seu e-mail para enviar e resgatar pontos" (só se não verificado → `exigirVerificacaoEmail`) · **cartão de embarque do saldo**: topo "CARTÃO BLAXX · DE0A 11C2" | "NÍVEL OURO"; miolo `BXNumeroAnimado(saldo, .numeroGrande, "pontos")` + grade Em processamento · Nível · Próximo nível · Progresso; canhoto Passageiro <nome> · Destino Benefícios; CTAs "+ Comprar pontos" (`.cartao`), "Enviar pontos", "Resgatar →" (secundários) · atalhos 2 × 2 `BXCartaoClaro`: Extrato "Veja todos os movimentos.", Enviar pontos "Para quem você quiser, entre contas BlaXx.", Receber pontos "Mostre o seu Cartão BlaXx.", Meus resgates "Seus vouchers e códigos." (textos sem números inventados) · Campanhas (bilhetes, D04) · "Últimas movimentações" como `BXRecibo(cabeca: "EXTRATO RECENTE")` com 5 linhas (data · rótulo · ±pts) + "Ver extrato completo →" · "Parceiros por categoria" com pílulas Postos/Supermercados/Farmácias → `.parceiros(busca:)`.
   Estados: esqueleto do cartão e do recibo; erro do saldo mostra "—" + `BXEstadoErro` no lugar do recibo; campanhas com erro mostram erro, não "nenhuma campanha".
2. **Carteira**: `BXCabecalhoPagina("CARTEIRA BLAXX", "Sua carteira.", "Tudo que entra e sai, em um lugar só.")` · cartão preto "SALDO" `BXNumeroAnimado(.saldoMono)` **neon sobre tinta** + "Nível Ouro · faltam 25.200 pts para Black" (de `/card/`) + botões "+ Comprar pontos" (primário), "Enviar pontos", "Receber", "Resgatar →" (vazados sobre preto) · cartão "EM PROCESSAMENTO" com chip preto e texto "Envios dos últimos 60 segundos. Você pode desfazer pelo extrato." · mini cartão do nível (zoom → `.cartaoBlaxx`) · "Ver extrato completo →".
3. **Extrato** (`GET /wallet/transactions?limit=100`): cabeçalho "EXTRATO" / "Cada ponto, rastreado." · números "Entradas no período" / "Saídas no período" (somados dos lançamentos carregados, rótulo honesto) e "Saldo atual" · `BXAbas` Tudo/Entradas/Saídas · `BXCampoBusca("Buscar movimento")` · seções por dia (`BXFormato.dia`) com cabeçalho fixo; linha = `BXIcone(.setaCima|.setaBaixo, .atalho)` + rótulo pelo tipo + hora + `BXStatus` se não confirmado + `±pts` (`okTexto`/`perigoTexto`) · rodapé "Mostrando os últimos 100 movimentos." Vazio "Nenhum movimento ainda." + "Comprar pontos". Erro com "Tentar de novo".
4. **Lançamento** (sheet `[.medium, .large]`): `BXRecibo(cabeca: "COMPROVANTE")` Tipo, Status, Data e hora, Referência (copiar), PONTOS faixa; se `transfer_out` + `pending` + criado há < 60 s: "Desfazer envio (Ns)" → `POST /transfer/<reference>/cancel` → recarrega carteira; compartilhar como imagem.
5. **Cartão BlaXx** (`GET /card/`, `/card/pass/status`, `/card/pass`): "SEU CARTÃO" / "Cartão BlaXx." / "Seu nível é definido pelos pontos acumulados e nunca cai ao resgatar." · face na cor do nível (`BXCor.nivel`), `BXWordmark` (nunca `Text`), selo do nível, saldo `.saldoMono` + "pts", "Nome · ID DE0A11C2", "Acumulado", "Faltam N p/ <próximo>", `BXProgresso` · `PKAddPassButton` só se disponível (se não: nota mono "CARTEIRA DO IPHONE · EM BREVE", sem botão) · "Programa de níveis": nome + mínimo ("0+ pts", "Por convite") + chip "ATUAL"; **sem `perks`**. Erro → `BXEstadoErro` (nunca o cartão demo "Ricardo · Ouro" do web).
6. **Notificações** (`GET /notifications/`, `PATCH …/read`, `POST /read-all`): "CENTRAL DE NOTIFICAÇÕES" / "Tudo que aconteceu na sua conta." · pílulas Todas/Não lidas · "Marcar todas como lidas" · lista num cartão: ícone pelo tipo, título, `relativo`, corpo seguro, bolinha neon de não lida · toque marca e navega (purchase/transfer → `.extrato`, voucher → `.voucher(id:)`, campaign → `.campanhas`). Atualiza `BXSessao.naoLidas`.

**Violações que o G2 não pode reproduzir:** saldo em R$ (`balance_brl_equiv`) como número principal (`RewardsHomeView.swift:116-123,150-156`); "Patrimônio total R$" e R$ por programa (`RewardsWalletView.swift:48-53,103`); programas Smiles/TudoAzul/LATAM Pass/Livelo/Esfera (`RewardsModel.swift:57-63`); gráfico e sparkline inventados (`RewardsWalletView.swift:20-24`, `RewardsHomeView.swift:257-263`); inicial "R" de fallback (`RewardsHomeView.swift:93`); ícones SF verdes e `megaphone.fill` (`RewardsHomeView.swift:187-196,218-223`); setas do extrato fora do padrão (`RewardsActivityViews.swift:142-147`); descrição crua "Resgate via PIX → chave" e "Envio (pending)" (`RewardsActivityViews.swift:149`); wordmark em `Text` (`RewardsWalletView.swift:135-137`, `RewardsCatalogViews.swift:49-51`); erro de campanhas virando vazio (`RewardsHomeView.swift:53`). Do web: "Plano Plus/Prime", meta 100.000 pts, "+20 % de bônus", campanhas fixas do painel, "Próx. expirar", "A expirar 12 dias", gráfico "Acúmulo 6 meses", "Pontos a expirar" inventados, números de demonstração quando a API falha (32.480, 1.250, 800), "Disponíveis = saldo − pendentes", cartão demo "Ricardo · 16.320 · Ouro", `perks` do nível com "PIX", cor `#C6FF00`.

**Pronto quando:** build `dd-g2` ok sem aviso em `Saldo/`; fotos G2 das 6 telas (pronto/carregando/vazio/erro, AX), com `-BXSubtela lancamento`; armadilhas de demo invisíveis.

### G3 · Movimentar: Comprar, Valor livre, Pagamento, Histórico, Enviar, Receber

**Arquivos (dono):** `R/Telas/Movimentar/` (pasta, inclui `BXTelasMovimentar.swift`). Fotos `DOCS/fotos-ios-depois/G3-*`.
Sugeridos: `BXComprarTela.swift`, `BXValorLivreSheet.swift`, `BXPagamentoPixSheet.swift`, `BXPagamentoCartao.swift` (atrás de D02), `BXCompraConcluidaTela.swift`, `BXHistoricoComprasTela.swift`, `BXEnviarTela.swift`, `BXConfirmarEnvioSheet.swift`, `BXEnvioConcluidoTela.swift`, `BXLeitorQR.swift`, `BXReceberTela.swift`.

**Destinos que resolve:** `.comprar(pacote:)`, `.historicoCompras`, `.enviar(para:)`, `.receber`.

1. **Comprar** (`GET /pix/packages`, `GET /payments/card/config` se D02): `BXCabecalhoPagina("COMPRAR PONTOS", "Escolha o seu ponto de partida.", "Pacotes sem mensalidade. Os pontos entram na conta depois da confirmação do pagamento.")` · 4 `BXBilhetePacote` (pré-seleção pelo `pacote:` do destino, senão Plus) · `BXRecibo(cabeca: "EXTRATO DA SUA COMPRA")`: Pacote, Pontos, Pagamento ("PIX", ou "Cartão ou PIX" se D02), Mensalidade nenhuma, TOTAL (tarifa), faixa PONTOS NA CONTA, nota "Os pontos do pacote já incluem o bônus. Pontos são créditos promocionais de uso restrito na plataforma.", via, ação "COMPRAR N PTS →" · `BXLinkSeta("Valor livre")` · "Histórico de compras →" · aviso legal mono. Ação → `POST /pix/charge {package}` (aquecer) → sheet de pagamento. **Não gera cobrança sozinho ao abrir** (o web gera com `?pkg=`).
2. **Valor livre** (sheet): campo `.dinheiro` "Quanto você quer comprar?" (mín. R$ 10,00, máx. R$ 100.000,00) · nota "Os pontos são calculados na confirmação." · sem prévia de pontos · "Gerar QR Code de pagamento" → `POST /pix/charge {amount_brl}`.
3. **Pagamento PIX** (sheet `.large`): "Pague pelo app do seu banco" · `BXQRCode(br_code)` (ou `qr_code_image`) · "Copiar código" · recibo Valor · Pontos (`points_to_credit` do servidor) · "Expira em mm:ss" · `BXStatus(.aviso, "AGUARDANDO PAGAMENTO")` · polling `GET /pix/charge/<id>` a cada 4 s até expirar, pausado em segundo plano e retomado ao voltar · paid → `BXCompraConcluidaTela` · expired/rejected → estado com "Gerar novo código" · fechar com cobrança pendente pede confirmação ("A cobrança continua válida por N min. Você pode reabrir pelo histórico."). Em DEBUG com provider mock: "Simular pagamento (demo)".
4. **Erros de compra**: `.pagamentoIndisponivel` (C6, D01) → `BXEstadoErro` "O pagamento por PIX está indisponível no momento." sem reenvio automático; limite mensal/valor → mensagem do servidor sanitizada; 401 → sessão.
5. **Compra concluída**: recibo "COMPRA CONFIRMADA" com faixa "PONTOS NA CONTA +N", háptica `.success`, "Ver meu saldo" → `.carteira`, "Comprar mais".
6. **Cartão** (só com `BXRecursos.compraCartao`): seletor "PIX | Cartão" quando `config.enabled`; tokenização exige SDK do Stripe (não está no projeto; D02); `POST /payments/card/charge` com `Idempotency-Key`; `in_process` → polling. Sem D02 aprovado, nada disso aparece.
7. **Histórico de compras** (`GET /pix/my-charges`, + cartão se D02): lista por data com valor, pontos, status (`BXStatus`), pendente reabre o QR.
8. **Enviar** (`POST /transfer/`): `BXCabecalhoPagina("ENVIAR PONTOS", "Pontos para quem você quiser.", "Entre contas BlaXx. O envio pode ser desfeito em até 60 segundos.")` · "Para" (e-mail, CPF ou Cartão BlaXx, preenchido por `para:`) + botão "Ler QR" (`DataScannerViewController`, só se `isSupported` e se `Bundle.main` tiver `NSCameraUsageDescription`; aceita o URL `blaxxpontos://enviar?para=<ID>` gerado pelo Receber e o código puro de 8 hex; qualquer outro QR é recusado com aviso) · "Pontos a enviar" grande + atalhos 500 · 1.000 · 5.000 · 10.000 · Tudo · "Mensagem (opcional)" com contador 140 · "Sua senha (confirmação)" · recibo resumo (Para, Pontos, Mensagem, Seus pontos, Após o envio) **sem linha de taxa** · validações locais ("O envio mínimo é de 100 pts.", "Pontos insuficientes.", "Confirme com sua senha.") · "Revisar envio" → **confirmação** (sheet `.medium`) → envio com `BXChaveIdempotencia` da intenção. Tratamentos: 400 "senha incorreta" (inline, não desloga), 401 `mfa_required` → campo de código TOTP e reenvio com `mfa_code`, 409 `DUPLICATE_SUSPECTED` → diálogo "Parece um envio repetido. Enviar de novo?" (nova chave só se confirmar), 429 `RECIPIENT_PROBE_BLOCKED`, 403 e-mail → `exigirVerificacaoEmail`. A senha vive só em `@State` e é apagada ao sair da tela.
9. **Envio concluído**: `BXRecibo(cabeca: "COMPROVANTE DE ENVIO")` Comprovante `ENV-…`, Para, Pontos, Data, Status "Em processamento" → "Efetivado" · "Desfazer (59 s)" → `POST /transfer/<id>/cancel` · aos 61 s recarrega a carteira (efetiva o envio e dispara a notificação do destinatário) · compartilhar comprovante como imagem · "Enviar mais", "Ver extrato".
10. **Receber**: "RECEBER PONTOS" / "Mostre o seu Cartão BlaXx." · `BXQRCode("blaxxpontos://enviar?para=DE0A11C2")` em cartão branco, brilho máximo enquanto visível · número `DE0A 11C2` em `.saldoMono` (tinta) + copiar · `ShareLink` "Meu Cartão BlaXx: DE0A 11C2" · nota "Quem tem a BlaXx pode enviar pontos para você com este código, o seu e-mail ou o seu CPF."

**Violações que o G3 não pode reproduzir:** "Vender pontos", "Você recebe via PIX R$ X", "Resgatar via PIX" e textos finais de PIX no resgate (`RewardsFinanceSheets.swift:456,466-470,475,493,541,544`) e ação "Vender" (`RewardsHomeView.swift:178`), tudo fora por D03; linhas "Taxa de serviço / Grátis / Sem taxa" (`RewardsTradeSheet.swift:113`, `RewardsSendView.swift:182,208`) e "Taxa de envio GRÁTIS"/"Sem taxa" do web; contatos inventados (`RewardsModel.swift:65-70`) e "Pontos enviados! … concluída na hora" (`RewardsSendView.swift:234-242`), porque o envio fica 60 s em processamento; CTA desabilitado com texto neon sobre cinza (`RewardsComponents.swift:96-109`) e traço neon sobre branco no pacote (`RewardsFinanceSheets.swift:251`); `/pix/packages` sem checar status (`API.swift:741-764`); envio e resgate sem `Idempotency-Key`; slider de passo 1.000 (`RewardsComponents.swift:217`). Do web: régua "R$ 180 · 2.000 pts" e prévia de pontos do valor livre (valor do ponto), bônus "+10/+20/+40 %" e "até 15 %" (D07), "Simulador" com valores fixos, boleto "em breve", senha guardada em `sessionStorage`, conteúdo fixo de demonstração debaixo da confirmação, `receber-pontos.html` inventada.

**Pronto quando:** build `dd-g3` ok sem aviso em `Movimentar/`; fotos G3 com `-BXSubtela valorLivre|pix|pago|confirmar|concluido` e `-BXDemoEstado erro` (PIX indisponível); a palavra "PIX" aparece só nas telas de compra (grep, §5.7).

### G4 · Descobrir e resgatar: Parceiros, Detalhe, Resgates, Benefício, Voucher, Campanhas

**Arquivos (dono):** `R/Telas/Descobrir/` (pasta, inclui `BXTelasDescobrir.swift`). Fotos `DOCS/fotos-ios-depois/G4-*`.
Sugeridos: `BXParceirosTela.swift`, `BXCartaoParceiro.swift`, `BXFavoritos.swift` (UserDefaults), `BXCatalogo.swift` (cache em memória de parceiros e benefícios visíveis), `BXParceiroTela.swift`, `BXResgatesTela.swift`, `BXBeneficioTela.swift`, `BXConfirmarResgateSheet.swift`, `BXResgateConcluidoTela.swift`, `BXVoucherTela.swift`, `BXCampanhasTela.swift`.

**Destinos que resolve:** `.parceiros(busca:)`, `.parceiro(id:)`, `.resgates(_)`, `.beneficio(id:)`, `.voucher(id:)`, `.campanhas`. Os públicos funcionam para visitante (ações que exigem conta chamam `pedirEntrada`).

1. **Parceiros** (`GET /partners/`, `/partners/categories`, `/campaigns/` se D04; logado: `/card/`): cartão de embarque "PAINEL DE PARTIDAS · PARCEIROS" | "REDE EM EXPANSÃO · 2026", capa "Parceiros / BlaXx." + marcada "Escolha o seu destino.", rótulo "DESTINO · NOME DA MARCA OU CATEGORIA" + `BXCampoBusca("Buscar parceiro ou loja")` + botão "Meus favoritos N", lead do web; canhoto visitante (Passageiro Você · Portão Parceiros · Lista Aberta, "Criar conta") ou logado (Seus pontos · Em processamento · Nível · Progresso + "Ver carteira" / "Resgatar pontos →"; sem resposta: "Indisponível agora") · "PAINEL DE PARTIDAS · LISTA COMPLETA" / "Todos os parceiros." / `BXNumeroDestaque("N", "parceiros na lista")` · pílulas `.kit`: Todos N · Favoritos N · Postos · Supermercados · Farmácias · Viagens · Moda · Beleza · "Mais categorias +X" (tracejada → sheet com todas as canônicas) · status mono "N PARCEIROS · MOSTRANDO 20" · aviso de cidade (`BXSanitizador.cidade`) · lista de `BXCartaoParceiro` (69 pt: ícone `.cartao` da categoria + nome `.nomeParceiro` + categoria original mono + picote + canhoto `.favorito`), 20 por vez com carga ao rolar · campanhas (bilhetes rotativos a cada 6 s, parados com Reduzir Movimento) + recibo "RESUMO DA LISTA" (Parceiros, Categorias, Campanhas ativas, Seus favoritos, faixa "REDE ……… EM EXPANSÃO", "Os favoritos ficam salvos só neste aparelho.") · rota "Busque · Filtre · Favorite · Confira".
   Estados: esqueleto de 8 cartões; erro "Não foi possível carregar os parceiros agora." + "Tentar de novo"; vazio por categoria; favoritos vazio "Toque no coração do canhoto de um parceiro para guardar aqui."; busca sem resultado + "Limpar busca".
2. **Detalhe do parceiro** (`GET /partners/<id>`): farelo mono "INÍCIO / PARCEIROS / <NOME>" · cartão "CARTÃO DO PARCEIRO · BLAXX", `BXIcone(.marca)` + "Categoria <nome>", título = nome (encolhe), marcada "Troque seus pontos." (com benefício) ou "Rede em expansão."; grade De Seus pontos · Para Benefícios · Disponíveis N · A partir de X pts; canhoto Passageiro Você · Destino <parceiro>, CTA "Ver benefícios" (rola) ou "Ver todos os resgates", "Outros destinos · Parceiros →" · "BILHETES · BENEFÍCIOS DO PARCEIRO" / "Troque seus pontos aqui." com bilhetes ordenados por pontos (BX · VOUCHER | POPULAR, nome, pontos, "VALIDADE DO VOUCHER N dias", "Ver benefício →", canhoto com ícone da categoria) ou bilhete "BX · SEM BILHETE / Nenhum benefício disponível agora." · recibo "FICHA DO PARCEIRO" (Parceiro, Categoria, Benefícios, Conta ativa/visitante, E-mail verificado sim/não, Confirmação "no app", A PARTIR DE, nota do regulamento) · rota "Tenha · Escolha · Confirme · Troque". Estados: carregando, não encontrado ("Parceiro não encontrado. Escolha outro destino."), erro com "Tentar de novo". Parceiro fictício → tratado como não encontrado.
3. **Resgates** (`GET /benefits/`, `GET /vouchers/`): "RESGATES" / "Troque por benefícios e experiências." + `BXChip(.preto, "SEUS PONTOS N")` · `BXAbas` Catálogo · Meus resgates (`ativo: .neon`) · Catálogo: pílulas `.conta` com rótulos acentuados; cartões/bilhetes com ícone da categoria, nome, parceiro, custo, "Você pode resgatar" ou "Faltam N pts" + `BXProgresso`; esgotado com `BXStatus(.perigo, "ESGOTADO")` · Meus resgates: filtros Todos/Ativos/Usados/Expirados; voucher com canhoto de ícone, status, código + "Copiar", "N pts · VÁLIDO ATÉ dd/mm/aaaa"; vazio "Você ainda não tem resgates." + "Ver catálogo".
4. **Benefício** (`GET /benefits/<id>`): bilhete grande · descrição segura · "Validade do voucher: N dias", estoque, link para o parceiro · recibo Saldo · Custo · Saldo após · CTA "Resgatar agora" ou estado **saldo insuficiente** ("Faltam N pts para este benefício", barra, "Comprar pontos" → `.comprar()`).
5. **Confirmar resgate** (sheet `.medium`): recibo resumo + "Confirmar resgate" → `POST /benefits/<id>/redeem` com `BXChaveIdempotencia` → 402 saldo, 409 sem estoque, 403 e-mail (`exigirVerificacaoEmail`).
6. **Resgate concluído**: recibo "VOUCHER" com código em mono grande, copiar (`.impact(.light)`), validade, "Ver meus resgates", "Voltar ao catálogo"; recarrega a carteira.
7. **Voucher** (`GET /vouchers/<id>`): código grande + copiar, status, validade, benefício; sem QR (não há integração com parceiro que o leia).
8. **Campanhas** (D04; `GET /campaigns/`, `POST /campaigns/<id>/join`): "CAMPANHAS" / "Metas que valem pontos." · bilhete por campanha: nome seguro 19/900, descrição segura, `BXChip(.neon, "+N pts")`, progresso **só em %** + `BXProgresso`, "FALTAM N DIAS"/"ÚLTIMO DIA", "Participar →" / "EM ANDAMENTO" / "Concluída". Vazio "Nenhuma campanha ativa no momento.".

**Violações que o G4 não pode reproduzir:** parceiros mock com "+120 % bônus" e "pts · R$" (`RewardsPartnersView.swift:57-66`); "logos" de terceiros como letras coloridas (`RewardsComponents.swift:13-28`, `RewardsProgramSheet.swift:26-31`); emoji de benefício e fallback "🎁" (`RewardsCatalogViews.swift:356`); "x% de R$ alvo" (`RewardsCatalogViews.swift:235`); benefícios de parceiro fictício e `partner_name` deles. Da API: `accrual_rule`, `logo_emoji`, `image_emoji`, descrições "Parceiro Livelo"/"fictícia", `mechanic`, `target_brl`. Do web: categoria crua "educacao"/"experiencia" nos filtros, "Confirmação com senha" (o backend não pede senha no resgate de benefício), Netflix/Starbucks/Carrefour/Spotify e todo o conteúdo fixo das telas de demonstração, "Simular gasto R$ 100".

**Pronto quando:** build `dd-g4` ok sem aviso em `Descobrir/`; fotos G4 (lista, favoritos, mais categorias, detalhe com e sem benefício, catálogo, meus resgates, benefício normal/insuficiente/esgotado, confirmar, concluído, voucher, campanhas; estados; AX); "Loja Exemplo" invisível; "Mercado Teste" sem descrição.

### G5 · Conta e ajuda: Perfil, Segurança, Privacidade, Convidar, Ajuda, FAQ, Chamado

**Arquivos (dono):** `R/Telas/Conta/` (pasta, inclui `BXTelasConta.swift`). Fotos `DOCS/fotos-ios-depois/G5-*`.
Sugeridos: `BXPerfilTela.swift`, `BXSegurancaTela.swift`, `BXTrocarSenhaSheet.swift`, `BXTOTPSheet.swift`, `BXCelularSheet.swift`, `BXPrivacidadeTela.swift`, `BXExcluirContaSheet.swift`, `BXConvidarTela.swift`, `BXAjudaTela.swift`, `BXFaqTela.swift`, `BXFaqDados.swift`, `BXChamadoSheet.swift`.

**Destinos que resolve:** `.perfil`, `.seguranca`, `.privacidade`, `.convidar`, `.ajuda`, `.faq`.

1. **Perfil** (`GET /auth/me` via sessão, carteira, `/card/`): "SUA CONTA" / "Perfil." · cartão do usuário: `BXAvatar(tamanho: 86)`, nome 24/900, e-mail, `BXChip(.preto, "CLIENTE" | "CLIENTE VIP")`, números Saldo · Em processamento · Nível · "Configurações de segurança →" · "Dados pessoais" (rótulo mono / valor): Nome, E-mail + `BXStatus` VERIFICADO/PENDENTE (pendente → verificar), Celular mascarado, CPF mascarado (conta Google sem CPF: "Não informado"), Cartão BlaXx · nota "Para alterar seus dados, fale com o suporte." + "Abrir chamado" · links Segurança, Privacidade e dados, Notificações (`.notificacoes`), Convidar amigos (D06) · "Sair da conta" (confirmação → `BXSessao.sair()`) · versão do app.
2. **Segurança**: "SUA CONTA" / "Segurança." · **Autenticação**: Senha → `BXTrocarSenhaSheet` (atual, nova com checklist, confirmar → `POST /auth/change-password`; 401 = "Senha atual incorreta" inline; sucesso derruba a sessão → `sessaoRevogada("Senha alterada. Entre de novo.")`; conta só Google: texto do servidor "Defina uma senha em 'Esqueci a senha'") · Verificação em duas etapas: aplicativo autenticador (`mfa_enabled` → ATIVA/INATIVA; ligar: `/auth/mfa/setup` → `BXQRCode(uri)` + segredo copiável + "Abrir no app autenticador" (`otpauth://`) + código → `/auth/mfa/enable`; desligar: senha + código) e SMS (celular: `/user/phone` → código → `/user/phone/verify`; ligar/desligar com senha; `phone_not_verified` leva a verificar o celular; o `/auth/me` não diz se o SMS está ativo, então a tela mostra as duas ações e trata a resposta) · E-mail: VERIFICADO/PENDENTE · **Sessões ativas** (`GET /user/sessions`): dispositivo, IP mascarado, último uso relativo, chip "ATUAL", deslizar "Encerrar" (`DELETE`), "Encerrar todas as sessões" (aviso de que esta também cai → `POST /auth/sessions/revoke-all` → `sessaoRevogada`) · **Histórico de acesso** (`GET /user/access-log?limit=50`) · "Boas práticas" (sem falar em "resgates por transferência").
3. **Privacidade e dados**: consentimentos (`GET /privacy/consents`, tipos legíveis: Termos de uso, Política de privacidade, LGPD, Ofertas e novidades, Cookies; revogar só marketing/cookies) · "Exportar meus dados" (`GET /auth/account/export` → arquivo JSON por `ShareLink`; o arquivo não é exibido na tela) · "Termos de uso", "Política de privacidade", "Regulamento" (site) · "Excluir minha conta" → `BXExcluirContaSheet`: explicação (dados anonimizados, histórico mantido por exigência legal), senha (ou reautenticação Google), digitar "EXCLUIR", botão `.perigo` → `DELETE /auth/account` com `confirm: "EXCLUIR MINHA CONTA"` → `sessaoRevogada("Sua conta foi excluída.")`.
4. **Convidar amigos** (D06): "CONVIDAR" / "Chame seus amigos para a BlaXx." · texto sem promessa de pontos · `ShareLink` com `https://blaxxpontos.com.br/cadastro` · se D06 virar "remover", o destino some da gaveta e do Perfil.
5. **Central de ajuda**: "Como podemos te ajudar?" · busca local · 8 temas (`BXCartaoClaro`: Acúmulo de pontos, Resgates, Comprar pontos, Enviar pontos, Conta e perfil, Segurança, Campanhas, Termos e documentos) → FAQ filtrada · "Abrir um chamado" (neon, "Resposta em até 1 dia útil.") · `BXRodapeRecibo`.
6. **FAQ** (`BXFaqDados.swift`): perguntas do `WEB/central-ajuda.html` **sem** PIX no resgate e **sem** "Quanto vale um ponto BlaXx?"; afirmações que dependam do regulamento (prazos, validade) só se estiverem no regulamento publicado, com link "Regulamento".
7. **Chamado**: `MFMailComposeViewController` (ou `mailto:suporte@blaxxpontos.com.br`) com assunto e corpo pré-preenchidos (versão do app, iOS, Cartão BlaXx; nunca senha).

**Violações que o G5 não pode reproduzir:** Ajuda "O valor sai por PIX…" e "Prazo do resgate — O PIX…" (`RewardsAccountViews.swift:711-714`); "Chave PIX" no Perfil (`:429`); FAQ "Quanto vale um ponto BlaXx?" (`:743`); "Código copiado ✓" (`:656`); ícones de linha tinta sobre cinza (`:176-181`); exclusão sem `confirm` e com rota de reserva inexistente (`API.swift:542-555`); 401 de senha errada tratado como sessão. Do web: sessões fixas "iPhone 15 · São Paulo", "2FA ativa desde 12/03/2026", nota "92/100", interruptores de preferência sem endpoint, convidados fictícios, "5.000 pts por amigo", "Mariana84", `PATCH /user/profile`, `PATCH /user/password`, `/auth/logout-all`.

**Pronto quando:** build `dd-g5` ok sem aviso em `Conta/`; fotos G5 (perfil, segurança com `-BXSubtela senha|totp`, privacidade com `excluir`, convidar, ajuda, FAQ; estados; AX).

### 5.6 Desativação atômica do mundo antigo (G1, um passo só)

Quando `ContentView` já aponta para `BXRaiz`, o G1 envolve **o conteúdo inteiro** de cada um dos 18 arquivos antigos de `R/` em:

```swift
#if BX_LEGADO_REWARDS   // desativado no redesenho Embarque de 22/10/2026. Não apagar sem decisão do dono (D14).
… conteúdo original intacto …
#endif
```

`BX_LEGADO_REWARDS` nunca é definido. Como nenhum arquivo novo referencia tipos antigos (§0.2) e o código morto da raiz não depende de `R/` (conferido: só `ContentView` usava `RewardsRoot`, e `Session.swift` usa `Cache/WalletCache.swift`, que fica), o build continua verde. Isso tira do binário o mundo mock (programas, contatos, ofertas, selo de homologação, conta demo). Os arquivos da raiz (`BuyView`, `RedeemView`, `MobileShell`, `API.swift` etc.) ficam como estão, fora do escopo.

### 5.7 Checagens comuns (cada grupo roda na sua pasta antes de entregar)

```bash
P="R/Telas/<Pasta>"   # ou R/Embarque para o G0
# valor do ponto, campos proibidos, PIX fora da compra, termos proibidos
grep -rniE 'pts ?/ ?R\$|1 ?pt ?= ?R|a cada R\$|≈|balance_brl|brl_equiv|accrual|logo_emoji|image_emoji|mechanic|target_brl|fict[ií]ci|livelo|taxa|patrim[oô]nio' "$P"
grep -rnw 'PIX' "$P"                     # só pode aparecer em Movimentar (compra)
# mundo antigo e literais
grep -rnE '\bRW[A-Z]|Rewards[A-Z]|BlaxxAPI|BlaxxColor|BlaxxFont|TokenStore|WalletCache|Color\(hex:|\.font\(\.system|Image\(systemName' "$P"
# emoji
perl -CSD -ne 'print "$ARGV:$.: $_" if /[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B50}\x{2705}]/' $(find "$P" -name '*.swift')
# texto neon sobre claro
grep -rn 'foregroundStyle(BXCor.neon' "$P"   # tem de dar 0 (usar .bxTextoNeon() sobre tinta)
# avisos novos
grep -E 'warning: .*Rewards/(Telas/<Pasta>|Embarque)/' build.log
```

Resultado esperado: zero linhas, com exceções justificadas em comentário no código (ex.: "taxa" num nome de variável não exibido).

---

## 6. Decisões que dependem do dono

Nenhuma destas foi decidida aqui. A coluna "Padrão do app até decidir" é só o comportamento seguro da build.

| # | Decisão | Por que importa | Padrão do app até decidir |
|---|---|---|---|
| D01 | **C6 cancelou a homologação da API PIX** (e-mail colado nesta conversa: falta do roteiro de testes; exige novo cadastro no portal Developers e credenciais novas). Retomar com o C6 ou trocar de provedor? | Sem isso, toda compra por PIX falha em produção, no app e no site (`POST /pix/charge` → 400). O Asaas já tinha caído. | Comprar mostra os pacotes e, ao gerar, "O pagamento por PIX está indisponível no momento." |
| D02 | **Compra por cartão no app iOS** (Stripe em modo live, SDK novo no projeto, regra 3.1.1 da App Store sobre compra fora do In-App Purchase, e a mesma pergunta vale para a compra por PIX dentro do app). | Hoje o cartão é o único meio vivo em produção e cobra de verdade. Comprar pontos dentro do app pode ser recusado na revisão. | `BXRecursos.compraCartao = false`. |
| D03 | **Resgate por transferência** (`POST /redeem/`, saque em dinheiro): manter no app (sem R$, sem a palavra PIX) ou retirar? | A versão atual mostra R$ e "Resgatar via PIX", proibidos. O web tirou do menu. Sem mostrar valor, o cliente não sabe quanto recebe. | Fora do app. |
| D04 | **Campanhas de produção em Release**: "Pacote Premium", "Família engajada" (depende de indicação, que não existe) e "Maio em dobro" (em outubro). São reais? | Regra "nada de campanhas inventadas em Release". | Escondidas em Release (`BXRecursos.campanhas` só em DEBUG). |
| D05 | **Catálogo de parceiros**: os 258 com descrição "Parceiro Livelo · …" são marcas reais sem integração. Mostrar só os nomes, como o web faz, ou esconder até existir rede real? Com os 8 fictícios escondidos, sobram 2 benefícios em Release (Sorteio e Doação, da BlaXx). | Risco de anunciar parceria que não existe (memória "Home anuncia parceiros fake"). | Igual ao web: nomes e categorias, sem descrição; fictícios e seus benefícios escondidos. |
| D06 | **Indique e ganhe**: o backend não tem programa de indicação. "Convidar amigos" só para compartilhar, ou tirar o item? | O web promete 5.000 pts (e 500 ou 2.500 ao amigo) sem backend. | "Convidar amigos" sem prometer pontos. |
| D07 | **Texto de bônus dos pacotes**: o web tem quatro versões ("cerca de 5 %/10 %", "+10/+20/+40 %", "até 15 %", "+20 %"); a conta real dá Plus +5,3 %, Prime +11,1 %, Black +17,6 % sobre o Start (e a memória registra a arbitragem do Black). | Número de bônus errado é promessa falsa. | Sem percentual; só pontos e tarifa. |
| D08 | **Pacote Black** aparece no app (a home do web mostra 3, a API tem 4)? | Ligado à arbitragem do bônus. | Os 4 da API. |
| D09 | **Benefícios por nível**: os `perks` da API citam PIX. Escrever textos novos ou mostrar só nome e mínimo? | Texto de produto. | Só nome e mínimo de pontos. |
| D10 | **Login com Google no iOS**: a regra 4.8 da App Store exige oferecer Sign in with Apple junto, e o backend não tem login Apple. | Recusa na revisão. | **DECIDIDO (dono, 22/10): Google também em Release**, com o fluxo nativo do GoogleAuthService. Antes de ir para a App Store, adicionar Sign in with Apple (backend + app). |
| D11 | **Bloqueio por Face ID ao abrir o app.** | Conveniência × atrito. | Desligado. |
| D12 | **Push**: religar o entitlement `aps-environment` e a chave APNs no backend. | Hoje o app não recebe push. | Registro só depois do login; sem entitlement, nada chega. |
| D13 | **Universal Links** (`apple-app-site-association` em blaxxpontos.com.br) para o link de redefinir senha abrir no app e para o preenchimento de senha do iCloud. | O e-mail de redefinição aponta para o site. | Continua o esquema `blaxxpontos://`; o e-mail abre o site. |
| D14 | **Apagar de vez** os 18 arquivos antigos de `Rewards/` e o código morto da raiz. | Limpeza do repositório. | Só desativados com `#if BX_LEGADO_REWARDS`. |
| D15 | **Conta demo de homologação no banco de produção** (credenciais escritas em `RewardsBackend.swift:266-271`): desativar a conta e trocar a senha? | Credencial no repositório e conta de teste em produção. | O app novo não usa a conta. |
| D16 | **Família tipográfica oficial do app**: Brand Book diz Space Grotesk; o web Embarque usa Archivo + Space Mono, e os TTF já estão no disco (não versionados) e registrados no `Info.plist` (alteração não commitada). | Fidelidade ao web × Brand Book. | `BXFonte.modo = .sistema` (SF Pro condensado + SF Mono), troca de uma linha. |
| D17 | **Venda de pontos B2B** (`venda-pontos.html`) no app de cliente, ou no máximo um link "Para empresas" para o site? | Página sem backend e com métricas inventadas. | Fora do app. |
| D18 | **Pedidos ao backend**, em ordem de impacto: sinal de PIX disponível (`available` em `/pix/provider` ou `code` no 400); edição de perfil; `phone_verified` e `mfa_method` no `/auth/me`; paginação do extrato; efetivação de envios por cron; prévia do destinatário; indicação de verdade ou retirada da campanha "Família engajada"; JSON nos 404/429. | Sem eles, o app fica com textos de contorno. | Textos honestos de contorno (§2.2). |
