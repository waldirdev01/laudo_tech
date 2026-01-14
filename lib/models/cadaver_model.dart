/// Modelo para dados do cadáver em CVLI
library;

enum FaixaEtaria {
  rn('RN'),
  crianca('Criança'),
  adolescente('Adolescente'),
  adulto('Adulto'),
  idoso('Idoso'),
  prejudicado('Prejudicado');

  final String label;
  const FaixaEtaria(this.label);
}

enum SexoCadaver {
  masculino('Masculino'),
  feminino('Feminino'),
  trans('Trans'),
  prejudicado('Prejudicado');

  final String label;
  const SexoCadaver(this.label);
}

enum Compleicao {
  franzina('Franzina'),
  normolinea('Normolínea'),
  robusta('Robusta'),
  prejudicado('Prejudicado');

  final String label;
  const Compleicao(this.label);
}

enum CorCabelo {
  castanho('Castanho'),
  preto('Preto'),
  loiro('Loiro'),
  grisalho('Grisalho'),
  ruivo('Ruivo'),
  outro('Outro');

  final String label;
  const CorCabelo(this.label);
}

enum TipoCabelo {
  liso('Liso'),
  crespo('Crespo'),
  ondulado('Ondulado'),
  outro('Outro');

  final String label;
  const TipoCabelo(this.label);
}

enum TamanhoCabelo {
  curto('Curto'),
  longo('Longo'),
  calvo('Calvo'),
  outro('Outro');

  final String label;
  const TamanhoCabelo(this.label);
}

enum TipoBarba {
  cavanhaque('Cavanhaque'),
  bigode('Bigode'),
  naoSeAplica('Não se Aplica'),
  outro('Outro');

  final String label;
  const TipoBarba(this.label);
}

enum CorBarba {
  castanha('Castanha'),
  preta('Preta'),
  loira('Loira'),
  grisalha('Grisalha'),
  ruiva('Ruiva'),
  outra('Outra');

  final String label;
  const CorBarba(this.label);
}

enum TamanhoBarba {
  aparada('Aparada'),
  longa('Longa'),
  porFazer('Por Fazer'),
  outro('Outro');

  final String label;
  const TamanhoBarba(this.label);
}

enum EstadoRigidez {
  naoInstalada('Não Instalada'),
  emInstalacao('Em Instalação'),
  instalada('Instalada'),
  emDesinstalacao('Em Desinstalação'),
  desinstalada('Desinstalada');

  final String label;
  const EstadoRigidez(this.label);
}

enum EstadoHipostase {
  movel('Móvel'),
  quaseFixas('Quase Fixas'),
  fixas('Fixas'),
  ausente('Ausente');

  final String label;
  const EstadoHipostase(this.label);
}

/// Modelo para uma veste do cadáver
class VesteCadaverModel {
  final String? id;
  final int numero;
  final String? tipoMarca;
  final String? cor;
  final bool? sujidades;
  final bool? sangue;
  final bool? bolsos;
  final bool? bolsosVazios;
  final String? notas;

  VesteCadaverModel({
    this.id,
    required this.numero,
    this.tipoMarca,
    this.cor,
    this.sujidades,
    this.sangue,
    this.bolsos,
    this.bolsosVazios,
    this.notas,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'numero': numero,
    'tipoMarca': tipoMarca,
    'cor': cor,
    'sujidades': sujidades,
    'sangue': sangue,
    'bolsos': bolsos,
    'bolsosVazios': bolsosVazios,
    'notas': notas,
  };

  factory VesteCadaverModel.fromJson(Map<String, dynamic> json) =>
      VesteCadaverModel(
        id: json['id'] as String?,
        numero: json['numero'] as int? ?? 1,
        tipoMarca: json['tipoMarca'] as String?,
        cor: json['cor'] as String?,
        sujidades: json['sujidades'] as bool?,
        sangue: json['sangue'] as bool?,
        bolsos: json['bolsos'] as bool?,
        bolsosVazios: json['bolsosVazios'] as bool?,
        notas: json['notas'] as String?,
      );

  VesteCadaverModel copyWith({
    String? id,
    int? numero,
    String? tipoMarca,
    String? cor,
    bool? sujidades,
    bool? sangue,
    bool? bolsos,
    bool? bolsosVazios,
    String? notas,
  }) {
    return VesteCadaverModel(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      tipoMarca: tipoMarca ?? this.tipoMarca,
      cor: cor ?? this.cor,
      sujidades: sujidades ?? this.sujidades,
      sangue: sangue ?? this.sangue,
      bolsos: bolsos ?? this.bolsos,
      bolsosVazios: bolsosVazios ?? this.bolsosVazios,
      notas: notas ?? this.notas,
    );
  }
}

// ========== ENUMS E MODELO PAF (Projétil de Arma de Fogo) ==========

/// Tipo de lesão PAF
enum TipoLesaoPaf {
  entrada('Entrada'),
  saida('Saída'),
  raspao('Raspão');

  final String label;
  const TipoLesaoPaf(this.label);
}

/// Distância do disparo
enum DistanciaTiro {
  encostado('Encostado'),
  curtaDistancia('Curta distância (com resíduos)'),
  longaDistancia('Longa distância'),
  indeterminada('Indeterminada');

  final String label;
  const DistanciaTiro(this.label);
}

/// Sinais característicos de PAF
class SinaisPaf {
  static const orlaEscoriacao = 'Orla de escoriação (zona de Fisch)';
  static const orlaEnxugo = 'Orla de enxugo';
  static const esfumacamento = 'Esfumaçamento (fuligem)';
  static const chamuscamento = 'Chamuscamento (chama)';
  static const tatuagem = 'Tatuagem (grãos de pólvora)';
  static const bordasInvertidas = 'Bordas invertidas';
  static const bordasEvertidas = 'Bordas evertidas';

  static List<String> get todos => [
    orlaEscoriacao,
    orlaEnxugo,
    esfumacamento,
    chamuscamento,
    tatuagem,
    bordasInvertidas,
    bordasEvertidas,
  ];
}

/// Dados específicos de lesão PAF
class PafData {
  final TipoLesaoPaf tipo;
  final DistanciaTiro? distancia;
  final double? diametro;
  final Set<String> sinais;

  PafData({
    required this.tipo,
    this.distancia,
    this.diametro,
    Set<String>? sinais,
  }) : sinais = sinais ?? {};

  Map<String, dynamic> toJson() => {
    'tipo': tipo.name,
    'distancia': distancia?.name,
    'diametro': diametro,
    'sinais': sinais.toList(),
  };

  factory PafData.fromJson(Map<String, dynamic> json) => PafData(
    tipo: TipoLesaoPaf.values.firstWhere(
      (e) => e.name == json['tipo'],
      orElse: () => TipoLesaoPaf.entrada,
    ),
    distancia: json['distancia'] != null
        ? DistanciaTiro.values.firstWhere(
            (e) => e.name == json['distancia'],
            orElse: () => DistanciaTiro.indeterminada,
          )
        : null,
    diametro: (json['diametro'] as num?)?.toDouble(),
    sinais: Set<String>.from(json['sinais'] as List? ?? []),
  );

  PafData copyWith({
    TipoLesaoPaf? tipo,
    DistanciaTiro? distancia,
    double? diametro,
    Set<String>? sinais,
  }) {
    return PafData(
      tipo: tipo ?? this.tipo,
      distancia: distancia ?? this.distancia,
      diametro: diametro ?? this.diametro,
      sinais: sinais ?? Set<String>.from(this.sinais),
    );
  }
}

/// Aplica presets automáticos de sinais PAF baseado no tipo e distância
Set<String> aplicarPresetPAF(TipoLesaoPaf tipo, DistanciaTiro? distancia) {
  final sinais = <String>{};

  switch (tipo) {
    case TipoLesaoPaf.saida:
      // SAÍDA: apenas bordas evertidas
      sinais.add(SinaisPaf.bordasEvertidas);
      break;

    case TipoLesaoPaf.raspao:
      // RASPÃO: apenas orla de escoriação
      sinais.add(SinaisPaf.orlaEscoriacao);
      break;

    case TipoLesaoPaf.entrada:
      switch (distancia) {
        case DistanciaTiro.encostado:
          // ENTRADA + ENCOSTADO: bordas evertidas
          sinais.add(SinaisPaf.bordasEvertidas);
          break;

        case DistanciaTiro.curtaDistancia:
          // ENTRADA + CURTA DISTÂNCIA: todos os sinais menos bordas evertidas
          sinais.addAll([
            SinaisPaf.orlaEscoriacao,
            SinaisPaf.orlaEnxugo,
            SinaisPaf.esfumacamento,
            SinaisPaf.chamuscamento,
            SinaisPaf.tatuagem,
            SinaisPaf.bordasInvertidas,
          ]);
          break;

        case DistanciaTiro.longaDistancia:
          // ENTRADA + LONGA DISTÂNCIA
          sinais.addAll([
            SinaisPaf.orlaEscoriacao,
            SinaisPaf.orlaEnxugo,
            SinaisPaf.bordasInvertidas,
          ]);
          break;

        case DistanciaTiro.indeterminada:
        case null:
          // Padrão para entrada sem distância definida
          sinais.addAll([
            SinaisPaf.orlaEscoriacao,
            SinaisPaf.orlaEnxugo,
            SinaisPaf.bordasInvertidas,
          ]);
          break;
      }
      break;
  }

  return sinais;
}

/// Gera descrição automática para lesão PAF
String gerarDescricaoPAF({
  required String regiao,
  required TipoLesaoPaf tipo,
  DistanciaTiro? distancia,
  double? diametro,
  required Set<String> sinais,
}) {
  final buffer = StringBuffer();

  buffer.write(
    'Lesão compatível com ferimento por projétil de arma de fogo (PAF)',
  );
  buffer.write(', caracterizada por orifício de ${tipo.label.toLowerCase()}');
  buffer.write(', localizado em $regiao');

  if (diametro != null && diametro > 0) {
    buffer.write(
      ', com diâmetro aproximado de ${diametro.toStringAsFixed(0)} mm',
    );
  }

  if (sinais.isNotEmpty) {
    // Formatar sinais removendo parênteses para descrição mais limpa
    final sinaisFormatados = sinais.map((s) {
      // Remove texto entre parênteses para descrição mais concisa
      return s.replaceAll(RegExp(r'\s*\([^)]*\)'), '').toLowerCase();
    }).toList();

    if (sinaisFormatados.length == 1) {
      buffer.write(', apresentando ${sinaisFormatados.first}');
    } else {
      final ultimoSinal = sinaisFormatados.removeLast();
      buffer.write(
        ', apresentando ${sinaisFormatados.join(", ")} e $ultimoSinal',
      );
    }
  }

  if (tipo != TipoLesaoPaf.saida && distancia != null) {
    String distanciaTexto;
    switch (distancia) {
      case DistanciaTiro.encostado:
        distanciaTexto = 'disparo encostado';
        break;
      case DistanciaTiro.curtaDistancia:
        distanciaTexto = 'disparo a curta distância';
        break;
      case DistanciaTiro.longaDistancia:
        distanciaTexto = 'disparo a longa distância';
        break;
      case DistanciaTiro.indeterminada:
        distanciaTexto = 'distância indeterminada';
        break;
    }
    buffer.write(', compatível com $distanciaTexto');
  }

  buffer.write('.');
  return buffer.toString();
}

/// Gera texto automático para posição do corpo baseado no preset
String gerarTextoPosicaoCorpo({required String? preset, String? textoLivre}) {
  if (preset == null || preset.isEmpty) {
    return textoLivre ?? '';
  }

  if (preset == 'outra') {
    return textoLivre ?? '';
  }

  switch (preset) {
    case 'decubito_dorsal':
      return 'O cadáver encontrava-se em decúbito dorsal (deitado de costas), com o dorso apoiado ao solo e a face voltada para cima.';
    case 'decubito_ventral':
      return 'O cadáver encontrava-se em decúbito ventral (deitado de bruços), com a face voltada para o solo.';
    case 'lateral_direito':
      return 'O cadáver encontrava-se em decúbito lateral direito, apoiado sobre o lado direito do corpo.';
    case 'lateral_esquerdo':
      return 'O cadáver encontrava-se em decúbito lateral esquerdo, apoiado sobre o lado esquerdo do corpo.';
    case 'sentado':
      return 'O cadáver encontrava-se em posição sentada ou semi-sentada, com o tronco ereto ou parcialmente apoiado.';
    case 'fetal':
      return 'O cadáver encontrava-se em posição fetal, com os membros flexionados e o corpo encolhido.';
    case 'genupeitoral':
      return 'O cadáver encontrava-se em posição genupeitoral, com joelhos e tórax apoiados.';
    case 'pendente':
      return 'O cadáver encontrava-se em posição pendente, suspenso por laço ao nível do pescoço.';
    default:
      return textoLivre ?? '';
  }
}

/// Modelo para lesão/evidência no cadáver
class LesaoCadaverModel {
  final String? id;
  final String regiao; // ex: "Frontal", "Torácicas", etc.
  final String? descricao;
  final String? tipo; // PAF, PAB, contusão, etc.
  final bool isPaf;
  final PafData? paf;

  LesaoCadaverModel({
    this.id,
    required this.regiao,
    this.descricao,
    this.tipo,
    this.isPaf = false,
    this.paf,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'regiao': regiao,
    'descricao': descricao,
    'tipo': tipo,
    'isPaf': isPaf,
    'paf': paf?.toJson(),
  };

  factory LesaoCadaverModel.fromJson(Map<String, dynamic> json) =>
      LesaoCadaverModel(
        id: json['id'] as String?,
        regiao: json['regiao'] as String? ?? '',
        descricao: json['descricao'] as String?,
        tipo: json['tipo'] as String?,
        isPaf: json['isPaf'] as bool? ?? false,
        paf: json['paf'] != null
            ? PafData.fromJson(json['paf'] as Map<String, dynamic>)
            : null,
      );

  LesaoCadaverModel copyWith({
    String? id,
    String? regiao,
    String? descricao,
    String? tipo,
    bool? isPaf,
    PafData? paf,
  }) {
    return LesaoCadaverModel(
      id: id ?? this.id,
      regiao: regiao ?? this.regiao,
      descricao: descricao ?? this.descricao,
      tipo: tipo ?? this.tipo,
      isPaf: isPaf ?? this.isPaf,
      paf: paf ?? this.paf,
    );
  }
}

/// Modelo principal do cadáver
class CadaverModel {
  final String? id;
  final int numero; // Cadáver 1, 2, 3...

  // Identificação
  final String? numeroLaudoCadaverico;
  final String? nomeDaVitima;
  final String? documentoIdentificacao;
  final String? dataNascimento;
  final String? filiacao;

  // Características físicas
  final FaixaEtaria? faixaEtaria;
  final SexoCadaver? sexo;
  final Compleicao? compleicao;
  final CorCabelo? corCabelo;
  final String? corCabeloOutro;
  final TipoCabelo? tipoCabelo;
  final String? tipoCabeloOutro;
  final TamanhoCabelo? tamanhoCabelo;
  final String? tamanhoCabeloOutro;
  final TipoBarba? tipoBarba;
  final String? tipoBarbaOutro;
  final CorBarba? corBarba;
  final String? corBarbaOutra;
  final TamanhoBarba? tamanhoBarba;
  final String? tamanhoBarbaOutro;

  // Localização no ambiente
  final String?
  localizacaoAmbiente; // ex: "sobre a cama", "no centro do quarto"

  // Coordenadas opcionais para pontos-chave do corpo
  final String? coordenadaCabecaX; // Coordenada X da cabeça (opcional)
  final String? coordenadaCabecaY; // Coordenada Y da cabeça (opcional)
  final String? alturaCabeca; // Altura da cabeça em relação ao piso (opcional)
  final String? coordenadaPesX; // Coordenada X dos pés (opcional)
  final String? coordenadaPesY; // Coordenada Y dos pés (opcional)
  final String? alturaPes; // Altura dos pés em relação ao piso (opcional)
  final String?
  coordenadaCentroTroncoX; // Coordenada X do centro do tronco (opcional)
  final String?
  coordenadaCentroTroncoY; // Coordenada Y do centro do tronco (opcional)
  final String?
  alturaCentroTronco; // Altura do centro do tronco em relação ao piso (opcional)

  // Posição do corpo
  final String?
  posicaoCorpoPreset; // "decubito_dorsal", "ventral", "lateral_direito", etc.
  final String? posicaoCorpoLivre; // texto livre se preset == "outra"

  // Exames - Rigidez
  final EstadoRigidez? rigidezMandibula;
  final EstadoRigidez? rigidezMemSuperior;
  final EstadoRigidez? rigidezMemInferior;

  // Exames - Manchas de Hipóstase
  final String? hipostasePosicao;
  final EstadoHipostase? hipostaseEstado;
  final bool? hipostaseCompativeis;

  // Exames - Secreções
  final bool? secrecaoNasal;
  final String? secrecaoNasalTipo;
  final bool? secrecaoOral;
  final String? secrecaoOralTipo;
  final bool? secrecaoAnal;
  final String? secrecaoAnalTipo;
  final bool? secrecaoPenianaVaginal;
  final String? secrecaoPenianaVaginalTipo;

  // Outras observações
  final String? outrasObservacoes;

  // Lesões/Evidências no cadáver
  final List<LesaoCadaverModel>? lesoes;

  // Vestes
  final List<VesteCadaverModel>? vestes;

  // Tatuagens e marcas corporais
  final String? tatuagensMarcas;

  // Pertences encontrados com o cadáver
  final String? pertences;

  CadaverModel({
    this.id,
    required this.numero,
    this.numeroLaudoCadaverico,
    this.nomeDaVitima,
    this.documentoIdentificacao,
    this.dataNascimento,
    this.filiacao,
    this.faixaEtaria,
    this.sexo,
    this.compleicao,
    this.corCabelo,
    this.corCabeloOutro,
    this.tipoCabelo,
    this.tipoCabeloOutro,
    this.tamanhoCabelo,
    this.tamanhoCabeloOutro,
    this.tipoBarba,
    this.tipoBarbaOutro,
    this.corBarba,
    this.corBarbaOutra,
    this.tamanhoBarba,
    this.tamanhoBarbaOutro,
    this.localizacaoAmbiente,
    this.coordenadaCabecaX,
    this.coordenadaCabecaY,
    this.alturaCabeca,
    this.coordenadaPesX,
    this.coordenadaPesY,
    this.alturaPes,
    this.coordenadaCentroTroncoX,
    this.coordenadaCentroTroncoY,
    this.alturaCentroTronco,
    this.posicaoCorpoPreset,
    this.posicaoCorpoLivre,
    this.rigidezMandibula,
    this.rigidezMemSuperior,
    this.rigidezMemInferior,
    this.hipostasePosicao,
    this.hipostaseEstado,
    this.hipostaseCompativeis,
    this.secrecaoNasal,
    this.secrecaoNasalTipo,
    this.secrecaoOral,
    this.secrecaoOralTipo,
    this.secrecaoAnal,
    this.secrecaoAnalTipo,
    this.secrecaoPenianaVaginal,
    this.secrecaoPenianaVaginalTipo,
    this.outrasObservacoes,
    this.lesoes,
    this.vestes,
    this.tatuagensMarcas,
    this.pertences,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'numero': numero,
    'numeroLaudoCadaverico': numeroLaudoCadaverico,
    'nomeDaVitima': nomeDaVitima,
    'documentoIdentificacao': documentoIdentificacao,
    'dataNascimento': dataNascimento,
    'filiacao': filiacao,
    'faixaEtaria': faixaEtaria?.name,
    'sexo': sexo?.name,
    'compleicao': compleicao?.name,
    'corCabelo': corCabelo?.name,
    'corCabeloOutro': corCabeloOutro,
    'tipoCabelo': tipoCabelo?.name,
    'tipoCabeloOutro': tipoCabeloOutro,
    'tamanhoCabelo': tamanhoCabelo?.name,
    'tamanhoCabeloOutro': tamanhoCabeloOutro,
    'tipoBarba': tipoBarba?.name,
    'tipoBarbaOutro': tipoBarbaOutro,
    'corBarba': corBarba?.name,
    'corBarbaOutra': corBarbaOutra,
    'tamanhoBarba': tamanhoBarba?.name,
    'tamanhoBarbaOutro': tamanhoBarbaOutro,
    'localizacaoAmbiente': localizacaoAmbiente,
    'coordenadaCabecaX': coordenadaCabecaX,
    'coordenadaCabecaY': coordenadaCabecaY,
    'alturaCabeca': alturaCabeca,
    'coordenadaPesX': coordenadaPesX,
    'coordenadaPesY': coordenadaPesY,
    'alturaPes': alturaPes,
    'coordenadaCentroTroncoX': coordenadaCentroTroncoX,
    'coordenadaCentroTroncoY': coordenadaCentroTroncoY,
    'alturaCentroTronco': alturaCentroTronco,
    'posicaoCorpoPreset': posicaoCorpoPreset,
    'posicaoCorpoLivre': posicaoCorpoLivre,
    'rigidezMandibula': rigidezMandibula?.name,
    'rigidezMemSuperior': rigidezMemSuperior?.name,
    'rigidezMemInferior': rigidezMemInferior?.name,
    'hipostasePosicao': hipostasePosicao,
    'hipostaseEstado': hipostaseEstado?.name,
    'hipostaseCompativeis': hipostaseCompativeis,
    'secrecaoNasal': secrecaoNasal,
    'secrecaoNasalTipo': secrecaoNasalTipo,
    'secrecaoOral': secrecaoOral,
    'secrecaoOralTipo': secrecaoOralTipo,
    'secrecaoAnal': secrecaoAnal,
    'secrecaoAnalTipo': secrecaoAnalTipo,
    'secrecaoPenianaVaginal': secrecaoPenianaVaginal,
    'secrecaoPenianaVaginalTipo': secrecaoPenianaVaginalTipo,
    'outrasObservacoes': outrasObservacoes,
    'lesoes': lesoes?.map((l) => l.toJson()).toList(),
    'vestes': vestes?.map((v) => v.toJson()).toList(),
    'tatuagensMarcas': tatuagensMarcas,
    'pertences': pertences,
  };

  factory CadaverModel.fromJson(Map<String, dynamic> json) {
    return CadaverModel(
      id: json['id'] as String?,
      numero: json['numero'] as int? ?? 1,
      numeroLaudoCadaverico: json['numeroLaudoCadaverico'] as String?,
      nomeDaVitima: json['nomeDaVitima'] as String?,
      documentoIdentificacao: json['documentoIdentificacao'] as String?,
      dataNascimento: json['dataNascimento'] as String?,
      filiacao: json['filiacao'] as String?,
      faixaEtaria: json['faixaEtaria'] != null
          ? FaixaEtaria.values.firstWhere(
              (e) => e.name == json['faixaEtaria'],
              orElse: () => FaixaEtaria.adulto,
            )
          : null,
      sexo: json['sexo'] != null
          ? SexoCadaver.values.firstWhere(
              (e) => e.name == json['sexo'],
              orElse: () => SexoCadaver.masculino,
            )
          : null,
      compleicao: json['compleicao'] != null
          ? Compleicao.values.firstWhere(
              (e) => e.name == json['compleicao'],
              orElse: () => Compleicao.normolinea,
            )
          : null,
      corCabelo: json['corCabelo'] != null
          ? CorCabelo.values.firstWhere(
              (e) => e.name == json['corCabelo'],
              orElse: () => CorCabelo.preto,
            )
          : null,
      corCabeloOutro: json['corCabeloOutro'] as String?,
      tipoCabelo: json['tipoCabelo'] != null
          ? TipoCabelo.values.firstWhere(
              (e) => e.name == json['tipoCabelo'],
              orElse: () => TipoCabelo.liso,
            )
          : null,
      tipoCabeloOutro: json['tipoCabeloOutro'] as String?,
      tamanhoCabelo: json['tamanhoCabelo'] != null
          ? TamanhoCabelo.values.firstWhere(
              (e) => e.name == json['tamanhoCabelo'],
              orElse: () => TamanhoCabelo.curto,
            )
          : null,
      tamanhoCabeloOutro: json['tamanhoCabeloOutro'] as String?,
      tipoBarba: json['tipoBarba'] != null
          ? TipoBarba.values.firstWhere(
              (e) => e.name == json['tipoBarba'],
              orElse: () => TipoBarba.naoSeAplica,
            )
          : null,
      tipoBarbaOutro: json['tipoBarbaOutro'] as String?,
      corBarba: json['corBarba'] != null
          ? CorBarba.values.firstWhere(
              (e) => e.name == json['corBarba'],
              orElse: () => CorBarba.preta,
            )
          : null,
      corBarbaOutra: json['corBarbaOutra'] as String?,
      tamanhoBarba: json['tamanhoBarba'] != null
          ? TamanhoBarba.values.firstWhere(
              (e) => e.name == json['tamanhoBarba'],
              orElse: () => TamanhoBarba.aparada,
            )
          : null,
      tamanhoBarbaOutro: json['tamanhoBarbaOutro'] as String?,
      localizacaoAmbiente: json['localizacaoAmbiente'] as String?,
      coordenadaCabecaX: json['coordenadaCabecaX'] as String?,
      coordenadaCabecaY: json['coordenadaCabecaY'] as String?,
      alturaCabeca: json['alturaCabeca'] as String?,
      coordenadaPesX: json['coordenadaPesX'] as String?,
      coordenadaPesY: json['coordenadaPesY'] as String?,
      alturaPes: json['alturaPes'] as String?,
      coordenadaCentroTroncoX: json['coordenadaCentroTroncoX'] as String?,
      coordenadaCentroTroncoY: json['coordenadaCentroTroncoY'] as String?,
      alturaCentroTronco: json['alturaCentroTronco'] as String?,
      posicaoCorpoPreset: json['posicaoCorpoPreset'] as String?,
      posicaoCorpoLivre: json['posicaoCorpoLivre'] as String?,
      rigidezMandibula: json['rigidezMandibula'] != null
          ? EstadoRigidez.values.firstWhere(
              (e) => e.name == json['rigidezMandibula'],
              orElse: () => EstadoRigidez.naoInstalada,
            )
          : null,
      rigidezMemSuperior: json['rigidezMemSuperior'] != null
          ? EstadoRigidez.values.firstWhere(
              (e) => e.name == json['rigidezMemSuperior'],
              orElse: () => EstadoRigidez.naoInstalada,
            )
          : null,
      rigidezMemInferior: json['rigidezMemInferior'] != null
          ? EstadoRigidez.values.firstWhere(
              (e) => e.name == json['rigidezMemInferior'],
              orElse: () => EstadoRigidez.naoInstalada,
            )
          : null,
      hipostasePosicao: json['hipostasePosicao'] as String?,
      hipostaseEstado: json['hipostaseEstado'] != null
          ? EstadoHipostase.values.firstWhere(
              (e) => e.name == json['hipostaseEstado'],
              orElse: () => EstadoHipostase.movel,
            )
          : null,
      hipostaseCompativeis: json['hipostaseCompativeis'] as bool?,
      secrecaoNasal: json['secrecaoNasal'] as bool?,
      secrecaoNasalTipo: json['secrecaoNasalTipo'] as String?,
      secrecaoOral: json['secrecaoOral'] as bool?,
      secrecaoOralTipo: json['secrecaoOralTipo'] as String?,
      secrecaoAnal: json['secrecaoAnal'] as bool?,
      secrecaoAnalTipo: json['secrecaoAnalTipo'] as String?,
      secrecaoPenianaVaginal: json['secrecaoPenianaVaginal'] as bool?,
      secrecaoPenianaVaginalTipo: json['secrecaoPenianaVaginalTipo'] as String?,
      outrasObservacoes: json['outrasObservacoes'] as String?,
      lesoes: (json['lesoes'] as List<dynamic>?)
          ?.map((l) => LesaoCadaverModel.fromJson(l as Map<String, dynamic>))
          .toList(),
      vestes: (json['vestes'] as List<dynamic>?)
          ?.map((v) => VesteCadaverModel.fromJson(v as Map<String, dynamic>))
          .toList(),
      tatuagensMarcas: json['tatuagensMarcas'] as String?,
      pertences: json['pertences'] as String?,
    );
  }

  CadaverModel copyWith({
    String? id,
    int? numero,
    String? numeroLaudoCadaverico,
    String? nomeDaVitima,
    String? documentoIdentificacao,
    String? dataNascimento,
    String? filiacao,
    FaixaEtaria? faixaEtaria,
    SexoCadaver? sexo,
    Compleicao? compleicao,
    CorCabelo? corCabelo,
    String? corCabeloOutro,
    TipoCabelo? tipoCabelo,
    String? tipoCabeloOutro,
    TamanhoCabelo? tamanhoCabelo,
    String? tamanhoCabeloOutro,
    TipoBarba? tipoBarba,
    String? tipoBarbaOutro,
    CorBarba? corBarba,
    String? corBarbaOutra,
    TamanhoBarba? tamanhoBarba,
    String? tamanhoBarbaOutro,
    String? localizacaoAmbiente,
    String? coordenadaCabecaX,
    String? coordenadaCabecaY,
    String? alturaCabeca,
    String? coordenadaPesX,
    String? coordenadaPesY,
    String? alturaPes,
    String? coordenadaCentroTroncoX,
    String? coordenadaCentroTroncoY,
    String? alturaCentroTronco,
    String? posicaoCorpoPreset,
    String? posicaoCorpoLivre,
    EstadoRigidez? rigidezMandibula,
    EstadoRigidez? rigidezMemSuperior,
    EstadoRigidez? rigidezMemInferior,
    String? hipostasePosicao,
    EstadoHipostase? hipostaseEstado,
    bool? hipostaseCompativeis,
    bool? secrecaoNasal,
    String? secrecaoNasalTipo,
    bool? secrecaoOral,
    String? secrecaoOralTipo,
    bool? secrecaoAnal,
    String? secrecaoAnalTipo,
    bool? secrecaoPenianaVaginal,
    String? secrecaoPenianaVaginalTipo,
    String? outrasObservacoes,
    List<LesaoCadaverModel>? lesoes,
    List<VesteCadaverModel>? vestes,
    String? tatuagensMarcas,
    String? pertences,
  }) {
    return CadaverModel(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      numeroLaudoCadaverico:
          numeroLaudoCadaverico ?? this.numeroLaudoCadaverico,
      nomeDaVitima: nomeDaVitima ?? this.nomeDaVitima,
      documentoIdentificacao:
          documentoIdentificacao ?? this.documentoIdentificacao,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      filiacao: filiacao ?? this.filiacao,
      faixaEtaria: faixaEtaria ?? this.faixaEtaria,
      sexo: sexo ?? this.sexo,
      compleicao: compleicao ?? this.compleicao,
      corCabelo: corCabelo ?? this.corCabelo,
      corCabeloOutro: corCabeloOutro ?? this.corCabeloOutro,
      tipoCabelo: tipoCabelo ?? this.tipoCabelo,
      tipoCabeloOutro: tipoCabeloOutro ?? this.tipoCabeloOutro,
      tamanhoCabelo: tamanhoCabelo ?? this.tamanhoCabelo,
      tamanhoCabeloOutro: tamanhoCabeloOutro ?? this.tamanhoCabeloOutro,
      tipoBarba: tipoBarba ?? this.tipoBarba,
      tipoBarbaOutro: tipoBarbaOutro ?? this.tipoBarbaOutro,
      corBarba: corBarba ?? this.corBarba,
      corBarbaOutra: corBarbaOutra ?? this.corBarbaOutra,
      tamanhoBarba: tamanhoBarba ?? this.tamanhoBarba,
      tamanhoBarbaOutro: tamanhoBarbaOutro ?? this.tamanhoBarbaOutro,
      localizacaoAmbiente: localizacaoAmbiente ?? this.localizacaoAmbiente,
      coordenadaCabecaX: coordenadaCabecaX ?? this.coordenadaCabecaX,
      coordenadaCabecaY: coordenadaCabecaY ?? this.coordenadaCabecaY,
      alturaCabeca: alturaCabeca ?? this.alturaCabeca,
      coordenadaPesX: coordenadaPesX ?? this.coordenadaPesX,
      coordenadaPesY: coordenadaPesY ?? this.coordenadaPesY,
      alturaPes: alturaPes ?? this.alturaPes,
      coordenadaCentroTroncoX:
          coordenadaCentroTroncoX ?? this.coordenadaCentroTroncoX,
      coordenadaCentroTroncoY:
          coordenadaCentroTroncoY ?? this.coordenadaCentroTroncoY,
      alturaCentroTronco: alturaCentroTronco ?? this.alturaCentroTronco,
      posicaoCorpoPreset: posicaoCorpoPreset ?? this.posicaoCorpoPreset,
      posicaoCorpoLivre: posicaoCorpoLivre ?? this.posicaoCorpoLivre,
      rigidezMandibula: rigidezMandibula ?? this.rigidezMandibula,
      rigidezMemSuperior: rigidezMemSuperior ?? this.rigidezMemSuperior,
      rigidezMemInferior: rigidezMemInferior ?? this.rigidezMemInferior,
      hipostasePosicao: hipostasePosicao ?? this.hipostasePosicao,
      hipostaseEstado: hipostaseEstado ?? this.hipostaseEstado,
      hipostaseCompativeis: hipostaseCompativeis ?? this.hipostaseCompativeis,
      secrecaoNasal: secrecaoNasal ?? this.secrecaoNasal,
      secrecaoNasalTipo: secrecaoNasalTipo ?? this.secrecaoNasalTipo,
      secrecaoOral: secrecaoOral ?? this.secrecaoOral,
      secrecaoOralTipo: secrecaoOralTipo ?? this.secrecaoOralTipo,
      secrecaoAnal: secrecaoAnal ?? this.secrecaoAnal,
      secrecaoAnalTipo: secrecaoAnalTipo ?? this.secrecaoAnalTipo,
      secrecaoPenianaVaginal:
          secrecaoPenianaVaginal ?? this.secrecaoPenianaVaginal,
      secrecaoPenianaVaginalTipo:
          secrecaoPenianaVaginalTipo ?? this.secrecaoPenianaVaginalTipo,
      outrasObservacoes: outrasObservacoes ?? this.outrasObservacoes,
      lesoes: lesoes ?? this.lesoes,
      vestes: vestes ?? this.vestes,
      tatuagensMarcas: tatuagensMarcas ?? this.tatuagensMarcas,
      pertences: pertences ?? this.pertences,
    );
  }
}
