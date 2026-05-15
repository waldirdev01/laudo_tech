import 'package:flutter/material.dart';

import '../models/membro_equipe_policial_model.dart';
import '../models/tipo_equipe_policial.dart';
import '../utils/equipe_hierarchy.dart';

class CadastroMembroEquipePolicialScreen extends StatefulWidget {
  final TipoEquipePolicial tipoEquipe;
  final MembroEquipePolicialModel? membroExistente;

  const CadastroMembroEquipePolicialScreen({
    super.key,
    required this.tipoEquipe,
    this.membroExistente,
  });

  @override
  State<CadastroMembroEquipePolicialScreen> createState() =>
      _CadastroMembroEquipePolicialScreenState();
}

class _CadastroMembroEquipePolicialScreenState
    extends State<CadastroMembroEquipePolicialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _matriculaController = TextEditingController();
  final _qualificacaoController = TextEditingController();
  String? _qualificacaoSelecionada;

  bool get _usaDropdownQualificacao =>
      widget.tipoEquipe == TipoEquipePolicial.policiaMilitar ||
      widget.tipoEquipe == TipoEquipePolicial.policiaCivil;

  List<String> get _opcoesQualificacao {
    switch (widget.tipoEquipe) {
      case TipoEquipePolicial.policiaMilitar:
        return EquipeHierarchy.graduacoesMilitaresBaixoParaCima;
      case TipoEquipePolicial.policiaCivil:
        return EquipeHierarchy.cargosPoliciaCivil;
      case TipoEquipePolicial.prf:
      case TipoEquipePolicial.gcm:
      case TipoEquipePolicial.outros:
        return const [];
    }
  }

  bool get _exigeQualificacao =>
      widget.tipoEquipe == TipoEquipePolicial.policiaMilitar ||
      widget.tipoEquipe == TipoEquipePolicial.policiaCivil;

  bool get _ocultaQualificacao => widget.tipoEquipe == TipoEquipePolicial.gcm;

  String get _rotuloQualificacao {
    switch (widget.tipoEquipe) {
      case TipoEquipePolicial.policiaMilitar:
      case TipoEquipePolicial.prf:
        return 'Posto/Graduação';
      case TipoEquipePolicial.policiaCivil:
        return 'Cargo';
      case TipoEquipePolicial.gcm:
        return 'Qualificação';
      case TipoEquipePolicial.outros:
        return 'Cargo/Função';
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.membroExistente != null) {
      _nomeController.text = widget.membroExistente!.nome;
      _matriculaController.text = widget.membroExistente!.matricula;
      _qualificacaoController.text =
          widget.membroExistente!.postoGraduacao ?? '';
      if (_opcoesQualificacao.contains(
        widget.membroExistente!.postoGraduacao,
      )) {
        _qualificacaoSelecionada = widget.membroExistente!.postoGraduacao;
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _matriculaController.dispose();
    _qualificacaoController.dispose();
    super.dispose();
  }

  void _salvarMembro() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final id =
        widget.membroExistente?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final qualificacao = _ocultaQualificacao
        ? null
        : _usaDropdownQualificacao
        ? _qualificacaoSelecionada
        : (_qualificacaoController.text.trim().isEmpty
              ? null
              : _qualificacaoController.text.trim());

    final membro = MembroEquipePolicialModel(
      id: id,
      nome: _nomeController.text.trim(),
      matricula: _matriculaController.text.trim(),
      postoGraduacao: qualificacao,
    );

    Navigator.of(context).pop(membro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.membroExistente != null ? 'Editar Membro' : 'Adicionar Membro',
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              if (!_ocultaQualificacao) ...[
                if (_usaDropdownQualificacao)
                  DropdownButtonFormField<String>(
                    initialValue: _qualificacaoSelecionada,
                    decoration: InputDecoration(
                      labelText:
                          '$_rotuloQualificacao${_exigeQualificacao ? ' *' : ''}',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.badge),
                    ),
                    isExpanded: true,
                    items: _opcoesQualificacao
                        .map(
                          (opcao) => DropdownMenuItem<String>(
                            value: opcao,
                            child: Text(opcao),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _qualificacaoSelecionada = value);
                    },
                    validator: (value) {
                      if (_exigeQualificacao &&
                          (value == null || value.isEmpty)) {
                        return 'Por favor, informe $_rotuloQualificacao';
                      }
                      return null;
                    },
                  )
                else
                  TextFormField(
                    controller: _qualificacaoController,
                    decoration: InputDecoration(
                      labelText: _rotuloQualificacao,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.badge),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, informe o nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _matriculaController,
                decoration: InputDecoration(
                  labelText:
                      widget.tipoEquipe == TipoEquipePolicial.policiaMilitar
                      ? 'RG'
                      : 'Matrícula',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return widget.tipoEquipe ==
                            TipoEquipePolicial.policiaMilitar
                        ? 'Por favor, informe o RG'
                        : 'Por favor, informe a matrícula';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _salvarMembro,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: Text(
                  widget.membroExistente != null
                      ? 'Salvar Alterações'
                      : 'Adicionar Membro',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
