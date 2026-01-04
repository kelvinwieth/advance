import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';
import 'ficha_analytics_screen.dart';
import 'ficha_form_screen.dart';

class FichasHomeScreen extends StatefulWidget {
  final AppDatabase database;

  const FichasHomeScreen({super.key, required this.database});

  @override
  State<FichasHomeScreen> createState() => _FichasHomeScreenState();
}

class _FichasHomeScreenState extends State<FichasHomeScreen> {
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
      if (!mounted) return;
      setState(() {
        _forms = forms;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao carregar as fichas.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm({VisitForm? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichaFormScreen(
          database: widget.database,
          existing: existing,
        ),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichas de Visita'),
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
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Fichas registradas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FichaAnalyticsScreen(
                                    database: widget.database,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.insights_outlined),
                              label: const Text('Insights'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _openForm(),
                              icon: const Icon(Icons.add),
                              label: const Text('Nova ficha'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _forms.isEmpty
                              ? const Center(
                                  child: Text('Nenhuma ficha cadastrada.'),
                                )
                              : ListView.separated(
                                  itemCount: _forms.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final form = _forms[index];
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _openForm(existing: form),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7FBFC),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFFE6E8EF),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              height: 44,
                                              width: 44,
                                              decoration: BoxDecoration(
                                                color:
                                                    const Color(0xFFE9F5F6),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.home_outlined,
                                                color: Color(0xFF038A99),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    form.address.isEmpty
                                                        ? 'Endereço não informado'
                                                        : form.address,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${form.city} · ${form.neighborhood}',
                                                    style: const TextStyle(
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _dateFormat
                                                        .format(form.visitAt),
                                                    style: const TextStyle(
                                                      color: Colors.black54,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
