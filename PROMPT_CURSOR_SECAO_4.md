# Prompt para o Cursor — Ajustar Seção 4 do laudo de Crime de Trânsito

## Contexto

Este é um app Flutter (`laudo_tech`) que gera laudos periciais em Word (.docx) para a Polícia Científica. O laudo é produzido programaticamente em OOXML pelo serviço `lib/services/laudo_generator_service.dart`, que **reescreve `document.xml` do zero** (não usa placeholder replacement no `template_laudo_mv.docx`).

Hoje o laudo gerado para "Crime de Trânsito" entrega a seção 4 assim:

```
4. DO LOCAL
  4.1 Endereço
      <endereço + município>
      Coordenadas geográficas: <S>, <W>.
      [Imagem 01: Captura de tela indicando o local periciado.]
(pula para)
5. EXAMES
  5.1 Condições da Via       ← conteúdo deveria estar em 4.1.3
  5.2 Veículos e Danos       ← parte identificadora deveria estar em 4.2
  5.3 Envolvidos             ← vítima em óbito deveria estar em 4.3
  5.4 Natureza da Ocorrência
```

O padrão da Superintendência exige a seção 4 assim:

```
4. DESCRIÇÃO
  4.1 Local
    4.1.1 Endereço
    4.1.2 Coordenadas Geográficas
          IMAGEM 01: imagem de Satélite do Local do Fato – Fonte: Google Earth Pro
    4.1.3 Características e Condições (parágrafo narrativo)
    4.1.4 Velocidade Máxima Regulamentar
  4.2 Unidades Veiculares
    4.2.1 Unidade Veicular 1 (V1)
       Tipo de Veículo:       Marca/Modelo:       Cor:
       Placa de Licenciamento instalada:          Ano Fabricação/Ano Modelo:
    4.2.2 Unidade Veicular 2 (V2) ... (e assim por diante)
  4.3 Vítima em óbito no local
    4.3.1 Identificação
       Nome:                              Documento de Identificação:
       Data de nascimento:                Sexo:
       Laudo Cadavérico:
    4.3.2 Descrição/Indumentária/Pertences
       (vestes, acessórios, pertences e Cadeia de Custódia: ML / familiar / Delegacia)
```

## Objetivo

Alterar o app para que o laudo gerado saia exatamente nesse formato na seção 4, sem quebrar outros tipos de ocorrência (furto, dano, CVLI, morte a esclarecer).

## Arquivos que você PRECISA ler antes de começar

1. `lib/services/laudo_generator_service.dart` — em especial:
   - Linha ~1120: função que gera "4. DO LOCAL" (renomear para DESCRIÇÃO)
   - Linha ~1233: `_gerarSecaoExames` (bloco `if (ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito)` na linha ~1261)
   - Linha ~2859: `_textoCondicoesCrimeTransito`
   - Linha ~3050: `_textoVeiculosCrimeTransito`
   - Linha ~3121: `_textoEnvolvidosCrimeTransito`
   - Linha ~1176: `_gerarTituloSubSecao` (para entender o estilo de subtítulo)
2. `lib/models/crime_transito_model.dart` — `CrimeTransitoCondicoesViaModel`
3. `lib/models/veiculo_model.dart` — já tem `cor`, `anoFabricacao`, `anoModelo`, mas NÃO são emitidos
4. `lib/models/cadaver_model.dart` — tem `documentoIdentificacao`, `dataNascimento`, `sexo`, `vestes`, `pertences`
5. `lib/models/local_ficha_model.dart`
6. `lib/models/ficha_completa_model.dart`

Telas relevantes para os campos novos:
- `lib/screens/crime_transito_condicoes_screen.dart`
- `lib/screens/local_screen.dart`
- `lib/screens/cadastro_cadaver_screen.dart`
- `lib/screens/cadastro_veiculo_screen.dart`
- `lib/screens/cadastro_envolvido_transito_screen.dart`

## MUDANÇAS — FASE 1: Reestruturação do gerador (dado já existe, só está no lugar errado)

### 1.1 Renomear título e criar subestrutura 4.1

Em `laudo_generator_service.dart`, na função que gera a seção 4 (por volta da linha 1120):

- Trocar `_gerarTituloSecao('4. DO LOCAL')` por `_gerarTituloSecao('4. DESCRIÇÃO')`.
- Logo abaixo, emitir `_gerarTituloSubSecao('4.1 Local')`.
- Trocar o atual subtítulo `'4.1 Endereço'` por um subtítulo de 3º nível `'4.1.1 Endereço'`. **Crie um novo helper** `_gerarTituloSubSubSecao(String titulo)` se ainda não existir, idêntico ao `_gerarTituloSubSecao` mas SEM negrito ou com estilo menos destacado (use a Portaria 128/2019 Art. 2º IV.3 como referência — se não souber exatamente, mantenha negrito mas com itálico, para diferenciar do 2º nível).
- Emitir o parágrafo do endereço como está hoje.
- Emitir `_gerarTituloSubSubSecao('4.1.2 Coordenadas Geográficas')` antes do parágrafo de coordenadas.
- Trocar a legenda atual de `'Captura de tela indicando o local periciado'` por `'imagem de Satélite do Local do Fato – Fonte: Google Earth Pro'` na função `_gerarLegendaEImagemMapa` — **apenas quando** `ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito`. Procure onde essa legenda é construída e faça a condicional por tipo de ocorrência. Não quebre o comportamento de furto/dano/CVLI.

### 1.2 Criar 4.1.3 Características e Condições (mover o conteúdo de 5.1)

Ainda dentro da função que gera a seção 4, depois da imagem:

- Se `ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito`, emitir `_gerarTituloSubSubSecao('4.1.3 Características e Condições')` seguido do parágrafo retornado por `_textoCondicoesCrimeTransito(ficha.crimeTransitoCondicoes!)`.
- IMPORTANTE: quando vier para 4.1.3, este texto NÃO deve mais ser emitido em 5.1 nem em 6.1. Remova ou condicione a chamada em `_gerarSecaoExames` (linha ~1263) para NÃO repetir o conteúdo.

### 1.3 Criar 4.1.4 Velocidade Máxima Regulamentar

Emitir `_gerarTituloSubSubSecao('4.1.4 Velocidade Máxima Regulamentar')` seguido de um parágrafo construído assim:

- Se `cond.velocidadeMaxima` estiver preenchido E `cond.velocidadePorSinalizacao == true`: emitir `'A via apresentava sinalização regulamentar de velocidade máxima de ${cond.velocidadeMaxima} km/h.'`
- Se `cond.velocidadePorCTB == true` (sinalização ausente): emitir `'Não havia sinalização regulamentar de velocidade máxima no trecho. Conforme estabelece o art. 61, §1º do CTB/1997, a via foi classificada como ${classificacaoCTB}, portanto o limite de velocidade é de ${cond.velocidadeMaxima} km/h.'`
- Se nenhum dos dois estiver disponível, emitir `'Não foi possível determinar a velocidade máxima regulamentar para o trecho.'`

O campo `classificacaoCTB` não existe ainda — veja Fase 2 abaixo. Por enquanto, imprima `'urbana/rural (tipo a definir)'` como placeholder se `classificacaoCTB` for nulo, para não quebrar a geração.

**IMPORTANTE**: remover esse trecho de velocidade de dentro de `_textoCondicoesCrimeTransito` (linhas ~3023-3035) para que não saia duplicado em 4.1.3.

### 1.4 Criar 4.2 Unidades Veiculares

Ainda na função que gera a seção 4, DEPOIS de fechar a subseção 4.1:

- Se `ficha.veiculos != null && ficha.veiculos!.isNotEmpty`, emitir `_gerarTituloSubSecao('4.2 Unidades Veiculares')`.
- Para cada veículo (com índice `i` começando em 1):
  - Emitir `_gerarTituloSubSubSecao('4.2.${i} Unidade Veicular ${i} (V${i})')`.
  - Emitir dois parágrafos de identificação (não uma frase só):
    - Parágrafo 1: `'Tipo de Veículo: ${tipo}.   Marca/Modelo: ${marcaModelo}.   Cor: ${cor}.'`
    - Parágrafo 2: `'Placa de Licenciamento instalada: ${placa}.   Ano Fabricação/Ano Modelo: ${anoFab}/${anoMod}.'`
  - Use `'Não informado'` para qualquer campo nulo/vazio.
  - NÃO emitir aqui: setores de impacto, intensidade de dano, frenagem, tacógrafo, localização do veículo. Esses campos são de EXAMES (seção 6.2) — deixe continuar saindo em 5.2 por enquanto, vamos mover em uma outra etapa.

- Se houver veículo do tipo bicicleta ou dispensado de placa (confira enum `TipoVeiculo`), emitir uma nota padrão no final de 4.2: `'Tratando-se de veículo dispensado do uso de placas de identificação (Resolução n. 993/2023-CONTRAN), segue descrição básica: ${descricao}.'`

### 1.5 Criar 4.3 Vítima em óbito no local

Depois do bloco 4.2, se houver cadáveres registrados E o tipo de ocorrência é `crimeTransito`:

- Emitir `_gerarTituloSubSecao('4.3 Vítima em óbito no local')`.
- Para cada cadáver com índice `i` (começando em 1, suprimir índice se houver só 1):
  - Emitir `_gerarTituloSubSubSecao('4.3.1 Identificação')`.
  - Emitir dois parágrafos:
    - `'Nome: ${nome}.   Documento de Identificação: ${documentoIdentificacao}.'`
    - `'Data de nascimento: ${dataNascimento}.   Sexo: ${sexo}.   Laudo Cadavérico: ${laudoCadavericoRG ?? "a ser complementado"}.'`
  - Emitir `_gerarTituloSubSubSecao('4.3.2 Descrição/Indumentária/Pertences')`.
  - Emitir parágrafo construído a partir de `cadaver.vestes` (lista) e `cadaver.pertences`.
  - Emitir parágrafo de cadeia de custódia: `'Cadeia de Custódia: os pertences e itens encontrados junto ao corpo foram destinados ${destinoPertences}.'` — se `destinoPertences` não estiver disponível, usar `'conforme relação anexa'`.

- A ligação entre "cadáver" e "envolvido do trânsito" precisa ser preservada: **não remova o cadáver da seção 5.3 / 6.1** ainda; apenas emita também em 4.3. Depois refinamos para não duplicar.

### 1.6 Limpar as seções 5.x para não duplicar

Em `_gerarSecaoExames` (linha ~1261 no bloco de `crimeTransito`):

- Manter "5. EXAMES" por enquanto (vamos renumerar para 6 em outra fase).
- Remover "5.1 Condições da Via" — já está em 4.1.3.
- Em "5.2 Veículos e Danos", manter SOMENTE o conteúdo de EXAMES do veículo (intensidade de dano, setores de impacto, frenagem, tacógrafo, danosObservacoes). Remover tipo/marca/modelo/placa/cor/ano porque estão em 4.2.
- Em "5.3 Envolvidos", manter apenas o texto de participação na dinâmica (classificação, situação, posição). A identificação completa da vítima em óbito está em 4.3.
- Manter "5.4 Natureza da Ocorrência".

## MUDANÇAS — FASE 2: Novos campos em models e telas

### 2.1 `CrimeTransitoCondicoesViaModel` (lib/models/crime_transito_model.dart)

Adicionar:

- `OrientacaoCardeal? orientacaoTrafego` — novo enum com valores `norteSul`, `sulNorte`, `lesteOeste`, `oesteLeste` (e variantes diagonais se necessário).
- `SeparacaoPistas? tipoSeparacaoPistas` — novo enum `canteiroCentral`, `defensaLateral`, `mureta`, `nenhuma`.
- `int? numeroFaixasRolamento`
- `int? numeroFaixasAcostamento`
- `ClassificacaoCTBVia? classificacaoCTB` — novo enum:
  - `ClassificacaoLocalizacao` (urbana, rural)
  - `ClassificacaoTipoVia` (transitoRapido, arterial, coletora, local, rodovia, estrada)
  - Ou um enum combinado com os 6×2 = 12 valores possíveis.

Atualizar `toJson`, `fromJson`, `copyWith`.

### 2.2 Tela `CrimeTransitoCondicoesScreen` (lib/screens/crime_transito_condicoes_screen.dart)

Adicionar campos de UI:

- Dropdown para orientação do sentido de tráfego (N–S / L–O / etc).
- Dropdown para tipo de separação entre pistas.
- Dois inputs numéricos: "Número de faixas de rolamento" e "Número de faixas de acostamento".
- Dois dropdowns para classificação CTB: (1) urbana × rural, (2) tipo da via (rápida / arterial / coletora / local / rodovia / estrada).

Fazer bind com o model atualizado e salvar na ficha.

### 2.3 Imagem de satélite no `LocalFichaModel` e tela

Em `lib/models/local_ficha_model.dart`, adicionar:

- `String? imagemSatelitePath` — caminho do arquivo de imagem de satélite (Google Earth Pro exportado).
- Manter `capturaTelaLocalPath` como está (captura do Maps do app, usada em outros tipos de ocorrência).

Em `lib/screens/local_screen.dart`:

- Adicionar botão "Adicionar imagem de satélite (Google Earth Pro)" que faça upload de uma imagem e salve em `imagemSatelitePath`.
- Na geração do laudo, quando tipo for crime de trânsito e `imagemSatelitePath` estiver preenchido, usar essa imagem como IMAGEM 01. Se não estiver, usar fallback (captura do Maps) e imprimir legenda "Fonte: captura de tela do aplicativo" apontando que não é a imagem oficial.

### 2.4 `CadaverModel` — complementos para 4.3

Em `lib/models/cadaver_model.dart`, adicionar:

- `String? rgLaudoCadaverico` — número do laudo cadavérico no IML.
- `List<PertenceCadaverModel>? pertencesEstruturados` — nova classe:

```dart
class PertenceCadaverModel {
  final String descricao;
  final DestinoPertence destino; // enum: medicinaLegal, familiar, delegacia
  final String? observacoes;
  // toJson / fromJson / copyWith
}

enum DestinoPertence { medicinaLegal, familiar, delegacia }
```

Manter o campo antigo `pertences` (String) para retrocompatibilidade, mas priorizar a lista estruturada quando existir.

Em `lib/screens/cadastro_cadaver_screen.dart`:

- Adicionar campo de texto "RG do Laudo Cadavérico (IML)".
- Adicionar UI para cadastrar pertences estruturados, um a um, cada um com dropdown de destino.

### 2.5 Ligação Envolvido-do-trânsito ↔ Cadáver

Quando o usuário marcar um envolvido como `situacao == obito` em `CadastroEnvolvidoTransitoScreen`, oferecer um seletor de cadáver (dos já cadastrados) para vincular. Adicionar em `EnvolvidoTransitoModel` (ou equivalente) um campo `String? cadaverIdVinculado` para saber qual cadáver usar na seção 4.3.

## MUDANÇAS — FASE 3 (opcional, se houver tempo): Preparar para seção 6 de exames

Depois que a seção 4 estiver alinhada, os dados que hoje saem em "5.2 Veículos e Danos" e "5.3 Envolvidos" precisarão migrar para "6.2 Nas Unidades Veiculares" e "6.3 Na Vítima". Essa é outra fase — NÃO faça agora, mas mantenha os textos de exames em funções separadas para facilitar mover depois.

## Critérios de validação

Depois de implementar, gere o laudo de uma ficha de teste de crime de trânsito e verifique:

1. A seção 4 começa com `4. DESCRIÇÃO`.
2. Existem os subtítulos `4.1 Local`, `4.1.1 Endereço`, `4.1.2 Coordenadas Geográficas`, `4.1.3 Características e Condições`, `4.1.4 Velocidade Máxima Regulamentar`.
3. Existe `4.2 Unidades Veiculares` com subtítulos `4.2.1 V1`, `4.2.2 V2` e os 5 campos de identificação (tipo, marca/modelo, cor, placa, ano fab/modelo) em formato de bloco.
4. Se há vítima em óbito, existe `4.3 Vítima em óbito no local` com `4.3.1` e `4.3.2`.
5. A imagem 01 aparece com a legenda nova ("Fonte: Google Earth Pro") quando há imagem de satélite.
6. Em 5.2 (por enquanto) só sai o conteúdo de exames (danos, frenagem, tacógrafo), SEM duplicar marca/modelo/cor/placa.
7. `flutter analyze` passa sem erros.
8. Gerar um laudo real e abrir no Word para conferir visualmente.

## Restrições

- NÃO quebre o fluxo para os outros tipos de ocorrência (furto, dano, CVLI, morte a esclarecer). Use condicionais por `TipoOcorrencia`.
- Mantenha toda a lógica de fonte, espaçamento e estilo OOXML já existente (`_fontName`, `_fontSizeNormal`, `_gerarParagrafoHistorico`, etc.).
- Não mexa em `template_laudo_mv.docx`.
- Comente no código onde for não-trivial o porquê da mudança (ex: `// 4.1.3: movido de 5.1 conforme padrão da Superintendência`).

## Entrega

Comece pela FASE 1 inteira (mudança de gerador, sem tocar em models/telas ainda, usando placeholders onde falta dado). Depois passe para a FASE 2. Mostre o diff de cada arquivo conforme for alterando.
