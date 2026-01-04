import 'ficha_base_model.dart';
import 'solicitacao_model.dart';
import 'tipo_ocorrencia.dart';
import 'equipe_ficha_model.dart';
import 'equipe_policial_ficha_model.dart';
import 'local_ficha_model.dart';
import 'local_furto_model.dart';
import 'evidencia_model.dart';
import 'dano_model.dart';

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
  
  // Dados do local
  final LocalFichaModel? local;
  
  // Dados da ficha base (HISTÓRICO, ISOLAMENTO, PRESERVAÇÃO, CONDIÇÕES METEOROLÓGICAS)
  final FichaBaseModel? dadosFichaBase;
  
  // Dados específicos por tipo de ocorrência (ex: LocalFurtoModel para FURTO)
  final LocalFurtoModel? localFurto;
  final EvidenciasFurtoModel? evidenciasFurto;
  
  // Modus Operandi
  final String? modusOperandi;
  
  // Dados específicos para investigação de dano (art. 163 - CP/1940)
  final DanoModel? dano;
  
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
    this.local,
    this.dadosFichaBase,
    this.localFurto,
    this.evidenciasFurto,
    this.modusOperandi,
    this.dano,
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
        'local': local?.toJson(),
        'dadosFichaBase': dadosFichaBase?.toJson(),
        'localFurto': localFurto?.toJson(),
        'evidenciasFurto': evidenciasFurto?.toJson(),
        'modusOperandi': modusOperandi,
        'dano': dano?.toJson(),
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
          ? EquipeFichaModel.fromJson(
              json['equipe'] as Map<String, dynamic>,
            )
          : null,
      equipesPoliciais: json['equipesPoliciais'] != null
          ? (json['equipesPoliciais'] as List<dynamic>)
              .map((e) => EquipePolicialFichaModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      naoHaviaEquipesPoliciais: json['naoHaviaEquipesPoliciais'] as bool?,
      local: json['local'] != null
          ? LocalFichaModel.fromJson(json['local'] as Map<String, dynamic>)
          : null,
      dadosFichaBase: json['dadosFichaBase'] != null
          ? FichaBaseModel.fromJson(
              json['dadosFichaBase'] as Map<String, dynamic>,
            )
          : null,
      localFurto: json['localFurto'] != null
          ? LocalFurtoModel.fromJson(
              json['localFurto'] as Map<String, dynamic>,
            )
          : null,
      evidenciasFurto: json['evidenciasFurto'] != null
          ? EvidenciasFurtoModel.fromJson(
              json['evidenciasFurto'] as Map<String, dynamic>,
            )
          : null,
      modusOperandi: json['modusOperandi'] as String?,
      dano: json['dano'] != null
          ? DanoModel.fromJson(json['dano'] as Map<String, dynamic>)
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
    LocalFichaModel? local,
    FichaBaseModel? dadosFichaBase,
    LocalFurtoModel? localFurto,
    EvidenciasFurtoModel? evidenciasFurto,
    String? modusOperandi,
    DanoModel? dano,
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
      naoHaviaEquipesPoliciais: naoHaviaEquipesPoliciais ?? this.naoHaviaEquipesPoliciais,
      local: local ?? this.local,
      dadosFichaBase: dadosFichaBase ?? this.dadosFichaBase,
      localFurto: localFurto ?? this.localFurto,
      evidenciasFurto: evidenciasFurto ?? this.evidenciasFurto,
      modusOperandi: modusOperandi ?? this.modusOperandi,
      dano: dano ?? this.dano,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      dataUltimaAtualizacao: dataUltimaAtualizacao ?? this.dataUltimaAtualizacao,
    );
  }
}

