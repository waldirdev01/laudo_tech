T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}

/// Condições do solo do local imediato
enum CondicaoSoloLocal { seco, umido, molhado }

/// Tipos de iluminação predominantes
enum IluminacaoLocal { artificial, naturalDia, ausente }

/// Descrição do traçado da pista
enum TracadoPista {
  curvaEsquerda,
  curvaDireita,
  reto,
  raioAmplo,
  raioPequeno,
  cruzamento,
}

/// Tipo de pista (simples/dupla)
enum TipoPistaRodovia { simples, dupla }

/// Sentido da via
enum SentidoPista { unico, duplo }

/// Perfil da via (relevo)
enum PerfilPista { plano, suave, declive, moderado, aclive, acentuado }

/// Tipo de pavimento da via (seleção única)
enum TipoPavimento {
  asfalto,
  concreto,
  paralelepipedo,
  cascalho,
  terraBatida,
  terraSolta,
}

/// Condições do estado de conservação da via (multi-select)
enum CondicaoViaOpcao {
  seca,
  umida,
  molhada,
  semDefeito,
  comBuracos,
  comOndulacoes,
  emObras,
  escorregadia,
  comContaminantes,
  outro,
}

/// Tipo de contaminante na via (multi-select)
enum ContaminanteTipo {
  oleo,
  areia,
  combustivel,
  outro,
}

/// Condições específicas de via não pavimentada (multi-select)
enum CondicaoViaNaoPavimentada {
  comErosao,
  comValetas,
  poeiraSuspensao,
  alagada,
  vegetacaoNaPista,
  acostamentoIndefinido,
}

/// Placas de sinalização vertical encontradas
enum PlacaVertical {
  paradaObrigatoria,
  deAPreferencia,
  advertencia,
}

/// Estado de conservação da sinalização
enum ConservacaoSinalizacao { boa, regular, ruim }

/// Intensidade do tráfego
enum RegimeTrafego { intenso, moderado, leve, outro }

/// Condição de visibilidade
enum VisibilidadeTipo { boa, reduzida }

/// Tipos de separação entre faixas
enum SeparacaoFaixasOpcao {
  simplesContinua,
  duplaContinua,
  simplesSeccionada,
  duplaContinuaSeccionada,
}

/// Cores das faixas
enum CorFaixa { amarela, branca }

/// Elementos de separação entre pistas
enum SeparacaoPistasOpcao {
  canteiro,
  muretaConcreto,
  tachoes,
  defensa,
  nenhum,
  outro
}

/// Elementos presentes nas laterais da pista
enum ElementoLateral {
  meioFio,
  faixaPintada,
  acostamento,
  muretaConcreto,
  outro
}

/// Estado de conservação do acostamento/lateral
enum ConservacaoEstado { boa, ruim }

/// Orientação cardinal da via (eixo da rodovia)
enum OrientacaoVia {
  norteSul,
  lesteOeste,
  nordesteSudoeste,
  noroesteSudeste,
}

/// Classificação da via conforme CTB (Arts. 60–61)
enum ClassificacaoVia {
  urbanaTransitoRapido,
  urbanaArterial,
  urbanaColetora,
  urbanaLocal,
  ruralRodovia,
  ruralEstrada,
}

/// Destino dado aos pertences encontrados com o envolvido
enum DestinoPertences { recolhido, entregueAPessoa }

/// Equipamentos de segurança utilizados pelos envolvidos
enum CrimeTransitoEquipamentoSeguranca {
  cinto,
  capacete,
  nenhum,
  naoSeAplica,
}

/// Classificação da pessoa envolvida
enum CrimeTransitoClassificacaoEnvolvido { condutor, passageiro, pedestre }

/// Situação clínica observada
enum CrimeTransitoSituacaoEnvolvido { semFerimentos, feridoGrave, obito }

/// Posição em que foi encontrada
enum CrimeTransitoPosicaoEnvolvido { interiorVeiculo, leitoVia, exteriorPista }

/// Tipo da natureza (simples ou composta)
enum CrimeTransitoNaturezaTipo { simples, composta }

/// Formas de interação entre as unidades envolvidas
enum CrimeTransitoFormaInteracao {
  saidaPista,
  colisao,
  colisaoFrontal,
  colisaoOposta,
  objetoFixo,
  capotamento,
  abalroamento,
  colisaoTraseira,
  colisaoTransversal,
  veiculoEstacionado,
  tombamento,
  choque,
  colisaoLateral,
  colisaoObliqua,
  veiculoParado,
  colisaoLongitudinal,
  colisaoOrtogonal,
  pedestre,
  queda,
  atropelamento,
  animal,
  outro,
}

List<T> _mapListFromJson<T extends Enum>(
  List<dynamic>? raw,
  List<T> values,
) =>
    raw
        ?.map(
          (e) => _firstWhereOrNull(values, (v) => v.name == e) ?? values.first,
        )
        .whereType<T>()
        .toList() ??
    const [];

T? _enumFromJson<T extends Enum>(List<T> values, dynamic value) {
  if (value == null) return null;
  return _firstWhereOrNull(values, (v) => v.name == value);
}

/// Informações sobre a sinalização da via (vertical e horizontal)
class CrimeTransitoSinalizacaoInfo {
  // Vertical
  final List<PlacaVertical>? placasVerticais;
  final String? placaAdvertenciaDescricao;
  final ConservacaoSinalizacao? conservacaoVertical;
  // Horizontal
  final List<SeparacaoFaixasOpcao>? separacoesFaixas;
  final List<CorFaixa>? corFaixas;

  const CrimeTransitoSinalizacaoInfo({
    this.placasVerticais,
    this.placaAdvertenciaDescricao,
    this.conservacaoVertical,
    this.separacoesFaixas,
    this.corFaixas,
  });

  Map<String, dynamic> toJson() => {
        'placasVerticais': placasVerticais?.map((e) => e.name).toList(),
        'placaAdvertenciaDescricao': placaAdvertenciaDescricao,
        'conservacaoVertical': conservacaoVertical?.name,
        'separacoesFaixas': separacoesFaixas?.map((e) => e.name).toList(),
        'corFaixas': corFaixas?.map((e) => e.name).toList(),
      };

  factory CrimeTransitoSinalizacaoInfo.fromJson(Map<String, dynamic> json) =>
      CrimeTransitoSinalizacaoInfo(
        placasVerticais: _mapListFromJson(
            json['placasVerticais'] as List<dynamic>?, PlacaVertical.values),
        placaAdvertenciaDescricao:
            json['placaAdvertenciaDescricao'] as String?,
        conservacaoVertical: _enumFromJson(
            ConservacaoSinalizacao.values, json['conservacaoVertical']),
        separacoesFaixas: _mapListFromJson(
            json['separacoesFaixas'] as List<dynamic>?,
            SeparacaoFaixasOpcao.values),
        corFaixas: _mapListFromJson(
            json['corFaixas'] as List<dynamic>?, CorFaixa.values),
      );

  CrimeTransitoSinalizacaoInfo copyWith({
    List<PlacaVertical>? placasVerticais,
    String? placaAdvertenciaDescricao,
    ConservacaoSinalizacao? conservacaoVertical,
    List<SeparacaoFaixasOpcao>? separacoesFaixas,
    List<CorFaixa>? corFaixas,
  }) {
    return CrimeTransitoSinalizacaoInfo(
      placasVerticais: placasVerticais ?? this.placasVerticais,
      placaAdvertenciaDescricao:
          placaAdvertenciaDescricao ?? this.placaAdvertenciaDescricao,
      conservacaoVertical: conservacaoVertical ?? this.conservacaoVertical,
      separacoesFaixas: separacoesFaixas ?? this.separacoesFaixas,
      corFaixas: corFaixas ?? this.corFaixas,
    );
  }
}

/// Informações sobre cada lateral da pista
class CrimeTransitoLateralInfo {
  final List<ElementoLateral>? elementos;
  final String? largura;
  final ConservacaoEstado? conservacao;
  final String? observacoes;

  const CrimeTransitoLateralInfo({
    this.elementos,
    this.largura,
    this.conservacao,
    this.observacoes,
  });

  Map<String, dynamic> toJson() => {
        'elementos': elementos?.map((e) => e.name).toList(),
        'largura': largura,
        'conservacao': conservacao?.name,
        'observacoes': observacoes,
      };

  factory CrimeTransitoLateralInfo.fromJson(Map<String, dynamic> json) =>
      CrimeTransitoLateralInfo(
        elementos: _mapListFromJson(
          json['elementos'] as List<dynamic>?,
          ElementoLateral.values,
        ),
        largura: json['largura'] as String?,
        conservacao:
            _enumFromJson(ConservacaoEstado.values, json['conservacao']),
        observacoes: json['observacoes'] as String?,
      );

  CrimeTransitoLateralInfo copyWith({
    List<ElementoLateral>? elementos,
    String? largura,
    ConservacaoEstado? conservacao,
    String? observacoes,
  }) {
    return CrimeTransitoLateralInfo(
      elementos: elementos ?? this.elementos,
      largura: largura ?? this.largura,
      conservacao: conservacao ?? this.conservacao,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}

/// Descreve as condições da via/pista para crime de trânsito
class CrimeTransitoCondicoesViaModel {
  final ClassificacaoVia? classificacaoVia;
  final List<CondicaoSoloLocal>? condicoesSolo;
  final List<IluminacaoLocal>? iluminacao;
  final List<TracadoPista>? tracados;
  final List<TipoPistaRodovia>? tiposPista;
  final List<SentidoPista>? sentidos;
  final List<PerfilPista>? perfis;
  final String? larguraPista;
  final String? intensidadePerfil;
  final OrientacaoVia? orientacaoVia;
  /// Lados onde há acostamento (ex: "Leste", "Oeste"), derivado da orientação da via
  final List<String>? ladosAcostamento;
  final int? faixasAcostamento;
  final TipoPavimento? tipoPavimento;
  final List<CondicaoViaOpcao>? condicoesVia;
  final List<ContaminanteTipo>? contaminantes;
  final List<CondicaoViaNaoPavimentada>? condicoesNaoPavimentada;
  final String? condicaoViaOutroDescricao;
  final CrimeTransitoSinalizacaoInfo? sinalizacao;
  final RegimeTrafego? regimeTrafego;
  final String? regimeTrafegoOutro;
  final bool? velocidadePorSinalizacao;
  final bool? velocidadePorCTB;
  final String? velocidadeMaxima;
  final int? numeroFaixas;
  final List<String>? largurasFaixas;
  final VisibilidadeTipo? visibilidade;
  final String? visibilidadeReducaoDescricao;
  final List<SeparacaoPistasOpcao>? separacoesPistas;
  final CrimeTransitoLateralInfo? lateralDireita;
  final CrimeTransitoLateralInfo? lateralEsquerda;
  final String? observacoes;

  const CrimeTransitoCondicoesViaModel({
    this.classificacaoVia,
    this.condicoesSolo,
    this.iluminacao,
    this.tracados,
    this.tiposPista,
    this.sentidos,
    this.perfis,
    this.larguraPista,
    this.intensidadePerfil,
    this.orientacaoVia,
    this.ladosAcostamento,
    this.faixasAcostamento,
    this.tipoPavimento,
    this.condicoesVia,
    this.contaminantes,
    this.condicoesNaoPavimentada,
    this.condicaoViaOutroDescricao,
    this.sinalizacao,
    this.regimeTrafego,
    this.regimeTrafegoOutro,
    this.velocidadePorSinalizacao,
    this.velocidadePorCTB,
    this.velocidadeMaxima,
    this.numeroFaixas,
    this.largurasFaixas,
    this.visibilidade,
    this.visibilidadeReducaoDescricao,
    this.separacoesPistas,
    this.lateralDireita,
    this.lateralEsquerda,
    this.observacoes,
  });

  Map<String, dynamic> toJson() => {
        'classificacaoVia': classificacaoVia?.name,
        'condicoesSolo': condicoesSolo?.map((e) => e.name).toList(),
        'iluminacao': iluminacao?.map((e) => e.name).toList(),
        'tracados': tracados?.map((e) => e.name).toList(),
        'tiposPista': tiposPista?.map((e) => e.name).toList(),
        'sentidos': sentidos?.map((e) => e.name).toList(),
        'perfis': perfis?.map((e) => e.name).toList(),
        'larguraPista': larguraPista,
        'intensidadePerfil': intensidadePerfil,
        'orientacaoVia': orientacaoVia?.name,
        'ladosAcostamento': ladosAcostamento,
        'faixasAcostamento': faixasAcostamento,
        'tipoPavimento': tipoPavimento?.name,
        'condicoesVia': condicoesVia?.map((e) => e.name).toList(),
        'contaminantes': contaminantes?.map((e) => e.name).toList(),
        'condicoesNaoPavimentada': condicoesNaoPavimentada?.map((e) => e.name).toList(),
        'condicaoViaOutroDescricao': condicaoViaOutroDescricao,
        'sinalizacao': sinalizacao?.toJson(),
        'regimeTrafego': regimeTrafego?.name,
        'regimeTrafegoOutro': regimeTrafegoOutro,
        'velocidadePorSinalizacao': velocidadePorSinalizacao,
        'velocidadePorCTB': velocidadePorCTB,
        'velocidadeMaxima': velocidadeMaxima,
        'numeroFaixas': numeroFaixas,
        'largurasFaixas': largurasFaixas,
        'visibilidade': visibilidade?.name,
        'visibilidadeReducaoDescricao': visibilidadeReducaoDescricao,
        'separacoesPistas': separacoesPistas?.map((e) => e.name).toList(),
        'lateralDireita': lateralDireita?.toJson(),
        'lateralEsquerda': lateralEsquerda?.toJson(),
        'observacoes': observacoes,
      };

  factory CrimeTransitoCondicoesViaModel.fromJson(Map<String, dynamic> json) =>
      CrimeTransitoCondicoesViaModel(
        classificacaoVia: _enumFromJson(ClassificacaoVia.values, json['classificacaoVia']),
        condicoesSolo: _mapListFromJson(
          json['condicoesSolo'] as List<dynamic>?,
          CondicaoSoloLocal.values,
        ),
        iluminacao: _mapListFromJson(
            json['iluminacao'] as List<dynamic>?, IluminacaoLocal.values),
        tracados: _mapListFromJson(
            json['tracados'] as List<dynamic>?, TracadoPista.values),
        tiposPista: _mapListFromJson(
            json['tiposPista'] as List<dynamic>?, TipoPistaRodovia.values),
        sentidos: _mapListFromJson(
            json['sentidos'] as List<dynamic>?, SentidoPista.values),
        perfis: _mapListFromJson(
            json['perfis'] as List<dynamic>?, PerfilPista.values),
        larguraPista: json['larguraPista'] as String?,
        intensidadePerfil: json['intensidadePerfil'] as String?,
        orientacaoVia: _enumFromJson(OrientacaoVia.values, json['orientacaoVia']),
        ladosAcostamento: (json['ladosAcostamento'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        faixasAcostamento: json['faixasAcostamento'] as int?,
        tipoPavimento: _enumFromJson(TipoPavimento.values, json['tipoPavimento']),
        condicoesVia: _mapListFromJson(
            json['condicoesVia'] as List<dynamic>?, CondicaoViaOpcao.values),
        contaminantes: _mapListFromJson(
            json['contaminantes'] as List<dynamic>?, ContaminanteTipo.values),
        condicoesNaoPavimentada: _mapListFromJson(
            json['condicoesNaoPavimentada'] as List<dynamic>?,
            CondicaoViaNaoPavimentada.values),
        condicaoViaOutroDescricao: json['condicaoViaOutroDescricao'] as String?,
        sinalizacao: json['sinalizacao'] != null
            ? CrimeTransitoSinalizacaoInfo.fromJson(
                json['sinalizacao'] as Map<String, dynamic>,
              )
            : null,
        regimeTrafego:
            _enumFromJson(RegimeTrafego.values, json['regimeTrafego']),
        regimeTrafegoOutro: json['regimeTrafegoOutro'] as String?,
        velocidadePorSinalizacao: json['velocidadePorSinalizacao'] as bool?,
        velocidadePorCTB: json['velocidadePorCTB'] as bool?,
        velocidadeMaxima: json['velocidadeMaxima'] as String?,
        numeroFaixas: json['numeroFaixas'] as int?,
        largurasFaixas: (json['largurasFaixas'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        visibilidade:
            _enumFromJson(VisibilidadeTipo.values, json['visibilidade']),
        visibilidadeReducaoDescricao:
            json['visibilidadeReducaoDescricao'] as String?,
        separacoesPistas: _mapListFromJson(
          json['separacoesPistas'] as List<dynamic>?,
          SeparacaoPistasOpcao.values,
        ),
        lateralDireita: json['lateralDireita'] != null
            ? CrimeTransitoLateralInfo.fromJson(
                json['lateralDireita'] as Map<String, dynamic>,
              )
            : null,
        lateralEsquerda: json['lateralEsquerda'] != null
            ? CrimeTransitoLateralInfo.fromJson(
                json['lateralEsquerda'] as Map<String, dynamic>,
              )
            : null,
        observacoes: json['observacoes'] as String?,
      );

  CrimeTransitoCondicoesViaModel copyWith({
    ClassificacaoVia? classificacaoVia,
    List<CondicaoSoloLocal>? condicoesSolo,
    List<IluminacaoLocal>? iluminacao,
    List<TracadoPista>? tracados,
    List<TipoPistaRodovia>? tiposPista,
    List<SentidoPista>? sentidos,
    List<PerfilPista>? perfis,
    String? larguraPista,
    String? intensidadePerfil,
    OrientacaoVia? orientacaoVia,
    List<String>? ladosAcostamento,
    int? faixasAcostamento,
    TipoPavimento? tipoPavimento,
    List<CondicaoViaOpcao>? condicoesVia,
    List<ContaminanteTipo>? contaminantes,
    List<CondicaoViaNaoPavimentada>? condicoesNaoPavimentada,
    String? condicaoViaOutroDescricao,
    CrimeTransitoSinalizacaoInfo? sinalizacao,
    RegimeTrafego? regimeTrafego,
    String? regimeTrafegoOutro,
    bool? velocidadePorSinalizacao,
    bool? velocidadePorCTB,
    String? velocidadeMaxima,
    int? numeroFaixas,
    List<String>? largurasFaixas,
    VisibilidadeTipo? visibilidade,
    String? visibilidadeReducaoDescricao,
    List<SeparacaoPistasOpcao>? separacoesPistas,
    CrimeTransitoLateralInfo? lateralDireita,
    CrimeTransitoLateralInfo? lateralEsquerda,
    String? observacoes,
  }) {
    return CrimeTransitoCondicoesViaModel(
      classificacaoVia: classificacaoVia ?? this.classificacaoVia,
      condicoesSolo: condicoesSolo ?? this.condicoesSolo,
      iluminacao: iluminacao ?? this.iluminacao,
      tracados: tracados ?? this.tracados,
      tiposPista: tiposPista ?? this.tiposPista,
      sentidos: sentidos ?? this.sentidos,
      perfis: perfis ?? this.perfis,
      larguraPista: larguraPista ?? this.larguraPista,
      intensidadePerfil: intensidadePerfil ?? this.intensidadePerfil,
      orientacaoVia: orientacaoVia ?? this.orientacaoVia,
      ladosAcostamento: ladosAcostamento ?? this.ladosAcostamento,
      faixasAcostamento: faixasAcostamento ?? this.faixasAcostamento,
      tipoPavimento: tipoPavimento ?? this.tipoPavimento,
      condicoesVia: condicoesVia ?? this.condicoesVia,
      contaminantes: contaminantes ?? this.contaminantes,
      condicoesNaoPavimentada: condicoesNaoPavimentada ?? this.condicoesNaoPavimentada,
      condicaoViaOutroDescricao:
          condicaoViaOutroDescricao ?? this.condicaoViaOutroDescricao,
      sinalizacao: sinalizacao ?? this.sinalizacao,
      regimeTrafego: regimeTrafego ?? this.regimeTrafego,
      regimeTrafegoOutro: regimeTrafegoOutro ?? this.regimeTrafegoOutro,
      velocidadePorSinalizacao:
          velocidadePorSinalizacao ?? this.velocidadePorSinalizacao,
      velocidadePorCTB: velocidadePorCTB ?? this.velocidadePorCTB,
      velocidadeMaxima: velocidadeMaxima ?? this.velocidadeMaxima,
      numeroFaixas: numeroFaixas ?? this.numeroFaixas,
      largurasFaixas: largurasFaixas ?? this.largurasFaixas,
      visibilidade: visibilidade ?? this.visibilidade,
      visibilidadeReducaoDescricao:
          visibilidadeReducaoDescricao ?? this.visibilidadeReducaoDescricao,
      separacoesPistas: separacoesPistas ?? this.separacoesPistas,
      lateralDireita: lateralDireita ?? this.lateralDireita,
      lateralEsquerda: lateralEsquerda ?? this.lateralEsquerda,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}

/// Descreve a integridade/estado de um item (vestes, calçado, etc)
class IntegridadeItemModel {
  final bool? integro;
  final String? observacoes;

  const IntegridadeItemModel({
    this.integro,
    this.observacoes,
  });

  Map<String, dynamic> toJson() => {
        'integro': integro,
        'observacoes': observacoes,
      };

  factory IntegridadeItemModel.fromJson(Map<String, dynamic> json) =>
      IntegridadeItemModel(
        integro: json['integro'] as bool?,
        observacoes: json['observacoes'] as String?,
      );

  IntegridadeItemModel copyWith({bool? integro, String? observacoes}) {
    return IntegridadeItemModel(
      integro: integro ?? this.integro,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}

/// Pessoa envolvida na ocorrência de trânsito
class CrimeTransitoEnvolvidoModel {
  final String id;
  final String? nome;
  final String? cnh;
  final String? cnhValidade;
  final String? cnhCategoria;
  final String? rg;
  final String? dataNascimento;
  final CrimeTransitoClassificacaoEnvolvido? classificacao;
  final List<CrimeTransitoEquipamentoSeguranca>? equipamentosSeguranca;
  final CrimeTransitoSituacaoEnvolvido? situacao;
  final CrimeTransitoPosicaoEnvolvido? posicao;
  final String? posicaoDetalhe;
  final IntegridadeItemModel? vestes;
  final IntegridadeItemModel? calcados;
  final bool? pertencesEncontrados;
  final String? pertencesDescricao;
  final DestinoPertences? destinoPertences;
  final String? pertencesEntregueIdentificacao;
  final String? observacoes;
  final List<String>? fotosVistaAmplaPosicaoEncontrado;
  final List<String>? fotosVistaAmplaCenario;
  final List<String>? fotosLesoesPertences;

  const CrimeTransitoEnvolvidoModel({
    required this.id,
    this.nome,
    this.cnh,
    this.cnhValidade,
    this.cnhCategoria,
    this.rg,
    this.dataNascimento,
    this.classificacao,
    this.equipamentosSeguranca,
    this.situacao,
    this.posicao,
    this.posicaoDetalhe,
    this.vestes,
    this.calcados,
    this.pertencesEncontrados,
    this.pertencesDescricao,
    this.destinoPertences,
    this.pertencesEntregueIdentificacao,
    this.observacoes,
    this.fotosVistaAmplaPosicaoEncontrado,
    this.fotosVistaAmplaCenario,
    this.fotosLesoesPertences,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'cnh': cnh,
        'cnhValidade': cnhValidade,
        'cnhCategoria': cnhCategoria,
        'rg': rg,
        'dataNascimento': dataNascimento,
        'classificacao': classificacao?.name,
        'equipamentosSeguranca':
            equipamentosSeguranca?.map((e) => e.name).toList(),
        'situacao': situacao?.name,
        'posicao': posicao?.name,
        'posicaoDetalhe': posicaoDetalhe,
        'vestes': vestes?.toJson(),
        'calcados': calcados?.toJson(),
        'pertencesEncontrados': pertencesEncontrados,
        'pertencesDescricao': pertencesDescricao,
        'destinoPertences': destinoPertences?.name,
        'pertencesEntregueIdentificacao': pertencesEntregueIdentificacao,
        'observacoes': observacoes,
        'fotosVistaAmplaPosicaoEncontrado': fotosVistaAmplaPosicaoEncontrado,
        'fotosVistaAmplaCenario': fotosVistaAmplaCenario,
        'fotosLesoesPertences': fotosLesoesPertences,
      };

  factory CrimeTransitoEnvolvidoModel.fromJson(Map<String, dynamic> json) =>
      CrimeTransitoEnvolvidoModel(
        id: json['id'] as String,
        nome: json['nome'] as String?,
        cnh: json['cnh'] as String?,
        cnhValidade: json['cnhValidade'] as String?,
        cnhCategoria: json['cnhCategoria'] as String?,
        rg: json['rg'] as String?,
        dataNascimento: json['dataNascimento'] as String?,
        classificacao: _enumFromJson(
          CrimeTransitoClassificacaoEnvolvido.values,
          json['classificacao'],
        ),
        equipamentosSeguranca: _mapListFromJson(
          json['equipamentosSeguranca'] as List<dynamic>?,
          CrimeTransitoEquipamentoSeguranca.values,
        ),
        situacao: _enumFromJson(
          CrimeTransitoSituacaoEnvolvido.values,
          json['situacao'],
        ),
        posicao: _enumFromJson(
          CrimeTransitoPosicaoEnvolvido.values,
          json['posicao'],
        ),
        posicaoDetalhe: json['posicaoDetalhe'] as String?,
        vestes: json['vestes'] != null
            ? IntegridadeItemModel.fromJson(
                json['vestes'] as Map<String, dynamic>,
              )
            : null,
        calcados: json['calcados'] != null
            ? IntegridadeItemModel.fromJson(
                json['calcados'] as Map<String, dynamic>,
              )
            : null,
        pertencesEncontrados: json['pertencesEncontrados'] as bool?,
        pertencesDescricao: json['pertencesDescricao'] as String?,
        destinoPertences: _enumFromJson(
            DestinoPertences.values, json['destinoPertences']),
        pertencesEntregueIdentificacao:
            json['pertencesEntregueIdentificacao'] as String?,
        observacoes: json['observacoes'] as String?,
        fotosVistaAmplaPosicaoEncontrado:
            (json['fotosVistaAmplaPosicaoEncontrado'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList(),
        fotosVistaAmplaCenario:
            (json['fotosVistaAmplaCenario'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList(),
        fotosLesoesPertences:
            (json['fotosLesoesPertences'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList(),
      );

  CrimeTransitoEnvolvidoModel copyWith({
    String? id,
    String? nome,
    String? cnh,
    String? cnhValidade,
    String? cnhCategoria,
    String? rg,
    String? dataNascimento,
    CrimeTransitoClassificacaoEnvolvido? classificacao,
    List<CrimeTransitoEquipamentoSeguranca>? equipamentosSeguranca,
    CrimeTransitoSituacaoEnvolvido? situacao,
    CrimeTransitoPosicaoEnvolvido? posicao,
    String? posicaoDetalhe,
    IntegridadeItemModel? vestes,
    IntegridadeItemModel? calcados,
    bool? pertencesEncontrados,
    String? pertencesDescricao,
    DestinoPertences? destinoPertences,
    String? pertencesEntregueIdentificacao,
    String? observacoes,
    List<String>? fotosVistaAmplaPosicaoEncontrado,
    List<String>? fotosVistaAmplaCenario,
    List<String>? fotosLesoesPertences,
  }) {
    return CrimeTransitoEnvolvidoModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      cnh: cnh ?? this.cnh,
      cnhValidade: cnhValidade ?? this.cnhValidade,
      cnhCategoria: cnhCategoria ?? this.cnhCategoria,
      rg: rg ?? this.rg,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      classificacao: classificacao ?? this.classificacao,
      equipamentosSeguranca:
          equipamentosSeguranca ?? this.equipamentosSeguranca,
      situacao: situacao ?? this.situacao,
      posicao: posicao ?? this.posicao,
      posicaoDetalhe: posicaoDetalhe ?? this.posicaoDetalhe,
      vestes: vestes ?? this.vestes,
      calcados: calcados ?? this.calcados,
      pertencesEncontrados: pertencesEncontrados ?? this.pertencesEncontrados,
      pertencesDescricao: pertencesDescricao ?? this.pertencesDescricao,
      destinoPertences: destinoPertences ?? this.destinoPertences,
      pertencesEntregueIdentificacao:
          pertencesEntregueIdentificacao ?? this.pertencesEntregueIdentificacao,
      observacoes: observacoes ?? this.observacoes,
      fotosVistaAmplaPosicaoEncontrado:
          fotosVistaAmplaPosicaoEncontrado ?? this.fotosVistaAmplaPosicaoEncontrado,
      fotosVistaAmplaCenario:
          fotosVistaAmplaCenario ?? this.fotosVistaAmplaCenario,
      fotosLesoesPertences:
          fotosLesoesPertences ?? this.fotosLesoesPertences,
    );
  }
}

/// Informações sobre a natureza da ocorrência de trânsito
class CrimeTransitoNaturezaModel {
  final CrimeTransitoNaturezaTipo? tipo;
  final int? quantidadeUnidades;
  final List<CrimeTransitoFormaInteracao>? formasInteracao;
  final List<CrimeTransitoFormaInteracao>? observacoesComplementares;
  final bool? materialRecolhido;
  final String? materialDescricao;
  final bool? solicitacaoExamesComplementares;
  final String? laboratorioDestino;
  final String? examesDinamica;
  final String? croquiObservacoes;
  final String? observacoes;
  final String? complementoDinamicaFato;
  /// IDs do catálogo [CausasDeterminantesCatalogo] (modelos SDT) escolhidos na Dinâmica do Fato.
  final List<String>? causasDeterminantesIds;

  const CrimeTransitoNaturezaModel({
    this.tipo,
    this.quantidadeUnidades,
    this.formasInteracao,
    this.observacoesComplementares,
    this.materialRecolhido,
    this.materialDescricao,
    this.solicitacaoExamesComplementares,
    this.laboratorioDestino,
    this.examesDinamica,
    this.croquiObservacoes,
    this.observacoes,
    this.complementoDinamicaFato,
    this.causasDeterminantesIds,
  });

  Map<String, dynamic> toJson() => {
        'tipo': tipo?.name,
        'quantidadeUnidades': quantidadeUnidades,
        'formasInteracao': formasInteracao?.map((e) => e.name).toList(),
        'observacoesComplementares':
            observacoesComplementares?.map((e) => e.name).toList(),
        'materialRecolhido': materialRecolhido,
        'materialDescricao': materialDescricao,
        'solicitacaoExamesComplementares': solicitacaoExamesComplementares,
        'laboratorioDestino': laboratorioDestino,
        'examesDinamica': examesDinamica,
        'croquiObservacoes': croquiObservacoes,
        'observacoes': observacoes,
        'complementoDinamicaFato': complementoDinamicaFato,
        'causasDeterminantesIds': causasDeterminantesIds,
      };

  factory CrimeTransitoNaturezaModel.fromJson(Map<String, dynamic> json) =>
      CrimeTransitoNaturezaModel(
        tipo: _enumFromJson(CrimeTransitoNaturezaTipo.values, json['tipo']),
        quantidadeUnidades: json['quantidadeUnidades'] as int?,
        formasInteracao: _mapListFromJson(
          json['formasInteracao'] as List<dynamic>?,
          CrimeTransitoFormaInteracao.values,
        ),
        observacoesComplementares: _mapListFromJson(
          json['observacoesComplementares'] as List<dynamic>?,
          CrimeTransitoFormaInteracao.values,
        ),
        materialRecolhido: json['materialRecolhido'] as bool?,
        materialDescricao: json['materialDescricao'] as String?,
        solicitacaoExamesComplementares:
            json['solicitacaoExamesComplementares'] as bool?,
        laboratorioDestino: json['laboratorioDestino'] as String?,
        examesDinamica: json['examesDinamica'] as String?,
        croquiObservacoes: json['croquiObservacoes'] as String?,
        observacoes: json['observacoes'] as String?,
        complementoDinamicaFato:
            json['complementoDinamicaFato'] as String?,
        causasDeterminantesIds:
            (json['causasDeterminantesIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList(),
      );

  CrimeTransitoNaturezaModel copyWith({
    CrimeTransitoNaturezaTipo? tipo,
    int? quantidadeUnidades,
    List<CrimeTransitoFormaInteracao>? formasInteracao,
    List<CrimeTransitoFormaInteracao>? observacoesComplementares,
    bool? materialRecolhido,
    String? materialDescricao,
    bool? solicitacaoExamesComplementares,
    String? laboratorioDestino,
    String? examesDinamica,
    String? croquiObservacoes,
    String? observacoes,
    String? complementoDinamicaFato,
    List<String>? causasDeterminantesIds,
  }) {
    return CrimeTransitoNaturezaModel(
      tipo: tipo ?? this.tipo,
      quantidadeUnidades: quantidadeUnidades ?? this.quantidadeUnidades,
      formasInteracao: formasInteracao ?? this.formasInteracao,
      observacoesComplementares:
          observacoesComplementares ?? this.observacoesComplementares,
      materialRecolhido: materialRecolhido ?? this.materialRecolhido,
      materialDescricao: materialDescricao ?? this.materialDescricao,
      solicitacaoExamesComplementares: solicitacaoExamesComplementares ??
          this.solicitacaoExamesComplementares,
      laboratorioDestino: laboratorioDestino ?? this.laboratorioDestino,
      examesDinamica: examesDinamica ?? this.examesDinamica,
      croquiObservacoes: croquiObservacoes ?? this.croquiObservacoes,
      observacoes: observacoes ?? this.observacoes,
      complementoDinamicaFato:
          complementoDinamicaFato ?? this.complementoDinamicaFato,
      causasDeterminantesIds:
          causasDeterminantesIds ?? this.causasDeterminantesIds,
    );
  }
}
