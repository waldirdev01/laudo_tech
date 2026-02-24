/// Modelo para dados de veículo em CVLI
library;

import 'vestigio_veiculo_model.dart';

T? _enumFromName<T extends Enum>(Iterable<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

List<T>? _enumListFromJson<T extends Enum>(
  List<dynamic>? raw,
  List<T> values,
) {
  if (raw == null) return null;
  final result = <T>[];
  for (final entry in raw) {
    final value = _enumFromName(values, entry as String?);
    if (value != null) {
      result.add(value);
    }
  }
  return result.isEmpty ? null : result;
}

enum TipoVeiculo {
  automovel('Automóvel'),
  motocicleta('Motocicleta'),
  caminhao('Caminhão'),
  onibus('Ônibus'),
  outro('Outro');

  final String label;
  const TipoVeiculo(this.label);
}

enum PosicaoVeiculo {
  estacionado('Estacionado'),
  paradoNaVia('Parado na via'),
  tombado('Tombado'),
  incendiado('Incendiado'),
  outra('Outra');

  final String label;
  const PosicaoVeiculo(this.label);
}

enum RelacaoVeiculo {
  veiculoVitima('Veículo da vítima'),
  veiculoSuspeito('Veículo do suspeito'),
  veiculoTerceiro('Veículo de terceiro'),
  indeterminado('Indeterminado');

  final String label;
  const RelacaoVeiculo(this.label);
}

enum IntensidadeDano { leve, media, grave, gravissima }

enum SetorImpacto {
  anterior,
  posterior,
  lateralEsquerdo,
  lateralDireito,
  angularAnteriorEsquerdo,
  angularAnteriorDireito,
  angularPosteriorEsquerdo,
  angularPosteriorDireito,
}

enum TipificacaoDeformacao {
  amassamento,
  cisalhamento,
  arrastamento,
  empenamento,
  arrancamento,
  estampamento,
  quebramento,
  esmagamento,
  sanfonamento,
  mossa,
  atritamento,
  afundamento,
}

enum OrientacaoDeformacao {
  direitaParaEsquerda,
  esquerdaParaDireita,
  dianteiraParaTraseira,
  traseiraParaDianteira,
}

enum StatusComponenteVeiculo { funcionando, naoFuncionando, prejudicado }

enum EstadoPneumaticos { novos, meiaVida, desgastados }

enum AirbagStatus { acionado, naoAcionado, ausente }

enum RetrovisorStatus { presente, ausente }

enum TacografoStatus { ausente, recolhido }

/// Modelo para veículo encontrado na cena
class VeiculoModel {
  final String? id;
  final int numero; // Veículo 1, 2, 3...

  // Identificação básica
  final TipoVeiculo? tipoVeiculo;
  final String? tipoVeiculoOutro; // Se tipoVeiculo == outro
  final String? marcaModelo;
  final String? anoFabricacao;
  final String? anoModelo;
  final String? cor;
  final String? placa;
  final String? chassiAparente;

  // Localização no ambiente
  final String?
      localizacaoAmbiente; // ex: "estacionado na rua", "no centro da via"

  // Coordenadas opcionais
  final String? coordenadaFrenteX;
  final String? coordenadaFrenteY;
  final String? alturaFrente;
  final String? coordenadaTraseiraX;
  final String? coordenadaTraseiraY;
  final String? alturaTraseira;
  final String? coordenadaCentroX;
  final String? coordenadaCentroY;
  final String? alturaCentro;

  // Estado e posição
  final PosicaoVeiculo? posicao;
  final String? posicaoLivre; // Se posicao == outra
  final String? condicaoGeral;
  final IntensidadeDano? intensidadeDano;
  final List<SetorImpacto>? setoresImpacto;
  final List<TipificacaoDeformacao>? tipificacoesDeformacoes;
  final List<OrientacaoDeformacao>? orientacoesDeformacoes;
  final String? danosObservacoes;
  final StatusComponenteVeiculo? faroisLanternas;
  final StatusComponenteVeiculo? cintosSeguranca;
  final EstadoPneumaticos? estadoPneumaticos;
  final StatusComponenteVeiculo? freios;
  final StatusComponenteVeiculo? direcao;
  final AirbagStatus? airbag;
  final RetrovisorStatus? retrovisor;
  final TacografoStatus? tacografoStatus;
  final String? frenagemMetros;
  final String? bicicletaCor;
  final String? bicicletaMarcaModelo;
  final String? bicicletaElementosSinalizacao;
  final bool? bicicletaPossuiCampainha;

  /// Fotos do veículo no ambiente (obrigatório ao menos uma para o laudo).
  final List<String> fotosVistaVeiculoAmbiente;

  // Vestígios/Evidências (novo sistema)
  final List<VestigioVeiculoModel>? vestigios;

  // Vestígios/Evidências (campos antigos - mantidos para compatibilidade)
  final bool? presencaSangue;
  final String?
      localizacaoSangue; // Campo condicional se presencaSangue == true
  final bool? presencaProjeteisImpactos;
  final String?
      localizacaoProjeteisImpactos; // Campo condicional se presencaProjeteisImpactos == true
  final String? descricaoDanos;
  final String? outrosVestigios;

  // Relacionamento com o caso
  final RelacaoVeiculo? relacao;
  final String? observacoes;

  VeiculoModel({
    this.id,
    required this.numero,
    this.tipoVeiculo,
    this.tipoVeiculoOutro,
    this.marcaModelo,
    this.anoFabricacao,
    this.anoModelo,
    this.cor,
    this.placa,
    this.chassiAparente,
    this.localizacaoAmbiente,
    this.coordenadaFrenteX,
    this.coordenadaFrenteY,
    this.alturaFrente,
    this.coordenadaTraseiraX,
    this.coordenadaTraseiraY,
    this.alturaTraseira,
    this.coordenadaCentroX,
    this.coordenadaCentroY,
    this.alturaCentro,
    this.posicao,
    this.posicaoLivre,
    this.condicaoGeral,
    this.intensidadeDano,
    this.setoresImpacto,
    this.tipificacoesDeformacoes,
    this.orientacoesDeformacoes,
    this.danosObservacoes,
    this.faroisLanternas,
    this.cintosSeguranca,
    this.estadoPneumaticos,
    this.freios,
    this.direcao,
    this.airbag,
    this.retrovisor,
    this.tacografoStatus,
    this.frenagemMetros,
    this.bicicletaCor,
    this.bicicletaMarcaModelo,
    this.bicicletaElementosSinalizacao,
    this.bicicletaPossuiCampainha,
    this.fotosVistaVeiculoAmbiente = const [],
    this.vestigios,
    this.presencaSangue,
    this.localizacaoSangue,
    this.presencaProjeteisImpactos,
    this.localizacaoProjeteisImpactos,
    this.descricaoDanos,
    this.outrosVestigios,
    this.relacao,
    this.observacoes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero': numero,
        'tipoVeiculo': tipoVeiculo?.name,
        'tipoVeiculoOutro': tipoVeiculoOutro,
        'marcaModelo': marcaModelo,
        'anoFabricacao': anoFabricacao,
        'anoModelo': anoModelo,
        'cor': cor,
        'placa': placa,
        'chassiAparente': chassiAparente,
        'localizacaoAmbiente': localizacaoAmbiente,
        'coordenadaFrenteX': coordenadaFrenteX,
        'coordenadaFrenteY': coordenadaFrenteY,
        'alturaFrente': alturaFrente,
        'coordenadaTraseiraX': coordenadaTraseiraX,
        'coordenadaTraseiraY': coordenadaTraseiraY,
        'alturaTraseira': alturaTraseira,
        'coordenadaCentroX': coordenadaCentroX,
        'coordenadaCentroY': coordenadaCentroY,
        'alturaCentro': alturaCentro,
        'posicao': posicao?.name,
        'posicaoLivre': posicaoLivre,
        'condicaoGeral': condicaoGeral,
        'intensidadeDano': intensidadeDano?.name,
        'setoresImpacto': setoresImpacto?.map((e) => e.name).toList(),
        'tipificacoesDeformacoes':
            tipificacoesDeformacoes?.map((e) => e.name).toList(),
        'orientacoesDeformacoes':
            orientacoesDeformacoes?.map((e) => e.name).toList(),
        'danosObservacoes': danosObservacoes,
        'faroisLanternas': faroisLanternas?.name,
        'cintosSeguranca': cintosSeguranca?.name,
        'estadoPneumaticos': estadoPneumaticos?.name,
        'freios': freios?.name,
        'direcao': direcao?.name,
        'airbag': airbag?.name,
        'retrovisor': retrovisor?.name,
        'tacografoStatus': tacografoStatus?.name,
        'frenagemMetros': frenagemMetros,
        'bicicletaCor': bicicletaCor,
        'bicicletaMarcaModelo': bicicletaMarcaModelo,
        'bicicletaElementosSinalizacao': bicicletaElementosSinalizacao,
        'bicicletaPossuiCampainha': bicicletaPossuiCampainha,
        'fotosVistaVeiculoAmbiente': fotosVistaVeiculoAmbiente,
        'vestigios': vestigios?.map((v) => v.toJson()).toList(),
        'presencaSangue': presencaSangue,
        'localizacaoSangue': localizacaoSangue,
        'presencaProjeteisImpactos': presencaProjeteisImpactos,
        'localizacaoProjeteisImpactos': localizacaoProjeteisImpactos,
        'descricaoDanos': descricaoDanos,
        'outrosVestigios': outrosVestigios,
        'relacao': relacao?.name,
        'observacoes': observacoes,
      };

  factory VeiculoModel.fromJson(Map<String, dynamic> json) {
    TipoVeiculo? tipoVeiculo;
    if (json['tipoVeiculo'] != null) {
      tipoVeiculo = TipoVeiculo.values.firstWhere(
        (e) => e.name == json['tipoVeiculo'],
        orElse: () => TipoVeiculo.automovel,
      );
    }

    PosicaoVeiculo? posicao;
    if (json['posicao'] != null) {
      posicao = PosicaoVeiculo.values.firstWhere(
        (e) => e.name == json['posicao'],
        orElse: () => PosicaoVeiculo.estacionado,
      );
    }

    RelacaoVeiculo? relacao;
    if (json['relacao'] != null) {
      relacao = RelacaoVeiculo.values.firstWhere(
        (e) => e.name == json['relacao'],
        orElse: () => RelacaoVeiculo.indeterminado,
      );
    }

    List<VestigioVeiculoModel>? vestigios;
    if (json['vestigios'] != null) {
      vestigios = (json['vestigios'] as List)
          .map((v) => VestigioVeiculoModel.fromJson(v as Map<String, dynamic>))
          .toList();
    }

    return VeiculoModel(
      id: json['id'] as String?,
      numero: json['numero'] as int? ?? 1,
      tipoVeiculo: tipoVeiculo,
      tipoVeiculoOutro: json['tipoVeiculoOutro'] as String?,
      marcaModelo: json['marcaModelo'] as String?,
      anoFabricacao: json['anoFabricacao'] as String? ??
          json['ano'] as String?, // Compatibilidade com dados antigos
      anoModelo: json['anoModelo'] as String?,
      cor: json['cor'] as String?,
      placa: json['placa'] as String?,
      chassiAparente: json['chassiAparente'] as String?,
      localizacaoAmbiente: json['localizacaoAmbiente'] as String?,
      coordenadaFrenteX: json['coordenadaFrenteX'] as String?,
      coordenadaFrenteY: json['coordenadaFrenteY'] as String?,
      alturaFrente: json['alturaFrente'] as String?,
      coordenadaTraseiraX: json['coordenadaTraseiraX'] as String?,
      coordenadaTraseiraY: json['coordenadaTraseiraY'] as String?,
      alturaTraseira: json['alturaTraseira'] as String?,
      coordenadaCentroX: json['coordenadaCentroX'] as String?,
      coordenadaCentroY: json['coordenadaCentroY'] as String?,
      alturaCentro: json['alturaCentro'] as String?,
      posicao: posicao,
      posicaoLivre: json['posicaoLivre'] as String?,
      condicaoGeral: json['condicaoGeral'] as String?,
      intensidadeDano: _enumFromName(
          IntensidadeDano.values, json['intensidadeDano'] as String?),
      setoresImpacto: _enumListFromJson(
        json['setoresImpacto'] as List<dynamic>?,
        SetorImpacto.values,
      ),
      tipificacoesDeformacoes: _enumListFromJson(
        json['tipificacoesDeformacoes'] as List<dynamic>?,
        TipificacaoDeformacao.values,
      ),
      orientacoesDeformacoes: _enumListFromJson(
        json['orientacoesDeformacoes'] as List<dynamic>?,
        OrientacaoDeformacao.values,
      ),
      danosObservacoes: json['danosObservacoes'] as String?,
      faroisLanternas: _enumFromName(
        StatusComponenteVeiculo.values,
        json['faroisLanternas'] as String?,
      ),
      cintosSeguranca: _enumFromName(
        StatusComponenteVeiculo.values,
        json['cintosSeguranca'] as String?,
      ),
      estadoPneumaticos: _enumFromName(
        EstadoPneumaticos.values,
        json['estadoPneumaticos'] as String?,
      ),
      freios: _enumFromName(
        StatusComponenteVeiculo.values,
        json['freios'] as String?,
      ),
      direcao: _enumFromName(
        StatusComponenteVeiculo.values,
        json['direcao'] as String?,
      ),
      airbag: _enumFromName(AirbagStatus.values, json['airbag'] as String?),
      retrovisor: _enumFromName(
        RetrovisorStatus.values,
        json['retrovisor'] as String?,
      ),
      tacografoStatus: _enumFromName(
        TacografoStatus.values,
        json['tacografoStatus'] as String?,
      ),
      frenagemMetros: json['frenagemMetros'] as String?,
      bicicletaCor: json['bicicletaCor'] as String?,
      bicicletaMarcaModelo: json['bicicletaMarcaModelo'] as String?,
      bicicletaElementosSinalizacao:
          json['bicicletaElementosSinalizacao'] as String?,
      bicicletaPossuiCampainha: json['bicicletaPossuiCampainha'] as bool?,
      fotosVistaVeiculoAmbiente:
          (json['fotosVistaVeiculoAmbiente'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
      vestigios: vestigios,
      presencaSangue: json['presencaSangue'] as bool?,
      localizacaoSangue: json['localizacaoSangue'] as String?,
      presencaProjeteisImpactos: json['presencaProjeteisImpactos'] as bool?,
      localizacaoProjeteisImpactos:
          json['localizacaoProjeteisImpactos'] as String?,
      descricaoDanos: json['descricaoDanos'] as String?,
      outrosVestigios: json['outrosVestigios'] as String?,
      relacao: relacao,
      observacoes: json['observacoes'] as String?,
    );
  }

  VeiculoModel copyWith({
    String? id,
    int? numero,
    TipoVeiculo? tipoVeiculo,
    String? tipoVeiculoOutro,
    String? marcaModelo,
    String? anoFabricacao,
    String? anoModelo,
    String? cor,
    String? placa,
    String? chassiAparente,
    String? localizacaoAmbiente,
    String? coordenadaFrenteX,
    String? coordenadaFrenteY,
    String? alturaFrente,
    String? coordenadaTraseiraX,
    String? coordenadaTraseiraY,
    String? alturaTraseira,
    String? coordenadaCentroX,
    String? coordenadaCentroY,
    String? alturaCentro,
    PosicaoVeiculo? posicao,
    String? posicaoLivre,
    String? condicaoGeral,
    IntensidadeDano? intensidadeDano,
    List<SetorImpacto>? setoresImpacto,
    List<TipificacaoDeformacao>? tipificacoesDeformacoes,
    List<OrientacaoDeformacao>? orientacoesDeformacoes,
    String? danosObservacoes,
    StatusComponenteVeiculo? faroisLanternas,
    StatusComponenteVeiculo? cintosSeguranca,
    EstadoPneumaticos? estadoPneumaticos,
    StatusComponenteVeiculo? freios,
    StatusComponenteVeiculo? direcao,
    AirbagStatus? airbag,
    RetrovisorStatus? retrovisor,
    TacografoStatus? tacografoStatus,
    String? frenagemMetros,
    String? bicicletaCor,
    String? bicicletaMarcaModelo,
    String? bicicletaElementosSinalizacao,
    bool? bicicletaPossuiCampainha,
    List<String>? fotosVistaVeiculoAmbiente,
    List<VestigioVeiculoModel>? vestigios,
    bool? presencaSangue,
    String? localizacaoSangue,
    bool? presencaProjeteisImpactos,
    String? localizacaoProjeteisImpactos,
    String? descricaoDanos,
    String? outrosVestigios,
    RelacaoVeiculo? relacao,
    String? observacoes,
  }) {
    return VeiculoModel(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      tipoVeiculo: tipoVeiculo ?? this.tipoVeiculo,
      tipoVeiculoOutro: tipoVeiculoOutro ?? this.tipoVeiculoOutro,
      marcaModelo: marcaModelo ?? this.marcaModelo,
      anoFabricacao: anoFabricacao ?? this.anoFabricacao,
      anoModelo: anoModelo ?? this.anoModelo,
      cor: cor ?? this.cor,
      placa: placa ?? this.placa,
      chassiAparente: chassiAparente ?? this.chassiAparente,
      localizacaoAmbiente: localizacaoAmbiente ?? this.localizacaoAmbiente,
      coordenadaFrenteX: coordenadaFrenteX ?? this.coordenadaFrenteX,
      coordenadaFrenteY: coordenadaFrenteY ?? this.coordenadaFrenteY,
      alturaFrente: alturaFrente ?? this.alturaFrente,
      coordenadaTraseiraX: coordenadaTraseiraX ?? this.coordenadaTraseiraX,
      coordenadaTraseiraY: coordenadaTraseiraY ?? this.coordenadaTraseiraY,
      alturaTraseira: alturaTraseira ?? this.alturaTraseira,
      coordenadaCentroX: coordenadaCentroX ?? this.coordenadaCentroX,
      coordenadaCentroY: coordenadaCentroY ?? this.coordenadaCentroY,
      alturaCentro: alturaCentro ?? this.alturaCentro,
      posicao: posicao ?? this.posicao,
      posicaoLivre: posicaoLivre ?? this.posicaoLivre,
      condicaoGeral: condicaoGeral ?? this.condicaoGeral,
      intensidadeDano: intensidadeDano ?? this.intensidadeDano,
      setoresImpacto: setoresImpacto ?? this.setoresImpacto,
      tipificacoesDeformacoes:
          tipificacoesDeformacoes ?? this.tipificacoesDeformacoes,
      orientacoesDeformacoes:
          orientacoesDeformacoes ?? this.orientacoesDeformacoes,
      danosObservacoes: danosObservacoes ?? this.danosObservacoes,
      faroisLanternas: faroisLanternas ?? this.faroisLanternas,
      cintosSeguranca: cintosSeguranca ?? this.cintosSeguranca,
      estadoPneumaticos: estadoPneumaticos ?? this.estadoPneumaticos,
      freios: freios ?? this.freios,
      direcao: direcao ?? this.direcao,
      airbag: airbag ?? this.airbag,
      retrovisor: retrovisor ?? this.retrovisor,
      tacografoStatus: tacografoStatus ?? this.tacografoStatus,
      frenagemMetros: frenagemMetros ?? this.frenagemMetros,
      bicicletaCor: bicicletaCor ?? this.bicicletaCor,
      bicicletaMarcaModelo: bicicletaMarcaModelo ?? this.bicicletaMarcaModelo,
      bicicletaElementosSinalizacao:
          bicicletaElementosSinalizacao ?? this.bicicletaElementosSinalizacao,
      bicicletaPossuiCampainha:
          bicicletaPossuiCampainha ?? this.bicicletaPossuiCampainha,
      fotosVistaVeiculoAmbiente:
          fotosVistaVeiculoAmbiente ?? this.fotosVistaVeiculoAmbiente,
      vestigios: vestigios ?? this.vestigios,
      presencaSangue: presencaSangue ?? this.presencaSangue,
      localizacaoSangue: localizacaoSangue ?? this.localizacaoSangue,
      presencaProjeteisImpactos:
          presencaProjeteisImpactos ?? this.presencaProjeteisImpactos,
      localizacaoProjeteisImpactos:
          localizacaoProjeteisImpactos ?? this.localizacaoProjeteisImpactos,
      descricaoDanos: descricaoDanos ?? this.descricaoDanos,
      outrosVestigios: outrosVestigios ?? this.outrosVestigios,
      relacao: relacao ?? this.relacao,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}
