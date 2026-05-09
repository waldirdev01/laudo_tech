# Bloodstain Prompt Architecture

## Objetivo

Esta arquitetura organiza o uso futuro da base de manchas de sangue no Laudo Tech de forma previsível, conservadora e estável entre chamadas.

## Blocos Recomendados

### 1. Bloco de Segurança

Contém:

- propósito assistivo da funcionalidade;
- proibição de conclusões definitivas;
- obrigação de separar observação, hipótese e limitação;
- obrigação de pedir mais dados quando a documentação for insuficiente.

### 2. Bloco de Contexto Estruturado

Contém:

- tipo de laudo;
- descrição resumida do perito;
- tipo de superfície;
- orientação do plano;
- presença de escala;
- qualidade aparente das imagens;
- relação com ambiente, corpo e objetos.

### 3. Bloco de Regras de Entrada

Contém:

- bloqueio de classificação sem imagem;
- bloqueio de inferência dimensional sem escala;
- redução de escopo quando faltarem foto ampla ou foto aproximada;
- redução de escopo quando houver conflito entre texto e imagem.

### 4. Bloco de Conhecimento Operacional

Contém:

- taxonomia de padrões;
- diferenciações críticas;
- frases seguras;
- expressões proibidas;
- critérios de cautela.

### 5. Bloco de Saída Estruturada

Formato recomendado:

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

## Ordem Recomendada de Montagem do Prompt

1. instruções fixas de segurança;
2. regras de bloqueio e limitação;
3. contexto estruturado do caso;
4. anexos visuais e texto do perito;
5. conhecimento operacional pertinente;
6. formato obrigatório de saída.

## Comportamentos Obrigatórios

- Quando faltarem dados mínimos, responder com limitação e coleta complementar.
- Quando houver mais de uma hipótese plausível, listar alternativas sem fechamento categórico.
- Quando a documentação for fraca, preferir `inespecífico` ou `indeterminado`.
- Nunca tratar `nível_de_cautela` como prova científica.

## Observação

Esta arquitetura foi escrita para ser aproveitada depois tanto em prompts longos quanto em versão serializada para uso em assets JSON.
