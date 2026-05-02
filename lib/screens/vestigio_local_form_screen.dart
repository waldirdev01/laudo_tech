import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/laboratorio_model.dart';
import '../models/unidade_model.dart';
import '../models/vestigio_local_model.dart';
import '../services/laboratorio_service.dart';
import '../services/perito_service.dart';
import '../services/unidade_service.dart';

/// Tela cheia para cadastrar ou editar um vestígio de local (mediato / imediato / relacionado).
class VestigioLocalFormScreen extends StatefulWidget {
  final String fichaId;
  final VestigioLocalModel? vestigioExistente;

  /// Novo vestígio: após cada salvamento chama [onSalvo], limpa o formulário e permanece nesta tela
  /// até o usuário tocar em **Concluir** ou na seta voltar.
  final bool manterNaTelaAposSalvarNovo;

  /// Obrigatório quando [manterNaTelaAposSalvarNovo] é true.
  final ValueChanged<VestigioLocalModel>? onSalvo;

  // ignore: prefer_const_constructors_in_immutables — [onSalvo] impede const.
  VestigioLocalFormScreen({
    super.key,
    required this.fichaId,
    this.vestigioExistente,
    this.manterNaTelaAposSalvarNovo = false,
    this.onSalvo,
  }) : assert(
         !manterNaTelaAposSalvarNovo || onSalvo != null,
         'onSalvo é obrigatório quando manterNaTelaAposSalvarNovo é true',
       );

  static String gerarIdVestigio() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  @override
  State<VestigioLocalFormScreen> createState() =>
      _VestigioLocalFormScreenState();
}

class _VestigioLocalFormScreenState extends State<VestigioLocalFormScreen> {
  final _peritoService = PeritoService();
  final _unidadeService = UnidadeService();
  final _laboratorioService = LaboratorioService();
  final _imagePicker = ImagePicker();
  final _scrollController = ScrollController();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _coordenadaXCtrl;
  late final TextEditingController _coordenadaYCtrl;
  late final TextEditingController _alturaCtrl;
  late final TextEditingController _numeroLacreCtrl;

  final List<String> _fotosVinculadas = [];

  TipoAcaoVestigio? _tipoAcaoSelecionado;
  TipoDestinoVestigio? _tipoDestinoSelecionado;
  String? _destinoIdSelecionado;
  bool _isSangueHumano = false;
  String? _erroMensagem;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.vestigioExistente;
    _nomeCtrl = TextEditingController(text: e?.nome ?? '');
    _descricaoCtrl = TextEditingController(text: e?.descricao ?? '');
    _coordenadaXCtrl = TextEditingController(text: e?.coordenadaX ?? '');
    _coordenadaYCtrl = TextEditingController(text: e?.coordenadaY ?? '');
    _alturaCtrl = TextEditingController(text: e?.alturaRelacaoPiso ?? '');
    _numeroLacreCtrl = TextEditingController(text: e?.numeroLacre ?? '');
    _fotosVinculadas.addAll(e?.fotosVinculadasPaths ?? const <String>[]);
    _tipoAcaoSelecionado = e?.tipoAcao;
    _tipoDestinoSelecionado = e?.tipoDestino;
    _destinoIdSelecionado = e?.destinoId;
    _isSangueHumano = e?.isSangueHumano ?? false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nomeCtrl.dispose();
    _descricaoCtrl.dispose();
    _coordenadaXCtrl.dispose();
    _coordenadaYCtrl.dispose();
    _alturaCtrl.dispose();
    _numeroLacreCtrl.dispose();
    super.dispose();
  }

  void _resetFormParaNovo() {
    FocusManager.instance.primaryFocus?.unfocus();
    _nomeCtrl.clear();
    _descricaoCtrl.clear();
    _coordenadaXCtrl.clear();
    _coordenadaYCtrl.clear();
    _alturaCtrl.clear();
    _numeroLacreCtrl.clear();
    _fotosVinculadas.clear();
    setState(() {
      _tipoAcaoSelecionado = null;
      _tipoDestinoSelecionado = null;
      _destinoIdSelecionado = null;
      _isSangueHumano = false;
      _erroMensagem = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  String _nomeArquivo(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  Future<String?> _persistirFotoVestigio(XFile arquivo) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pasta = Directory(
        '${dir.path}/levantamento_fotografico/${widget.fichaId}',
      );
      if (!await pasta.exists()) {
        await pasta.create(recursive: true);
      }
      final ext = arquivo.path.contains('.')
          ? arquivo.path.split('.').last.toLowerCase()
          : 'jpg';
      final destino = File(
        '${pasta.path}/foto_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      final bytes = await arquivo.readAsBytes();
      await destino.writeAsBytes(bytes);
      return destino.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _salvar() async {
    setState(() {
      _erroMensagem = null;
    });

    if (_descricaoCtrl.text.trim().isEmpty ||
        _coordenadaXCtrl.text.trim().isEmpty ||
        _coordenadaYCtrl.text.trim().isEmpty) {
      setState(() {
        _erroMensagem = 'Preencha descrição e coordenadas X e Y';
      });
      return;
    }

    if (_fotosVinculadas.isEmpty) {
      setState(() {
        _erroMensagem =
            'Informe ao menos uma fotografia relacionada ao vestígio.';
      });
      return;
    }

    if (_tipoAcaoSelecionado == TipoAcaoVestigio.coletado) {
      if (_tipoDestinoSelecionado == null) {
        setState(() {
          _erroMensagem =
              'Selecione se será analisado na Unidade ou encaminhado para laboratório';
        });
        return;
      }

      final lista = _tipoDestinoSelecionado == TipoDestinoVestigio.unidade
          ? await _unidadeService.listarUnidades()
          : await _laboratorioService.listarLaboratorios();

      if (lista.isEmpty) {
        final tipoTexto = _tipoDestinoSelecionado == TipoDestinoVestigio.unidade
            ? 'unidade'
            : 'laboratório';
        setState(() {
          _erroMensagem =
              'Nenhuma $tipoTexto cadastrada. Cadastre em Configurações antes de salvar.';
        });
        return;
      }

      if (_destinoIdSelecionado == null) {
        final tipoTexto = _tipoDestinoSelecionado == TipoDestinoVestigio.unidade
            ? 'unidade'
            : 'laboratório';
        setState(() {
          _erroMensagem = 'Selecione a $tipoTexto de destino';
        });
        return;
      }
    }

    setState(() => _salvando = true);
    try {
      final perito = await _peritoService.obterPerito();
      final nomePerito = perito?.nome ?? '';

      String? coletadoPor;
      String? dataHoraColeta;
      if (_tipoAcaoSelecionado == TipoAcaoVestigio.coletado) {
        coletadoPor = nomePerito;
        final agora = DateTime.now();
        dataHoraColeta = DateFormat('dd/MM/yyyy HH:mm').format(agora);
      }

      final novo = VestigioLocalModel(
        id: widget.vestigioExistente?.id ?? VestigioLocalFormScreen.gerarIdVestigio(),
        nome: _nomeCtrl.text.trim().isEmpty ? null : _nomeCtrl.text.trim(),
        descricao: _descricaoCtrl.text.trim(),
        coordenadaX: _coordenadaXCtrl.text.trim(),
        coordenadaY: _coordenadaYCtrl.text.trim(),
        alturaRelacaoPiso: _alturaCtrl.text.trim().isEmpty
            ? null
            : _alturaCtrl.text.trim(),
        tipoAcao: _tipoAcaoSelecionado,
        tipoDestino: _tipoDestinoSelecionado,
        destinoId: _destinoIdSelecionado,
        coletadoPor: coletadoPor,
        dataHoraColeta: dataHoraColeta,
        numeroLacre: _numeroLacreCtrl.text.trim().isEmpty
            ? null
            : _numeroLacreCtrl.text.trim(),
        isSangueHumano: _isSangueHumano,
        fotosVinculadasPaths: List<String>.from(_fotosVinculadas),
      );

      if (!mounted) return;

      final continuar = widget.manterNaTelaAposSalvarNovo &&
          widget.vestigioExistente == null &&
          widget.onSalvo != null;

      if (continuar) {
        widget.onSalvo!(novo);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vestígio salvo. Registre outro ou toque em Concluir para voltar aos detalhes do local.',
            ),
          ),
        );
        _resetFormParaNovo();
      } else {
        Navigator.of(context).pop(novo);
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existente = widget.vestigioExistente;
    final fluxoContinuo =
        widget.manterNaTelaAposSalvarNovo && existente == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fluxoContinuo
              ? 'Registrar vestígios'
              : (existente == null ? 'Adicionar vestígio' : 'Editar vestígio'),
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
          TextFormField(
            controller: _nomeCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome do vestígio (opcional)',
              hintText: 'Ex.: mancha hemática próxima à porta',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descricaoCtrl,
            decoration: const InputDecoration(
              labelText: 'Descrição do vestígio *',
              border: OutlineInputBorder(),
            ),
            maxLines: null,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 12),
          const Text(
            'Fotografias do vestígio *',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
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
                  if (foto == null) return;
                  final path = await _persistirFotoVestigio(foto);
                  if (path == null) return;
                  setState(() => _fotosVinculadas.add(path));
                },
                icon: const Icon(Icons.photo_camera),
                label: const Text('Fotografar'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final fotos = await _imagePicker.pickMultiImage(
                    imageQuality: 90,
                  );
                  if (fotos.isEmpty) return;
                  for (final foto in fotos) {
                    final path = await _persistirFotoVestigio(foto);
                    if (path != null) {
                      setState(() => _fotosVinculadas.add(path));
                    }
                  }
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Galeria'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_fotosVinculadas.isEmpty)
            Text(
              'Nenhuma foto vinculada.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ..._fotosVinculadas.map(
              (path) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined, size: 18),
                title: Text(
                  _nomeArquivo(path),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remover foto',
                  onPressed: () {
                    setState(() => _fotosVinculadas.remove(path));
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _coordenadaXCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Coordenada X *',
                    border: OutlineInputBorder(),
                    hintText: 'Ex: -23,5 ou -23.5',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _coordenadaYCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Coordenada Y *',
                    border: OutlineInputBorder(),
                    hintText: 'Ex: -46,6 ou -46.6',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _alturaCtrl,
            decoration: const InputDecoration(
              labelText: 'Altura em relação ao piso (opcional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Sangue humano'),
            subtitle: const Text(
              'Marque se este vestígio é sangue humano (para textos específicos no laudo)',
              style: TextStyle(fontSize: 12),
            ),
            value: _isSangueHumano,
            onChanged: (value) {
              setState(() => _isSangueHumano = value ?? false);
            },
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'O vestígio será coletado ou apenas registrado?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RadioGroup<TipoAcaoVestigio>(
            groupValue: _tipoAcaoSelecionado,
            onChanged: (value) {
              setState(() {
                _tipoAcaoSelecionado = value;
                if (value != TipoAcaoVestigio.coletado) {
                  _tipoDestinoSelecionado = null;
                  _destinoIdSelecionado = null;
                }
              });
            },
            child: Column(
              children: [
                ListTile(
                  leading: Radio<TipoAcaoVestigio>(
                    value: TipoAcaoVestigio.registrado,
                  ),
                  title: const Text('Apenas Registrado'),
                  onTap: () {
                    setState(() {
                      _tipoAcaoSelecionado = TipoAcaoVestigio.registrado;
                      _tipoDestinoSelecionado = null;
                      _destinoIdSelecionado = null;
                    });
                  },
                ),
                ListTile(
                  leading: Radio<TipoAcaoVestigio>(
                    value: TipoAcaoVestigio.coletado,
                  ),
                  title: const Text('Coletado'),
                  onTap: () {
                    setState(() {
                      _tipoAcaoSelecionado = TipoAcaoVestigio.coletado;
                    });
                  },
                ),
              ],
            ),
          ),
          if (_tipoAcaoSelecionado == TipoAcaoVestigio.coletado) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Será analisado na Unidade ou encaminhado para laboratório?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            RadioGroup<TipoDestinoVestigio>(
              groupValue: _tipoDestinoSelecionado,
              onChanged: (value) {
                setState(() {
                  _tipoDestinoSelecionado = value;
                  _destinoIdSelecionado = null;
                });
              },
              child: Column(
                children: [
                  ListTile(
                    leading: Radio<TipoDestinoVestigio>(
                      value: TipoDestinoVestigio.unidade,
                    ),
                    title: const Text('Unidade'),
                    onTap: () {
                      setState(() {
                        _tipoDestinoSelecionado = TipoDestinoVestigio.unidade;
                        _destinoIdSelecionado = null;
                      });
                    },
                  ),
                  ListTile(
                    leading: Radio<TipoDestinoVestigio>(
                      value: TipoDestinoVestigio.laboratorio,
                    ),
                    title: const Text('Laboratório'),
                    onTap: () {
                      setState(() {
                        _tipoDestinoSelecionado =
                            TipoDestinoVestigio.laboratorio;
                        _destinoIdSelecionado = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            if (_tipoDestinoSelecionado != null) ...[
              const SizedBox(height: 12),
              FutureBuilder<List<dynamic>>(
                future: _tipoDestinoSelecionado == TipoDestinoVestigio.unidade
                    ? _unidadeService.listarUnidades()
                    : _laboratorioService.listarLaboratorios(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final lista = snapshot.data ?? [];
                  if (lista.isEmpty) {
                    final tipoTexto =
                        _tipoDestinoSelecionado == TipoDestinoVestigio.unidade
                        ? 'unidade'
                        : 'laboratório';
                    return Text(
                      'Nenhuma $tipoTexto cadastrada. Cadastre em Configurações.',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    // ignore: deprecated_member_use
                    value: _destinoIdSelecionado,
                    decoration: InputDecoration(
                      labelText:
                          _tipoDestinoSelecionado == TipoDestinoVestigio.unidade
                          ? 'Selecione a Unidade'
                          : 'Selecione o Laboratório',
                      border: const OutlineInputBorder(),
                    ),
                    selectedItemBuilder: (context) {
                      return lista.map<Widget>((item) {
                        final nome =
                            _tipoDestinoSelecionado ==
                                TipoDestinoVestigio.unidade
                            ? (item as UnidadeModel).nome
                            : (item as LaboratorioModel).nome;
                        return Text(
                          nome,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      }).toList();
                    },
                    items: lista.map<DropdownMenuItem<String>>((item) {
                      final nome =
                          _tipoDestinoSelecionado == TipoDestinoVestigio.unidade
                          ? (item as UnidadeModel).nome
                          : (item as LaboratorioModel).nome;
                      final id = item.id;
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(nome),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _destinoIdSelecionado = value);
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numeroLacreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número do lacre (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: _salvando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar vestígio'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
