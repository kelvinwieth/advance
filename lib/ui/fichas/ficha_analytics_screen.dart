import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';

class FichaAnalyticsScreen extends StatefulWidget {
  final AppDatabase database;

  const FichaAnalyticsScreen({super.key, required this.database});

  @override
  State<FichaAnalyticsScreen> createState() => _FichaAnalyticsScreenState();
}

class _FichaAnalyticsScreenState extends State<FichaAnalyticsScreen> {
  bool _loading = true;
  String? _errorMessage;
  VisitAnalytics? _analytics;

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
      final analytics = widget.database.fetchVisitAnalytics();
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao carregar os insights.';
        _loading = false;
      });
    }
  }

  Widget _buildMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights das Fichas'),
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6E8EF)),
                    ),
                    child: _analytics == null
                        ? const Center(
                            child: Text('Nenhum dado disponível.'),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resumo geral',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildMetric(
                                    'Total de visitas',
                                    _analytics!.totalVisits.toString(),
                                  ),
                                  _buildMetric(
                                    'Total de pessoas alcançadas',
                                    _analytics!.totalPeople.toString(),
                                  ),
                                  _buildMetric(
                                    'Total de pessoas que aceitaram Jesus',
                                    _analytics!.totalAceitouJesus.toString(),
                                  ),
                                  _buildMetric(
                                    'Visitas com pedido de nova visita',
                                    _analytics!.totalNovaVisita.toString(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Distribuição por faixa etária',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildMetric(
                                'Crianças',
                                _analytics!.ageChildren.toString(),
                              ),
                              const SizedBox(height: 8),
                              _buildMetric(
                                'Jovens',
                                _analytics!.ageYouth.toString(),
                              ),
                              const SizedBox(height: 8),
                              _buildMetric(
                                'Adultos',
                                _analytics!.ageAdults.toString(),
                              ),
                              const SizedBox(height: 8),
                              _buildMetric(
                                'Idosos',
                                _analytics!.ageElderly.toString(),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Distribuição por religião',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildMetric(
                                'Católica',
                                _analytics!.religionCatolica.toString(),
                              ),
                              const SizedBox(height: 8),
                              _buildMetric(
                                'Espírita',
                                _analytics!.religionEspirita.toString(),
                              ),
                              const SizedBox(height: 8),
                              _buildMetric(
                                'Ateu',
                                _analytics!.religionAteu.toString(),
                              ),
                              const SizedBox(height: 8),
                              _buildMetric(
                                'Desviado',
                                _analytics!.religionDesviado.toString(),
                              ),
                              const SizedBox(height: 8),
                              _buildMetric(
                                'Outros',
                                _analytics!.religionOutros.toString(),
                              ),
                            ],
                          ),
                  ),
                ),
    );
  }
}
