import 'package:flutter/material.dart';
import '../models/ficha_completa_model.dart';
import '../models/equipe_policial_ficha_model.dart';
import '../models/tipo_equipe_policial.dart';
import '../services/ficha_service.dart';
import 'cadastro_equipe_policial_screen.dart';
import 'local_screen.dart';

class EquipesPoliciaisScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const EquipesPoliciaisScreen({
    super.key,
    required this.ficha,
  });

  @override
  State<EquipesPoliciaisScreen> createState() => _EquipesPoliciaisScreenState();
}

class _EquipesPoliciaisScreenState extends State<EquipesPoliciaisScreen> {
  final _fichaService = FichaService();
  List<EquipePolicialFichaModel> _equipes = [];
  bool _naoHaviaEquipes = false;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarEquipes();
  }

  void _carregarEquipes() {
    setState(() {
      _equipes = List.from(widget.ficha.equipesPoliciais ?? []);
      _naoHaviaEquipes = widget.ficha.naoHaviaEquipesPoliciais ?? false;
      _carregando = false;
    });
  }

  Future<void> _adicionarEquipe() async {
    if (_naoHaviaEquipes) {
      // Se marcou "Não havia equipes", desmarcar ao adicionar uma equipe
      setState(() {
        _naoHaviaEquipes = false;
      });
    }
    
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CadastroEquipePolicialScreen(),
      ),
    );

    if (resultado != null && resultado is EquipePolicialFichaModel) {
      setState(() {
        _equipes.add(resultado);
      });
    }
  }

  Future<void> _editarEquipe(int index) async {
    final equipe = _equipes[index];
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CadastroEquipePolicialScreen(
          equipeExistente: equipe,
        ),
      ),
    );

    if (resultado != null && resultado is EquipePolicialFichaModel) {
      setState(() {
        _equipes[index] = resultado;
      });
    }
  }

  void _removerEquipe(int index) {
    setState(() {
      _equipes.removeAt(index);
    });
  }

  Future<void> _salvarEquipes() async {
    setState(() {
      _salvando = true;
    });

    try {
      // Se marcou "Não havia equipes", limpar a lista de equipes
      final List<EquipePolicialFichaModel> equipesFinais = _naoHaviaEquipes ? [] : _equipes;
      
      // Preservar todos os dados existentes ao atualizar
      final fichaAtualizada = widget.ficha.copyWith(
        equipesPoliciais: equipesFinais.isEmpty ? null : equipesFinais,
        naoHaviaEquipesPoliciais: _naoHaviaEquipes,
        dataUltimaAtualizacao: DateTime.now(),
        // Preservar equipe de perícia se já existir
        equipe: widget.ficha.equipe,
        // Preservar dados da ficha base se já existirem
        dadosFichaBase: widget.ficha.dadosFichaBase,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipes salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para tela de local
        if (!mounted) return;
        final navigator = Navigator.of(context);
        final resultado = await navigator.push(
          MaterialPageRoute(
            builder: (context) => LocalScreen(ficha: fichaAtualizada),
          ),
        );

        // Se voltou do local, retornar true para atualizar lista
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
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demais Equipes Policiais/De Salvamento'),
        centerTitle: true,
        actions: [
          if (!_naoHaviaEquipes)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _adicionarEquipe,
              tooltip: 'Adicionar equipe',
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Checkbox "Não havia equipes no local"
                Card(
                  margin: const EdgeInsets.all(16),
                  child: CheckboxListTile(
                    title: const Text('Não havia equipes no local'),
                    value: _naoHaviaEquipes,
                    onChanged: (value) {
                      setState(() {
                        _naoHaviaEquipes = value ?? false;
                        // Se marcar "Não havia equipes", limpar a lista
                        if (_naoHaviaEquipes) {
                          _equipes.clear();
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _naoHaviaEquipes
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 80,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Não havia equipes no local',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        )
                      : _equipes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_outlined,
                                size: 80,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma equipe adicionada',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Adicione equipes policiais ou de salvamento',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _adicionarEquipe,
                                icon: const Icon(Icons.add),
                                label: const Text('Adicionar Primeira Equipe'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _equipes.length,
                          itemBuilder: (context, index) {
                            final equipe = _equipes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                leading: Icon(
                                  _getIconForTipo(equipe.tipo),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  equipe.tipo == TipoEquipePolicial.outros
                                      ? (equipe.outrosTipo ?? equipe.tipo.label)
                                      : equipe.tipo.label,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${equipe.membros.length} membro(s)',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editarEquipe(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Confirmar Exclusão'),
                                            content: const Text('Deseja realmente remover esta equipe?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _removerEquipe(index);
                                                },
                                                child: const Text('Remover'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (equipe.tipo == TipoEquipePolicial.policiaMilitar &&
                                            equipe.viaturaNumero != null) ...[
                                          Text(
                                            'Viatura n.: ${equipe.viaturaNumero}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        if (equipe.membros.isEmpty)
                                          Text(
                                            'Nenhum membro adicionado',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                          )
                                        else
                                          ...equipe.membros.map((membro) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          membro.nome,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        if (membro.postoGraduacao != null)
                                                          Text(
                                                            'Posto/Graduação: ${membro.postoGraduacao}',
                                                            style: Theme.of(context).textTheme.bodySmall,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    'Matrícula: ${membro.matricula}',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                // Botão de salvar sempre visível
                SafeArea(
                  top: false,
                  minimum: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12 + bottomInset,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (!_naoHaviaEquipes)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _adicionarEquipe,
                              child: const Text('Adicionar Equipe'),
                            ),
                          ),
                        if (!_naoHaviaEquipes) const SizedBox(width: 12),
                        Expanded(
                          flex: _naoHaviaEquipes ? 1 : 2,
                          child: FilledButton(
                            onPressed: _salvando ? null : _salvarEquipes,
                            child: _salvando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Salvar e Continuar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  IconData _getIconForTipo(TipoEquipePolicial tipo) {
    switch (tipo) {
      case TipoEquipePolicial.policiaMilitar:
        return Icons.local_police;
      case TipoEquipePolicial.policiaCivil:
        return Icons.badge;
      case TipoEquipePolicial.prf:
        return Icons.directions_car;
      case TipoEquipePolicial.bombeiros:
        return Icons.fire_truck;
      case TipoEquipePolicial.samu:
        return Icons.medical_services;
      case TipoEquipePolicial.outros:
        return Icons.group;
    }
  }
}

