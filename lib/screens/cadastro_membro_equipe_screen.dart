import 'package:flutter/material.dart';
import '../models/membro_equipe_model.dart';
import '../services/equipe_service.dart';

class CadastroMembroEquipeScreen extends StatefulWidget {
  final MembroEquipeModel? membro; // Se fornecido, está editando

  const CadastroMembroEquipeScreen({
    super.key,
    this.membro,
  });

  @override
  State<CadastroMembroEquipeScreen> createState() => _CadastroMembroEquipeScreenState();
}

class _CadastroMembroEquipeScreenState extends State<CadastroMembroEquipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cargoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _matriculaController = TextEditingController();
  
  bool _salvando = false;
  final _equipeService = EquipeService();

  @override
  void initState() {
    super.initState();
    if (widget.membro != null) {
      _cargoController.text = widget.membro!.cargo;
      _nomeController.text = widget.membro!.nome;
      _matriculaController.text = widget.membro!.matricula;
    }
  }

  @override
  void dispose() {
    _cargoController.dispose();
    _nomeController.dispose();
    _matriculaController.dispose();
    super.dispose();
  }

  Future<void> _salvarMembro() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      final id = widget.membro?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      final membro = MembroEquipeModel(
        id: id,
        cargo: _cargoController.text.trim(),
        nome: _nomeController.text.trim(),
        matricula: _matriculaController.text.trim(),
      );

      if (widget.membro != null) {
        await _equipeService.atualizarMembro(membro);
      } else {
        await _equipeService.adicionarMembro(membro);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.membro != null
                ? 'Membro atualizado com sucesso!'
                : 'Membro adicionado à equipe!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
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
        title: Text(widget.membro != null ? 'Editar Membro' : 'Adicionar Membro'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: _cargoController,
                decoration: const InputDecoration(
                  labelText: 'Cargo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                  hintText: 'Ex: Perito Criminal, Fotógrafo Criminalístico',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, informe o cargo';
                  }
                  return null;
                },
              ),
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
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, informe a matrícula';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _salvando ? null : _salvarMembro,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(widget.membro != null ? 'Salvar Alterações' : 'Adicionar à Equipe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

