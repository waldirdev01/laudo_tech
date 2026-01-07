import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/perito_model.dart';
import '../services/perito_service.dart';

class CadastroPeritoScreen extends StatefulWidget {
  final bool isEdicao;
  
  const CadastroPeritoScreen({super.key, this.isEdicao = false});

  @override
  State<CadastroPeritoScreen> createState() => _CadastroPeritoScreenState();
}

class _CadastroPeritoScreenState extends State<CadastroPeritoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _matriculaController = TextEditingController();
  final _unidadeController = TextEditingController();
  final _cidadeController = TextEditingController();
  
  String? _caminhoTemplate;
  bool _carregando = false;
  bool _carregandoDados = true;

  final _peritoService = PeritoService();

  @override
  void initState() {
    super.initState();
    if (widget.isEdicao) {
      _carregarDadosPerito();
    } else {
      _carregandoDados = false;
    }
  }

  Future<void> _carregarDadosPerito() async {
    final perito = await _peritoService.obterPerito();
    if (perito != null && mounted) {
      setState(() {
        _nomeController.text = perito.nome;
        _matriculaController.text = perito.matricula;
        _unidadeController.text = perito.unidadePericial;
        _cidadeController.text = perito.cidade;
        _caminhoTemplate = perito.caminhoTemplate;
        _carregandoDados = false;
      });
    } else {
      setState(() {
        _carregandoDados = false;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _matriculaController.dispose();
    _unidadeController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  Future<void> _selecionarTemplate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'doc'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final caminhoOriginal = result.files.single.path!;
        final arquivoOriginal = File(caminhoOriginal);
        
        if (!await arquivoOriginal.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Arquivo não encontrado')),
            );
          }
          return;
        }

        // Copiar para diretório permanente do app
        final diretorio = await getApplicationDocumentsDirectory();
        final diretorioTemplates = Directory('${diretorio.path}/templates');
        if (!await diretorioTemplates.exists()) {
          await diretorioTemplates.create(recursive: true);
        }

        // Nome estável (evita acumular vários e facilita recuperar automaticamente)
        final nomeArquivo = 'template_laudo.docx';
        final arquivoDestino = File('${diretorioTemplates.path}/$nomeArquivo');
        
        await arquivoOriginal.copy(arquivoDestino.path);

        setState(() {
          _caminhoTemplate = arquivoDestino.path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template copiado com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo: $e')),
        );
      }
    }
  }

  Future<void> _salvarPerito() async {
    // Fechar teclado agressivamente
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Se estiver editando e não mudou o template, usar o caminho existente
    if (widget.isEdicao && _caminhoTemplate == null) {
      final peritoAtual = await _peritoService.obterPerito();
      if (peritoAtual?.caminhoTemplate != null) {
        _caminhoTemplate = peritoAtual!.caminhoTemplate;
      }
    }

    // Validar se tem template (após tentar recuperar o existente)
    if (_caminhoTemplate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione o template Word'),
          ),
        );
      }
      return;
    }

    setState(() {
      _carregando = true;
    });

    try {
      // Verificar se o template existe antes de salvar
      if (_caminhoTemplate != null) {
        final templateFile = File(_caminhoTemplate!);
        if (!await templateFile.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Arquivo template não encontrado. Por favor, selecione novamente.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() {
            _carregando = false;
          });
          return;
        }
      }

      final perito = PeritoModel(
        nome: _nomeController.text.trim(),
        matricula: _matriculaController.text.trim(),
        unidadePericial: _unidadeController.text.trim(),
        cidade: _cidadeController.text.trim(),
        caminhoTemplate: _caminhoTemplate,
      );

      await _peritoService.salvarPerito(perito);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEdicao 
                ? 'Dados atualizados com sucesso!' 
                : 'Perito cadastrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Forçar fechamento do teclado antes de sair
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        
        // Pequeno delay para garantir que o teclado recolha antes da transição
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          // Voltar para tela inicial
          Navigator.of(context).pop(true);
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
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoDados) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar Perito'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEdicao ? 'Editar Perito' : 'Cadastro de Perito'),
          centerTitle: true,
        ),
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, informe o nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _matriculaController,
                  decoration: const InputDecoration(
                    labelText: 'Matrícula',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, informe a matrícula';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _unidadeController,
                  decoration: const InputDecoration(
                    labelText: 'Unidade Pericial',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, informe a unidade pericial';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cidadeController,
                  decoration: const InputDecoration(
                    labelText: 'Cidade',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, informe a cidade';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Template Word da Regional',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecione o documento Word com cabeçalho e rodapé da sua regional',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _selecionarTemplate,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Selecionar Template Word'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                if (_caminhoTemplate != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _caminhoTemplate!.split('/').last,
                            style: TextStyle(color: Colors.green.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isEdicao)
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            color: Colors.green.shade700,
                            onPressed: () {
                              setState(() {
                                _caminhoTemplate = null;
                              });
                            },
                            tooltip: 'Remover template',
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _carregando ? null : _salvarPerito,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _carregando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isEdicao ? 'Salvar Alterações' : 'Salvar Cadastro'),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
