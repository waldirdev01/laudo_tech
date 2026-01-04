import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/ficha_completa_model.dart';
import '../models/local_ficha_model.dart';
import '../services/ficha_service.dart';
import 'historico_screen.dart';

class LocalScreen extends StatefulWidget {
  final FichaCompletaModel ficha;

  const LocalScreen({super.key, required this.ficha});

  @override
  State<LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<LocalScreen> {
  final _fichaService = FichaService();
  final _enderecoController = TextEditingController();
  final _municipioController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _obtendoCoordenadas = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    // Preencher com dados da solicitação (se disponíveis)
    _enderecoController.text = widget.ficha.dadosSolicitacao.endereco ?? '';
    _municipioController.text = widget.ficha.dadosSolicitacao.municipio ?? '';

    // Carregar dados já salvos (se estiver editando)
    if (widget.ficha.local != null) {
      _enderecoController.text =
          widget.ficha.local!.endereco ?? _enderecoController.text;
      _municipioController.text =
          widget.ficha.local!.municipio ?? _municipioController.text;
      _latitude = widget.ficha.local!.latitude;
      _longitude = widget.ficha.local!.longitude;
    }
  }

  @override
  void dispose() {
    _enderecoController.dispose();
    _municipioController.dispose();
    super.dispose();
  }

  Future<bool> _solicitarPermissaoLocalizacao() async {
    try {
      // Verificar se já tem permissão
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Permissão de localização negada. Não será possível obter coordenadas.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permissão de localização negada permanentemente. Abra as configurações para permitir.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao verificar permissão: $e\nTente fazer um rebuild completo do app (flutter clean && flutter pub get).',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _obterCoordenadasGPS() async {
    setState(() {
      _obtendoCoordenadas = true;
    });

    try {
      final temPermissao = await _solicitarPermissaoLocalizacao();
      if (!temPermissao) {
        setState(() {
          _obtendoCoordenadas = false;
        });
        return;
      }

      // Verificar se o serviço de localização está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _obtendoCoordenadas = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Serviço de localização desabilitado. Por favor, habilite o GPS.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Obter posição atual com timeout
      Position position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Tempo limite excedido ao obter localização');
            },
          );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _obtendoCoordenadas = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordenadas obtidas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _obtendoCoordenadas = false;
        });

        String mensagemErro = 'Erro ao obter coordenadas: $e';

        // Mensagem mais amigável para MissingPluginException
        if (e.toString().contains('MissingPluginException')) {
          mensagemErro =
              'Plugin de GPS não encontrado. Por favor, execute:\n'
              '1. flutter clean\n'
              '2. flutter pub get\n'
              '3. Rebuild o app completamente';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagemErro),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _salvarLocal() async {
    setState(() {
      _salvando = true;
    });

    try {
      final local = LocalFichaModel(
        endereco: _enderecoController.text.trim().isEmpty
            ? null
            : _enderecoController.text.trim(),
        municipio: _municipioController.text.trim().isEmpty
            ? null
            : _municipioController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );

      // Preservar todos os dados existentes
      final fichaAtualizada = widget.ficha.copyWith(
        local: local,
        dataUltimaAtualizacao: DateTime.now(),
        equipe: widget.ficha.equipe,
        equipesPoliciais: widget.ficha.equipesPoliciais,
        dadosFichaBase: widget.ficha.dadosFichaBase,
      );

      await _fichaService.salvarFicha(fichaAtualizada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar para tela de histórico
        final navigator = Navigator.of(context);
        final resultado = await navigator.push(
          MaterialPageRoute(
            builder: (context) => HistoricoScreen(ficha: fichaAtualizada),
          ),
        );

        // Se voltou do histórico, retornar true para atualizar lista
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
    final localModel = LocalFichaModel(
      latitude: _latitude,
      longitude: _longitude,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Local'), centerTitle: true),
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
                'LOCAL',
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
                  // Linha 1: Endereço (largura total)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Endereço:',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _enderecoController,
                          decoration: const InputDecoration(
                            hintText: 'Digite o endereço completo',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Linha 2: Município e Coordenadas
                  Row(
                    children: [
                      // Município
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Município:',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _municipioController,
                                decoration: const InputDecoration(
                                  hintText: 'Nome do município',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 100,
                        color: Colors.grey.shade300,
                      ),
                      // Coordenadas
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Coordenadas:',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              if (_latitude != null && _longitude != null) ...[
                                Text(
                                  localModel.coordenadasSFormatada ?? '-',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  localModel.coordenadasWFormatada ?? '-',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ] else
                                Text(
                                  'S: ___° ___\' ___\'\nW: ___° ___\' ___\'',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _obtendoCoordenadas
                                    ? null
                                    : _obterCoordenadasGPS,
                                icon: _obtendoCoordenadas
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.gps_fixed, size: 18),
                                label: Text(
                                  _obtendoCoordenadas
                                      ? 'Obtendo...'
                                      : 'Obter GPS',
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _salvarLocal,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
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
          ],
        ),
      ),
    );
  }
}
