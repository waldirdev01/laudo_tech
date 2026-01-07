import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ficha_completa_model.dart';
import '../models/tipo_ocorrencia.dart';
import '../services/ficha_service.dart';
import 'dano_screen.dart';

class ModusOperandiScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const ModusOperandiScreen({
    super.key,
    required this.ficha,
  });

  @override
  State<ModusOperandiScreen> createState() => _ModusOperandiScreenState();
}

class _ModusOperandiScreenState extends State<ModusOperandiScreen> {
  final _fichaService = FichaService();
  final _modusOperandiController = TextEditingController();
  bool _salvando = false;
  bool? _conclusaoPositiva;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    // Carregar modus operandi já salvo (se estiver editando)
    if (widget.ficha.modusOperandi != null) {
      _modusOperandiController.text = widget.ficha.modusOperandi!;
    }
    // Carregar conclusão já escolhida
    _conclusaoPositiva = widget.ficha.conclusaoPositiva;
  }

  @override
  void dispose() {
    _modusOperandiController.dispose();
    super.dispose();
  }

  Future<FichaCompletaModel?> _salvarModusOperandi({bool fecharTela = true}) async {
    setState(() {
      _salvando = true;
    });

    try {
      // Se for finalizar, preencher data/hora de término APENAS se ainda não estiver preenchido
      String? dataHoraTermino;
      if (fecharTela) {
        // Salvar e Finalizar - preencher data/hora de término apenas se estiver vazio
        if (widget.ficha.dataHoraTermino == null || widget.ficha.dataHoraTermino!.isEmpty) {
          final agora = DateTime.now();
          dataHoraTermino = DateFormat('dd/MM/yyyy HH:mm').format(agora);
        } else {
          // Preservar o valor já existente (pode ter sido editado manualmente)
          dataHoraTermino = widget.ficha.dataHoraTermino;
        }
      } else {
        // Se não for finalizar, preservar o valor existente
        dataHoraTermino = widget.ficha.dataHoraTermino;
      }
      
      // Preservar todos os dados existentes
      final fichaAtualizada = widget.ficha.copyWith(
        modusOperandi: _modusOperandiController.text.trim().isEmpty
            ? null
            : _modusOperandiController.text.trim(),
        conclusaoPositiva: _conclusaoPositiva,
        dataHoraTermino: dataHoraTermino,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: widget.ficha.equipe,
        equipesPoliciais: widget.ficha.equipesPoliciais,
        local: widget.ficha.local,
        dadosFichaBase: widget.ficha.dadosFichaBase,
        localFurto: widget.ficha.localFurto,
        evidenciasFurto: widget.ficha.evidenciasFurto,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modus Operandi salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        if (fecharTela) {
          // Retornar true para atualizar lista
          Navigator.of(context).pop(true);
          return null;
        } else {
          return fichaAtualizada;
        }
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
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
        title: const Text('Modus Operandi'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
                'MODUS OPERANDI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Área de texto
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextFormField(
                  controller: _modusOperandiController,
                  decoration: const InputDecoration(
                    hintText: 'Digite o modus operandi...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  maxLines: null,
                  minLines: 8,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Seção de Conclusão
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
                'CONCLUSÃO DO LAUDO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Escolha o tipo de conclusão para o laudo:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<bool>(
                      title: const Text('Conclusão Positiva'),
                      subtitle: const Text(
                        'Os vestígios coletados permitiram análise e forneceram subsídios técnicos suficientes.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: true,
                      groupValue: _conclusaoPositiva,
                      onChanged: (value) {
                        setState(() {
                          _conclusaoPositiva = value;
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      title: const Text('Conclusão Negativa (Exiguidade de Vestígios)'),
                      subtitle: const Text(
                        'A ausência ou insuficiência de vestígios não permitiu conclusões mais detalhadas.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: false,
                      groupValue: _conclusaoPositiva,
                      onChanged: (value) {
                        setState(() {
                          _conclusaoPositiva = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Verificar se é tipo que inclui dano
            if (widget.ficha.tipoOcorrencia == TipoOcorrencia.furtoDanoExameLocal) ...[
              FilledButton(
                onPressed: _salvando ? null : () async {
                  final navigator = Navigator.of(context);
                  final fichaAtualizada = await _salvarModusOperandi(fecharTela: false);
                  if (!mounted || fichaAtualizada == null) return;
                  final resultado = await navigator.push(
                    MaterialPageRoute(
                      builder: (context) => DanoScreen(ficha: fichaAtualizada),
                    ),
                  );
                  if (!mounted) return;
                  if (resultado == true) {
                    navigator.pop(true);
                  }
                },
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
                    : const Text('Salvar e Ir para Dano'),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: _salvando ? null : () => _salvarModusOperandi(fecharTela: true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _salvando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Salvar e Finalizar'),
            ),
          ],
        ),
      ),
    );
  }
}

