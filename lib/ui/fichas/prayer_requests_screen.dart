import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';
import 'ficha_form_screen.dart';

class PrayerRequestsScreen extends StatefulWidget {
  final AppDatabase database;

  const PrayerRequestsScreen({super.key, required this.database});

  @override
  State<PrayerRequestsScreen> createState() => _PrayerRequestsScreenState();
}

class _PrayerRequestsScreenState extends State<PrayerRequestsScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  bool _loading = true;
  String? _errorMessage;
  List<VisitForm> _forms = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final forms = widget.database.fetchVisitForms();
      final filtered = forms
          .where((form) => form.prayerRequests.trim().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _forms = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao carregar os pedidos de oração.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm(VisitForm form) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichaFormScreen(
          database: widget.database,
          existing: form,
        ),
      ),
    );
    _loadData();
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
            const Text('Pedidos de oração'),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6E8EF)),
                    ),
                    child: _forms.isEmpty
                        ? const Center(
                            child: Text('Nenhum pedido de oração registrado.'),
                          )
                        : ListView.separated(
                            itemCount: _forms.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final form = _forms[index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openForm(form),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7FBFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE6E8EF),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        form.prayerRequests,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1D1D1D),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${form.names.isEmpty ? 'Visita sem nomes' : form.names} · ${form.neighborhood}',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_dateFormat.format(form.visitAt)} · ${form.team.isEmpty ? 'Equipe não informada' : form.team}',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
    );
  }
}
