import 'package:flutter/material.dart';
import '../models/membro_equipe_policial_model.dart';
import '../models/tipo_equipe_policial.dart';

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
  final _postoGraduacaoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.membroExistente != null) {
      _nomeController.text = widget.membroExistente!.nome;
      _matriculaController.text = widget.membroExistente!.matricula;
      _postoGraduacaoController.text = widget.membroExistente!.postoGraduacao ?? '';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _matriculaController.dispose();
    _postoGraduacaoController.dispose();
    super.dispose();
  }

  void _salvarMembro() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final id = widget.membroExistente?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // PM e Bombeiros precisam de posto/graduação
    final precisaPostoGraduacao = widget.tipoEquipe == TipoEquipePolicial.policiaMilitar ||
        widget.tipoEquipe == TipoEquipePolicial.bombeiros;

    final membro = MembroEquipePolicialModel(
      id: id,
      nome: _nomeController.text.trim(),
      matricula: _matriculaController.text.trim(),
      postoGraduacao: precisaPostoGraduacao
          ? (_postoGraduacaoController.text.trim().isEmpty
              ? null
              : _postoGraduacaoController.text.trim())
          : null,
    );

    Navigator.of(context).pop(membro);
  }

  @override
  Widget build(BuildContext context) {
    // PM e Bombeiros precisam de posto/graduação
    final precisaPostoGraduacao = widget.tipoEquipe == TipoEquipePolicial.policiaMilitar ||
        widget.tipoEquipe == TipoEquipePolicial.bombeiros;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.membroExistente != null ? 'Editar Membro' : 'Adicionar Membro'),
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
              if (precisaPostoGraduacao) ...[
                TextFormField(
                  controller: _postoGraduacaoController,
                  decoration: InputDecoration(
                    labelText: widget.tipoEquipe == TipoEquipePolicial.bombeiros
                        ? 'Posto/Graduação (Bombeiro)'
                        : 'Posto/Graduação',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge),
                    hintText: widget.tipoEquipe == TipoEquipePolicial.bombeiros
                        ? 'Ex: Major, Capitão, Tenente'
                        : 'Ex: Capitão, Tenente, Sargento',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: precisaPostoGraduacao
                      ? 'Nome (informar Posto/Graduação e nome)'
                      : 'Nome',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
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
                decoration: const InputDecoration(
                  labelText: 'Matrícula',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, informe a matrícula';
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
                child: Text(widget.membroExistente != null
                    ? 'Salvar Alterações'
                    : 'Adicionar Membro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

