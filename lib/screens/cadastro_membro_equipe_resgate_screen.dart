import 'package:flutter/material.dart';

import '../models/equipe_resgate_model.dart';
import '../models/membro_equipe_resgate_model.dart';
import '../utils/equipe_hierarchy.dart';

class CadastroMembroEquipeResgateScreen extends StatefulWidget {
  final TipoEquipeResgate tipoEquipe;
  final MembroEquipeResgateModel? membroExistente;

  const CadastroMembroEquipeResgateScreen({
    super.key,
    required this.tipoEquipe,
    this.membroExistente,
  });

  @override
  State<CadastroMembroEquipeResgateScreen> createState() =>
      _CadastroMembroEquipeResgateScreenState();
}

class _CadastroMembroEquipeResgateScreenState
    extends State<CadastroMembroEquipeResgateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cargoController = TextEditingController();
  final _matriculaController = TextEditingController();
  final _crmController = TextEditingController();
  bool _ehMedico = false;
  String? _graduacaoCbmSelecionada;

  bool get _usaDropdownCbm => widget.tipoEquipe == TipoEquipeResgate.cbm;

  @override
  void initState() {
    super.initState();
    if (widget.membroExistente != null) {
      _nomeController.text = widget.membroExistente!.nome;
      _cargoController.text = widget.membroExistente!.cargo ?? '';
      _matriculaController.text = widget.membroExistente!.matricula ?? '';
      _crmController.text = widget.membroExistente!.crm ?? '';
      _ehMedico =
          widget.membroExistente!.crm != null &&
          widget.membroExistente!.crm!.isNotEmpty;
      if (EquipeHierarchy.graduacoesMilitaresBaixoParaCima.contains(
        widget.membroExistente!.cargo,
      )) {
        _graduacaoCbmSelecionada = widget.membroExistente!.cargo;
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cargoController.dispose();
    _matriculaController.dispose();
    _crmController.dispose();
    super.dispose();
  }

  void _salvarMembro() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final cargo = _usaDropdownCbm
        ? _graduacaoCbmSelecionada
        : (_cargoController.text.trim().isEmpty
              ? null
              : _cargoController.text.trim());

    final membro = MembroEquipeResgateModel(
      id:
          widget.membroExistente?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      nome: _nomeController.text.trim(),
      cargo: cargo,
      matricula: _matriculaController.text.trim().isEmpty
          ? null
          : _matriculaController.text.trim(),
      crm: _ehMedico && _crmController.text.trim().isNotEmpty
          ? _crmController.text.trim()
          : null,
      unidadeNumero: null,
    );

    Navigator.of(context).pop(membro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.membroExistente == null ? 'Adicionar Membro' : 'Editar Membro',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  hintText: 'Nome completo',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, informe o nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_usaDropdownCbm)
                DropdownButtonFormField<String>(
                  initialValue: _graduacaoCbmSelecionada,
                  decoration: const InputDecoration(
                    labelText: 'Posto/Graduação *',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: EquipeHierarchy.graduacoesMilitaresBaixoParaCima
                      .map(
                        (opcao) => DropdownMenuItem<String>(
                          value: opcao,
                          child: Text(opcao),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _graduacaoCbmSelecionada = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, informe o posto/graduação';
                    }
                    return null;
                  },
                )
              else
                TextFormField(
                  controller: _cargoController,
                  decoration: const InputDecoration(
                    labelText: 'Cargo/Função',
                    hintText: 'Ex: Médico, Enfermeiro, Técnico',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _matriculaController,
                decoration: InputDecoration(
                  labelText: widget.tipoEquipe == TipoEquipeResgate.cbm
                      ? 'RG'
                      : 'Matrícula',
                  hintText: widget.tipoEquipe == TipoEquipeResgate.cbm
                      ? 'Número do RG'
                      : 'Número de matrícula',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.tipoEquipe != TipoEquipeResgate.cbm)
                CheckboxListTile(
                  title: const Text('É médico?'),
                  value: _ehMedico,
                  onChanged: (value) {
                    setState(() {
                      _ehMedico = value ?? false;
                      if (!_ehMedico) {
                        _crmController.clear();
                      }
                    });
                  },
                ),
              if (_ehMedico && widget.tipoEquipe != TipoEquipeResgate.cbm) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _crmController,
                  decoration: const InputDecoration(
                    labelText: 'CRM *',
                    hintText: 'Número do CRM',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_ehMedico && (value == null || value.trim().isEmpty)) {
                      return 'Por favor, informe o CRM';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _salvarMembro,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
