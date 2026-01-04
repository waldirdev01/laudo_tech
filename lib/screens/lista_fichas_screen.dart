import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../models/ficha_completa_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../services/ficha_service.dart';
import '../services/laudo_generator_service.dart';
import '../services/perito_service.dart';
import '../services/word_generator_service.dart';
import 'condicoes_observacoes_screen.dart';
import 'dano_screen.dart';
import 'equipes_policiais_screen.dart';
import 'evidencias_furto_screen.dart';
import 'historico_screen.dart';
import 'isolamento_screen.dart';
import 'local_furto_screen.dart';
import 'local_screen.dart';
import 'modus_operandi_screen.dart';
import 'preenchimento_ficha_screen.dart';
import 'preservacao_screen.dart';
import 'selecao_equipe_screen.dart';

class ListaFichasScreen extends StatefulWidget {
  const ListaFichasScreen({super.key});

  @override
  State<ListaFichasScreen> createState() => _ListaFichasScreenState();
}

class _ListaFichasScreenState extends State<ListaFichasScreen> {
  final _fichaService = FichaService();
  final _wordGeneratorService = WordGeneratorService();
  List<FichaCompletaModel> _fichas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarFichas();
  }

  Future<void> _carregarFichas() async {
    setState(() {
      _carregando = true;
    });

    try {
      final fichas = await _fichaService.listarFichas();
      if (mounted) {
        setState(() {
          _fichas = fichas;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar fichas: $e')));
      }
    }
  }

  Future<void> _abrirFicha(FichaCompletaModel ficha) async {
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreenchimentoFichaScreen(
          tipoOcorrencia: ficha.tipoOcorrencia,
          dadosSolicitacao: ficha.dadosSolicitacao,
          fichaExistente: ficha,
        ),
      ),
    );

    if (resultado == true) {
      _carregarFichas();
    }
  }

  Future<void> _mostrarMenuNavegacao(FichaCompletaModel ficha) async {
    final telaEscolhida = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navegar para Tela'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('1. Solicitação'),
                onTap: () => Navigator.of(context).pop('solicitacao'),
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('2. Equipe de Perícia'),
                onTap: () => Navigator.of(context).pop('equipe'),
              ),
              ListTile(
                leading: const Icon(Icons.local_police),
                title: const Text('3. Equipes Policiais'),
                onTap: () => Navigator.of(context).pop('equipes_policiais'),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('4. Local'),
                onTap: () => Navigator.of(context).pop('local'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('5. Histórico'),
                onTap: () => Navigator.of(context).pop('historico'),
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('6. Isolamento'),
                onTap: () => Navigator.of(context).pop('isolamento'),
              ),
              ListTile(
                leading: const Icon(Icons.shield),
                title: const Text('7. Preservação'),
                onTap: () => Navigator.of(context).pop('preservacao'),
              ),
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('8. Condições Ambientais'),
                onTap: () => Navigator.of(context).pop('condicoes'),
              ),
              if (ficha.tipoOcorrencia ==
                  TipoOcorrencia.furtoDanoExameLocal) ...[
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('9. Local (Furto)'),
                  onTap: () => Navigator.of(context).pop('local_furto'),
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('10. Evidências'),
                  onTap: () => Navigator.of(context).pop('evidencias'),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.psychology),
                title: const Text('11. Modus Operandi'),
                onTap: () => Navigator.of(context).pop('modus_operandi'),
              ),
              if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal)
                ListTile(
                  leading: const Icon(Icons.warning),
                  title: const Text('12. Dano'),
                  onTap: () => Navigator.of(context).pop('dano'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (telaEscolhida != null && mounted) {
      await _navegarParaTela(ficha, telaEscolhida);
    }
  }

  Future<void> _gerarDocumentoWord(FichaCompletaModel ficha) async {
    if (!mounted) return;

    // Verificar se o template existe antes de tentar gerar
    final perito = await PeritoService().obterPerito();
    if (perito == null || perito.caminhoTemplate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Template não configurado. Vá em Configurações > Editar Perito e selecione o template.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final templateFile = File(perito.caminhoTemplate!);
    if (!await templateFile.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Arquivo template não encontrado. Vá em Configurações > Editar Perito e selecione o template novamente.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Mostrar diálogo de carregamento
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Gerando documento Word...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final arquivo = await _wordGeneratorService.gerarDocumentoWord(ficha);

      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar diálogo de carregamento

      // Abrir o arquivo gerado
      await OpenFilex.open(arquivo.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documento gerado com sucesso!\n${arquivo.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar diálogo de carregamento

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar documento: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _gerarDocumentoLaudo(FichaCompletaModel ficha) async {
    // Verificar se o perito está cadastrado
    final peritoService = PeritoService();
    final perito = await peritoService.obterPerito();

    if (perito == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre o perito nas configurações antes de gerar o laudo',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Verificar se o template existe
    final templatePath = perito.caminhoTemplate;
    if (templatePath == null || templatePath.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um template nas configurações do perito'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final templateFile = File(templatePath);
    if (!await templateFile.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Template não encontrado. Selecione novamente nas configurações.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo de carregamento
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Gerando laudo...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final laudoService = LaudoGeneratorService();
      final arquivo = await laudoService.gerarLaudo(
        ficha: ficha,
        perito: perito,
        templatePath: templatePath,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar diálogo de carregamento

      // Abrir o arquivo gerado
      final result = await OpenFilex.open(arquivo.path);

      if (result.type != ResultType.done) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Laudo gerado: ${arquivo.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar diálogo de carregamento

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar laudo: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _navegarParaTela(FichaCompletaModel ficha, String tela) async {
    Widget? telaDestino;

    switch (tela) {
      case 'solicitacao':
        telaDestino = PreenchimentoFichaScreen(
          tipoOcorrencia: ficha.tipoOcorrencia,
          dadosSolicitacao: ficha.dadosSolicitacao,
          fichaExistente: ficha,
        );
        break;
      case 'equipe':
        telaDestino = SelecaoEquipeScreen(ficha: ficha);
        break;
      case 'equipes_policiais':
        telaDestino = EquipesPoliciaisScreen(ficha: ficha);
        break;
      case 'local':
        telaDestino = LocalScreen(ficha: ficha);
        break;
      case 'historico':
        telaDestino = HistoricoScreen(ficha: ficha);
        break;
      case 'isolamento':
        telaDestino = IsolamentoScreen(ficha: ficha);
        break;
      case 'preservacao':
        telaDestino = PreservacaoScreen(ficha: ficha);
        break;
      case 'condicoes':
        telaDestino = CondicoesObservacoesScreen(ficha: ficha);
        break;
      case 'local_furto':
        if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) {
          telaDestino = LocalFurtoScreen(ficha: ficha);
        }
        break;
      case 'evidencias':
        if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) {
          telaDestino = EvidenciasFurtoScreen(ficha: ficha);
        }
        break;
      case 'modus_operandi':
        telaDestino = ModusOperandiScreen(ficha: ficha);
        break;
      case 'dano':
        if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) {
          telaDestino = DanoScreen(ficha: ficha);
        }
        break;
    }

    if (telaDestino != null) {
      final resultado = await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => telaDestino!));

      if (resultado == true && mounted) {
        _carregarFichas();
      }
    }
  }

  Future<void> _removerFicha(FichaCompletaModel ficha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Deseja realmente excluir esta ficha?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _fichaService.removerFicha(ficha.id);
        _carregarFichas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ficha excluída com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fichas Salvas'), centerTitle: true),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _fichas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma ficha salva',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie uma nova ocorrência para começar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _carregarFichas,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _fichas.length,
                itemBuilder: (context, index) {
                  final ficha = _fichas[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.description,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        ficha.dadosSolicitacao.raiNumero ?? 'Sem RAI',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            ficha.tipoOcorrencia.label,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (ficha.dadosSolicitacao.numeroOcorrencia != null)
                            Text(
                              'Ocorrência: ${ficha.dadosSolicitacao.numeroOcorrencia}',
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Criada em: ${DateFormat('dd/MM/yyyy HH:mm').format(ficha.dataCriacao)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (ficha.dataHoraTermino == null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Em andamento',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'navegar',
                            child: Row(
                              children: [
                                Icon(Icons.navigation, size: 20),
                                SizedBox(width: 8),
                                Text('Navegar para Tela'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'gerar_ficha',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Gerar Ficha',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'gerar_laudo',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.article,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Gerar Laudo',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'excluir',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Excluir',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'editar') {
                            _abrirFicha(ficha);
                          } else if (value == 'navegar') {
                            _mostrarMenuNavegacao(ficha);
                          } else if (value == 'gerar_ficha') {
                            _gerarDocumentoWord(ficha);
                          } else if (value == 'gerar_laudo') {
                            _gerarDocumentoLaudo(ficha);
                          } else if (value == 'excluir') {
                            _removerFicha(ficha);
                          }
                        },
                      ),
                      onTap: () => _abrirFicha(ficha),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
