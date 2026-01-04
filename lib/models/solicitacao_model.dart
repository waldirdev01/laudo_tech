import 'pessoa_envolvida_model.dart';

/// Modelo para dados extraídos do PDF de SOLICITAÇÃO de Perícia
class SolicitacaoModel {
  // SOLICITAÇÃO
  final String? raiNumero;
  final String? numeroOcorrencia;
  final String? naturezaOcorrencia;
  final String? dataHoraComunicacao;
  final String? dataHoraDeslocamento;
  final String? dataHoraInicio;
  final String? dataHoraTermino;
  final String? pedidoDilacao; // Número do Processo SEI se houver

  // EQUIPE DE PERÍCIA CRIMINAL ACIONADA
  final String? peritoCriminal;
  final String? matriculaPerito;
  final String? fotografoCriminalistico;
  final String? demaisServidoresPoliciais;

  // DEMAIS EQUIPES POLICIAIS/DE SALVAMENTO
  final String? policiaMilitarRodoviariaViatura;
  final List<PessoaEquipe>? equipePolicial;
  final String? autoridadePolicial;
  final String? matriculaAutoridade;
  final List<PessoaEquipe>? agentesPolicia;

  // EQUIPE DE RESGATE
  final bool? cbm;
  final bool? samu;
  final bool? semResgate;
  final String? unidadeNumero;
  final String? medicoAssistente;
  final String? crmGo;
  final String? outrosSocorristas;

  // UNIDADES
  final String? unidadeOrigem; // Unidade requisitante (ORIGEM)
  final String? unidadeAfeta; // Unidade afeta (AFETA)

  // PESSOAS ENVOLVIDAS
  final List<PessoaEnvolvidaModel>? pessoasEnvolvidas;

  // LOCAL
  final String? endereco;
  final String? municipio;
  final String? coordenadasS; // Latitude Sul
  final String? coordenadasW; // Longitude Oeste

  SolicitacaoModel({
    this.raiNumero,
    this.numeroOcorrencia,
    this.naturezaOcorrencia,
    this.dataHoraComunicacao,
    this.dataHoraDeslocamento,
    this.dataHoraInicio,
    this.dataHoraTermino,
    this.pedidoDilacao,
    this.peritoCriminal,
    this.matriculaPerito,
    this.fotografoCriminalistico,
    this.demaisServidoresPoliciais,
    this.policiaMilitarRodoviariaViatura,
    this.equipePolicial,
    this.autoridadePolicial,
    this.matriculaAutoridade,
    this.agentesPolicia,
    this.cbm,
    this.samu,
    this.semResgate,
    this.unidadeNumero,
    this.medicoAssistente,
    this.crmGo,
    this.outrosSocorristas,
    this.unidadeOrigem,
    this.unidadeAfeta,
    this.pessoasEnvolvidas,
    this.endereco,
    this.municipio,
    this.coordenadasS,
    this.coordenadasW,
  });

  Map<String, dynamic> toJson() => {
        'raiNumero': raiNumero,
        'numeroOcorrencia': numeroOcorrencia,
        'naturezaOcorrencia': naturezaOcorrencia,
        'dataHoraComunicacao': dataHoraComunicacao,
        'dataHoraDeslocamento': dataHoraDeslocamento,
        'dataHoraInicio': dataHoraInicio,
        'dataHoraTermino': dataHoraTermino,
        'pedidoDilacao': pedidoDilacao,
        'peritoCriminal': peritoCriminal,
        'matriculaPerito': matriculaPerito,
        'fotografoCriminalistico': fotografoCriminalistico,
        'demaisServidoresPoliciais': demaisServidoresPoliciais,
        'policiaMilitarRodoviariaViatura': policiaMilitarRodoviariaViatura,
        'equipePolicial': equipePolicial?.map((e) => e.toJson()).toList(),
        'autoridadePolicial': autoridadePolicial,
        'matriculaAutoridade': matriculaAutoridade,
        'agentesPolicia': agentesPolicia?.map((e) => e.toJson()).toList(),
        'cbm': cbm,
        'samu': samu,
        'semResgate': semResgate,
        'unidadeNumero': unidadeNumero,
        'medicoAssistente': medicoAssistente,
        'crmGo': crmGo,
        'outrosSocorristas': outrosSocorristas,
        'unidadeOrigem': unidadeOrigem,
        'unidadeAfeta': unidadeAfeta,
        'pessoasEnvolvidas': pessoasEnvolvidas?.map((e) => e.toJson()).toList(),
        'endereco': endereco,
        'municipio': municipio,
        'coordenadasS': coordenadasS,
        'coordenadasW': coordenadasW,
      };

  factory SolicitacaoModel.fromJson(Map<String, dynamic> json) => SolicitacaoModel(
        raiNumero: json['raiNumero'] as String?,
        numeroOcorrencia: json['numeroOcorrencia'] as String?,
        naturezaOcorrencia: json['naturezaOcorrencia'] as String?,
        dataHoraComunicacao: json['dataHoraComunicacao'] as String?,
        dataHoraDeslocamento: json['dataHoraDeslocamento'] as String?,
        dataHoraInicio: json['dataHoraInicio'] as String?,
        dataHoraTermino: json['dataHoraTermino'] as String?,
        pedidoDilacao: json['pedidoDilacao'] as String?,
        peritoCriminal: json['peritoCriminal'] as String?,
        matriculaPerito: json['matriculaPerito'] as String?,
        fotografoCriminalistico: json['fotografoCriminalistico'] as String?,
        demaisServidoresPoliciais: json['demaisServidoresPoliciais'] as String?,
        policiaMilitarRodoviariaViatura: json['policiaMilitarRodoviariaViatura'] as String?,
        equipePolicial: (json['equipePolicial'] as List?)
            ?.map((e) => PessoaEquipe.fromJson(e as Map<String, dynamic>))
            .toList(),
        autoridadePolicial: json['autoridadePolicial'] as String?,
        matriculaAutoridade: json['matriculaAutoridade'] as String?,
        agentesPolicia: (json['agentesPolicia'] as List?)
            ?.map((e) => PessoaEquipe.fromJson(e as Map<String, dynamic>))
            .toList(),
        cbm: json['cbm'] as bool?,
        samu: json['samu'] as bool?,
        semResgate: json['semResgate'] as bool?,
        unidadeNumero: json['unidadeNumero'] as String?,
        medicoAssistente: json['medicoAssistente'] as String?,
        crmGo: json['crmGo'] as String?,
        outrosSocorristas: json['outrosSocorristas'] as String?,
        unidadeOrigem: json['unidadeOrigem'] as String?,
        unidadeAfeta: json['unidadeAfeta'] as String?,
        pessoasEnvolvidas: (json['pessoasEnvolvidas'] as List?)
            ?.map((e) => PessoaEnvolvidaModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        endereco: json['endereco'] as String?,
        municipio: json['municipio'] as String?,
        coordenadasS: json['coordenadasS'] as String?,
        coordenadasW: json['coordenadasW'] as String?,
      );
}

class PessoaEquipe {
  final String? nome;
  final String? matricula;

  PessoaEquipe({this.nome, this.matricula});

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'matricula': matricula,
      };

  factory PessoaEquipe.fromJson(Map<String, dynamic> json) => PessoaEquipe(
        nome: json['nome'] as String?,
        matricula: json['matricula'] as String?,
      );
}

