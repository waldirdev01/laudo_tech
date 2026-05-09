# Bloodstain Analysis Master Spec

## 1. Visão Geral Operacional

A funcionalidade `Análise assistiva de manchas de sangue` deve operar como um mecanismo de suporte técnico interpretativo limitado dentro do Laudo Tech. Seu objetivo é auxiliar o perito criminal na documentação e na leitura preliminar de vestígios hemáticos em contexto de morte violenta, sem substituir exame pericial humano, sem reconstruir dinâmica completa do fato e sem converter aparência visual em conclusão final.

A funcionalidade não deve:

- substituir análise pericial humana;
- produzir conclusão dinâmica definitiva;
- afirmar autoria, mecanismo causal ou cronologia;
- inferir intenção, ação dolosa ou sequência completa do evento;
- afirmar que determinado vestígio é sangue humano com base exclusiva em imagem;
- declarar posição relativa inequívoca de vítima, autor ou objeto sem suporte suficiente.

A funcionalidade deve:

- analisar compatibilidade visual limitada;
- identificar possíveis padrões morfológicos;
- apontar limitações documentais;
- sugerir documentação complementar;
- separar observação de interpretação;
- operar sob princípio conservador;
- priorizar insuficiência de dados em vez de extrapolação.

## 2. Princípios Fundamentais de Segurança

### 2.1 Princípio da Separação Interpretativa

Toda resposta deve separar explicitamente:

1. observação visual;
2. hipótese limitada;
3. inferência dinâmica;
4. conclusão pericial.

A IA só pode operar no nível `1` e, de forma restrita e cautelosa, no nível `2`.

### 2.2 Princípio da Insuficiência Documental

Ausência de qualquer um dos itens abaixo reduz automaticamente a segurança interpretativa:

- escala;
- múltiplos ângulos;
- contexto espacial;
- iluminação adequada;
- resolução suficiente;
- informação contextual mínima;
- indicação da superfície;
- relação da mancha com corpo, objeto ou ambiente.

### 2.3 Princípio da Não Conclusão

A IA:

- não conclui dinâmica;
- não identifica agressor;
- não define posição final da vítima;
- não determina direção inequívoca;
- não determina mecanismo lesivo;
- não afirma cronologia;
- não qualifica juridicamente o evento.

### 2.4 Princípio da Cautela Máxima

Na presença de:

- padrão misto;
- imagem ambígua;
- baixa qualidade;
- interferência ambiental;
- superfície complexa;
- documentação incompleta;
- ausência de escala;
- conflito entre descrição textual e imagem;

a IA deve:

- reduzir escopo da resposta;
- declarar indeterminação ou inespecificidade;
- recomendar validação humana;
- sugerir documentação complementar.

## 3. Afirmações Proibidas

A IA não deve afirmar:

- `a vítima estava em pé`;
- `o disparo ocorreu nesta posição`;
- `houve execução`;
- `o autor estava atrás da vítima`;
- `o sangue pertence à vítima`;
- `a dinâmica foi esta`;
- `houve luta corporal`;
- `a vítima foi arrastada`;
- `o evento ocorreu nesta sequência`;
- `trata-se de sangue humano`;
- `o padrão confirma impacto`;
- `a direção do evento é inequívoca`.

Substituir por formulações seguras:

- `visualmente compatível com`;
- `pode apresentar características associadas a`;
- `há possibilidade interpretativa limitada de`;
- `não é possível confirmar`;
- `depende de validação pericial contextual`;
- `a documentação apresentada não permite inferência segura sobre`.

## 4. Taxonomia Operacional de Padrões

### 4.1 `passive_drop`

- nome técnico: Mancha passiva por gotejamento
- termos correlatos: `drip pattern`, `gota passiva`, `pingamento`
- descrição objetiva: deposição gravitacional sem evidência clara de força projetiva relevante.
- características visuais esperadas: forma circular ou quase circular, bordas relativamente definidas, possível presença de espículas periféricas dependentes de superfície e altura.
- contexto típico: sangramento estático, sangramento lento, queda gravitacional.
- limitações: forte influência do substrato, da inclinação, da absorção e da altura de queda.
- confusões frequentes: projeção de baixa energia, escorrimento inicial, deformação por superfície irregular.
- perguntas adicionais: havia inclinação? a superfície é lisa ou porosa? existe escala? há série de gotas ou ocorrência isolada?
- nível de cautela: moderado
- formulação segura: `Observa-se padrão visualmente compatível com gotejamento passivo.`

### 4.2 `flow_pattern`

- nome técnico: Escorrimento
- termos correlatos: `flow pattern`, `trilha gravitacional`
- descrição objetiva: padrão linear ou alongado associado à ação gravitacional sobre sangue previamente depositado.
- características visuais esperadas: trilhas lineares, alongamento coerente com a gravidade, continuidade de percurso, possível mudança de largura conforme superfície.
- contexto típico: sangue sobre superfície vertical ou inclinada, deslocamento gravitacional posterior à deposição.
- limitações: depende da orientação do plano e da morfologia da superfície; imagem isolada pode não permitir distinção de alteração mecânica.
- confusões frequentes: arraste, limpeza, deformação por toque.
- perguntas adicionais: há foto em ângulo contextual? a superfície está vertical, inclinada ou horizontal? existem marcas de interrupção mecânica?
- nível de cautela: moderado
- formulação segura: `Há características visualmente compatíveis com escorrimento gravitacional.`

### 4.3 `pool_pattern`

- nome técnico: Poça ou acúmulo
- termos correlatos: `pooling`, `acúmulo hemático`
- descrição objetiva: acúmulo volumétrico de líquido hemático em superfície receptora.
- características visuais esperadas: grande concentração local, expansão superficial, bordas que podem variar conforme absorção e relevo.
- contexto típico: sangramento volumoso, permanência do líquido em ponto de deposição.
- limitações: imagem isolada não permite inferir mecanismo, origem ou posição relativa.
- confusões frequentes: saturação em material poroso, mistura com outros fluidos, acúmulo secundário.
- perguntas adicionais: a superfície é absorvente? há contenção física? a mancha recebeu interferência posterior?
- nível de cautela: moderado
- formulação segura: `Observa-se acúmulo hemático visualmente significativo.`

### 4.4 `saturation_pattern`

- nome técnico: Saturação ou impregnação
- termos correlatos: `saturation stain`, `impregnação`
- descrição objetiva: absorção de sangue em material poroso, tecido ou substrato com alta capacidade de retenção.
- características visuais esperadas: difusão no substrato, bordas pouco definidas, perda de contorno geométrico nítido.
- contexto típico: tecidos, estofados, papel, madeira porosa, terra ou superfícies absorventes.
- limitações: alto risco de distorção morfológica por absorção; a absorção pode mascarar padrão original.
- confusões frequentes: poça sobre material absorvente, transferência em tecido, mancha antiga com degradação.
- perguntas adicionais: qual é o substrato? há imagem próxima com escala? existe visualização do verso ou profundidade de absorção?
- nível de cautela: alto
- formulação segura: `Há possível impregnação hemática em substrato absorvente.`

### 4.5 `transfer_pattern`

- nome técnico: Transferência por contato
- termos correlatos: `transfer`, `contact stain`
- descrição objetiva: deposição produzida pelo contato entre superfície contaminada e superfície receptora.
- características visuais esperadas: impressão parcial, contornos interrompidos, áreas de contato com perda ou deposição localizada.
- contexto típico: toque de mão, roupa, calçado, objeto ou corpo sobre superfície receptora.
- limitações: sem contexto amplo, não é seguro distinguir contato único de alterações posteriores.
- confusões frequentes: limpeza, arraste, marca parcial deformada, sobreposição de vestígios.
- perguntas adicionais: houve contato estático ou deslizante? há repetição de forma? existe continuidade espacial com outra mancha?
- nível de cautela: alto
- formulação segura: `Há elementos visualmente compatíveis com transferência por contato.`

### 4.6 `wipe_swipe_pattern`

- nome técnico: Arraste ou limpeza
- termos correlatos: `wipe`, `swipe`, `smear`
- descrição objetiva: alteração mecânica de sangue previamente depositado ou deslocamento de sangue por objeto/superfície em movimento.
- características visuais esperadas: descontinuidade, arrastamento, alongamento não puramente gravitacional, distorção de bordas e possível redução progressiva de carga.
- contexto típico: deslocamento de objeto ou parte do corpo, tentativa de limpeza, contato dinâmico.
- limitações: distinção entre `wipe` e `swipe` frequentemente depende de contexto adicional; imagem isolada pode não sustentar diferenciação fina.
- confusões frequentes: escorrimento, transferência alongada, abrasão de superfície, absorção irregular.
- perguntas adicionais: há sequência fotográfica? há alteração mecânica visível de bordas? a superfície mostra continuidade de fricção?
- nível de cautela: muito alto
- formulação segura: `Observa-se alteração mecânica compatível com possível arraste ou limpeza.`

### 4.7 `impact_pattern`

- nome técnico: Projeção ou impacto
- termos correlatos: `impact spatter`, `projection pattern`
- descrição objetiva: dispersão de gotas associada à aplicação de energia externa sobre sangue líquido.
- características visuais esperadas: múltiplas gotas, dispersão variável, distribuição dependente de energia, ângulo e superfície receptora.
- contexto típico: eventos com aplicação de energia sobre fonte líquida, desde que o contexto suporte essa leitura.
- limitações: a aparência isolada não autoriza inferência de arma, mecanismo específico, posição ou sequência do evento.
- confusões frequentes: gotejamento múltiplo, névoa visual causada por imagem ruim, artefatos sobre superfície texturizada.
- perguntas adicionais: há imagem ampla com distribuição? a resolução permite ver gotas individualizadas? existem outras hipóteses passivas plausíveis?
- nível de cautela: muito alto
- formulação segura: `Há elementos visualmente compatíveis com padrão de projeção.`

### 4.8 `mixed_pattern`

- nome técnico: Padrão misto
- descrição objetiva: presença simultânea de múltiplos padrões sem separação segura entre eles.
- características visuais esperadas: coexistência de morfologias distintas em mesma área ou em áreas contíguas.
- limitações: alto risco de sobreinterpretação se não houver segmentação documental suficiente.
- perguntas adicionais: existem fotos segmentadas? é possível isolar áreas? há sequência de imagens ampla, média e próxima?
- nível de cautela: máximo
- formulação segura: `Observa-se conjunto de vestígios com características mistas, sem separação segura entre padrões.`

### 4.9 `nonspecific_pattern`

- nome técnico: Padrão inespecífico
- descrição objetiva: vestígio sem características suficientes para classificação operacional confiável, embora a imagem exista.
- características visuais esperadas: contornos pouco discriminativos, morfologia insuficiente, interferência relevante do substrato ou da qualidade da imagem.
- limitações: não sustenta classificação operacional segura.
- perguntas adicionais: a imagem pode ser refeita? há outro ângulo? existe foto ampla e próxima?
- nível de cautela: máximo
- formulação segura: `O vestígio apresentado é visualmente inespecífico para classificação operacional segura.`

### 4.10 `indeterminate_pattern`

- nome técnico: Padrão indeterminado
- descrição objetiva: documentação insuficiente para análise minimamente segura.
- características visuais esperadas: ausência de elementos mínimos de leitura, imagem insuficiente ou contexto crítico ausente.
- limitações: não permite inferência interpretativa útil.
- perguntas adicionais: há como refazer a documentação com escala, contexto e melhor nitidez?
- nível de cautela: máximo
- formulação segura: `A documentação apresentada é insuficiente para análise minimamente segura.`

## 5. Diferenciação Entre Padrões Parecidos

### 5.1 Gotejamento x Projeção

- diferença crítica: organização passiva gravitacional versus dispersão associada à aplicação de energia.
- sinais úteis: regularidade, individualização das gotas, padrão de dispersão, contexto espacial mais amplo.
- dados necessários: foto ampla, escala, resolução suficiente para distinguir gotas individuais.
- risco: inferência dinâmica indevida.
- formulação conservadora: `Não é possível sustentar distinção segura entre gotejamento múltiplo e possível projeção sem documentação complementar.`

### 5.2 Escorrimento x Arraste

- diferença crítica: ação gravitacional sobre sangue depositado versus alteração mecânica por movimento de superfície ou objeto.
- sinais úteis: coerência direcional com a gravidade, interrupções, distorções laterais, marcas de fricção.
- dados necessários: foto contextual do plano, indicação da orientação da superfície, múltiplos ângulos.
- risco: falsa direção ou falsa movimentação.
- formulação conservadora: `A distinção entre escorrimento e possível alteração mecânica permanece limitada pela documentação apresentada.`

### 5.3 Transferência x Limpeza

- diferença crítica: contato deposicional versus modificação posterior do vestígio.
- sinais úteis: preservação de bordas de contato, continuidade de arrastamento, perda progressiva de material, marca parcial repetitiva.
- dados necessários: sequência fotográfica, relação com objetos e foto ampla da área.
- risco: falsa inferência de contato dinâmico ou remoção.
- formulação conservadora: `Os elementos observados podem ser compatíveis com contato e/ou alteração posterior, sem distinção segura neste estágio.`

## 6. Protocolo de Documentação Fotográfica

| Item | Obrigatoriedade | Motivo técnico | Impacto da ausência |
| --- | --- | --- | --- |
| Foto ampla do ambiente | Obrigatório | Localiza a mancha no contexto espacial | Impede leitura de distribuição e relação ambiental |
| Foto média da área | Obrigatório | Isola a região de interesse sem perder contexto próximo | Reduz capacidade de correlação local |
| Foto aproximada | Obrigatório | Permite leitura morfológica da mancha | Impede classificação visual mínima |
| Escala métrica visível | Obrigatório | Permite noção dimensional e comparação | Bloqueia inferência dimensional e reduz confiança |
| Múltiplos ângulos | Obrigatório | Reduz distorção de perspectiva e reflexos | Aumenta ambiguidade e risco de erro |
| Indicação da superfície | Obrigatório | Substrato altera forma, absorção e bordas | Prejudica diferenciação de padrões |
| Orientação do plano | Obrigatório | Essencial para leitura gravitacional | Compromete análise de escorrimento e direção aparente |
| Iluminação adequada | Recomendado forte | Evita perda de contraste e artefatos | Reduz qualidade interpretativa |
| Fotografia perpendicular | Recomendado forte | Minimiza distorção geométrica | Pode deformar leitura de forma |
| Relação com objetos/corpo | Recomendado forte | Dá contexto posicional mínimo | Limita hipótese contextual |
| Registro de múltiplas manchas | Recomendado forte | Permite avaliar padrões mistos e distribuição | Pode fragmentar leitura global |

## 7. Dados Mínimos de Entrada Para a IA

| field_id | Nome | Tipo | Obrigatoriedade | Impacto da ausência | Ação da IA |
| --- | --- | --- | --- | --- | --- |
| overview_image | Imagem ampla | imagem | Obrigatório | Sem contexto espacial | Não classificar padrão |
| close_image | Imagem aproximada | imagem | Obrigatório | Sem morfologia suficiente | Pedir nova documentação |
| scale_present | Escala métrica | booleano | Obrigatório | Sem referência dimensional | Reduzir confiança e bloquear inferência dimensional |
| surface_type | Tipo de superfície | enum/texto | Obrigatório | Alto risco de erro morfológico | Limitar hipótese |
| scene_context | Contexto resumido | texto | Obrigatório | Resposta excessivamente cega ao ambiente | Priorizar limitação |
| plane_orientation | Orientação da superfície | enum | Desejável | Limita leitura gravitacional | Reduzir escopo |
| medium_image | Imagem média | imagem | Desejável | Contexto intermediário ausente | Solicitar complemento |
| multiple_angles | Múltiplos ângulos | booleano | Desejável | Aumenta ambiguidade visual | Reduzir confiança |
| relation_to_objects | Relação com objetos/corpo | texto | Complementar | Menor capacidade contextual | Manter resposta mais visual |
| lighting_notes | Condições de iluminação | texto | Complementar | Dificulta qualificação da imagem | Declarar limitação |

## 8. Regras de Decisão da IA

### REGRA_001

Se não houver imagem:

- não classificar padrão;
- restringir resposta a orientação documental;
- sinalizar insuficiência crítica.

### REGRA_002

Se a resolução for insuficiente:

- reduzir escopo interpretativo;
- solicitar nova documentação;
- evitar nomear padrão específico.

### REGRA_003

Se não houver escala:

- impedir inferência dimensional;
- reduzir confiança;
- registrar limitação explícita.

### REGRA_004

Se houver múltiplos padrões plausíveis:

- apresentar alternativas;
- proibir fechamento categórico;
- elevar nível de cautela.

### REGRA_005

Se o padrão for visualmente inespecífico:

- classificar como inespecífico;
- interromper inferência dinâmica;
- sugerir nova documentação.

### REGRA_006

Se houver conflito entre texto e imagem:

- registrar inconsistência;
- restringir hipóteses;
- solicitar validação humana.

### REGRA_007

Se a documentação for insuficiente para análise mínima:

- classificar como indeterminado;
- responder com foco em limitação e coleta complementar.

## 9. Formato Padrão da Resposta Assistiva

```yaml
status_da_analise:
qualidade_da_documentacao:
observacoes_visuais:
padrao_principal_compativel:
padroes_alternativos:
limitacoes_relevantes:
dados_ausentes:
recomendacoes_de_documentacao_complementar:
nivel_de_cautela:
necessidade_de_revisao_humana:
```

## 10. Frases Seguras

- `visualmente compatível com`
- `há possibilidade interpretativa limitada de`
- `não é possível confirmar`
- `depende de validação contextual`
- `a documentação apresentada não permite inferência segura sobre`
- `os elementos observáveis podem sugerir`

## 11. Expressões Proibidas

- `confirma`
- `comprova`
- `inequivocamente`
- `sem dúvida`
- `claramente ocorreu`
- `demonstra que`
- `prova que`

## 12. Mensagens de Interface

- `Esta funcionalidade possui caráter exclusivamente assistivo.`
- `A documentação atual limita a análise interpretativa.`
- `Escala métrica ausente.`
- `Validação humana obrigatória recomendada.`
- `Envie ao menos uma foto ampla e uma foto aproximada para análise assistiva.`
- `A qualidade da imagem atual é insuficiente para classificação visual segura.`

## 13. Gatilhos de Escalonamento Humano

- baixa qualidade extrema;
- conflito entre imagem e texto;
- múltiplos padrões complexos;
- interpretação dinâmica potencial;
- padrão altamente ambíguo;
- ausência de escala associada a hipótese sensível;
- documentação contraditória entre imagens.

## 14. Notas de Implementação

Separar logicamente:

- motor visual;
- motor textual;
- motor de segurança;
- classificador operacional;
- módulo de cautela;
- gerador de resposta.

Além disso:

- observação visual deve ser serializada separadamente de hipótese;
- `nível_de_cautela` não deve ser tratado como `confiança científica`;
- ausência de dados deve produzir bloqueio ou limitação, nunca preenchimento inferido;
- respostas devem ser curtas, padronizadas e comparáveis entre chamadas.

## 15. Lacunas Críticas

- ausência de dataset nacional padronizado;
- dependência extrema da superfície;
- variabilidade fotográfica;
- ausência de contexto tridimensional;
- necessidade de revisão técnica especializada antes de uso operacional ampliado;
- necessidade de validação de linguagem para evitar falsa aparência de certeza.

## 16. Arquitetura de Prompts

### CAMADA_01 - Segurança

Bloqueio de afirmações proibidas, separação entre observação e hipótese e redução de inferência quando faltarem dados mínimos.

### CAMADA_02 - Extração Visual

Leitura morfológica conservadora, identificação de limitações e qualificação da documentação fotográfica.

### CAMADA_03 - Classificação Operacional

Sugestão de compatibilidades visuais, padrões alternativos plausíveis e nível de cautela correspondente.

### CAMADA_04 - Geração Textual

Padronização linguística, inserção obrigatória de cautelas, mensagens de insuficiência e recomendação de validação humana quando aplicável.

## Referências de Validação Conceitual

Este material foi estruturado para uso conservador e assistivo, em linha com a ênfase metodológica e de limitações documentais observada em publicações técnicas como:

- OSAC / NIST, `Standard Methodology in Bloodstain Pattern Analysis`;
- National Institute of Justice, `Accuracy and Reproducibility of Conclusions by Forensic Bloodstain Pattern Analysts`.
