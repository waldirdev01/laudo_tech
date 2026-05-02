import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';

class CadastroEnvolvidoTransitoScreen extends StatefulWidget {
  final CrimeTransitoEnvolvidoModel envolvido;
  final FichaCompletaModel ficha;

  const CadastroEnvolvidoTransitoScreen({
    super.key,
    required this.envolvido,
    required this.ficha,
  });

  @override
  State<CadastroEnvolvidoTransitoScreen> createState() =>
      _CadastroEnvolvidoTransitoScreenState();
}

class _CadastroEnvolvidoTransitoScreenState
    extends State<CadastroEnvolvidoTransitoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _nomeCtrl = TextEditingController();
  final _cnhCtrl = TextEditingController();
  final _cnhValidadeCtrl = TextEditingController();
  final _cnhCategoriaCtrl = TextEditingController();
  final _rgCtrl = TextEditingController();
  final _dataNascimentoCtrl = TextEditingController();
  final _posicaoDetalheCtrl = TextEditingController();
  final _vestesObsCtrl = TextEditingController();
  final _calcadosObsCtrl = TextEditingController();
  final _pertencesObsCtrl = TextEditingController();
  final _pertencesEntregueCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  CrimeTransitoClassificacaoEnvolvido? _classificacao;
  final Set<CrimeTransitoEquipamentoSeguranca> _equipamentos = {};
  CrimeTransitoSituacaoEnvolvido? _situacao;
  CrimeTransitoPosicaoEnvolvido? _posicao;
  bool? _calcadosIntegro;
  bool _pertencesEncontrados = false;
  DestinoPertences? _destinoPertences;
  bool _salvando = false;

  List<String> _fotosVistaAmplaPosicao = [];
  List<String> _fotosVistaAmplaCenario = [];
  List<String> _fotosLesoesPertences = [];

  @override
  void initState() {
    super.initState();
    final envolvido = widget.envolvido;
    _nomeCtrl.text = envolvido.nome ?? '';
    _cnhCtrl.text = envolvido.cnh ?? '';
    _cnhValidadeCtrl.text = envolvido.cnhValidade ?? '';
    _cnhCategoriaCtrl.text = envolvido.cnhCategoria ?? '';
    _rgCtrl.text = envolvido.rg ?? '';
    _dataNascimentoCtrl.text = envolvido.dataNascimento ?? '';
    _posicaoDetalheCtrl.text = envolvido.posicaoDetalhe ?? '';
    _vestesObsCtrl.text = envolvido.vestes?.observacoes ?? '';
    _calcadosObsCtrl.text = envolvido.calcados?.observacoes ?? '';
    _pertencesObsCtrl.text = envolvido.pertencesDescricao ?? '';
    _pertencesEntregueCtrl.text = envolvido.pertencesEntregueIdentificacao ?? '';
    _observacoesCtrl.text = envolvido.observacoes ?? '';
    _classificacao = envolvido.classificacao;
    _equipamentos.addAll(envolvido.equipamentosSeguranca ?? const []);
    _situacao = envolvido.situacao;
    _posicao = envolvido.posicao;
    _calcadosIntegro = envolvido.calcados?.integro;
    _pertencesEncontrados = envolvido.pertencesEncontrados ?? false;
    _destinoPertences = envolvido.destinoPertences;
    _fotosVistaAmplaPosicao =
        List<String>.from(envolvido.fotosVistaAmplaPosicaoEncontrado ?? []);
    _fotosVistaAmplaCenario =
        List<String>.from(envolvido.fotosVistaAmplaCenario ?? []);
    _fotosLesoesPertences =
        List<String>.from(envolvido.fotosLesoesPertences ?? []);
  }

  Future<String?> _persistirFoto(XFile foto, String subpasta) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final pasta = Directory(
        '${dir.path}/levantamento_transito/${widget.ficha.id}/envolvido_${widget.envolvido.id}/$subpasta',
      );
      if (!await pasta.exists()) await pasta.create(recursive: true);
      final nome = 'foto_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final destino = File('${pasta.path}/$nome');
      final bytes = await foto.readAsBytes();
      await destino.writeAsBytes(bytes);
      return destino.path;
    } catch (_) {
      return null;
    }
  }

  Widget _buildGrupoFotos({
    required String titulo,
    required String subpasta,
    required List<String> fotos,
    required ValueChanged<List<String>> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
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
                    if (foto == null || !mounted) return;
                    final path = await _persistirFoto(foto, subpasta);
                    if (path != null) {
                      setState(() {
                        fotos.add(path);
                        onChanged(List.from(fotos));
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
                      if (path != null) fotos.add(path);
                    }
                    setState(() => onChanged(List.from(fotos)));
                  },
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Galeria'),
                ),
              ],
            ),
            if (fotos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fotos.asMap().entries.map((e) {
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
                                errorBuilder: (_, _, _) => _thumbQuebrado(),
                              )
                            : _thumbQuebrado(),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              fotos.removeAt(e.key);
                              onChanged(List.from(fotos));
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _thumbQuebrado() {
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

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cnhCtrl.dispose();
    _cnhValidadeCtrl.dispose();
    _cnhCategoriaCtrl.dispose();
    _rgCtrl.dispose();
    _dataNascimentoCtrl.dispose();
    _posicaoDetalheCtrl.dispose();
    _vestesObsCtrl.dispose();
    _calcadosObsCtrl.dispose();
    _pertencesObsCtrl.dispose();
    _pertencesEntregueCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  void _alternarEquipamento(CrimeTransitoEquipamentoSeguranca equipamento) {
    setState(() {
      if (_equipamentos.contains(equipamento)) {
        _equipamentos.remove(equipamento);
      } else {
        _equipamentos.add(equipamento);
      }
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    final envolvidoAtualizado = widget.envolvido.copyWith(
      nome: _nomeCtrl.text.trim().isEmpty ? null : _nomeCtrl.text.trim(),
      cnh: _cnhCtrl.text.trim().isEmpty ? null : _cnhCtrl.text.trim(),
      cnhValidade: _cnhValidadeCtrl.text.trim().isEmpty
          ? null
          : _cnhValidadeCtrl.text.trim(),
      cnhCategoria: _cnhCategoriaCtrl.text.trim().isEmpty
          ? null
          : _cnhCategoriaCtrl.text.trim(),
      rg: _rgCtrl.text.trim().isEmpty ? null : _rgCtrl.text.trim(),
      dataNascimento: _dataNascimentoCtrl.text.trim().isEmpty
          ? null
          : _dataNascimentoCtrl.text.trim(),
      classificacao: _classificacao,
      equipamentosSeguranca: _equipamentos.toList(),
      situacao: _situacao,
      posicao: _posicao,
      posicaoDetalhe: _posicaoDetalheCtrl.text.trim().isEmpty
          ? null
          : _posicaoDetalheCtrl.text.trim(),
      vestes: _vestesObsCtrl.text.trim().isEmpty
          ? null
          : IntegridadeItemModel(
              integro: null,
              observacoes: _vestesObsCtrl.text.trim(),
            ),
      calcados:
          (_calcadosIntegro == null && _calcadosObsCtrl.text.trim().isEmpty)
              ? null
              : IntegridadeItemModel(
                  integro: _calcadosIntegro,
                  observacoes: _calcadosObsCtrl.text.trim().isEmpty
                      ? null
                      : _calcadosObsCtrl.text.trim(),
                ),
      pertencesEncontrados: _pertencesEncontrados,
      pertencesDescricao: (_pertencesEncontrados && _pertencesObsCtrl.text.trim().isNotEmpty)
          ? _pertencesObsCtrl.text.trim()
          : null,
      destinoPertences: _pertencesEncontrados ? _destinoPertences : null,
      pertencesEntregueIdentificacao: (_pertencesEncontrados &&
              _destinoPertences == DestinoPertences.entregueAPessoa &&
              _pertencesEntregueCtrl.text.trim().isNotEmpty)
          ? _pertencesEntregueCtrl.text.trim()
          : null,
      observacoes: _observacoesCtrl.text.trim().isEmpty
          ? null
          : _observacoesCtrl.text.trim(),
      fotosVistaAmplaPosicaoEncontrado: _fotosVistaAmplaPosicao.isEmpty
          ? null
          : _fotosVistaAmplaPosicao,
      fotosVistaAmplaCenario: _fotosVistaAmplaCenario.isEmpty
          ? null
          : _fotosVistaAmplaCenario,
      fotosLesoesPertences: _fotosLesoesPertences.isEmpty
          ? null
          : _fotosLesoesPertences,
    );

    if (!mounted) return;
    Navigator.of(context).pop(envolvidoAtualizado);
  }

  Widget _buildEquipamentos() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: CrimeTransitoEquipamentoSeguranca.values
          .map(
            (equip) => FilterChip(
              label: Text(
                switch (equip) {
                  CrimeTransitoEquipamentoSeguranca.cinto => 'Cinto',
                  CrimeTransitoEquipamentoSeguranca.capacete => 'Capacete',
                  CrimeTransitoEquipamentoSeguranca.nenhum => 'Nenhum',
                  CrimeTransitoEquipamentoSeguranca.naoSeAplica =>
                    'Não se aplica',
                },
              ),
              selected: _equipamentos.contains(equip),
              onSelected: (_) => _alternarEquipamento(equip),
            ),
          )
          .toList(),
    );
  }

  Widget _buildIntegridadeField({
    required String titulo,
    required bool? valor,
    required ValueChanged<bool?> onChanged,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<bool?>(
          initialValue: valor,
          decoration: InputDecoration(labelText: titulo),
          items: const [
            DropdownMenuItem(value: null, child: Text('Não informado')),
            DropdownMenuItem(value: true, child: Text('Íntegros')),
            DropdownMenuItem(value: false, child: Text('Não íntegros')),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Detalhes (se não íntegros)',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Envolvido'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvar,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fotografias',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildGrupoFotos(
                titulo: 'Vista ampla do cenário',
                subpasta: 'vista_ampla_cenario',
                fotos: _fotosVistaAmplaCenario,
                onChanged: (v) => setState(() => _fotosVistaAmplaCenario = v),
              ),
              _buildGrupoFotos(
                titulo: 'Vista ampla na posição em que foi encontrado',
                subpasta: 'vista_ampla_posicao',
                fotos: _fotosVistaAmplaPosicao,
                onChanged: (v) => setState(() => _fotosVistaAmplaPosicao = v),
              ),
              _buildGrupoFotos(
                titulo: 'Lesões e pertences',
                subpasta: 'lesoes_pertences',
                fotos: _fotosLesoesPertences,
                onChanged: (v) => setState(() => _fotosLesoesPertences = v),
              ),
              const SizedBox(height: 20),
              Text(
                'Dados do envolvido',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome (opcional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cnhCtrl,
                decoration: const InputDecoration(labelText: 'CNH n.º'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cnhValidadeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Validade CNH'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cnhCategoriaCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Categoria CNH'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rgCtrl,
                decoration: const InputDecoration(labelText: 'RG'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dataNascimentoCtrl,
                decoration:
                    const InputDecoration(labelText: 'Data de nascimento'),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<CrimeTransitoClassificacaoEnvolvido>(
                initialValue: _classificacao,
                decoration: const InputDecoration(labelText: 'Classificação'),
                items: CrimeTransitoClassificacaoEnvolvido.values
                    .map(
                      (valor) => DropdownMenuItem(
                        value: valor,
                        child: Text(
                          switch (valor) {
                            CrimeTransitoClassificacaoEnvolvido.condutor =>
                              'Condutor',
                            CrimeTransitoClassificacaoEnvolvido.passageiro =>
                              'Passageiro',
                            CrimeTransitoClassificacaoEnvolvido.pedestre =>
                              'Pedestre',
                          },
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (valor) => setState(() => _classificacao = valor),
              ),
              const SizedBox(height: 12),
              Text('Equipamentos de segurança',
                  style: Theme.of(context).textTheme.titleSmall),
              _buildEquipamentos(),
              const SizedBox(height: 20),
              RadioGroup<CrimeTransitoSituacaoEnvolvido>(
                groupValue: _situacao,
                onChanged: (v) => setState(() => _situacao = v),
                child: Column(
                  children: CrimeTransitoSituacaoEnvolvido.values
                      .map(
                        (valor) =>
                            RadioListTile<CrimeTransitoSituacaoEnvolvido>(
                          title: Text(
                            switch (valor) {
                              CrimeTransitoSituacaoEnvolvido.semFerimentos =>
                                'Sem ferimentos',
                              CrimeTransitoSituacaoEnvolvido.feridoGrave =>
                                'Ferido grave (hospital)',
                              CrimeTransitoSituacaoEnvolvido.obito => 'Óbito',
                            },
                          ),
                          value: valor,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              RadioGroup<CrimeTransitoPosicaoEnvolvido>(
                groupValue: _posicao,
                onChanged: (v) => setState(() => _posicao = v),
                child: Column(
                  children: CrimeTransitoPosicaoEnvolvido.values
                      .map(
                        (valor) =>
                            RadioListTile<CrimeTransitoPosicaoEnvolvido>(
                          title: Text(
                            switch (valor) {
                              CrimeTransitoPosicaoEnvolvido.interiorVeiculo =>
                                'No interior do veículo',
                              CrimeTransitoPosicaoEnvolvido.leitoVia =>
                                'No leito da via',
                              CrimeTransitoPosicaoEnvolvido.exteriorPista =>
                                'Exterior à pista',
                            },
                          ),
                          value: valor,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _posicaoDetalheCtrl,
                decoration: const InputDecoration(
                  labelText: 'Detalhe da posição (ex.: banco traseiro direito)',
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _vestesObsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vestes',
                  hintText: 'Descreva as vestes do envolvido',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _buildIntegridadeField(
                titulo: 'Calçados (íntegro / não íntegro)',
                valor: _calcadosIntegro,
                onChanged: (valor) => setState(() => _calcadosIntegro = valor),
                controller: _calcadosObsCtrl,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Pertences encontrados'),
                value: _pertencesEncontrados,
                onChanged: (v) => setState(() => _pertencesEncontrados = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_pertencesEncontrados) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _pertencesObsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição dos pertences',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Destino dos pertences',
                    style: Theme.of(context).textTheme.bodyMedium),
                RadioGroup<DestinoPertences>(
                  groupValue: _destinoPertences,
                  onChanged: (v) => setState(() => _destinoPertences = v),
                  child: Column(
                    children: [
                      RadioListTile<DestinoPertences>(
                        title: const Text('Recolhido'),
                        value: DestinoPertences.recolhido,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<DestinoPertences>(
                        title: const Text('Entregue a alguém'),
                        value: DestinoPertences.entregueAPessoa,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                if (_destinoPertences == DestinoPertences.entregueAPessoa) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pertencesEntregueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Identificação da pessoa',
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _observacoesCtrl,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Observações gerais'),
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
                  label: Text(_salvando ? 'Salvando...' : 'Salvar envolvido'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
