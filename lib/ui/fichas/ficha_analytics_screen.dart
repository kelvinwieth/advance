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
  List<VisitCityCount> _cityCounts = [];

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
      final cityCounts = widget.database.fetchVisitCityCounts();
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _cityCounts = cityCounts;
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

  Widget _buildMetric(String label, String value, {IconData? icon}) {
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
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: const Color(0xFF038A99)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBar({
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    final percent = total == 0 ? 0.0 : value / total;
    final percentLabel = total == 0
        ? '0%'
        : '${(percent * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                percentLabel,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EFF2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              widthFactor: percent,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPercent(int part, int total) {
    if (total == 0) return '0%';
    final value = (part / total) * 100;
    return '${value.toStringAsFixed(0)}%';
  }

  String _formatAverage(int total, int count) {
    if (count == 0) return '0';
    final value = total / count;
    return value.toStringAsFixed(1).replaceFirst('.', ',');
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
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
                  child: SizedBox.expand(
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
                                Row(
                                  children: [
                                    Container(
                                      height: 44,
                                      width: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE9F5F6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.insights_outlined,
                                        color: Color(0xFF038A99),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Panorama das visitas',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Acompanhe volume, impacto e perfil das pessoas alcançadas.',
                                            style: TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final twoColumns =
                                          constraints.maxWidth >= 900;

                                      final leftColumn = Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionCard(
                                            title: 'Resumo geral',
                                            child: Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: [
                                                _buildMetric(
                                                  'Total de visitas',
                                                  _analytics!.totalVisits
                                                      .toString(),
                                                  icon: Icons.home_outlined,
                                                ),
                                                _buildMetric(
                                                  'Pessoas alcançadas',
                                                  _analytics!.totalPeople
                                                      .toString(),
                                                  icon: Icons.people_outline,
                                                ),
                                                _buildMetric(
                                                  'Aceitaram Jesus',
                                                  _analytics!.totalAceitouJesus
                                                      .toString(),
                                                  icon: Icons.favorite_border,
                                                ),
                                                _buildMetric(
                                                  'Nova visita solicitada',
                                                  _analytics!.totalNovaVisita
                                                      .toString(),
                                                  icon: Icons.event_repeat,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildSectionCard(
                                            title: 'Indicadores',
                                            child: Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: [
                                                _buildMetric(
                                                  'Média de pessoas por visita',
                                                  _formatAverage(
                                                    _analytics!.totalPeople,
                                                    _analytics!.totalVisits,
                                                  ),
                                                  icon: Icons.timeline,
                                                ),
                                                _buildMetric(
                                                  'Taxa de decisões',
                                                  _formatPercent(
                                                    _analytics!
                                                        .totalAceitouJesus,
                                                    _analytics!.totalPeople,
                                                  ),
                                                  icon:
                                                      Icons.thumb_up_alt_outlined,
                                                ),
                                                _buildMetric(
                                                  'Taxa de nova visita',
                                                  _formatPercent(
                                                    _analytics!.totalNovaVisita,
                                                    _analytics!.totalVisits,
                                                  ),
                                                  icon: Icons.repeat,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildSectionCard(
                                            title: 'Resultados da visita',
                                            child: Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: [
                                                _buildMetric(
                                                  'Evangelho apresentado',
                                                  _analytics!.totalEvangelho
                                                      .toString(),
                                                ),
                                                _buildMetric(
                                                  'Ponte da Salvação',
                                                  _analytics!.totalPonteSalvacao
                                                      .toString(),
                                                ),
                                                _buildMetric(
                                                  'Reconciliações',
                                                  _analytics!
                                                      .totalReconciliacao
                                                      .toString(),
                                                ),
                                                _buildMetric(
                                                  'Primeira vez',
                                                  _analytics!.totalPrimeiraVez
                                                      .toString(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );

                                      final rightColumn = Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionCard(
                                            title: 'Distribuição por faixa etária',
                                            child: Column(
                                              children: [
                                                _buildDistributionBar(
                                                  label: 'Crianças',
                                                  value: _analytics!.ageChildren,
                                                  total: _analytics!.totalPeople,
                                                  color: const Color(0xFF8CC9CE),
                                                ),
                                                const SizedBox(height: 10),
                                                _buildDistributionBar(
                                                  label: 'Jovens',
                                                  value: _analytics!.ageYouth,
                                                  total: _analytics!.totalPeople,
                                                  color: const Color(0xFF4FA5AE),
                                                ),
                                                const SizedBox(height: 10),
                                                _buildDistributionBar(
                                                  label: 'Adultos',
                                                  value: _analytics!.ageAdults,
                                                  total: _analytics!.totalPeople,
                                                  color: const Color(0xFF038A99),
                                                ),
                                                const SizedBox(height: 10),
                                                _buildDistributionBar(
                                                  label: 'Idosos',
                                                  value: _analytics!.ageElderly,
                                                  total: _analytics!.totalPeople,
                                                  color: const Color(0xFFB3DFE9),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildSectionCard(
                                            title: 'Distribuição por religião',
                                            child: Column(
                                              children: [
                                                _buildDistributionBar(
                                                  label: 'Católica',
                                                  value:
                                                      _analytics!.religionCatolica,
                                                  total: _analytics!.totalPeople,
                                                  color: const Color(0xFF038A99),
                                                ),
                                                const SizedBox(height: 10),
                                                _buildDistributionBar(
                                                  label: 'Espírita',
                                                  value:
                                                      _analytics!.religionEspirita,
                                                  total: _analytics!.totalPeople,
                                                  color: const Color(0xFF4FA5AE),
                                                ),
                                                const SizedBox(height: 10),
                                                _buildDistributionBar(
                                                  label: 'Ateu',
                                                  value: _analytics!.religionAteu,
                                                  total: _analytics!.totalPeople,
                                                  color: const Color(0xFF8CC9CE),
                                                ),
                                                const SizedBox(height: 10),
                                                _buildDistributionBar(
                                                  label: 'Desviado',
                                                  value:
                                                      _analytics!.religionDesviado,
                                                  total: _analytics!.totalPeople,
                                                  color: const Color(0xFFB3DFE9),
                                                ),
                                                const SizedBox(height: 10),
                                                _buildDistributionBar(
                                                  label: 'Outros',
                                                  value: _analytics!.religionOutros,
                                                  total: _analytics!.totalPeople,
                                                  color: const Color(0xFF1D1D1D),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildSectionCard(
                                            title: 'Cidades com mais visitas',
                                            child: _cityCounts.isEmpty
                                                ? const Text(
                                                    'Nenhuma cidade registrada.',
                                                    style: TextStyle(
                                                      color: Colors.black54,
                                                    ),
                                                  )
                                                : Column(
                                                    children: _cityCounts
                                                        .map(
                                                          (item) => Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                              bottom: 10,
                                                            ),
                                                            child:
                                                                _buildDistributionBar(
                                                              label: item.city,
                                                              value: item.total,
                                                              total: _analytics!
                                                                  .totalVisits,
                                                              color: const Color(
                                                                0xFF038A99,
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                  ),
                                          ),
                                        ],
                                      );

                                      if (twoColumns) {
                                        return SingleChildScrollView(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: leftColumn),
                                              const SizedBox(width: 20),
                                              Expanded(child: rightColumn),
                                            ],
                                          ),
                                        );
                                      }

                                      return SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            leftColumn,
                                            const SizedBox(height: 20),
                                            rightColumn,
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
    );
  }
}
