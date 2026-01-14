import 'package:flutter/material.dart';

import '../models/equipe_resgate_model.dart';
import '../models/membro_equipe_resgate_model.dart';
import 'cadastro_membro_equipe_resgate_screen.dart';

class CadastroEquipeResgateScreen extends StatefulWidget {
  final EquipeResgateModel? equipeExistente;

  const CadastroEquipeResgateScreen({super.key, this.equipeExistente});

  @override
  State<CadastroEquipeResgateScreen> createState() =>
      _CadastroEquipeResgateScreenState();
}

class _CadastroEquipeResgateScreenState
    extends State<CadastroEquipeResgateScreen> {
  TipoEquipeResgate? _tipoSelecionado;
  final _outrosTipoController = TextEditingController();
  final _unidadeController = TextEditingController();
  List<MembroEquipeResgateModel> _membros = [];
  bool _naoEstavaNoLocal = false;

  @override
  void initState() {
    super.initState();
    if (widget.equipeExistente != null) {
      _tipoSelecionado = widget.equipeExistente!.tipo;
      _outrosTipoController.text = widget.equipeExistente!.outrosTipo ?? '';
      _unidadeController.text = widget.equipeExistente!.unidadeNumero ?? '';
      _membros = List.from(widget.equipeExistente!.membros);
      _naoEstavaNoLocal = widget.equipeExistente!.naoEstavaNoLocal;
    }
  }

  @override
  void dispose() {
    _outrosTipoController.dispose();
    _unidadeController.dispose();
    super.dispose();
  }

  Future<void> _adicionarMembro() async {
    if (_tipoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione o tipo de equipe primeiro'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            CadastroMembroEquipeResgateScreen(tipoEquipe: _tipoSelecionado!),
      ),
    );

    if (resultado != null && resultado is MembroEquipeResgateModel) {
      setState(() {
        _membros.add(resultado);
      });
    }
  }

  void _editarMembro(int index) async {
    final membro = _membros[index];
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CadastroMembroEquipeResgateScreen(
          tipoEquipe: _tipoSelecionado!,
          membroExistente: membro,
        ),
      ),
    );

    if (resultado != null && resultado is MembroEquipeResgateModel) {
      setState(() {
        _membros[index] = resultado;
      });
    }
  }

  void _removerMembro(int index) {
    setState(() {
      _membros.removeAt(index);
    });
  }

  void _salvarEquipe() {
    if (_tipoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione o tipo de equipe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_tipoSelecionado == TipoEquipeResgate.outros &&
        _outrosTipoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe o tipo de equipe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final equipe = EquipeResgateModel(
      tipo: _tipoSelecionado!,
      outrosTipo: _tipoSelecionado == TipoEquipeResgate.outros
          ? _outrosTipoController.text.trim()
          : null,
      unidadeNumero: _unidadeController.text.trim().isEmpty
          ? null
          : _unidadeController.text.trim(),
      membros: _membros,
      naoEstavaNoLocal: _naoEstavaNoLocal,
    );

    Navigator.of(context).pop(equipe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.equipeExistente == null
              ? 'Adicionar Equipe de Resgate'
              : 'Editar Equipe de Resgate',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tipo de equipe
            DropdownButtonFormField<TipoEquipeResgate>(
              initialValue: _tipoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Tipo de Equipe *',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: TipoEquipeResgate.values.map((tipo) {
                return DropdownMenuItem(
                  value: tipo,
                  child: Text(tipo.label, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _tipoSelecionado = value;
                  if (value != TipoEquipeResgate.outros) {
                    _outrosTipoController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            // Campo "Outros" se necessário
            if (_tipoSelecionado == TipoEquipeResgate.outros) ...[
              TextFormField(
                controller: _outrosTipoController,
                decoration: const InputDecoration(
                  labelText: 'Especificar tipo *',
                  hintText: 'Informe o tipo de equipe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Unidade número
            TextFormField(
              controller: _unidadeController,
              decoration: const InputDecoration(
                labelText: 'Unidade n.',
                hintText: 'Número da unidade',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Checkbox "Não estava no local, mas esteve presente"
            CheckboxListTile(
              title: const Text('Não estava no local, mas esteve presente'),
              value: _naoEstavaNoLocal,
              onChanged: (value) {
                setState(() {
                  _naoEstavaNoLocal = value ?? false;
                });
              },
            ),
            const SizedBox(height: 24),
            // Lista de membros
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Membros (${_membros.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _adicionarMembro,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Membro'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_membros.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nenhum membro adicionado',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...List.generate(_membros.length, (index) {
                final membro = _membros[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(membro.nome),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (membro.cargo != null)
                          Text('Cargo: ${membro.cargo}'),
                        if (membro.matricula != null)
                          Text('Matrícula: ${membro.matricula}'),
                        if (membro.crm != null) Text('CRM: ${membro.crm}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editarMembro(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removerMembro(index),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvarEquipe,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: const Text('Salvar Equipe'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
