import 'package:flutter/material.dart';

import '../models/laboratorio_model.dart';
import '../models/unidade_model.dart';
import '../services/laboratorio_service.dart';
import '../services/unidade_service.dart';

class CadastroUnidadesLaboratoriosScreen extends StatefulWidget {
  const CadastroUnidadesLaboratoriosScreen({super.key});

  @override
  State<CadastroUnidadesLaboratoriosScreen> createState() =>
      _CadastroUnidadesLaboratoriosScreenState();
}

class _CadastroUnidadesLaboratoriosScreenState
    extends State<CadastroUnidadesLaboratoriosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _unidadeService = UnidadeService();
  final _laboratorioService = LaboratorioService();

  List<UnidadeModel> _unidades = [];
  List<LaboratorioModel> _laboratorios = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    final unidades = await _unidadeService.listarUnidades();
    final laboratorios = await _laboratorioService.listarLaboratorios();
    setState(() {
      _unidades = unidades;
      _laboratorios = laboratorios;
      _carregando = false;
    });
  }

  Future<void> _adicionarOuEditarUnidade({UnidadeModel? existente}) async {
    final nomeCtrl = TextEditingController(text: existente?.nome ?? '');
    final siglaCtrl = TextEditingController(text: existente?.sigla ?? '');

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existente == null ? 'Nova Unidade' : 'Editar Unidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome da Unidade *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: siglaCtrl,
              decoration: const InputDecoration(
                labelText: 'Sigla (opcional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nomeCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informe o nome da unidade'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (resultado == true) {
      final unidade = UnidadeModel(
        id: existente?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        nome: nomeCtrl.text.trim(),
        sigla: siglaCtrl.text.trim().isEmpty ? null : siglaCtrl.text.trim(),
      );
      if (existente == null) {
        await _unidadeService.adicionarUnidade(unidade);
      } else {
        await _unidadeService.atualizarUnidade(unidade);
      }
      _carregarDados();
    }
  }

  Future<void> _adicionarOuEditarLaboratorio({
    LaboratorioModel? existente,
  }) async {
    final nomeCtrl = TextEditingController(text: existente?.nome ?? '');
    final siglaCtrl = TextEditingController(text: existente?.sigla ?? '');

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existente == null ? 'Novo Laboratório' : 'Editar Laboratório',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do Laboratório *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: siglaCtrl,
              decoration: const InputDecoration(
                labelText: 'Sigla (opcional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nomeCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informe o nome do laboratório'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (resultado == true) {
      final laboratorio = LaboratorioModel(
        id: existente?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        nome: nomeCtrl.text.trim(),
        sigla: siglaCtrl.text.trim().isEmpty ? null : siglaCtrl.text.trim(),
      );
      if (existente == null) {
        await _laboratorioService.adicionarLaboratorio(laboratorio);
      } else {
        await _laboratorioService.atualizarLaboratorio(laboratorio);
      }
      _carregarDados();
    }
  }

  Future<void> _excluirUnidade(UnidadeModel unidade) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Unidade'),
        content: Text('Deseja excluir "${unidade.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _unidadeService.removerUnidade(unidade.id);
      _carregarDados();
    }
  }

  Future<void> _excluirLaboratorio(LaboratorioModel laboratorio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Laboratório'),
        content: Text('Deseja excluir "${laboratorio.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _laboratorioService.removerLaboratorio(laboratorio.id);
      _carregarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unidades e Laboratórios'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Unidades', icon: Icon(Icons.business)),
            Tab(text: 'Laboratórios', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListaUnidades(),
                _buildListaLaboratorios(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _adicionarOuEditarUnidade();
          } else {
            _adicionarOuEditarLaboratorio();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListaUnidades() {
    if (_unidades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma unidade cadastrada',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toque em + para adicionar',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _unidades.length,
      itemBuilder: (context, index) {
        final unidade = _unidades[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.business)),
            title: Text(unidade.nome),
            subtitle: unidade.sigla != null ? Text(unidade.sigla!) : null,
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
              onSelected: (value) {
                if (value == 'editar') {
                  _adicionarOuEditarUnidade(existente: unidade);
                } else if (value == 'excluir') {
                  _excluirUnidade(unidade);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildListaLaboratorios() {
    if (_laboratorios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Nenhum laboratório cadastrado',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toque em + para adicionar',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _laboratorios.length,
      itemBuilder: (context, index) {
        final laboratorio = _laboratorios[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.science)),
            title: Text(laboratorio.nome),
            subtitle: laboratorio.sigla != null ? Text(laboratorio.sigla!) : null,
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
              onSelected: (value) {
                if (value == 'editar') {
                  _adicionarOuEditarLaboratorio(existente: laboratorio);
                } else if (value == 'excluir') {
                  _excluirLaboratorio(laboratorio);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
