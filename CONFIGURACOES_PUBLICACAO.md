# Configurações Críticas para Publicação - Laudo Tech

⚠️ **IMPORTANTE**: Este arquivo contém todas as configurações necessárias para manter o app publicável nas lojas.

## 📱 Identificadores do App

### Android
- **Package Name**: `com.waldirdev01.laudo_tech`
- **Application ID**: `com.waldirdev01.laudo_tech`

### iOS
- **Bundle Identifier**: `com.waldirdev01.laudoTech`

## 🔢 Versão Atual
- **Version**: `1.0.0+8`
- **Android versionCode**: 8
- **Android versionName**: 1.0.0
- **iOS CFBundleShortVersionString**: 1.0.0
- **iOS CFBundleVersion**: 8

## 🔑 Assinatura Android
- **Keystore**: `android/app/upload-keystore.jks` (mantido)
- **Key Properties**: `android/key.properties` (mantido)
- **Key Alias**: upload
- **Passwords**: Mantidas em key.properties

## 🎨 Assets Mantidos
- `assets/images/logo.png` - Ícone do app
- `assets/images/appstore.png`
- `assets/images/playstore.png`
- `assets/templates/` - Templates de laudos (MANTIDOS)

## 📄 Arquivos de Configuração Mantidos

### Android
- `android/app/build.gradle` - Configurações de build, versionCode, signing
- `android/key.properties` - Credenciais de assinatura
- `android/app/upload-keystore.jks` - Keystore de upload
- `android/app/proguard-rules.pro` - Regras ProGuard
- `android/gradle.properties` - Propriedades Gradle
- `android/settings.gradle` - Configurações do projeto

### iOS
- `ios/Runner/Info.plist` - Permissões e configurações
- `ios/Runner.xcodeproj/project.pbxproj` - Configurações do projeto
- `ios/Runner/Assets.xcassets/` - Ícones e imagens
- `ios/Podfile` - Dependências CocoaPods

## 🔐 Permissões iOS (Info.plist)
```xml
NSPhotoLibraryUsageDescription - Acesso à galeria para evidências
NSPhotoLibraryAddUsageDescription - Salvar fotos de perícia
NSLocationWhenInUseUsageDescription - Coordenadas GPS para laudos
NSLocationAlwaysAndWhenInUseUsageDescription - Coordenadas GPS para laudos
NSCameraUsageDescription - Capturar fotos de evidências (se necessário)
```

## 🛠️ Configurações de Build

### Android (build.gradle)
- **compileSdk**: 36
- **targetSdk**: 35
- **minSdk**: Definido pelo Flutter
- **ndkVersion**: 27.0.12077973
- **Java Version**: 17
- **Kotlin JVM Target**: 17
- **ProGuard**: Habilitado em release
- **Dependência**: pdfbox-android 2.0.27.0

### iOS
- **Deployment Target**: Verificar em project.pbxproj
- **Display Name**: Laudo Tech
- **Orientações**: Portrait, Landscape Left, Landscape Right

## 📋 Metadados para Lojas

### Nome e Descrição
- **Nome**: Laudo Tech
- **Descrição**: Ferramenta para geração automatizada de laudos periciais. Aplicativo profissional para documentação de ocorrências com precisão e eficiência.

### Categorias
- **Principal**: Produtividade
- **Secundária**: Utilitários
- **Classificação Etária**: 4+ (Apropriado para todas as idades)

### Palavras-chave
laudo, perícia, documento, relatório, profissional, técnico

## ✅ Conformidade
Ver `APP_STORE_COMPLIANCE.md` para checklist completo de conformidade.

## 🚀 Próximos Passos ao Atualizar

1. Incrementar o build number (+1)
   - Android: `versionCode` em `build.gradle`
   - iOS: CFBundleVersion (ou usar --build-number no flutter build)
   - pubspec.yaml: `version: 1.0.0+9` (por exemplo)

2. Build para produção:
   ```bash
   # Android
   flutter build appbundle --release
   
   # iOS
   flutter build ipa --release
   ```

3. Testar em dispositivos físicos antes de enviar

4. Upload:
   - Android: Google Play Console
   - iOS: App Store Connect via Xcode ou Transporter

## 📝 Notas Importantes
- As configurações de assinatura Android estão em `key.properties` (NÃO comitar senhas!)
- O keystore `upload-keystore.jks` deve ser mantido seguro
- Bundle IDs devem permanecer os mesmos para atualizações
- Versão deve sempre incrementar para novas releases

