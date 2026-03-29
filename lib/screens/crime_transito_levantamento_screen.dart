import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/crime_transito_levantamento_model.dart';
import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import 'lista_veiculos_screen.dart';

class CrimeTransitoLevantamentoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;
  const CrimeTransitoLevantamentoScreen({super.key, required this.ficha});

  @override
  State<CrimeTransitoLevantamentoScreen> createState() =>
      _CrimeTransitoLevantamentoScreenState();
}

class _CrimeTransitoLevantamentoScreenState
    extends State<CrimeTransitoLevantamentoScreen> {
  final _fichaService = FichaService();
  final _imagePicker = ImagePicker();
  bool _salvando = false;

  // --- Dinâmica (derivada das formas de interação) ---
  final _dinamicaOutroCtrl = TextEditingController();
  final _qtdVeiculosCtrl = TextEditingController(text: '1');

  // --- Natureza da ocorrência (incorporada ao levantamento) ---
  CrimeTransitoNaturezaTipo? _tipoOcorrencia;
  final _quantidadeUnidadesCtrl = TextEditingController();
  final Set<CrimeTransitoFormaInteracao> _formasInteracao = {};

  /// Formas de dinâmica principal (UI)
  static const _formasDinamicaPrincipal = [
    CrimeTransitoFormaInteracao.colisaoFrontal,
    CrimeTransitoFormaInteracao.colisaoTraseira,
    CrimeTransitoFormaInteracao.colisaoTransversal,
    CrimeTransitoFormaInteracao.colisaoLateral,
    CrimeTransitoFormaInteracao.abalroamento,
    CrimeTransitoFormaInteracao.choque,
    CrimeTransitoFormaInteracao.atropelamento,
    CrimeTransitoFormaInteracao.saidaPista,
    CrimeTransitoFormaInteracao.outro,
  ];

  /// Deriva DinamicaAcidente a partir das formas selecionadas (para grupos de fotos)
  DinamicaAcidente? get _dinamicaDerivada {
    if (_formasInteracao.contains(CrimeTransitoFormaInteracao.atropelamento)) {
      return DinamicaAcidente.atropelamento;
    }
    if (_formasInteracao.contains(CrimeTransitoFormaInteracao.saidaPista)) {
      return DinamicaAcidente.saidaPista;
    }
    if (_formasInteracao.contains(CrimeTransitoFormaInteracao.choque) ||
        _formasInteracao.contains(CrimeTransitoFormaInteracao.objetoFixo)) {
      return DinamicaAcidente.choqueObjetoFixo;
    }
    if (_formasInteracao.contains(CrimeTransitoFormaInteracao.colisaoFrontal)) {
      return DinamicaAcidente.colisaoFrontal;
    }
    if (_formasInteracao.contains(
      CrimeTransitoFormaInteracao.colisaoTraseira,
    )) {
      return DinamicaAcidente.colisaoTraseira;
    }
    if (_formasInteracao.any(
      (f) => const [
        CrimeTransitoFormaInteracao.colisaoTransversal,
        CrimeTransitoFormaInteracao.colisaoLateral,
        CrimeTransitoFormaInteracao.abalroamento,
      ].contains(f),
    )) {
      return DinamicaAcidente.colisaoTransversalLateral;
    }
    if (_formasInteracao.contains(CrimeTransitoFormaInteracao.outro)) {
      return DinamicaAcidente.outro;
    }
    if (_formasInteracao.isNotEmpty) {
      return DinamicaAcidente.outro;
    }
    return null;
  }

  bool? _materialRecolhido;
  final _materialDescricaoCtrl = TextEditingController();
  bool? _solicitacaoExames;
  final _laboratorioCtrl = TextEditingController();
  final _examesDinamicaCtrl = TextEditingController();

  // --- Marco Zero ---
  final _marcoZeroDescricaoCtrl = TextEditingController();
  final _marcoZeroLatCtrl = TextEditingController();
  final _marcoZeroLngCtrl = TextEditingController();
  List<String> _marcoZeroFotos = [];

  // --- Fotos Local Encontrado ---
  List<FotoLegendaModel> _fotosLocalEncontrado = [];
  final _legendaLocalEncontradoCtrl = TextEditingController();

  // --- Fotos Contextuais (geradas por tipo de acidente) ---
  final Map<String, List<FotoLegendaModel>> _fotosContextuais = {};
  final Map<String, TextEditingController> _legendasContextuais = {};

  // --- Sinalização ---
  List<FotoLegendaModel> _fotosSinalizacao = [];
  final _legendaSinalizacaoCtrl = TextEditingController();

  // --- Vestígios ---
  List<VestigioViaModel> _vestigios = [];

  // --- Fotos Complementares ---
  List<FotoLegendaModel> _fotosComplementares = [];
  final _legendaComplementaresCtrl = TextEditingController();

  int get _qtdVeiculos => int.tryParse(_qtdVeiculosCtrl.text) ?? 1;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.crimeTransitoLevantamento;
    final natureza = widget.ficha.crimeTransitoNatureza;

    if (dados != null) {
      _dinamicaOutroCtrl.text = dados.dinamicaOutroDescricao ?? '';
      _qtdVeiculosCtrl.text = (dados.quantidadeVeiculos ?? 1).toString();
      _tipoOcorrencia = dados.tipoOcorrencia;
      _quantidadeUnidadesCtrl.text =
          (dados.quantidadeUnidades ?? dados.quantidadeVeiculos ?? '')
              .toString();
      _formasInteracao.addAll(dados.formasInteracao ?? []);
      _materialRecolhido = dados.materialRecolhido;
      _materialDescricaoCtrl.text = dados.materialDescricao ?? '';
      _solicitacaoExames = dados.solicitacaoExamesComplementares;
      _laboratorioCtrl.text = dados.laboratorioDestino ?? '';
      _examesDinamicaCtrl.text = dados.examesDinamica ?? '';
    }
    // Migração: se levantamento não tinha natureza, preencher a partir da tela antiga
    if (natureza != null && (dados == null || dados.tipoOcorrencia == null)) {
      _tipoOcorrencia ??= natureza.tipo;
      if (_quantidadeUnidadesCtrl.text.trim().isEmpty) {
        _quantidadeUnidadesCtrl.text = (natureza.quantidadeUnidades ?? '')
            .toString();
      }
      _formasInteracao.addAll(natureza.formasInteracao ?? []);
      _materialRecolhido ??= natureza.materialRecolhido;
      if (_materialDescricaoCtrl.text.trim().isEmpty) {
        _materialDescricaoCtrl.text = natureza.materialDescricao ?? '';
      }
      _solicitacaoExames ??= natureza.solicitacaoExamesComplementares;
      if (_laboratorioCtrl.text.trim().isEmpty) {
        _laboratorioCtrl.text = natureza.laboratorioDestino ?? '';
      }
      if (_examesDinamicaCtrl.text.trim().isEmpty) {
        _examesDinamicaCtrl.text = natureza.examesDinamica ?? '';
      }
    }
    if (dados == null) return;

    if (dados.marcoZero != null) {
      _marcoZeroDescricaoCtrl.text = dados.marcoZero!.descricao ?? '';
      _marcoZeroLatCtrl.text = dados.marcoZero!.latitude ?? '';
      _marcoZeroLngCtrl.text = dados.marcoZero!.longitude ?? '';
      _marcoZeroFotos = List<String>.from(dados.marcoZero!.fotos)
        ..removeWhere((p) => !File(p).existsSync());
    }

    if (dados.fotosLocalEncontrado != null) {
      _fotosLocalEncontrado = List<FotoLegendaModel>.from(
        dados.fotosLocalEncontrado!.fotos,
      );
      _legendaLocalEncontradoCtrl.text =
          dados.fotosLocalEncontrado!.legendaGrupo;
    }

    for (final grupo in dados.fotosContextuais) {
      _fotosContextuais[grupo.categoria] = List<FotoLegendaModel>.from(
        grupo.fotos,
      );
      _legendasContextuais[grupo.categoria] = TextEditingController(
        text: grupo.legendaGrupo,
      );
    }

    if (dados.fotosSinalizacao != null) {
      _fotosSinalizacao = List<FotoLegendaModel>.from(
        dados.fotosSinalizacao!.fotos,
      );
      _legendaSinalizacaoCtrl.text = dados.fotosSinalizacao!.legendaGrupo;
    }

    _vestigios = List<VestigioViaModel>.from(dados.vestigios);

    if (dados.fotosComplementares != null) {
      _fotosComplementares = List<FotoLegendaModel>.from(
        dados.fotosComplementares!.fotos,
      );
      _legendaComplementaresCtrl.text = dados.fotosComplementares!.legendaGrupo;
    }
  }

  @override
  void dispose() {
    _dinamicaOutroCtrl.dispose();
    _qtdVeiculosCtrl.dispose();
    _quantidadeUnidadesCtrl.dispose();
    _materialDescricaoCtrl.dispose();
    _laboratorioCtrl.dispose();
    _examesDinamicaCtrl.dispose();
    _marcoZeroDescricaoCtrl.dispose();
    _marcoZeroLatCtrl.dispose();
    _marcoZeroLngCtrl.dispose();
    _legendaLocalEncontradoCtrl.dispose();
    _legendaSinalizacaoCtrl.dispose();
    _legendaComplementaresCtrl.dispose();
    for (final c in _legendasContextuais.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _categoriasContextuais() {
    final qtd = _qtdVeiculos;
    switch (_dinamicaDerivada) {
      case DinamicaAcidente.colisaoFrontal:
      case DinamicaAcidente.colisaoTraseira:
      case DinamicaAcidente.colisaoTransversalLateral:
        return [
          for (int i = 1; i <= qtd; i++) 'Ponto de vista do condutor $i',
          'Sítio de colisão',
          for (int i = 1; i <= qtd; i++) 'Trajeto do veículo $i após embate',
        ];
      case DinamicaAcidente.atropelamento:
        return [
          for (int i = 1; i <= qtd; i++) 'Ponto de vista do condutor $i',
          'Ponto de vista do pedestre',
          'Local do atropelamento',
          'Posição da vítima / pertences',
        ];
      case DinamicaAcidente.saidaPista:
        return [
          for (int i = 1; i <= qtd; i++) 'Ponto de vista do condutor $i',
          'Ponto de saída da via',
          for (int i = 1; i <= qtd; i++) 'Trajeto do veículo $i fora da pista',
        ];
      case DinamicaAcidente.choqueObjetoFixo:
        return [
          for (int i = 1; i <= qtd; i++) 'Ponto de vista do condutor $i',
          'Objeto fixo atingido',
          for (int i = 1; i <= qtd; i++) 'Veículo $i junto ao objeto',
          'Marcas de aproximação',
        ];
      case DinamicaAcidente.outro:
        return [
          for (int i = 1; i <= qtd; i++) 'Ponto de vista do condutor $i',
          'Fotos da dinâmica',
        ];
      case null:
        return [];
    }
  }

  void _toggleForma(CrimeTransitoFormaInteracao forma) {
    setState(() {
      if (_formasInteracao.contains(forma)) {
        _formasInteracao.remove(forma);
      } else {
        _formasInteracao.add(forma);
      }
    });
  }

  TextEditingController _getCtrlContextual(String cat) {
    return _legendasContextuais.putIfAbsent(cat, () => TextEditingController());
  }

  List<FotoLegendaModel> _getFotosContextuais(String cat) {
    return _fotosContextuais.putIfAbsent(cat, () => []);
  }

  Future<String?> _persistirFoto(XFile foto, String subpasta) async {
    final dir = await getApplicationDocumentsDirectory();
    final pasta = Directory(
      '${dir.path}/levantamento_transito/${widget.ficha.id}/$subpasta',
    );
    if (!await pasta.exists()) await pasta.create(recursive: true);
    final nome = 'foto_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final destino = File('${pasta.path}/$nome');
    await File(foto.path).copy(destino.path);
    return destino.path;
  }

  Future<void> _obterGPS() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('GPS desativado')));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _marcoZeroLatCtrl.text = pos.latitude.toStringAsFixed(6);
        _marcoZeroLngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível obter a localização')),
        );
      }
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);

    final contextuais = <GrupoFotosModel>[];
    for (final cat in _categoriasContextuais()) {
      final fotos = _getFotosContextuais(cat);
      final ctrl = _getCtrlContextual(cat);
      if (fotos.isNotEmpty || ctrl.text.trim().isNotEmpty) {
        contextuais.add(
          GrupoFotosModel(
            categoria: cat,
            legendaGrupo: ctrl.text.trim(),
            fotos: fotos,
          ),
        );
      }
    }

    final levantamento = CrimeTransitoLevantamentoModel(
      dinamica: _dinamicaDerivada,
      dinamicaOutroDescricao: _dinamicaOutroCtrl.text.trim().isEmpty
          ? null
          : _dinamicaOutroCtrl.text.trim(),
      quantidadeVeiculos: _qtdVeiculos,
      tipoOcorrencia: _tipoOcorrencia,
      quantidadeUnidades: int.tryParse(_quantidadeUnidadesCtrl.text.trim()),
      formasInteracao: _formasInteracao.isEmpty
          ? null
          : _formasInteracao.toList(),
      materialRecolhido: _materialRecolhido,
      materialDescricao: _materialDescricaoCtrl.text.trim().isEmpty
          ? null
          : _materialDescricaoCtrl.text.trim(),
      solicitacaoExamesComplementares: _solicitacaoExames,
      laboratorioDestino: _laboratorioCtrl.text.trim().isEmpty
          ? null
          : _laboratorioCtrl.text.trim(),
      examesDinamica: _examesDinamicaCtrl.text.trim().isEmpty
          ? null
          : _examesDinamicaCtrl.text.trim(),
      croquiObservacoes: null,
      marcoZero:
          (_marcoZeroDescricaoCtrl.text.trim().isEmpty &&
              _marcoZeroLatCtrl.text.trim().isEmpty &&
              _marcoZeroFotos.isEmpty)
          ? null
          : MarcoZeroTransitoModel(
              descricao: _marcoZeroDescricaoCtrl.text.trim().isEmpty
                  ? null
                  : _marcoZeroDescricaoCtrl.text.trim(),
              latitude: _marcoZeroLatCtrl.text.trim().isEmpty
                  ? null
                  : _marcoZeroLatCtrl.text.trim(),
              longitude: _marcoZeroLngCtrl.text.trim().isEmpty
                  ? null
                  : _marcoZeroLngCtrl.text.trim(),
              fotos: _marcoZeroFotos,
            ),
      fotosLocalEncontrado: _fotosLocalEncontrado.isEmpty
          ? null
          : GrupoFotosModel(
              categoria: 'local_encontrado',
              legendaGrupo: _legendaLocalEncontradoCtrl.text.trim(),
              fotos: _fotosLocalEncontrado,
            ),
      fotosContextuais: contextuais,
      fotosSinalizacao: _fotosSinalizacao.isEmpty
          ? null
          : GrupoFotosModel(
              categoria: 'sinalizacao',
              legendaGrupo: _legendaSinalizacaoCtrl.text.trim(),
              fotos: _fotosSinalizacao,
            ),
      vestigios: _vestigios,
      fotosComplementares: _fotosComplementares.isEmpty
          ? null
          : GrupoFotosModel(
              categoria: 'complementares',
              legendaGrupo: _legendaComplementaresCtrl.text.trim(),
              fotos: _fotosComplementares,
            ),
    );

    // Manter crimeTransitoNatureza em sincronia para laudo/Word
    final natureza = CrimeTransitoNaturezaModel(
      tipo: _tipoOcorrencia,
      quantidadeUnidades: int.tryParse(_quantidadeUnidadesCtrl.text.trim()),
      formasInteracao: _formasInteracao.isEmpty
          ? null
          : _formasInteracao.toList(),
      materialRecolhido: _materialRecolhido,
      materialDescricao: _materialDescricaoCtrl.text.trim().isEmpty
          ? null
          : _materialDescricaoCtrl.text.trim(),
      solicitacaoExamesComplementares: _solicitacaoExames,
      laboratorioDestino: _laboratorioCtrl.text.trim().isEmpty
          ? null
          : _laboratorioCtrl.text.trim(),
      examesDinamica: _examesDinamicaCtrl.text.trim().isEmpty
          ? null
          : _examesDinamicaCtrl.text.trim(),
      croquiObservacoes: null,
    );

    final fichaAtualizada = widget.ficha.copyWith(
      crimeTransitoLevantamento: levantamento,
      crimeTransitoNatureza: natureza,
      dataUltimaAtualizacao: DateTime.now(),
    );

    await _fichaService.salvarFicha(fichaAtualizada);

    if (!mounted) return;
    setState(() => _salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Levantamento salvo com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ListaVeiculosScreen(ficha: fichaAtualizada),
      ),
    );
    if (mounted && resultado == true) {
      Navigator.of(context).pop(true);
    }
  }

  // ─── Widgets auxiliares ────────────────────────────────────────

  Widget _buildSectionTitle(String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoBox(String texto) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(texto, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildGrupoFotos({
    required String titulo,
    required List<FotoLegendaModel> fotos,
    required TextEditingController legendaCtrl,
    required String subpasta,
    required void Function(List<FotoLegendaModel>) onChanged,
    bool obrigatoria = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (obrigatoria)
                  Text(
                    ' *',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: legendaCtrl,
              decoration: const InputDecoration(
                labelText: 'Legenda do grupo',
                isDense: true,
              ),
              maxLines: 2,
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
                    final path = await _persistirFoto(foto, subpasta);
                    if (path != null) {
                      setState(() {
                        fotos.add(FotoLegendaModel(path: path));
                        onChanged(fotos);
                      });
                    }
                  },
                  icon: const Icon(Icons.photo_camera, size: 18),
                  label: const Text('Câmera'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final imgs = await _imagePicker.pickMultiImage(
                      imageQuality: 90,
                    );
                    if (imgs.isEmpty || !mounted) return;
                    for (final img in imgs) {
                      final path = await _persistirFoto(img, subpasta);
                      if (path != null) {
                        fotos.add(FotoLegendaModel(path: path));
                      }
                    }
                    setState(() => onChanged(fotos));
                  },
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Galeria'),
                ),
              ],
            ),
            if (fotos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  obrigatoria
                      ? 'Nenhuma foto. Adicione ao menos uma.'
                      : 'Nenhuma foto.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: fotos.asMap().entries.map((e) {
                    final file = File(e.value.path);
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: file.existsSync()
                              ? Image.file(
                                  file,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _brokenThumb(),
                                )
                              : _brokenThumb(),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                fotos.removeAt(e.key);
                                onChanged(fotos);
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _brokenThumb() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.broken_image, color: Colors.white54),
    );
  }

  String _labelFormaInteracao(CrimeTransitoFormaInteracao f) => switch (f) {
    CrimeTransitoFormaInteracao.saidaPista => 'Saída de pista',
    CrimeTransitoFormaInteracao.colisao => 'Colisão',
    CrimeTransitoFormaInteracao.colisaoFrontal => 'Colisão frontal',
    CrimeTransitoFormaInteracao.colisaoOposta => 'Colisão oposta',
    CrimeTransitoFormaInteracao.objetoFixo => 'Objeto fixo',
    CrimeTransitoFormaInteracao.capotamento => 'Capotamento',
    CrimeTransitoFormaInteracao.abalroamento => 'Abalroamento',
    CrimeTransitoFormaInteracao.colisaoTraseira => 'Colisão traseira',
    CrimeTransitoFormaInteracao.colisaoTransversal => 'Colisão transversal',
    CrimeTransitoFormaInteracao.veiculoEstacionado => 'Veículo estacionado',
    CrimeTransitoFormaInteracao.tombamento => 'Tombamento',
    CrimeTransitoFormaInteracao.choque => 'Choque',
    CrimeTransitoFormaInteracao.colisaoLateral => 'Colisão lateral',
    CrimeTransitoFormaInteracao.colisaoObliqua => 'Colisão oblíqua',
    CrimeTransitoFormaInteracao.veiculoParado => 'Veículo parado',
    CrimeTransitoFormaInteracao.colisaoLongitudinal => 'Colisão longitudinal',
    CrimeTransitoFormaInteracao.colisaoOrtogonal => 'Colisão ortogonal',
    CrimeTransitoFormaInteracao.pedestre => 'Pedestre',
    CrimeTransitoFormaInteracao.queda => 'Queda',
    CrimeTransitoFormaInteracao.atropelamento => 'Atropelamento',
    CrimeTransitoFormaInteracao.animal => 'Animal',
    CrimeTransitoFormaInteracao.outro => 'Outro',
  };

  String _labelTipoVestigio(TipoVestigioVia t) => switch (t) {
    TipoVestigioVia.marcaFrenagem => 'Marca de frenagem',
    TipoVestigioVia.marcaDerrapagem => 'Marca de derrapagem',
    TipoVestigioVia.sulcagem => 'Sulcagem',
    TipoVestigioVia.raspagem => 'Raspagem',
    TipoVestigioVia.arraste => 'Arraste',
    TipoVestigioVia.liquidos => 'Líquidos',
    TipoVestigioVia.fragmentos => 'Fragmentos',
    TipoVestigioVia.outro => 'Outro',
  };

  String _labelPosicao(PosicaoRelativaVestigio p) => switch (p) {
    PosicaoRelativaVestigio.antes => 'Antes do sítio',
    PosicaoRelativaVestigio.apos => 'Após o sítio',
    PosicaoRelativaVestigio.noSitio => 'No sítio',
    PosicaoRelativaVestigio.naoSeAplica => 'N/A',
  };

  Future<void> _adicionarVestigio() async {
    final resultado = await showModalBottomSheet<VestigioViaModel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VestigioBottomSheet(
        fichaId: widget.ficha.id,
        qtdVeiculos: _qtdVeiculos,
        imagePicker: _imagePicker,
      ),
    );
    if (resultado != null) {
      setState(() => _vestigios.add(resultado));
    }
  }

  Future<void> _editarVestigio(int index) async {
    final resultado = await showModalBottomSheet<VestigioViaModel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VestigioBottomSheet(
        fichaId: widget.ficha.id,
        qtdVeiculos: _qtdVeiculos,
        imagePicker: _imagePicker,
        vestigioExistente: _vestigios[index],
      ),
    );
    if (resultado != null) {
      setState(() => _vestigios[index] = resultado);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final categorias = _categoriasContextuais();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Levantamento - Via'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Resumo do caso'),
            _buildInfoBox(
              'Selecione a dinâmica principal do acidente. Depois siga para o levantamento.',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _qtdVeiculosCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de veículos',
                        hintText: 'Ex: 2',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CrimeTransitoNaturezaTipo>(
                      initialValue: _tipoOcorrencia,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Natureza da ocorrência',
                        border: OutlineInputBorder(),
                      ),
                      items: CrimeTransitoNaturezaTipo.values
                          .map(
                            (tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(
                                tipo == CrimeTransitoNaturezaTipo.simples
                                    ? 'Simples (1 unidade)'
                                    : 'Composta (2 ou mais unidades)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _tipoOcorrencia = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _quantidadeUnidadesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de unidades envolvidas',
                        hintText:
                            'Inclua pedestre, animal ou objeto, se houver',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dinâmica principal',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _formasDinamicaPrincipal.map((forma) {
                        return FilterChip(
                          label: Text(_labelFormaInteracao(forma)),
                          selected: _formasInteracao.contains(forma),
                          onSelected: (_) => _toggleForma(forma),
                        );
                      }).toList(),
                    ),
                    if (_formasInteracao.contains(
                      CrimeTransitoFormaInteracao.outro,
                    )) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dinamicaOutroCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Descreva a dinâmica',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── 1. Marco Zero ──
            _buildSectionTitle('1. Marco Zero'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Defina o ponto de referência para as medidas. '
                      'As medidas são imprescindíveis para o laudo.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _marcoZeroDescricaoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descrição do ponto de referência',
                        hintText: 'Ex: Poste nº 15 da rede elétrica',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _marcoZeroLatCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude (graus decimais)',
                              hintText: 'Ex.: -23.550519',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _marcoZeroLngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude (graus decimais)',
                              hintText: 'Ex.: -46.633309',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _obterGPS,
                          icon: const Icon(Icons.my_location),
                          tooltip: 'Obter GPS',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final foto = await _imagePicker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 90,
                            );
                            if (foto == null || !mounted) return;
                            final path = await _persistirFoto(
                              foto,
                              'marco_zero',
                            );
                            if (path != null) {
                              setState(() => _marcoZeroFotos.add(path));
                            }
                          },
                          icon: const Icon(Icons.photo_camera, size: 18),
                          label: const Text('Foto do marco zero'),
                        ),
                      ],
                    ),
                    if (_marcoZeroFotos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _marcoZeroFotos.asMap().entries.map((e) {
                          final file = File(e.value);
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: file.existsSync()
                                    ? Image.file(
                                        file,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _brokenThumb(),
                                      )
                                    : _brokenThumb(),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _marcoZeroFotos.removeAt(e.key),
                                  ),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── 2. Local como encontrado ──
            _buildSectionTitle('2. Local como encontrado'),
            _buildGrupoFotos(
              titulo: 'Local como encontrado pela equipe pericial',
              fotos: _fotosLocalEncontrado,
              legendaCtrl: _legendaLocalEncontradoCtrl,
              subpasta: 'local_encontrado',
              obrigatoria: true,
              onChanged: (v) => _fotosLocalEncontrado = v,
            ),

            // ── 3. Fotos por tipo de acidente ──
            if (categorias.isNotEmpty) ...[
              _buildSectionTitle('3. Fotos da dinâmica'),
              ...categorias.map((cat) {
                final subpasta = cat.toLowerCase().replaceAll(
                  RegExp(r'[^a-z0-9]+'),
                  '_',
                );
                return _buildGrupoFotos(
                  titulo: cat,
                  fotos: _getFotosContextuais(cat),
                  legendaCtrl: _getCtrlContextual(cat),
                  subpasta: subpasta,
                  onChanged: (v) => _fotosContextuais[cat] = v,
                );
              }),
            ] else ...[
              _buildSectionTitle('3. Fotos da dinâmica'),
              _buildInfoBox(
                'Selecione o tipo de dinâmica do acidente no resumo do caso para liberar automaticamente os grupos de fotos contextuais.',
              ),
            ],

            // ── 4. Sinalização ──
            _buildSectionTitle('4. Sinalização'),
            _buildGrupoFotos(
              titulo: 'Fotos da sinalização presente',
              fotos: _fotosSinalizacao,
              legendaCtrl: _legendaSinalizacaoCtrl,
              subpasta: 'sinalizacao',
              onChanged: (v) => _fotosSinalizacao = v,
            ),

            // ── 5. Vestígios na Via ──
            _buildSectionTitle('5. Vestígios na Via'),
            if (_vestigios.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nenhum vestígio adicionado.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._vestigios.asMap().entries.map((e) {
                final v = e.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.pin_drop),
                    title: Text(_labelTipoVestigio(v.tipo)),
                    subtitle: Text(
                      [
                        if (v.condutorAssociado != null) v.condutorAssociado!,
                        if (v.medidaMetros != null &&
                            v.medidaMetros!.isNotEmpty)
                          '${v.medidaMetros} m',
                        if (v.posicao != null) _labelPosicao(v.posicao!),
                        '${v.fotos.length} foto(s)',
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _editarVestigio(e.key),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () =>
                              setState(() => _vestigios.removeAt(e.key)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _adicionarVestigio,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar vestígio'),
            ),

            // ── 6. Fotos Complementares ──
            _buildSectionTitle('6. Fotos complementares'),
            _buildGrupoFotos(
              titulo: 'Outras fotos relevantes',
              fotos: _fotosComplementares,
              legendaCtrl: _legendaComplementaresCtrl,
              subpasta: 'complementares',
              onChanged: (v) => _fotosComplementares = v,
            ),

            // ── Complementos do caso (final da tela) ──
            _buildSectionTitle('Complementos do caso'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preencha somente quando houver coleta, solicitação complementar ou observação relevante.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<bool?>(
                      initialValue: _materialRecolhido,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Houve material recolhido?',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Não informado'),
                        ),
                        DropdownMenuItem(value: true, child: Text('Sim')),
                        DropdownMenuItem(value: false, child: Text('Não')),
                      ],
                      onChanged: (v) => setState(() => _materialRecolhido = v),
                    ),
                    if (_materialRecolhido == true) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _materialDescricaoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Material recolhido (descrição)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<bool?>(
                      initialValue: _solicitacaoExames,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Solicitou exames complementares?',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Não informado'),
                        ),
                        DropdownMenuItem(value: true, child: Text('Sim')),
                        DropdownMenuItem(value: false, child: Text('Não')),
                      ],
                      onChanged: (v) => setState(() => _solicitacaoExames = v),
                    ),
                    if (_solicitacaoExames == true) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _laboratorioCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Laboratório/Seção',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _examesDinamicaCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Exames/Dinâmica',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Salvar ──
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_salvando ? 'Salvando...' : 'Salvar e continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Sheet para adicionar/editar vestígio ─────────────────

class _VestigioBottomSheet extends StatefulWidget {
  final String fichaId;
  final int qtdVeiculos;
  final ImagePicker imagePicker;
  final VestigioViaModel? vestigioExistente;

  const _VestigioBottomSheet({
    required this.fichaId,
    required this.qtdVeiculos,
    required this.imagePicker,
    this.vestigioExistente,
  });

  @override
  State<_VestigioBottomSheet> createState() => _VestigioBottomSheetState();
}

class _VestigioBottomSheetState extends State<_VestigioBottomSheet> {
  TipoVestigioVia _tipo = TipoVestigioVia.marcaFrenagem;
  final _tipoOutroCtrl = TextEditingController();
  String? _condutorAssociado;
  PosicaoRelativaVestigio? _posicao;
  final _medidaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  List<FotoLegendaModel> _fotos = [];

  @override
  void initState() {
    super.initState();
    final v = widget.vestigioExistente;
    if (v != null) {
      _tipo = v.tipo;
      _tipoOutroCtrl.text = v.tipoOutroDescricao ?? '';
      _condutorAssociado = v.condutorAssociado;
      _posicao = v.posicao;
      _medidaCtrl.text = v.medidaMetros ?? '';
      _obsCtrl.text = v.observacao ?? '';
      _fotos = List<FotoLegendaModel>.from(v.fotos);
    }
  }

  @override
  void dispose() {
    _tipoOutroCtrl.dispose();
    _medidaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<String?> _persistirFoto(XFile foto) async {
    final dir = await getApplicationDocumentsDirectory();
    final pasta = Directory(
      '${dir.path}/levantamento_transito/${widget.fichaId}/vestigios',
    );
    if (!await pasta.exists()) await pasta.create(recursive: true);
    final nome = 'foto_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final destino = File('${pasta.path}/$nome');
    await File(foto.path).copy(destino.path);
    return destino.path;
  }

  void _salvar() {
    final vestigio = VestigioViaModel(
      id:
          widget.vestigioExistente?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: _tipo,
      tipoOutroDescricao: _tipo == TipoVestigioVia.outro
          ? (_tipoOutroCtrl.text.trim().isEmpty
                ? null
                : _tipoOutroCtrl.text.trim())
          : null,
      condutorAssociado: _condutorAssociado,
      posicao: _posicao,
      medidaMetros: _medidaCtrl.text.trim().isEmpty
          ? null
          : _medidaCtrl.text.trim(),
      fotos: _fotos,
      observacao: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
    );
    Navigator.of(context).pop(vestigio);
  }

  String _labelTipo(TipoVestigioVia t) => switch (t) {
    TipoVestigioVia.marcaFrenagem => 'Marca de frenagem',
    TipoVestigioVia.marcaDerrapagem => 'Marca de derrapagem',
    TipoVestigioVia.sulcagem => 'Sulcagem',
    TipoVestigioVia.raspagem => 'Raspagem',
    TipoVestigioVia.arraste => 'Arraste',
    TipoVestigioVia.liquidos => 'Líquidos',
    TipoVestigioVia.fragmentos => 'Fragmentos',
    TipoVestigioVia.outro => 'Outro',
  };

  @override
  Widget build(BuildContext context) {
    final condutores = [
      'Não identificado',
      for (int i = 1; i <= widget.qtdVeiculos; i++) 'Condutor $i',
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.vestigioExistente != null
                          ? 'Editar vestígio'
                          : 'Novo vestígio',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              DropdownButtonFormField<TipoVestigioVia>(
                isExpanded: true,
                initialValue: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de vestígio',
                ),
                items: TipoVestigioVia.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(_labelTipo(t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v!),
              ),

              if (_tipo == TipoVestigioVia.outro) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _tipoOutroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descreva o vestígio',
                  ),
                ),
              ],

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _condutorAssociado,
                decoration: const InputDecoration(
                  labelText: 'Condutor associado',
                ),
                hint: const Text('Selecione'),
                items: condutores
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _condutorAssociado = v),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<PosicaoRelativaVestigio>(
                isExpanded: true,
                initialValue: _posicao,
                decoration: const InputDecoration(
                  labelText: 'Posição relativa ao sítio',
                ),
                hint: const Text('Selecione'),
                items: PosicaoRelativaVestigio.values
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(switch (p) {
                          PosicaoRelativaVestigio.antes => 'Antes do sítio',
                          PosicaoRelativaVestigio.apos => 'Após o sítio',
                          PosicaoRelativaVestigio.noSitio => 'No sítio',
                          PosicaoRelativaVestigio.naoSeAplica => 'N/A',
                        }),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _posicao = v),
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _medidaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Medida (metros)',
                  hintText: 'Informe a medida, se possível',
                  suffixText: 'm',
                ),
              ),

              const SizedBox(height: 16),
              TextField(
                controller: _obsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observação / legenda',
                ),
              ),

              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final foto = await widget.imagePicker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 90,
                      );
                      if (foto == null || !mounted) return;
                      final path = await _persistirFoto(foto);
                      if (path != null) {
                        setState(
                          () => _fotos.add(FotoLegendaModel(path: path)),
                        );
                      }
                    },
                    icon: const Icon(Icons.photo_camera, size: 18),
                    label: const Text('Câmera'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final imgs = await widget.imagePicker.pickMultiImage(
                        imageQuality: 90,
                      );
                      if (imgs.isEmpty || !mounted) return;
                      for (final img in imgs) {
                        final path = await _persistirFoto(img);
                        if (path != null) {
                          _fotos.add(FotoLegendaModel(path: path));
                        }
                      }
                      setState(() {});
                    },
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Galeria'),
                  ),
                ],
              ),
              if (_fotos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _fotos.asMap().entries.map((e) {
                    final file = File(e.value.path);
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: file.existsSync()
                              ? Image.file(
                                  file,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 64,
                                    height: 64,
                                    color: Colors.grey.shade800,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.white54,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey.shade800,
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _fotos.removeAt(e.key)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(3),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Nenhuma foto do vestígio.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _salvar,
                  child: const Text('Salvar vestígio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
