# Screenshots — App Store BlaXx Pontos

Lista de capturas obrigatórias por dispositivo, conteúdo recomendado e diretrizes
de segurança / homologação. Capturar em ordem; a primeira screenshot é a "hero"
mais importante (aparece na busca da App Store antes do usuário abrir a página).

## Dispositivos e resoluções

A App Store atualmente exige 3 tamanhos canônicos de iPhone + iPad. Capturar
todos para evitar rejeição automática:

| Dispositivo                       | Resolução (pt @3x) | Obrigatório |
|-----------------------------------|--------------------|-------------|
| iPhone 6.7" (15 Pro Max / 16 Pro Max) | 1290 × 2796        | Sim         |
| iPhone 6.5" (Xs Max / 11 Pro Max) | 1284 × 2778        | Sim         |
| iPhone 5.5" (8 Plus)              | 1242 × 2208        | Sim (legado)|
| iPad Pro 12.9" (gen 6 / M2)       | 2048 × 2732        | Sim (se há build iPad) |

## Roteiro de capturas (6 telas por tamanho)

Para cada dispositivo capturar nesta ordem:

1. **Dashboard / Carteira (hero)**
   - Tela principal com saldo em destaque (ex.: "47.820 pts")
   - Mostra equivalente em reais e botões de ação rápida
   - Texto sobre a screenshot: "Seus pontos. Seu jeito."

2. **Comprar Pontos (QR PIX)**
   - Sheet de compra com QR Code PIX e valor
   - Mostrar o pacote escolhido (ex.: Plus — 25.000 pts por R$ 200)
   - Texto: "Compre por PIX em segundos"

3. **Enviar Pontos (sucesso)**
   - Tela pós-envio com check verde e detalhe da operação
   - Mostrar destinatário (e-mail anônimo: `parceiro@blaxx.app`)
   - Texto: "Envie pontos para qualquer membro"

4. **Cartão BlaXx**
   - Cartão neon com nível atual (ex.: Plus) e barra de progresso
   - Botão "Adicionar à Apple Wallet" visível
   - Texto: "Seu cartão. Sua identidade BlaXx."

5. **Resgatar (PIX)**
   - Sheet de resgate com chave PIX e valor em R$ correspondente
   - Mostrar a quote (ex.: "10.000 pts = R$ 80,00")
   - Texto: "Resgate para qualquer chave PIX"

6. **Parceiros / Benefícios**
   - Lista de parceiros com logos e regras de acúmulo
   - Categoria em destaque (ex.: "Restaurantes")
   - Texto: "Acumule onde você já gasta"

## Como capturar

### Em dispositivo real (preferível para fidelidade visual)
1. Configurar build DEBUG apontando para conta demo de homologação
   (`rewards.demo@blaxx.app`)
2. iPhone → Ajustes → Mostrar bateria 100%, Wi-Fi cheio, sem notificações
   (Modo Foco "Não Perturbe")
3. Garantir hora no formato 9:41 (padrão Apple para marketing)
4. Capturar com Volume+ Power. Transferir via AirDrop para o Mac.

### Em simulador (rápido, batch)
```
xcrun simctl boot "iPhone 15 Pro Max"
xcrun simctl status_bar "iPhone 15 Pro Max" override --time 9:41 \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
xcrun simctl io "iPhone 15 Pro Max" screenshot ~/Desktop/01_dashboard.png
```

### Pelo Xcode (Devices)
Window → Devices and Simulators → selecionar device → "Take Screenshot".

## Diretrizes obrigatórias

### Segurança (REJEIÇÃO se desrespeitado)
- **Nunca dados pessoais reais.** Usar conta `rewards.demo@blaxx.app`
- **Nunca CPF, telefone, chave PIX real.** Usar valores fictícios documentados em
  `RewardsBackend.swift` / docs de homologação
- **Nunca screenshots com banner de "ambiente de homologação"** — usar release.
  Em homologação, ajustar UI temporariamente para esconder o banner se houver

### Visual
- **Verde neon oficial:** `#59FD27` (conforme Brand Book v1.0)
- **Fundo preto oficial:** `#0A0B0E`
- **Fonte:** Space Grotesk (sem Inter)
- **Logo:** lockup oficial — não distorcer, não recolorir
- Centralizar elementos; deixar respiração nas margens (mín. 24pt)
- Aplicar fade preto no topo se o status bar atrapalhar leitura

### Texto sobre screenshot
- PT-BR claro, curto (até 6 palavras)
- Tipografia consistente — mesma fonte/peso em todas
- Cor `#59FD27` ou branco sobre fundo escuro
- Evitar exclamações ou superlativos vendedores ("MELHOR!", "INCRÍVEL!")

## Checklist final antes de subir

- [ ] 6 screenshots por dispositivo (24 ao total se cobrir 4 dispositivos)
- [ ] PNG sem transparência
- [ ] Resolução exata (sem upscale)
- [ ] Nenhum dado pessoal real
- [ ] Hora 9:41, bateria 100%, Wi-Fi cheio
- [ ] Verde neon correto (#59FD27)
- [ ] Logo BlaXx oficial sem distorção
- [ ] Conferir em monitor calibrado (cores reais)
- [ ] App em modo claro (light mode) — padrão atual do BlaXx Pontos
