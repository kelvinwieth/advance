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
  List<VisitNeighborhoodCount> _neighborhoodCounts = [];

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
      final neighborhoodCounts = widget.database.fetchVisitNeighborhoodCounts();
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _neighborhoodCounts = neighborhoodCounts;
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

  Widget _buildMetric(
    String label,
    String value, {
    IconData? icon,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: compact ? 10 : 16,
      ),
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
        title: Row(
          children: [
            Image.asset(
              'assets/acev.png',
              height: 26,
            ),
            const SizedBox(width: 10),
            const Text('Insights'),
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

                                      final summaryMetrics = [
                                        _buildMetric(
                                          'Casas visitadas',
                                          _analytics!.totalVisits.toString(),
                                          icon: Icons.home_outlined,
                                          compact: true,
                                        ),
                                        _buildMetric(
                                          'Pessoas visitadas',
                                          _analytics!.totalPeople.toString(),
                                          icon: Icons.people_outline,
                                          compact: true,
                                        ),
                                        _buildMetric(
                                          'Crianças visitadas',
                                          _analytics!.ageChildren.toString(),
                                          icon: Icons.child_care_outlined,
                                          compact: true,
                                        ),
                                        _buildMetric(
                                          'Literaturas distribuídas',
                                          _analytics!.totalLiterature.toString(),
                                          icon: Icons.menu_book_outlined,
                                          compact: true,
                                        ),
                                        _buildMetric(
                                          'Decisões por Cristo',
                                          _analytics!.totalAceitouJesus.toString(),
                                          icon: Icons.volunteer_activism,
                                          compact: true,
                                        ),
                                        _buildMetric(
                                          'Reconciliações',
                                          _analytics!.totalReconciliacao.toString(),
                                          icon: Icons.handshake_outlined,
                                          compact: true,
                                        ),
                                        _buildMetric(
                                          'Nova visita solicitada',
                                          _analytics!.totalNovaVisita.toString(),
                                          icon: Icons.event_repeat,
                                          compact: true,
                                        ),
                                        _buildMetric(
                                          'Bairros alcançados',
                                          _analytics!.totalNeighborhoods.toString(),
                                          icon: Icons.map_outlined,
                                          compact: true,
                                        ),
                                      ];

                                      final summarySection = _buildSectionCard(
                                        title: 'Resumo geral',
                                        child: LayoutBuilder(
                                          builder: (context, summaryConstraints) {
                                            final maxWidth =
                                                summaryConstraints.maxWidth;
                                            final targetWidth = 240.0;
                                            final columns =
                                                (maxWidth / targetWidth)
                                                    .floor()
                                                    .clamp(2, 4);
                                            final spacing = 12.0;
                                            final cardWidth = (maxWidth -
                                                    (spacing * (columns - 1))) /
                                                columns;

                                            return Wrap(
                                              spacing: spacing,
                                              runSpacing: spacing,
                                              children: [
                                                for (final metric
                                                    in summaryMetrics)
                                                  SizedBox(
                                                    width: cardWidth,
                                                    child: metric,
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      );

                                      Widget buildAdaptiveGrid(
                                        List<Widget> items, {
                                        double targetWidth = 240,
                                      }) {
                                        return LayoutBuilder(
                                          builder: (context, gridConstraints) {
                                            final maxWidth =
                                                gridConstraints.maxWidth;
                                            final columns = (maxWidth /
                                                    targetWidth)
                                                .floor()
                                                .clamp(2, 4);
                                            final spacing = 12.0;
                                            final cardWidth = (maxWidth -
                                                    (spacing * (columns - 1))) /
                                                columns;
                                            return Wrap(
                                              spacing: spacing,
                                              runSpacing: spacing,
                                              children: [
                                                for (final item in items)
                                                  SizedBox(
                                                    width: cardWidth,
                                                    child: item,
                                                  ),
                                              ],
                                            );
                                          },
                                        );
                                      }

                                      final leftColumn = Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 16),
                                          _buildSectionCard(
                                            title: 'Indicadores',
                                            child: buildAdaptiveGrid(
                                              [
                                                _buildMetric(
                                                  'Média de pessoas por visita',
                                                  _formatAverage(
                                                    _analytics!.totalPeople,
                                                    _analytics!.totalVisits,
                                                  ),
                                                  icon: Icons.timeline,
                                                  compact: true,
                                                ),
                                                _buildMetric(
                                                  'Taxa de decisões por visita',
                                                  _formatPercent(
                                                    _analytics!
                                                        .totalAceitouJesus,
                                                    _analytics!.totalVisits,
                                                  ),
                                                  icon:
                                                      Icons.thumb_up_alt_outlined,
                                                  compact: true,
                                                ),
                                                _buildMetric(
                                                  'Taxa de nova visita por ficha',
                                                  _formatPercent(
                                                    _analytics!.totalNovaVisita,
                                                    _analytics!.totalVisits,
                                                  ),
                                                  icon: Icons.repeat,
                                                  compact: true,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildSectionCard(
                                            title: 'Resultados da visita',
                                            child: buildAdaptiveGrid(
                                              [
                                                _buildMetric(
                                                  'Gráfico apresentado',
                                                  _analytics!.totalEvangelho
                                                      .toString(),
                                                  icon:
                                                      Icons.auto_graph_outlined,
                                                  compact: true,
                                                ),
                                                _buildMetric(
                                                  'Ponte da Salvação',
                                                  _analytics!.totalPonteSalvacao
                                                      .toString(),
                                                  icon: Icons.alt_route_outlined,
                                                  compact: true,
                                                ),
                                                _buildMetric(
                                                  'Decisões',
                                                  _analytics!.totalAceitouJesus
                                                      .toString(),
                                                  icon:
                                                      Icons.volunteer_activism,
                                                  compact: true,
                                                ),
                                                _buildMetric(
                                                  'Reconciliações',
                                                  _analytics!
                                                      .totalReconciliacao
                                                      .toString(),
                                                  icon: Icons.handshake_outlined,
                                                  compact: true,
                                                ),
                                                _buildMetric(
                                                  'Primeira vez no Evangelho',
                                                  _analytics!.totalPrimeiraVez
                                                      .toString(),
                                                  icon:
                                                      Icons.flash_on_outlined,
                                                  compact: true,
                                                ),
                                                _buildMetric(
                                                  'Deseja nova visita',
                                                  _analytics!.totalNovaVisita
                                                      .toString(),
                                                  icon: Icons.event_repeat,
                                                  compact: true,
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
                                            title: 'Bairros com mais visitas',
                                            child: _neighborhoodCounts.isEmpty
                                                ? const Text(
                                                    'Nenhum bairro registrado.',
                                                    style: TextStyle(
                                                      color: Colors.black54,
                                                    ),
                                                  )
                                                : Column(
                                                    children: _neighborhoodCounts
                                                        .map(
                                                          (item) => Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                              bottom: 10,
                                                            ),
                                                            child:
                                                                _buildDistributionBar(
                                                              label: item.neighborhood,
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
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    summarySection,
                                                    const SizedBox(height: 16),
                                                    leftColumn,
                                                  ],
                                                ),
                                              ),
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
                                            summarySection,
                                            const SizedBox(height: 16),
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
