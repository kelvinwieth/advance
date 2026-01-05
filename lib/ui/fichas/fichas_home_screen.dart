import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';
import 'ficha_analytics_screen.dart';
import 'ficha_form_screen.dart';
import 'prayer_requests_screen.dart';

class FichasHomeScreen extends StatefulWidget {
  final AppDatabase database;

  const FichasHomeScreen({super.key, required this.database});

  @override
  State<FichasHomeScreen> createState() => _FichasHomeScreenState();
}

class _FichasHomeScreenState extends State<FichasHomeScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  final DateFormat _filterDateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _errorMessage;
  List<VisitForm> _forms = [];
  bool _filterNovaVisita = false;
  DateTime? _filterDate;
  bool _orderAsc = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final initial = _filterDate ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() {
      _filterDate = DateTime(date.year, date.month, date.day);
    });
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
            const Text('Fichas'),
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
                              builder: (_) => PrayerRequestsScreen(
                                database: widget.database,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.favorite_border),
                          label: const Text('Pedidos de oração'),
                        ),
                        const SizedBox(width: 12),
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
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar por nome, bairro, endereço, referência ou equipe',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: const Color(0xFFF1F2F6),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Tooltip(
                          message: _filterDate == null
                              ? 'Filtrar por data'
                              : 'Remover filtro de data',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _filterDate == null
                                ? _pickFilterDate
                                : () => setState(() {
                                    _filterDate = null;
                                  }),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F2F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    _filterDate == null
                                        ? 'Data'
                                        : _filterDateFormat.format(
                                            _filterDate!,
                                          ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _filterDate == null
                                        ? Icons.expand_more
                                        : Icons.close,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Tooltip(
                          message: _orderAsc
                              ? 'Ordenar por data (mais antigas primeiro)'
                              : 'Ordenar por data (mais recentes primeiro)',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _orderAsc = !_orderAsc;
                              });
                            },
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F2F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _orderAsc
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _filterNovaVisita = !_filterNovaVisita;
                            });
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _filterNovaVisita
                                  ? const Color(0xFFE1F2F4)
                                  : const Color(0xFFF1F2F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _filterNovaVisita
                                    ? const Color(0xFF8CC9CE)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_filterNovaVisita) ...[
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Color(0xFF038A99),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  'Deseja nova visita',
                                  style: TextStyle(
                                    color: _filterNovaVisita
                                        ? const Color(0xFF1D1D1D)
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Tooltip(
                          message: 'Limpar filtros',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _filterNovaVisita = false;
                                _filterDate = null;
                                _orderAsc = false;
                                _searchController.clear();
                              });
                            },
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F2F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.filter_alt_off_outlined,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildFilteredList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilteredList() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _forms.where((form) {
      if (_filterNovaVisita && !form.resultNovaVisita) return false;
      if (_filterDate != null) {
        final visitDate = DateTime(
          form.visitAt.year,
          form.visitAt.month,
          form.visitAt.day,
        );
        if (visitDate != _filterDate) return false;
      }
      if (query.isEmpty) return true;
      return form.names.toLowerCase().contains(query) ||
          form.neighborhood.toLowerCase().contains(query) ||
          form.address.toLowerCase().contains(query) ||
          form.referencePoint.toLowerCase().contains(query) ||
          form.team.toLowerCase().contains(query);
    }).toList();

    filtered.sort(
      (a, b) => _orderAsc
          ? a.visitAt.compareTo(b.visitAt)
          : b.visitAt.compareTo(a.visitAt),
    );

    return filtered.isEmpty
        ? const Center(child: Text('Nenhuma ficha encontrada.'))
        : ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final form = filtered[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openForm(existing: form),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFC),
                    borderRadius: BorderRadius.circular(16),
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
                          color: const Color(0xFFE9F5F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          color: Color(0xFF038A99),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              form.names.isEmpty
                                  ? 'Visita sem nomes'
                                  : form.names,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${form.neighborhood} · ${form.address}${form.referencePoint.isEmpty ? '' : ' · ${form.referencePoint}'}',
                              style: const TextStyle(
                                color: Colors.black54,
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
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
