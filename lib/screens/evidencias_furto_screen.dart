import 'package:flutter/material.dart';
import '../models/ficha_completa_model.dart';
import '../models/evidencia_model.dart';
import '../services/ficha_service.dart';
import 'modus_operandi_screen.dart';

class EvidenciasFurtoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const EvidenciasFurtoScreen({
    super.key,
    required this.ficha,
  });

  @override
  State<EvidenciasFurtoScreen> createState() => _EvidenciasFurtoScreenState();
}

class _EvidenciasFurtoScreenState extends State<EvidenciasFurtoScreen> {
  final _fichaService = FichaService();
  bool _salvando = false;

  // Controllers para Marco Zero
  final _marcoZeroDescricaoController = TextEditingController();
  final _marcoZeroXController = TextEditingController();
  final _marcoZeroYController = TextEditingController();

  // Mapa para armazenar controllers das evidências
  final Map<String, TextEditingController> _descricaoControllers = {};
  final Map<String, TextEditingController> _coord1Controllers = {};
  final Map<String, TextEditingController> _coord2Controllers = {};
  final Map<String, TextEditingController> _observacoesControllers = {};

  // Lista de identificações pré-definidas
  static const List<String> _identificacoesPredefinidas = [
    'Destruição ou Rompimento de Obstáculo',
    'Escalada (se sim, inserir altura do obstáculo, em metros)',
    'Uso de Instrumentos (se sim, especificar)',
    'Emprego de Chave Falsa',
    'Concurso de uma ou mais pessoas',
    'Ausência de Fechaduras (ou similares)',
    'Vestígios de Recenticidade',
    'Material Apreendido/Encaminhado para Exames Complementares',
  ];

  // Lista de materiais encontrados (vestígios)
  static const List<String> _materiaisEncontrados = [
    'Sangue humano',
    'Fragmentos de impressões papilares',
  ];

  // Lista de meios de encaminhamento
  static const List<String> _meiosEncaminhamento = [
    'Suabe',
    'Levantador papiloscópico',
    'Papel glossy',
  ];

  // Lista completa de materiais comuns (para compatibilidade)
  static const List<String> _materiaisComuns = [
    ..._materiaisEncontrados,
    ..._meiosEncaminhamento,
  ];

  // Materiais que têm descrição pré-definida
  static const Map<String, String> _descricoesPredefinidas = {
    'Fragmentos de impressões papilares': 'Reveladas por meio da aplicação de pó regular preto sobre a superfície.',
  };

  List<EvidenciaModel> _evidencias = [];
  List<MaterialApreendidoModel> _materiaisApreendidos = [];
  MarcoZeroModel? _marcoZero;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _inicializarEvidencias();
  }

  void _carregarDados() {
    final dados = widget.ficha.evidenciasFurto;
    if (dados != null) {
      _marcoZero = dados.marcoZero;
      if (_marcoZero != null) {
        _marcoZeroDescricaoController.text = _marcoZero!.descricao ?? '';
        _marcoZeroXController.text = _marcoZero!.coordenadaX ?? '';
        _marcoZeroYController.text = _marcoZero!.coordenadaY ?? '';
      }
      _evidencias = List.from(dados.evidencias);
      _materiaisApreendidos = List.from(dados.materiaisApreendidos);
      // Limpar controllers antigos e criar novos baseados nos dados carregados
      _limparControllersEvidencias();
    }
  }

  void _inicializarEvidencias() {
    if (_evidencias.isEmpty) {
      // Criar evidências iniciais com identificações pré-definidas
      _evidencias = _identificacoesPredefinidas.asMap().entries.map((entry) {
        return EvidenciaModel(
          id: 'EV${(entry.key + 1).toString().padLeft(2, '0')}',
          identificacao: entry.value,
        );
      }).toList();
    }
  }

  TextEditingController _getDescricaoController(String id, String? value) {
    if (!_descricaoControllers.containsKey(id)) {
      _descricaoControllers[id] = TextEditingController(text: value ?? '');
    }
    return _descricaoControllers[id]!;
  }

  TextEditingController _getCoord1Controller(String id, String? value) {
    if (!_coord1Controllers.containsKey(id)) {
      _coord1Controllers[id] = TextEditingController(text: value ?? '');
    }
    return _coord1Controllers[id]!;
  }

  TextEditingController _getCoord2Controller(String id, String? value) {
    if (!_coord2Controllers.containsKey(id)) {
      _coord2Controllers[id] = TextEditingController(text: value ?? '');
    }
    return _coord2Controllers[id]!;
  }

  TextEditingController _getObservacoesController(String id, String? value) {
    if (!_observacoesControllers.containsKey(id)) {
      _observacoesControllers[id] = TextEditingController(text: value ?? '');
    }
    return _observacoesControllers[id]!;
  }

  void _limparControllersEvidencias() {
    for (var controller in _descricaoControllers.values) {
      controller.dispose();
    }
    for (var controller in _coord1Controllers.values) {
      controller.dispose();
    }
    for (var controller in _coord2Controllers.values) {
      controller.dispose();
    }
    for (var controller in _observacoesControllers.values) {
      controller.dispose();
    }
    _descricaoControllers.clear();
    _coord1Controllers.clear();
    _coord2Controllers.clear();
    _observacoesControllers.clear();
  }

  @override
  void dispose() {
    _marcoZeroDescricaoController.dispose();
    _marcoZeroXController.dispose();
    _marcoZeroYController.dispose();
    _limparControllersEvidencias();
    super.dispose();
  }

  void _adicionarMaterial(String descricao, {String? quantidade, String? descricaoDetalhada}) {
    setState(() {
      final novoId = DateTime.now().millisecondsSinceEpoch.toString();
      _materiaisApreendidos.add(
        MaterialApreendidoModel(
          id: novoId,
          descricao: descricao,
          isCustom: !_materiaisComuns.contains(descricao),
          quantidade: quantidade,
          descricaoDetalhada: descricaoDetalhada,
        ),
      );
    });
  }

  void _atualizarQuantidadeMaterial(String id, String? quantidade) {
    setState(() {
      final index = _materiaisApreendidos.indexWhere((m) => m.id == id);
      if (index != -1) {
        _materiaisApreendidos[index] = _materiaisApreendidos[index].copyWith(
          quantidade: quantidade?.isEmpty ?? true ? null : quantidade,
        );
      }
    });
  }

  void _atualizarDescricaoDetalhadaMaterial(String id, String? descricaoDetalhada) {
    setState(() {
      final index = _materiaisApreendidos.indexWhere((m) => m.id == id);
      if (index != -1) {
        _materiaisApreendidos[index] = _materiaisApreendidos[index].copyWith(
          descricaoDetalhada: descricaoDetalhada?.isEmpty ?? true ? null : descricaoDetalhada,
        );
      }
    });
  }

  void _removerMaterial(String id) {
    setState(() {
      _materiaisApreendidos.removeWhere((m) => m.id == id);
    });
  }

  Future<void> _salvarEvidencias() async {
    setState(() {
      _salvando = true;
    });

    try {
      final marcoZero = MarcoZeroModel(
        descricao: _marcoZeroDescricaoController.text.trim().isEmpty
            ? null
            : _marcoZeroDescricaoController.text.trim(),
        coordenadaX: _marcoZeroXController.text.trim().isEmpty
            ? null
            : _marcoZeroXController.text.trim(),
        coordenadaY: _marcoZeroYController.text.trim().isEmpty
            ? null
            : _marcoZeroYController.text.trim(),
      );

      final evidenciasFurto = EvidenciasFurtoModel(
        marcoZero: marcoZero.descricao != null || marcoZero.coordenadaX != null || marcoZero.coordenadaY != null
            ? marcoZero
            : null,
        evidencias: _evidencias,
        materiaisApreendidos: _materiaisApreendidos,
      );

      final fichaAtualizada = widget.ficha.copyWith(
        evidenciasFurto: evidenciasFurto,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: widget.ficha.equipe,
        equipesPoliciais: widget.ficha.equipesPoliciais,
        local: widget.ficha.local,
        dadosFichaBase: widget.ficha.dadosFichaBase,
        localFurto: widget.ficha.localFurto,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidências salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navegar para tela de Modus Operandi
        if (!mounted) return;
        final resultado = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ModusOperandiScreen(ficha: fichaAtualizada),
          ),
        );

        // Se voltou do modus operandi, retornar true para atualizar lista
        if (!mounted) return;
        if (resultado == true) {
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

  Widget _buildMarcoZeroSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Text(
              'MARCO ZERO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Defina o ponto de referência (marco zero) para as coordenadas:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _marcoZeroDescricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição do Marco Zero',
                    hintText: 'Ex: Canto esquerdo da entrada principal',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _marcoZeroXController,
                        decoration: const InputDecoration(
                          labelText: 'Coordenada X',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _marcoZeroYController,
                        decoration: const InputDecoration(
                          labelText: 'Coordenada Y',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenciaRow(EvidenciaModel evidencia, int index) {
    final descricaoController = _getDescricaoController(evidencia.id, evidencia.descricao);
    final coord1Controller = _getCoord1Controller(evidencia.id, evidencia.coordenada1);
    final coord2Controller = _getCoord2Controller(evidencia.id, evidencia.coordenada2);
    final observacoesController = _getObservacoesController(evidencia.id, evidencia.observacoesEspeciais);

    // Verificar se precisa de campo especial
    final precisaCampoEspecial = evidencia.identificacao.contains('altura') ||
        evidencia.identificacao.contains('especificar');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    evidencia.id,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    evidencia.identificacao,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (precisaCampoEspecial) ...[
              TextFormField(
                controller: observacoesController,
                decoration: InputDecoration(
                  labelText: evidencia.identificacao.contains('altura')
                      ? 'Altura do obstáculo (metros)'
                      : 'Especificar instrumentos',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  final updated = evidencia.copyWith(observacoesEspeciais: value.isEmpty ? null : value);
                  setState(() {
                    _evidencias[index] = updated;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: descricaoController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: '(tamanho, cor, recenticidade, sentido de produção, área)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (value) {
                final updated = evidencia.copyWith(descricao: value.isEmpty ? null : value);
                setState(() {
                  _evidencias[index] = updated;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: coord1Controller,
                    decoration: const InputDecoration(
                      labelText: 'Coord. 1',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final updated = evidencia.copyWith(coordenada1: value.isEmpty ? null : value);
                      setState(() {
                        _evidencias[index] = updated;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: coord2Controller,
                    decoration: const InputDecoration(
                      labelText: 'Coord. 2',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final updated = evidencia.copyWith(coordenada2: value.isEmpty ? null : value);
                      setState(() {
                        _evidencias[index] = updated;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recolhido:',
                      style: TextStyle(fontSize: 12),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: evidencia.recolhidoSim ?? false,
                          onChanged: (value) {
                            final updated = evidencia.copyWith(
                              recolhidoSim: value ?? false,
                              recolhidoNao: value == true ? false : evidencia.recolhidoNao,
                            );
                            setState(() {
                              _evidencias[index] = updated;
                            });
                          },
                        ),
                        const Text('Sim', style: TextStyle(fontSize: 12)),
                        Checkbox(
                          value: evidencia.recolhidoNao ?? false,
                          onChanged: (value) {
                            final updated = evidencia.copyWith(
                              recolhidoNao: value ?? false,
                              recolhidoSim: value == true ? false : evidencia.recolhidoSim,
                            );
                            setState(() {
                              _evidencias[index] = updated;
                            });
                          },
                        ),
                        const Text('Não', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMateriaisSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              'MATERIAIS APRENDIDOS/ENCAMINHADOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Materiais Encontrados
                const Text(
                  'Materiais Encontrados:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _materiaisEncontrados.map((material) {
                    final jaSelecionado = _materiaisApreendidos.any((m) => m.descricao == material);
                    return FilterChip(
                      label: Text(material),
                      selected: jaSelecionado,
                      onSelected: (selected) {
                        if (selected && !jaSelecionado) {
                          // Verificar se tem descrição pré-definida
                          final descricaoPredefinida = _descricoesPredefinidas[material];
                          _adicionarMaterial(
                            material,
                            descricaoDetalhada: descricaoPredefinida,
                          );
                        } else if (!selected && jaSelecionado) {
                          final materialModel = _materiaisApreendidos.firstWhere((m) => m.descricao == material);
                          _removerMaterial(materialModel.id);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Meios de Encaminhamento
                const Text(
                  'Meios de Encaminhamento:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _meiosEncaminhamento.map((material) {
                    final jaSelecionado = _materiaisApreendidos.any((m) => m.descricao == material);
                    return FilterChip(
                      label: Text(material),
                      selected: jaSelecionado,
                      onSelected: (selected) {
                        if (selected && !jaSelecionado) {
                          // Meios de encaminhamento requerem quantidade
                          final quantidadeController = TextEditingController();
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Adicionar $material'),
                              content: TextField(
                                controller: quantidadeController,
                                decoration: const InputDecoration(
                                  labelText: 'Quantidade',
                                  hintText: 'Ex: 5 amostras, 3 unidades',
                                  border: OutlineInputBorder(),
                                ),
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    final quantidade = quantidadeController.text.trim();
                                    _adicionarMaterial(
                                      material,
                                      quantidade: quantidade.isEmpty ? null : quantidade,
                                    );
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Adicionar'),
                                ),
                              ],
                            ),
                          );
                        } else if (!selected && jaSelecionado) {
                          final materialModel = _materiaisApreendidos.firstWhere((m) => m.descricao == material);
                          _removerMaterial(materialModel.id);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Materiais Adicionados:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                if (_materiaisApreendidos.isEmpty)
                  const Text(
                    'Nenhum material selecionado',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  )
                else
                  ..._materiaisApreendidos.map((material) {
                    final isMaterialEncontrado = _materiaisEncontrados.contains(material.descricao);
                    final isMeioEncaminhamento = _meiosEncaminhamento.contains(material.descricao);
                    final quantidadeController = TextEditingController(text: material.quantidade ?? '');
                    final descricaoController = TextEditingController(text: material.descricaoDetalhada ?? '');
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    material.descricao,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _removerMaterial(material.id),
                                ),
                              ],
                            ),
                            // Para materiais encontrados: mostrar campo de descrição
                            if (isMaterialEncontrado) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: descricaoController,
                                decoration: const InputDecoration(
                                  labelText: 'Descrição',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                maxLines: 3,
                                onChanged: (value) {
                                  _atualizarDescricaoDetalhadaMaterial(material.id, value);
                                },
                              ),
                            ],
                            // Para meios de encaminhamento: mostrar campo de quantidade
                            if (isMeioEncaminhamento) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 200,
                                child: TextFormField(
                                  controller: quantidadeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantidade',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  keyboardType: TextInputType.text,
                                  onChanged: (value) {
                                    _atualizarQuantidadeMaterial(material.id, value);
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final controller = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Adicionar Material'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Descrição do material',
                            border: OutlineInputBorder(),
                          ),
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () {
                              if (controller.text.trim().isNotEmpty) {
                                _adicionarMaterial(controller.text.trim());
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Adicionar'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Material Personalizado'),
                ),
              ],
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
        title: const Text('Evidências'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Marco Zero
            _buildMarcoZeroSection(),
            
            // Título EVIDÊNCIAS
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
                'EVIDÊNCIAS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Instruções
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• Descrever detalhadamente os vestígios detectados em cada local e posicioná-los no cenário; e',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black87
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Especificar as informações de Cadeia de Custódia de cada vestígio, informando acerca de sua coleta e encaminhamento.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black87
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // Lista de Evidências
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                children: _evidencias.asMap().entries.map((entry) {
                  return _buildEvidenciaRow(entry.value, entry.key);
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Materiais Apreendidos
            _buildMateriaisSection(),
            
            // Observação sobre croqui
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Faça seu croqui e adicione depois quando gerar a ficha.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black87
                      : Colors.black87,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _salvarEvidencias,
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

