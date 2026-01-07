import 'dart:io';

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
        }
      }

      // Método Flutter usando Syncfusion
      final File arquivo = File(caminhoArquivo);
      if (!await arquivo.exists()) {
        throw Exception('Arquivo PDF não encontrado: $caminhoArquivo');
      }

      final bytes = await arquivo.readAsBytes();
      final PdfDocument documento = PdfDocument(inputBytes: bytes);

      final StringBuffer textoCompleto = StringBuffer();

      for (int i = 0; i < documento.pages.count; i++) {
        final String textoPagina = PdfTextExtractor(
          documento,
        ).extractText(startPageIndex: i, endPageIndex: i);
        textoCompleto.writeln(textoPagina);
      }

      documento.dispose();
      return textoCompleto.toString();
    } catch (e) {
      throw Exception('Erro ao extrair texto do PDF: $e');
    }
  }

  /// Extrai dados estruturados de uma solicitação de perícia
  Future<SolicitacaoModel> extrairDadosSolicitacao(
    String caminhoArquivo,
  ) async {
    final texto = await extrairTexto(caminhoArquivo);

    // Debug: mostrar texto extraído (primeiros 2000 caracteres)
    print('=== TEXTO EXTRAÍDO DO PDF (primeiros 2000 chars) ===');
    print(texto.length > 2000 ? texto.substring(0, 2000) : texto);
    print('=== FIM DO TEXTO EXTRAÍDO ===');

    // Parsear campos específicos do PDF de solicitação
    return _parsearSolicitacao(texto);
  }

  /// Parseia o texto extraído do PDF para criar SolicitacaoModel
  SolicitacaoModel _parsearSolicitacao(String texto) {
    // Manter quebras de linha para melhor parsing
    final linhas = texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final textoNormalizado = linhas.join('\n');

    // === FORMATO ESPECIAL: Labels numa linha, valores nas linhas seguintes ===
    // Detectar se é o formato especial (REQUISIÇÃO DE PERÍCIA com labels agrupadas)
    final bool formatoLabelsAgrupadas =
        RegExp(
          r'RAI:\s*Data\s+de\s+cria',
          caseSensitive: false,
        ).hasMatch(textoNormalizado) ||
        textoNormalizado.contains('REQUISIÇÃO DE PERÍCIA');

    print('formatoLabelsAgrupadas: $formatoLabelsAgrupadas');
    print(
      'Contém REQUISIÇÃO DE PERÍCIA: ${textoNormalizado.contains("REQUISIÇÃO DE PERÍCIA")}',
    );

    String? raiNumero;
    String? dataHoraComunicacao;
    String? peritoCriminal;
    String? naturezaOcorrencia;
    String? numeroOcorrencia;
    String? municipio;
    String? endereco;
    String? unidadeOrigem;
    String? unidadeAfeta;

    if (formatoLabelsAgrupadas) {
      print('Entrando no parsing de formato especial');

      // Formato especial do PDF de requisição
      // RAI: número após "Unidade de destino:" e antes da data
      final raiMatch = RegExp(
        r'Unidade de destino:[^\n]+\n(\d+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      raiNumero = raiMatch?.group(1);
      print('RAI match: ${raiMatch?.group(0)} -> $raiNumero');

      // Data/Hora: após o RAI na mesma região
      final dataMatch = RegExp(
        r'\n(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})\s+[A-Z]',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      dataHoraComunicacao = dataMatch?.group(1);
      print('Data match: ${dataMatch?.group(0)} -> $dataHoraComunicacao');

      // Responsável: nome após a data
      final responsavelMatch = RegExp(
        r'\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}\s+([A-ZÁÉÍÓÚÇÃÊÔÕ\s]+)\n',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      peritoCriminal = responsavelMatch?.group(1)?.trim();
      print('Responsável match: $peritoCriminal');

      // Número da Ocorrência: capturar no bloco ou próximo de "Ocorrência"
      final ocorrenciaMatch = RegExp(
        r'Ocorr[eê]ncia\s*(?:n[ºo.]*)?\s*[:\-]?\s*([0-9]+/[0-9]{4})',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      numeroOcorrencia = ocorrenciaMatch?.group(1);

      if (numeroOcorrencia == null) {
        final ocorrenciaMatch2 = RegExp(
          r'\n([0-9]+/[0-9]{4})\n',
          caseSensitive: false,
        ).firstMatch(textoNormalizado);
        numeroOcorrencia = ocorrenciaMatch2?.group(1);
      }
      print('Ocorrência match: $numeroOcorrencia');

      // Natureza/Tipificação: linha após o número da ocorrência
      final naturezaMatch = RegExp(
        r'\d+/\d{4}\n([^\n]+(?:FURTO|ROUBO|DANO|HOMICÍDIO|LATROCÍNIO|ACIDENTE|LESÃO)[^\n]*)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      naturezaOcorrencia = naturezaMatch?.group(1)?.trim();
      print('Natureza match 1: $naturezaOcorrencia');

      if (naturezaOcorrencia == null) {
        // Tentar capturar a linha após o número
        final naturezaMatch2 = RegExp(
          r'\d+/\d{4}\n([A-ZÁÉÍÓÚÇÃÊÔÕ][^\n]+)',
          caseSensitive: false,
        ).firstMatch(textoNormalizado);
        naturezaOcorrencia = naturezaMatch2?.group(1)?.trim();
        print('Natureza match 2: $naturezaOcorrencia');
      }

      // Município: linha após a tipificação (cidade em maiúsculas)
      // Procurar por nome de cidade (palavra em maiúsculas sozinha ou antes de endereço)
      final municipioMatch = RegExp(
        r'(?:FURTO|ROUBO|DANO|HOMICÍDIO|CPB)[^\n]*\n([A-ZÁÉÍÓÚÇÃÊÔÕ]+)\n',
        caseSensitive: true,
      ).firstMatch(textoNormalizado);
      municipio = municipioMatch?.group(1)?.trim();
      print('Município match: $municipio');

      // Endereço: linha após o município (antes de Latitude)
      if (municipio != null) {
        final enderecoMatch = RegExp(
          municipio +
              r'\n([^\n]+(?:,\s*[^\n]+)*?)(?=\nLatitude|\nLocal|\nHist[óo]rico)',
          caseSensitive: false,
        ).firstMatch(textoNormalizado);
        endereco = enderecoMatch?.group(1)?.trim();
        print('Endereço match 1: $endereco');
      }

      // Se não encontrou endereço, tentar outro padrão
      if (endereco == null) {
        final enderecoMatch2 = RegExp(
          r'(?:QUADRA|RUA|AV\.|AVENIDA|RODOVIA|BR-|GO-)[^\n]+',
          caseSensitive: false,
        ).firstMatch(textoNormalizado);
        endereco = enderecoMatch2?.group(0)?.trim();
        print('Endereço match 2: $endereco');
      }

      // Extrair Unidades no formato especial
      // (ORIGEM) CENTRAL GERAL... [CGFPACPLANALTINA/11aDRP]
      // (DESTINO) DIVISÃO... [03 CRPTC/DPLC]
      // (AFETA) CENTRAL GERAL... [CGFPACPLANALTINA/11aDRP]
      final origemMatch = RegExp(
        r'\(ORIGEM\)\s+([^\n\[]+)(?:\[[^\]]+\])?',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      if (origemMatch != null) {
        unidadeOrigem = origemMatch.group(1)?.trim();
        print('Unidade Origem match: $unidadeOrigem');
      }

      final afetaMatch = RegExp(
        r'\(AFETA\)\s+([^\n\[]+)(?:\[[^\]]+\])?',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      if (afetaMatch != null) {
        unidadeAfeta = afetaMatch.group(1)?.trim();
        print('Unidade Afeta match: $unidadeAfeta');
      }
    } else {
      // Formato tradicional com "Campo: Valor"
      // Extrair RAI (vários formatos possíveis)
      final raiMatch1 = RegExp(
        r'RAI\s*n[.:°º]?\s*:?\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      final raiMatch2 = RegExp(
        r'RAI[:\s]+(\d+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      raiNumero = raiMatch1?.group(1) ?? raiMatch2?.group(1);

      // Extrair Data de Criação / Data/Hora Comunicação
      final dataCriacaoMatch = RegExp(
        r'Data\s+de\s+cria[çc][ãa]o\s*:?\s*(\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}(?::\d{2})?)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      dataHoraComunicacao = dataCriacaoMatch?.group(1)?.trim();

      if (dataHoraComunicacao == null) {
        final dataHoraComunicacaoMatch = RegExp(
          r'Data/Hora\s+(?:da\s+)?Comunica[çc][ãa]o\s*:?\s*(\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}(?::\d{2})?)',
          caseSensitive: false,
        ).firstMatch(textoNormalizado);
        dataHoraComunicacao = dataHoraComunicacaoMatch?.group(1)?.trim();
      }

      // Extrair Responsável
      final responsavelMatch = RegExp(
        r'Respons[áa]vel\s*:?\s*([^\n]+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      peritoCriminal = responsavelMatch?.group(1)?.trim();

      // Extrair Natureza da Ocorrência
      final naturezaMatch = RegExp(
        r'Natureza\s+da\s+Ocorr[êe]ncia\s*:?\s*([^\n]+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      naturezaOcorrencia = naturezaMatch?.group(1)?.trim();

      if (naturezaOcorrencia == null) {
        final conteudoMatch = RegExp(
          r'Conte[úu]do\s*:?\s*([^\n]+)',
          caseSensitive: false,
        ).firstMatch(textoNormalizado);
        naturezaOcorrencia = conteudoMatch?.group(1)?.trim();
      }

      // Extrair Número da Ocorrência
      final ocorrenciaMatch = RegExp(
        r'Ocorr[êe]ncia\s+n[º°]?\s*:?\s*([^\n]+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      numeroOcorrencia = ocorrenciaMatch?.group(1)?.trim();

      // Extrair Cidade
      final cidadeMatch = RegExp(
        r'Cidade\s*:?\s*([^\n:]+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      municipio = cidadeMatch?.group(1)?.trim();

      if (municipio == null) {
        final municipioMatch = RegExp(
          r'Munic[íi]pio\s*:?\s*([^\n:]+)',
          caseSensitive: false,
        ).firstMatch(textoNormalizado);
        municipio = municipioMatch?.group(1)?.trim();
      }

      // Extrair Endereço
      final enderecoMatch = RegExp(
        r'Endere[çc]o\s*:?\s*([^\n]+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      endereco = enderecoMatch?.group(1)?.trim();
    }

    // Extrair Tipificações (usado como fallback para natureza)
    final tipificacoesMatch = RegExp(
      r'Tipifica[çc][õo]es\s*:?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);
    final tipificacoes = tipificacoesMatch?.group(1)?.trim();

    // Extrair Coordenadas (formato decimal: Latitude: -16,6723584; Longitude: -49,2797952)
    String? coordenadasS;
    String? coordenadasW;

    final coordenadasDecimalMatch = RegExp(
      r'Latitude\s*:?\s*([-]?\d+[.,]\d+)\s*;?\s*Longitude\s*:?\s*([-]?\d+[.,]\d+)',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);

    if (coordenadasDecimalMatch != null) {
      coordenadasS = coordenadasDecimalMatch.group(1)?.replaceAll(',', '.');
      coordenadasW = coordenadasDecimalMatch.group(2)?.replaceAll(',', '.');
    } else {
      // Tentar formato graus/minutos/segundos
      final coordenadasSMatch = RegExp(
        'S:\\s*(\\d+\\s*[°]\\s*\\d+\\s*[\']\\s*\\d+\\s*["])',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      coordenadasS = coordenadasSMatch?.group(1);

      final coordenadasWMatch = RegExp(
        'W:\\s*(\\d+\\s*[°]\\s*\\d+\\s*[\']\\s*\\d+\\s*["])',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      coordenadasW = coordenadasWMatch?.group(1);
    }

    // Extrair Matrícula do Perito (procurar próximo ao nome do perito)
    String? matriculaPerito;
    final matriculaMatch = RegExp(
      r'Matr[íi]cula\s*:?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);
    matriculaPerito = matriculaMatch?.group(1);

    // Extrair Unidades (formato tradicional)
    // Procurar por (ORIGEM) e (AFETA) diretamente no texto
    // Buscar tudo entre "Unidades:" e o próximo campo (ou fim)
    final unidadesSectionMatch = RegExp(
      r'Unidades\s*:?\s*(.*?)(?=\n(?:Conte[úu]do|Dados\s+da\s+Ocorr[êe]ncia|LOCAL|$))',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(texto);

    if (unidadesSectionMatch != null) {
      final unidadesTexto = unidadesSectionMatch.group(1) ?? '';

      // Extrair unidade origem (ORIGEM) - capturar até encontrar (DESTINO) ou (AFETA)
      final origemMatch = RegExp(
        r'\(ORIGEM\)\s*:?\s*(.*?)(?=\(DESTINO\)|\(AFETA\)|$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(unidadesTexto);
      if (origemMatch != null) {
        unidadeOrigem = origemMatch
            .group(1)
            ?.trim()
            .replaceAll(RegExp(r'\s+'), ' ');
      }

      // Extrair unidade afeta (AFETA) - capturar tudo após (AFETA)
      final afetaMatch = RegExp(
        r'\(AFETA\)\s*:?\s*(.*?)(?=\n\n|$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(unidadesTexto);
      if (afetaMatch != null) {
        unidadeAfeta = afetaMatch
            .group(1)
            ?.trim()
            .replaceAll(RegExp(r'\s+'), ' ');
      }
    }

    // Extrair Pessoas Envolvidas
    final List<PessoaEnvolvidaModel> pessoasEnvolvidas = [];

    // Buscar seção "Pessoas Envolvidas" - pode estar em diferentes formatos
    final pessoasSectionMatch = RegExp(
      r'Pessoas\s+Envolvidas\s*\n.*?\n(.*?)(?=\n\n|\n[A-Z][A-Z][A-Z]|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(texto);

    if (pessoasSectionMatch != null) {
      final pessoasTexto = pessoasSectionMatch.group(1) ?? '';

      // Dividir por linhas e processar cada uma
      final linhas = pessoasTexto
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      for (final linha in linhas) {
        // Procurar por padrões: NOME (TIPO) ou NOME - TIPO
        // Pode ter bullet points, espaços, etc.
        final linhaLimpa = linha.trim();

        // Padrão 1: NOME (TIPO)
        var pessoaMatch = RegExp(
          r'([A-ZÁÉÍÓÚÇÃÊÔÕ\s]+?)\s*\(([^)]+)\)',
          caseSensitive: false,
        ).firstMatch(linhaLimpa);

        // Padrão 2: NOME - TIPO ou NOME: TIPO
        pessoaMatch ??= RegExp(
          r'([A-ZÁÉÍÓÚÇÃÊÔÕ\s]+?)\s*[-:]\s*([A-ZÁÉÍÓÚÇÃÊÔÕ\s]+)',
          caseSensitive: false,
        ).firstMatch(linhaLimpa);

        if (pessoaMatch != null) {
          final nome = pessoaMatch.group(1)?.trim() ?? '';
          final tipoTexto = (pessoaMatch.group(2)?.toUpperCase() ?? '').trim();

          // Determinar tipo baseado nas palavras-chave
          TipoPessoa tipo;
          if (tipoTexto.contains('AUTOR')) {
            tipo = TipoPessoa.autor;
          } else if (tipoTexto.contains('VÍTIMA') &&
              tipoTexto.contains('COMUNICANTE')) {
            tipo = TipoPessoa.vitimaComunicante;
          } else if (tipoTexto.contains('VÍTIMA')) {
            tipo = TipoPessoa.vitima;
          } else if (tipoTexto.contains('COMUNICANTE')) {
            tipo = TipoPessoa.comunicante;
          } else {
            tipo = TipoPessoa.outro;
          }

          // Remover caracteres especiais do nome (bullet points, etc)
          final nomeLimpo = nome.replaceAll(RegExp(r'^[•\-\*]\s*'), '').trim();

          // Filtrar ruídos de rodapé
          final lower = nomeLimpo.toLowerCase();
          if (lower.contains('powered by tcpdf')) {
            continue;
          }

          if (nomeLimpo.isNotEmpty && nomeLimpo.length > 2) {
            pessoasEnvolvidas.add(
              PessoaEnvolvidaModel(nome: nomeLimpo, tipo: tipo),
            );
          }
        }
      }
    }

    return SolicitacaoModel(
      raiNumero: raiNumero,
      numeroOcorrencia: numeroOcorrencia,
      naturezaOcorrencia: naturezaOcorrencia ?? tipificacoes,
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
