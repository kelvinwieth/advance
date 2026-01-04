import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'fichas/fichas_home_screen.dart';
import 'home_screen.dart';
import 'widgets/app_dialog.dart';

class EntryScreen extends StatelessWidget {
  final AppDatabase database;

  const EntryScreen({super.key, required this.database});

  Future<void> _exportDatabaseCopy(BuildContext context) async {
    final saveLocation = await getSaveLocation(
      suggestedName: 'avanco.db',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'SQLite', extensions: ['db']),
      ],
    );
    if (saveLocation == null) return;

    try {
      final source = File(database.dbPath);
      await source.copy(saveLocation.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banco exportado com sucesso.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao exportar o banco.')),
      );
    }
  }

  Future<bool> _confirmClearDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Limpar banco',
          onClose: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Isso vai remover permanentemente membros, tarefas, fichas e atribuições. '
            'Esta ação não pode ser desfeita.',
          ),
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: AppDialog.outlinedStyle(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: AppDialog.destructiveStyle(),
                child: const Text('Limpar banco'),
              ),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<bool> _confirmMockDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Banco de teste',
          onClose: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Isso vai adicionar dados de teste para tarefas e fichas.',
          ),
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: AppDialog.outlinedStyle(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: AppDialog.primaryStyle(),
                child: const Text('Adicionar dados de teste'),
              ),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _showConfigDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Configurações',
          onClose: () => Navigator.of(dialogContext).pop(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Gerencie dados e backups do backoffice.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final confirm = await _confirmClearDatabase(dialogContext);
                  if (!confirm) return;
                  try {
                    database.clearDatabase();
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Banco limpo.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Falha ao limpar o banco.')),
                    );
                  }
                },
                style: AppDialog.destructiveStyle(),
                child: const Text('Limpar banco'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final confirm = await _confirmMockDatabase(dialogContext);
                  if (!confirm) return;
                  try {
                    final now = DateTime.now();
                    final isoDate =
                        now.toIso8601String().split('T').first;
                    database.insertMockData(isoDate: isoDate);
                    database.insertMockVisitForms();
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dados de teste adicionados.'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Falha ao adicionar dados de teste.'),
                      ),
                    );
                  }
                },
                style: AppDialog.outlinedStyle(),
                child: const Text('Banco de teste'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _exportDatabaseCopy(context);
                },
                style: AppDialog.primaryStyle(),
                child: const Text('Exportar banco'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _promptConfigAccess(BuildContext context) async {
    final controller = TextEditingController();
    String? errorText;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AppDialog(
              title: 'Acesso às configurações',
              onClose: () => Navigator.of(dialogContext).pop(false),
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
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Senha',
                      filled: true,
                      fillColor: AppDialog.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
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
              actions: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
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
            );
          },
        );
      },
    );
    controller.dispose();
    if (confirmed == true) {
      await _showConfigDialog(context);
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
