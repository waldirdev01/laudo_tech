import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import 'crime_transito_levantamento_screen.dart';

enum _ViaCTB {
  urbanaTransitoRapido,
  urbanaArterial,
  urbanaColetora,
  urbanaLocal,
  ruralRodovia,
  ruralEstrada,
}

/// Categorias do art. 61, §1º, CTB (vias rurais – rodovias).
enum _CategoriaVeiculoCTB {
  automoveisMotos,   // 110 km/h pista dupla, 100 km/h pista simples
  onibusMicroonibus, // 90 km/h
  caminhoes,         // 80 km/h
}

class CrimeTransitoCondicoesScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const CrimeTransitoCondicoesScreen({super.key, required this.ficha});

  @override
  State<CrimeTransitoCondicoesScreen> createState() =>
      _CrimeTransitoCondicoesScreenState();
}

class _CrimeTransitoCondicoesScreenState
    extends State<CrimeTransitoCondicoesScreen> {
  final _fichaService = FichaService();
  final _larguraPistaCtrl = TextEditingController();
  final _intensidadePerfilCtrl = TextEditingController();
  final _condicaoOutroCtrl = TextEditingController();
  final _velocidadeMaxCtrl = TextEditingController();
  final _numeroFaixasCtrl = TextEditingController();
  final _largurasFaixasCtrl = TextEditingController();
  final _visibilidadeDescricaoCtrl = TextEditingController();
  final _sinalizacaoObsCtrl = TextEditingController();
  final _regimeOutroCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  final _lateralDirLarguraCtrl = TextEditingController();
  final _lateralDirObsCtrl = TextEditingController();
  final _lateralEsqLarguraCtrl = TextEditingController();
  final _lateralEsqObsCtrl = TextEditingController();

  final Set<CondicaoSoloLocal> _soloSelecionado = {};
  final Set<IluminacaoLocal> _iluminacaoSelecionada = {};
  final Set<TracadoPista> _tracadoSelecionado = {};
  final Set<TipoPistaRodovia> _tipoPistaSelecionado = {};
  final Set<SentidoPista> _sentidoSelecionado = {};

  /// Perfil da via: direção (apenas uma) — plano, aclive ou declive.
  PerfilPista? _perfilDirecao;

  /// Intensidade do aclive/declive (opcional, apenas uma quando há aclive ou declive).
  PerfilPista? _perfilIntensidade;
  final Set<CondicaoViaOpcao> _condicoesViaSelecionadas = {};
  final Set<SinalizacaoTipo> _sinalizacaoTipos = {};
  final Set<SinalizacaoSituacao> _sinalizacaoSituacoes = {};
  final Set<SeparacaoFaixasOpcao> _separacaoFaixas = {};
  final Set<CorFaixa> _corFaixas = {};
  final Set<SeparacaoPistasOpcao> _separacaoPistas = {};
  final Set<ElementoLateral> _lateralDirElementos = {};
  final Set<ElementoLateral> _lateralEsqElementos = {};

  RegimeTrafego? _regime;
  VisibilidadeTipo? _visibilidade;
  ConservacaoEstado? _lateralDirConservacao;
  ConservacaoEstado? _lateralEsqConservacao;
  bool _velocidadePorSinalizacao = false;
  bool _velocidadePorCTB = false;

  /// Valor selecionado no dropdown quando "Velocidade conforme CTB" está marcado (ex: "60").
  String? _velocidadeCTBSelecionada;
  _ViaCTB? _viaCTBSelecionada;
  TipoPistaRodovia? _tipoPistaRodoviaCTB;
  _CategoriaVeiculoCTB? _categoriaVeiculoCTB;
  bool _salvando = false;

  static const List<Map<String, String>> _viasCTB = [
    {'value': 'urbanaTransitoRapido', 'label': 'Via urbana de trânsito rápido'},
    {'value': 'urbanaArterial', 'label': 'Via urbana arterial'},
    {'value': 'urbanaColetora', 'label': 'Via urbana coletora'},
    {'value': 'urbanaLocal', 'label': 'Via urbana local'},
    {'value': 'ruralRodovia', 'label': 'Via rural - rodovia'},
    {'value': 'ruralEstrada', 'label': 'Via rural - estrada (não pavimentada)'},
  ];

  List<Map<String, String>> _opcoesVelocidadeCTBFiltradas() {
    switch (_viaCTBSelecionada) {
      case _ViaCTB.urbanaTransitoRapido:
        return const [
          {'value': '80', 'label': '80 km/h - Via urbana de trânsito rápido'},
        ];
      case _ViaCTB.urbanaArterial:
        return const [
          {'value': '60', 'label': '60 km/h - Via urbana arterial'},
        ];
      case _ViaCTB.urbanaColetora:
        return const [
          {'value': '40', 'label': '40 km/h - Via urbana coletora'},
        ];
      case _ViaCTB.urbanaLocal:
        return const [
          {'value': '30', 'label': '30 km/h - Via urbana local'},
        ];
      case _ViaCTB.ruralEstrada:
        return const [
          {'value': '60', 'label': '60 km/h - Estrada (via rural)'},
        ];
      case _ViaCTB.ruralRodovia:
        if (_tipoPistaRodoviaCTB == null || _categoriaVeiculoCTB == null) {
          return const [];
        }
        // Art. 61, §1º, CTB: rodovia pista dupla → 110, 90, 80; pista simples → 100, 90, 80
        if (_categoriaVeiculoCTB == _CategoriaVeiculoCTB.automoveisMotos) {
          return _tipoPistaRodoviaCTB == TipoPistaRodovia.dupla
              ? const [
                  {
                    'value': '110',
                    'label':
                        '110 km/h - Rodovia pista dupla (automóveis e motos)',
                  },
                ]
              : const [
                  {
                    'value': '100',
                    'label':
                        '100 km/h - Rodovia pista simples (automóveis e motos)',
                  },
                ];
        }
        if (_categoriaVeiculoCTB == _CategoriaVeiculoCTB.onibusMicroonibus) {
          return const [
            {
              'value': '90',
              'label': '90 km/h - Rodovia (ônibus e micro-ônibus)',
            },
          ];
        }
        // caminhoes → 80 km/h (pista dupla ou simples)
        return const [
          {'value': '80', 'label': '80 km/h - Rodovia (caminhões)'},
        ];
      case null:
        return const [];
    }
  }

  void _normalizarVelocidadeCTBSelecionada() {
    final valoresValidos = _opcoesVelocidadeCTBFiltradas()
        .map((e) => e['value'])
        .whereType<String>();
    if (_velocidadeCTBSelecionada != null &&
        !valoresValidos.contains(_velocidadeCTBSelecionada)) {
      _velocidadeCTBSelecionada = null;
    }
  }

  _ViaCTB? _mapearViaCTBDeValor(String? value) {
    switch (value) {
      case 'urbanaTransitoRapido':
        return _ViaCTB.urbanaTransitoRapido;
      case 'urbanaArterial':
        return _ViaCTB.urbanaArterial;
      case 'urbanaColetora':
        return _ViaCTB.urbanaColetora;
      case 'urbanaLocal':
        return _ViaCTB.urbanaLocal;
      case 'ruralRodovia':
        return _ViaCTB.ruralRodovia;
      case 'ruralEstrada':
        return _ViaCTB.ruralEstrada;
      default:
        return null;
    }
  }

  void _inferirContextoCTBPorVelocidadeSalva(String velocidade) {
    switch (velocidade) {
      case '80':
        // 80 km/h: via urbana de trânsito rápido OU rodovia (caminhões); prioriza urbana
        _viaCTBSelecionada = _ViaCTB.urbanaTransitoRapido;
        break;
      case '40':
        _viaCTBSelecionada = _ViaCTB.urbanaColetora;
        break;
      case '30':
        _viaCTBSelecionada = _ViaCTB.urbanaLocal;
        break;
      case '110':
        _viaCTBSelecionada = _ViaCTB.ruralRodovia;
        _tipoPistaRodoviaCTB = TipoPistaRodovia.dupla;
        _categoriaVeiculoCTB = _CategoriaVeiculoCTB.automoveisMotos;
        break;
      case '100':
        _viaCTBSelecionada = _ViaCTB.ruralRodovia;
        _tipoPistaRodoviaCTB = TipoPistaRodovia.simples;
        _categoriaVeiculoCTB = _CategoriaVeiculoCTB.automoveisMotos;
        break;
      case '90':
        _viaCTBSelecionada = _ViaCTB.ruralRodovia;
        _tipoPistaRodoviaCTB = TipoPistaRodovia.dupla; // tanto dupla quanto simples = 90
        _categoriaVeiculoCTB = _CategoriaVeiculoCTB.onibusMicroonibus;
        break;
      default:
        // 60: urbana arterial ou estrada rural — mantém sem inferência
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final dados = widget.ficha.crimeTransitoCondicoes;
    if (dados == null) return;

    _soloSelecionado.addAll(dados.condicoesSolo ?? const []);
    _iluminacaoSelecionada.addAll(dados.iluminacao ?? const []);
    _tracadoSelecionado.addAll(dados.tracados ?? const []);
    _tipoPistaSelecionado.addAll(dados.tiposPista ?? const []);
    _sentidoSelecionado.addAll(dados.sentidos ?? const []);
    final perfis = dados.perfis ?? const [];
    for (final p in [
      PerfilPista.plano,
      PerfilPista.aclive,
      PerfilPista.declive,
    ]) {
      if (perfis.contains(p)) {
        _perfilDirecao = p;
        break;
      }
    }
    for (final p in [
      PerfilPista.suave,
      PerfilPista.moderado,
      PerfilPista.acentuado,
    ]) {
      if (perfis.contains(p)) {
        _perfilIntensidade = p;
        break;
      }
    }
    _condicoesViaSelecionadas.addAll(dados.condicoesVia ?? const []);
    _sinalizacaoTipos.addAll(dados.sinalizacao?.tipos ?? const []);
    _sinalizacaoSituacoes.addAll(dados.sinalizacao?.situacoes ?? const []);
    _separacaoFaixas.addAll(dados.separacoesFaixas ?? const []);
    _corFaixas.addAll(dados.corFaixas ?? const []);
    _separacaoPistas.addAll(dados.separacoesPistas ?? const []);
    _lateralDirElementos.addAll(dados.lateralDireita?.elementos ?? const []);
    _lateralEsqElementos.addAll(dados.lateralEsquerda?.elementos ?? const []);
    _regime = dados.regimeTrafego;
    _visibilidade = dados.visibilidade;
    _lateralDirConservacao = dados.lateralDireita?.conservacao;
    _lateralEsqConservacao = dados.lateralEsquerda?.conservacao;
    _velocidadePorSinalizacao = dados.velocidadePorSinalizacao ?? false;
    _velocidadePorCTB = dados.velocidadePorCTB ?? false;
    if (dados.velocidadePorCTB == true &&
        (dados.velocidadeMaxima ?? '').isNotEmpty) {
      _velocidadeCTBSelecionada = dados.velocidadeMaxima!.trim();
      _inferirContextoCTBPorVelocidadeSalva(_velocidadeCTBSelecionada!);
    }

    _velocidadeMaxCtrl.text = dados.velocidadePorSinalizacao == true
        ? (dados.velocidadeMaxima ?? '')
        : '';
    _larguraPistaCtrl.text = dados.larguraPista ?? '';
    _intensidadePerfilCtrl.text = dados.intensidadePerfil ?? '';
    _condicaoOutroCtrl.text = dados.condicaoViaOutroDescricao ?? '';
    _numeroFaixasCtrl.text = dados.numeroFaixas != null
        ? dados.numeroFaixas.toString()
        : '';
    _largurasFaixasCtrl.text = (dados.largurasFaixas ?? const [])
        .where((e) => e.isNotEmpty)
        .join('\n');
    _visibilidadeDescricaoCtrl.text = dados.visibilidadeReducaoDescricao ?? '';
    _sinalizacaoObsCtrl.text = dados.sinalizacao?.observacoes ?? '';
    _regimeOutroCtrl.text = dados.regimeTrafegoOutro ?? '';
    _observacoesCtrl.text = dados.observacoes ?? '';
    _lateralDirLarguraCtrl.text = dados.lateralDireita?.largura ?? '';
    _lateralDirObsCtrl.text = dados.lateralDireita?.observacoes ?? '';
    _lateralEsqLarguraCtrl.text = dados.lateralEsquerda?.largura ?? '';
    _lateralEsqObsCtrl.text = dados.lateralEsquerda?.observacoes ?? '';
  }

  @override
  void dispose() {
    _larguraPistaCtrl.dispose();
    _intensidadePerfilCtrl.dispose();
    _condicaoOutroCtrl.dispose();
    _velocidadeMaxCtrl.dispose();
    _numeroFaixasCtrl.dispose();
    _largurasFaixasCtrl.dispose();
    _visibilidadeDescricaoCtrl.dispose();
    _sinalizacaoObsCtrl.dispose();
    _regimeOutroCtrl.dispose();
    _observacoesCtrl.dispose();
    _lateralDirLarguraCtrl.dispose();
    _lateralDirObsCtrl.dispose();
    _lateralEsqLarguraCtrl.dispose();
    _lateralEsqObsCtrl.dispose();
    super.dispose();
  }

  void _alternarSelecao<T>(Set<T> conjunto, T valor) {
    setState(() {
      if (conjunto.contains(valor)) {
        conjunto.remove(valor);
      } else {
        conjunto.add(valor);
      }
    });
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);

    final condicoes = CrimeTransitoCondicoesViaModel(
      condicoesSolo: _soloSelecionado.toList(),
      iluminacao: _iluminacaoSelecionada.toList(),
      tracados: _tracadoSelecionado.toList(),
      tiposPista: _tipoPistaSelecionado.toList(),
      sentidos: _sentidoSelecionado.toList(),
      perfis: () {
        if (_perfilDirecao == null) return null;
        if (_perfilDirecao == PerfilPista.plano) return [PerfilPista.plano];
        final list = [_perfilDirecao!];
        if (_perfilIntensidade != null) list.add(_perfilIntensidade!);
        return list;
      }(),
      larguraPista: _larguraPistaCtrl.text.trim().isEmpty
          ? null
          : _larguraPistaCtrl.text.trim(),
      intensidadePerfil: _intensidadePerfilCtrl.text.trim().isEmpty
          ? null
          : _intensidadePerfilCtrl.text.trim(),
      condicoesVia: _condicoesViaSelecionadas.toList(),
      condicaoViaOutroDescricao: _condicaoOutroCtrl.text.trim().isEmpty
          ? null
          : _condicaoOutroCtrl.text.trim(),
      sinalizacao:
          (_sinalizacaoTipos.isEmpty &&
              _sinalizacaoSituacoes.isEmpty &&
              _sinalizacaoObsCtrl.text.trim().isEmpty)
          ? null
          : CrimeTransitoSinalizacaoInfo(
              tipos: _sinalizacaoTipos.toList(),
              situacoes: _sinalizacaoSituacoes.toList(),
              observacoes: _sinalizacaoObsCtrl.text.trim().isEmpty
                  ? null
                  : _sinalizacaoObsCtrl.text.trim(),
            ),
      regimeTrafego: _regime,
      regimeTrafegoOutro: _regimeOutroCtrl.text.trim().isEmpty
          ? null
          : _regimeOutroCtrl.text.trim(),
      velocidadePorSinalizacao: _velocidadePorSinalizacao,
      velocidadePorCTB: _velocidadePorCTB,
      velocidadeMaxima: _velocidadePorSinalizacao
          ? (_velocidadeMaxCtrl.text.trim().isEmpty
                ? null
                : _velocidadeMaxCtrl.text.trim())
          : (_velocidadePorCTB ? _velocidadeCTBSelecionada : null),
      numeroFaixas: int.tryParse(_numeroFaixasCtrl.text.trim()),
      largurasFaixas: _largurasFaixasCtrl.text
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      visibilidade: _visibilidade,
      visibilidadeReducaoDescricao:
          _visibilidadeDescricaoCtrl.text.trim().isEmpty
          ? null
          : _visibilidadeDescricaoCtrl.text.trim(),
      separacoesFaixas: _separacaoFaixas.toList(),
      corFaixas: _corFaixas.toList(),
      separacoesPistas: _separacaoPistas.toList(),
      lateralDireita:
          (_lateralDirElementos.isEmpty &&
              _lateralDirLarguraCtrl.text.trim().isEmpty &&
              _lateralDirObsCtrl.text.trim().isEmpty &&
              _lateralDirConservacao == null)
          ? null
          : CrimeTransitoLateralInfo(
              elementos: _lateralDirElementos.toList(),
              largura: _lateralDirLarguraCtrl.text.trim().isEmpty
                  ? null
                  : _lateralDirLarguraCtrl.text.trim(),
              conservacao: _lateralDirConservacao,
              observacoes: _lateralDirObsCtrl.text.trim().isEmpty
                  ? null
                  : _lateralDirObsCtrl.text.trim(),
            ),
      lateralEsquerda:
          (_lateralEsqElementos.isEmpty &&
              _lateralEsqLarguraCtrl.text.trim().isEmpty &&
              _lateralEsqObsCtrl.text.trim().isEmpty &&
              _lateralEsqConservacao == null)
          ? null
          : CrimeTransitoLateralInfo(
              elementos: _lateralEsqElementos.toList(),
              largura: _lateralEsqLarguraCtrl.text.trim().isEmpty
                  ? null
                  : _lateralEsqLarguraCtrl.text.trim(),
              conservacao: _lateralEsqConservacao,
              observacoes: _lateralEsqObsCtrl.text.trim().isEmpty
                  ? null
                  : _lateralEsqObsCtrl.text.trim(),
            ),
      observacoes: _observacoesCtrl.text.trim().isEmpty
          ? null
          : _observacoesCtrl.text.trim(),
    );

    final fichaAtualizada = widget.ficha.copyWith(
      crimeTransitoCondicoes: condicoes,
      dataUltimaAtualizacao: DateTime.now(),
    );

    await _fichaService.salvarFicha(fichaAtualizada);

    if (!mounted) return;
    setState(() => _salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Condições salvas com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
    // Ir para a próxima tela do fluxo (Veículos) em vez de voltar à lista
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CrimeTransitoLevantamentoScreen(ficha: fichaAtualizada),
      ),
    );
    if (mounted && resultado == true) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildSectionTitle(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMultiSelectChips<T>({
    required Iterable<T> opcoes,
    required Set<T> selecionados,
    required String Function(T) label,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: opcoes
          .map(
            (opcao) => FilterChip(
              label: Text(label(opcao)),
              selected: selecionados.contains(opcao),
              onSelected: (_) => _alternarSelecao(selecionados, opcao),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Condições da Via - Trânsito'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Condições do Local'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<CondicaoSoloLocal>(
              opcoes: CondicaoSoloLocal.values,
              selecionados: _soloSelecionado,
              label: (v) => switch (v) {
                CondicaoSoloLocal.seco => 'Seco',
                CondicaoSoloLocal.umido => 'Úmido',
                CondicaoSoloLocal.molhado => 'Molhado',
              },
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Iluminação'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<IluminacaoLocal>(
              opcoes: IluminacaoLocal.values,
              selecionados: _iluminacaoSelecionada,
              label: (v) => switch (v) {
                IluminacaoLocal.artificial => 'Artificial',
                IluminacaoLocal.naturalDia => 'Natural (Dia)',
                IluminacaoLocal.ausente => 'Ausente (Noturno)',
              },
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Traçado da Pista'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<TracadoPista>(
              opcoes: TracadoPista.values,
              selecionados: _tracadoSelecionado,
              label: (v) => switch (v) {
                TracadoPista.curvaEsquerda => 'Curva à esquerda',
                TracadoPista.curvaDireita => 'Curva à direita',
                TracadoPista.reto => 'Reto',
                TracadoPista.raioAmplo => 'Raio amplo',
                TracadoPista.raioPequeno => 'Raio pequeno',
                TracadoPista.cruzamento => 'Cruzamento',
              },
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Tipo de Pista'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<TipoPistaRodovia>(
              opcoes: TipoPistaRodovia.values,
              selecionados: _tipoPistaSelecionado,
              label: (v) => v == TipoPistaRodovia.simples ? 'Simples' : 'Dupla',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Sentido da Via'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<SentidoPista>(
              opcoes: SentidoPista.values,
              selecionados: _sentidoSelecionado,
              label: (v) => v == SentidoPista.unico ? 'Único' : 'Duplo',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Perfil da Via'),
            const SizedBox(height: 4),
            Text(
              'Sentido do perfil',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  [
                    PerfilPista.plano,
                    PerfilPista.aclive,
                    PerfilPista.declive,
                  ].map((opcao) {
                    final selecionado = _perfilDirecao == opcao;
                    final label = switch (opcao) {
                      PerfilPista.plano => 'Plano',
                      PerfilPista.aclive => 'Aclive (subida)',
                      PerfilPista.declive => 'Declive (descida)',
                      _ => opcao.name,
                    };
                    return FilterChip(
                      label: Text(label),
                      selected: selecionado,
                      onSelected: (_) {
                        setState(() {
                          _perfilDirecao = selecionado ? null : opcao;
                          if (_perfilDirecao != PerfilPista.aclive &&
                              _perfilDirecao != PerfilPista.declive) {
                            _perfilIntensidade = null;
                          }
                        });
                      },
                    );
                  }).toList(),
            ),
            if (_perfilDirecao == PerfilPista.aclive ||
                _perfilDirecao == PerfilPista.declive) ...[
              const SizedBox(height: 12),
              Text(
                'Intensidade',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    [
                      PerfilPista.suave,
                      PerfilPista.moderado,
                      PerfilPista.acentuado,
                    ].map((opcao) {
                      final selecionado = _perfilIntensidade == opcao;
                      final label = switch (opcao) {
                        PerfilPista.suave => 'Suave',
                        PerfilPista.moderado => 'Moderado',
                        PerfilPista.acentuado => 'Acentuado',
                        _ => opcao.name,
                      };
                      return FilterChip(
                        label: Text(label),
                        selected: selecionado,
                        onSelected: (_) {
                          setState(() {
                            _perfilIntensidade = selecionado ? null : opcao;
                          });
                        },
                      );
                    }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _larguraPistaCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Largura da pista (m)',
                hintText: 'Ex: 3,5',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _intensidadePerfilCtrl,
              decoration: const InputDecoration(
                labelText: 'Intensidade (Aclive/Declive)',
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Condições da Via / Pavimentação'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<CondicaoViaOpcao>(
              opcoes: CondicaoViaOpcao.values,
              selecionados: _condicoesViaSelecionadas,
              label: (v) => switch (v) {
                CondicaoViaOpcao.seca => 'Seca',
                CondicaoViaOpcao.molhada => 'Molhada',
                CondicaoViaOpcao.semDefeito => 'Sem defeito',
                CondicaoViaOpcao.emObras => 'Em obras',
                CondicaoViaOpcao.cascalho => 'Cascalho',
                CondicaoViaOpcao.terra => 'Terra',
                CondicaoViaOpcao.asfaltoRugoso => 'Asfalto rugoso',
                CondicaoViaOpcao.buracos => 'Buracos',
                CondicaoViaOpcao.ondulacoes => 'Ondulações',
                CondicaoViaOpcao.contaminantes => 'Com contaminantes',
                CondicaoViaOpcao.asfaltoLiso => 'Asfalto liso',
                CondicaoViaOpcao.outro => 'Outro',
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _condicaoOutroCtrl,
              decoration: const InputDecoration(
                labelText: 'Descreva "Outro" (se aplicável)',
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Sinalização presente'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<SinalizacaoTipo>(
              opcoes: SinalizacaoTipo.values,
              selecionados: _sinalizacaoTipos,
              label: (v) => switch (v) {
                SinalizacaoTipo.vertical => 'Vertical',
                SinalizacaoTipo.horizontal => 'Horizontal',
                SinalizacaoTipo.semaforica => 'Semafórica',
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Situação da Sinalização',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _buildMultiSelectChips<SinalizacaoSituacao>(
              opcoes: SinalizacaoSituacao.values,
              selecionados: _sinalizacaoSituacoes,
              label: (v) => switch (v) {
                SinalizacaoSituacao.normal => 'Normal',
                SinalizacaoSituacao.desligado => 'Desligado',
                SinalizacaoSituacao.defeituoso => 'Defeituoso',
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sinalizacaoObsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observações sobre sinalização',
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Regime de Tráfego'),
            const SizedBox(height: 8),
            RadioGroup<RegimeTrafego>(
              groupValue: _regime,
              onChanged: (value) => setState(() => _regime = value),
              child: Column(
                children: RegimeTrafego.values
                    .map(
                      (opcao) => RadioListTile<RegimeTrafego>(
                        title: Text(switch (opcao) {
                          RegimeTrafego.intenso => 'Intenso',
                          RegimeTrafego.moderado => 'Moderado',
                          RegimeTrafego.leve => 'Leve',
                          RegimeTrafego.outro => 'Outro',
                        }),
                        value: opcao,
                      ),
                    )
                    .toList(),
              ),
            ),
            if (_regime == RegimeTrafego.outro)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _regimeOutroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descreva o regime de tráfego',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Velocidade indicada por sinalização expressa'),
              value: _velocidadePorSinalizacao,
              onChanged: (value) {
                setState(() {
                  _velocidadePorSinalizacao = value;
                  if (_velocidadePorSinalizacao) {
                    _velocidadePorCTB = false;
                    _velocidadeCTBSelecionada = null;
                  }
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Velocidade conforme CTB/1997 (Art. 61, §1º)'),
              value: _velocidadePorCTB,
              onChanged: (value) {
                setState(() {
                  _velocidadePorCTB = value;
                  if (_velocidadePorCTB) {
                    _velocidadePorSinalizacao = false;
                    _velocidadeMaxCtrl.clear();
                  } else {
                    _velocidadeCTBSelecionada = null;
                    _viaCTBSelecionada = null;
                    _tipoPistaRodoviaCTB = null;
                    _categoriaVeiculoCTB = null;
                  }
                });
              },
            ),
            if (_velocidadePorSinalizacao)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _velocidadeMaxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Velocidade máxima permitida (km/h)',
                    hintText: 'Ex: 60',
                  ),
                ),
              ),
            if (_velocidadePorCTB) const SizedBox(height: 12),
            if (_velocidadePorCTB)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _viaCTBSelecionada == null
                    ? null
                    : switch (_viaCTBSelecionada!) {
                        _ViaCTB.urbanaTransitoRapido => 'urbanaTransitoRapido',
                        _ViaCTB.urbanaArterial => 'urbanaArterial',
                        _ViaCTB.urbanaColetora => 'urbanaColetora',
                        _ViaCTB.urbanaLocal => 'urbanaLocal',
                        _ViaCTB.ruralRodovia => 'ruralRodovia',
                        _ViaCTB.ruralEstrada => 'ruralEstrada',
                      },
                decoration: const InputDecoration(
                  labelText: 'Classificação da via (Art. 61, §1º, CTB)',
                  helperText: 'Quando não houver sinalização indicando limite diferente.',
                ),
                hint: const Text('Selecione o tipo de via'),
                items: _viasCTB
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e['value'],
                        child: Text(e['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _viaCTBSelecionada = _mapearViaCTBDeValor(value);
                    _tipoPistaRodoviaCTB = null;
                    _categoriaVeiculoCTB = null;
                    _normalizarVelocidadeCTBSelecionada();
                  });
                },
              ),
            if (_velocidadePorCTB && _viaCTBSelecionada == _ViaCTB.ruralRodovia)
              const SizedBox(height: 20),
            if (_velocidadePorCTB && _viaCTBSelecionada == _ViaCTB.ruralRodovia)
              DropdownButtonFormField<TipoPistaRodovia>(
                isExpanded: true,
                initialValue: _tipoPistaRodoviaCTB,
                decoration: const InputDecoration(
                  labelText: 'Rodovia - tipo de pista',
                ),
                hint: const Text('Selecione simples ou dupla'),
                items: TipoPistaRodovia.values
                    .map(
                      (e) => DropdownMenuItem<TipoPistaRodovia>(
                        value: e,
                        child: Text(
                          e == TipoPistaRodovia.simples
                              ? 'Pista simples'
                              : 'Pista dupla',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _tipoPistaRodoviaCTB = value;
                    _normalizarVelocidadeCTBSelecionada();
                  });
                },
              ),
            if (_velocidadePorCTB && _viaCTBSelecionada == _ViaCTB.ruralRodovia)
              const SizedBox(height: 20),
            if (_velocidadePorCTB && _viaCTBSelecionada == _ViaCTB.ruralRodovia)
              DropdownButtonFormField<_CategoriaVeiculoCTB>(
                isExpanded: true,
                initialValue: _categoriaVeiculoCTB,
                decoration: const InputDecoration(
                  labelText: 'Categoria do veículo (CTB)',
                ),
                hint: const Text('Selecione a categoria'),
                items: _CategoriaVeiculoCTB.values
                    .map(
                      (e) => DropdownMenuItem<_CategoriaVeiculoCTB>(
                        value: e,
                        child: Text(
                          switch (e) {
                            _CategoriaVeiculoCTB.automoveisMotos =>
                              'Automóveis e motos',
                            _CategoriaVeiculoCTB.onibusMicroonibus =>
                              'Ônibus e micro-ônibus',
                            _CategoriaVeiculoCTB.caminhoes => 'Caminhões',
                          },
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _categoriaVeiculoCTB = value;
                    _normalizarVelocidadeCTBSelecionada();
                  });
                },
              ),
            const SizedBox(height: 20),
            if (_velocidadePorCTB && _opcoesVelocidadeCTBFiltradas().isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue:
                    _opcoesVelocidadeCTBFiltradas().any(
                      (e) => e['value'] == _velocidadeCTBSelecionada,
                    )
                    ? _velocidadeCTBSelecionada
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Velocidade máxima (Art. 61, §1º, CTB)',
                ),
                hint: const Text('Selecione o limite'),
                selectedItemBuilder: (context) =>
                    _opcoesVelocidadeCTBFiltradas()
                        .map(
                          (e) => Text(
                            e['label']!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                        .toList(),
                items: _opcoesVelocidadeCTBFiltradas()
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e['value'],
                        child: Text(e['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _velocidadeCTBSelecionada = value);
                },
              ),
            if (_velocidadePorCTB && _opcoesVelocidadeCTBFiltradas().isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _viaCTBSelecionada == _ViaCTB.ruralRodovia
                      ? 'Para rodovia, selecione o tipo de pista e a categoria do veículo para definir o limite (Art. 61, §1º, CTB).'
                      : 'Selecione a classificação da via para definir o limite (Art. 61, §1º, CTB).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _numeroFaixasCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número de faixas de rolamento',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _largurasFaixasCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              maxLines: 3,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.\n\r\s]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Largura das faixas (separe por vírgula ou linha)',
                hintText: 'Ex: 3,5 ou 3,5; 4; 3,2',
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Visibilidade'),
            const SizedBox(height: 8),
            RadioGroup<VisibilidadeTipo>(
              groupValue: _visibilidade,
              onChanged: (value) => setState(() {
                _visibilidade = value;
              }),
              child: Column(
                children: VisibilidadeTipo.values
                    .map(
                      (opcao) => RadioListTile<VisibilidadeTipo>(
                        title: Text(
                          opcao == VisibilidadeTipo.boa ? 'Boa' : 'Reduzida',
                        ),
                        value: opcao,
                      ),
                    )
                    .toList(),
              ),
            ),
            if (_visibilidade == VisibilidadeTipo.reduzida)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _visibilidadeDescricaoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Informe o motivo da visibilidade reduzida',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildSectionTitle('Separação das Faixas'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<SeparacaoFaixasOpcao>(
              opcoes: SeparacaoFaixasOpcao.values,
              selecionados: _separacaoFaixas,
              label: (v) => switch (v) {
                SeparacaoFaixasOpcao.simplesContinua => 'Simples Contínua',
                SeparacaoFaixasOpcao.duplaContinua => 'Dupla Contínua',
                SeparacaoFaixasOpcao.simplesSeccionada => 'Simples Seccionada',
                SeparacaoFaixasOpcao.duplaContinuaSeccionada =>
                  'Dupla Contínua/Seccionada',
              },
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Cor das Faixas'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<CorFaixa>(
              opcoes: CorFaixa.values,
              selecionados: _corFaixas,
              label: (v) => v == CorFaixa.amarela ? 'Amarela' : 'Branca',
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Separação das Pistas'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<SeparacaoPistasOpcao>(
              opcoes: SeparacaoPistasOpcao.values,
              selecionados: _separacaoPistas,
              label: (v) => switch (v) {
                SeparacaoPistasOpcao.canteiro => 'Canteiro',
                SeparacaoPistasOpcao.muretaConcreto => 'Mureta de concreto',
                SeparacaoPistasOpcao.tachoes => 'Tachões',
                SeparacaoPistasOpcao.defensa => 'Defensa / Guard rail',
                SeparacaoPistasOpcao.nenhum => 'Nenhum',
                SeparacaoPistasOpcao.outro => 'Outro',
              },
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Lateral Direita da Pista'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<ElementoLateral>(
              opcoes: ElementoLateral.values,
              selecionados: _lateralDirElementos,
              label: (v) => switch (v) {
                ElementoLateral.meioFio => 'Meio-fio',
                ElementoLateral.faixaPintada => 'Faixa pintada',
                ElementoLateral.acostamento => 'Acostamento',
                ElementoLateral.muretaConcreto => 'Mureta de concreto',
                ElementoLateral.outro => 'Outro',
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lateralDirLarguraCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Largura (m)',
                hintText: 'Ex: 3,5',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ConservacaoEstado>(
              initialValue: _lateralDirConservacao,
              decoration: const InputDecoration(labelText: 'Conservação'),
              items: ConservacaoEstado.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e == ConservacaoEstado.boa ? 'Boa' : 'Ruim'),
                    ),
                  )
                  .toList(),
              onChanged: (valor) => setState(() {
                _lateralDirConservacao = valor;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lateralDirObsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observações da lateral direita',
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Lateral Esquerda da Pista'),
            const SizedBox(height: 8),
            _buildMultiSelectChips<ElementoLateral>(
              opcoes: ElementoLateral.values,
              selecionados: _lateralEsqElementos,
              label: (v) => switch (v) {
                ElementoLateral.meioFio => 'Meio-fio',
                ElementoLateral.faixaPintada => 'Faixa pintada',
                ElementoLateral.acostamento => 'Acostamento',
                ElementoLateral.muretaConcreto => 'Mureta de concreto',
                ElementoLateral.outro => 'Outro',
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lateralEsqLarguraCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Largura (m)',
                hintText: 'Ex: 3,5',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ConservacaoEstado>(
              initialValue: _lateralEsqConservacao,
              decoration: const InputDecoration(labelText: 'Conservação'),
              items: ConservacaoEstado.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e == ConservacaoEstado.boa ? 'Boa' : 'Ruim'),
                    ),
                  )
                  .toList(),
              onChanged: (valor) => setState(() {
                _lateralEsqConservacao = valor;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lateralEsqObsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observações da lateral esquerda',
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Observações Gerais'),
            const SizedBox(height: 8),
            TextField(
              controller: _observacoesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Descreva observações relevantes sobre a via',
              ),
            ),
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
                label: Text(_salvando ? 'Salvando...' : 'Salvar condições'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
