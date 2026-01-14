import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/equipe_policial_ficha_model.dart';
import '../models/equipe_resgate_model.dart';
import '../models/ficha_completa_model.dart';
import '../models/tipo_equipe_policial.dart';
import '../services/ficha_service.dart';
import 'cadastro_equipe_policial_screen.dart';
import 'cadastro_equipe_resgate_screen.dart';
import 'local_screen.dart';

class EquipesPoliciaisScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const EquipesPoliciaisScreen({super.key, required this.ficha});

  @override
  State<EquipesPoliciaisScreen> createState() => _EquipesPoliciaisScreenState();
}

class _EquipesPoliciaisScreenState extends State<EquipesPoliciaisScreen> {
  final _fichaService = FichaService();
  List<EquipePolicialFichaModel> _equipes = [];
  List<EquipeResgateModel> _equipesResgate = [];
  bool _naoHaviaEquipes = false;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarEquipes();
  }

  Future<void> _carregarEquipes() async {
    // Recarregar a ficha do serviço para garantir dados atualizados
    final fichaAtualizada = await _fichaService.obterFicha(widget.ficha.id);
    if (!mounted) return;
    setState(() {
      final ficha = fichaAtualizada ?? widget.ficha;
      _equipes = List.from(ficha.equipesPoliciais ?? []);
      _equipesResgate = List.from(ficha.equipesResgate ?? []);
      _naoHaviaEquipes = ficha.naoHaviaEquipesPoliciais ?? false;
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

  Future<void> _adicionarEquipeResgate() async {
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CadastroEquipeResgateScreen(),
      ),
    );

    if (resultado != null && resultado is EquipeResgateModel) {
      setState(() {
        _equipesResgate.add(resultado);
      });
    }
  }

  Future<void> _editarEquipeResgate(int index) async {
    final equipe = _equipesResgate[index];
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            CadastroEquipeResgateScreen(equipeExistente: equipe),
      ),
    );

    if (resultado != null && resultado is EquipeResgateModel) {
      setState(() {
        _equipesResgate[index] = resultado;
      });
    }
  }

  void _removerEquipeResgate(int index) {
    setState(() {
      _equipesResgate.removeAt(index);
    });
  }

  Future<void> _editarEquipe(int index) async {
    final equipe = _equipes[index];
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            CadastroEquipePolicialScreen(equipeExistente: equipe),
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
      final List<EquipePolicialFichaModel> equipesFinais = _naoHaviaEquipes
          ? []
          : _equipes;

      // Debug: verificar o que está sendo salvo
      if (kDebugMode) {
        print('Salvando equipes policiais: ${equipesFinais.length}');
      }
      if (kDebugMode) {
        print('Salvando equipes de resgate: ${_equipesResgate.length}');
      }
      if (_equipesResgate.isNotEmpty) {
        for (var i = 0; i < _equipesResgate.length; i++) {
          if (kDebugMode) {
            print(
              '  Equipe ${i + 1}: ${_equipesResgate[i].tipo.label} - ${_equipesResgate[i].membros.length} membros',
            );
          }
        }
      }

      // Preservar todos os dados existentes ao atualizar
      final fichaAtualizada = widget.ficha.copyWith(
        equipesPoliciais: equipesFinais.isEmpty ? null : equipesFinais,
        naoHaviaEquipesPoliciais: _naoHaviaEquipes,
        // Passar a lista atual. Se vazia, passar null para limpar completamente
        equipesResgate: _equipesResgate.isEmpty ? null : _equipesResgate,
        dataUltimaAtualizacao: DateTime.now(),
        // Preservar equipe de perícia se já existir
        equipe: widget.ficha.equipe,
        // Preservar dados da ficha base se já existirem
        dadosFichaBase: widget.ficha.dadosFichaBase,
        // Preservar outros dados importantes
        local: widget.ficha.local,
        localFurto: widget.ficha.localFurto,
        evidenciasFurto: widget.ficha.evidenciasFurto,
        modusOperandi: widget.ficha.modusOperandi,
        conclusaoPositiva: widget.ficha.conclusaoPositiva,
        fotosLevantamento: widget.ficha.fotosLevantamento,
        dano: widget.ficha.dano,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      // Recarregar dados após salvar para garantir sincronização
      await _carregarEquipes();

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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        // SEÇÃO: EQUIPES POLICIAIS
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'EQUIPES POLICIAIS',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_naoHaviaEquipes)
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 60,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Não havia equipes no local',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_equipes.isEmpty)
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.group_outlined,
                                    size: 60,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhuma equipe policial adicionada',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _adicionarEquipe,
                                    icon: const Icon(Icons.add),
                                    label: const Text(
                                      'Adicionar Equipe Policial',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...List.generate(_equipes.length, (index) {
                            final equipe = _equipes[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ExpansionTile(
                                leading: Icon(
                                  _getIconForTipo(equipe.tipo),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  equipe.tipo == TipoEquipePolicial.outros
                                      ? (equipe.outrosTipo ?? equipe.tipo.label)
                                      : equipe.tipo.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Confirmar Exclusão',
                                            ),
                                            content: const Text(
                                              'Deseja realmente remover esta equipe?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (equipe.tipo ==
                                                TipoEquipePolicial
                                                    .policiaMilitar &&
                                            equipe.viaturaNumero != null) ...[
                                          Text(
                                            'Viatura n.: ${equipe.viaturaNumero}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        if (equipe.membros.isEmpty)
                                          Text(
                                            'Nenhum membro adicionado',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          )
                                        else
                                          ...equipe.membros.map((membro) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          membro.nome,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        if (membro
                                                                .postoGraduacao !=
                                                            null)
                                                          Text(
                                                            'Posto/Graduação: ${membro.postoGraduacao}',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodySmall,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    'Matrícula: ${membro.matricula}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
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
                          }),
                        const SizedBox(height: 24),
                        // SEÇÃO: EQUIPES DE RESGATE
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'EQUIPES DE RESGATE',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_equipesResgate.isEmpty)
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.medical_services_outlined,
                                    size: 60,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhuma equipe de resgate adicionada',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _adicionarEquipeResgate,
                                    icon: const Icon(Icons.add),
                                    label: const Text(
                                      'Adicionar Equipe de Resgate',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...List.generate(_equipesResgate.length, (index) {
                            final equipe = _equipesResgate[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ExpansionTile(
                                leading: Icon(
                                  equipe.tipo == TipoEquipeResgate.cbm
                                      ? Icons.fire_truck
                                      : equipe.tipo == TipoEquipeResgate.samu
                                      ? Icons.medical_services
                                      : Icons.group,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  equipe.tipo == TipoEquipeResgate.outros
                                      ? (equipe.outrosTipo ?? equipe.tipo.label)
                                      : equipe.tipo.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${equipe.membros.length} membro(s)'),
                                    if (equipe.naoEstavaNoLocal)
                                      Text(
                                        'Não estava no local, mas esteve presente',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _editarEquipeResgate(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Confirmar Exclusão',
                                            ),
                                            content: const Text(
                                              'Deseja realmente remover esta equipe de resgate?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _removerEquipeResgate(index);
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (equipe.unidadeNumero != null) ...[
                                          Text(
                                            'Unidade n.: ${equipe.unidadeNumero}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        if (equipe.membros.isEmpty)
                                          Text(
                                            'Nenhum membro adicionado',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          )
                                        else
                                          ...equipe.membros.map((membro) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    membro.nome,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (membro.cargo != null)
                                                    Text(
                                                      'Cargo: ${membro.cargo}',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodySmall,
                                                    ),
                                                  if (membro.matricula != null)
                                                    Text(
                                                      'Matrícula: ${membro.matricula}',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodySmall,
                                                    ),
                                                  if (membro.crm != null)
                                                    Text(
                                                      'CRM: ${membro.crm}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                          ),
                                                    ),
                                                  if (membro.unidadeNumero !=
                                                      null)
                                                    Text(
                                                      'Unidade: ${membro.unidadeNumero}',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodySmall,
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
                          }),
                        const SizedBox(height: 16),
                      ],
                    ),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
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
      case TipoEquipePolicial.outros:
        return Icons.group;
    }
  }
}
