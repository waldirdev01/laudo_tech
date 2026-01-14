import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ficha_completa_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../services/ficha_service.dart';
import '../services/laudo_generator_service.dart';
import '../services/perito_service.dart';
import '../services/word_generator_service.dart';
import 'condicoes_observacoes_screen.dart';
import 'dano_screen.dart';
import 'detalhes_local_screen.dart';
import 'equipes_policiais_screen.dart';
import 'evidencias_furto_screen.dart';
import 'historico_screen.dart';
import 'isolamento_screen.dart';
import 'lista_cadaveres_screen.dart';
import 'lista_veiculos_screen.dart';
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
                title: const Text('4. Local - Coordenadas GPS'),
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
              if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal ||
                  ficha.tipoOcorrencia == TipoOcorrencia.cvli) ...[
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('9. Local - Detalhes do Local'),
                  onTap: () => Navigator.of(context).pop('local_furto'),
                ),
              ],
              if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal)
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('10. Evidências'),
                  onTap: () => Navigator.of(context).pop('evidencias'),
                ),
              if (ficha.tipoOcorrencia == TipoOcorrencia.cvli) ...[
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: const Text('10. Veículos'),
                  onTap: () => Navigator.of(context).pop('veiculos'),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('11. Cadáveres'),
                  onTap: () => Navigator.of(context).pop('cadaveres'),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.psychology),
                title: const Text('12. Modus Operandi'),
                onTap: () => Navigator.of(context).pop('modus_operandi'),
              ),
              if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal)
                ListTile(
                  leading: const Icon(Icons.warning),
                  title: const Text('13. Dano'),
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

      // Tentar abrir o arquivo gerado
      await _abrirOuCompartilharArquivo(arquivo, 'Ficha');
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

    // Perguntar se deseja incluir fotos (reutilizando fotos persistidas na ficha)
    final fichaService = FichaService();
    var fichaAtual = await fichaService.obterFicha(ficha.id) ?? ficha;

    // Limpar paths inexistentes (se o usuário apagou do app via sistema)
    final fotosExistentes = <String>[];
    for (final p in fichaAtual.fotosLevantamento) {
      final f = File(p);
      if (await f.exists()) fotosExistentes.add(p);
    }

    // Se teve limpeza, persistir de volta
    if (fotosExistentes.length != fichaAtual.fotosLevantamento.length) {
      await fichaService.salvarFicha(
        fichaAtual.copyWith(fotosLevantamento: fotosExistentes),
      );
    }

    List<File>? fotosSelecionadas;
    if (!mounted) return;

    // Se já existem fotos, oferecer usar/adicionar/nenhuma
    if (fotosExistentes.isNotEmpty) {
      final acao = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Levantamento Fotográfico'),
          content: Text(
            'Esta ficha já possui ${fotosExistentes.length} foto(s) salva(s). O que deseja fazer?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('nao'),
              child: const Text('Não incluir'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('adicionar'),
              child: const Text('Adicionar mais'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('usar'),
              child: const Text('Usar salvas'),
            ),
          ],
        ),
      );

      if (acao == 'usar') {
        fotosSelecionadas = fotosExistentes.map((p) => File(p)).toList();
      } else if (acao == 'adicionar') {
        final novas = await _selecionarFotos();
        if (novas != null && novas.isNotEmpty) {
          final novosPaths = await _persistirFotosDaFicha(ficha.id, novas);
          final atualizadas = [...fotosExistentes, ...novosPaths];
          await fichaService.salvarFicha(
            fichaAtual.copyWith(fotosLevantamento: atualizadas),
          );
          fotosSelecionadas = atualizadas.map((p) => File(p)).toList();
        } else {
          fotosSelecionadas = fotosExistentes.map((p) => File(p)).toList();
        }
      } else {
        fotosSelecionadas = null;
      }
    } else {
      final incluirFotos = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incluir Fotos'),
          content: const Text('Deseja incluir fotos no laudo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sim'),
            ),
          ],
        ),
      );

      if (incluirFotos == true) {
        final novas = await _selecionarFotos();
        if (novas != null && novas.isNotEmpty) {
          final paths = await _persistirFotosDaFicha(ficha.id, novas);
          await fichaService.salvarFicha(
            fichaAtual.copyWith(fotosLevantamento: paths),
          );
          fotosSelecionadas = paths.map((p) => File(p)).toList();
        }
      }
    }

    // Permitir reordenar/excluir fotos antes de gerar o laudo (isso altera "Fotografia 01/02..." e a contagem)
    if (fotosSelecionadas != null && fotosSelecionadas.isNotEmpty) {
      final pathsAtuais = fotosSelecionadas.map((f) => f.path).toList();
      final novosPaths = await _gerenciarFotosLevantamento(pathsAtuais);
      if (!mounted) return;

      if (novosPaths != null) {
        final removidas = pathsAtuais.toSet().difference(novosPaths.toSet());
        for (final p in removidas) {
          try {
            final f = File(p);
            if (await f.exists()) {
              await f.delete();
            }
          } catch (_) {
            // Ignorar falhas de remoção (permissão/arquivo em uso etc.)
          }
        }

        await fichaService.salvarFicha(
          fichaAtual.copyWith(fotosLevantamento: novosPaths),
        );
        fichaAtual = fichaAtual.copyWith(fotosLevantamento: novosPaths);

        fotosSelecionadas = novosPaths.isEmpty
            ? null
            : novosPaths.map((p) => File(p)).toList();
      }
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
        ficha: fichaAtual,
        perito: perito,
        templatePath: templatePath,
        fotos: fotosSelecionadas,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Fechar diálogo de carregamento

      // Tentar abrir o arquivo gerado
      await _abrirOuCompartilharArquivo(arquivo, 'Laudo');
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

  /// Tenta abrir o arquivo; se falhar, oferece compartilhar
  Future<void> _abrirOuCompartilharArquivo(File arquivo, String tipo) async {
    final result = await OpenFilex.open(arquivo.path);

    if (result.type == ResultType.done) {
      // Abriu com sucesso
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$tipo gerado com sucesso!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // Não conseguiu abrir - mostrar opções
      if (!mounted) return;
      final acao = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$tipo Gerado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('O documento foi gerado com sucesso!'),
              const SizedBox(height: 12),
              Text(
                'Não foi possível abrir automaticamente.\n\nArquivo: ${arquivo.path.split('/').last}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'fechar'),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'compartilhar'),
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar'),
            ),
          ],
        ),
      );

      if (acao == 'compartilhar' && mounted) {
        await Share.shareXFiles([
          XFile(arquivo.path),
        ], text: '$tipo - Laudo Tech');
      }
    }
  }

  Future<List<File>?> _selecionarFotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final fotos = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();

      if (!mounted) return fotos;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fotos.length} foto(s) selecionada(s)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      return fotos;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar fotos: $e'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }
  }

  Future<List<String>> _persistirFotosDaFicha(
    String fichaId,
    List<File> fotos,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final pasta = Directory('${dir.path}/levantamento_fotografico/$fichaId');
    if (!await pasta.exists()) {
      await pasta.create(recursive: true);
    }

    final paths = <String>[];
    for (final foto in fotos) {
      if (!await foto.exists()) continue;
      final ext = foto.path.split('.').last.toLowerCase();
      final nome = 'foto_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final destino = File('${pasta.path}/$nome');
      await foto.copy(destino.path);
      paths.add(destino.path);
    }
    return paths;
  }

  Future<List<String>?> _gerenciarFotosLevantamento(List<String> paths) async {
    if (paths.isEmpty) return paths;

    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _GerenciarFotosLevantamentoSheet(pathsIniciais: paths),
    );
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
        if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal ||
            ficha.tipoOcorrencia == TipoOcorrencia.cvli) {
          telaDestino = LocalFurtoScreen(ficha: ficha);
        }
        break;
      case 'evidencias':
        if (ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) {
          telaDestino = EvidenciasFurtoScreen(ficha: ficha);
        }
        break;
      case 'veiculos':
        if (ficha.tipoOcorrencia == TipoOcorrencia.cvli) {
          telaDestino = ListaVeiculosScreen(ficha: ficha);
        }
        break;
      case 'cadaveres':
        if (ficha.tipoOcorrencia == TipoOcorrencia.cvli) {
          telaDestino = ListaCadaveresScreen(ficha: ficha);
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
                          if (ficha.dataHoraTermino == null ||
                              ficha.dataHoraTermino!.isEmpty) ...[
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.orange.shade900,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Em atendimento',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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

class _GerenciarFotosLevantamentoSheet extends StatefulWidget {
  const _GerenciarFotosLevantamentoSheet({required this.pathsIniciais});

  final List<String> pathsIniciais;

  @override
  State<_GerenciarFotosLevantamentoSheet> createState() =>
      _GerenciarFotosLevantamentoSheetState();
}

class _GerenciarFotosLevantamentoSheetState
    extends State<_GerenciarFotosLevantamentoSheet> {
  late final List<String> _paths = [...widget.pathsIniciais];

  String _basename(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    if (idx == -1) return path;
    return path.substring(idx + 1);
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      child: SizedBox(
        height: altura,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Organizar fotos do Anexo (${_paths.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_paths),
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _paths.isEmpty
                  ? const Center(child: Text('Nenhuma foto selecionada.'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.all(12),
                      itemCount: _paths.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _paths.removeAt(oldIndex);
                          _paths.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final path = _paths[index];
                        final titulo =
                            'Fotografia ${(index + 1).toString().padLeft(2, '0')}';

                        return Card(
                          key: ValueKey(path),
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            child: ListTile(
                              leading: SizedBox(
                                width: 56,
                                height: 56,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => Container(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.broken_image),
                                        ),
                                  ),
                                ),
                              ),
                              title: Text(titulo),
                              subtitle: Text(_basename(path)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Excluir',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      setState(() {
                                        _paths.removeAt(index);
                                      });
                                    },
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_handle),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
