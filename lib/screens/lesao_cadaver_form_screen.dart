import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cadaver_model.dart';
import '../services/openai_service.dart';
import '../services/photo_backup_service.dart';
import '../widgets/ai_suggestion_button.dart';

typedef AjudaRegiaoLesaoCallback =
    void Function(BuildContext context, TextEditingController regiaoCtrl);

enum TipoLesaoArmaBranca {
  puntiforme('Puntiforme'),
  incisa('Incisa'),
  perfuroincisa('Perfuroincisa'),
  perfurocortante('Perfurocortante');

  final String label;
  const TipoLesaoArmaBranca(this.label);
}

enum ClassificacaoLamina {
  facaUmGume('Faca de um gume'),
  facaDoisGumes('Faca de dois gumes'),
  punhal('Punhal');

  final String label;
  const ClassificacaoLamina(this.label);
}

class SinaisPab {
  static const bordasRegulares = 'Bordas regulares/nítidas';
  static const caudaEscoriacao = 'Cauda de escoriação (sugere direção)';
  static const maiorProfundidade = 'Predomínio de profundidade';
  static const maiorExtensao = 'Predomínio de extensão superficial';

  static List<String> get todos => [
    bordasRegulares,
    caudaEscoriacao,
    maiorProfundidade,
    maiorExtensao,
  ];
}

/// Tela cheia para cadastrar ou editar uma lesão/evidência no exame do cadáver.
class LesaoCadaverFormScreen extends StatefulWidget {
  final String fichaId;
  final int cadaverNumero;
  final LesaoCadaverModel? lesaoExistente;

  /// Nova lesão: após cada salvamento chama [onSalvo], limpa o formulário e permanece nesta tela
  /// até **Concluir** ou voltar.
  final bool manterNaTelaAposSalvarNovo;
  final ValueChanged<LesaoCadaverModel>? onSalvo;
  final AjudaRegiaoLesaoCallback onAjudaRegiao;

  // ignore: prefer_const_constructors_in_immutables — [onSalvo] / callback impedem const.
  LesaoCadaverFormScreen({
    super.key,
    required this.fichaId,
    required this.cadaverNumero,
    this.lesaoExistente,
    this.manterNaTelaAposSalvarNovo = false,
    this.onSalvo,
    required this.onAjudaRegiao,
  }) : assert(
         !manterNaTelaAposSalvarNovo || onSalvo != null,
         'onSalvo é obrigatório quando manterNaTelaAposSalvarNovo é true',
       );

  static String gerarIdLesao() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  @override
  State<LesaoCadaverFormScreen> createState() => _LesaoCadaverFormScreenState();
}

class _LesaoCadaverFormScreenState extends State<LesaoCadaverFormScreen> {
  final _imagePicker = ImagePicker();
  final _scrollController = ScrollController();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _regiaoCtrl;
  late final TextEditingController _tipoCtrl;
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _diametroCtrl;

  late String _subpastaFotos;
  final List<String> _fotosLesao = [];

  bool _isPaf = false;
  bool _isPab = false;
  TipoLesaoPaf _tipoLesaoPaf = TipoLesaoPaf.entrada;
  DistanciaTiro? _distanciaTiro;
  Set<String> _sinaisSelecionados = {};
  TipoLesaoArmaBranca _tipoLesaoPab = TipoLesaoArmaBranca.perfuroincisa;
  ClassificacaoLamina _classificacaoLamina = ClassificacaoLamina.facaUmGume;
  Set<String> _sinaisPabSelecionados = {};

  String? _erroMensagem;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.lesaoExistente;
    _nomeCtrl = TextEditingController(text: e?.nome ?? '');
    _regiaoCtrl = TextEditingController(text: e?.regiao ?? '');
    _tipoCtrl = TextEditingController(text: e?.tipo ?? '');
    _descricaoCtrl = TextEditingController(text: e?.descricao ?? '');
    _diametroCtrl = TextEditingController(
      text: e?.paf?.diametro?.toString() ?? '',
    );
    _isPaf = e?.isPaf ?? false;
    _isPab = !_isPaf && (e?.tipo?.toUpperCase() == 'PAB');
    _tipoLesaoPaf = e?.paf?.tipo ?? TipoLesaoPaf.entrada;
    _distanciaTiro = e?.paf?.distancia;
    _sinaisSelecionados = Set<String>.from(e?.paf?.sinais ?? []);
    _fotosLesao.addAll(e?.fotosPaths ?? const <String>[]);
    _subpastaFotos = e != null
        ? 'lesao_${e.id}'
        : 'lesao_novo_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nomeCtrl.dispose();
    _regiaoCtrl.dispose();
    _tipoCtrl.dispose();
    _descricaoCtrl.dispose();
    _diametroCtrl.dispose();
    super.dispose();
  }

  void _resetFormParaNovo() {
    FocusManager.instance.primaryFocus?.unfocus();
    _nomeCtrl.clear();
    _regiaoCtrl.clear();
    _tipoCtrl.clear();
    _descricaoCtrl.clear();
    _diametroCtrl.clear();
    _fotosLesao.clear();
    setState(() {
      _isPaf = false;
      _isPab = false;
      _tipoLesaoPaf = TipoLesaoPaf.entrada;
      _distanciaTiro = null;
      _sinaisSelecionados = {};
      _tipoLesaoPab = TipoLesaoArmaBranca.perfuroincisa;
      _classificacaoLamina = ClassificacaoLamina.facaUmGume;
      _sinaisPabSelecionados = {};
      _erroMensagem = null;
      _subpastaFotos = 'lesao_novo_${DateTime.now().microsecondsSinceEpoch}';
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  String _nomeArquivoFoto(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  Future<String?> _persistirFotoLesao(XFile arquivo) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pasta = Directory(
        '${dir.path}/levantamento_fotografico/${widget.fichaId}/cadaver_${widget.cadaverNumero}/$_subpastaFotos',
      );
      if (!await pasta.exists()) await pasta.create(recursive: true);
      final ext = arquivo.path.contains('.')
          ? arquivo.path.split('.').last.toLowerCase()
          : 'jpg';
      final destino = File(
        '${pasta.path}/foto_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      final bytes = await arquivo.readAsBytes();
      await destino.writeAsBytes(bytes);
      await PhotoBackupService.saveToGallery(destino.path);
      return destino.path;
    } catch (_) {
      return null;
    }
  }

  void _atualizarPresets() {
    final novos = aplicarPresetPAF(_tipoLesaoPaf, _distanciaTiro);
    setState(() => _sinaisSelecionados = novos);
    _atualizarDescricaoAutomatica();
  }

  void _atualizarDescricaoAutomatica() {
    if (_regiaoCtrl.text.trim().isEmpty) return;

    if (_isPaf) {
      final descricao = gerarDescricaoPAF(
        regiao: _regiaoCtrl.text.trim(),
        tipo: _tipoLesaoPaf,
        distancia: _tipoLesaoPaf != TipoLesaoPaf.saida ? _distanciaTiro : null,
        diametro: double.tryParse(_diametroCtrl.text),
        sinais: _sinaisSelecionados,
      );
      setState(() {
        _descricaoCtrl.text = descricao;
      });
      return;
    }

    if (_isPab) {
      final descricaoTipo = switch (_tipoLesaoPab) {
        TipoLesaoArmaBranca.puntiforme =>
          'Lesão puntiforme, compatível com ação de instrumento perfurante',
        TipoLesaoArmaBranca.incisa =>
          'Lesão incisa, compatível com ação de instrumento cortante',
        TipoLesaoArmaBranca.perfuroincisa =>
          'Lesão perfuroincisa, compatível com ação de instrumento perfurocortante',
        TipoLesaoArmaBranca.perfurocortante =>
          'Lesão por instrumento perfurocortante (padrão perfuroinciso)',
      };
      final partes = <String>[
        '$descricaoTipo (${_classificacaoLamina.label.toLowerCase()})',
        'em ${_regiaoCtrl.text.trim()}',
      ];
      if (_sinaisPabSelecionados.isNotEmpty) {
        final sinais = _sinaisPabSelecionados.toList();
        final textoSinais = sinais.length == 1
            ? sinais.first.toLowerCase()
            : '${sinais.sublist(0, sinais.length - 1).join(', ').toLowerCase()} e ${sinais.last.toLowerCase()}';
        partes.add('apresentando $textoSinais');
      }
      setState(() {
        _descricaoCtrl.text = '${partes.join(', ')}.';
      });
    }
  }

  Future<void> _salvar() async {
    setState(() => _erroMensagem = null);

    if (_regiaoCtrl.text.trim().isEmpty) {
      setState(() => _erroMensagem = 'Informe a região da lesão');
      return;
    }

    setState(() => _salvando = true);
    try {
      PafData? pafData;
      if (_isPaf) {
        pafData = PafData(
          tipo: _tipoLesaoPaf,
          distancia: _tipoLesaoPaf != TipoLesaoPaf.saida
              ? _distanciaTiro
              : null,
          diametro: double.tryParse(_diametroCtrl.text),
          sinais: Set<String>.from(_sinaisSelecionados),
        );
      }

      final novaLesao = LesaoCadaverModel(
        id: widget.lesaoExistente?.id ?? LesaoCadaverFormScreen.gerarIdLesao(),
        nome: _nomeCtrl.text.trim().isEmpty ? null : _nomeCtrl.text.trim(),
        regiao: _regiaoCtrl.text.trim(),
        tipo: _isPaf
            ? 'PAF'
            : _isPab
            ? 'PAB'
            : (_tipoCtrl.text.trim().isEmpty ? null : _tipoCtrl.text.trim()),
        descricao: _descricaoCtrl.text.trim().isEmpty
            ? null
            : _descricaoCtrl.text.trim(),
        isPaf: _isPaf,
        paf: pafData,
        fotosPaths: List<String>.from(_fotosLesao),
        numerosFotografias: widget.lesaoExistente?.numerosFotografias,
      );

      if (!mounted) return;

      final continuar =
          widget.manterNaTelaAposSalvarNovo &&
          widget.lesaoExistente == null &&
          widget.onSalvo != null;

      if (continuar) {
        widget.onSalvo!(novaLesao);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lesão salva. Registre outra ou toque em Concluir para voltar ao cadastro do cadáver.',
            ),
          ),
        );
        _resetFormParaNovo();
      } else {
        Navigator.of(context).pop(novaLesao);
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _buildAiContextLesao() {
    final partes = <String>[];
    if (_nomeCtrl.text.trim().isNotEmpty) {
      partes.add('Identificação: ${_nomeCtrl.text.trim()}.');
    }
    if (_regiaoCtrl.text.trim().isNotEmpty) {
      partes.add('Região anatômica: ${_regiaoCtrl.text.trim()}.');
    }
    if (_tipoCtrl.text.trim().isNotEmpty) {
      partes.add('Tipo informado: ${_tipoCtrl.text.trim()}.');
    }
    if (_isPaf) {
      partes.add('Marcado como lesão por PAF.');
      partes.add('Tipo de lesão PAF: ${_tipoLesaoPaf.label}.');
      if (_distanciaTiro != null) {
        partes.add('Distância selecionada: ${_distanciaTiro!.label}.');
      }
      if (_diametroCtrl.text.trim().isNotEmpty) {
        partes.add('Diâmetro informado: ${_diametroCtrl.text.trim()} mm.');
      }
      if (_sinaisSelecionados.isNotEmpty) {
        partes.add('Sinais selecionados: ${_sinaisSelecionados.join(', ')}.');
      }
    }
    if (_isPab) {
      partes.add('Marcado como lesão por faca/punhal (PAB).');
      partes.add('Tipo de lesão por arma branca: ${_tipoLesaoPab.label}.');
      partes.add('Classificação da lâmina: ${_classificacaoLamina.label}.');
      if (_sinaisPabSelecionados.isNotEmpty) {
        partes.add(
          'Características selecionadas: ${_sinaisPabSelecionados.join(', ')}.',
        );
      }
    }
    return partes.join('\n');
  }

  void _replaceDescricao(String text) {
    setState(() => _descricaoCtrl.text = text.trim());
  }

  void _appendDescricao(String text) {
    final atual = _descricaoCtrl.text.trim();
    setState(() {
      _descricaoCtrl.text = atual.isEmpty
          ? text.trim()
          : '$atual\n\n${text.trim()}';
    });
  }

  Widget _buildSecaoFotosLesao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Fotos da lesão',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final foto = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 90,
                );
                if (foto == null || !mounted) return;
                final path = await _persistirFotoLesao(foto);
                if (path != null) {
                  setState(() => _fotosLesao.add(path));
                }
              },
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Câmera'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final fotos = await _imagePicker.pickMultiImage(
                  imageQuality: 90,
                );
                if (fotos.isEmpty || !mounted) return;
                final novas = <String>[];
                for (final foto in fotos) {
                  final path = await _persistirFotoLesao(foto);
                  if (path != null) novas.add(path);
                }
                if (novas.isNotEmpty) {
                  setState(() => _fotosLesao.addAll(novas));
                }
              },
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Galeria'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_fotosLesao.isEmpty)
          Text(
            'Nenhuma foto.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          )
        else
          ..._fotosLesao.map(
            (path) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined, size: 18),
              title: Text(
                _nomeArquivoFoto(path),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remover foto',
                onPressed: () => setState(() => _fotosLesao.remove(path)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final existente = widget.lesaoExistente;
    final fluxoContinuo =
        widget.manterNaTelaAposSalvarNovo && existente == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fluxoContinuo
              ? 'Registrar lesões'
              : (existente == null ? 'Nova lesão' : 'Editar lesão'),
        ),
        centerTitle: true,
        actions: [
          if (fluxoContinuo)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Concluir'),
            ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (_erroMensagem != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _erroMensagem!,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          TextField(
            controller: _nomeCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome ou identificação (opcional)',
              border: OutlineInputBorder(),
              hintText: 'Ex.: Orifício A, ferimento frontal',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regiaoCtrl,
            decoration: const InputDecoration(
              labelText: 'Região *',
              border: OutlineInputBorder(),
              hintText: 'Ex: Anterior 12 - Epigástricas ou texto livre',
            ),
            onChanged: (_) => _atualizarDescricaoAutomatica(),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => widget.onAjudaRegiao(context, _regiaoCtrl),
            icon: const Icon(Icons.help_outline, size: 20),
            label: const Text('Consultar numeração do corpo (figura CVLI)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tipoCtrl,
            enabled: !_isPaf && !_isPab,
            decoration: InputDecoration(
              labelText: 'Tipo',
              border: const OutlineInputBorder(),
              hintText: (_isPaf || _isPab)
                  ? 'Preenchido automaticamente'
                  : 'Ex: PAB, contusão, etc.',
              filled: _isPaf || _isPab,
              fillColor: (_isPaf || _isPab) ? Colors.grey.shade800 : null,
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Lesão por PAF'),
            value: _isPaf,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) {
              setState(() {
                _isPaf = value ?? false;
                if (_isPaf) {
                  _isPab = false;
                  _tipoCtrl.text = 'PAF';
                  _atualizarPresets();
                  _atualizarDescricaoAutomatica();
                } else {
                  _tipoCtrl.clear();
                  _descricaoCtrl.clear();
                  _sinaisSelecionados.clear();
                  _distanciaTiro = null;
                }
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Lesão por faca/punhal (PAB)'),
            value: _isPab,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) {
              setState(() {
                _isPab = value ?? false;
                if (_isPab) {
                  _isPaf = false;
                  _tipoCtrl.text = 'PAB';
                  if (_sinaisPabSelecionados.isEmpty) {
                    _sinaisPabSelecionados = {SinaisPab.bordasRegulares};
                  }
                  _atualizarDescricaoAutomatica();
                } else {
                  _tipoCtrl.clear();
                  _descricaoCtrl.clear();
                  _sinaisPabSelecionados.clear();
                }
              });
            },
          ),
          if (_isPaf) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Tipo de lesão',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TipoLesaoPaf.values.map((tipo) {
                final isSelected = _tipoLesaoPaf == tipo;
                return ChoiceChip(
                  label: Text(tipo.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _tipoLesaoPaf = tipo;
                        if (tipo == TipoLesaoPaf.saida) {
                          _distanciaTiro = null;
                        }
                      });
                      _atualizarPresets();
                      _atualizarDescricaoAutomatica();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Distância do disparo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _tipoLesaoPaf == TipoLesaoPaf.saida
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DistanciaTiro.values.map((dist) {
                final isSelected = _distanciaTiro == dist;
                final isDisabled = _tipoLesaoPaf == TipoLesaoPaf.saida;
                return ChoiceChip(
                  label: Text(
                    dist.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDisabled ? Colors.grey : null,
                    ),
                  ),
                  selected: isSelected && !isDisabled,
                  onSelected: isDisabled
                      ? null
                      : (selected) {
                          setState(() {
                            _distanciaTiro = selected ? dist : null;
                          });
                          _atualizarPresets();
                          _atualizarDescricaoAutomatica();
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _diametroCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Diâmetro do orifício (mm)',
                border: OutlineInputBorder(),
                hintText: 'Ex: 9',
              ),
              onChanged: (_) => _atualizarDescricaoAutomatica(),
            ),
            const SizedBox(height: 16),
            Text(
              'Características',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...SinaisPaf.todos.map(
              (sinal) => CheckboxListTile(
                title: Text(sinal, style: const TextStyle(fontSize: 13)),
                value: _sinaisSelecionados.contains(sinal),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _sinaisSelecionados.add(sinal);
                    } else {
                      _sinaisSelecionados.remove(sinal);
                    }
                  });
                  _atualizarDescricaoAutomatica();
                },
              ),
            ),
            const Divider(),
          ],
          if (_isPab) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Tipo de lesão por arma branca',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TipoLesaoArmaBranca.values.map((tipo) {
                final isSelected = _tipoLesaoPab == tipo;
                return ChoiceChip(
                  label: Text(tipo.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() => _tipoLesaoPab = tipo);
                    _atualizarDescricaoAutomatica();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Classificação da lâmina',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ClassificacaoLamina.values.map((lamina) {
                final isSelected = _classificacaoLamina == lamina;
                return ChoiceChip(
                  label: Text(lamina.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() => _classificacaoLamina = lamina);
                    _atualizarDescricaoAutomatica();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Características principais',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...SinaisPab.todos.map(
              (sinal) => CheckboxListTile(
                title: Text(sinal, style: const TextStyle(fontSize: 13)),
                value: _sinaisPabSelecionados.contains(sinal),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _sinaisPabSelecionados.add(sinal);
                    } else {
                      _sinaisPabSelecionados.remove(sinal);
                    }
                  });
                  _atualizarDescricaoAutomatica();
                },
              ),
            ),
            const Divider(),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _buildSecaoFotosLesao(),
          const SizedBox(height: 12),
          TextField(
            controller: _descricaoCtrl,
            decoration: InputDecoration(
              labelText: _isPaf
                  ? 'Descrição (gerada automaticamente)'
                  : _isPab
                  ? 'Descrição (gerada automaticamente)'
                  : 'Descrição',
              border: const OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 8),
          AiSuggestionButton(
            fieldLabel: 'Descrição de lesão',
            currentText: _descricaoCtrl.text,
            currentTextBuilder: () => _descricaoCtrl.text,
            profile: AiSuggestionProfile.cvli,
            contextTextBuilder: _buildAiContextLesao,
            imagePathsBuilder: () => _fotosLesao,
            onReplace: _replaceDescricao,
            onAppend: _appendDescricao,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: _salvando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    fluxoContinuo
                        ? 'Salvar lesão'
                        : (existente == null ? 'Adicionar' : 'Salvar'),
                  ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
