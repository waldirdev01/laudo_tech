/// Modelo para dados de veículo em CVLI
library;

import 'vestigio_veiculo_model.dart';

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
      anoFabricacao:
          json['anoFabricacao'] as String? ??
          json['ano'] as String?, // Compatibilidade com dados antigos
      anoModelo: json['anoModelo'] as String?,
      cor: json['cor'] as String?,
      placa: json['placa'] as String?,
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
