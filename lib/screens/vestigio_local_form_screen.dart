import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/laboratorio_model.dart';
import '../models/metodo_posicionamento_model.dart';
import '../models/unidade_model.dart';
import '../models/vestigio_local_model.dart';
import '../services/laboratorio_service.dart';
import '../services/ficha_service.dart';
import '../services/perito_service.dart';
import '../services/photo_backup_service.dart';
import '../services/unidade_service.dart';
import '../utils/coordinate_formatter.dart';
import 'exames_complementares_screen.dart';

/// Tela cheia para cadastrar ou editar um vestígio de local (mediato / imediato / relacionado).
class VestigioLocalFormScreen extends StatefulWidget {
  final String fichaId;
  final VestigioLocalModel? vestigioExistente;
  final List<String> ambientesDisponiveis;
  final String? ambienteInicial;
  final bool modoRapido;
  final MetodoPosicionamentoVestigio metodoPosicionamentoPadrao;
  final bool permitirOverrideMetodo;
  final String? avisoContextoGps;

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
    this.ambientesDisponiveis = const [],
    this.ambienteInicial,
    this.modoRapido = false,
    this.metodoPosicionamentoPadrao = MetodoPosicionamentoVestigio.nenhum,
    this.permitirOverrideMetodo = true,
    this.avisoContextoGps,
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
  final _fichaService = FichaService();
  final _imagePicker = ImagePicker();
  final _scrollController = ScrollController();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _coordenadaXCtrl;
  late final TextEditingController _coordenadaYCtrl;
  late final TextEditingController _alturaCtrl;
  late final TextEditingController _numeroLacreCtrl;
  late final TextEditingController _latitudeCtrl;
  late final TextEditingController _longitudeCtrl;

  final List<String> _fotosVinculadas = [];

  TipoAcaoVestigio? _tipoAcaoSelecionado;
  TipoDestinoVestigio? _tipoDestinoSelecionado;
  String? _destinoIdSelecionado;
  bool _isSangueHumano = false;
  bool _isElementoMunicao = false;
  String? _tipoManchaSangueSelecionada;
  String? _tipoElementoMunicaoSelecionado;
  String? _calibreSelecionado;
  String? _ambienteSelecionado;
  final List<String> _opcoesElementoMunicao = [
    'estojo',
    'projétil de arma de fogo',
    'fragmento de chumbo',
    'fragmento de camisa',
  ];
  final List<String> _opcoesCalibre = [
    '.38 SPL',
    '.22 L.R.',
    '.32 L.R.',
    '.380 ACP',
    '9mm LUGER',
  ];
  String? _erroMensagem;
  bool _salvando = false;
  bool _capturandoGps = false;
  bool _usarMetodoEspecifico = false;
  MetodoPosicionamentoVestigio? _metodoOverride;
  double? _precisaoGpsMetros;
  DateTime? _gpsCapturadoEm;
  static const _opcoesManchaSangue = [
    'mancha por contato',
    'mancha por gotejamento',
    'mancha por escorrimento',
    'mancha por projeção',
    'poça hemática',
    'impregnação hemática',
  ];

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
    _latitudeCtrl = TextEditingController(
      text: e?.latitude != null ? e!.latitude!.toStringAsFixed(6) : '',
    );
    _longitudeCtrl = TextEditingController(
      text: e?.longitude != null ? e!.longitude!.toStringAsFixed(6) : '',
    );
    _fotosVinculadas.addAll(e?.fotosVinculadasPaths ?? const <String>[]);
    _ambienteSelecionado = e?.ambiente ?? widget.ambienteInicial;
    if (_ambienteSelecionado != null &&
        !widget.ambientesDisponiveis.contains(_ambienteSelecionado)) {
      _ambienteSelecionado = widget.ambienteInicial;
    }
    _tipoAcaoSelecionado = e?.tipoAcao;
    _tipoDestinoSelecionado = e?.tipoDestino;
    _destinoIdSelecionado = e?.destinoId;
    _isSangueHumano = e?.isSangueHumano ?? false;
    _metodoOverride = e?.metodoPosicionamentoOverride;
    _usarMetodoEspecifico = _metodoOverride != null;
    _precisaoGpsMetros = e?.precisaoGpsMetros;
    _gpsCapturadoEm = e?.gpsCapturadoEm;
    if (widget.modoRapido && _tipoAcaoSelecionado == null) {
      _tipoAcaoSelecionado = TipoAcaoVestigio.registrado;
    }
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
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
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
    _latitudeCtrl.clear();
    _longitudeCtrl.clear();
    _fotosVinculadas.clear();
    setState(() {
      _tipoAcaoSelecionado = widget.modoRapido
          ? TipoAcaoVestigio.registrado
          : null;
      _tipoDestinoSelecionado = null;
      _destinoIdSelecionado = null;
      _isSangueHumano = false;
      _isElementoMunicao = false;
      _tipoManchaSangueSelecionada = null;
      _tipoElementoMunicaoSelecionado = null;
      _calibreSelecionado = null;
      _ambienteSelecionado = widget.ambienteInicial;
      _usarMetodoEspecifico = false;
      _metodoOverride = null;
      _precisaoGpsMetros = null;
      _gpsCapturadoEm = null;
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

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  MetodoPosicionamentoVestigio get _metodoPosicionamentoEfetivo =>
      _usarMetodoEspecifico && _metodoOverride != null
      ? _metodoOverride!
      : widget.metodoPosicionamentoPadrao;

  bool get _usaMarcoZero =>
      _metodoPosicionamentoEfetivo == MetodoPosicionamentoVestigio.marcoZero;

  bool get _usaGps =>
      _metodoPosicionamentoEfetivo == MetodoPosicionamentoVestigio.gps;

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
      await PhotoBackupService.saveToGallery(destino.path);
      return destino.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _capturarCoordenadasGps() async {
    setState(() => _erroMensagem = null);
    try {
      setState(() => _capturandoGps = true);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _erroMensagem =
              'Permissão de localização não concedida. Não foi possível capturar as coordenadas.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitudeCtrl.text = pos.latitude.toStringAsFixed(6);
        _longitudeCtrl.text = pos.longitude.toStringAsFixed(6);
        _precisaoGpsMetros = pos.accuracy;
        _gpsCapturadoEm = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _erroMensagem = 'Erro ao capturar coordenadas GPS: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _capturandoGps = false);
      }
    }
  }

  Future<void> _salvar() async {
    setState(() {
      _erroMensagem = null;
    });

    if (_descricaoCtrl.text.trim().isEmpty) {
      setState(() {
        _erroMensagem = 'Preencha a descrição do vestígio';
      });
      return;
    }

    if (widget.ambientesDisponiveis.isNotEmpty &&
        _ambienteSelecionado == null) {
      setState(() {
        _erroMensagem = 'Selecione o ambiente relacionado ao vestígio';
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

    if (_usaMarcoZero) {
      if (_coordenadaXCtrl.text.trim().isEmpty ||
          _coordenadaYCtrl.text.trim().isEmpty) {
        setState(() {
          _erroMensagem =
              'Informe as coordenadas X e Y do vestígio em relação ao marco zero.';
        });
        return;
      }
    }

    if (_usaGps) {
      final latitude = double.tryParse(
        _latitudeCtrl.text.trim().replaceAll(',', '.'),
      );
      final longitude = double.tryParse(
        _longitudeCtrl.text.trim().replaceAll(',', '.'),
      );
      if (latitude == null || longitude == null) {
        setState(() {
          _erroMensagem =
              'Capture ou informe coordenadas GPS válidas para este vestígio.';
        });
        return;
      }
    }

    if (!widget.modoRapido &&
        _tipoAcaoSelecionado == TipoAcaoVestigio.coletado) {
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
        id:
            widget.vestigioExistente?.id ??
            VestigioLocalFormScreen.gerarIdVestigio(),
        nome: _nomeCtrl.text.trim().isEmpty ? null : _nomeCtrl.text.trim(),
        descricao: _descricaoCtrl.text.trim(),
        ambiente: _ambienteSelecionado,
        coordenadaX: !_usaMarcoZero || _coordenadaXCtrl.text.trim().isEmpty
            ? null
            : _coordenadaXCtrl.text.trim(),
        coordenadaY: !_usaMarcoZero || _coordenadaYCtrl.text.trim().isEmpty
            ? null
            : _coordenadaYCtrl.text.trim(),
        alturaRelacaoPiso: !_usaMarcoZero || _alturaCtrl.text.trim().isEmpty
            ? null
            : _alturaCtrl.text.trim(),
        latitude: _usaGps
            ? double.tryParse(_latitudeCtrl.text.trim().replaceAll(',', '.'))
            : null,
        longitude: _usaGps
            ? double.tryParse(_longitudeCtrl.text.trim().replaceAll(',', '.'))
            : null,
        precisaoGpsMetros: _usaGps ? _precisaoGpsMetros : null,
        gpsCapturadoEm: _usaGps ? _gpsCapturadoEm : null,
        metodoPosicionamentoOverride: _usarMetodoEspecifico
            ? _metodoOverride
            : null,
        tipoAcao: widget.modoRapido
            ? TipoAcaoVestigio.registrado
            : _tipoAcaoSelecionado,
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

      final continuar =
          widget.manterNaTelaAposSalvarNovo &&
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

  Future<void> _abrirExamesComplementares() async {
    final ficha = await _fichaService.obterFicha(widget.fichaId);
    if (!mounted) return;
    if (ficha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir os exames complementares para esta ficha.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExamesComplementaresScreen(ficha: ficha),
      ),
    );
  }

  void _aplicarDescricaoSangue(String tipoMancha) {
    _descricaoCtrl.text = 'Presença de $tipoMancha.';
    _descricaoCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _descricaoCtrl.text.length),
    );
  }

  void _aplicarDescricaoElementoMunicao() {
    final tipo = _tipoElementoMunicaoSelecionado;
    if (tipo == null || tipo.isEmpty) return;

    String texto;
    if (tipo == 'estojo') {
      if (_calibreSelecionado != null && _calibreSelecionado!.isNotEmpty) {
        texto = 'Estojo de munição calibre ${_calibreSelecionado!}.';
      } else {
        texto = 'Estojo de munição, calibre não identificado.';
      }
    } else {
      texto = '${tipo[0].toUpperCase()}${tipo.substring(1)}.';
    }

    _descricaoCtrl.text = texto;
    _descricaoCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _descricaoCtrl.text.length),
    );
  }

  Future<void> _adicionarOpcaoPersonalizada({
    required String titulo,
    required String label,
    required List<String> destino,
    void Function(String valor)? onAdicionada,
  }) async {
    final ctrl = TextEditingController();
    final valor = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (valor == null || valor.isEmpty) return;
    if (!destino.contains(valor)) {
      setState(() => destino.add(valor));
    }
    if (onAdicionada != null) onAdicionada(valor);
  }

  Widget _buildPosicionamentoSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final coordsGpsFormatadas = CoordinateFormatter.formatPair(
      latitude: CoordinateFormatter.formatLatitude(
        double.tryParse(_latitudeCtrl.text.trim().replaceAll(',', '.')),
      ),
      longitude: CoordinateFormatter.formatLongitude(
        double.tryParse(_longitudeCtrl.text.trim().replaceAll(',', '.')),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Posicionamento do vestígio',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Card(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Método deste escopo: ${widget.metodoPosicionamentoPadrao.label}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (widget.permitirOverrideMetodo) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alterar método somente deste vestígio'),
                    value: _usarMetodoEspecifico,
                    onChanged: (value) {
                      setState(() {
                        _usarMetodoEspecifico = value;
                        if (!value) {
                          _metodoOverride = null;
                        } else {
                          _metodoOverride = widget.metodoPosicionamentoPadrao;
                        }
                      });
                    },
                  ),
                ],
                if (_usarMetodoEspecifico) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<MetodoPosicionamentoVestigio>(
                    initialValue:
                        _metodoOverride ?? widget.metodoPosicionamentoPadrao,
                    decoration: const InputDecoration(
                      labelText: 'Método deste vestígio',
                      border: OutlineInputBorder(),
                    ),
                    items: MetodoPosicionamentoVestigio.values
                        .map(
                          (metodo) => DropdownMenuItem(
                            value: metodo,
                            child: Text(metodo.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _metodoOverride = value);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_metodoPosicionamentoEfetivo == MetodoPosicionamentoVestigio.nenhum)
          Text(
            'Este vestígio será registrado sem posicionamento técnico.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        if (_usaMarcoZero) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _coordenadaXCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Coordenada X *',
                    border: OutlineInputBorder(),
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
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          if (!widget.modoRapido) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _alturaCtrl,
              decoration: const InputDecoration(
                labelText: 'Altura em relação ao piso (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
        if (_usaGps) ...[
          if (widget.avisoContextoGps != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.avisoContextoGps!,
                style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
              ),
            ),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _capturandoGps ? null : _capturarCoordenadasGps,
                icon: const Icon(Icons.my_location),
                label: Text(_capturandoGps ? 'Capturando...' : 'Capturar GPS'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _latitudeCtrl,
            decoration: const InputDecoration(
              labelText: 'Latitude *',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _longitudeCtrl,
            decoration: const InputDecoration(
              labelText: 'Longitude *',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
          ),
          if (coordsGpsFormatadas != null) ...[
            const SizedBox(height: 8),
            Text('Coordenadas formatadas: $coordsGpsFormatadas'),
          ],
          if (_precisaoGpsMetros != null) ...[
            const SizedBox(height: 8),
            Text(
              'Precisão estimada: ${_precisaoGpsMetros!.toStringAsFixed(1)} m',
              style: TextStyle(
                color: _precisaoGpsMetros! > 10
                    ? Colors.orange.shade900
                    : Colors.grey.shade700,
              ),
            ),
            if (_precisaoGpsMetros! > 10)
              Text(
                'Precisão estimada ruim. Recomenda-se cautela na utilização deste posicionamento.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              ),
          ],
        ],
      ],
    );
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
            controller: _descricaoCtrl,
            decoration: InputDecoration(
              labelText: widget.modoRapido
                  ? 'Legenda do vestígio *'
                  : 'Descrição do vestígio *',
              hintText: widget.modoRapido
                  ? 'Ex.: Mancha hemática próxima ao sofá.'
                  : 'Ex.: fragmentos de impressões papilares.',
              border: OutlineInputBorder(),
            ),
            maxLines: null,
            textInputAction: TextInputAction.newline,
          ),
          if (!widget.modoRapido) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do vestígio (opcional)',
                hintText: 'Ex.: EV01: fragmento 01 (ou FGT01)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
          ],
          if (widget.ambientesDisponiveis.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _ambienteSelecionado,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ambiente do vestígio *',
                border: OutlineInputBorder(),
              ),
              items: widget.ambientesDisponiveis
                  .map(
                    (ambiente) => DropdownMenuItem<String>(
                      value: ambiente,
                      child: Text(_capitalize(ambiente)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _ambienteSelecionado = value);
              },
            ),
          ],
          if (!widget.modoRapido) ...[
            const SizedBox(height: 12),
            const Text(
              'Classificação rápida do vestígio',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sangue humano'),
              value: _isSangueHumano,
              onChanged: (value) {
                setState(() {
                  final ativo = value ?? false;
                  _isSangueHumano = ativo;
                  if (ativo) {
                    _isElementoMunicao = false;
                    _tipoElementoMunicaoSelecionado = null;
                    _calibreSelecionado = null;
                  } else {
                    _tipoManchaSangueSelecionada = null;
                  }
                });
              },
            ),
          ],
          if (!widget.modoRapido && _isSangueHumano) ...[
            const SizedBox(height: 4),
            Text(
              'Selecione um tipo de mancha para preencher a descrição e complemente se necessário.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: _opcoesManchaSangue
                  .map(
                    (op) => ChoiceChip(
                      label: Text(op),
                      selected: _tipoManchaSangueSelecionada == op,
                      onSelected: (_) {
                        setState(() {
                          _tipoManchaSangueSelecionada = op;
                          _aplicarDescricaoSangue(op);
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
          if (!widget.modoRapido) ...[
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Elemento de munição'),
              value: _isElementoMunicao,
              onChanged: (value) {
                setState(() {
                  final ativo = value ?? false;
                  _isElementoMunicao = ativo;
                  if (ativo) {
                    _isSangueHumano = false;
                    _tipoManchaSangueSelecionada = null;
                  } else {
                    _tipoElementoMunicaoSelecionado = null;
                    _calibreSelecionado = null;
                  }
                });
              },
            ),
          ],
          if (!widget.modoRapido && _isElementoMunicao) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tipo de elemento',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                IconButton(
                  tooltip: 'Adicionar tipo',
                  icon: const Icon(Icons.add),
                  onPressed: () => _adicionarOpcaoPersonalizada(
                    titulo: 'Novo tipo de elemento',
                    label: 'Tipo',
                    destino: _opcoesElementoMunicao,
                    onAdicionada: (valor) {
                      _tipoElementoMunicaoSelecionado = valor;
                      _calibreSelecionado = null;
                      _aplicarDescricaoElementoMunicao();
                    },
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: _opcoesElementoMunicao
                  .map(
                    (op) => ChoiceChip(
                      label: Text(op),
                      selected: _tipoElementoMunicaoSelecionado == op,
                      onSelected: (_) {
                        setState(() {
                          _tipoElementoMunicaoSelecionado = op;
                          if (op != 'estojo') _calibreSelecionado = null;
                          _aplicarDescricaoElementoMunicao();
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            if (_tipoElementoMunicaoSelecionado == 'estojo') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      // ignore: deprecated_member_use
                      value: _calibreSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Selecionar calibre',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _opcoesCalibre
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _calibreSelecionado = value;
                          _aplicarDescricaoElementoMunicao();
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Adicionar calibre',
                    icon: const Icon(Icons.add),
                    onPressed: () => _adicionarOpcaoPersonalizada(
                      titulo: 'Novo calibre',
                      label: 'Calibre',
                      destino: _opcoesCalibre,
                      onAdicionada: (valor) {
                        _calibreSelecionado = valor;
                        _aplicarDescricaoElementoMunicao();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 12),
          const Text(
            'Fotografias do vestígio *',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          if (widget.modoRapido) ...[
            const SizedBox(height: 4),
            Text(
              'A legenda será usada na lista de vestígios. A numeração da fotografia será preenchida automaticamente no laudo.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final foto = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 75,
                    maxWidth: 2048,
                    maxHeight: 2048,
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
                    imageQuality: 75,
                    maxWidth: 2048,
                    maxHeight: 2048,
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
          _buildPosicionamentoSection(),
          if (!widget.modoRapido) ...[
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
          ],
          if (!widget.modoRapido &&
              _tipoAcaoSelecionado == TipoAcaoVestigio.coletado) ...[
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _abrirExamesComplementares,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Ir para exames complementares'),
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
