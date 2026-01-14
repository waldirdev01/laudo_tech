import 'cadaver_model.dart';
import 'dano_model.dart';
import 'detatlhes_local.dart';
import 'equipe_ficha_model.dart';
import 'equipe_policial_ficha_model.dart';
import 'equipe_resgate_model.dart';
import 'evidencia_model.dart';
import 'ficha_base_model.dart';
import 'local_ficha_model.dart';
import 'solicitacao_model.dart';
import 'tipo_ocorrencia.dart';
import 'veiculo_model.dart';

/// Modelo completo de uma ficha (combina dados da solicitação + dados preenchidos)
class FichaCompletaModel {
  final String id;
  final TipoOcorrencia tipoOcorrencia;
  final SolicitacaoModel dadosSolicitacao;

  // Dados da primeira tabela (SOLICITAÇÃO)
  final String? dataHoraDeslocamento;
  final String? dataHoraInicio;
  final String? dataHoraTermino; // Pode ficar em branco
  final String? pedidoDilacao;

  // Dados da equipe de perícia
  final EquipeFichaModel? equipe;

  // Dados das demais equipes policiais/de salvamento
  final List<EquipePolicialFichaModel>? equipesPoliciais;
  final bool? naoHaviaEquipesPoliciais; // Indica se não havia equipes no local

  // Dados da equipe de resgate (separado das equipes policiais)
  final List<EquipeResgateModel>? equipesResgate;

  // Dados do local
  final LocalFichaModel? local;

  // Dados da ficha base (HISTÓRICO, ISOLAMENTO, PRESERVAÇÃO, CONDIÇÕES METEOROLÓGICAS)
  final FichaBaseModel? dadosFichaBase;

  // Dados específicos por tipo de ocorrência (ex: LocalFurtoModel para FURTO)
  final LocalFurtoModel? localFurto;
  final EvidenciasFurtoModel? evidenciasFurto;

  // Modus Operandi
  final String? modusOperandi;

  // Conclusão do laudo (true = positiva, false = negativa, null = não escolhido)
  final bool? conclusaoPositiva;

  // Levantamento fotográfico (caminhos persistidos no diretório do app)
  final List<String> fotosLevantamento;

  // Dados específicos para investigação de dano (art. 163 - CP/1940)
  final DanoModel? dano;

  // Dados específicos para CVLI - Cadáveres
  final List<CadaverModel>? cadaveres;

  // Dados específicos para CVLI - Veículos
  final List<VeiculoModel>? veiculos;

  final DateTime dataCriacao;
  final DateTime? dataUltimaAtualizacao;

  FichaCompletaModel({
    required this.id,
    required this.tipoOcorrencia,
    required this.dadosSolicitacao,
    this.dataHoraDeslocamento,
    this.dataHoraInicio,
    this.dataHoraTermino,
    this.pedidoDilacao,
    this.equipe,
    this.equipesPoliciais,
    this.naoHaviaEquipesPoliciais,
    this.equipesResgate,
    this.local,
    this.dadosFichaBase,
    this.localFurto,
    this.evidenciasFurto,
    this.modusOperandi,
    this.conclusaoPositiva,
    this.fotosLevantamento = const [],
    this.dano,
    this.cadaveres,
    this.veiculos,
    required this.dataCriacao,
    this.dataUltimaAtualizacao,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipoOcorrencia': tipoOcorrencia.name,
    'dadosSolicitacao': dadosSolicitacao.toJson(),
    'dataHoraDeslocamento': dataHoraDeslocamento,
    'dataHoraInicio': dataHoraInicio,
    'dataHoraTermino': dataHoraTermino,
    'pedidoDilacao': pedidoDilacao,
    'equipe': equipe?.toJson(),
    'equipesPoliciais': equipesPoliciais?.map((e) => e.toJson()).toList(),
    'naoHaviaEquipesPoliciais': naoHaviaEquipesPoliciais,
    'equipesResgate': equipesResgate?.map((e) => e.toJson()).toList(),
    'local': local?.toJson(),
    'dadosFichaBase': dadosFichaBase?.toJson(),
    'localFurto': localFurto?.toJson(),
    'evidenciasFurto': evidenciasFurto?.toJson(),
    'modusOperandi': modusOperandi,
    'conclusaoPositiva': conclusaoPositiva,
    'fotosLevantamento': fotosLevantamento,
    'dano': dano?.toJson(),
    'cadaveres': cadaveres?.map((c) => c.toJson()).toList(),
    'veiculos': veiculos?.map((v) => v.toJson()).toList(),
    'dataCriacao': dataCriacao.toIso8601String(),
    'dataUltimaAtualizacao': dataUltimaAtualizacao?.toIso8601String(),
  };

  factory FichaCompletaModel.fromJson(Map<String, dynamic> json) {
    return FichaCompletaModel(
      id: json['id'] as String,
      tipoOcorrencia: TipoOcorrencia.values.firstWhere(
        (e) => e.name == json['tipoOcorrencia'],
        orElse: () => TipoOcorrencia.furtoDanoExameLocal,
      ),
      dadosSolicitacao: SolicitacaoModel.fromJson(
        json['dadosSolicitacao'] as Map<String, dynamic>,
      ),
      dataHoraDeslocamento: json['dataHoraDeslocamento'] as String?,
      dataHoraInicio: json['dataHoraInicio'] as String?,
      dataHoraTermino: json['dataHoraTermino'] as String?,
      pedidoDilacao: json['pedidoDilacao'] as String?,
      equipe: json['equipe'] != null
          ? EquipeFichaModel.fromJson(json['equipe'] as Map<String, dynamic>)
          : null,
      equipesPoliciais: json['equipesPoliciais'] != null
          ? (json['equipesPoliciais'] as List<dynamic>)
                .map(
                  (e) => EquipePolicialFichaModel.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList()
          : null,
      naoHaviaEquipesPoliciais: json['naoHaviaEquipesPoliciais'] as bool?,
      equipesResgate: json['equipesResgate'] != null
          ? (json['equipesResgate'] as List<dynamic>)
                .map(
                  (e) => EquipeResgateModel.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
      local: json['local'] != null
          ? LocalFichaModel.fromJson(json['local'] as Map<String, dynamic>)
          : null,
      dadosFichaBase: json['dadosFichaBase'] != null
          ? FichaBaseModel.fromJson(
              json['dadosFichaBase'] as Map<String, dynamic>,
            )
          : null,
      localFurto: json['localFurto'] != null
          ? LocalFurtoModel.fromJson(json['localFurto'] as Map<String, dynamic>)
          : null,
      evidenciasFurto: json['evidenciasFurto'] != null
          ? EvidenciasFurtoModel.fromJson(
              json['evidenciasFurto'] as Map<String, dynamic>,
            )
          : null,
      modusOperandi: json['modusOperandi'] as String?,
      conclusaoPositiva: json['conclusaoPositiva'] as bool?,
      fotosLevantamento:
          (json['fotosLevantamento'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dano: json['dano'] != null
          ? DanoModel.fromJson(json['dano'] as Map<String, dynamic>)
          : null,
      cadaveres: json['cadaveres'] != null
          ? (json['cadaveres'] as List<dynamic>)
                .map((c) => CadaverModel.fromJson(c as Map<String, dynamic>))
                .toList()
          : null,
      veiculos: json['veiculos'] != null
          ? (json['veiculos'] as List<dynamic>)
                .map((v) => VeiculoModel.fromJson(v as Map<String, dynamic>))
                .toList()
          : null,
      dataCriacao: DateTime.parse(json['dataCriacao'] as String),
      dataUltimaAtualizacao: json['dataUltimaAtualizacao'] != null
          ? DateTime.parse(json['dataUltimaAtualizacao'] as String)
          : null,
    );
  }

  FichaCompletaModel copyWith({
    String? id,
    TipoOcorrencia? tipoOcorrencia,
    SolicitacaoModel? dadosSolicitacao,
    String? dataHoraDeslocamento,
    String? dataHoraInicio,
    String? dataHoraTermino,
    String? pedidoDilacao,
    EquipeFichaModel? equipe,
    List<EquipePolicialFichaModel>? equipesPoliciais,
    bool? naoHaviaEquipesPoliciais,
    List<EquipeResgateModel>? equipesResgate,
    LocalFichaModel? local,
    FichaBaseModel? dadosFichaBase,
    LocalFurtoModel? localFurto,
    EvidenciasFurtoModel? evidenciasFurto,
    String? modusOperandi,
    bool? conclusaoPositiva,
    List<String>? fotosLevantamento,
    DanoModel? dano,
    List<CadaverModel>? cadaveres,
    List<VeiculoModel>? veiculos,
    DateTime? dataCriacao,
    DateTime? dataUltimaAtualizacao,
  }) {
    return FichaCompletaModel(
      id: id ?? this.id,
      tipoOcorrencia: tipoOcorrencia ?? this.tipoOcorrencia,
      dadosSolicitacao: dadosSolicitacao ?? this.dadosSolicitacao,
      dataHoraDeslocamento: dataHoraDeslocamento ?? this.dataHoraDeslocamento,
      dataHoraInicio: dataHoraInicio ?? this.dataHoraInicio,
      dataHoraTermino: dataHoraTermino ?? this.dataHoraTermino,
      pedidoDilacao: pedidoDilacao ?? this.pedidoDilacao,
      equipe: equipe ?? this.equipe,
      equipesPoliciais: equipesPoliciais ?? this.equipesPoliciais,
      naoHaviaEquipesPoliciais:
          naoHaviaEquipesPoliciais ?? this.naoHaviaEquipesPoliciais,
      // Se passar uma lista vazia explicitamente ([]), usar null para limpar.
      // Se passar null, manter o valor anterior.
      // Se passar uma lista não vazia, usar ela.
      equipesResgate: equipesResgate == null
          ? this.equipesResgate
          : (equipesResgate.isEmpty ? null : equipesResgate),
      local: local ?? this.local,
      dadosFichaBase: dadosFichaBase ?? this.dadosFichaBase,
      localFurto: localFurto ?? this.localFurto,
      evidenciasFurto: evidenciasFurto ?? this.evidenciasFurto,
      modusOperandi: modusOperandi ?? this.modusOperandi,
      conclusaoPositiva: conclusaoPositiva ?? this.conclusaoPositiva,
      fotosLevantamento: fotosLevantamento ?? this.fotosLevantamento,
      dano: dano ?? this.dano,
      cadaveres: cadaveres ?? this.cadaveres,
      veiculos: veiculos ?? this.veiculos,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      dataUltimaAtualizacao:
          dataUltimaAtualizacao ?? this.dataUltimaAtualizacao,
    );
  }
}
