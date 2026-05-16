import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ficha_completa_model.dart';
import '../models/laboratorio_model.dart';
import '../models/metodo_posicionamento_model.dart';
import '../models/unidade_model.dart';
import '../models/veiculo_model.dart';
import '../models/vestigio_veiculo_model.dart';
import '../services/laboratorio_service.dart';
import '../services/photo_backup_service.dart';
import '../services/unidade_service.dart';
import '../models/tipo_ocorrencia.dart';
import 'vestigio_veiculo_form_screen.dart';

class CadastroVeiculoScreen extends StatefulWidget {
  final VeiculoModel veiculo;
  final FichaCompletaModel ficha;

  const CadastroVeiculoScreen({
    super.key,
    required this.veiculo,
    required this.ficha,
  });

  @override
  State<CadastroVeiculoScreen> createState() => _CadastroVeiculoScreenState();
}

class _CadastroVeiculoScreenState extends State<CadastroVeiculoScreen> {
  final _unidadeService = UnidadeService();
  final _laboratorioService = LaboratorioService();

  // Controllers - Identificação
  final _tipoVeiculoOutroCtrl = TextEditingController();
  final _marcaModeloCtrl = TextEditingController();
  final _anoFabricacaoCtrl = TextEditingController();
  final _anoModeloCtrl = TextEditingController();
  final _corCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _chassiCtrl = TextEditingController();

  // Controllers - Localização
  final _localizacaoAmbienteCtrl = TextEditingController();
  final _coordenadaFrenteXCtrl = TextEditingController();
  final _coordenadaFrenteYCtrl = TextEditingController();
  final _alturaFrenteCtrl = TextEditingController();
  final _coordenadaTraseiraXCtrl = TextEditingController();
  final _coordenadaTraseiraYCtrl = TextEditingController();
  final _alturaTraseiraCtrl = TextEditingController();
  final _coordenadaCentroXCtrl = TextEditingController();
  final _coordenadaCentroYCtrl = TextEditingController();
  final _alturaCentroCtrl = TextEditingController();

  // Controllers - Estado e Posição
  final _posicaoLivreCtrl = TextEditingController();
  final _condicaoGeralCtrl = TextEditingController();
  final _danosObservacoesCtrl = TextEditingController();
  final _bicicletaCorCtrl = TextEditingController();
  final _bicicletaModeloCtrl = TextEditingController();
  final _bicicletaSinalizacaoCtrl = TextEditingController();

  // Controllers - Vestígios (legados, mantidos para compatibilidade)
  final _localizacaoSangueCtrl = TextEditingController();
  final _localizacaoProjeteisImpactosCtrl = TextEditingController();

  // Controllers - Relacionamento
  final _observacoesCtrl = TextEditingController();

  // Estados
  TipoVeiculo? _tipoVeiculo;
  PosicaoVeiculo? _posicao;
  RelacaoVeiculo? _relacao;
  IntensidadeDano? _intensidadeDano;
  final Set<SetorImpacto> _setoresImpacto = {};
  final Set<TipificacaoDeformacao> _tipificacoes = {};
  final Set<OrientacaoDeformacao> _orientacoes = {};
  StatusComponenteVeiculo? _faroisStatus;
  StatusComponenteVeiculo? _cintosStatus;
  EstadoPneumaticos? _estadoPneus;
  StatusComponenteVeiculo? _freiosStatus;
  StatusComponenteVeiculo? _direcaoStatus;
  AirbagStatus? _airbagStatus;
  RetrovisorStatus? _retrovisorStatus;
  TacografoStatus? _tacografoStatus;
  bool _bicicletaPossuiCampainha = false;
  // Flags legados (enquanto migramos para lista de vestígios)
  List<VestigioVeiculoModel> _vestigios = [];
  bool _modoRapido = false;
  bool _registrarCoordenadasRapido = false;
  MetodoPosicionamentoVestigio _metodoPosicionamentoVestigios =
      MetodoPosicionamentoVestigio.nenhum;

  List<String> _fotosVistaVeiculoAmbiente = [];
  final _imagePicker = ImagePicker();

  bool get _isCrimeTransito =>
      widget.ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    final v = widget.veiculo;
    _tipoVeiculo = v.tipoVeiculo;
    _tipoVeiculoOutroCtrl.text = v.tipoVeiculoOutro ?? '';
    _marcaModeloCtrl.text = v.marcaModelo ?? '';
    _anoFabricacaoCtrl.text = v.anoFabricacao ?? '';
    _anoModeloCtrl.text = v.anoModelo ?? '';
    _corCtrl.text = v.cor ?? '';
    _placaCtrl.text = v.placa ?? '';
    _chassiCtrl.text = v.chassiAparente ?? '';

    final posicaoLegada = (v.posicao == PosicaoVeiculo.outra)
        ? (v.posicaoLivre ?? '')
        : (v.posicao?.label ?? '');
    _localizacaoAmbienteCtrl.text =
        (v.localizacaoAmbiente ?? '').trim().isNotEmpty
        ? v.localizacaoAmbiente!
        : posicaoLegada;
    _coordenadaFrenteXCtrl.text = v.coordenadaFrenteX ?? '';
    _coordenadaFrenteYCtrl.text = v.coordenadaFrenteY ?? '';
    _alturaFrenteCtrl.text = v.alturaFrente ?? '';
    _coordenadaTraseiraXCtrl.text = v.coordenadaTraseiraX ?? '';
    _coordenadaTraseiraYCtrl.text = v.coordenadaTraseiraY ?? '';
    _alturaTraseiraCtrl.text = v.alturaTraseira ?? '';
    _coordenadaCentroXCtrl.text = v.coordenadaCentroX ?? '';
    _coordenadaCentroYCtrl.text = v.coordenadaCentroY ?? '';
    _alturaCentroCtrl.text = v.alturaCentro ?? '';
    _registrarCoordenadasRapido =
        _coordenadaFrenteXCtrl.text.trim().isNotEmpty ||
        _coordenadaFrenteYCtrl.text.trim().isNotEmpty ||
        _alturaFrenteCtrl.text.trim().isNotEmpty ||
        _coordenadaTraseiraXCtrl.text.trim().isNotEmpty ||
        _coordenadaTraseiraYCtrl.text.trim().isNotEmpty ||
        _alturaTraseiraCtrl.text.trim().isNotEmpty ||
        _coordenadaCentroXCtrl.text.trim().isNotEmpty ||
        _coordenadaCentroYCtrl.text.trim().isNotEmpty ||
        _alturaCentroCtrl.text.trim().isNotEmpty;

    _posicao = v.posicao;
    _posicaoLivreCtrl.text = v.posicaoLivre ?? '';
    _condicaoGeralCtrl.text = v.condicaoGeral ?? '';
    _intensidadeDano = v.intensidadeDano;
    _setoresImpacto
      ..clear()
      ..addAll(v.setoresImpacto ?? const []);
    _tipificacoes
      ..clear()
      ..addAll(v.tipificacoesDeformacoes ?? const []);
    _orientacoes
      ..clear()
      ..addAll(v.orientacoesDeformacoes ?? const []);
    _danosObservacoesCtrl.text = v.danosObservacoes ?? '';
    _faroisStatus = v.faroisLanternas;
    _cintosStatus = v.cintosSeguranca;
    _estadoPneus = v.estadoPneumaticos;
    _freiosStatus = v.freios;
    _direcaoStatus = v.direcao;
    _airbagStatus = v.airbag;
    _retrovisorStatus = v.retrovisor;
    _tacografoStatus = v.tacografoStatus;
    _bicicletaCorCtrl.text = v.bicicletaCor ?? '';
    _bicicletaModeloCtrl.text = v.bicicletaMarcaModelo ?? '';
    _bicicletaSinalizacaoCtrl.text = v.bicicletaElementosSinalizacao ?? '';
    _bicicletaPossuiCampainha = v.bicicletaPossuiCampainha ?? false;

    _vestigios = List<VestigioVeiculoModel>.from(v.vestigios ?? []);
    _metodoPosicionamentoVestigios =
        v.metodoPosicionamentoVestigios ??
        _inferirMetodoPosicionamentoVestigios(_vestigios);

    _fotosVistaVeiculoAmbiente = List<String>.from(v.fotosVistaVeiculoAmbiente);

    _relacao = v.relacao;
    _observacoesCtrl.text = v.observacoes ?? '';
  }

  @override
  void dispose() {
    _tipoVeiculoOutroCtrl.dispose();
    _marcaModeloCtrl.dispose();
    _anoFabricacaoCtrl.dispose();
    _anoModeloCtrl.dispose();
    _corCtrl.dispose();
    _placaCtrl.dispose();
    _chassiCtrl.dispose();
    _localizacaoAmbienteCtrl.dispose();
    _coordenadaFrenteXCtrl.dispose();
    _coordenadaFrenteYCtrl.dispose();
    _alturaFrenteCtrl.dispose();
    _coordenadaTraseiraXCtrl.dispose();
    _coordenadaTraseiraYCtrl.dispose();
    _alturaTraseiraCtrl.dispose();
    _coordenadaCentroXCtrl.dispose();
    _coordenadaCentroYCtrl.dispose();
    _alturaCentroCtrl.dispose();
    _posicaoLivreCtrl.dispose();
    _condicaoGeralCtrl.dispose();
    _danosObservacoesCtrl.dispose();
    _bicicletaCorCtrl.dispose();
    _bicicletaModeloCtrl.dispose();
    _bicicletaSinalizacaoCtrl.dispose();
    _localizacaoSangueCtrl.dispose();
    _localizacaoProjeteisImpactosCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  VeiculoModel _construirVeiculo() {
    return widget.veiculo.copyWith(
      tipoVeiculo: _tipoVeiculo,
      tipoVeiculoOutro: _tipoVeiculoOutroCtrl.text.trim().isEmpty
          ? null
          : _tipoVeiculoOutroCtrl.text.trim(),
      marcaModelo: _marcaModeloCtrl.text.trim().isEmpty
          ? null
          : _marcaModeloCtrl.text.trim(),
      anoFabricacao: _anoFabricacaoCtrl.text.trim().isEmpty
          ? null
          : _anoFabricacaoCtrl.text.trim(),
      anoModelo: _anoModeloCtrl.text.trim().isEmpty
          ? null
          : _anoModeloCtrl.text.trim(),
      cor: _corCtrl.text.trim().isEmpty ? null : _corCtrl.text.trim(),
      placa: _placaCtrl.text.trim().isEmpty ? null : _placaCtrl.text.trim(),
      chassiAparente: _isCrimeTransito
          ? null
          : (_chassiCtrl.text.trim().isEmpty ? null : _chassiCtrl.text.trim()),
      localizacaoAmbiente: _localizacaoAmbienteCtrl.text.trim().isEmpty
          ? null
          : _localizacaoAmbienteCtrl.text.trim(),
      coordenadaFrenteX: _coordenadaFrenteXCtrl.text.trim().isEmpty
          ? null
          : _coordenadaFrenteXCtrl.text.trim(),
      coordenadaFrenteY: _coordenadaFrenteYCtrl.text.trim().isEmpty
          ? null
          : _coordenadaFrenteYCtrl.text.trim(),
      alturaFrente: _alturaFrenteCtrl.text.trim().isEmpty
          ? null
          : _alturaFrenteCtrl.text.trim(),
      coordenadaTraseiraX: _coordenadaTraseiraXCtrl.text.trim().isEmpty
          ? null
          : _coordenadaTraseiraXCtrl.text.trim(),
      coordenadaTraseiraY: _coordenadaTraseiraYCtrl.text.trim().isEmpty
          ? null
          : _coordenadaTraseiraYCtrl.text.trim(),
      alturaTraseira: _alturaTraseiraCtrl.text.trim().isEmpty
          ? null
          : _alturaTraseiraCtrl.text.trim(),
      coordenadaCentroX: _coordenadaCentroXCtrl.text.trim().isEmpty
          ? null
          : _coordenadaCentroXCtrl.text.trim(),
      coordenadaCentroY: _coordenadaCentroYCtrl.text.trim().isEmpty
          ? null
          : _coordenadaCentroYCtrl.text.trim(),
      alturaCentro: _alturaCentroCtrl.text.trim().isEmpty
          ? null
          : _alturaCentroCtrl.text.trim(),
      posicao: _posicao,
      posicaoLivre: _posicaoLivreCtrl.text.trim().isEmpty
          ? null
          : _posicaoLivreCtrl.text.trim(),
      condicaoGeral: _condicaoGeralCtrl.text.trim().isEmpty
          ? null
          : _condicaoGeralCtrl.text.trim(),
      intensidadeDano: _intensidadeDano,
      setoresImpacto: _setoresImpacto.isEmpty ? null : _setoresImpacto.toList(),
      tipificacoesDeformacoes: _tipificacoes.isEmpty
          ? null
          : _tipificacoes.toList(),
      orientacoesDeformacoes: _orientacoes.isEmpty
          ? null
          : _orientacoes.toList(),
      danosObservacoes: _danosObservacoesCtrl.text.trim().isEmpty
          ? null
          : _danosObservacoesCtrl.text.trim(),
      faroisLanternas: _faroisStatus,
      cintosSeguranca: _cintosStatus,
      estadoPneumaticos: _estadoPneus,
      freios: _freiosStatus,
      direcao: _direcaoStatus,
      airbag: _airbagStatus,
      retrovisor: _retrovisorStatus,
      tacografoStatus: _tacografoStatus,
      bicicletaCor: _bicicletaCorCtrl.text.trim().isEmpty
          ? null
          : _bicicletaCorCtrl.text.trim(),
      bicicletaMarcaModelo: _bicicletaModeloCtrl.text.trim().isEmpty
          ? null
          : _bicicletaModeloCtrl.text.trim(),
      bicicletaElementosSinalizacao:
          _bicicletaSinalizacaoCtrl.text.trim().isEmpty
          ? null
          : _bicicletaSinalizacaoCtrl.text.trim(),
      bicicletaPossuiCampainha: _bicicletaPossuiCampainha,
      fotosVistaVeiculoAmbiente: _fotosVistaVeiculoAmbiente,
      metodoPosicionamentoVestigios: _metodoPosicionamentoVestigios,
      vestigios: _vestigios,
      relacao: _relacao,
      observacoes: _observacoesCtrl.text.trim().isEmpty
          ? null
          : _observacoesCtrl.text.trim(),
    );
  }

  MetodoPosicionamentoVestigio _inferirMetodoPosicionamentoVestigios(
    List<VestigioVeiculoModel> vestigios,
  ) {
    if (vestigios.any((v) => v.latitude != null && v.longitude != null)) {
      return MetodoPosicionamentoVestigio.gps;
    }
    if (vestigios.any(
      (v) =>
          (v.coordenadaX ?? '').trim().isNotEmpty ||
          (v.coordenadaY ?? '').trim().isNotEmpty,
    )) {
      return MetodoPosicionamentoVestigio.marcoZero;
    }
    return MetodoPosicionamentoVestigio.nenhum;
  }

  String _resumoPosicionamentoVestigio(VestigioVeiculoModel vestigio) {
    final metodo =
        vestigio.metodoPosicionamentoOverride ?? _metodoPosicionamentoVestigios;
    switch (metodo) {
      case MetodoPosicionamentoVestigio.marcoZero:
        final partes = <String>[];
        if ((vestigio.coordenadaX ?? '').trim().isNotEmpty) {
          partes.add('X=${vestigio.coordenadaX}');
        }
        if ((vestigio.coordenadaY ?? '').trim().isNotEmpty) {
          partes.add('Y=${vestigio.coordenadaY}');
        }
        if ((vestigio.alturaRelacaoPiso ?? '').trim().isNotEmpty) {
          partes.add('altura ${vestigio.alturaRelacaoPiso}');
        }
        return partes.isEmpty
            ? 'Posicionamento: marco zero'
            : 'Posicionamento: ${partes.join(', ')}';
      case MetodoPosicionamentoVestigio.gps:
        final partes = <String>[];
        if ((vestigio.coordenadasGpsFormatadas ?? '').trim().isNotEmpty) {
          partes.add(vestigio.coordenadasGpsFormatadas!);
        }
        if (vestigio.precisaoGpsMetros != null) {
          partes.add(
            'precisão ${vestigio.precisaoGpsMetros!.toStringAsFixed(1)} m',
          );
        }
        return partes.isEmpty
            ? 'Posicionamento: GPS'
            : 'Posicionamento: ${partes.join(' | ')}';
      case MetodoPosicionamentoVestigio.nenhum:
        return 'Posicionamento: não registrado';
    }
  }

  void _alternarEnum<T>(Set<T> conjunto, T valor) {
    setState(() {
      if (conjunto.contains(valor)) {
        conjunto.remove(valor);
      } else {
        conjunto.add(valor);
      }
    });
  }

  String _descricaoStatusComponente(StatusComponenteVeiculo valor) {
    switch (valor) {
      case StatusComponenteVeiculo.funcionando:
        return 'Funcionando';
      case StatusComponenteVeiculo.naoFuncionando:
        return 'Não funcionando';
      case StatusComponenteVeiculo.prejudicado:
        return 'Prejudicado';
    }
  }

  Widget _buildStatusDropdown({
    required String label,
    required StatusComponenteVeiculo? valor,
    required ValueChanged<StatusComponenteVeiculo?> onChanged,
  }) {
    return DropdownButtonFormField<StatusComponenteVeiculo>(
      initialValue: valor,
      decoration: InputDecoration(labelText: label),
      items: StatusComponenteVeiculo.values
          .map(
            (status) => DropdownMenuItem(
              value: status,
              child: Text(_descricaoStatusComponente(status)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildChipGroup<T>({
    required Iterable<T> valores,
    required Set<T> selecionados,
    required String titulo,
    required String Function(T valor) label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: valores
              .map(
                (valor) => FilterChip(
                  label: Text(label(valor)),
                  selected: selecionados.contains(valor),
                  onSelected: (_) => _alternarEnum(selecionados, valor),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCrimeTransitoSection() {
    if (!_isCrimeTransito) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          'Informações específicas - Crime de Trânsito',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<IntensidadeDano>(
          initialValue: _intensidadeDano,
          decoration: const InputDecoration(labelText: 'Intensidade dos danos'),
          items: IntensidadeDano.values
              .map(
                (dano) => DropdownMenuItem(
                  value: dano,
                  child: Text(switch (dano) {
                    IntensidadeDano.leve => 'Leve',
                    IntensidadeDano.media => 'Média',
                    IntensidadeDano.grave => 'Grave',
                    IntensidadeDano.gravissima => 'Gravíssima',
                  }),
                ),
              )
              .toList(),
          onChanged: (valor) => setState(() => _intensidadeDano = valor),
        ),
        _buildChipGroup<SetorImpacto>(
          valores: SetorImpacto.values,
          selecionados: _setoresImpacto,
          titulo: 'Setor atingido pelo impacto',
          label: (v) => switch (v) {
            SetorImpacto.anterior => 'Anterior',
            SetorImpacto.posterior => 'Posterior',
            SetorImpacto.lateralEsquerdo => 'Lateral esquerdo',
            SetorImpacto.lateralDireito => 'Lateral direito',
            SetorImpacto.angularAnteriorEsquerdo => 'Angular anterior esquerdo',
            SetorImpacto.angularAnteriorDireito => 'Angular anterior direito',
            SetorImpacto.angularPosteriorEsquerdo =>
              'Angular posterior esquerdo',
            SetorImpacto.angularPosteriorDireito => 'Angular posterior direito',
          },
        ),
        _buildChipGroup<TipificacaoDeformacao>(
          valores: TipificacaoDeformacao.values,
          selecionados: _tipificacoes,
          titulo: 'Tipificação das deformações',
          label: (v) => switch (v) {
            TipificacaoDeformacao.amassamento => 'Amassamento',
            TipificacaoDeformacao.cisalhamento => 'Cisalhamento',
            TipificacaoDeformacao.arrastamento => 'Arrastamento',
            TipificacaoDeformacao.empenamento => 'Empenamento',
            TipificacaoDeformacao.arrancamento => 'Arrancamento',
            TipificacaoDeformacao.estampamento => 'Estampamento',
            TipificacaoDeformacao.quebramento => 'Quebramento',
            TipificacaoDeformacao.esmagamento => 'Esmagamento',
            TipificacaoDeformacao.sanfonamento => 'Sanfonamento',
            TipificacaoDeformacao.mossa => 'Mossa',
            TipificacaoDeformacao.atritamento => 'Atritamento',
            TipificacaoDeformacao.afundamento => 'Afundamento',
          },
        ),
        _buildChipGroup<OrientacaoDeformacao>(
          valores: OrientacaoDeformacao.values,
          selecionados: _orientacoes,
          titulo: 'Orientação das deformações',
          label: (v) => switch (v) {
            OrientacaoDeformacao.direitaParaEsquerda => 'Direita → Esquerda',
            OrientacaoDeformacao.esquerdaParaDireita => 'Esquerda → Direita',
            OrientacaoDeformacao.dianteiraParaTraseira =>
              'Dianteira → Traseira',
            OrientacaoDeformacao.traseiraParaDianteira =>
              'Traseira → Dianteira',
          },
        ),
        TextField(
          controller: _danosObservacoesCtrl,
          decoration: const InputDecoration(
            labelText: 'Observações complementares',
          ),
          maxLines: 2,
        ),
        _buildStatusDropdown(
          label: 'Faróis/Lanternas',
          valor: _faroisStatus,
          onChanged: (valor) => setState(() => _faroisStatus = valor),
        ),
        const SizedBox(height: 16),
        _buildStatusDropdown(
          label: 'Cintos de segurança',
          valor: _cintosStatus,
          onChanged: (valor) => setState(() => _cintosStatus = valor),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<EstadoPneumaticos>(
          initialValue: _estadoPneus,
          decoration: const InputDecoration(labelText: 'Pneumáticos'),
          items: EstadoPneumaticos.values
              .map(
                (estado) => DropdownMenuItem(
                  value: estado,
                  child: Text(switch (estado) {
                    EstadoPneumaticos.novos => 'Novos',
                    EstadoPneumaticos.meiaVida => 'Meia vida',
                    EstadoPneumaticos.desgastados => 'Desgastados',
                  }),
                ),
              )
              .toList(),
          onChanged: (valor) => setState(() => _estadoPneus = valor),
        ),
        const SizedBox(height: 16),
        _buildStatusDropdown(
          label: 'Freios',
          valor: _freiosStatus,
          onChanged: (valor) => setState(() => _freiosStatus = valor),
        ),
        const SizedBox(height: 16),
        _buildStatusDropdown(
          label: 'Direção',
          valor: _direcaoStatus,
          onChanged: (valor) => setState(() => _direcaoStatus = valor),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<AirbagStatus>(
          initialValue: _airbagStatus,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Airbag'),
          items: AirbagStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(switch (status) {
                    AirbagStatus.acionado => 'Acionado',
                    AirbagStatus.naoAcionado => 'Não acionado',
                    AirbagStatus.ausente => 'Ausente',
                  }),
                ),
              )
              .toList(),
          onChanged: (valor) => setState(() => _airbagStatus = valor),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<RetrovisorStatus>(
          initialValue: _retrovisorStatus,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Retrovisor'),
          items: RetrovisorStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(
                    status == RetrovisorStatus.presente
                        ? 'Presente'
                        : 'Ausente',
                  ),
                ),
              )
              .toList(),
          onChanged: (valor) => setState(() => _retrovisorStatus = valor),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<TacografoStatus>(
          initialValue: _tacografoStatus,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Disco de tacógrafo',
            hintText: 'Não se aplica se o veículo não possui',
          ),
          items: TacografoStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(switch (status) {
                    TacografoStatus.ausente => 'Ausente',
                    TacografoStatus.recolhido => 'Recolhido',
                    TacografoStatus.naoSeAplica => 'Não se aplica',
                  }),
                ),
              )
              .toList(),
          onChanged: (valor) => setState(() => _tacografoStatus = valor),
        ),
        const SizedBox(height: 16),
        Text(
          'Bicicleta (preencher se aplicável)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        TextField(
          controller: _bicicletaCorCtrl,
          decoration: const InputDecoration(labelText: 'Cor'),
        ),
        TextField(
          controller: _bicicletaModeloCtrl,
          decoration: const InputDecoration(labelText: 'Marca/Modelo'),
        ),
        TextField(
          controller: _bicicletaSinalizacaoCtrl,
          decoration: const InputDecoration(
            labelText: 'Elementos de sinalização',
            helperText: 'Ex.: dianteira, lateral, pedais, traseira',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Possui campainha?'),
          value: _bicicletaPossuiCampainha,
          onChanged: (valor) => setState(() {
            _bicicletaPossuiCampainha = valor;
          }),
        ),
      ],
    );
  }

  Future<void> _adicionarOuEditarVestigio({
    VestigioVeiculoModel? existente,
  }) async {
    final inclusaoContinua = existente == null;

    final resultado = await Navigator.of(context).push<VestigioVeiculoModel>(
      MaterialPageRoute(
        builder: (ctx) => VestigioVeiculoFormScreen(
          fichaId: widget.ficha.id,
          veiculoNumero: widget.veiculo.numero,
          vestigioExistente: existente,
          modoRapido: _modoRapido,
          metodoPosicionamentoPadrao: _metodoPosicionamentoVestigios,
          manterNaTelaAposSalvarNovo: inclusaoContinua,
          onSalvo: inclusaoContinua
              ? (VestigioVeiculoModel v) {
                  if (!mounted) return;
                  setState(() => _vestigios.add(v));
                }
              : null,
        ),
      ),
    );

    if (!mounted) return;

    if (inclusaoContinua) return;

    if (resultado == null) return;

    setState(() {
      final idx = _vestigios.indexWhere((e) => e.id == resultado.id);
      if (idx >= 0) {
        _vestigios[idx] = resultado;
      } else {
        _vestigios.add(resultado);
      }
    });
  }

  void _removerVestigio(String id) {
    setState(() {
      _vestigios.removeWhere((v) => v.id == id);
    });
  }

  Future<String?> _persistirFotoVeiculo(XFile arquivo, String subpasta) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pasta = Directory(
        '${dir.path}/levantamento_fotografico/${widget.ficha.id}/veiculo_${widget.veiculo.numero}/$subpasta',
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
      await PhotoBackupService.saveToGalleryWithFeedback(messenger, destino.path);
      return destino.path;
    } catch (_) {
      return null;
    }
  }

  static String _nomeArquivoFoto(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  void _salvar() {
    if (_fotosVistaVeiculoAmbiente.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adicione ao menos uma foto: Vista do veículo no ambiente.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_localizacaoAmbienteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a localização do veículo no ambiente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final veiculo = _construirVeiculo();
    Navigator.of(context).pop(veiculo);
  }

  Widget _buildDropdown<T extends Enum>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        final labelText = (item as dynamic).label as String;
        return DropdownMenuItem<T>(value: item, child: Text(labelText));
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Veículo ${widget.veiculo.numero}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_modoRapido ? Icons.speed : Icons.speed_outlined),
            style: IconButton.styleFrom(
              backgroundColor: _modoRapido
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              foregroundColor: _modoRapido
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : null,
            ),
            onPressed: () => setState(() {
              _modoRapido = !_modoRapido;
            }),
            tooltip: _modoRapido
                ? 'Desativar modo rápido'
                : 'Ativar modo rápido',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvar,
            tooltip: 'Salvar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fotos da cena (veículo no ambiente)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOTOS DA CENA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Vista do veículo no ambiente *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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
                              imageQuality: 75,
                              maxWidth: 2048,
                              maxHeight: 2048,
                            );
                            if (foto == null || !mounted) return;
                            final path = await _persistirFotoVeiculo(
                              foto,
                              'vista_ambiente',
                            );
                            if (path != null) {
                              setState(
                                () => _fotosVistaVeiculoAmbiente = [
                                  ..._fotosVistaVeiculoAmbiente,
                                  path,
                                ],
                              );
                            }
                          },
                          icon: const Icon(Icons.photo_camera, size: 18),
                          label: const Text('Câmera'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final fotos = await _imagePicker.pickMultiImage(
                              imageQuality: 75,
                              maxWidth: 2048,
                              maxHeight: 2048,
                            );
                            if (fotos.isEmpty || !mounted) return;
                            final novas = <String>[];
                            for (final foto in fotos) {
                              final path = await _persistirFotoVeiculo(
                                foto,
                                'vista_ambiente',
                              );
                              if (path != null) novas.add(path);
                            }
                            if (novas.isNotEmpty) {
                              setState(
                                () => _fotosVistaVeiculoAmbiente = [
                                  ..._fotosVistaVeiculoAmbiente,
                                  ...novas,
                                ],
                              );
                            }
                          },
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text('Galeria'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_fotosVistaVeiculoAmbiente.isEmpty)
                      Text(
                        'Nenhuma foto. Adicione ao menos uma.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      )
                    else
                      ..._fotosVistaVeiculoAmbiente.asMap().entries.map(
                        (e) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.image_outlined, size: 18),
                          title: Text(
                            _nomeArquivoFoto(e.value),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remover foto',
                            onPressed: () {
                              setState(() {
                                _fotosVistaVeiculoAmbiente = List<String>.from(
                                  _fotosVistaVeiculoAmbiente,
                                )..removeAt(e.key);
                              });
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!_modoRapido) ...[
              const SizedBox(height: 16),
              // Identificação Básica
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IDENTIFICAÇÃO BÁSICA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDropdown<TipoVeiculo>(
                        label: 'Tipo de veículo',
                        value: _tipoVeiculo,
                        items: TipoVeiculo.values,
                        onChanged: (v) {
                          setState(() {
                            _tipoVeiculo = v;
                            if (v != TipoVeiculo.outro) {
                              _tipoVeiculoOutroCtrl.clear();
                            }
                          });
                        },
                      ),
                      if (_tipoVeiculo == TipoVeiculo.outro) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _tipoVeiculoOutroCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Especifique o tipo',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _marcaModeloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Marca/Modelo',
                          border: OutlineInputBorder(),
                          hintText: 'Ex: Ford Ka, Honda CG 160',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _anoFabricacaoCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Ano de Fabricação',
                                border: OutlineInputBorder(),
                                hintText: 'Ex: 2020',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _anoModeloCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Ano Modelo',
                                border: OutlineInputBorder(),
                                hintText: 'Ex: 2021',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _corCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cor',
                                border: OutlineInputBorder(),
                                hintText: 'Ex: Branco, Prata',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _placaCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Placa (opcional)',
                                border: OutlineInputBorder(),
                                hintText: 'ABC-1234',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Situação e posicionamento do veículo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modoRapido
                          ? 'LEGENDA DO VEÍCULO'
                          : 'SITUAÇÃO E POSICIONAMENTO DO VEÍCULO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _localizacaoAmbienteCtrl,
                      decoration: InputDecoration(
                        labelText: _modoRapido
                            ? 'Legenda / posição do veículo *'
                            : 'Situação e posicionamento no local *',
                        border: const OutlineInputBorder(),
                        hintText: _modoRapido
                            ? 'Ex: veículo na varanda, junto ao corpo.'
                            : 'Ex: estacionado no acostamento, sentido norte-sul, parcialmente sobre a calçada, tombado sobre o lado direito',
                      ),
                      maxLines: 2,
                    ),
                    if (!_modoRapido) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _condicaoGeralCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Condição geral',
                          border: OutlineInputBorder(),
                          hintText:
                              'Ex: avarias na lateral esquerda e para-choque dianteiro deslocado',
                        ),
                        maxLines: 3,
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_modoRapido)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Registrar coordenadas do veículo'),
                        value: _registrarCoordenadasRapido,
                        onChanged: (value) => setState(() {
                          _registrarCoordenadasRapido = value;
                          if (!value) {
                            _coordenadaFrenteXCtrl.clear();
                            _coordenadaFrenteYCtrl.clear();
                            _alturaFrenteCtrl.clear();
                            _coordenadaTraseiraXCtrl.clear();
                            _coordenadaTraseiraYCtrl.clear();
                            _alturaTraseiraCtrl.clear();
                            _coordenadaCentroXCtrl.clear();
                            _coordenadaCentroYCtrl.clear();
                            _alturaCentroCtrl.clear();
                          }
                        }),
                      ),
                    if (!_modoRapido || _registrarCoordenadasRapido) ...[
                      Text(
                        'Coordenadas (opcionais)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Coordenadas da Frente
                      Text(
                        'Frente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _coordenadaFrenteXCtrl,
                              decoration: const InputDecoration(
                                labelText: 'X',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Ex: -23,5',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _coordenadaFrenteYCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Y',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Ex: -46,6',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _alturaFrenteCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Altura',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Ex: 0.5 m',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Coordenadas da Traseira
                      Text(
                        'Traseira',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _coordenadaTraseiraXCtrl,
                              decoration: const InputDecoration(
                                labelText: 'X',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Ex: -23,5',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _coordenadaTraseiraYCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Y',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Ex: -46,6',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _alturaTraseiraCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Altura',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Ex: 0.5 m',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Coordenadas do Centro
                      Text(
                        'Centro',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _coordenadaCentroXCtrl,
                              decoration: const InputDecoration(
                                labelText: 'X',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Ex: -23,5',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _coordenadaCentroYCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Y',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Ex: -46,6',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _alturaCentroCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Altura',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Ex: 0.5 m',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Vestígios/Evidências
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'VESTÍGIOS/EVIDÊNCIAS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _adicionarOuEditarVestigio,
                          tooltip: 'Adicionar vestígio',
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<MetodoPosicionamentoVestigio>(
                      initialValue: _metodoPosicionamentoVestigios,
                      decoration: const InputDecoration(
                        labelText: 'Método de posicionamento dos vestígios',
                        border: OutlineInputBorder(),
                        isDense: true,
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
                        setState(() => _metodoPosicionamentoVestigios = value);
                      },
                    ),
                    if (_metodoPosicionamentoVestigios ==
                        MetodoPosicionamentoVestigio.gps) ...[
                      const SizedBox(height: 8),
                      Text(
                        'O GPS pode apresentar variação relevante em locais cobertos ou de difícil recepção.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_vestigios.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nenhum vestígio cadastrado',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._vestigios.map((vestigio) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    vestigio.rotuloNomeDescricao.isEmpty
                                        ? 'Vestígio'
                                        : vestigio.rotuloNomeDescricao,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (vestigio.isSangueHumano)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Sangue',
                                      style: TextStyle(
                                        color: Colors.red.shade900,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (vestigio.fotosPaths.isNotEmpty)
                                  Text(
                                    '${vestigio.fotosPaths.length} foto(s)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                if ((vestigio.descricao ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    'Legenda: ${vestigio.descricao!.trim()}',
                                  ),
                                if (vestigio.localizacao != null)
                                  Text('Local: ${vestigio.localizacao}'),
                                Text(_resumoPosicionamentoVestigio(vestigio)),
                                if (vestigio.numerosFotografias?.isNotEmpty ==
                                    true)
                                  Text(
                                    'Fotografia(s): ${vestigio.numerosFotografias!.map((n) => n.toString().padLeft(2, '0')).join(', ')}',
                                  ),
                                if (vestigio.tipoAcao != null)
                                  Text('Tipo: ${vestigio.tipoAcao!.label}'),
                                if (vestigio.tipoAcao ==
                                        TipoAcaoVestigioVeiculo.coletado &&
                                    vestigio.coletadoPor != null)
                                  Text('Coletado por: ${vestigio.coletadoPor}'),
                                if (vestigio.dataHoraColeta != null)
                                  Text('Data/Hora: ${vestigio.dataHoraColeta}'),
                                if (vestigio.tipoDestino != null &&
                                    vestigio.destinoId != null)
                                  FutureBuilder<dynamic>(
                                    future:
                                        vestigio.tipoDestino ==
                                            TipoDestinoVestigioVeiculo.unidade
                                        ? _unidadeService.listarUnidades()
                                        : _laboratorioService
                                              .listarLaboratorios(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        final lista = snapshot.data as List;
                                        final items = lista.where(
                                          (item) =>
                                              item.id == vestigio.destinoId,
                                        );
                                        if (items.isNotEmpty) {
                                          final item = items.first;
                                          final nome =
                                              vestigio.tipoDestino ==
                                                  TipoDestinoVestigioVeiculo
                                                      .unidade
                                              ? (item as UnidadeModel).nome
                                              : (item as LaboratorioModel).nome;
                                          return Text(
                                            'Destino: ${vestigio.tipoDestino!.label} - $nome',
                                          );
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _adicionarOuEditarVestigio(
                                    existente: vestigio,
                                  ),
                                  tooltip: 'Editar',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  onPressed: () =>
                                      _removerVestigio(vestigio.id),
                                  tooltip: 'Excluir',
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (!_modoRapido) ...[
              _buildCrimeTransitoSection(),

              // Relacionamento com o caso (oculto em acidente de trânsito)
              if (widget.ficha.tipoOcorrencia == TipoOcorrencia.crimeTransito)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      controller: _observacoesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observações',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RELACIONAMENTO COM O CASO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildDropdown<RelacaoVeiculo>(
                          label: 'Relação',
                          value: _relacao,
                          items: RelacaoVeiculo.values,
                          onChanged: (v) => setState(() => _relacao = v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _observacoesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Observações',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _salvar,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: const Text('Salvar Veículo'),
          ),
        ),
      ),
    );
  }
}
