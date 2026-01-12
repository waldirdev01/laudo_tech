import 'package:flutter/material.dart';

import '../models/equipe_ficha_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/membro_equipe_model.dart';
import '../models/perito_model.dart';
import '../services/equipe_service.dart';
import '../services/ficha_service.dart';
import '../services/perito_service.dart';
import 'equipes_policiais_screen.dart';

class SelecaoEquipeScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const SelecaoEquipeScreen({super.key, required this.ficha});

  @override
  State<SelecaoEquipeScreen> createState() => _SelecaoEquipeScreenState();
}

class _SelecaoEquipeScreenState extends State<SelecaoEquipeScreen> {
  final _equipeService = EquipeService();
  final _peritoService = PeritoService();
  final _fichaService = FichaService();

  List<MembroEquipeModel> _todosMembros = [];
  PeritoModel? _peritoCadastrado;
  String? _fotografoSelecionado;
  List<String> _demaisServidoresSelecionados = [];
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
    });

    try {
      // Carregar perito cadastrado
      final perito = await _peritoService.obterPerito();

      // Carregar todos os membros da equipe
      final membros = await _equipeService.listarEquipe();

      // Carregar equipe já selecionada (se estiver editando)
      final equipeExistente = widget.ficha.equipe;

      if (mounted) {
        setState(() {
          _todosMembros = membros;
          _peritoCadastrado = perito;

          // Se já tem equipe selecionada, carregar
          if (equipeExistente != null) {
            _fotografoSelecionado = equipeExistente.fotografoCriminalisticoId;
            _demaisServidoresSelecionados = List.from(
              equipeExistente.demaisServidoresIds,
            );
          }

          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  MembroEquipeModel? _obterMembroPorId(String? id) {
    if (id == null) return null;
    try {
      return _todosMembros.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _salvarEquipe() async {
    // Validar se tem perito cadastrado
    if (_peritoCadastrado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'É necessário ter um perito cadastrado. Vá em Configurações > Editar Perito',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      // O perito não precisa de ID, pois é sempre o perito cadastrado
      // Mas vamos manter o modelo para compatibilidade
      final equipe = EquipeFichaModel(
        peritoCriminalId: 'perito_cadastrado', // Identificador especial
        fotografoCriminalisticoId: _fotografoSelecionado,
        demaisServidoresIds: _demaisServidoresSelecionados,
      );

      // Preservar todos os dados existentes ao atualizar
      final fichaAtualizada = widget.ficha.copyWith(
        equipe: equipe,
        dataUltimaAtualizacao: DateTime.now(),
        // Preservar equipes policiais se já existirem
        equipesPoliciais: widget.ficha.equipesPoliciais,
        // Preservar dados da ficha base se já existirem
        dadosFichaBase: widget.ficha.dadosFichaBase,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipe salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para equipes policiais
        final navigator = Navigator.of(context);
        final resultado = await navigator.push(
          MaterialPageRoute(
            builder: (context) =>
                EquipesPoliciaisScreen(ficha: fichaAtualizada),
          ),
        );

        // Se voltou das equipes policiais, retornar true para atualizar lista
        if (!mounted) return;
        if (resultado == true) {
          navigator.pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipe de Perícia Criminal Acionada'),
        centerTitle: true,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título da seção
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'EQUIPE DE PERÍCIA CRIMINAL ACIONADA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Tabela de dados
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Linha 1: Perito Criminal e Matrícula
                        _buildTableRow([
                          _buildPeritoCriminalDisplay(),
                          _buildMatriculaPeritoDisplay(),
                        ]),
                        const Divider(height: 1),
                        // Linha 2: Fotógrafo Criminalístico
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fotógrafo Criminalístico:',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              _buildDropdownMembro(
                                _fotografoSelecionado,
                                (id) =>
                                    setState(() => _fotografoSelecionado = id),
                                filtro: 'fotógrafo',
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Linha 3: Demais Servidores
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Demais Servidores Policiais (informar nome e carreira a qual pertence):',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              _buildListaDemaisServidores(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _salvando ? null : _salvarEquipe,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: _salvando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Salvar e Continuar'),
                  ),
                  const SizedBox(height: 80), // Padding extra no final para garantir que o botão fique visível
                ],
              ),
            ),
    );
  }

  Widget _buildTableRow(List<Widget> cells) {
    return Row(
      children: [
        Expanded(child: cells[0]),
        Container(width: 1, height: 80, color: Colors.grey.shade300),
        Expanded(child: cells.length > 1 ? cells[1] : const SizedBox()),
      ],
    );
  }

  Widget _buildPeritoCriminalDisplay() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perito Criminal:',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _peritoCadastrado?.nome ?? '-',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (_peritoCadastrado == null) ...[
            const SizedBox(height: 4),
            Text(
              'Cadastre em Configurações > Editar Perito',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatriculaPeritoDisplay() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Matrícula:',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _peritoCadastrado?.matricula ?? '-',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownMembro(
    String? selecionado,
    Function(String?) onChanged, {
    String? filtro,
    bool obrigatorio = false,
  }) {
    // Filtrar membros se necessário
    List<MembroEquipeModel> membrosFiltrados = _todosMembros;
    if (filtro != null) {
      membrosFiltrados = _todosMembros
          .where((m) => m.cargo.toLowerCase().contains(filtro.toLowerCase()))
          .toList();
    }

    // Adicionar opção "Nenhum" para campos opcionais
    if (filtro != null) {
      membrosFiltrados = [
        MembroEquipeModel(id: '', cargo: '', nome: 'Nenhum', matricula: ''),
        ...membrosFiltrados,
      ];
    }

    if (membrosFiltrados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Nenhum membro cadastrado. Cadastre em Configurações > Equipe',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: selecionado,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: membrosFiltrados.map((membro) {
        return DropdownMenuItem<String>(
          value: membro.id.isEmpty ? null : membro.id,
          child: Text(
            membro.id.isEmpty
                ? membro.nome
                : '${membro.nome} - ${membro.cargo}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      selectedItemBuilder: (context) {
        return membrosFiltrados.map((membro) {
          final texto = membro.id.isEmpty
              ? membro.nome
              : '${membro.nome} - ${membro.cargo}';
          return Text(texto, overflow: TextOverflow.ellipsis);
        }).toList();
      },
      onChanged: (value) => onChanged(value),
      validator: (value) {
        if (obrigatorio && (value == null || value.isEmpty)) {
          return 'Selecione um membro';
        }
        return null;
      },
    );
  }

  Widget _buildListaDemaisServidores() {
    final membrosDisponiveis = _todosMembros
        .where((m) => !_demaisServidoresSelecionados.contains(m.id))
        .toList();

    return Column(
      children: [
        // Lista de membros selecionados
        ..._demaisServidoresSelecionados.map((id) {
          final membro = _obterMembroPorId(id);
          if (membro == null) return const SizedBox.shrink();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(membro.nome),
              subtitle: Text(
                '${membro.cargo} - Matrícula: ${membro.matricula}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _demaisServidoresSelecionados.remove(id);
                  });
                },
              ),
            ),
          );
        }),
        // Dropdown para adicionar novo
        if (membrosDisponiveis.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Todos os membros já foram adicionados',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Selecione um membro'),
              items: membrosDisponiveis.map((membro) {
                return DropdownMenuItem<String>(
                  value: membro.id,
                  child: Text(
                    '${membro.nome} - ${membro.cargo}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null && mounted) {
                  setState(() {
                    _demaisServidoresSelecionados.add(id);
                  });
                }
              },
              style: Theme.of(context).textTheme.bodyMedium,
              underline: const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}
