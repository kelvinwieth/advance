import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'config_screen.dart';
import 'fichas/fichas_home_screen.dart';
import 'home_screen.dart';
import 'widgets/app_dialog.dart';

class EntryScreen extends StatelessWidget {
  final AppDatabase database;

  const EntryScreen({super.key, required this.database});

  Future<void> _promptConfigAccess(BuildContext context) async {
    final controller = TextEditingController();
    String? errorText;
    var obscure = true;
    final confirmed = kDebugMode
        ? true
        : await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return AppDialog(
                    title: 'Acesso às configurações',
                    onClose: () => Navigator.of(dialogContext).pop(false),
                    actions: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: AppDialog.outlinedStyle(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (controller.text.trim() != 'molodoy') {
                              setModalState(() {
                                errorText = 'Senha incorreta.';
                              });
                              return;
                            }
                            Navigator.of(dialogContext).pop(true);
                          },
                          style: AppDialog.primaryStyle(),
                          child: const Text('Acessar'),
                        ),
                      ),
                    ],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Digite a senha para continuar.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            filled: true,
                            fillColor: AppDialog.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setModalState(() {
                                  obscure = !obscure;
                                });
                              },
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => setModalState(() {}),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorText!,
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
    controller.dispose();
    if (confirmed == true) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConfigScreen(database: database),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/acev.png',
                  height: 68,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Avanço Missionário',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Escolha o módulo que você deseja acessar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 640;
                    final children = [
                      _ModuleCard(
                        title: 'Tarefas',
                        description:
                            'Organize as tarefas diárias da equipe de staff.',
                        icon: Icons.event_note,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HomeScreen(database: database),
                            ),
                          );
                        },
                      ),
                      _ModuleCard(
                        title: 'Fichas',
                        description:
                            'Registre e acompanhe as visitas missionárias.',
                        icon: Icons.assignment_turned_in_outlined,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  FichasHomeScreen(database: database),
                            ),
                          );
                        },
                      ),
                      _ModuleCard(
                        title: 'Configurações',
                        description: 'Gerencie dados, testes e exportação.',
                        icon: Icons.settings,
                        onTap: () => _promptConfigAccess(context),
                      ),
                    ];

                    if (isNarrow) {
                      return Column(
                        children: [
                          children[0],
                          const SizedBox(height: 16),
                          children[1],
                          const SizedBox(height: 16),
                          children[2],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: children[0]),
                        const SizedBox(width: 16),
                        Expanded(child: children[1]),
                        const SizedBox(width: 16),
                        Expanded(child: children[2]),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6E8EF)),
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F5F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF038A99)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
