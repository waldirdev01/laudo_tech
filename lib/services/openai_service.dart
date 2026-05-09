import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/tipo_ocorrencia.dart';
import 'ai_settings_service.dart';

class AiSuggestionRequest {
  final String fieldLabel;
  final String currentText;
  final String contextText;
  final List<String> imagePaths;
  final AiSuggestionStyle style;
  final AiSuggestionProfile profile;
  final String? providerOverride;
  final String additionalInstructions;
  final String responseDirective;

  const AiSuggestionRequest({
    required this.fieldLabel,
    required this.currentText,
    this.contextText = '',
    this.imagePaths = const [],
    this.style = AiSuggestionStyle.technical,
    this.profile = AiSuggestionProfile.general,
    this.providerOverride,
    this.additionalInstructions = '',
    this.responseDirective = '',
  });
}

enum AiSuggestionStyle {
  technical(
    'Técnica',
    'Gere uma descrição técnica completa, mas sem excesso de detalhes irrelevantes.',
  ),
  concise(
    'Sucinta',
    'Gere uma descrição curta, em um único parágrafo, preservando apenas os elementos essenciais.',
  ),
  objective(
    'Objetiva',
    'Gere uma descrição direta, factual e sem floreios, evitando adjetivos desnecessários.',
  ),
  reviseCurrent(
    'Revisar texto atual',
    'Revise e melhore o texto atual, mantendo o mesmo conteúdo e sem acrescentar fatos novos.',
  );

  final String label;
  final String promptInstruction;

  const AiSuggestionStyle(this.label, this.promptInstruction);
}

enum AiSuggestionProfile {
  general(
    'Geral',
    'Adapte a redação ao campo solicitado, mantendo linguagem pericial técnica e neutra.',
  ),
  cvli(
    'CVLI',
    'Considere que o campo pertence a um laudo de morte violenta. Priorize descrição do cadáver, posição, vestes, lesões, vestígios e ambiente. Use terminologia médico-legal e não conclua causa, instrumento ou dinâmica sem base explícita.',
  ),
  morteEsclarecer(
    'Morte a esclarecer',
    'Considere que o campo pertence a um laudo de morte a esclarecer. Seja ainda mais conservador com inferências e limite-se aos achados objetivos do corpo, vestes, ambiente e vestígios visíveis.',
  ),
  crimeTransito(
    'Crime de trânsito',
    'Considere que o campo pertence a um laudo de acidente/crime de trânsito. Priorize via, sinalização, veículos, vestígios, posições e dinâmica observável. Não atribua culpa, velocidade ou causa determinante sem base explícita.',
  ),
  furtoDanoExameLocal(
    'Furto, dano e exame de local',
    'Considere que o campo pertence a um exame de local de furto ou dano. Priorize acessos, sinais de arrombamento, disposição de objetos, danos materiais, vestígios e características do ambiente. Não atribua autoria ou modo de ação além do observado.',
  ),
  bloodstainAnalysis(
    'Análise de manchas de sangue',
    'Considere que a tarefa é uma análise assistiva de manchas de sangue em contexto de morte violenta. Limite-se a descrever padrões visualmente compatíveis, dados ausentes, cautelas e necessidade de validação humana. Não reconstrua a dinâmica completa do evento e não conclua mecanismo, cronologia, autoria ou posição relativa sem suporte suficiente.',
  );

  final String label;
  final String specialtyInstruction;

  const AiSuggestionProfile(this.label, this.specialtyInstruction);

  static AiSuggestionProfile fromTipoOcorrencia(TipoOcorrencia tipo) {
    return switch (tipo) {
      TipoOcorrencia.cvli => AiSuggestionProfile.cvli,
      TipoOcorrencia.morteEsclarecer => AiSuggestionProfile.morteEsclarecer,
      TipoOcorrencia.crimeTransito => AiSuggestionProfile.crimeTransito,
      TipoOcorrencia.furtoDanoExameLocal =>
        AiSuggestionProfile.furtoDanoExameLocal,
    };
  }
}

class AiSuggestionService {
  AiSuggestionService({AiSettingsService? settingsService, http.Client? httpClient})
    : _settingsService = settingsService ?? AiSettingsService(),
      _httpClient = httpClient ?? http.Client();

  final AiSettingsService _settingsService;
  final http.Client _httpClient;

  Future<String> generateSuggestion(AiSuggestionRequest request) async {
    final settings = request.providerOverride == null
        ? await _settingsService.load()
        : await _settingsService.loadForProvider(request.providerOverride!);
    if (!settings.enabled) {
      throw const AiServiceException('A IA está desativada nas configurações.');
    }

    final apiKey = await _settingsService.getApiKey(settings.provider);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw AiServiceException(
        'Configure a chave da ${AiSettingsService.providerLabel(settings.provider)} antes de usar a IA.',
      );
    }

    final imageContents = await _imageContents(request.imagePaths);
    final hasTextContext =
        request.currentText.trim().isNotEmpty || request.contextText.trim().isNotEmpty;
    if (!hasTextContext && imageContents.isEmpty) {
      throw const AiServiceException(
        'Informe um texto, selecione dados do formulário ou adicione uma foto antes de gerar a sugestão.',
      );
    }

    if (imageContents.isNotEmpty &&
        !AiSettingsService.providerSupportsImages(settings.provider)) {
      throw AiServiceException(
        '${AiSettingsService.providerLabel(settings.provider)} não está habilitado para análise com imagem nesta integração. Configure o OpenAI / ChatGPT para usar esta funcionalidade.',
      );
    }

    return switch (settings.provider) {
      AiSettingsService.deepSeekProvider => _generateWithDeepSeek(
        settings: settings,
        apiKey: apiKey,
        request: request,
        hasTextContext: hasTextContext,
      ),
      _ => _generateWithOpenAi(
        settings: settings,
        apiKey: apiKey,
        request: request,
        imageContents: imageContents,
      ),
    };
  }

  Future<void> testConnection() async {
    await generateSuggestion(
      const AiSuggestionRequest(
        fieldLabel: 'Teste de conexão',
        currentText: '',
        contextText:
            'Responda apenas com: Configuração de IA validada com sucesso.',
        style: AiSuggestionStyle.objective,
      ),
    );
  }

  String _buildPrompt(AiSuggestionRequest request, {required bool hasImages}) {
    final buffer = StringBuffer()
      ..writeln('Campo do laudo: ${request.fieldLabel}.')
      ..writeln()
      ..writeln('Perfil técnico: ${request.profile.label}.')
      ..writeln(request.profile.specialtyInstruction)
      ..writeln()
      ..writeln('Estilo desejado: ${request.style.label}.')
      ..writeln(request.style.promptInstruction)
      ..writeln()
      ..writeln('Tarefa:')
      ..writeln(
        'Gere uma sugestão de texto técnico, objetiva e revisável, em português do Brasil.',
      )
      ..writeln(
        'Não afirme conclusão pericial, causa, calibre, distância de disparo ou diagnóstico além do que estiver nos dados/imagens.',
      )
      ..writeln(
        'Use linguagem descritiva e indique incerteza quando a informação não estiver clara.',
      );

    if (request.responseDirective.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Formato esperado da resposta:')
        ..writeln(request.responseDirective.trim());
    }

    if (request.contextText.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Dados de contexto:')
        ..writeln(request.contextText.trim());
    }

    if (request.currentText.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Texto atual do campo:')
        ..writeln(request.currentText.trim());
    }

    if (hasImages) {
      buffer
        ..writeln()
        ..writeln(
          'Há imagem(ns) anexada(s). Descreva somente aspectos visualmente observáveis.',
        );
    }

    return buffer.toString();
  }

  Future<String> _generateWithOpenAi({
    required AiSettings settings,
    required String apiKey,
    required AiSuggestionRequest request,
    required List<Map<String, String>> imageContents,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('https://api.openai.com/v1/responses'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${apiKey.trim()}',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'model': settings.model,
        'instructions': _buildInstructionsForRequest(request),
        'input': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_text',
                'text': _buildPrompt(
                  request,
                  hasImages: imageContents.isNotEmpty,
                ),
              },
              ...imageContents,
            ],
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(_formatError(response, provider: settings.provider));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final output = _extractOpenAiOutputText(decoded).trim();
    if (output.isEmpty) {
      throw const AiServiceException('A IA não retornou texto útil.');
    }
    return output;
  }

  Future<String> _generateWithDeepSeek({
    required AiSettings settings,
    required String apiKey,
    required AiSuggestionRequest request,
    required bool hasTextContext,
  }) async {
    if (!hasTextContext) {
      throw const AiServiceException(
        'A integração atual com DeepSeek usa apenas texto. Informe texto ou dados do formulário antes de gerar a sugestão.',
      );
    }

    final response = await _httpClient.post(
      Uri.parse('https://api.deepseek.com/chat/completions'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${apiKey.trim()}',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'model': settings.model,
        'messages': [
          {'role': 'system', 'content': _buildInstructionsForRequest(request)},
          {
            'role': 'user',
            'content': _buildPrompt(request, hasImages: false),
          },
        ],
        'thinking': {'type': 'disabled'},
        'stream': false,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(_formatError(response, provider: settings.provider));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final output = _extractDeepSeekOutputText(decoded).trim();
    if (output.isEmpty) {
      throw const AiServiceException('A IA não retornou texto útil.');
    }
    return output;
  }

  Future<List<Map<String, String>>> _imageContents(List<String> paths) async {
    final contents = <Map<String, String>>[];
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      contents.add({
        'type': 'input_image',
        'image_url': 'data:${_mimeType(path)};base64,${base64Encode(bytes)}',
        'detail': 'auto',
      });
    }
    return contents;
  }

  String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _extractOpenAiOutputText(Map<String, dynamic> decoded) {
    final direct = decoded['output_text'];
    if (direct is String && direct.trim().isNotEmpty) return direct;

    final output = decoded['output'];
    if (output is! List) return '';
    final parts = <String>[];
    for (final item in output) {
      if (item is! Map<String, dynamic>) continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final contentItem in content) {
        if (contentItem is! Map<String, dynamic>) continue;
        final text = contentItem['text'];
        if (text is String && text.trim().isNotEmpty) {
          parts.add(text.trim());
        }
      }
    }
    return parts.join('\n\n');
  }

  String _extractDeepSeekOutputText(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) return '';
    final message = firstChoice['message'];
    if (message is! Map<String, dynamic>) return '';
    final content = message['content'];
    if (content is String) return content;
    return '';
  }

  String _formatError(http.Response response, {required String provider}) {
    final providerLabel = AiSettingsService.providerLabel(provider);
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return 'Falha na $providerLabel: $message';
        }
      }
    } catch (_) {
      // Mantem a mensagem genérica abaixo.
    }
    return 'Falha na $providerLabel (${response.statusCode}). Verifique a conexão, a chave e o modelo.';
  }

  String _buildInstructions(AiSuggestionProfile profile) {
    final extra = profile == AiSuggestionProfile.general
        ? ''
        : '\n${profile.specialtyInstruction}';
    return '''
$_baseInstructions
Perfil técnico ativo: ${profile.label}.
$extra
''';
  }

  String _buildInstructionsForRequest(AiSuggestionRequest request) {
    final buffer = StringBuffer(_buildInstructions(request.profile));
    if (request.additionalInstructions.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(request.additionalInstructions.trim());
    }
    return buffer.toString().trim();
  }

  static const _baseInstructions = '''
Você é um assistente de redação pericial para laudos criminais.
Seu papel é sugerir texto descritivo, claro e revisável.
Não substitua a análise do perito.
Não invente fatos ausentes.
Não conclua causa jurídica, médica ou balística.
Não inclua aviso, saudação, lista de ressalvas nem explicação sobre a tarefa.
Responda somente com o texto sugerido para o campo.
''';
}

class AiServiceException implements Exception {
  final String message;

  const AiServiceException(this.message);

  @override
  String toString() => message;
}

typedef OpenAiService = AiSuggestionService;
