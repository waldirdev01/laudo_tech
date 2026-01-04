import 'package:flutter/material.dart';
import '../models/ficha_completa_model.dart';
import '../models/local_furto_model.dart';
import '../services/ficha_service.dart';
import 'evidencias_furto_screen.dart';

class LocalFurtoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const LocalFurtoScreen({
    super.key,
    required this.ficha,
  });

  @override
  State<LocalFurtoScreen> createState() => _LocalFurtoScreenState();
}

class _LocalFurtoScreenState extends State<LocalFurtoScreen> {
  final _fichaService = FichaService();
  final _viasAcessoController = TextEditingController();
  final _sinaisArrombamentoController = TextEditingController();
  final _descricaoLocalController = TextEditingController();
  final _demaisObservacoesController = TextEditingController();
  bool _salvando = false;

  // Estados dos checkboxes
  bool? _classificacaoMediato;
  bool? _classificacaoImediato;
  bool? _classificacaoRelacionado;
  
  bool? _pisoSeco;
  bool? _pisoUmido;
  bool? _pisoMolhado;
  
  bool? _iluminacaoArtificial;
  bool? _iluminacaoNatural;
  bool? _iluminacaoAusente;
  
  bool? _sinaisArrombamentoSim;
  bool? _sinaisArrombamentoNao;
  bool? _sinaisArrombamentoNaoSeAplica;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.localFurto;
    if (dados != null) {
      _classificacaoMediato = dados.classificacaoMediato;
      _classificacaoImediato = dados.classificacaoImediato;
      _classificacaoRelacionado = dados.classificacaoRelacionado;
      _pisoSeco = dados.pisoSeco;
      _pisoUmido = dados.pisoUmido;
      _pisoMolhado = dados.pisoMolhado;
      _iluminacaoArtificial = dados.iluminacaoArtificial;
      _iluminacaoNatural = dados.iluminacaoNatural;
      _iluminacaoAusente = dados.iluminacaoAusente;
      _sinaisArrombamentoSim = dados.sinaisArrombamentoSim;
      _sinaisArrombamentoNao = dados.sinaisArrombamentoNao;
      _sinaisArrombamentoNaoSeAplica = dados.sinaisArrombamentoNaoSeAplica;
      _viasAcessoController.text = dados.descricaoViasAcesso ?? '';
      _sinaisArrombamentoController.text = dados.sinaisArrombamentoDescricao ?? '';
      _descricaoLocalController.text = dados.descricaoLocal ?? '';
      _demaisObservacoesController.text = dados.demaisObservacoes ?? '';
    }
  }

  @override
  void dispose() {
    _viasAcessoController.dispose();
    _sinaisArrombamentoController.dispose();
    _descricaoLocalController.dispose();
    _demaisObservacoesController.dispose();
    super.dispose();
  }

  void _onClassificacaoChanged(bool? value, String tipo) {
    setState(() {
      switch (tipo) {
        case 'mediato':
          _classificacaoMediato = value ?? false;
          break;
        case 'imediato':
          _classificacaoImediato = value ?? false;
          break;
        case 'relacionado':
          _classificacaoRelacionado = value ?? false;
          break;
      }
    });
  }

  void _onPisoChanged(bool? value, String tipo) {
    setState(() {
      switch (tipo) {
        case 'seco':
          _pisoSeco = value ?? false;
          if (value == true) {
            _pisoUmido = false;
            _pisoMolhado = false;
          }
          break;
        case 'umido':
          _pisoUmido = value ?? false;
          if (value == true) {
            _pisoSeco = false;
            _pisoMolhado = false;
          }
          break;
        case 'molhado':
          _pisoMolhado = value ?? false;
          if (value == true) {
            _pisoSeco = false;
            _pisoUmido = false;
          }
          break;
      }
    });
  }

  void _onIluminacaoChanged(bool? value, String tipo) {
    setState(() {
      switch (tipo) {
        case 'artificial':
          _iluminacaoArtificial = value ?? false;
          if (value == true) {
            _iluminacaoNatural = false;
            _iluminacaoAusente = false;
          }
          break;
        case 'natural':
          _iluminacaoNatural = value ?? false;
          if (value == true) {
            _iluminacaoArtificial = false;
            _iluminacaoAusente = false;
          }
          break;
        case 'ausente':
          _iluminacaoAusente = value ?? false;
          if (value == true) {
            _iluminacaoArtificial = false;
            _iluminacaoNatural = false;
          }
          break;
      }
    });
  }

  void _onSinaisArrombamentoChanged(bool? value, String tipo) {
    setState(() {
      switch (tipo) {
        case 'sim':
          _sinaisArrombamentoSim = value ?? false;
          if (value == true) {
            _sinaisArrombamentoNao = false;
            _sinaisArrombamentoNaoSeAplica = false;
          }
          break;
        case 'nao':
          _sinaisArrombamentoNao = value ?? false;
          if (value == true) {
            _sinaisArrombamentoSim = false;
            _sinaisArrombamentoNaoSeAplica = false;
          }
          break;
        case 'naoSeAplica':
          _sinaisArrombamentoNaoSeAplica = value ?? false;
          if (value == true) {
            _sinaisArrombamentoSim = false;
            _sinaisArrombamentoNao = false;
          }
          break;
      }
    });
  }

  Future<void> _salvarLocalFurto() async {
    setState(() {
      _salvando = true;
    });

    try {
      final localFurto = LocalFurtoModel(
        classificacaoMediato: _classificacaoMediato,
        classificacaoImediato: _classificacaoImediato,
        classificacaoRelacionado: _classificacaoRelacionado,
        pisoSeco: _pisoSeco,
        pisoUmido: _pisoUmido,
        pisoMolhado: _pisoMolhado,
        iluminacaoArtificial: _iluminacaoArtificial,
        iluminacaoNatural: _iluminacaoNatural,
        iluminacaoAusente: _iluminacaoAusente,
        descricaoViasAcesso: _viasAcessoController.text.trim().isEmpty
            ? null
            : _viasAcessoController.text.trim(),
        sinaisArrombamentoDescricao: _sinaisArrombamentoController.text.trim().isEmpty
            ? null
            : _sinaisArrombamentoController.text.trim(),
        descricaoLocal: _descricaoLocalController.text.trim().isEmpty
            ? null
            : _descricaoLocalController.text.trim(),
        demaisObservacoes: _demaisObservacoesController.text.trim().isEmpty
            ? null
            : _demaisObservacoesController.text.trim(),
        sinaisArrombamentoSim: _sinaisArrombamentoSim,
        sinaisArrombamentoNao: _sinaisArrombamentoNao,
        sinaisArrombamentoNaoSeAplica: _sinaisArrombamentoNaoSeAplica,
      );

      // Preservar todos os dados existentes
      final fichaAtualizada = widget.ficha.copyWith(
        localFurto: localFurto,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: widget.ficha.equipe,
        equipesPoliciais: widget.ficha.equipesPoliciais,
        local: widget.ficha.local,
        dadosFichaBase: widget.ficha.dadosFichaBase,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para tela de evidências
        final resultado = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EvidenciasFurtoScreen(ficha: fichaAtualizada),
          ),
        );

        // Se voltou das evidências, retornar true para atualizar lista
        if (mounted && resultado == true) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Widget _buildCheckboxRow(String label, List<Map<String, dynamic>> opcoes) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: opcoes.map((opcao) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: opcao['value'] as bool? ?? false,
                      onChanged: opcao['onChanged'] as void Function(bool?)?,
                    ),
                    Flexible(child: Text(opcao['label'] as String)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local - Furto/Dano'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título da seção
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: const Text(
                'LOCAL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Tabela de dados
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                children: [
                  // Classificação
                  _buildCheckboxRow(
                    'Classificação',
                    [
                      {
                        'label': 'Mediato',
                        'value': _classificacaoMediato ?? false,
                        'onChanged': (value) => _onClassificacaoChanged(value, 'mediato'),
                      },
                      {
                        'label': 'Imediato',
                        'value': _classificacaoImediato ?? false,
                        'onChanged': (value) => _onClassificacaoChanged(value, 'imediato'),
                      },
                      {
                        'label': 'Relacionado',
                        'value': _classificacaoRelacionado ?? false,
                        'onChanged': (value) => _onClassificacaoChanged(value, 'relacionado'),
                      },
                    ],
                  ),
                  const Divider(height: 1),
                  // Condições do Piso
                  _buildCheckboxRow(
                    'Condições do Piso',
                    [
                      {
                        'label': 'Seco',
                        'value': _pisoSeco ?? false,
                        'onChanged': (value) => _onPisoChanged(value, 'seco'),
                      },
                      {
                        'label': 'Úmido',
                        'value': _pisoUmido ?? false,
                        'onChanged': (value) => _onPisoChanged(value, 'umido'),
                      },
                      {
                        'label': 'Molhado',
                        'value': _pisoMolhado ?? false,
                        'onChanged': (value) => _onPisoChanged(value, 'molhado'),
                      },
                    ],
                  ),
                  const Divider(height: 1),
                  // Iluminação
                  _buildCheckboxRow(
                    'Iluminação',
                    [
                      {
                        'label': 'Artificial',
                        'value': _iluminacaoArtificial ?? false,
                        'onChanged': (value) => _onIluminacaoChanged(value, 'artificial'),
                      },
                      {
                        'label': 'Natural',
                        'value': _iluminacaoNatural ?? false,
                        'onChanged': (value) => _onIluminacaoChanged(value, 'natural'),
                      },
                      {
                        'label': 'Ausente',
                        'value': _iluminacaoAusente ?? false,
                        'onChanged': (value) => _onIluminacaoChanged(value, 'ausente'),
                      },
                    ],
                  ),
                  const Divider(height: 1),
                  // Descrição das Vias de Acesso
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Descrição das Vias de Acesso:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _viasAcessoController,
                          decoration: const InputDecoration(
                            hintText: 'Descreva as vias de acesso...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Sinais de Arrombamento
                  _buildCheckboxRow(
                    'Sinais de Arrombamento',
                    [
                      {
                        'label': 'Sim',
                        'value': _sinaisArrombamentoSim ?? false,
                        'onChanged': (value) => _onSinaisArrombamentoChanged(value, 'sim'),
                      },
                      {
                        'label': 'Não',
                        'value': _sinaisArrombamentoNao ?? false,
                        'onChanged': (value) => _onSinaisArrombamentoChanged(value, 'nao'),
                      },
                      {
                        'label': 'Não Se Aplica',
                        'value': _sinaisArrombamentoNaoSeAplica ?? false,
                        'onChanged': (value) => _onSinaisArrombamentoChanged(value, 'naoSeAplica'),
                      },
                    ],
                  ),
                  const Divider(height: 1),
                  // Descrição dos Sinais de Arrombamento
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Descrição dos Sinais de Arrombamento:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _sinaisArrombamentoController,
                          decoration: const InputDecoration(
                            hintText: 'Descreva os sinais de arrombamento...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Descrição do Local
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Descrição do Local:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '(Descrever os Locais Mediato, Imediato e Relacionado (nesta ordem), atentando-se para a descrição do geral para o particular).',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descricaoLocalController,
                          decoration: const InputDecoration(
                            hintText: 'Descreva o local...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: null,
                          minLines: 8,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Demais Observações
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demais Observações:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _demaisObservacoesController,
                          decoration: const InputDecoration(
                            hintText: 'Digite observações adicionais...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: null,
                          minLines: 4,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _salvarLocalFurto,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _salvando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Salvar e Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

