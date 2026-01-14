import 'package:flutter/material.dart';

import '../models/cadaver_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import 'cadastro_cadaver_screen.dart';
import 'dinamica_screen.dart';

class ListaCadaveresScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const ListaCadaveresScreen({super.key, required this.ficha});

  @override
  State<ListaCadaveresScreen> createState() => _ListaCadaveresScreenState();
}

class _ListaCadaveresScreenState extends State<ListaCadaveresScreen> {
  final _fichaService = FichaService();
  late FichaCompletaModel _ficha;
  List<CadaverModel> _cadaveres = [];

  @override
  void initState() {
    super.initState();
    _ficha = widget.ficha;
    _cadaveres = List<CadaverModel>.from(_ficha.cadaveres ?? []);
  }

  Future<void> _adicionarCadaver() async {
    final proximoNumero = _cadaveres.isEmpty
        ? 1
        : _cadaveres.map((c) => c.numero).reduce((a, b) => a > b ? a : b) + 1;

    final novoCadaver = CadaverModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      numero: proximoNumero,
    );

    final resultado = await Navigator.of(context).push<CadaverModel>(
      MaterialPageRoute(
        builder: (context) => CadastroCadaverScreen(
          cadaver: novoCadaver,
          ficha: _ficha,
        ),
      ),
    );

    if (resultado != null) {
      setState(() {
        _cadaveres.add(resultado);
      });
      await _salvarCadaveres();
    }
  }

  Future<void> _editarCadaver(CadaverModel cadaver) async {
    final resultado = await Navigator.of(context).push<CadaverModel>(
      MaterialPageRoute(
        builder: (context) => CadastroCadaverScreen(
          cadaver: cadaver,
          ficha: _ficha,
        ),
      ),
    );

    if (resultado != null) {
      setState(() {
        final index = _cadaveres.indexWhere((c) => c.id == resultado.id);
        if (index >= 0) {
          _cadaveres[index] = resultado;
        }
      });
      await _salvarCadaveres();
    }
  }

  Future<void> _excluirCadaver(CadaverModel cadaver) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Cadáver'),
        content: Text(
          'Deseja excluir o Cadáver ${cadaver.numero}'
          '${cadaver.nomeDaVitima != null ? ' (${cadaver.nomeDaVitima})' : ''}?',
        ),
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
      setState(() {
        _cadaveres.removeWhere((c) => c.id == cadaver.id);
      });
      await _salvarCadaveres();
    }
  }

  Future<void> _salvarCadaveres() async {
    final fichaAtualizada = _ficha.copyWith(
      cadaveres: _cadaveres,
      dataUltimaAtualizacao: DateTime.now(),
    );
    await _fichaService.salvarFicha(fichaAtualizada);
    _ficha = fichaAtualizada;
  }

  Future<void> _salvarEContinuar() async {
    if (_cadaveres.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Atenção'),
          content: const Text(
            'É necessário cadastrar pelo menos um cadáver para continuar.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Garantir que cadáveres estão salvos antes de seguir
    await _salvarCadaveres();

    // Navegar para tela de dinâmica (ela própria limpa a pilha e vai para HomeScreen)
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DinamicaScreen(ficha: _ficha),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadáveres'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Informações
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cadastro de Cadáver(es)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adicione os cadáveres encontrados no local do crime.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de cadáveres
            Expanded(
              child: _cadaveres.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum cadáver cadastrado',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Toque em + para adicionar',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cadaveres.length,
                      itemBuilder: (context, index) {
                      final cadaver = _cadaveres[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cadaver.sexo == SexoCadaver.feminino
                                ? Colors.pink.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              cadaver.sexo == SexoCadaver.feminino
                                  ? Icons.female
                                  : Icons.male,
                              color: cadaver.sexo == SexoCadaver.feminino
                                  ? Colors.pink.shade700
                                  : Colors.blue.shade700,
                            ),
                          ),
                          title: Text(
                            cadaver.nomeDaVitima ?? 'Cadáver ${cadaver.numero}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cadaver.sexo != null)
                                Text('Sexo: ${cadaver.sexo!.label}'),
                              if (cadaver.faixaEtaria != null)
                                Text('Faixa etária: ${cadaver.faixaEtaria!.label}'),
                              if (cadaver.numeroLaudoCadaverico != null)
                                Text('Laudo: ${cadaver.numeroLaudoCadaverico}'),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'editar',
                                child: Text('Editar'),
                              ),
                              const PopupMenuItem(
                                value: 'excluir',
                                child: Text('Excluir'),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'editar') {
                                _editarCadaver(cadaver);
                              } else if (value == 'excluir') {
                                _excluirCadaver(cadaver);
                              }
                            },
                          ),
                          onTap: () => _editarCadaver(cadaver),
                        ),
                      );
                    },
                  ),
            ),

            // Botão de salvar e continuar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _salvarEContinuar,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('Salvar e Continuar'),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarCadaver,
        child: const Icon(Icons.add),
      ),
    );
  }
}
