import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme_provider.dart';
import 'cadastro_perito_screen.dart';
import 'equipe_screen.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Text(
            'Aparência',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('Tema'),
                  subtitle: Text(
                    themeProvider.themeMode == ThemeMode.light
                        ? 'Claro'
                        : themeProvider.themeMode == ThemeMode.dark
                        ? 'Escuro'
                        : 'Sistema',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _mostrarDialogoTema(context, themeProvider);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Perfil',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Editar Perito'),
                  subtitle: const Text('Alterar dados do perito cadastrado'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const CadastroPeritoScreen(isEdicao: true),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Equipe',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Gerenciar Equipe'),
                  subtitle: const Text(
                    'Cadastrar membros da equipe de perícia',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const EquipeScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoTema(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escolher Tema'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Claro'),
                  leading: Icon(
                    themeProvider.themeMode == ThemeMode.light
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.light);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: const Text('Escuro'),
                  leading: Icon(
                    themeProvider.themeMode == ThemeMode.dark
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.dark);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: const Text('Sistema'),
                  leading: Icon(
                    themeProvider.themeMode == ThemeMode.system
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.system);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
