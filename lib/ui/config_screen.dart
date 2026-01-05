import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'widgets/app_dialog.dart';

class ConfigScreen extends StatelessWidget {
  final AppDatabase database;

  const ConfigScreen({super.key, required this.database});

  Future<void> _exportDatabaseCopy(BuildContext context) async {
    final saveLocation = await getSaveLocation(
      suggestedName: 'avanco.db',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'SQLite', extensions: ['db']),
      ],
    );
    if (saveLocation == null) return;

    try {
      database.exportDatabase(saveLocation.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banco exportado com sucesso.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao exportar o banco.')),
      );
    }
  }

  Future<void> _importDatabaseCopy(BuildContext context) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'SQLite', extensions: ['db']),
      ],
    );
    if (file == null) return;

    final confirmed = await _confirmImportDatabase(context);
    if (!confirmed) return;

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const Center(child: CircularProgressIndicator());
        },
      );
      await database.importDatabase(file.path);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banco importado com sucesso.')),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao importar o banco.')),
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

  Future<bool> _confirmImportDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Importar banco',
          onClose: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Isso vai substituir o banco atual pelos dados importados.',
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
                child: const Text('Importar'),
              ),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/acev.png',
              height: 26,
            ),
            const SizedBox(width: 10),
            const Text('Configurações'),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 980,
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Gerencie dados, testes e exportações do backoffice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;
                        final children = [
                          _ConfigOptionCard(
                            title: 'Limpar banco',
                            description:
                                'Remove todas as tarefas, fichas e atribuições.',
                            icon: Icons.delete_outline,
                          onTap: () async {
                            final confirm =
                                await _confirmClearDatabase(context);
                            if (!confirm) return;
                            try {
                              await database.clearDatabase();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Banco limpo.'),
                                ),
                              );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Falha ao limpar o banco.'),
                                  ),
                                );
                              }
                            },
                          ),
                          _ConfigOptionCard(
                            title: 'Banco de teste',
                            description:
                                'Adiciona dados simulados para tarefas e fichas.',
                            icon: Icons.auto_fix_high_outlined,
                            onTap: () async {
                              final confirm =
                                  await _confirmMockDatabase(context);
                              if (!confirm) return;
                              try {
                                final now = DateTime.now();
                                final isoDate =
                                    now.toIso8601String().split('T').first;
                                database.insertMockData(isoDate: isoDate);
                                database.insertMockVisitForms();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Dados de teste adicionados.'),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Falha ao adicionar dados de teste.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          _ConfigOptionCard(
                            title: 'Exportar banco',
                            description:
                                'Salve uma cópia completa do banco de dados.',
                            icon: Icons.download_outlined,
                            onTap: () => _exportDatabaseCopy(context),
                          ),
                          _ConfigOptionCard(
                            title: 'Importar banco',
                            description:
                                'Substitua o banco atual por um arquivo externo.',
                            icon: Icons.upload_file_outlined,
                            onTap: () => _importDatabaseCopy(context),
                          ),
                        ];

                        const cardWidth = 420.0;
                        if (isNarrow) {
                          return Column(
                            children: [
                              for (var i = 0; i < children.length; i++) ...[
                                SizedBox(width: cardWidth, child: children[i]),
                                if (i != children.length - 1)
                                  const SizedBox(height: 16),
                              ],
                            ],
                          );
                        }

                        return Center(
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: children
                                .map(
                                  (card) => SizedBox(
                                    width: cardWidth,
                                    child: card,
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConfigOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ConfigOptionCard({
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
                      color: Color(0xFF1D1D1D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}
