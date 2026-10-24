# 02 · Inventário do Web Mobile (375 px) — referência de design e funcionalidade para o app iOS

Data: 22/10/2026 · Fonte: `blaxx/` servido em `http://localhost:8799` (tema "Embarque": `assets/blaxx-embarque.css` + chrome de `assets/blaxx-nav.js`).
Somente leitura: nenhum arquivo do site, do backend ou do app foi alterado.

## Como as fotos foram feitas

- Chrome headless, viewport **375 × 812**, `deviceScaleFactor 1`, `mobile:true`, service worker ignorado, cache desligado. Os recortes de componente (90 e 93) e a folha de ícones (95) saíram em 2x/3x para ver detalhe.
- Página inteira em partes: rola de 640 em 640 px e fotografa a janela, por isso a barra do topo (sticky) e a barra de abas (fixa) aparecem em toda parte, como no celular. Nome: `NN-tela-PP.png` (PP = parte).
- "Logado" = sessão simulada no `localStorage` (`blaxx_token`, `blaxx_user` "Cliente Teste", `teste@exemplo.test`). A API local (:5050) não roda.
- **Proxy só de leitura**: as chamadas da página para `localhost:5050` e para `blaxx-pontos-exe.onrender.com` foram interceptadas. Só `GET` público (`/pix/packages`, `/partners/`, `/partners/<id>`, `/partners/categories`, `/benefits/`, `/campaigns/`) foi atendido com a resposta pública de produção, buscada **sem token**. Todo o resto (inclusive qualquer POST/PUT/PATCH/DELETE) foi derrubado antes de sair da máquina: 0 requisições de escrita chegaram a produção. Por isso parceiros, benefícios, campanhas e pacotes aparecem com dados reais, e saldo, extrato, perfil e notificações aparecem no estado "sem resposta".
- A faixa "Conexão instável" foi escondida nas fotos de tela (ela tem foto própria, `94-faixa-offline.png`).
- `pagamento-pix.html` foi fotografada com o `blaxx-app.js` bloqueado (sem cobrança ativa ela redireciona em 1,5 s). `confirmar-envio.html` recebeu um fluxo de teste (`destinatario@exemplo.test`, 100 pts, sem senha) para mostrar a revisão real.

Pasta: `docs/redesenho/fotos-web/` (204 PNG, 9,7 MB).

| Fotos | Tela | Estado |
|---|---|---|
| 01-home-visitante-01…10 | home-embarque.html | visitante |
| 02-login-01…03 | login.html | visitante |
| 03-cadastro-passo1/2/3 | cadastro.html (3 passos) | visitante |
| 04-recuperar-senha-01…02 | recuperar-senha.html | visitante |
| 10-dashboard-01…07 | dashboard.html | logado |
| 11-carteira-01…05 | carteira.html | logado |
| 12-extrato-01…03 | extrato.html | logado |
| 13-parceiros-01…09 | parceiros.html | logado, 266 parceiros reais |
| 14-detalhe-parceiro-acer-01…05 | detalhe-parceiro.html?id=d1f5ecb2… (ACER, real, sem benefício) | logado |
| 14b-detalhe-parceiro-com-beneficios-ficticio-01…06 | detalhe-parceiro.html?id=36b28812… (FarmaPlus, **fictício**, só para mostrar o bilhete de benefício) | logado |
| 15-resgates-01…08 | resgates.html (catálogo /benefits/) | logado |
| 16 a 19 | beneficio-detalhe, confirmar-resgate, resgate-concluido, meus-resgates | logado (conteúdo fixo de demonstração) |
| 20-comprar-pontos-01…07 | comprar-pontos.html (pacotes da API) | logado |
| 20b-comprar-gaveta-01…04 | comprar.html (o "Comprar pontos" da gaveta) | logado |
| 21-comprar-livre-01…03 | comprar-livre.html (valor livre) | logado |
| 22 a 25 | checkout, pagamento-pix (sem cobrança), pagamento-cartao, compra-aprovada | logado |
| 26-enviar-pontos / 26b-enviar-gaveta / 27-confirmar-envio / 28-envio-concluido | fluxo de envio | logado |
| 29-receber-pontos | receber-pontos.html | logado (demo) |
| 30-venda-pontos-01…11 | venda-pontos.html (B2B) | logado |
| 31-campanhas-01…04 | campanhas.html (/campaigns/ real) | logado |
| 32-indique / 32b-indique-ganhe | as duas versões de "Indique e ganhe" | logado |
| 33-perfil / 34-seguranca / 35-central-notificacoes / 36-central-ajuda / 37-cartao | conta | logado |
| 38-detalhe-transacao / 39-detalhe-voucher / 40-saldo-insuficiente | telas de apoio | logado (demo) |
| 90-tabbar-logado | barra de abas (3x) | |
| 91-gaveta-logado-1/2 | gaveta logado (abre pela esquerda), topo e fim | |
| 92-gaveta-visitante | gaveta visitante (abre pela direita) | |
| 93-topo-logado / 93-topo-visitante | barra utilitária + barra preta (3x) | |
| 94-faixa-offline | faixa "Conexão instável" sobre o painel | |
| 95-icones-folha | os 51 desenhos de `icones.json` no quadrado neon (2x) | |

Arquivos irmãos: `docs/redesenho/icones.json` (objeto `ICONES` de `assets/blaxx-nav.js`, 50 desenhos, mais `menu` da barra de abas = 51) e `docs/redesenho/medidas-computadas-375.txt` (estilo computado de ~300 seletores em 14 telas: tamanho, fonte, cor, raio, padding, sombra), que é a fonte das medidas abaixo.

---

## 0. Achados que mudam o que o app deve copiar

1. **A API de produção traz conteúdo que as regras proíbem.** `GET /partners/` (266 itens): 258 com `description` "Parceiro Livelo · slug", 8 com "… fictícia usada nos exemplos do catálogo" (AeroFly, EduMais, FarmaPlus, FlixZone, PostoBR, Pão & Cia, ShopVerde, Sabor Local), **todos** com `accrual_rule` ("2 pts/R$", "1 pt a cada R$ 1,15…") e `logo_emoji`. `GET /benefits/` (10 itens): 8 pertencem aos parceiros fictícios, 2 são da própria BlaXx (Sorteio R$ 1.000, Doação Instituto BlaXx), todos com `image_emoji`. `GET /campaigns/` (3): `mechanic` traz valores em reais ("Compre 1 pacote Black (R$ 2.142,00)…"), e uma se chama "Maio em dobro" em outubro (cara de seed). O web limpa a tela com o filtro da seção 6, mas **mostra os nomes dos 8 parceiros fictícios e os benefícios deles**. No app Release, com a regra "nada de parceiro inventado", o catálogo de benefícios fica com 2 itens.
2. **Metade da área logada do web é demonstração com dado inventado**, não tela funcional: painel (Plano Plus/Prime, meta 100.000, campanhas "Supermercado em dobro" e "Postos Shell em dobro", "iFood R$ 50", "2 vouchers ativos"), meus-resgates (Netflix, Starbucks, Carrefour, Spotify), beneficio-detalhe → confirmar-resgate → resgate-concluido (Netflix 12.000 pts), checkout/pagamento-cartao/compra-aprovada (Plus a R$ 49,90), receber-pontos (Mariana, Lucas), indique e indique-ganhe (convidados fictícios), segurança (sessões "iPhone 15 · São Paulo", "2FA ativa desde 12/03/2026", nota 92/100), carteira (32.480 pts, gráfico e "Nexus Airlines" quando a API falha), cartão (estado demo "Ricardo · 16.320 pts · Ouro" quando a API falha), venda-pontos (GMV R$ 2,8M, cases), detalhe-transacao, detalhe-voucher, saldo-insuficiente. Para o app, vale o **layout e o fluxo**; o conteúdo vem da API ou não aparece.
3. **Valor do ponto vaza em três lugares do web** e não pode ir para o app: `comprar.html` (régua "R$ 180 · 2.000 pts" e "+278 pts bônus", calculados com `CENTS_PER_POINT = 9`), `comprar-livre.html` ("Você recebe X pts" calculado no cliente) e `GET /wallet/` (`balance_brl_equiv`). `resgate-pix.html` (saque por transferência, com dica de teste "fail-") ainda existe e acende a aba Resgates; o catálogo de níveis do backend diz "…catálogo de benefícios e PIX". Resgate nunca é PIX.
4. **Bônus dos pacotes tem quatro versões no web.** Home e mega-menu: "cerca de 5%" (Plus) e "cerca de 10%" (Prime). comprar-pontos: "+10% / +20% / +40%" e "até 15% de bônus". checkout: "+10%". Painel: "+20% de bônus em todas as compras". A conta real com `/pix/packages`: Plus +5,3%, Prime +11,1%, Black +17,6% sobre o Start. A home mostra 3 pacotes; a API tem 4 (Black, R$ 2.142, 28.000 pts).
5. **Duas ou três páginas para a mesma função**, e a navegação aponta para versões diferentes: gaveta → `comprar.html`, `enviar.html`, `indique.html`; barra de abas e lateral → `comprar-pontos.html` (→ `comprar-livre.html?pkg=`), `enviar-pontos.html`, `indique-ganhe.html`. Também `central-notificacoes.html` × `notificacoes.html`, `detalhe-parceiro.html` × `parceiro-detalhe.html`, `beneficio-detalhe.html` × `detalhe-beneficio.html`. O app deve ter uma tela por função (seção 7).
6. **Níveis**: o painel e a carteira do web falam em "Plano Plus / Plano Prime" (nomes de pacote). O backend tem níveis de verdade em `GET /card/` e `GET /card/tiers`: Bronze (0), Prata (5.000), Ouro (20.000), Black (50.000), BlaXx VIP (convite). O app deve usar `/card/`.
7. **Margem lateral não é uma só**: 16 px (home, painel, detalhe do parceiro), 22 px (parceiros), 40 px (as páginas do `chrome.js`: carteira, extrato, resgates, campanhas, perfil, segurança, notificações). O tema manda 16 px no celular; recomendo 16 pt no app.
8. **Segurança**: o envio de pontos do web guarda a **senha da conta** em `sessionStorage` (`blaxx_flow_transfer_pending`) entre a tela de envio e a de confirmação. Não repetir: no app a senha vai direto no `POST /transfer/` e não é persistida.
9. Detalhes visuais a não copiar: filtros de resgates com a categoria crua da API ("educacao", "experiencia", minúsculas e sem acento); "R$ 2142,00" sem separador de milhar em comprar-pontos; na gaveta logada o "×" fica colado na borda; a confirmação de envio real aparece **em cima** do conteúdo fixo de demonstração (Lucas Andrade) que continua embaixo.
10. **Fontes**: o web usa **Archivo** (variável, eixo de largura: o título é 900 a 80%) + **Space Mono**, por decisão registrada no próprio CSS ("Space Grotesk não tem esse eixo"). O Brand Book diz Space Grotesk. Para o app parecer o web, embutir Archivo e Space Mono (OFL) no bundle. A carga por `@import` do Google Fonts atrasa a página: `seguranca.html` ficou mais de 5 s em `readyState=loading`.

---

## 1. Tokens (exatos, de `assets/blaxx-embarque.css`)

### 1.1 Cores

| Token | Valor | Uso |
|---|---|---|
| `--bx-bg` | `#E4E1D9` | chão de toda página |
| `--bx-surface` | `#FBFAF7` | cartões, gaveta, campos, recibo |
| `--bx-surface-2` | `#F4F2EC` | hover, fundo de campo de busca, trilho de progresso |
| `--bx-line` | `#D9D6CE` | contornos de 1px e picote |
| `--bx-leader` | `#B9B6AE` | pontilhado do recibo, tracejado do "Mais categorias" |
| `--bx-grey` | `#555860` | texto secundário (5,45:1 no chão, 6,76:1 no cartão) |
| `--bx-grey-soft` | `#5F6168` | só ícone e decoração, nunca texto |
| `--bx-ink` | `#0A0B0E` | preto da marca: texto, barras, painéis |
| `--bx-ink-2` | `#2A2D35` | linha sobre preto |
| `--bx-ink-3` | `#3A3D46` | tracejado sobre preto |
| `--bx-ink-muted` | `#8A8D96` | texto secundário sobre preto (5,9:1) e rótulo inativo da barra de abas |
| `--bx-bar-fg` | `#C9CBD1` | texto da barra utilitária e da cabeça do recibo |
| papel (sem token) | `#F4F2EC` | texto principal sobre preto |
| `--bx-neon` | `#59FD27` | **só preenchimento** sobre claro; texto neon só sobre preto |
| hover neon (literal) | `#4FE81F` | botão neon pressionado |
| `--bx-neon-deep` | `#5AB800` | estado `:active` do botão neon; nunca texto |
| `--bx-azul` | `#8EC3EA` | esfera do globo (`sphHi #E3F1FC`, `sphLo #4A93D1`, terra `rgba(15,50,90,.85)`) |
| ok | fundo `#E4F5DA`, texto `#1f6b14` | status "Ativa", valores positivos (`--pos`) |
| aviso | fundo `#F7EFD6`, texto `#7a5a00` | alerta, "12 DIAS" |
| perigo | fundo `#F6DFD6`, texto `#9a2f15` | erro, valores negativos (`--neg`) |
| info | fundo `#DCE8F3`, texto `#1b4a80` | toast info |
| `--lime-soft` | `#EEF7E2` | fundo do chip "Olá, Cliente" |
| quadro preto | linha `#1C1F25`, hover `#15171C`, rodapé de info `#111318`, chip `#1A1D23`, bolinha apagada `#4A4D55` | painel de partidas |
| scrim | `rgba(10,11,14,.45)` | atrás da gaveta |
| legenda do mapa | Postos `rgb(231,178,74)`, Supermercados `rgb(79,201,106)`, Farmácias `rgb(63,198,216)`, Rede em expansão `#0A0B0E` | globo |

### 1.2 Tipografia

- Famílias: `--bx-sans: 'Archivo'` (wght 400–900, wdth 62–125) e `--bx-mono: 'Space Mono'` (400, 700).
- Assinaturas: título de capa = Archivo **900, font-stretch 80%**, `letter-spacing -.03em`, `line-height .9`; título de página = Archivo 800, stretch 88%, `line-height 1`, `-.03em`; rótulos = Space Mono MAIÚSCULAS com `letter-spacing .08–.1em`.

Tamanhos medidos a 375 px (computados no navegador):

| Papel | Medida |
|---|---|
| Título de capa (`.bx-cartao-titulo`, letreiro da home) | 55,5 px / 900 / 80% / lh 49,95 / ls −1,665 (`clamp(40px,14.8vw,64px)`) |
| Linha neon do título (`mark`) | 0,66em = 36,6 px, lh 1,24–1,28, padding `.05em .18em`, fundo neon |
| Título de página (`h1`) | 30 px / 800 / 88% / lh 1 / ls −0,9 (`clamp(28px,8vw,34px)`) |
| Título de seção do kit (`.bx-titulo-secao`, h2 da home) | 34 px / 800 / lh 1 / ls −1,02 |
| h2 das páginas de conta | 22 px / 800 |
| Rótulo de seção (`.bx-secao-rotulo`) | Space Mono 13 px / ls 1,04 / MAIÚSC / cinza |
| Rótulo de dado (`.bx-rotulo`) | Space Mono 11 px / ls 1,1 (10 px na grade do cartão) / MAIÚSC / cinza |
| Valor de dado (`.bx-rotulo + b`) | 14 px / 700 / lh 1,3 no celular (22 px no desktop) |
| Lead | 16 px / lh 1,5 / cinza |
| Corpo | 15 px (páginas de conta) e 16 px (kit) |
| Rótulo de campo (`label`) | Space Mono 11 px / ls 1,1 / MAIÚSC / cinza |
| Campo (`input`) | 16 px / 500 (16 px evita o zoom do iOS) |
| Botão | 15 px / 700; CTA do cartão 16 px / 700; ação do recibo 17 px / 700 MAIÚSC |
| Número grande (saldo no painel) | 41 px / 800 / ls −1,65 |
| Saldo na carteira | Space Mono 45 px / 700, **neon sobre preto** |
| Pontos no bilhete | 34 px / 800 (`small` "pts" 18 px / 600 / cinza) |
| Total do recibo | 36 px / 900 / ls −1,08 |
| Rótulo da barra de abas | Space Mono 11 px / ls .04em / MAIÚSC |

### 1.3 Raios, sombras, movimento, espaçamento

| Token | Valor |
|---|---|
| `--bx-r-xl` | 28 px (cartão de embarque e painel no desktop; **24 px no celular ≤600**) |
| `--bx-r-lg` | 18 px (cartões, bilhetes, quadro, recibo de partidas, convites) |
| `--bx-r-md` | 14 px (mega-menu, FAQ) |
| `--bx-r-sm` | 12 px (botão `.button`, campo, quadrado de ícone 44 px, CTA do cartão) |
| `--bx-r-xs` | 10 px (item da gaveta, item da barra de abas) |
| `--bx-r-xxs` | 8 px (botão `.btn`, "Criar conta", pílula de filtro do kit, quadrado do ícone da aba) |
| pílula | 999 px (chips, status, abas segmentadas, sino, chip do usuário) |
| `--bx-sh` | `0 18px 40px rgba(10,11,14,.08)` |
| `--bx-sh-lg` | `0 24px 48px rgba(10,11,14,.12)` |
| `--sh-1` | `0 6px 16px rgba(10,11,14,.05)` |
| recibo | `filter: drop-shadow(0 18px 30px rgba(10,11,14,.12))`, `rotate(1deg)` só acima de 1000 px |
| `--bx-ease` | `cubic-bezier(.2,.75,.2,1)` (mega-menu .22s, gaveta .2s ease-out, letreiro .55s) |
| margem lateral | 16 px no celular (`clamp(16px,4.4vw,56px)`) |
| ritmo | seção `padding-bottom` 40 px (≤600), cabeçalho de seção 24 px abaixo, cartão `padding 18 px`, grade de cartões `gap 12 px` |
| alvo de toque | botões 48 px de altura mínima, chips 44 px, item da gaveta 48 px, item da aba 52 px |
| quebras | 1000 / 900 / 880 (celular: aparece a barra de abas, some a lateral) / 600 / 520 / 480 |

---

## 2. Componentes (com medidas a 375 px)

### 2.1 Cartão de embarque (`.bx-cartao`; na home `.cartao`)
- Fundo surface, raio 24, sombra `--bx-sh`, 343 px de largura (16 de margem). No celular empilha: **miolo** em cima, **picote horizontal**, **canhoto** embaixo.
- Miolo: padding 22/16/24, gap 20. Ordem: linha de topo em mono 11 px MAIÚSC cinza com dois textos ("Cartão de embarque · BlaXx Pontos" | "Brasil · 2026"); título de capa (uma linha por `<span>`, última linha com `mark` neon); grade 2 × 2 (gap 16/14, `border-top 1px line`, padding-top 18) de pares rótulo/valor ("De Pontos · Para Benefícios · Pagamento Cartão ou transferência · Mensalidade Nenhuma"); lead 16 px cinza.
- Picote (`.bx-perf` virado): `border-top 2px dashed --bx-line` e dois recortes redondos de 28 px na cor do chão (`--bx-perf-fundo`, padrão `--bx-bg`) saindo 14 px para fora nas pontas.
- Canhoto: padding 20/20/22, gap 18. Dados em linha (Passageiro Você · Portão Cadastro · Assento Livre), CTA neon (raio 12, padding 16, 16 px/700, 49 px de altura), "Já tenho conta · **Entrar →**" 15 px, código de barras 36 px.
- Código de barras (`--bx-barcode`): gradiente repetido de 14 px: 2 preto, 2 vazio, 3 preto, 2 vazio, 1 preto, 4 vazio. No rodapé o mesmo desenho em papel `#F4F2EC`.
- Variações vistas: home (visitante), parceiros (canhoto vira "Seus pontos / Pendentes / Nível atual / Progresso" para quem entrou, com "Ver carteira" e "Resgatar pontos →"), detalhe do parceiro (quadrado de categoria 52 px + nome do parceiro no título, grade "De Seus pontos · Para Benefícios · Disponíveis N benefícios · A partir de X pts", canhoto "Passageiro Você · Destino <parceiro>").
- Micro-interação da home: a 2ª linha alterna "Novos destinos / Novos sonhos / Novas aventuras" a cada 2,6 s, subindo (0,55 s); para com movimento reduzido, sob o dedo e fora da tela.

### 2.2 Rota com escalas (`.bx-rota-grid` / `.bx-escala`)
- No celular é linha do tempo vertical. Cada escala: rótulo mono 12 px MAIÚSC cinza com recuo de 38 ("ESCALA 01 · COMPRAR"), ação = ponto 24 px preto (o último é neon com borda preta) + palavra 34 px/800 com fundo da cor do chão (padding 0 14), descrição 15 px cinza com recuo 38.
- Tracejado vertical `2px dashed ink` ligando os pontos (x = 11 px, de 41 px abaixo do topo da escala até a próxima), padding-bottom 30 por escala.
- Usada na home (Compre, Ganhe, Envie, Troque), em parceiros (Busque, Filtre, Favorite, Confira) e no detalhe do parceiro (Tenha, Escolha, Confirme, Troque).

### 2.3 Bilhete com canhoto (`.bx-bilhete`)
- Linha flex: miolo (padding 16/16/14, gap 8) + picote vertical (2 px tracejado, recortes de 28 px em cima e embaixo) + canhoto (56 px de largura no ≤600; 96 px no desktop).
- Fundo surface, raio 18, borda 2 px transparente → **preta quando selecionado**; foco com contorno 3 px preto.
- Miolo: cabeçalho mono 11 px MAIÚSC cinza (no ≤600 empilha: "BX · Plus ★" / "cerca de 5% de bônus"), pontos 34 px/800 + "pts" 18 px cinza, par "TARIFA / R$ 470,00" (22 px/700).
- Canhoto: selo redondo 30 px com borda 2 px preta; selecionado = canhoto **neon** e selo preto com visto neon. O texto vertical ("Selecionar") some no ≤600.
- Variações: bilhete de campanha em parceiros (canhoto neon com seta, "+5.000 pts ao concluir", contador "01 de 03", pontos de paginação 28 × 10 e setas em quadrado neon 44 px, gira a cada 6 s), bilhete de benefício no detalhe do parceiro ("BX · Voucher | Popular", nome 19 px/800, "353 pts", "Validade do voucher 90 dias", "Ver benefício →", ícone da categoria no canhoto), cartão de parceiro da lista (abaixo).

### 2.4 Recibo com zigue-zague e cabeça preta (`.bx-recibo`)
- Serrilhado de 12 px em cima e embaixo (dois gradientes de 135°/−135°, período 12 px); com cabeça preta o serrilhado de cima fica preto.
- Corpo surface, Space Mono 13 px, padding 22/16, gap 14.
- Cabeça preta sangrando até a borda (padding 18/16/16): wordmark `blaxx-wordmark-barra.svg` 30 px de altura + legenda mono 12 px `#C9CBD1` ("EXTRATO DA SUA COMPRA", "RESUMO DA LISTA", "FICHA DO PARCEIRO").
- Linha tracejada preta 2 px (`.bx-tracejo`), linhas de recibo `RÓTULO ……… valor` (pontilhado 2 px `#B9B6AE`, gap 8), total ("TOTAL" + 36 px/900), faixa neon que sangra 12 px para os lados ("PONTOS NA CONTA ……… 5.500"), nota 12 px cinza, "VIA DO PASSAGEIRO" entre dois tracejados, botão preto de largura total 56 px, 17 px/700 MAIÚSC ("COMPRAR 5.500 PTS →").
- Regra do próprio CSS: sem linha de valor do ponto e sem "taxa".

### 2.5 Painel de partidas e quadro preto (`.bx-painel`, `.bx-quadro`)
- Painel: surface, borda 1 px, raio 24, padding 20/16, sombra. Topo com rótulo mono + h2 34 px, número grande com fundo neon (44 px/900, "27 cidades no mapa"), legenda mono 12 px com quadradinhos 12 px de raio 3, separador `2px dashed line`.
- Globo: moldura quadrada raio 18, fundo `#F4F2EC`, canvas arrastável (d3 + topojson), dica mono 12 px "Arraste para girar · clique numa cidade…".
- Quadro preto: raio 18, Space Mono 14 px, cabeçalho mono 11 px `#8A8D96` (Destino · País · Situação), linhas MAIÚSC 13 px com padding 12/16 e divisória `#1C1F25`, país 12 px apagado, situação com bolinha 8 px (neon = "Em implantação", cinza = "Em expansão"; o texto some no ≤520), linha ativa toda neon com texto preto, rodapé de informação `#111318` com título 20 px/800 branco, chips e link neon sublinhado. Lista rola por dentro (máx 300 px no ≤600).

### 2.6 Rótulos, pílulas, chips e status
- Rótulo mono MAIÚSC: `.bx-rotulo` 11 px/ls .1em cinza; `.bx-secao-rotulo` 13 px/ls .08em.
- Chip "eyebrow" das páginas de conta: Space Mono 11 px MAIÚSC, fundo `#F4F2EC`, borda 1 px line, pílula, padding 5/12 ("CARTEIRA BLAXX", "EXTRATO").
- Chip do painel "OLÁ, CLIENTE": mono 11 px/700, fundo `#EEF7E2`, borda 1 px neon, padding 8/14.
- Chip preto: fundo preto, texto **neon** (permitido: neon sobre preto) — "EM ANÁLISE", "CLIENTE", "PRÓXIMO NÍVEL".
- Status: `● ATIVA` texto `#1f6b14` em `#E4F5DA`, mono 11 px/700, pílula, padding 6/11; pendente amarelo; estornado vermelho.
- Pílula de filtro do kit (parceiros): mono 11 px MAIÚSC, raio **8**, altura 40, padding 0 12, contador na própria pílula ("TODOS 266"); ativa neon; "MAIS CATEGORIAS +30" com borda tracejada `#B9B6AE`.
- Pílula de filtro das páginas de conta (resgates, notificações): Archivo 13 px/700, pílula 999, altura 44, padding 8/16; ativa neon.
- Abas segmentadas (extrato "Tudo · Entradas · Saídas", resgates "Catálogo · Meus resgates"): trilho surface com borda, padding 5, gap 6; aba ativa preta, 44 px de altura, texto papel (extrato) ou neon (resgates).

### 2.7 Botões e campos
| Botão | Medida |
|---|---|
| Primário neon (`.button`, `.btn--primary`) | neon, texto preto, 15 px/700, raio 12 (`.btn` raio 8), padding 13/20, **48 px mín.**, hover `#4FE81F` |
| Preto (`.button.dark`, `.btn--dark`) | preto, texto surface; é o "Entrar →" do login e o "Continuar →" do cadastro (raio 8, padding 13/22) |
| Secundário (`.button.secondary`, `.btn--outline`) | surface, borda 1 px line, texto preto |
| Vazado sobre preto (`.btn--ghost-dark`) | transparente, borda 1 px `rgba(244,242,236,.35)`, texto papel |
| CTA do cartão (`.bx-cartao-cta`) | neon, raio 12, padding 16, 16 px/700 |
| Ação do recibo (`.bx-recibo-acao`) | preto, sem raio, padding 18, 17 px/700 MAIÚSC |
| "Criar conta" do convite | neon, raio 8, 52 px, 16 px/700, largura total no celular |
| Desabilitado | opacidade .45 |
- Campo: surface, borda 1 px line, raio 12, padding 13/14, 48 px, 16 px/500; foco = borda preta + halo `0 0 0 3px rgba(89,253,39,.35)`. Busca de parceiros: 56 px, 18 px/600, fundo `#F4F2EC`, ícone de lupa em quadrado neon 40 px dentro do campo.
- Interruptor (perfil): 46 × 26, pílula, ligado neon.
- Barra de progresso: trilho `#F4F2EC` com borda line, 12 px, preenchimento neon.

### 2.8 Cartões claros com ícone (atalhos, convite, parceiro)
- Cartão: surface, borda 1 px line, raio 18, padding 18 (16 nos atalhos), sombra só nos cartões grandes.
- Ícone: quadrado **neon 44 px raio 12** com desenho preto de traço a 56% (24 px) — `.bx-ico`. Variantes: 36 px (atalhos do painel, desenho 20), 40 px (cartão de parceiro, lupa), 30 px raio 8 (barra de abas, favorito), 28 px raio 8 (lateral, quadro), 52 px (marca no detalhe do parceiro). Regra: todo ícone é quadrado neon com desenho preto; emoji nunca.
- Convite (visitante, antes do rodapé): rótulo "CRIAR CONTA · SEM MENSALIDADE", h2 32 px "Inicie sua aventura com a BlaXx.", 4 cartões (Cadastro em minutos · Sem mensalidade · Envie para quem quiser · Troque por benefícios), bloco preto final raio 18 ("Pronto para embarcar?" 24 px/800 branco, botão neon "Criar conta →", link "Já tenho conta · Entrar").
- Cartão de parceiro da lista (`.pz-card`): 331 × 69, raio 18, sem sombra. Esquerda: ícone 40 px + nome 17 px/800 + categoria mono 11 px MAIÚSC cinza. Picote vertical. Direita: canhoto 56 px com coração em quadrado neon 30 px (favorito, guardado só no aparelho).

### 2.9 Chrome do celular
- **Barra utilitária** (preta, 28 px): Space Mono 11 px `#C9CBD1`, padding 7/16; no celular só "● Rede em expansão" (bolinha e texto neon sobre preto).
- **Barra do topo** (preta, sticky, 60 px + borda 1 px `#2A2D35` em cima e embaixo, padding 0 16, gap 10): wordmark `assets/marca/blaxx-wordmark-barra.svg` ("Bla" branco, "Xx" neon) a 114 × 22. Direita, visitante: só o hambúrguer (44 px, pílula, borda `#2A2D35`, três traços papel de 2 px). Direita, logado: sino (42 px, círculo **neon** com sino preto) → `central-notificacoes.html`; chip do usuário (42 px, avatar neon 32 px com a inicial) → `perfil.html`; hambúrguer. "Entrar", "Criar conta" e "Sair" saem da barra no celular (vão para a gaveta).
- **Barra de abas** (só logado, ≤880): fixa embaixo, preta, borda superior `#2A2D35`, padding 6/4 + área segura, 72 px no total, 5 colunas iguais. Item: coluna, gap 4, 52 px mín., raio 10. Ícone em quadrado neon 30 px raio 8 padding 5. Rótulo Space Mono 11 px MAIÚSC: **ativo neon**, inativo `#8A8D96`. Itens e quando acendem:
  - Início → `dashboard.html` (dashboard, index)
  - Carteira → `carteira.html` (carteira, extrato)
  - Comprar → `comprar-pontos.html` (comprar-pontos, comprar, comprar-livre, checkout)
  - Resgates → `resgates.html` (resgates, meus-resgates, resgate-pix)
  - Menu → abre a gaveta
- **Gaveta** (`#bxNavDrawer`): logado abre pela **esquerda**, visitante pela **direita**; largura `min(88vw,360px)` = 330 px; fundo surface; padding 14/14/28 (+88 com a barra de abas); "×" 44 px; rótulo de grupo Space Mono 11 px MAIÚSC cinza; link 48 px, raio 10, padding 12/14, Archivo 16 px/600; item atual preto com texto surface; botão "Sair" neon 50 px. Fecha com Esc, toque no scrim, "×"; trava a rolagem; foco preso.
  - Logado: **Conta** Início, Carteira, Extrato, Cartão BlaXx, Perfil · **Pontos** Comprar pontos (`comprar.html`), Enviar pontos (`enviar.html`), Resgatar benefícios (`resgates.html`), Indique e ganhe (`indique.html`) · **Descobrir** Parceiros, Campanhas · **Ajuda** Central de ajuda, Perguntas frequentes, Abrir chamado · **Sair**.
  - Visitante: "Criar conta" (neon) e "Entrar" (vazado) no topo · **Conheça** Comprar pontos, Como funciona, Parceiros, Regulamento · **Ajuda** Central de ajuda, Perguntas frequentes, Fale conosco.
- **Rodapé-recibo** (preto de borda a borda): logo completo `blaxx-logo-completo-justo.svg` 80 px de altura, frase "Um programa de recompensas simples: compre pontos, envie para quem quiser e troque por benefícios em parceiros selecionados. Sem letra miúda." (15 px `#8A8D96`), colunas PRODUTO / AJUDA / LEGAL (cabeça Space Mono 12 px papel, links 15 px `#8A8D96`, todos para páginas "sobre-*"), base "© 2026 BlaXx Pontos" + código de barras papel 200 × 28 + aviso legal 12 px ("Os pontos BlaXx não são moeda, depósito, investimento, valor mobiliário ou criptoativo. São créditos promocionais de uso restrito dentro da plataforma BlaXx."). Com a barra de abas ganha 66 px a mais embaixo.
- **Faixa offline** (`#bx-offline-banner`, foto 94): aparece após 3 falhas seguidas; no celular fica no pé, acima das abas, 12 px das bordas, raio 12, fundo aviso; "Conexão instável com o servidor. Tentando reconectar…" + botão "Verificar agora"; tenta `/health` a cada 30 s por até 5 min.
- **Toast** (`notify`): fixo no topo direito, raio 14, 14 px/600, cores de status, some em 4 s; erro com `role=alert`.
- **Estados padrão**: esqueleto (blocos `--bx-surface-2` animados), vazio (cartão tracejado com texto cinza centralizado), erro com "Tentar de novo" (ícone de alerta no quadrado neon).

---

## 3. Navegação: destinos por tela

| Função | Gaveta | Abas | Lateral (desktop) | Barra desktop logado |
|---|---|---|---|---|
| Início | dashboard | dashboard | dashboard | dashboard |
| Carteira | carteira | carteira | carteira | — |
| Extrato | extrato | (acende Carteira) | extrato | — |
| Comprar | **comprar.html** | **comprar-pontos.html** | comprar-pontos | comprar-pontos |
| Enviar | **enviar.html** | — | **enviar-pontos.html** | — |
| Resgates | resgates | resgates | resgates + meus-resgates | resgates |
| Indique | **indique.html** | — | **indique-ganhe.html** | — |
| Parceiros / Campanhas | sim / sim | — | sim / sim | parceiros |
| Cartão BlaXx | cartao | — | — | — |
| Perfil / Segurança | perfil / — | — | perfil / seguranca | — |
| Notificações | sino no topo | — | — | sino |
| Vender pontos (B2B) | — | — | — | venda-pontos |

Visitante que toca em página protegida vai para `login.html?next=/<página>` (`assets/blaxx-acesso.js`, 29 páginas protegidas + 20 "de conta"). Logado em login/cadastro volta para `dashboard.html`.

---

## 4. Telas

Formato: **seções em ordem** · componentes · textos-chave · ações · endpoints · estados · alertas.

### 4.1 Home — `home-embarque.html` (visitante) · fotos 01-01…10
1. Barra utilitária + barra preta (wordmark, hambúrguer).
2. **Cartão de embarque** (2.1): "Cartão de embarque · BlaXx Pontos | Brasil · 2026"; título "Seus pontos. / Novos destinos·sonhos·aventuras. / Compre. Ganhe. Envie. Troque." (neon); grade De Pontos · Para Benefícios · Pagamento Cartão ou transferência · Mensalidade Nenhuma; lead "Compre pontos, envie para quem você quiser e troque por benefícios em parceiros selecionados. O que você vê é o que você paga."; canhoto Passageiro Você · Portão Cadastro · Assento Livre, CTA "Começar agora" → cadastro, "Já tenho conta · Entrar →", código de barras.
3. **Rota · Como funciona** (2.2): Compre (Pacotes ou valor livre. Pagamento com cartão ou transferência.) · Ganhe (Bônus nos pacotes maiores e pontos extras nas campanhas.) · Envie (Mande pontos para quem você quiser, entre contas BlaXx.) · Troque (Benefícios e experiências em parceiros selecionados.).
4. **Pacotes + recibo**: h2 "Escolha o seu ponto de partida." + link "Valor livre →"; 3 bilhetes Start 2.000 / R$ 180,00 · Plus ★ 5.500 / R$ 470,00 "cerca de 5% de bônus" (marcado) · Prime 12.000 / R$ 972,00 "cerca de 10% de bônus"; recibo "EXTRATO DA SUA COMPRA" (Pacote, Pontos, Bônus, Pagamento cartão ou transferência, Mensalidade nenhuma, TOTAL, faixa PONTOS NA CONTA, nota "Os pontos do pacote já incluem o bônus…", VIA DO PASSAGEIRO, "COMPRAR 5.500 PTS →" → `comprar-pontos.html?pkg=plus`). Tocar num bilhete reescreve o recibo.
5. **Painel de partidas · Mapa** (2.5): "Seus pontos, o mundo inteiro.", 27 cidades (São Paulo e Rio "Em implantação" + 25 cidades do mundo "Em expansão"), globo, quadro preto; tocar numa cidade mostra os serviços ("Rede em expansão: ainda não há parceiros nesta cidade.") ou "Ver parceiros →".
6. Convite "Criar conta" (2.8) e rodapé-recibo.
- Endpoint: `GET /pix/packages` (atualiza pontos/preço; HTML é o fallback). Mapa usa dados locais (`assets/blaxx-globo.js`).
- Alerta: só 3 pacotes; a API tem também o Black.

### 4.2 Entrar — `login.html` · fotos 02
- Cartão único (surface, raio 18, padding 24/20): h1 "Bem-vindo de volta." (30 px/900), sub "Entre para acessar seus pontos e benefícios.", campo "E-MAIL OU CPF", "SENHA", linha "Lembrar de mim" + "Esqueci a senha" (→ recuperar), campo oculto "Código de verificação (2FA)", erro inline, botão preto "Entrar →", divisor "OU", botão do Google ("Fazer Login com o Google"), nota "Protegido por verificação em duas etapas (2FA)."; abaixo "© 2026 BlaXx · TERMOS · PRIVACIDADE · AJUDA".
- `POST /auth/login {email, password, mfa_code?}` → `{token, refresh_token, user}`; 401 + `mfa_required` mostra o campo 2FA; `mfa_challenge_token` = "2FA por SMS ativo, conclua pelo app oficial."; 423 conta bloqueada. Google: `POST /auth/google` (`assets/blaxx-google.js`). Destino: `?next=` (só caminho interno) ou `dashboard.html`.
- Erros: "Informe e-mail/CPF e senha.", "Falha de conexão: …".

### 4.3 Criar conta — `cadastro.html` · fotos 03 (passos 1, 2, 3)
- Barra de passos (3 segmentos de 6 px, neon até o atual), chip neon "PONTOS DE BOAS-VINDAS" com ícone, "PASSO N DE 3".
- Passo 1 "Quem é você?" / "Vamos começar pelo básico.": Nome completo, CPF, "Continuar →", "ou", Google ("Inscrever-se no Google").
- Passo 2 "Como te encontramos?" / "Usamos para login, avisos e segurança.": E-mail, Celular (opcional), "← Voltar" + "Continuar →".
- Passo 3 "Crie seu acesso." / "Último passo. Defina sua senha e confirme os termos.": Senha (mínimo 7), aceite "Li e aceito os termos de uso, as regras de pontos e a política de privacidade (LGPD).", "Criar conta grátis →".
- Validação: nome e sobrenome; CPF preenchido; e-mail com @; senha ≥ 7; aceite.
- `POST /auth/register {name, email, cpf, password, phone?, accept_terms, accept_privacy, accept_lgpd}` → 201 `{token, user, refresh_token}`. Backend aceita também `birth_date` (18+) e `referral_code` (documentado, sem efeito hoje). Erro de CPF volta ao passo 1, de e-mail ao passo 2.

### 4.4 Recuperar senha — `recuperar-senha.html` · fotos 04
- h1 "Recuperar senha.", "Informe seu e-mail e enviaremos um link para redefinir sua senha.", campo E-mail, "Enviar link de recuperação →", "O link expira em 30 minutos."
- `POST /auth/forgot-password {email}`; resposta sempre genérica: "Se este e-mail estiver cadastrado, enviamos as instruções de redefinição. Verifique a caixa de entrada e o spam." (formulário some). Continuação: `redefinir-senha.html` → `POST /auth/reset-password {token, password, password_confirm}`.

### 4.5 Painel — `dashboard.html` · fotos 10-01…07
1. Chip "OLÁ, CLIENTE", h1 "Bom te ver de volta.", linha "Você está a N pts do plano Prime." (**inventado**).
2. **Cartão de saldo preto** (raio 18, padding 20): "SALDO DE PONTOS" + pílula neon "PLANO PLUS" (**inventado**), número 41 px + "pontos", grade Disponíveis · Pendentes · Próx. expirar (mono 11 / 20 px/700), botões empilhados "+ Comprar pontos" (neon), "Resgatar →" (surface), "Enviar pontos".
3. Cartão neon "PRÓXIMO NÍVEL · Plano Prime · Faltam … para subir e ganhar +20% de bônus em todas as compras.", barra de progresso, "Acelerar →" (**inventado**).
4. **Atalhos** (grade 2 × 2 de cartões com ícone 36 px): Extrato "Veja todos os movimentos." · Enviar pontos "Sem taxa entre amigos." · Indique e ganhe "5.000 pts por amigo." · Meus resgates "2 vouchers ativos." (os dois últimos textos inventados).
5. **Campanhas ativas** + "Ver todas →": 3 cartões com capa preta e chip neon (Supermercado em dobro, Indique 3 amigos, Postos Shell em dobro) — **todos fixos e inventados** (a lista real está em campanhas.html).
6. **Últimas movimentações** + "Ver extrato completo →": tabela Data · Descrição · Status · Pontos (`GET /wallet/transactions?limit=5`), vazio "Nenhuma movimentação ainda.", erro "Erro: …".
7. Resgates populares (iFood R$ 50, Vale-compras R$ 50, **fixos**) e Parceiros por categoria (Supermercados, Postos → `parceiros.html?q=`).
- Endpoints: `GET /wallet/` (`balance_pts`, `pending_pts`; Disponíveis = saldo − pendentes; Próx. expirar fixo em 0), `GET /wallet/transactions?limit=5`. Rótulos de transação: purchase Compra, transfer_in Recebido, transfer_out Enviado, redeem Resgate, refund Estorno, bonus Bônus (faltam expire e accrual); status confirmed Confirmado, pending Aguardando, reversed Estornado.
- O `blaxx-app.js` ainda troca "Mariana Costa", "84.750" etc. no texto da página e esconde o corpo até hidratar (`data-auth-loading`).

### 4.6 Carteira — `carteira.html` · fotos 11
1. Chip "CARTEIRA BLAXX", h1 "Sua carteira.", lead "Tudo que entra e sai, em um lugar só."
2. Cartão preto: "SALDO TOTAL", número **Space Mono 45 px neon**, "Plano Plus · próximo nível em 67.520 pts" (**inventado**), botões "+ Comprar pontos" (neon → `comprar.html`), "Resgatar →", "Enviar pontos" (vazados → `resgates.html`, `enviar.html`).
3. Três cartões de número: Disponíveis (chip "PRONTOS", "Liberados para resgate agora."), Pendentes (chip preto "EM ANÁLISE", "Liberam em até 7 dias após a compra."), A expirar (etiqueta "12 DIAS", "Use antes de 10 jun 2026.").
4. "Acúmulo · últimos 6 meses" (gráfico de barras DEZ…MAI, "+12.4k este mês") e "Pontos a expirar" (Mercado Vivo, Bônus campanha, Nexus Airlines) — **inventados**; "Ver extrato completo →".
- `GET /wallet/` substitui só o saldo, Disponíveis e Pendentes; **se a API falha, os números de demonstração (32.480, 1.250, 800) ficam na tela**.

### 4.7 Extrato — `extrato.html` · fotos 12
1. Chip "EXTRATO", h1 "Cada ponto, rastreado."
2. Três números: "Entradas · mês" (verde, "+N"), "Saídas · mês" (vermelho, "−N"), "Saldo atual" (Space Mono 24 px/700).
3. Abas Tudo · Entradas · Saídas; busca "Buscar movimento...".
4. Lista agrupada por dia ("Hoje", "Ontem", "12 out"): cartão por dia; linha = ícone seta ↑ (verde) ou ↓ (vermelho) em quadrado, descrição, hora (+ " · pending"), valor "+1.234 / pts".
- `GET /wallet/` + `GET /wallet/transactions?limit=100` (máx. 100 pelo backend). Vazio "Nenhum movimento encontrado.". O web não abre detalhe da transação (a página `detalhe-transacao.html` é fixa).

### 4.8 Parceiros — `parceiros.html` · fotos 13-01…09 (exemplar do kit Embarque)
1. **Cartão de embarque**: "Painel de partidas · Parceiros | Rede em expansão · 2026", título "Parceiros / BlaXx. / Escolha o seu destino." (neon), busca "Destino · nome da marca ou categoria" (campo 56 px com lupa em quadrado neon), botão "Meus favoritos N", lead "Busque pela marca ou pela categoria… A rede está em expansão: novos parceiros entram aos poucos."; canhoto: visitante (Passageiro Você · Portão Parceiros · Lista Aberta, "Criar conta") ou logado (Seus pontos, Pendentes "Em processamento/Nada pendente", Nível atual de `/card/`, Progresso % com trilho e "Faltam N pts para <nível>", "Ver carteira", "Resgatar pontos →"; sem resposta: "Indisponível agora").
2. **Lista completa**: "Painel de partidas · Lista completa", h2 "Todos os parceiros.", número neon "266 parceiros na lista", separador tracejado; pílulas Todos N · Favoritos N · Postos · Supermercados · Farmácias · Viagens · Moda · Beleza + "Mais categorias +30"; status mono ("266 PARCEIROS · MOSTRANDO 20"); aviso de cidade (busca "São Paulo", "rj"… → "Rede em expansão nesta cidade"); grade de cartões de parceiro (2.8) com 20 por vez no celular e "Mostrar mais parceiros +20 de N" (botão preto 52 px).
3. **Embarque extra · Campanhas** ("Campanhas ativas." + "Ver campanhas →"): bilhetes de campanha rotativos (BX · Campanha ativa, "01 de 03", nome, "+5.000 pts ao concluir", descrição), pontos e setas; ao lado o recibo "RESUMO DA LISTA" (Parceiros, Categorias, Campanhas ativas, Seus favoritos, NA LISTA, faixa "REDE ……… EM EXPANSÃO", "Os favoritos ficam salvos só neste navegador.", "VER A LISTA →").
4. **Rota · Como usar a lista**: Busque · Filtre · Favorite · Confira.
- Endpoints: `GET /partners/`, `GET /partners/categories`, `GET /campaigns/`, e com sessão `GET /wallet/` + `GET /card/`.
- Regras de tela que o app deve copiar: categorias irmãs juntadas (Combustível/Posto → Postos; Supermercado/Mercados → Supermercados; Farmácia → Farmácias; Casa & Decoração → Casa; Tech → Eletrônicos; Moda Plus/Infantil/Esportiva/Íntima/Sustentável → Moda), ícone por categoria (tabela `ICONE_CAT`: Postos posto, Supermercados/Alimentação/Bebidas/Café supermercado, Restaurantes loja, Farmácias/Saúde farmacia, Viagens aviao (hotel se o nome tiver hotel/resort/pousada…), Moda/Calçados/Acessórios/Joias/Esportes moda, Beleza tag, Eletrônicos/Telecom celular, Streaming/Entretenimento/Música filme, E-commerce/Compras carrinho, Presentes resgates, Casa/Construção inicio, Seguros seguranca, Consórcio/Finanças/Câmbio comprar, Energia raio, Educação documento, Pet loja, Serviços configuracoes, Outros tag), busca sem acento por nome + categoria, `?q=postos|supermercado|farmácia` liga a pílula. **Nunca** mostra `description`, `accrual_rule` nem `logo_emoji`. Estados: esqueleto de 8 cartões, erro "Não foi possível carregar os parceiros agora." + "Tentar de novo", vazio por categoria, favoritos vazio "Toque no coração do canhoto de um parceiro para guardar aqui.", busca sem resultado + "Limpar busca".

### 4.9 Detalhe do parceiro — `detalhe-parceiro.html?id=` · fotos 14 (ACER) e 14b (FarmaPlus)
1. Farelo mono "INÍCIO / PARCEIROS / <NOME>".
2. Cartão de embarque do parceiro (2.1): "Cartão do parceiro · BlaXx", quadrado de categoria 52 px + "Categoria <nome>", título = nome (encolhe até caber) + linha neon "Troque seus pontos." ou "Rede em expansão.", grade De/Para/Disponíveis/A partir de, lead; canhoto Passageiro Você · Destino <parceiro>, CTA "Ver benefícios" (ou "Ver todos os resgates" sem benefício), "Outros destinos · Parceiros →".
3. **Bilhetes · Benefícios do parceiro** ("Troque seus pontos aqui." + "Todos os resgates →"): um bilhete por benefício, ordenados por pontos, → `beneficio-detalhe.html?id=`; sem benefício: bilhete "BX · Sem bilhete / Nenhum benefício disponível agora." com "Ver todos os resgates →" e "Outros parceiros →". Recibo "FICHA DO PARCEIRO" (Parceiro, Categoria, Benefícios, Conta ativa, E-mail verificado, Confirmação com senha, A PARTIR DE, faixa "PEDIDO PROCESSADO ……… até 1 dia útil", nota "Os pontos de cada benefício seguem a tabela de resgate publicada na plataforma… (Regulamento, §05 e §07).").
4. **Rota · Como usar seus pontos** ("Do saldo ao benefício."): Tenha · Escolha · Confirme · Troque; "Fonte: Regulamento, §03 Acúmulo, §05 Resgate e §07 Tabela de resgate."
- `GET /partners/<id>` (traz `benefits[]`). Estados: carregando ("Carregando… / Um instante."), sem id ("Qual parceiro?"), não encontrado ("Parceiro não encontrado. / Escolha outro destino."), sem conexão/erro com "Tentar de novo" (30 s de tempo-limite).
- Rótulos de categoria de benefício: voucher Voucher, desconto Desconto, assinatura Assinatura, sorteio Sorteio, social Social, educacao Educação, experiencia Experiência, viagem Viagem, produto Produto; ícones voucher/tag/filme/estrela/indique/documento/festa/aviao/resgates.

### 4.10 Resgates — `resgates.html` · fotos 15
1. Chip "RESGATES", h1 "Troque por benefícios e experiências.", pílula preta "SEUS PONTOS —".
2. Abas "Catálogo · Meus resgates".
3. Catálogo: filtros por categoria crua da API (Todos, sorteio, desconto, social, voucher, assinatura, educacao, experiencia, viagem) e cartões (área de imagem verde-clara com chip de categoria e ícone "resgates", nome, descrição, "59 pts", botão "Resgatar" neon, linha "Você pode resgatar" ou "Faltam N pts").
4. Meus resgates: `GET /vouchers/` → cartão com canhoto de ícone, nome, status ATIVO/USADO/EXPIRADO, código + "Copiar", "N pts · VÁLIDO ATÉ dd/mm/aaaa".
- Endpoints: `GET /benefits/`, `GET /wallet/`, `GET /vouchers/`, `POST /benefits/<id>/redeem` (com `confirm()` do navegador, sem senha, sem `Idempotency-Key`). Vazio "Você ainda não tem resgates.". A regra do detalhe do parceiro ("confirmação com senha") não é seguida aqui.

### 4.11 Fluxo de resgate de demonstração — fotos 16 a 19, 39, 40
- `beneficio-detalhe.html` (Netflix 30 dias, "Como funciona", "Condições do resgate", resumo, "Resgatar agora →", "Outros benefícios"), `confirmar-resgate.html` (e-mail de entrega, dois aceites, resumo saldo/custo/saldo após, "Confirmar resgate →"), `resgate-concluido.html` (código RSG-…), `meus-resgates.html` (filtros Todos/Ativos/Utilizados/Expirados e 6 cartões), `detalhe-voucher.html`, `saldo-insuficiente.html`. **Todo o conteúdo é fixo e inventado**; só `beneficio-detalhe.html?id=` tenta trocar o miolo por `GET /benefits/<id>` + `GET /wallet/`. Serve de referência de **fluxo** (detalhe → confirmar → concluído → meus resgates), não de texto.

### 4.12 Comprar pontos — `comprar-pontos.html` · fotos 20
1. Farelo, selo "Pacotes simples, transparentes, sem mensalidade", h1 "Acelere seu próximo resgate.", lead (com "até 15% de bônus").
2. Botão "Valor livre · você define quanto comprar →".
3. Cartões de pacote de `GET /pix/packages` (Start, Plus "MAIS POPULAR" em cartão preto, Prime, Black): nome, preço, pontos, linha de bônus (**"+10% / +20% / +40%", fixa e errada**), "Comprar agora" → `comprar-livre.html?pkg=<chave>`.
4. "Por que comprar pontos?" (creditados após confirmação, bônus acima do Start, acumulável com campanhas, cartão ou transferência, válidos por 24 meses) e cartão neon "Simulador" (valores fixos: "Streaming · 30 dias 12.000 pts", "Milhas aéreas 25.000 pts"…).
5. "Como pagar.": Transferência ("Confirmação imediata · sem taxas", Recomendado), Cartão de crédito ("Visa, Master, Elo, Amex · aprovação imediata", → `comprar-livre.html?method=card`), Boleto ("Em breve.").
6. Aviso legal.

### 4.13 Comprar (gaveta) — `comprar.html` · fotos 20b
- Chip "COMPRAR PONTOS", h1 "Acelere sua jornada.", "Quanto maior o pacote, maior o bônus em pontos."; cartões de pacote selecionáveis com visto (Prime marcado "POPULAR", "+N pts bônus"); "Valor personalizado" com régua R$ 10–5.000 ("R$ 180 · 2.000 pts" — **mostra o valor do ponto**); resumo preto "Você vai receber" (Pontos base, Bônus do pacote, Total a pagar); métodos TRANSFERÊNCIA (ativo), CARTÃO e BOLETO (desligados); "Comprar pontos →"; "PAGAMENTO SEGURO · PONTOS LIBERADOS APÓS CONFIRMAÇÃO".
- `GET /pix/packages`, `GET /pix/provider` (se `is_mock`, aparece "Simular pagamento (demo)" → `POST /pix/simulate-payment`), `POST /pix/charge {package}` ou `{amount_brl}`, sobreposição com QR e copia-e-cola, `GET /pix/charge/<id>` a cada 4 s, pago → carteira.

### 4.14 Valor livre e pagamento — `comprar-livre.html` · fotos 21 (fluxo real de compra)
1. h1 "Comprar pontos", "Valor livre: você define quanto comprar."
2. Passo 1 "Quanto você quer comprar?": campo "R$ 0,00", "Você recebe N pts" (**calculado no cliente com 9 centavos por ponto**), seletor "PIX | Cartão de crédito" (só aparece se `GET /payments/card/config` vier `enabled`), "Gerar QR Code de pagamento" (mínimo R$ 10,00).
3. Passo 2 cartão: "Dados do cartão", nota de criptografia, Stripe Elements, botão "PAGAR R$ X".
4. Passo 2 PIX: "Pague pelo app do seu banco", valor, QR (`qr_code_image`), "Ou copie o código:" + "Copiar", resumo Valor · Pontos (`points_to_credit` do servidor) · Expira em 30 minutos, pílula "Aguardando pagamento…", "← Cancelar e voltar".
5. Passo 3 "Pagamento confirmado!" "+N pts adicionados ao seu saldo.", "✓ Pontos liberados", "Ver meu saldo".
- Com `?pkg=` a página **gera a cobrança sozinha ao abrir**. Endpoints: `POST /pix/charge {package}|{amount_brl}`, `GET /pix/charge/<id>` (4 s, até 30 min; paid / expired / rejected), `GET /payments/card/config`, `POST /payments/card/charge` (`Idempotency-Key`, `card_token`, `payment_method_id`, `installments`, `issuer_id` + package ou amount_brl) → approved / in_process / rejected, `GET /payments/card/charge/<id>`. 403 `email_not_verified` abre o modal de verificação (`POST /auth/verify-email/send`, `POST /auth/verify-email {code}`).

### 4.15 Telas antigas de pagamento — fotos 22 a 25
- `checkout.html` (Seus dados, Forma de pagamento PIX/Cartão "Em até 6x sem juros"/Boleto, Cupom, aceite, resumo "Pacote Plus · R$ 49,90"), `pagamento-pix.html` (selo "AGUARDANDO PAGAMENTO", "Pague com o QR Code", QR, copia-e-cola, resumo Pacote/Pontos/Forma PIX/Valor, "Como pagar" em 4 passos — ligada ao fluxo antigo `STORE.flow charge`), `pagamento-cartao.html` (formulário de cartão próprio com parcelas de R$ 49,90), `compra-aprovada.html` ("Compra aprovada", pedido PED-…). Conteúdo fixo; não usar como fonte.

### 4.16 Enviar pontos — `enviar-pontos.html` (lateral) · fotos 26, e `enviar.html` (gaveta) · fotos 26b
- `enviar-pontos.html`: "Envie pontos para outra conta BlaXx. Sem taxa entre contas pessoais."; "Para quem você quer enviar?" (E-mail ou CPF do destinatário, Quantos pontos enviar, Mensagem opcional até 140, "Verificação: Senha da sua conta"), aviso "Envios confirmados não podem ser cancelados.", "Continuar →"; lateral "Seus pontos" (saldo e "Plano Plus" fixos) e "Limites: Mínimo por envio 100 pts · Máximo diário 50.000 pts". → `confirmar-envio.html` (revisão real: Para, Pontos, Mensagem, aviso amarelo, "Voltar e editar" / "Confirmar envio →") → `POST /transfer/ {to, amount_pts, message, password}` → `envio-concluido.html` ("Pontos enviados.", "Comprovante registrado no extrato.", Pontos enviados, Saldo atualizado `GET /wallet/`, Comprovante `receipt_code`, Data; "Voltar ao painel", "Enviar mais", "Ver extrato").
- `enviar.html` (tela única, melhor desenho): chip "ENVIAR PONTOS", h1 "Pontos para quem você quiser.", "**Sem taxa** entre contas BlaXx. Os pontos chegam na hora."; Enviar para; Pontos a enviar (campo grande) + atalhos 500 · 1.000 · 5.000 · 10.000 · Tudo; Mensagem; "Sua senha (confirmação)"; resumo preto (avatar do destinatário, "Conta BlaXx", pontos, "Taxa de envio GRÁTIS", "Seus pontos", "Após o envio"); erros "O envio mínimo é de 100 pts.", "Pontos insuficientes.", "Confirme com sua senha."; sucesso "Envio concluído. Comprovante … Redirecionando…" → extrato.
- Backend aceita também `Idempotency-Key`, `X-Device-Id`, `X-Platform`, `mfa_code` (401 `mfa_required`) e `POST /transfer/<id>/cancel` (`is_cancellable`).

### 4.17 Receber pontos — `receber-pontos.html` · fotos 29
- Página de convite para quem recebeu ("Mariana, Lucas enviou 2.000 pts para você.", "Entrar e receber" / "Não tenho conta", "O que fazer com 2.000 pts": Starbucks, "Resgate em transferência", Carrefour). **Toda fixa e inventada**, sem endpoint. No app, "receber" é só o lançamento `transfer_in` no extrato e a notificação.

### 4.18 Vender pontos (B2B) — `venda-pontos.html` · fotos 30
- Página comercial: "Solução B2B · BlaXx para empresas", h1 "Venda pontos como produto, incentivo e motor de recorrência.", números (R$ 5k mínimo, API, D+1, BI), "Dashboard parceiro" com métricas, três formatos (Lotes corporativos a partir de R$ 5.000, Campanhas patrocinadas, White label), passos 01–03, faixa preta "Para parceiros", "Cases" (supermercados +38%, farmácias, postos), "Solicitar proposta comercial →" (→ `contato.html`). **Métricas e cases inventados.** Não é função de cliente; não levar para o app do consumidor.

### 4.19 Campanhas — `campanhas.html` · fotos 31
- Chip "CAMPANHAS", h1 "Metas que valem pontos.", "Participe das campanhas ativas e receba pontos extras ao cumprir as metas."
- Cartão por campanha: título 19 px/900, descrição (ou `mechanic`), recompensa em selo neon "+5.000", "Meta R$ 2.142" + "%", barra de progresso, rodapé com prazo ("FALTAM N DIAS" / "ÚLTIMO DIA") e "Participar →" (neon) ou "EM ANDAMENTO" ou "Concluída".
- `GET /campaigns/` (com token traz `joined`, `progress_brl`, `progress_pct`, `completed_at`), `POST /campaigns/<id>/join`. Vazio "Nenhuma campanha ativa no momento.". (O `blaxx-app.js` tem um "Simular gasto R$ 100" → `POST /campaigns/<id>/progress` que **não** deve existir no app.)

### 4.20 Indique e ganhe — `indique.html` (gaveta) · fotos 32, e `indique-ganhe.html` (lateral) · fotos 32b
- `indique.html`: chip, h1 "Convide amigos. Ganhem juntos.", cartão preto "5.000 PTS POR AMIGO / Seu código de convite" (código derivado do nome + id no cliente, "Copiar", "Compartilhar link →", "WhatsApp"), cartão "15.000 pts já acumulados" (Convidados 5, Entraram 3, Pendentes 2), passos 01–03, trilho de conquistas (1 +5k, 3 +2k bônus, 5 Plano Plus grátis, 8 +10k, 10 Embaixador BlaXx), "Seus convidados" (5 nomes). Só `GET /auth/me`.
- `indique-ganhe.html`: faixa preta "5.000 pts a cada amigo cadastrado." (amigo ganha **500**, contra **2.500** na outra página), link fixo "blaxxpontos.com/convite?ref=mariana84", tabela de indicados fixa.
- **O backend não tem programa de indicação** (só aceita `referral_code` no cadastro, sem uso). Números, regras e convidados são inventados. No app: no máximo compartilhar um convite, sem prometer pontos, até existir regra no backend e no regulamento.

### 4.21 Perfil — `perfil.html` · fotos 33
- Chip "SUA CONTA", h1 "Perfil.", lead "Seus dados, seu plano e suas preferências de comunicação."
- Cartão do usuário: avatar neon 86 px com inicial, nome 24 px/900, e-mail, chip preto "CLIENTE" / "CLIENTE VIP" (`is_vip`), números Pontos · Pendentes · Disponíveis, "Configurações de segurança →".
- "Dados pessoais" (rótulo mono / valor): Nome completo, E-mail + chip "VERIFICADO/NÃO VERIFICADO", Celular mascarado "+55 (••) ••••-1234", CPF "***.***.789-**", "Chave para resgates" (`pix_key` ou e-mail).
- "Preferências": Notificações por e-mail, Notificações push, Ofertas de parceiros (interruptores **sem endpoint**).
- "Zona de risco": Sair da conta (limpa a sessão local), Excluir minha conta → "Solicitar" (abre chamado).
- `GET /auth/me`, `GET /wallet/`. O `blaxx-app.js` chama `PATCH /user/profile {name}`, mas **essa rota não existe no backend** (e o arquivo nem é carregado nesta página): hoje não há como editar o nome. Backend: `DELETE /auth/account`, `GET /auth/account/export`, `GET/POST/DELETE /privacy/consents`.

### 4.22 Segurança — `seguranca.html` · fotos 34
- Chip "SUA CONTA", h1 "Segurança.", "Proteja seus pontos e benefícios: 2FA, sessões e alertas."
- "Autenticação": Senha + "Alterar senha" (sobreposição: Senha atual, Nova senha mín. 7, Confirmar, "Salvar nova senha" → `POST /auth/change-password {old_password, new_password}`), "Verificação em duas etapas (2FA)" (chip "ATIVA" **fixo**), "Confirmação por e-mail" (chip real VERIFICADO/PENDENTE via `GET /auth/me`).
- "Sessões ativas" (3 dispositivos **fixos**, "ATUAL", "Encerrar", "Encerrar todas as outras sessões"), cartão preto "Nível de proteção 92/100" (**fixo**), "Boas práticas" (Nunca compartilhe códigos; "Confira o destino dos resgates" fala em "resgates por transferência").
- O backend já tem o real: `GET /user/sessions`, `DELETE /user/sessions/<id>`, `POST /auth/sessions/revoke-all`, `GET /user/access-log`, `POST /user/phone`, `POST /user/phone/verify`, `DELETE /user/phone`, `POST /user/2fa/sms/enable|disable`, `POST /auth/mfa/setup|enable|disable` (TOTP), `POST /auth/change-password`. Atenção: o `blaxx-app.js` chama `POST /auth/logout-all` e `PATCH /user/password`, que **não existem** no backend (usar `/auth/sessions/revoke-all` e `/auth/change-password`).

### 4.23 Notificações — `central-notificacoes.html` · fotos 35
- Chip "CENTRAL DE NOTIFICAÇÕES", h1 "Tudo que aconteceu na sua conta.", pílulas "Todas · Não lidas", "Marcar todas como lidas" (largura total), lista num cartão: ícone em quadrado neon (por tipo: purchase comprar, transfer trocar, expiration relogio, campaign campanhas, system info, redeem resgates, voucher voucher; ou pelo símbolo do backend ★ ✓ ⚠ ↪ ↩ 💸 ✦ ＋), título, tempo relativo ("agora", "há 5min", "há 2h", "há 3d"), corpo, bolinha de não lida.
- `GET /notifications/`, `PATCH /notifications/<id>/read` (ao tocar), `POST /notifications/read-all`; `GET /notifications/unread-count` existe para o sino. Vazios "Nenhuma notificação ainda." / "Nenhuma não lida.".

### 4.24 Central de ajuda — `central-ajuda.html` · fotos 36
- h1 "Como podemos te ajudar?", busca "Ex: como resgatar voucher, atraso no acúmulo, alterar senha…" (sem função), 8 cartões de tema (Acúmulo de pontos, Resgates, Comprar pontos, Enviar pontos, Conta & perfil, Segurança, Campanhas, Termos & documentos), "Perguntas mais buscadas" (6 `details`: pontos não creditados "até 24h… com a nota fiscal", usar voucher, compra recusada, ativar 2FA, enviar para qualquer pessoa, validade **24 meses**), cartões "Abrir um chamado" (neon, "Resposta em até 1 dia útil.") e "Meus chamados". Conteúdo estático; sem endpoint.

### 4.25 Cartão BlaXx — `cartao.html` · fotos 37
- Chip "SEU CARTÃO", h1 "Cartão Blaxx.", "Seu nível é definido pelos **pontos acumulados** e nunca cai ao resgatar. Adicione o cartão à carteira do iPhone."
- Cartão na cor do nível (Bronze `#CD7F32`, Prata `#9AA0A6`, Ouro `#D4AF37`, Black `#0B0B0C` com texto neon, VIP `#0A0A0A`): "BLAXX", selo do nível, saldo Space Mono 45 px + "pts", "Nome · ID XXXXXXXX", "Acumulado: N pts / Faltam N p/ <próximo>", trilho.
- Botão "Adicionar à Apple Wallet" (`GET /card/pass` baixa `.pkpass`; sem certificado vira "Apple Wallet · em breve" + nota). "Programa de níveis": lista dos 5 níveis com bolinha de cor, mínimo ("0+ pts", "Por convite"), benefícios e selo "ATUAL".
- `GET /card/`, `GET /card/tiers`, `GET /card/pass/status`, `GET /card/pass`. **Sem resposta, mostra um estado demo inventado (Ricardo, 16.320 pts, Ouro).** No iOS, o "Adicionar à Carteira" é nativo (PassKit).

### 4.26 Telas de apoio — fotos 38 a 40
- `detalhe-transacao.html` (Mercado Bom Preço, R$ 124,00, "+1.240 pts", Loja Pinheiros — **inventado**; fala em valor da compra × pontos), `detalhe-voucher.html` (Netflix, código, "Resgatar na Netflix →"), `saldo-insuficiente.html` ("Faltam 3.250 pts para este benefício", "Compre 3.500 pts agora", "Comprar pacote Start →"). Servem de modelo de estado (detalhe de lançamento, voucher, saldo insuficiente); o conteúdo deve vir de `GET /wallet/transactions`, `GET /vouchers/<id>` e do custo do benefício.

---

## 5. Contrato de API usado pelo web mobile (backend `https://blaxx-pontos-exe.onrender.com`)

| Endpoint | Método | Sessão | Telas | Campos usados |
|---|---|---|---|---|
| `/auth/login` | POST | não | login | `email` (e-mail ou CPF), `password`, `mfa_code?` → `token`, `refresh_token`, `user`; 401 `mfa_required`; 423 |
| `/auth/google` | POST | não | login, cadastro | credencial do Google → mesma resposta |
| `/auth/register` | POST | não | cadastro | `name, email, cpf, password, phone?, birth_date?, accept_terms, accept_privacy, accept_lgpd` → 201 |
| `/auth/refresh` | POST | refresh | todas | renova o access (30 min); refresh vale 30 dias |
| `/auth/me` | GET | sim | perfil, segurança, indique | `name, email, cpf, phone, pix_key, email_verified_at, is_vip, mfa_enabled, has_password, google_linked, status` |
| `/auth/logout`, `/auth/sessions/revoke-all` | POST | sim | Sair, Segurança | — (`/auth/logout-all`, chamado pelo web, não existe) |
| `/auth/forgot-password`, `/auth/reset-password` | POST | não | recuperar, redefinir | `email`; `token, password, password_confirm` |
| `/auth/change-password` | POST | sim | segurança | `old_password, new_password` → `ok` |
| `/auth/verify-email/send`, `/auth/verify-email` | POST | sim | modal de compra | `code` |
| `/wallet/` | GET | sim | painel, carteira, extrato, parceiros, perfil, envio | `balance_pts`, `pending_pts` (**ignorar `balance_brl_equiv`**) |
| `/wallet/transactions?limit=` | GET | sim | painel (5), extrato (100) | `type, status, amount_pts, description, reference, created_at` |
| `/card/`, `/card/tiers`, `/card/pass(/status)` | GET | sim / não | cartão, parceiros | `tier, next_tier, points_to_next, progress_pct, lifetime_points, member{id,name}, tiers[], wallet_pass_available` |
| `/pix/packages` | GET | não | home, comprar-pontos, comprar, mega-menu | `{start,plus,prime,black: {label, points, price_brl}}` |
| `/pix/provider` | GET | não | comprar | `is_mock` |
| `/pix/charge` | POST | sim | comprar-livre, comprar | `{package}` ou `{amount_brl}` (mín. 10) → `id, amount_brl, points_to_credit, br_code, qr_code_image, status, expires_at` |
| `/pix/charge/<id>` | GET | sim | idem (4 s) | `status`: pending, pending_confirmation, paid, expired, refunded, rejected |
| `/payments/card/config` | GET | não | comprar-livre | `enabled, public_key` |
| `/payments/card/charge(/<id>)` | POST/GET | sim | comprar-livre | `Idempotency-Key`; `status`: approved, in_process, rejected, cancelled |
| `/transfer/` | POST | sim | enviar | `to, amount_pts, message?, password, mfa_code?` → `receipt_code, created_at, is_cancellable` |
| `/partners/`, `/partners/categories`, `/partners/<id>` | GET | não | parceiros, detalhe | `id, name, category, city` (+ `benefits[]` no detalhe). **Não usar** `description`, `accrual_rule`, `logo_emoji` |
| `/benefits/`, `/benefits/<id>` | GET | não | resgates, detalhe | `id, name, category, cost_pts, expires_in_days, stock, tag, partner_id, partner_name`. **Não usar** `image_emoji` |
| `/benefits/<id>/redeem` | POST | sim | resgates | `Idempotency-Key` aceito → voucher |
| `/vouchers/`, `/vouchers/<id>` | GET | sim | meus resgates | `benefit_name, code, points_spent, expires_at, used_at, status` |
| `/campaigns/`, `/campaigns/<id>`, `/campaigns/<id>/join`, `/campaigns/mine` | GET/POST | opcional | campanhas, parceiros | `name, description, mechanic, reward_pts, target_brl, period_end, joined, progress_pct, completed_at` |
| `/notifications/`, `/<id>/read`, `/read-all`, `/unread-count` | GET/PATCH/POST | sim | notificações, sino | `type, title, body, icon, is_read, created_at` |
| `/user/sessions`, `/user/access-log`, `/user/phone…`, `/user/2fa/sms/…` | vários | sim | (só no `blaxx-app.js`) | segurança real |
| `/redeem/` | POST | sim | resgate-pix | **saque por transferência: não levar para o app** |

---

## 6. Limpeza obrigatória dos dados de produção (copiar do web)

- Texto livre (descrição de parceiro e benefício): descartar se casar com
  `/parceiro\s+livelo|fict[ií]ci|\bpix\b|a\s+cada\s+R\$|pts?\s*\/\s*R\$/i` (`detalhe-parceiro.html`, `textoValido`).
- Nome e descrição de campanha no bilhete: descartar se casar com `/R\$|\/\s*R\$|\bpix\b/i` (`parceiros.html`, `limpo`). O `mechanic` não aparece no bilhete.
- Nunca exibir: `accrual_rule`, `logo_emoji`, `image_emoji`, `balance_brl_equiv`, o texto de benefícios do nível que cita PIX.
- Ícone: sempre o desenho de `icones.json` escolhido pela categoria (tabelas em 4.8 e 4.9), nunca o emoji da API.
- Release (regra do dono, o web **não** faz): esconder parceiros cuja `description` contenha "fictícia" (8) e os benefícios ligados a eles (8 de 10); confirmar com o dono se as 3 campanhas de produção são reais antes de exibi-las.

---

## 7. Para o app iOS: o que levar de cada lugar

- **Linguagem visual**: o kit Embarque (cartão de embarque com picote e canhoto, rota com escalas, bilhete com canhoto, recibo com serrilhado e cabeça preta, painel/quadro preto, rótulos Space Mono MAIÚSCULOS, chão `#E4E1D9`, cartões `#FBFAF7` raio 18, preto `#0A0B0E`, neon só como preenchimento). As páginas da conta no web ainda usam os componentes antigos repintados; no app vale aplicar o kit nelas também (saldo como cartão de embarque, extrato como recibo, compra como bilhetes + recibo).
- **Chrome**: barra preta com o wordmark, sino neon e avatar; barra de abas preta com 5 itens (Início, Carteira, Comprar, Resgates, Menu) e ícones em quadrado neon 30 pt, rótulo mono 11 com ativo neon; Menu abre a gaveta agrupada (Conta / Pontos / Descobrir / Ajuda / Sair).
- **Uma tela por função** (escolha sugerida pelo que funciona de verdade no web):
  - Comprar = pacotes da API em bilhetes + recibo (home) e pagamento do `comprar-livre` (PIX com QR + copia-e-cola e cartão), com valor livre **sem** prévia de pontos calculada no cliente; usar `points_to_credit` da cobrança.
  - Enviar = `enviar.html` (atalhos 500/1.000/5.000/10.000/Tudo, resumo, senha na mesma tela, comprovante).
  - Resgates = catálogo `/benefits/` + "Meus resgates" `/vouchers/`, com o fluxo detalhe → confirmar (com senha) → concluído das telas de demonstração.
  - Parceiros e detalhe do parceiro = como no web (é a referência mais completa e já limpa).
  - Carteira/extrato = saldo + pendentes reais, extrato agrupado por dia com filtros Tudo/Entradas/Saídas; sem gráfico, sem "a expirar" inventado, sem "Plano".
  - Cartão BlaXx = níveis reais de `/card/` + Apple Wallet nativo.
  - Notificações, Perfil, Segurança = dados reais (sessões e 2FA dos endpoints `/user/*`), sem os números fixos.
  - Fora do app de consumidor: venda-pontos (B2B), resgate-pix (saque), receber-pontos e indique com recompensa (até haver regra).
- **Estados**: carregando (esqueleto), vazio com frase e ação, erro com "Tentar de novo", sem conexão; nunca mostrar número de demonstração quando a API falha.

---

## Anexo A · `icones.json`

51 entradas `{"nome": "<conteúdo interno do SVG>"}` para `viewBox 0 0 24 24`, `fill none`, `stroke currentColor`, `stroke-width 1.8`, `stroke-linecap/linejoin round`: inicio, carteira, extrato, parceiros, resgates, voucher, campanhas, comprar, enviar, receber, indique, perfil, seguranca, ajuda, sair, notificacoes, cartao, check, alerta, erro, info, estrela, email, chat, documento, anexo, festa, raio, carrinho, aviao, hotel, posto, farmacia, supermercado, filme, moda, local, loja, mais, seta, grafico, relogio, calendario, tag, favorito, celular, busca, configuracoes, trocar, usuario_mais (as 50 do objeto `ICONES`) e **menu** (vem do objeto `ICONE` da barra de abas, mesmo arquivo; no web ele usa `stroke-width 2`). Alguns pontos (`circle … r=1.4|0.6`) usam `fill="currentColor" stroke="none"` dentro do próprio desenho. "indique" e "favorito" são o mesmo coração. Renderização: desenho a 56% do quadrado neon (44 → 24,6; 30 → 20 com padding 5).

Desenhos de traço que aparecem inline nas páginas e **não** estão no conjunto (para o app decidir se entram): seta para cima `<path d="M12 19V5M5 12l7-7 7 7"/>` e para baixo `<path d="M12 5v14M5 12l7 7 7-7"/>` (linhas do extrato, traço 2), visto `<path d="M4 12.5 9.5 18 20 6"/>` (campanha concluída, envio), chave `<circle cx="8" cy="15" r="4"/><path d="M11 12 20 3"/><path d="M16 7l3 3M13 10l2.5 2.5"/>` (segurança), "sem mensalidade" `<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/><path d="m9.5 13.5 5 5M14.5 13.5l-5 5"/>` (convite), prancheta `<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 3h6v3H9Z"/><path d="M9 11h6M9 15h6"/>` (ajuda).

## Anexo B · Marca no web

- Barra preta: `assets/marca/blaxx-wordmark-barra.svg` (só "BlaXx", "Bla" branco, "Xx" `#59FD27`, desenho 817 × 158) a 114 × 22 no celular; cabeça do recibo a 30 px de altura.
- Fundo claro: `assets/marca/blaxx-wordmark-barra-claro.svg` (140 × 28).
- Rodapé: `assets/marca/blaxx-logo-completo-justo.svg` (logo completo) a 80 px de altura no celular.
- Equivalentes já no app: `BlaxxWordmark`, `BlaxxWordmarkClaro`, `BlaxxLockup`, `BlaxxSymbol` no `Assets.xcassets`.
