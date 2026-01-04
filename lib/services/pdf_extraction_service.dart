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

    // Extrair RAI (vários formatos possíveis)
    String? raiNumero;
    final raiMatch1 = RegExp(
      r'RAI\s*n[.:°º]?\s*:?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);
    final raiMatch2 = RegExp(
      r'RAI[:\s]+(\d+)',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);
    raiNumero = raiMatch1?.group(1) ?? raiMatch2?.group(1);

    // Extrair Data de Criação
    String? dataHoraComunicacao;
    final dataCriacaoMatch = RegExp(
      r'Data\s+de\s+cria[çc][ãa]o\s*:?\s*(\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}:\d{2})',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);
    dataHoraComunicacao = dataCriacaoMatch?.group(1)?.trim();

    if (dataHoraComunicacao == null) {
      final dataHoraComunicacaoMatch = RegExp(
        r'Data/Hora\s+da\s+Comunica[çc][ãa]o\s*:?\s*(\d{1,2}\s*/\s*\d{1,2}\s*/\s*\d{4}\s+\d{1,2}:\d{2})',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      dataHoraComunicacao = dataHoraComunicacaoMatch?.group(1)?.trim();
    }

    // Extrair Responsável
    String? peritoCriminal;
    final responsavelMatch = RegExp(
      r'Respons[áa]vel\s*:?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);
    peritoCriminal = responsavelMatch?.group(1)?.trim();

    if (peritoCriminal == null) {
      final peritoMatch = RegExp(
        r'Perito\s+Criminal\s*:?\s*([^\n]+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      peritoCriminal = peritoMatch?.group(1)?.trim();
    }

    // Extrair Natureza da Ocorrência / Conteúdo
    String? naturezaOcorrencia;
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
    String? numeroOcorrencia;
    final ocorrenciaMatch = RegExp(
      r'Ocorr[êe]ncia\s+n[º°]?\s*:?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);
    numeroOcorrencia = ocorrenciaMatch?.group(1)?.trim();

    // Extrair Tipificações
    final tipificacoesMatch = RegExp(
      r'Tipifica[çc][õo]es\s*:?\s*([^\n]+(?:\n[^\n]+)*)',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);
    final tipificacoes = tipificacoesMatch?.group(1)?.trim();

    // Extrair Cidade
    String? municipio;
    final cidadeMatch = RegExp(
      r'Cidade\s*:?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(textoNormalizado);
    municipio = cidadeMatch?.group(1)?.trim();

    if (municipio == null) {
      final municipioMatch = RegExp(
        r'Munic[íi]pio\s*:?\s*([^\n]+)',
        caseSensitive: false,
      ).firstMatch(textoNormalizado);
      municipio = municipioMatch?.group(1)?.trim();
    }

    // Extrair Endereço (pode ter múltiplas linhas)
    String? endereco;
    final enderecoMatch = RegExp(
      r'Endere[çc]o\s*:?\s*([^\n]+(?:\n[^\n]+)*?)(?=\n(?:Complemento|Coordenadas|Cidade|Munic[íi]pio|$))',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(textoNormalizado);
    endereco = enderecoMatch?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ');

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

    // Extrair Unidades
    String? unidadeOrigem;
    String? unidadeAfeta;

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
