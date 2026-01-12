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
  
  // Mapa para armazenar controllers dos materiais
  final Map<String, TextEditingController> _materialDescricaoControllers = {};
  final Map<String, TextEditingController> _materialQuantidadeControllers = {};

  // Lista de identificações pré-definidas (fixas - EV01 a EV07)
  static const List<String> _identificacoesPredefinidas = [
    'Destruição ou Rompimento de Obstáculo',
    'Escalada (se sim, inserir altura do obstáculo, em metros)',
    'Uso de Instrumentos (se sim, especificar)',
    'Emprego de Chave Falsa',
    'Concurso de uma ou mais pessoas',
    'Ausência de Fechaduras (ou similares)',
    'Vestígios de Recenticidade',
  ];
  
  // Número de evidências fixas (EV01 a EV07)
  static const int _numeroEvidenciasFixas = 7;

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
    // Observação: para "Fragmentos de impressões papilares" o campo é usado para descrever
    // a superfície onde houve a coleta (exigência do laudo em 5.2.2), então evitamos
    // preencher automaticamente com texto de técnica de revelação.
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
      // Criar apenas evidências fixas (EV01 a EV07)
      _evidencias = _identificacoesPredefinidas.asMap().entries.map((entry) {
        return EvidenciaModel(
          id: 'EV${(entry.key + 1).toString().padLeft(2, '0')}',
          identificacao: entry.value,
        );
      }).toList();
    } else {
      // Separar evidências fixas e dinâmicas ao carregar
      // Ordenar por ID numérico
      _evidencias.sort((a, b) {
        final numA = int.tryParse(a.id.replaceAll('EV', '')) ?? 0;
        final numB = int.tryParse(b.id.replaceAll('EV', '')) ?? 0;
        return numA.compareTo(numB);
      });
      
      // Garantir que todas as evidências fixas existam
      final evidenciasFixas = <EvidenciaModel>[];
      final evidenciasDinamicas = <EvidenciaModel>[];
      
      for (final evidencia in _evidencias) {
        if (_isEvidenciaFixa(evidencia)) {
          evidenciasFixas.add(evidencia);
        } else {
          evidenciasDinamicas.add(evidencia);
        }
      }
      
      // Preencher evidências fixas faltantes
      for (int i = 0; i < _identificacoesPredefinidas.length; i++) {
        final idEsperado = 'EV${(i + 1).toString().padLeft(2, '0')}';
        final existe = evidenciasFixas.any((e) => e.id == idEsperado);
        if (!existe) {
          evidenciasFixas.insert(
            i,
            EvidenciaModel(
              id: idEsperado,
              identificacao: _identificacoesPredefinidas[i],
            ),
          );
        }
      }
      
      // Ordenar evidências fixas por ID
      evidenciasFixas.sort((a, b) {
        final numA = int.tryParse(a.id.replaceAll('EV', '')) ?? 0;
        final numB = int.tryParse(b.id.replaceAll('EV', '')) ?? 0;
        return numA.compareTo(numB);
      });
      
      _evidencias = [...evidenciasFixas, ...evidenciasDinamicas];
    }
  }
  
  bool _isEvidenciaFixa(EvidenciaModel evidencia) {
    final numero = int.tryParse(evidencia.id.replaceAll('EV', '')) ?? 0;
    return numero <= _numeroEvidenciasFixas;
  }
  
  String _gerarProximoIdEvidencia() {
    if (_evidencias.isEmpty) {
      return 'EV08';
    }
    // Encontrar o maior número de evidência
    int maxNum = _numeroEvidenciasFixas;
    for (final evidencia in _evidencias) {
      final num = int.tryParse(evidencia.id.replaceAll('EV', '')) ?? 0;
      if (num > maxNum) {
        maxNum = num;
      }
    }
    return 'EV${(maxNum + 1).toString().padLeft(2, '0')}';
  }
  
  void _adicionarEvidencia() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Evidência'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Identificação da evidência',
            hintText: 'Ex: Impressões digitais, Manchas de sangue, etc.',
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
                setState(() {
                  _evidencias.add(
                    EvidenciaModel(
                      id: _gerarProximoIdEvidencia(),
                      identificacao: controller.text.trim(),
                    ),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }
  
  void _editarEvidencia(EvidenciaModel evidencia, int index) {
    final controller = TextEditingController(text: evidencia.identificacao);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Evidência'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Identificação da evidência',
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
                setState(() {
                  _evidencias[index] = evidencia.copyWith(
                    identificacao: controller.text.trim(),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
  
  void _removerEvidencia(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Evidência'),
        content: Text(
          'Deseja realmente remover a evidência ${_evidencias[index].id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                // Remover controllers da evidência
                final evidenciaId = _evidencias[index].id;
                _descricaoControllers[evidenciaId]?.dispose();
                _coord1Controllers[evidenciaId]?.dispose();
                _coord2Controllers[evidenciaId]?.dispose();
                _observacoesControllers[evidenciaId]?.dispose();
                _descricaoControllers.remove(evidenciaId);
                _coord1Controllers.remove(evidenciaId);
                _coord2Controllers.remove(evidenciaId);
                _observacoesControllers.remove(evidenciaId);
                
                _evidencias.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
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
    for (var controller in _materialDescricaoControllers.values) {
      controller.dispose();
    }
    for (var controller in _materialQuantidadeControllers.values) {
      controller.dispose();
    }
    _descricaoControllers.clear();
    _coord1Controllers.clear();
    _coord2Controllers.clear();
    _observacoesControllers.clear();
    _materialDescricaoControllers.clear();
    _materialQuantidadeControllers.clear();
  }
  
  TextEditingController _getMaterialDescricaoController(String id, String? value) {
    if (!_materialDescricaoControllers.containsKey(id)) {
      _materialDescricaoControllers[id] = TextEditingController(text: value ?? '');
    }
    return _materialDescricaoControllers[id]!;
  }
  
  TextEditingController _getMaterialQuantidadeController(String id, String? value) {
    if (!_materialQuantidadeControllers.containsKey(id)) {
      _materialQuantidadeControllers[id] = TextEditingController(text: value ?? '');
    }
    return _materialQuantidadeControllers[id]!;
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
      // Inicializar controllers para o novo material
      if (descricaoDetalhada != null) {
        _getMaterialDescricaoController(novoId, descricaoDetalhada);
      }
      if (quantidade != null) {
        _getMaterialQuantidadeController(novoId, quantidade);
      }
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
      // Remover controllers do material
      _materialDescricaoControllers[id]?.dispose();
      _materialQuantidadeControllers[id]?.dispose();
      _materialDescricaoControllers.remove(id);
      _materialQuantidadeControllers.remove(id);
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
    
    final isFixa = _isEvidenciaFixa(evidencia);

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
                // Botões de editar/excluir apenas para evidências dinâmicas
                if (!isFixa) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editarEvidencia(evidencia, index),
                    tooltip: 'Editar evidência',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _removerEvidencia(index),
                    tooltip: 'Remover evidência',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.red,
                  ),
                ],
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
                    final quantidadeController = _getMaterialQuantidadeController(material.id, material.quantidade);
                    final descricaoController = _getMaterialDescricaoController(material.id, material.descricaoDetalhada);
                    
                    return Card(
                      key: ValueKey(material.id),
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
                                key: ValueKey('${material.id}_descricao'),
                                controller: descricaoController,
                                decoration: InputDecoration(
                                  labelText: material.descricao == 'Sangue humano'
                                      ? 'Superfície onde estava a mancha'
                                      : material.descricao ==
                                              'Fragmentos de impressões papilares'
                                          ? 'Superfície onde houve a coleta'
                                      : 'Descrição',
                                  hintText: material.descricao == 'Sangue humano'
                                      ? 'Ex: sobre a superfície do vidro'
                                      : material.descricao ==
                                              'Fragmentos de impressões papilares'
                                          ? 'Ex: no vidro da janela da sala'
                                      : null,
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  key: ValueKey('${material.id}_quantidade'),
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

  void _mostrarInstrucoes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instruções de Uso - Evidências'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Descrever objetivamente os seguintes itens, quando houver, sem analisar aspectos da discussão:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('• Marcas de escalada (fazer medições da altura);'),
              const Text('• Rompimento/destruição de obstáculos;'),
              const Text('• Aberturas em janelas, paredes ou outros obstáculos (fazer medições);'),
              const Text('• Marcas de pegadas visíveis (quando possível, diferenciar se a pessoa estava calçada ou descalça);'),
              const Text('• Impressões Papilares visíveis;'),
              const Text('• Manchas de sangue/material biológico visíveis (material de contato, escarro, urina e outras substâncias);'),
              const Text('• Objetos deixados por autores;'),
              const Text('• Sinais indicativos de subtração de objetos (p. ex.: marcas de poeira);'),
              const Text('• Danos em objetos;'),
              const Text('• Desorganização de objetos e móveis (compatível com luta corporal; e/ou hábitos dos próprios moradores; e/ou busca por objetos de valor/interesse);'),
              const Text('• Outros elementos materiais relevantes.'),
              const SizedBox(height: 16),
              const Text(
                'OBS.: se houver levantamento de Impressões Papilares, mas não forem encontradas Impressões apropriadas, descrever que houve o levantamento sem o devido encaminhamento.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              const Text(
                'OBS.: é obrigatória a identificação numérica dos vestígios no local, nas fotos e no Laudo.',
                style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _mostrarInstrucoes,
            tooltip: 'Instruções de uso',
          ),
        ],
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
                children: [
                  ..._evidencias.asMap().entries.map((entry) {
                    return _buildEvidenciaRow(entry.value, entry.key);
                  }).toList(),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _adicionarEvidencia,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Evidência'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
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
            const SizedBox(height: 80), // Padding extra no final para garantir que o botão fique visível
          ],
        ),
      ),
    );
  }
}

