// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../models/ficha_completa_model.dart';
import '../models/veiculo_model.dart';
import '../services/ficha_service.dart';
import 'cadastro_veiculo_screen.dart';
import 'lista_cadaveres_screen.dart';

class ListaVeiculosScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const ListaVeiculosScreen({super.key, required this.ficha});

  @override
  State<ListaVeiculosScreen> createState() => _ListaVeiculosScreenState();
}

class _ListaVeiculosScreenState extends State<ListaVeiculosScreen> {
  final _fichaService = FichaService();
  late FichaCompletaModel _ficha;
  List<VeiculoModel> _veiculos = [];
  bool _ignorarVeiculos = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    // Recarregar a ficha do serviço para garantir dados atualizados
    final fichaAtualizada = await _fichaService.obterFicha(widget.ficha.id);
    if (fichaAtualizada != null) {
      setState(() {
        _ficha = fichaAtualizada;
        _veiculos = List<VeiculoModel>.from(_ficha.veiculos ?? []);
        // Só marca como ignorado se a lista estiver explicitamente vazia (não null)
        // Isso significa que o usuário já escolheu ignorar anteriormente
        _ignorarVeiculos = _ficha.veiculos != null && _ficha.veiculos!.isEmpty;
      });
    } else {
      setState(() {
        _ficha = widget.ficha;
        _veiculos = List<VeiculoModel>.from(_ficha.veiculos ?? []);
        _ignorarVeiculos = _ficha.veiculos != null && _ficha.veiculos!.isEmpty;
      });
    }
  }

  Future<void> _adicionarVeiculo() async {
    final proximoNumero = _veiculos.isEmpty
        ? 1
        : _veiculos.map((v) => v.numero).reduce((a, b) => a > b ? a : b) + 1;

    final novoVeiculo = VeiculoModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      numero: proximoNumero,
    );

    final resultado = await Navigator.of(context).push<VeiculoModel>(
      MaterialPageRoute(
        builder: (context) =>
            CadastroVeiculoScreen(veiculo: novoVeiculo, ficha: _ficha),
      ),
    );

    if (resultado != null) {
      setState(() {
        _veiculos.add(resultado);
        _ignorarVeiculos = false;
      });
      await _salvarVeiculos();
      // Recarregar dados após salvar
      await _carregarDados();
    }
  }

  Future<void> _editarVeiculo(VeiculoModel veiculo) async {
    final resultado = await Navigator.of(context).push<VeiculoModel>(
      MaterialPageRoute(
        builder: (context) =>
            CadastroVeiculoScreen(veiculo: veiculo, ficha: _ficha),
      ),
    );

    if (resultado != null) {
      setState(() {
        final index = _veiculos.indexWhere((v) => v.id == resultado.id);
        if (index >= 0) {
          _veiculos[index] = resultado;
        }
      });
      await _salvarVeiculos();
      // Recarregar dados após salvar
      await _carregarDados();
    }
  }

  Future<void> _excluirVeiculo(VeiculoModel veiculo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Veículo'),
        content: Text(
          'Deseja excluir o Veículo ${veiculo.numero}'
          '${veiculo.marcaModelo != null ? ' (${veiculo.marcaModelo})' : ''}?',
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
        _veiculos.removeWhere((v) => v.id == veiculo.id);
      });
      await _salvarVeiculos();
      // Recarregar dados após salvar
      await _carregarDados();
    }
  }

  Future<void> _ignorar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ignorar Veículos'),
        content: const Text(
          'Deseja continuar sem cadastrar veículos? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ignorar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() {
        _ignorarVeiculos = true;
        _veiculos.clear();
      });
      await _salvarVeiculos();
      _finalizar();
    }
  }

  Future<void> _salvarVeiculos() async {
    final fichaAtualizada = _ficha.copyWith(
      // Se ignorou, salva lista vazia. Se não ignorou mas não há veículos, mantém null.
      // Se há veículos, salva a lista.
      veiculos: _ignorarVeiculos ? [] : (_veiculos.isEmpty ? null : _veiculos),
      dataUltimaAtualizacao: DateTime.now(),
    );
    await _fichaService.salvarFicha(fichaAtualizada);
    _ficha = fichaAtualizada;
  }

  Future<void> _finalizar() async {
    // Garante que veículos estão salvos antes de seguir
    await _salvarVeiculos();

    // Navegar para cadáveres; se o usuário finalizar lá, retornar ficha para o chamador
    final resultadoCadaveres = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ListaCadaveresScreen(ficha: _ficha),
      ),
    );

    if (!mounted) return;
    if (resultadoCadaveres != null) {
      // Após voltar de cadáveres, recarrega ficha e devolve ao chamador
      await _carregarDados();
      Navigator.of(context).pop(_ficha);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veículos'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Informações
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cadastro de Veículo(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adicione os veículos encontrados no local do crime ou ignore se não houver.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de veículos ou mensagens
            _veiculos.isEmpty && !_ignorarVeiculos
                ? Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhum veículo cadastrado',
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
                : _ignorarVeiculos
                ? Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Veículos ignorados',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Nenhum veículo foi cadastrado',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _ignorarVeiculos = false;
                            });
                            _salvarVeiculos();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar veículos'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _veiculos.map((veiculo) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(
                              Icons.directions_car,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          title: Text(
                            veiculo.marcaModelo ?? 'Veículo ${veiculo.numero}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (veiculo.tipoVeiculo != null)
                                Text('Tipo: ${veiculo.tipoVeiculo!.label}'),
                              if (veiculo.placa != null)
                                Text('Placa: ${veiculo.placa}'),
                              if (veiculo.cor != null)
                                Text('Cor: ${veiculo.cor}'),
                              if (veiculo.relacao != null)
                                Text('Relação: ${veiculo.relacao!.label}'),
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
                                _editarVeiculo(veiculo);
                              } else if (value == 'excluir') {
                                _excluirVeiculo(veiculo);
                              }
                            },
                          ),
                          onTap: () => _editarVeiculo(veiculo),
                        ),
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 32),

            // Botões de ação
            if (_veiculos.isEmpty && !_ignorarVeiculos)
              OutlinedButton(
                onPressed: _ignorar,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Ignorar (não há veículos)'),
              ),
            if (_veiculos.isNotEmpty || _ignorarVeiculos)
              FilledButton(
                onPressed: _finalizar,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Salvar e Continuar'),
              ),
            const SizedBox(
              height: 80,
            ), // Padding extra no final para garantir que o botão fique visível
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ignorarVeiculos ? null : _adicionarVeiculo,
        tooltip: 'Adicionar veículo',
        child: const Icon(Icons.add),
      ),
    );
  }
}
