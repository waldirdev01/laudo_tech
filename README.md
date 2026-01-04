# Laudo Tech

Ferramenta profissional para geração automatizada de laudos periciais. Aplicativo para documentação de ocorrências com precisão e eficiência.

## 📱 Sobre o App

**Laudo Tech** é um aplicativo mobile desenvolvido em Flutter para auxiliar peritos na criação e gestão de laudos periciais de forma rápida e profissional.

### Versão Atual
- **Versão**: 1.0.0
- **Build**: 8

## 🏗️ Estrutura do Projeto

Este projeto foi recentemente limpo e reorganizado para facilitar a manutenção e futuras atualizações.

### Diretórios Principais

```
laudo_tech/
├── lib/                    # Código-fonte Dart/Flutter
│   └── main.dart          # Ponto de entrada do app
├── assets/                # Assets do app
│   ├── images/           # Imagens (logo, ícones)
│   └── templates/        # Templates de laudos
├── android/              # Configurações Android
│   ├── app/
│   │   ├── build.gradle  # Configurações de build e assinatura
│   │   └── upload-keystore.jks  # Keystore para publicação
│   └── key.properties    # Credenciais de assinatura (não comitar!)
├── ios/                  # Configurações iOS
│   └── Runner/
│       └── Info.plist    # Permissões e configurações
└── pubspec.yaml          # Dependências do projeto
```

## 🔧 Configuração do Ambiente

### Pré-requisitos
- Flutter SDK ^3.8.1
- Android Studio / Xcode
- Para Android: JDK 17
- Para iOS: macOS com Xcode

### Instalação

1. Clone o repositório:
```bash
git clone <url-do-repositorio>
cd laudo_tech
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Execute o app:
```bash
flutter run
```

## 📦 Build para Produção

### Android

```bash
# Gerar APK
flutter build apk --release

# Gerar App Bundle (recomendado para Play Store)
flutter build appbundle --release
```

O arquivo será gerado em:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle: `build/app/outputs/bundle/release/app-release.aab`

### iOS

```bash
# Gerar IPA
flutter build ipa --release
```

Depois, use Xcode ou Transporter para enviar à App Store.

## 🔐 Assinatura de Apps

### Android
- O keystore está em: `android/app/upload-keystore.jks`
- As credenciais estão em: `android/key.properties` (não comitar!)
- Package Name: `com.waldirdev01.laudo_tech`

### iOS
- Bundle Identifier: `com.waldirdev01.laudoTech`
- Usar certificado e provisioning profile configurados no Xcode

## 🚀 Publicação

### Google Play Store
1. Incrementar o build number em `pubspec.yaml` e `android/app/build.gradle`
2. Gerar o App Bundle: `flutter build appbundle --release`
3. Fazer upload no Google Play Console
4. Preencher changelog e informações de lançamento

### Apple App Store
1. Incrementar o build number em `pubspec.yaml`
2. Gerar o IPA: `flutter build ipa --release`
3. Fazer upload via Xcode ou Transporter
4. Submeter para revisão no App Store Connect

### ⚠️ Importante antes de publicar
- [ ] Testar em dispositivos físicos Android e iOS
- [ ] Verificar todas as funcionalidades principais
- [ ] Confirmar que permissões são solicitadas corretamente
- [ ] Atualizar screenshots nas lojas se necessário
- [ ] Revisar descrição e changelog

## 📝 Conformidade com Lojas

Ver arquivo `APP_STORE_COMPLIANCE.md` para checklist completo de conformidade com requisitos da App Store e Play Store.

Ver arquivo `CONFIGURACOES_PUBLICACAO.md` para todas as configurações críticas de publicação.

## 🔒 Arquivos Sensíveis

**NUNCA** comite estes arquivos:
- `android/key.properties` - Contém senhas do keystore
- `android/app/upload-keystore.jks` - Keystore de assinatura
- `ios/*.mobileprovision` - Provisioning profiles

## 🛠️ Desenvolvimento

### Adicionar Dependências

Use o comando (sem versão específica):
```bash
flutter pub add nome_do_pacote
```

### Executar Testes

```bash
flutter test
```

### Análise de Código

```bash
flutter analyze
```

## 📄 Licença

Propriedade privada. Todos os direitos reservados.

## 📞 Suporte

Para suporte ou dúvidas sobre o app:
- Email: suporte@laudotech.com
- Desenvolvedor: Waldir Oliveira

---

**Versão do README**: 2.0 (Projeto Reestruturado - Janeiro 2025)
