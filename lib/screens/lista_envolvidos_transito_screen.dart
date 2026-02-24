import 'package:flutter/material.dart';

import '../models/crime_transito_model.dart';
import '../models/ficha_completa_model.dart';
import '../services/ficha_service.dart';
import 'cadastro_envolvido_transito_screen.dart';
import 'crime_transito_natureza_screen.dart';

class ListaEnvolvidosTransitoScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const ListaEnvolvidosTransitoScreen({super.key, required this.ficha});

  @override
  State<ListaEnvolvidosTransitoScreen> createState() =>
      _ListaEnvolvidosTransitoScreenState();
}

class _ListaEnvolvidosTransitoScreenState
    extends State<ListaEnvolvidosTransitoScreen> {
  final _fichaService = FichaService();
  late FichaCompletaModel _ficha;
  List<CrimeTransitoEnvolvidoModel> _envolvidos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _ficha = widget.ficha;
    _carregar();
  }

  Future<void> _carregar() async {
    final fichaAtualizada = await _fichaService.obterFicha(widget.ficha.id);
    setState(() {
      _ficha = fichaAtualizada ?? widget.ficha;
      _envolvidos = List<CrimeTransitoEnvolvidoModel>.from(
        _ficha.envolvidosTransito ?? const [],
      );
      _carregando = false;
    });
  }

  Future<void> _adicionar() async {
    final novo = CrimeTransitoEnvolvidoModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    final resultado =
        await Navigator.of(context).push<CrimeTransitoEnvolvidoModel>(
      MaterialPageRoute(
        builder: (context) => CadastroEnvolvidoTransitoScreen(envolvido: novo),
      ),
    );

    if (resultado != null) {
      setState(() {
        _envolvidos.add(resultado);
      });
      await _salvar();
    }
  }

  Future<void> _editar(CrimeTransitoEnvolvidoModel envolvido) async {
    final resultado =
        await Navigator.of(context).push<CrimeTransitoEnvolvidoModel>(
      MaterialPageRoute(
        builder: (context) =>
            CadastroEnvolvidoTransitoScreen(envolvido: envolvido),
      ),
    );

    if (resultado != null) {
      setState(() {
        final index = _envolvidos.indexWhere((e) => e.id == resultado.id);
        if (index >= 0) {
          _envolvidos[index] = resultado;
        }
      });
      await _salvar();
    }
  }

  Future<void> _remover(CrimeTransitoEnvolvidoModel envolvido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir envolvido'),
        content: const Text('Tem certeza que deseja remover este registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() {
        _envolvidos.removeWhere((e) => e.id == envolvido.id);
      });
      await _salvar();
    }
  }

  Future<void> _salvar() async {
    final fichaAtualizada = _ficha.copyWith(
      envolvidosTransito: _envolvidos,
      dataUltimaAtualizacao: DateTime.now(),
    );
    await _fichaService.salvarFicha(fichaAtualizada);
    _ficha = fichaAtualizada;
  }

  Future<void> _avancarParaNatureza() async {
    await _salvar();
    if (!mounted) return;
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CrimeTransitoNaturezaScreen(ficha: _ficha),
      ),
    );
    if (resultado == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Envolvidos - Crime de Trânsito'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Avançar para Natureza',
            onPressed: _envolvidos.isEmpty ? null : _avancarParaNatureza,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionar,
        child: const Icon(Icons.add),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _envolvidos.isEmpty
              ? const Center(
                  child: Text('Nenhum envolvido cadastrado'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _envolvidos.length,
                  itemBuilder: (context, index) {
                    final envolvido = _envolvidos[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          envolvido.nome?.isNotEmpty == true
                              ? envolvido.nome!
                              : 'Envolvido ${index + 1}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (envolvido.classificacao != null)
                              Text(
                                switch (envolvido.classificacao!) {
                                  CrimeTransitoClassificacaoEnvolvido
                                        .condutor =>
                                    'Condutor',
                                  CrimeTransitoClassificacaoEnvolvido
                                        .passageiro =>
                                    'Passageiro',
                                  CrimeTransitoClassificacaoEnvolvido
                                        .pedestre =>
                                    'Pedestre',
                                },
                              ),
                            if (envolvido.situacao != null)
                              Text(
                                switch (envolvido.situacao!) {
                                  CrimeTransitoSituacaoEnvolvido
                                        .semFerimentos =>
                                    'Sem ferimentos',
                                  CrimeTransitoSituacaoEnvolvido.feridoGrave =>
                                    'Ferido grave',
                                  CrimeTransitoSituacaoEnvolvido.obito =>
                                    'Óbito',
                                },
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editar(envolvido),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: Colors.red,
                              onPressed: () => _remover(envolvido),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
