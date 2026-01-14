import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/pessoa_envolvida_model.dart';
import '../models/solicitacao_model.dart';

/// Serviço para extrair dados de arquivos PDF de solicitação de perícia
class PdfExtractionService {
  static const MethodChannel _channel = MethodChannel('laudo_tech/pdf');

  /// Extrai texto de um arquivo PDF
  Future<String> extrairTexto(String caminhoArquivo) async {
    try {
      // Tentar usar método nativo primeiro (iOS/Android)
      if (Platform.isIOS || Platform.isAndroid) {
        try {
          final resultado = await _channel.invokeMethod<String>('extractText', {
            'path': caminhoArquivo,
          });
          if (resultado != null && resultado.isNotEmpty) {
            return resultado;
          }
        } catch (e) {
          // Se falhar, usar método Flutter
          debugPrint('Erro na extração nativa: $e');
        }
      }

      // Método Flutter usando Syncfusion
      final File arquivo = File(caminhoArquivo);
      if (!await arquivo.exists()) {
        throw Exception('Arquivo PDF não encontrado: $caminhoArquivo');
      }

      final bytes = await arquivo.readAsBytes();
      final texto = extrairTextoBytes(
        bytes,
      ).replaceAll(RegExp(r'[\u0000]'), '').trimRight();
      if (texto.trim().isEmpty) {
        throw Exception('Não foi possível extrair texto do PDF (texto vazio).');
      }
      return texto;
    } catch (e) {
      throw Exception('Erro ao extrair texto do PDF: $e');
    }
  }

  /// Extrai texto de um PDF a partir de bytes (suporta Android quando o FilePicker retorna content URI)
  String extrairTextoBytes(Uint8List bytes) {
    try {
      final PdfDocument documento = PdfDocument(inputBytes: bytes);

      final StringBuffer textoCompleto = StringBuffer();

      for (int i = 0; i < documento.pages.count; i++) {
        final String textoPagina = PdfTextExtractor(
          documento,
        ).extractText(startPageIndex: i, endPageIndex: i);
        textoCompleto.writeln(textoPagina);
      }

      documento.dispose();
      return textoCompleto.toString().replaceAll(RegExp(r'[\u0000]'), '');
    } catch (e) {
      throw Exception('Erro ao extrair texto do PDF: $e');
    }
  }

  /// Extrai texto de um PDF a partir de bytes, tentando método nativo primeiro (Android/iOS).
  Future<String> extrairTextoBytesAsync(Uint8List bytes) async {
    // Android/iOS: tentar extração nativa via MethodChannel
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final resultado = await _channel.invokeMethod<String>('extractText', {
          'bytes': bytes,
        });
        if (resultado != null && resultado.trim().isNotEmpty) {
          return resultado;
        }
      } catch (e) {
        // fallback abaixo
      }
    }

    final texto = extrairTextoBytes(bytes);
    if (texto.trim().isEmpty) {
      throw Exception('Não foi possível extrair texto do PDF (texto vazio).');
    }
    return texto;
  }

  /// Extrai dados estruturados de uma solicitação de perícia
  Future<SolicitacaoModel> extrairDadosSolicitacao(
    String caminhoArquivo,
  ) async {
    final texto = await extrairTexto(caminhoArquivo);

    // Debug: mostrar texto extraído (primeiros 2000 caracteres)

    // Parsear campos específicos do PDF de solicitação
    return _parsearSolicitacao(texto);
  }

  /// Extrai dados estruturados a partir de bytes do PDF
  SolicitacaoModel extrairDadosSolicitacaoBytes(Uint8List bytes) {
    final texto = extrairTextoBytes(bytes);

    // Debug: mostrar texto extraído (primeiros 2000 caracteres)

    return _parsearSolicitacao(texto);
  }

  Future<SolicitacaoModel> extrairDadosSolicitacaoBytesAsync(
    Uint8List bytes,
  ) async {
    final texto = await extrairTextoBytesAsync(bytes);

    // Debug: mostrar texto extraído (primeiros 2000 caracteres)

    return _parsearSolicitacao(texto);
  }

  /// Parseia o texto extraído do PDF para criar SolicitacaoModel
  ///
  /// Objetivo: ser tolerante a variações de layout do PDF (1 ou mais páginas),
  /// linhas quebradas no meio das unidades e diferentes formas do bloco
  /// "Pessoas Envolvidas".
  SolicitacaoModel _parsearSolicitacao(String texto) {
    // Normalização básica do texto bruto
    String raw = texto.replaceAll('\r', '');

    // Alguns PDFs vêm com acentos decompostos (ex.: "Conteu\u0301do").
    // Remover marcas combinantes para tornar regex robusta.
    raw = raw.replaceAll(RegExp(r'[\u0300-\u036f]'), '');

    // Remover ruídos comuns do TCPDF
    raw = raw.replaceAll(
      RegExp(r'Powered by TCPDF.*', caseSensitive: false),
      '',
    );
    raw = raw.replaceAll(
      RegExp(r'Consulta realizada em:.*', caseSensitive: false),
      '',
    );
    raw = raw.replaceAll(
      RegExp(r'Pág\.?\s*\d+\s*de\s*\d+.*', caseSensitive: false),
      '',
    );

    // Normalizar múltiplas quebras de linha
    raw = raw.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Helpers
    String normSpaces(String s) {
      return s.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // Heurística para "descolar" blocos muito conhecidos quando o extrator colou tudo.
    // Mantém mapeamentos específicos e aplica um fallback bem conservador.
    String descolarTextoColado(String s) {
      String out = normSpaces(s);
      if (out.isEmpty) return out;

      final colado = out.replaceAll(RegExp(r'\s+'), '').toUpperCase();

      const fixes = <String, String>{
        // Planaltina (exatamente como aparece em muitos PDFs)
        'CENTRALGERALDEFLAGRANTESEPRONTOATENDIMENTOAOCIDADÃODEPLANALTINADEGOIÁS':
            'CENTRAL GERAL DE FLAGRANTES E PRONTO ATENDIMENTO AO CIDADÃO DE PLANALTINA DE GOIÁS',
        'CENTRALGERALDEFLAGRANTESEPRONTOATENDIMENTOAOCIDADÃODEPLANALTINADEGOIAS':
            'CENTRAL GERAL DE FLAGRANTES E PRONTO ATENDIMENTO AO CIDADÃO DE PLANALTINA DE GOIÁS',
        // Quando vem truncado sem a cidade no final
        'CENTRALGERALDEFLAGRANTESEPRONTOATENDIMENTOAOCIDADÃODE':
            'CENTRAL GERAL DE FLAGRANTES E PRONTO ATENDIMENTO AO CIDADÃO DE',
        'CENTRALGERALDEFLAGRANTESEPRONTOATENDIMENTOAOCIDADAODE':
            'CENTRAL GERAL DE FLAGRANTES E PRONTO ATENDIMENTO AO CIDADÃO DE',
        // Formosa
        'CENTRALGERALDEFLAGRANTESEPRONTOATENDIMENTOAOCIDADÃODEFORMOSA':
            'CENTRAL GERAL DE FLAGRANTES E PRONTO ATENDIMENTO AO CIDADÃO DE FORMOSA',
        'CENTRALGERALDEFLAGRANTESEPRONTOATENDIMENTOAOCIDADAODEFORMOSA':
            'CENTRAL GERAL DE FLAGRANTES E PRONTO ATENDIMENTO AO CIDADÃO DE FORMOSA',
        // DPLC
        'DIVISÃODEPERÍCIASCRIMINAISEMLOCAISDECRIME':
            'DIVISÃO DE PERÍCIAS CRIMINAIS EM LOCAIS DE CRIME',
        'DIVISAODEPERICIASCRIMINAISEMLOCAISDECRIME':
            'DIVISÃO DE PERÍCIAS CRIMINAIS EM LOCAIS DE CRIME',
      };

      if (fixes.containsKey(colado)) {
        return fixes[colado]!;
      }

      // Fallback conservador: se não há nenhum espaço e o texto é MUITO longo,
      // tentamos separar apenas em alguns conectores frequentes.
      if (!out.contains(' ') && out.length >= 35) {
        out = out
            .replaceAll('DE', ' DE ')
            .replaceAll('AO', ' AO ')
            .replaceAll('DA', ' DA ')
            .replaceAll('DO', ' DO ')
            .replaceAll('E', ' E ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      return out;
    }

    // Extrai o primeiro match de um regex (group 1)
    String? firstGroup(RegExp re) {
      final m = re.firstMatch(raw);
      return m?.group(1)?.trim();
    }

    // Extrai bloco entre dois marcadores (tolerante a variações de maiúsculas e espaços)
    String? between(String startLabel, String endLabel) {
      final pattern = RegExp(
        RegExp.escape(startLabel) +
            r'\s*(.*?)\s*(?=' +
            RegExp.escape(endLabel) +
            r'|$)',
        caseSensitive: false,
        dotAll: true,
      );
      final m = pattern.firstMatch(raw);
      return m?.group(1);
    }

    // === Campos principais ===
    // Alguns PDFs do ODIN trazem os valores "soltos" no topo (ex.: RAI e data/hora),
    // e apenas repetem os rótulos em uma linha ("RAI: Data de criação: ...").

    String? raiNumero = firstGroup(
      RegExp(r'\bRAI\s*:\s*(\d{6,})\b', caseSensitive: false),
    );

    // Fallback: padrão ODIN onde o RAI aparece sozinho em uma linha logo após "Unidade de destino"
    // Ex.: "Unidade de destino: ...\n45359193\n03/01/2026 08:38:22 NOME ..."
    raiNumero ??= (() {
      final m = RegExp(
        r'Unidade\s+de\s+destino\s*:\s*.*?\n\s*(\d{6,})\s*\n\s*(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(raw);
      return m?.group(1)?.trim();
    })();

    // Data/Hora (primeira ocorrência de dd/MM/yyyy HH:mm:ss)
    String? dataHoraComunicacao = firstGroup(
      RegExp(
        r'Data\s+de\s+criacao\s*:\s*(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}(?::\d{2})?)',
        caseSensitive: false,
      ),
    );
    dataHoraComunicacao ??= firstGroup(
      RegExp(r'(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})', caseSensitive: false),
    );

    // Responsável: pode vir como "Responsável: NOME" ou logo após a data/hora
    String? peritoCriminal = firstGroup(
      RegExp(r'Respons[áa]vel\s*:\s*([^\n]+)', caseSensitive: false),
    );
    peritoCriminal ??= (() {
      if (dataHoraComunicacao == null) return null;
      final m = RegExp(
        RegExp.escape(dataHoraComunicacao) +
            r'\s+([A-ZÁÉÍÓÚÇÃÊÔÕ\s]{5,})(?:\n|\r|$)',
        caseSensitive: false,
      ).firstMatch(raw);
      return m?.group(1)?.trim();
    })();

    // Número da ocorrência: pode vir como "Ocorrência no:" ou apenas "106/2026" em linha própria
    String? numeroOcorrencia = firstGroup(
      RegExp(
        r'Ocorr[êe]ncia\s*n[ºo\.]?\s*:\s*([0-9]+/[0-9]{4})',
        caseSensitive: false,
      ),
    );
    numeroOcorrencia ??= (() {
      // tenta pegar a primeira ocorrência do padrão NNN/AAAA após a palavra "Histórico"
      final m = RegExp(
        r'Hist[óo]rico\s*\n\s*(\d{1,6}/\d{4})\b',
        caseSensitive: false,
      ).firstMatch(raw);
      return m?.group(1)?.trim();
    })();

    // Tipificações e Conteúdo/Natureza
    // Após normalização de acentos, "Tipificações" vira "Tipificacoes"
    String? tipificacoes = firstGroup(
      RegExp(r'Tipifica[çc]?[õo]?es\s*:\s*([^\n]+)', caseSensitive: false),
    );
    // Fallback ODIN: tipificação vem na linha imediatamente após o número da ocorrência
    tipificacoes ??= (() {
      if (numeroOcorrencia == null) return null;
      final m = RegExp(
        RegExp.escape(numeroOcorrencia) + r'\s*\n\s*([^\n]+)',
        caseSensitive: false,
      ).firstMatch(raw);
      final tip = m?.group(1)?.trim();
      // Validar que não é um rótulo inválido
      if (tip != null) {
        final tipLower = tip.toLowerCase();
        if (tipLower.contains('historico') ||
            tipLower.contains('cidade:') ||
            tipLower.contains('endereco:') ||
            tipLower.contains('complemento:') ||
            tipLower.contains('coordenadas:') ||
            tipLower.contains('contato:')) {
          return null;
        }
      }
      return tip;
    })();

    // Fallback extra: pegar a primeira linha com padrão "TIPO -> ..." em qualquer lugar do texto.
    tipificacoes ??= (() {
      final m = RegExp(
        r'\b(FURTO|DANO|ROUBO|HOMICIDIO|LATROCINIO|LESAO|AGRESSAO|AMEACA|ESTUPRO|TRAFICO|BM)\s*->[^\n]*',
        caseSensitive: false,
      ).firstMatch(raw);
      return m?.group(0)?.trim();
    })();

    // Fallback para descrição de homicídio/CVLI no texto
    tipificacoes ??= (() {
      // Buscar descrição de homicídio no texto
      final m = RegExp(
        r'Ocorrencia\s+de\s+(Homicidio|CVLI|Latrocinio)[^\n]*',
        caseSensitive: false,
      ).firstMatch(raw);
      if (m != null) {
        return m.group(0)?.trim();
      }
      return null;
    })();

    // Helper para validar se o texto é uma linha de rótulos inválida
    bool isLinhaRotulos(String? texto) {
      if (texto == null || texto.trim().isEmpty) return true;
      final lower = texto.toLowerCase().trim();
      return lower.contains('dados da ocorrencia') ||
          lower.contains('requisicao de pericia') ||
          lower.contains('cidade:') ||
          lower.contains('endereco:') ||
          lower.contains('complemento:') ||
          lower.contains('coordenadas:') ||
          lower.contains('contato:') ||
          lower.contains('historico') ||
          lower.contains('ocorrencia no:') ||
          lower.contains('tipificac') ||
          lower == 'cidade:' ||
          lower.startsWith('cidade: endereco:');
    }

    String? naturezaOcorrencia = firstGroup(
      RegExp(r'Conteudo\s*:\s*([^\n]+)', caseSensitive: false),
    );

    // Validar se não capturou linha de rótulos ou texto inválido
    if (isLinhaRotulos(naturezaOcorrencia)) {
      naturezaOcorrencia = tipificacoes;
    }

    // Se ainda for inválido, buscar diretamente no texto
    if (isLinhaRotulos(naturezaOcorrencia)) {
      // Buscar padrão "TIPO -> ..." diretamente
      final m = RegExp(
        r'\b(FURTO|DANO|ROUBO|HOMICIDIO|LATROCINIO|LESAO|AGRESSAO|AMEACA|ESTUPRO|TRAFICO|BM)\s*->[^\n]*',
        caseSensitive: false,
      ).firstMatch(raw);
      naturezaOcorrencia = m?.group(0)?.trim();
    }

    // Último fallback: usar tipificações mesmo que seja null
    if (isLinhaRotulos(naturezaOcorrencia) || naturezaOcorrencia == null) {
      naturezaOcorrencia = tipificacoes;
    }

    // Município/Cidade
    String? municipio = firstGroup(
      RegExp(r'Cidade\s*:\s*([^\n,]+)', caseSensitive: false),
    );

    // Se capturou a "linha de rótulos" (ex.: "Endereco: Complemento: ..."), descarta.
    final munLower = (municipio ?? '').toLowerCase();
    if (municipio != null &&
        (munLower.contains('endereco') ||
            munLower.contains('complemento') ||
            munLower.contains('coordenadas') ||
            munLower.contains('contato') ||
            munLower.contains('historico'))) {
      municipio = null;
    }
    // Fallback ODIN: cidade vem na linha após a tipificação
    municipio ??= (() {
      if (tipificacoes == null) return null;
      final m = RegExp(
        RegExp.escape(tipificacoes) + r'\s*\n\s*([A-ZÁÉÍÓÚÇÃÊÔÕ\-\s]{3,})\s*\n',
        caseSensitive: false,
      ).firstMatch(raw);
      final cidade = m?.group(1)?.trim();
      // Validar que não é "Historico" ou outro rótulo
      if (cidade != null) {
        final cidadeLower = cidade.toLowerCase();
        if (cidadeLower.contains('historico') ||
            cidadeLower.contains('endereco') ||
            cidadeLower.contains('complemento') ||
            cidadeLower.contains('coordenadas') ||
            cidadeLower.contains('contato')) {
          return null;
        }
      }
      return cidade;
    })();
    // Fallback adicional: buscar cidade após número da ocorrência ou tipificação
    municipio ??= (() {
      if (numeroOcorrencia == null) return null;
      // Buscar padrão: número da ocorrência, depois tipificação (opcional), depois cidade
      // Primeiro tenta após tipificação (se existe)
      if (tipificacoes != null) {
        final m = RegExp(
          RegExp.escape(tipificacoes) +
              r'\s*\n\s*([A-ZÁÉÍÓÚÇÃÊÔÕ\-\s]{3,20})(?:\s*\n|$)',
          caseSensitive: false,
        ).firstMatch(raw);
        final cidade = m?.group(1)?.trim();
        if (cidade != null) {
          final cidadeLower = cidade.toLowerCase();
          // Validar que não é um rótulo ou tipificação
          if (!cidadeLower.contains('historico') &&
              !cidadeLower.contains('endereco') &&
              !cidadeLower.contains('complemento') &&
              !cidadeLower.contains('coordenadas') &&
              !cidadeLower.contains('contato') &&
              !cidadeLower.contains('->') &&
              !cidadeLower.contains('art.') &&
              cidade.length >= 3 &&
              cidade.length <= 30) {
            return cidade;
          }
        }
      }
      // Se não encontrou após tipificação, busca após número da ocorrência
      final m = RegExp(
        RegExp.escape(numeroOcorrencia) +
            r'\s*\n\s*(?:[^\n]*->[^\n]*\s*\n\s*)?([A-ZÁÉÍÓÚÇÃÊÔÕ\-\s]{3,20})(?:\s*\n|$)',
        caseSensitive: false,
      ).firstMatch(raw);
      final cidade = m?.group(1)?.trim();
      // Validar que não é "Historico" ou outro rótulo
      if (cidade != null) {
        final cidadeLower = cidade.toLowerCase();
        if (!cidadeLower.contains('historico') &&
            !cidadeLower.contains('endereco') &&
            !cidadeLower.contains('complemento') &&
            !cidadeLower.contains('coordenadas') &&
            !cidadeLower.contains('contato') &&
            !cidadeLower.contains('->') &&
            !cidadeLower.contains('art.') &&
            cidade.length >= 3 &&
            cidade.length <= 30) {
          return cidade;
        }
      }
      return null;
    })();

    // Endereço
    String? endereco = firstGroup(
      RegExp(r'Endereco\s*:\s*([^\n]+)', caseSensitive: false),
    );
    // Validar se não capturou linha de rótulos
    if (endereco != null) {
      final endLower = endereco.toLowerCase();
      if (endLower.contains('complemento:') ||
          endLower.contains('coordenadas:') ||
          endLower.contains('contato:') ||
          endLower.trim().isEmpty) {
        endereco = null;
      }
    }
    // Fallback ODIN: endereço vem na linha após a cidade e antes de "Latitude:" (quando existir)
    endereco ??= (() {
      if (municipio == null) return null;
      final m = RegExp(
        RegExp.escape(municipio) +
            r'\s*\n\s*([^\n]+?)\s*(?=\n\s*Latitude\s*:|\n\s*Coordenadas\s*:|\n\s*Local\s+de\s+furto|$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(raw);
      final end = m?.group(1)?.trim();
      // Validar que não é um rótulo
      if (end != null) {
        final endLower = end.toLowerCase();
        if (endLower.contains('complemento:') ||
            endLower.contains('coordenadas:') ||
            endLower.contains('contato:') ||
            endLower.contains('historico')) {
          return null;
        }
      }
      return end;
    })();

    // Coordenadas (aceita vírgula ou ponto)
    String? coordenadasS;
    String? coordenadasW;
    final coords = RegExp(
      r'Latitude\s*:\s*([-+]?\d+[\.,]\d+)\s*;\s*Longitude\s*:\s*([-+]?\d+[\.,]\d+)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (coords != null) {
      coordenadasS = coords.group(1)?.replaceAll(',', '.');
      coordenadasW = coords.group(2)?.replaceAll(',', '.');
    }

    // Matrícula (nem sempre existe)
    final String? matriculaPerito = firstGroup(
      RegExp(r'Matr[íi]cula\s*:\s*(\d+)', caseSensitive: false),
    );

    // === Unidades (ORIGEM/AFETA) ===
    String? unidadeOrigem;
    String? unidadeAfeta;

    // Tentar buscar no bloco "Unidades:" primeiro
    final unidadesBlock =
        between('Unidades:', 'Conteudo:') ??
        between('Unidades:', 'Pericia vinculada:');

    if (unidadesBlock != null && unidadesBlock.trim().isNotEmpty) {
      // Captura tudo após (ORIGEM) até (DESTINO) ou (AFETA)
      final mOrigem = RegExp(
        r'\(ORIGEM\)\s*(.*?)(?=\(DESTINO\)|\(AFETA\)|$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(unidadesBlock);
      if (mOrigem != null) {
        unidadeOrigem = descolarTextoColado(mOrigem.group(1) ?? '');
        // Remove eventual código entre colchetes, mas preserva o nome
        unidadeOrigem = unidadeOrigem
            .replaceAll(RegExp(r'\s*\[[^\]]+\]\s*'), ' ')
            .trim();
      }

      // Captura tudo após (AFETA) até fim
      final mAfeta = RegExp(
        r'\(AFETA\)\s*(.*)$',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(unidadesBlock);
      if (mAfeta != null) {
        unidadeAfeta = descolarTextoColado(mAfeta.group(1) ?? '');
        unidadeAfeta = unidadeAfeta
            .replaceAll(RegExp(r'\s*\[[^\]]+\]\s*'), ' ')
            .trim();
      }
    }

    // Fallback: buscar diretamente por (ORIGEM) e (AFETA) no texto inteiro
    if (unidadeOrigem == null || unidadeOrigem.isEmpty) {
      final mOrigem = RegExp(
        r'\(ORIGEM\)\s*(.*?)(?=\(DESTINO\)|\(AFETA\)|$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(raw);
      if (mOrigem != null) {
        unidadeOrigem = descolarTextoColado(mOrigem.group(1) ?? '');
        unidadeOrigem = unidadeOrigem
            .replaceAll(RegExp(r'\s*\[[^\]]+\]\s*'), ' ')
            .trim();
      }
    }

    if (unidadeAfeta == null || unidadeAfeta.isEmpty) {
      final mAfeta = RegExp(
        r'\(AFETA\)\s*(.*?)(?=\(ORIGEM\)|\(DESTINO\)|Conteudo:|Pericia vinculada:|Ocorrencia\s+de|Histórico|$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(raw);
      if (mAfeta != null) {
        var unidadeAfetaTemp = descolarTextoColado(mAfeta.group(1) ?? '');
        unidadeAfetaTemp = unidadeAfetaTemp
            .replaceAll(RegExp(r'\s*\[[^\]]+\]\s*'), ' ')
            .trim();

        // Limpar texto descritivo que pode ter sido capturado
        // Parar antes de "Ocorrencia de" ou outras palavras-chave
        if (unidadeAfetaTemp.isNotEmpty) {
          final stopWords = [
            RegExp(r'(.+?)(?:\s+Ocorrencia\s+de)', caseSensitive: false),
            RegExp(r'(.+?)(?:\s+Histórico)', caseSensitive: false),
            RegExp(r'(.+?)(?:\s+vitima)', caseSensitive: false),
            RegExp(r'(.+?)(?:\s+individuo)', caseSensitive: false),
          ];

          for (final pattern in stopWords) {
            final match = pattern.firstMatch(unidadeAfetaTemp);
            final group1 = match?.group(1);
            if (match != null && group1 != null) {
              final candidato = group1.trim();
              // Validar que o candidato parece um nome de unidade (não muito curto, não contém palavras descritivas)
              if (candidato.length > 10 &&
                  !candidato.toLowerCase().contains('vitima') &&
                  !candidato.toLowerCase().contains('individuo') &&
                  !candidato.toLowerCase().contains('atingido')) {
                unidadeAfetaTemp = candidato;
                break;
              }
            }
          }

          // Se ainda contém palavras descritivas, dividir e pegar apenas a primeira parte
          if (unidadeAfetaTemp.toLowerCase().contains('ocorrencia') ||
              unidadeAfetaTemp.toLowerCase().contains('vitima') ||
              unidadeAfetaTemp.toLowerCase().contains('individuo')) {
            final partes = unidadeAfetaTemp.split(
              RegExp(
                r'\s+Ocorrencia\s+de|\s+Histórico|\s+vitima',
                caseSensitive: false,
              ),
            );
            if (partes.isNotEmpty && partes[0].trim().length > 10) {
              unidadeAfetaTemp = partes[0].trim();
            }
          }
        }

        unidadeAfeta = unidadeAfetaTemp;
      }
    }

    // === Pessoas Envolvidas ===
    final List<PessoaEnvolvidaModel> pessoasEnvolvidas = [];

    // O bloco pode estar na mesma página ou em página separada.
    // Pegamos do título "Pessoas Envolvidas" até o próximo ruído/fim.
    String? pessoasRaw =
        between('Pessoas Envolvidas', 'Powered by TCPDF') ??
        between('Pessoas Envolvidas', 'Consulta realizada em:') ??
        between('Pessoas Envolvidas', 'Pág.') ??
        between('Pessoas Envolvidas', 'Dados da Ocorrência');

    if (pessoasRaw != null) {
      final linhasPessoas = pessoasRaw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      for (final linha in linhasPessoas) {
        final linhaLimpa = linha.replaceAll(RegExp(r'^[•\-\*]\s*'), '').trim();

        // Ex.: "ROSIMAR ... (VÍTIMA COMUNICANTE)"
        final m = RegExp(
          r'^(.+?)\s*\(([^)]+)\)\s*$',
          caseSensitive: false,
        ).firstMatch(linhaLimpa);

        if (m == null) continue;

        final nome = normSpaces(m.group(1) ?? '');
        final tipoTexto = (m.group(2) ?? '').toUpperCase().trim();

        if (nome.isEmpty) continue;
        if (nome.toLowerCase().contains('powered by tcpdf')) continue;

        TipoPessoa tipo;
        if (tipoTexto.contains('VÍTIMA') && tipoTexto.contains('COMUNICANTE')) {
          tipo = TipoPessoa.vitimaComunicante;
        } else if (tipoTexto.contains('VÍTIMA')) {
          tipo = TipoPessoa.vitima;
        } else if (tipoTexto.contains('COMUNICANTE')) {
          tipo = TipoPessoa.comunicante;
        } else if (tipoTexto.contains('AUTOR')) {
          tipo = TipoPessoa.autor;
        } else {
          tipo = TipoPessoa.outro;
        }

        pessoasEnvolvidas.add(PessoaEnvolvidaModel(nome: nome, tipo: tipo));
      }
    }

    // Se não achou a seção "Pessoas Envolvidas", pelo menos tenta capturar a VÍTIMA COMUNICANTE no texto inteiro.
    if (pessoasEnvolvidas.isEmpty) {
      final m = RegExp(
        r'^(.+?)\s*\(V[ÍI]TIMA\s+COMUNICANTE\)\s*$',
        caseSensitive: false,
        multiLine: true,
      ).firstMatch(raw);
      if (m != null) {
        final nome = normSpaces(m.group(1) ?? '');
        if (nome.isNotEmpty) {
          pessoasEnvolvidas.add(
            PessoaEnvolvidaModel(
              nome: nome,
              tipo: TipoPessoa.vitimaComunicante,
            ),
          );
        }
      }
    }

    return SolicitacaoModel(
      raiNumero: raiNumero,
      numeroOcorrencia: numeroOcorrencia,
      naturezaOcorrencia: naturezaOcorrencia,
      dataHoraComunicacao: dataHoraComunicacao,
      peritoCriminal: peritoCriminal,
      matriculaPerito: matriculaPerito,
      unidadeOrigem: unidadeOrigem,
      unidadeAfeta: unidadeAfeta,
      pessoasEnvolvidas: pessoasEnvolvidas.isNotEmpty
          ? pessoasEnvolvidas
          : null,
      endereco: endereco,
      municipio: municipio,
      coordenadasS: coordenadasS,
      coordenadasW: coordenadasW,
    );
  }
}
