# Fastlane — BlaXx Pontos

Pipeline mínimo para entregar builds Release ao TestFlight e atualizar
metadados na App Store Connect.

## Instalação inicial (uma vez por máquina)

```bash
brew install fastlane
# OU: sudo gem install fastlane -NV
```

Verificar:
```bash
fastlane --version
```

## Credenciais necessárias

A Apple recomenda **App Store Connect API Key** (JWT, sem 2FA). Para obter:

1. Acesse https://appstoreconnect.apple.com/access/api
2. Gere uma "App Manager" key
3. Baixe o `.p8` e anote `Key ID` + `Issuer ID`
4. Exporte:
   ```bash
   export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXX.p8"
   export APP_STORE_CONNECT_API_KEY_ID="XXXXX"
   export APP_STORE_CONNECT_API_ISSUER_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
   ```

Alternativa (legado, com 2FA):
```bash
export FASTLANE_APPLE_ID="ricardo.veles@gmail.com"
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export FASTLANE_TEAM_ID="ABCD1234EF"
```

## Lanes disponíveis

### `fastlane beta`
Incrementa build number, compila com assinatura release, faz upload para TestFlight.
```bash
cd blaxx_app/BlaxxPontos
bundle exec fastlane beta
```

### `fastlane build_only`
Compila o IPA assinado em `./build/` mas não faz upload. Útil para validar
provisioning antes de mandar pro TestFlight.

### `fastlane metadata`
Sobe os arquivos de `fastlane/metadata/pt-BR/` (description, keywords, etc.)
sem mexer no binário. Usar quando só queremos atualizar texto da loja.

## Estrutura

```
fastlane/
├── Appfile                   # IDs da app (env vars preferidas)
├── Fastfile                  # Definição das lanes
├── README.md                 # Este arquivo
├── SCREENSHOTS_CHECKLIST.md  # Guia de captura de screenshots
└── metadata/
    └── pt-BR/
        ├── description.txt
        ├── keywords.txt
        ├── marketing_url.txt
        ├── name.txt
        ├── privacy_url.txt
        ├── promotional_text.txt
        ├── release_notes.txt
        ├── subtitle.txt
        └── support_url.txt
```

## Antes de rodar `fastlane beta`

1. Bundle ID `Blaxx-Pontos-Inc.BlaxxPontos` registrado em Apple Developer
2. App criada em App Store Connect (rascunho da primeira versão)
3. Capability **Push Notifications** habilitada no profile
4. APNs key gerada em Developer Portal
5. `entitlements` correto (`aps-environment` = `production` para release pública,
   ou `development` para TestFlight interno — `BlaxxPontos.entitlements` atual
   usa `development`)
6. Screenshots prontos (ver `SCREENSHOTS_CHECKLIST.md`)
7. Política de privacidade publicada em `blaxxpontos.com.br/privacidade`

## Troubleshooting comum

- **"No matching provisioning profiles found"** → criar profile App Store no
  Developer Portal com o bundle ID correto e baixar para o Xcode
- **"Invalid provisioning profile, missing Push Notifications"** → habilitar
  capability na App ID e regerar o profile
- **Upload demora ~15min** → normal; Apple processa o build assincronamente
