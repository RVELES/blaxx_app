# 05 · Fundação do design system "Embarque" (G0) no app iOS

Data: 22/10/2026 · Base: `04-spec-redesenho.md` §1 e §4, medidas de `02-inventario-web-mobile.md` e
`medidas-computadas-375.txt`, fotos de `fotos-web/`.
Build Debug e Release verdes (iPhone 17 Pro, iOS 27, derivedData `SCRATCH/dd-fundacao` e `dd-fundacao-rel`),
**zero aviso** nos arquivos novos. Nenhum POST/PUT/DELETE, nenhum commit/push, nenhum arquivo apagado.

Caminhos: `R/` = `blaxx_app/BlaxxPontos/BlaxxPontos/Rewards/`, fotos em `docs/redesenho/fotos-fundacao/`.

---

## 1. O que foi entregue

### 1.1 Arquivos novos

```
R/Embarque/DS/BXCor.swift              tokens de cor + Color(bxHex:) + BXCor.nivel(_:)
R/Embarque/DS/BXMedidas.swift          BXRaio, BXEspaco, BXToque, BXSombra + .bxSombra, BXMovimento
R/Embarque/DS/BXFonte.swift            BXFonte (estilos, modo sistema/embarcada) + .bxFonte
R/Embarque/DS/BXSVG.swift              parser de SVG → Path (path/rect/circle/ellipse, arcos) + BXSVGVista
R/Embarque/DS/BXIconesDados.swift      BXIconeNome (57) + desenhos de icones.json e do Anexo A
R/Embarque/DS/BXIcone.swift            BXIcone, BXDesenhoIcone (interno), BXGlifo, BXSino, BXAvatar
R/Embarque/DS/BXMarca.swift            BXWordmark (.barra, .claro, .logoCompleto) com os d= dos SVG do web
R/Embarque/DS/BXFormas.swift           BXPicote, .bxSuperficie (furos reais), BXSerrilha, BXCodigoBarras,
                                       BXTracejado, BXLinhaTracejada, BXTraco
R/Embarque/DS/BXCartaoEmbarque.swift   BXCartaoEmbarque, BXTituloCapa, BXLinhaCapa, BXLetreiro, BXDado,
                                       BXGradeDados, BXCelulaDado, BXDadosCanhoto, BXLinkCanhoto
R/Embarque/DS/BXRotaEscalas.swift      BXEscala, BXRotaEscalas
R/Embarque/DS/BXBilhete.swift          BXBilhete, BXSeloBilhete, BXEstiloPressao, BXBilhetePacote, BXBilheteCampanha
R/Embarque/DS/BXRecibo.swift           BXRecibo, BXReciboLinha, BXPontilhado, BXReciboTotal, BXReciboFaixa,
                                       BXReciboTracejo, BXReciboVia, BXReciboNota
R/Embarque/DS/BXPainel.swift           BXPainel, BXNumeroDestaque, BXLegendaCor, BXQuadroLinha, BXQuadroPreto,
                                       BXColunasQuadro, BXQuadroInfo
R/Embarque/DS/BXRotulos.swift          BXRotulo, BXChip, BXStatus, BXPilula, BXGeometriaCompartilhada, BXAbas, BXProgresso
R/Embarque/DS/BXBotoes.swift           BXBotao, BXEstiloBotao, BXLinkSeta
R/Embarque/DS/BXCampos.swift           BXCampo, BXCampoBusca, BXCampoCodigo, BXInterruptorEstilo
R/Embarque/DS/BXEstados.swift          BXCarga, BXConteudo, BXEsqueleto, BXBlocoEsqueleto, BXEstadoVazio,
                                       BXEstadoErro, BXCarregando, BXFaixaOffline, BXToastCentral + .bxToastHost
R/Embarque/DS/BXChrome.swift           BXTabBar (+ BXAba.titulo/.icone), BXBarraUtilitaria, .bxBarraTopo,
                                       BXGavetaConteiner, BXGavetaGrupo, BXGavetaItem, BXCabecalhoPagina,
                                       BXSecao, BXCartaoClaro, BXRodapeRecibo
R/Embarque/DS/BXInteracao.swift        BXHaptica, .bxTextoNeon, BXNumeroAnimado, BXCopiar, BXQRCode, BXCompartilharImagem
R/Embarque/DS/BXFormato.swift          BXFormato (pontos, dinheiro, datas, relativo, dia, máscaras, ISO 8601)
R/Embarque/Nucleo/BXAmbiente.swift     BXAmbiente, BXRecursos (bandeiras D02–D11)
R/Embarque/Nucleo/BXNavegacao.swift    BXAba (só isto nesta entrega)
R/Embarque/Nucleo/BXErro.swift         BXErro completo (§1.7.3) + mensagemParaUsuario
R/Embarque/Nucleo/BXModelos.swift      BXPacote, BXCampanha (os DTOs que o DS recebe)
R/Embarque/Nucleo/BXSanitizador.swift  textoSeguro, textoCampanhaSeguro, ehFicticio, normalizar, semSimbolos
R/Embarque/Demo/BXDemo.swift           argumentos de lançamento (DEBUG lê; Release = constantes desligadas)
R/Embarque/Demo/BXGaleria.swift        (#if DEBUG) galeria de 18 páginas com todos os componentes
```

### 1.2 Arquivos existentes tocados (mínimo, só DEBUG)

| Arquivo | Mudança | Por quê |
|---|---|---|
| `ContentView.swift` | em `#if DEBUG`, `-BXGaleria` mostra `BXGaleria()` no lugar de `RewardsRoot()` | abrir a galeria (pedido da tarefa) |
| `BlaxxPontosApp.swift` | em `#if DEBUG`, com `-BXGaleria` o `.task` de push retorna antes de pedir permissão | sem isso, ao abrir a galeria o app pede push e, com token, faz `POST /push/devices/register` em **produção** (`PushService.registerWithBackend`). A galeria fica com zero rede. |

Release não muda: os dois blocos estão dentro de `#if DEBUG`.

### 1.3 Como abrir a galeria

```
DD=SCRATCH/dd-fundacao; SIM=29702B3D-53FF-44C6-810D-D665C7C7636A
xcodebuild -project ".../BlaxxPontos.xcodeproj" -scheme BlaxxPontos -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD" build
xcrun simctl install $SIM "$DD/Build/Products/Debug-iphonesimulator/BlaxxPontos.app"
xcrun simctl launch --terminate-running-process $SIM Blaxx-Pontos-Inc.BlaxxPontos -BXGaleria YES -BXGaleriaPagina 5 -BXCongelar YES
xcrun simctl io $SIM screenshot G0-05.png
```

| Argumento (só DEBUG) | Efeito |
|---|---|
| `-BXGaleria [YES]` | galeria no lugar do app (sem número: índice navegável das 18 páginas) |
| `-BXGaleriaPagina <n>` | abre direto a página n (cada página cabe numa tela, para foto) |
| `-BXCongelar [YES]` | para o letreiro e o brilho dos esqueletos (fotos determinísticas) |
| `-BXFonteEmbarcada [YES]` | Archivo + Space Mono em vez de SF (comparação para a decisão D16) |
| `-BXDemo`, `-BXDemoVisitante`, `-BXDemoEstado`, `-BXTela`, `-BXSubtela`, `-BXAncora` | já lidos por `BXDemo`, reservados ao modo demonstração completo (§4) |

Páginas: 1 cores e tipografia · 2 ícones (57) · 3 ícones ampliados · 4 marca e chrome (barra do topo real
em `NavigationStack` + barra de abas) · 5/6 cartão de embarque (topo/fim) · 7 rota · 8 bilhetes de pacote e
campanha · 9 bilhete de benefício e cartões de parceiro · 10 recibo · 11 painel e quadro preto · 12 rótulos,
chips, status, pílulas, abas, progresso · 13 botões e campos · 14 estados · 15 cabeçalho, seção, cartão claro,
número animado, QR · 16 bloco "Pronto para embarcar?" + rodapé-recibo · 17 gaveta · 18 escala tipográfica.

---

## 2. Achados que os grupos PRECISAM saber

1. **Barra de status: não usar `.preferredColorScheme(.light)` na raiz.** No iOS 27 (simulador), forçar o
   esquema da janela anula o `.toolbarColorScheme(.dark, for: .navigationBar)`: a hora e os ícones da barra
   de status saem pretos sobre a barra preta (medido: texto `#000000` sobre `#0A0B0E`). Com
   `.environment(\.colorScheme, .light)` na raiz, a barra de status fica clara (texto `#FFFFFF`) e os
   componentes continuam claros. A galeria já usa assim. **G1: em `BXRaiz`, trocar o
   `.preferredColorScheme(.light)` da spec (§1.1, §2.3, §5 G1 item 7) por `.environment(\.colorScheme, .light)`.**
   Foto: `comparacao-07-chrome.png`, `G0-04-marca-chrome.png`.
2. **`.background(Cor)` sem forma sai com cantos arredondados** dentro de containers do iOS 26+ (usa a
   container shape do ambiente). Para fundo retangular, sempre `.background(BXCor.x, in: Rectangle())`.
   Todo o DS já segue isso; as linhas marcadas do título de capa saíam arredondadas antes da correção.
3. **`ContentTransition` não tem `.push`.** O letreiro usa `.id(frase)` + `.transition(.push(from: .bottom))`
   dentro de um `ZStack` com `.clipped()`.
4. **Furos do picote** só abrem dentro de `.bxSuperficie(...)` (ou de `BXCartaoEmbarque`/`BXBilhete`, que já a
   aplicam). Um `BXPicote` solto desenha só a linha tracejada; não pinta círculo com a cor do chão.
5. **Neon como texto** só por `.bxTextoNeon()` e só sobre `BXCor.tinta` (aba ativa, chip preto, saldo da
   carteira, link do quadro). O único `foregroundStyle(BXCor.neon)` do código é a própria `bxTextoNeon()`.

---

## 3. API dos componentes, com exemplos

Assinaturas do contrato §1.6 mantidas; o que foi acrescentado tem valor padrão (marcado **+**).

### 3.1 Tokens

```swift
BXCor.chao / .superficie / .superficie2 / .linha / .pontilhado / .cinza / .cinzaIcone / .tinta / .tinta2 / .tinta3
     .tintaApagada / .barraTexto / .papel / .neon / .neonPressionado / .neonProfundo / .limaSuave / .halo
     .okFundo .okTexto .avisoFundo .avisoTexto .perigoFundo .perigoTexto .infoFundo .infoTexto
     .quadroLinha .quadroToque .quadroRodape .quadroChip .quadroApagado .scrim
     + .pontilhadoSobreNeon (rgba .35 da faixa do recibo) + .bordaSobrePreto (papel 35 %)
BXCor.nivel("ouro")              // (fundo, texto) da paleta LOCAL; nunca tier.color da API
BXRaio.xl 24 · .lg 18 · .md 14 · .sm 12 · .xs 10 · .xxs 8 · .pilula
BXEspaco.margem 16 · .secao 40 · .cabecalhoSecao 24 · .cartao 18 · .grade 12 · .colunaMax 560
BXToque.botao 48 · .chip 44 · .itemGaveta 48 · .itemAba 52
.bxSombra(.padrao | .grande | .leve | .recibo)
BXMovimento.ease · .gaveta · .letreiro · .mola · BXMovimento.ou(.mola, reduzido: reduzirMovimento)
```

### 3.2 Tipografia

```swift
Text("Sua carteira.").bxFonte(.tituloPagina)        // fonte + tracking + caixa + Dynamic Type
Text("Rota · Como funciona").bxFonte(.rotuloSecao)  // MAIÚSC só na tela; o VoiceOver lê em caixa normal
BXFonte.fonte(.recibo, tamanho: 12)                 // Font concreta (uso interno/raro)
BXFonte.modoPadrao                                  // ← ÚNICA linha a trocar para .embarcada (D16)
```

Estilos do contrato: `capa, linhaMarcada, tituloPagina, tituloSecao, h2, numeroGrande, numeroDestaque,
saldoMono, pontosBilhete, totalRecibo, tituloBilhete, nomeParceiro, valorDado, corpo, corpoKit, lead, botao,
botaoCartao, acaoRecibo, campo, rotulo, rotuloSecao, rotuloAba, recibo, legenda`.
**+** acrescentados (medidas do web): `rotuloGrade` (mono 10, grade do cartão), `rotuloMedio` (mono 12),
`sufixoPontos` (18/600), `tarifa` (22/700), `palavraEscala` (34/800), `quadro` (mono 13 MAIÚSC),
`tituloQuadro` (20/800), `tituloConvite` (24/800), `campoBusca` (18/600), `monoForte` (mono 11/700 MAIÚSC),
`item` (16/600).
Mudança de forma em relação à spec: `BXFonte.modo` virou propriedade calculada (`modoPadrao` + atalho
`-BXFonteEmbarcada` em DEBUG). O modo embarcado foi conferido: Archivo variável (wght/wdth) e Space Mono
carregam do bundle (`familiaEmbarcadaDisponivel == true`), fotos `G0-*-embarcada.png`.

### 3.3 Ícones e marca

```swift
BXIcone(.carteira)                                   // 44, raio 12, desenho 24,6
BXIcone(.busca, tamanho: .cartao)                    // .aba 30 · .lateral 28 · .atalho 36 · .cartao 40 · .padrao 44 · .marca 52
BXIcone(.seta, tamanho: .livre(lado: 34, raio: 10), contorno: true)   // + contorno: sobre superfície neon
BXIcone(.favorito, tamanho: .aba, preenchido: true)                   // + preenchido: coração marcado
BXGlifo(.fechar, cor: BXCor.tinta) ; BXGlifo(.menu, cor: BXCor.papel)  // controles do chrome, não conteúdo
BXSino(naoLidas: 3)
BXAvatar(inicial: usuario?.primeiroNome)            // nil → desenho de perfil, nunca letra inventada; + anel: false
BXWordmark(.barra, altura: 22) ; BXWordmark(.claro, altura: 28) ; BXWordmark(.logoCompleto, altura: 80)
```

57 nomes: os 51 de `icones.json` + `setaCima, setaBaixo, visto, chave, semMensalidade, prancheta`.
Conferência: 6 ícones a 150 pt (voucher, favorito, sair, comprar, ajuda, anexo; arcos, tracejado, elipse,
preenchimento) contra o SVG do web renderizado no Chrome no mesmo tamanho: **0,00 % de pixels com diferença
> 80/255** (só antisserrilhado). Foto `comparacao-09-icones-ampliados-6.png`. O quadrado do app usa canto
contínuo (squircle do iOS); o web usa canto circular.

### 3.4 Cartão de embarque

```swift
BXCartaoEmbarque(topo: ("Cartão de embarque · BlaXx Pontos", "Brasil · 2026")) {
    BXTituloCapa(linhas: ["Seus pontos."],
                 marcadas: ["Compre. Ganhe.", "Envie. Troque."],
                 letreiro: ["Novos destinos.", "Novos sonhos.", "Novas aventuras."])   // + letreiro, + intervaloLetreiro
    BXGradeDados([BXDado("De", "Pontos"), BXDado("Para", "Benefícios"),
                  BXDado("Pagamento", "Cartão ou transferência"), BXDado("Mensalidade", "Nenhuma")])
    Text("Compre pontos, envie para quem você quiser…").bxFonte(.lead).foregroundStyle(BXCor.cinza)
} canhoto: {
    BXDadosCanhoto([BXDado("Passageiro", "Você"), BXDado("Portão", "Cadastro"), BXDado("Assento", "Livre")])  // +
    VStack(spacing: 12) {
        BXBotao("Começar agora", estilo: .cartao) { nav.ir(.cadastro) }
        BXLinkCanhoto(prefixo: "Já tenho conta", titulo: "Entrar") { nav.ir(.entrar) }                       // +
    }
}
BXLetreiro(prefixo: "Novos", palavras: ["destinos.", "sonhos."])   // contrato; + BXLetreiro(frases:)
```

Título: uma linha por `Text`, passo de 0,9 em (espaçamento negativo calculado da altura real da fonte),
`lineLimit(1)` + `minimumScaleFactor(0.6)`; em tamanhos de acessibilidade, quebra livre. Letreiro: para com
Reduzir Movimento, fora da tela (`onScrollVisibilityChange`) e enquanto rola (posição mudou há < 0,4 s).

### 3.5 Formas

```swift
BXPicote(.horizontal) ; BXPicote(.vertical, recorte: 28)
VStack { … BXPicote(.horizontal) … }.bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha, sombra: .padrao)   // +
BXSerrilha(borda: .top).fill(BXCor.tinta).frame(height: 12)
BXCodigoBarras(altura: 36) ; BXCodigoBarras(altura: 28, cor: BXCor.papel)
BXTracejado() ; BXTracejado(cor: BXCor.linha)
```

Medidas tiradas das fotos do web: tracejado 2 pt com traço 6/vão 4; código de barras 2-2-3-2-1-4 (14 pt);
dente da serrilha em V de 90°, meia-base 2,5 pt a cada 12 pt.

### 3.6 Bilhetes

```swift
BXBilhetePacote(pacote: p, selecionado: p.chave == escolhido) { escolhido = p.chave }
BXBilheteCampanha(campanha: c, indice: 1, total: 3) { nav.ir(.campanhas) }
BXBilheteCampanha(nome:descricao:pontos:indice:total:acao:)          // + valores já sanitizados
BXBilhete(canhoto: .icone(.voucher), acao: { nav.ir(.beneficio(id: b.id)) }) { … miolo … }
BXBilhete(canhoto: .favorito(fav, alternar: { favoritos.alternar(p.id) }), acao: { nav.ir(.parceiro(id: p.id)) }) {
    HStack(spacing: 14) { BXIcone(p.icone, tamanho: .cartao); VStack(alignment: .leading) { … } }
}
```

Bilhete de pacote: só "BX · PLUS", pontos + "pts", "TARIFA" + preço (sem linha de bônus, D07; sem 2ª linha de
meio de pagamento, porque "PIX" não pode aparecer fora de Movimentar). Bilhete de campanha segue o web
(número grande "+500 pts ao concluir"), não o chip da spec. Seleção: mola + visto com escala; sem
`matchedGeometryEffect` entre bilhetes (o recorte do cartão cortaria o movimento).

### 3.7 Recibo

```swift
BXRecibo(cabeca: "Extrato da sua compra",
         acao: .init(titulo: "Comprar \(BXFormato.pontos(p.pontos)) pts →") { comprar(p) }) {
    BXReciboTracejo()
    BXReciboLinha("Pacote", p.rotulo)
    BXReciboLinha("Pontos", BXFormato.pontos(p.pontos))
    BXReciboLinha("Mensalidade", "nenhuma")
    BXReciboTracejo()
    BXReciboTotal("Total", BXFormato.dinheiro(p.preco))
    BXReciboFaixa("Pontos na conta", BXFormato.pontos(p.pontos))
    BXReciboNota("Os pontos do pacote já incluem o bônus. …")
    BXReciboVia()
}
```

Rótulos em MAIÚSC só na tela; cada linha é um elemento "Rótulo, valor" para o VoiceOver. Linha com altura
mínima de 20 (passo do Space Mono 13 do web). Nunca linha de valor do ponto nem de taxa.

### 3.8 Rota, painel e quadro

```swift
BXRotaEscalas([BXEscala(id: 1, rotulo: "Escala 01 · Comprar", palavra: "Compre", texto: "…"), …])
BXPainel(rotulo: "Painel de partidas · Mapa", titulo: "Seus pontos, o mundo inteiro.") {
    BXNumeroDestaque("27", legenda: "cidades no mapa")
    BXLegendaCor(BXCor.neon, "Em implantação")                                    // +
    BXTracejado(cor: BXCor.linha)
    BXQuadroPreto(linhas: cidades, selecionada: $cidade) { linha in              // + alturaMaxima (300)
        BXQuadroInfo(titulo: linha?.destino ?? "Escolha uma cidade", texto: "…",
                     link: linha?.ativa == true ? (titulo: "Ver parceiros", acao: { … }) : nil)   // +
    }
}
```

### 3.9 Rótulos, chips, status, pílulas, abas, progresso

```swift
BXRotulo("Destino · nome da marca") ; BXRotulo("Rota · Como funciona", .secao)
BXChip("Carteira BlaXx", .eyebrow) ; BXChip("Olá, \(nome)", .saudacao) ; BXChip("Em processamento", .preto) ; BXChip("+5.000 pts", .neon)
BXStatus("Ativa", .ok) ; BXStatus("Esgotado", .perigo) ; BXStatus("Novo", .info, ponto: false)
@Namespace var pilulas
BXPilula("Todos", contador: 266, ativa: f == .todos, animacao: pilulas) { withAnimation(BXMovimento.mola) { f = .todos } }  // + animacao
BXPilula("Mais categorias", contador: 30, ativa: false, tracejada: true) { maisCategorias = true }
BXPilula("Não lidas", ativa: soNaoLidas, estilo: .conta) { … }
BXAbas(selecao: $filtro, opcoes: [(.tudo, "Tudo"), (.entradas, "Entradas"), (.saidas, "Saídas")])
BXAbas(selecao: $aba, opcoes: [(.catalogo, "Catálogo"), (.meusResgates, "Meus resgates")], ativo: .neon)
BXProgresso(fracao: 0.49)
```

### 3.10 Botões e campos

```swift
BXBotao("+ Comprar pontos") { … }                          // .primario
BXBotao("Entrar →", estilo: .preto, carregando: entrando) { … }
BXBotao("Receber", estilo: .vazadoSobrePreto, icone: .receber) { … }
BXBotao("Excluir minha conta", estilo: .perigo) { … }.disabled(!confirmou)    // 0,45 no botão inteiro
Button { … } label: { … }.buttonStyle(BXEstiloBotao(estilo: .secundario))     // rótulo próprio
BXLinkSeta("Ver extrato completo") { nav.ir(.extrato()) }  // 16 + sublinhado 2 pt, como o web

BXCampo("E-mail ou CPF", texto: $login, tipo: .emailOuCPF)
BXCampo("Senha", texto: $senha, tipo: .senha, erro: erroSenha)      // SecureField + "Mostrar"; háptica de erro
BXCampo("CPF", texto: $cpf, tipo: .cpf)                              // máscara 000.000.000-00
BXCampo("Mensagem (opcional)", texto: $msg, tipo: .mensagem(limite: 140))
BXCampoBusca(texto: $busca, placeholder: "Buscar parceiro ou loja")
BXCampoCodigo(codigo: $codigo)                                       // 6 caixas, .oneTimeCode
Toggle("Avisos", isOn: $ligado).toggleStyle(BXInterruptorEstilo())
```

### 3.11 Estados

```swift
@State var carga: BXCarga<[BXLancamento]> = .carregando
BXConteudo(carga,
           vazio: BXEstadoVazio(icone: .extrato, titulo: "Nenhum movimento ainda.",
                                acao: (titulo: "Comprar pontos", executar: { nav.ir(.comprar()) })),
           tentarDeNovo: { await carregar() }) {
    ForEach(0..<6, id: \.self) { _ in BXEsqueleto(.linhaExtrato) }
} pronto: { itens in Lista(itens) }

BXFaixaOffline(verificando: con.verificando) { con.verificar() }
@State var toast = BXToastCentral()     // injetado pela casca
raiz.bxToastHost(toast) ; toast.mostrar("Código copiado.") ; toast.mostrar("…", .erro)
```

### 3.12 Chrome

```swift
NavigationStack(path: …) {
    tela.bxBarraTopo(.raizLogado, naoLidas: sessao.naoLidas, inicial: sessao.usuario?.primeiroNome,
                     aoSino: { nav.ir(.notificacoes) }, aoAvatar: { nav.ir(.perfil) },
                     aoEntrar: {}, aoMenu: {})
}
.safeAreaInset(edge: .bottom, spacing: 0) {
    BXTabBar(selecionada: $nav.aba, aoTocarMenu: { nav.abrirGaveta() }, aoRetocar: { _ in nav.voltarParaRaiz() })
}
.overlay { BXGavetaConteiner(aberta: $nav.gavetaAberta, lado: .esquerda) {
    BXGavetaGrupo("Conta"); BXGavetaItem("Início", atual: true) { … }; …   // + grupo e item prontos
} }
BXBarraUtilitaria()                                            // "● Rede em expansão"
BXCabecalhoPagina(eyebrow: "Extrato", titulo: "Cada ponto, rastreado.", lead: nil)
BXSecao(rotulo: "Rota · Como funciona", titulo: "…", link: ("Valor livre", { … })) { … }
BXCartaoClaro(icone: .extrato, titulo: "Extrato", texto: "Veja todos os movimentos.") { nav.ir(.extrato()) }
BXCartaoClaro(icone: .usuarioMais, titulo: "Cadastro em minutos", texto: "…", tamanhoIcone: .padrao)   // + tamanhoIcone
BXRodapeRecibo()
```

A barra do topo usa a do sistema (`.toolbarBackground` tinta visível, `.toolbarColorScheme(.dark)`,
itens com `.sharedBackgroundVisibility(.hidden)` para não ganharem a cápsula de vidro do iOS 26) e limita o
Dynamic Type dos itens a `.xxLarge`. Barra de abas: Large Content Viewer em cada item, `.selection` na troca.

### 3.13 Interação e formato

```swift
BXHaptica.tocar(.sucesso)
Text("32.480").bxFonte(.saldoMono).bxTextoNeon()            // só sobre tinta
BXNumeroAnimado(sessao.carteira?.saldo, estilo: .numeroGrande, sufixo: "pontos",
                contarNaEntrada: !sessao.carteiraDoCache)  // + contarNaEntrada, + corSufixo
BXCopiar.copiar(voucher.codigo, aviso: "Código copiado.", toast: toast)
BXQRCode("blaxxpontos://enviar?para=DE0A11C2", lado: 220)
BXCompartilharImagem.imagem(de: recibo)
BXFormato.pontos(32480) "32.480" · .pontosComUnidade · .pontosSinal(-353) "−353" · + .pontosFalados "32.480 pontos"
BXFormato.dinheiro(470) "R$ 470,00" · .data · .dataHora "22 out · 14:05" · + .hora · .relativo · .dia "Hoje"
BXFormato.agruparPorDia(itens, data: \.criadoEm)   // +
BXFormato.cartao("de0a11c2-…") "DE0A 11C2" · .cpfMascarado · .celularMascarado · .iso8601
BXFormato.mascaraCPF / .mascaraCelular / .mascaraPontos / .mascaraDinheiro / .decimalDeDinheiro   // +
```

### 3.14 Núcleo mínimo

`BXAba` (4 abas), `BXErro` completo com `mensagemParaUsuario`, `BXPacote` (decodifica `/pix/packages`
pela chave do objeto, `ordenar`), `BXCampanha` (sem `mechanic`/`target_brl`/`progress_brl`; `nomeSeguro`,
`descricaoSegura`, `diasRestantes`), `BXRecursos`/`BXAmbiente`, `BXSanitizador` (filtros de texto).

---

## 4. Fotos (`docs/redesenho/fotos-fundacao/`)

- `G0-01…G0-18-*.png`: as 18 páginas da galeria (iPhone 17 Pro, 3x, modo sistema).
- `G0-05/08/10/18-*-embarcada.png`: as mesmas páginas com Archivo + Space Mono (para a D16).
- `G0-AX-04/05/08-*.png`: tamanho de acessibilidade AX5 (barra de abas limitada a xxLarge).
- `comparacao-01…09-*.png`: web (fotos-web) × app lado a lado: cartão de embarque, rota, bilhetes,
  bilhete de benefício e cartão de parceiro, recibo, painel e quadro, chrome (topo + barra de abas a 3x),
  folha de ícones, 6 ícones ampliados com diferença de pixels.

## 5. O que fica para depois (não está nesta entrega)

- Núcleo de rede e sessão (§1.7): `BXAPI` (actor, renovação single-flight, idempotência, pinning),
  `BXAPI+Rotas`, `BXCofre`, `BXSessao`, `BXConectividade`, `BXCacheCarteira`, o resto de `BXModelos`,
  `BXSanitizador` (mapas de categoria/ícone/rótulo) e `BXNavegacao` (`BXDestino`, `BXNavegacao`).
- Modo demonstração completo (§4): `BXTransporteDemo`, `BXDemoDados`, roteamento de `-BXTela`/`-BXSubtela`.
- Os quatro esqueletos `R/Telas/{Saldo,Movimentar,Descobrir,Conta}/BXTelas*.swift` (§1.8): cada grupo cria o seu.
- Decisões do dono que afetam o DS: D16 (família tipográfica; trocar `BXFonte.modoPadrao`), D07 (texto de
  bônus do pacote), D01 (C6 cancelou a homologação PIX: o novo cadastro no portal Developers é do dono).
