import 'package:flutter/material.dart';
import '../models/equipe_policial_ficha_model.dart';
import '../models/tipo_equipe_policial.dart';
import '../models/membro_equipe_policial_model.dart';
import 'cadastro_membro_equipe_policial_screen.dart';

class CadastroEquipePolicialScreen extends StatefulWidget {
  final EquipePolicialFichaModel? equipeExistente;

  const CadastroEquipePolicialScreen({
    super.key,
    this.equipeExistente,
  });

  @override
  State<CadastroEquipePolicialScreen> createState() => _CadastroEquipePolicialScreenState();
}

class _CadastroEquipePolicialScreenState extends State<CadastroEquipePolicialScreen> {
  TipoEquipePolicial? _tipoSelecionado;
  final _outrosTipoController = TextEditingController();
  final _viaturaController = TextEditingController();
  List<MembroEquipePolicialModel> _membros = [];

  @override
  void initState() {
    super.initState();
    if (widget.equipeExistente != null) {
      _tipoSelecionado = widget.equipeExistente!.tipo;
      _outrosTipoController.text = widget.equipeExistente!.outrosTipo ?? '';
      _viaturaController.text = widget.equipeExistente!.viaturaNumero ?? '';
      _membros = List.from(widget.equipeExistente!.membros);
    }
  }

  @override
  void dispose() {
    _outrosTipoController.dispose();
    _viaturaController.dispose();
    super.dispose();
  }

  Future<void> _adicionarMembro() async {
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CadastroMembroEquipePolicialScreen(
          tipoEquipe: _tipoSelecionado!,
        ),
      ),
    );

    if (resultado != null && resultado is MembroEquipePolicialModel) {
      setState(() {
        _membros.add(resultado);
      });
    }
  }

  void _editarMembro(int index) async {
    final membro = _membros[index];
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CadastroMembroEquipePolicialScreen(
          tipoEquipe: _tipoSelecionado!,
          membroExistente: membro,
        ),
      ),
    );

    if (resultado != null && resultado is MembroEquipePolicialModel) {
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

    if (_tipoSelecionado == TipoEquipePolicial.outros &&
        _outrosTipoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe o tipo de equipe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final equipe = EquipePolicialFichaModel(
      tipo: _tipoSelecionado!,
      outrosTipo: _tipoSelecionado == TipoEquipePolicial.outros
          ? _outrosTipoController.text.trim()
          : null,
      viaturaNumero: _tipoSelecionado == TipoEquipePolicial.policiaMilitar
          ? (_viaturaController.text.trim().isEmpty ? null : _viaturaController.text.trim())
          : null,
      membros: _membros,
    );

    Navigator.of(context).pop(equipe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.equipeExistente != null ? 'Editar Equipe' : 'Adicionar Equipe'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Tipo de Equipe
            Text(
              'Tipo de Equipe *',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: DropdownButton<TipoEquipePolicial>(
                isExpanded: true,
                value: _tipoSelecionado,
                hint: const Text('Selecione o tipo de equipe'),
                items: TipoEquipePolicial.values.map((tipo) {
                  return DropdownMenuItem<TipoEquipePolicial>(
                    value: tipo,
                    child: Text(tipo.label),
                  );
                }).toList(),
                onChanged: (tipo) {
                  setState(() {
                    _tipoSelecionado = tipo;
                    // Limpar viatura se não for PM
                    if (tipo != TipoEquipePolicial.policiaMilitar) {
                      _viaturaController.clear();
                    }
                  });
                },
                underline: const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
            // Campo "Outros" se selecionado
            if (_tipoSelecionado == TipoEquipePolicial.outros) ...[
              TextFormField(
                controller: _outrosTipoController,
                decoration: const InputDecoration(
                  labelText: 'Especifique o tipo de equipe *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Campo Viatura para Polícia Militar
            if (_tipoSelecionado == TipoEquipePolicial.policiaMilitar) ...[
              TextFormField(
                controller: _viaturaController,
                decoration: const InputDecoration(
                  labelText: 'Viatura n.:',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                  hintText: 'Número da viatura',
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Lista de Membros
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Membros',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_tipoSelecionado != null)
                  TextButton.icon(
                    onPressed: _adicionarMembro,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Adicionar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_membros.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Nenhum membro adicionado. Clique em "Adicionar" para incluir membros.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._membros.asMap().entries.map((entry) {
                final index = entry.key;
                final membro = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(membro.nome),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (membro.postoGraduacao != null)
                          Text('Posto/Graduação: ${membro.postoGraduacao}'),
                        Text('Matrícula: ${membro.matricula}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editarMembro(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
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
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: Text(widget.equipeExistente != null ? 'Salvar Alterações' : 'Adicionar Equipe'),
            ),
          ],
        ),
      ),
    );
  }
}

