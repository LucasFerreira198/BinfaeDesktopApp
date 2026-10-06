import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cautela.dart';
import '../models/item.dart';
import '../providers/auth_provider.dart';
import '../providers/stock_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/cautela_detail_dialog.dart';
import '../widgets/item_detail_dialog.dart';

class HomeDashboardView extends StatefulWidget {
  final Function(int tabIndex, {String? statusFilter}) onNavigate;
  final VoidCallback onNewItem;
  final VoidCallback onNewCautela;

  const HomeDashboardView({
    super.key,
    required this.onNavigate,
    required this.onNewItem,
    required this.onNewCautela,
  });

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  List<CautelaModel> _recentCautelas = [];
  List<ItemMovementModel> _recentMovements = [];
  bool _isLoadingActivities = true;

  @override
  void initState() {
    super.initState();
    _startClock();
    _loadDashboardActivities();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _loadDashboardActivities() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final results = await Future.wait([
        api.listCautelas(status: 'ATIVA').catchError((_) => <CautelaModel>[]),
        api.fetchMovements().catchError((_) => <ItemMovementModel>[]),
      ]);

      if (mounted) {
        setState(() {
          _recentCautelas = (results[0] as List<CautelaModel>).take(6).toList();
          _recentMovements = (results[1] as List<ItemMovementModel>).take(6).toList();
          _isLoadingActivities = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingActivities = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stock = Provider.of<StockProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final metrics = stock.metrics;
    final groups = stock.groups;
    final allItems = stock.allItems;

    final formattedTime = DateFormat('HH:mm:ss').format(_currentTime);
    final formattedDate = AppDateUtils.formatDateLong(_currentTime);

    return RefreshIndicator(
      onRefresh: () async {
        await stock.syncData();
        await _loadDashboardActivities();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER OPERACIONAL: BREADCRUMB & RELÓGIO OFICIAL DE BRASÍLIA
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 720;
                final breadcrumbWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            ' | Centro de Operações de TI',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Base Aérea do Galeão (BINFAE-GL) • Operador: ${user != null ? user.displayName : "S2 D. PAULA"}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                );

                final clockWidget = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151D2A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$formattedTime UTC-3',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• Vercel SP Online',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cyan,
                        ),
                      ),
                    ],
                  ),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      breadcrumbWidget,
                      const SizedBox(height: 12),
                      clockWidget,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: breadcrumbWidget),
                    const SizedBox(width: 16),
                    clockWidget,
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // 2. LINHA DE 5 KPIS MODERNOS (Estilo LogiFlow / LoanHub)
            LayoutBuilder(
              builder: (context, constraints) {
                final List<Widget> kpiCards = <Widget>[
                  _ModernKpiCard(
                    title: 'Total Materiais',
                    value: '${metrics.total}',
                    badgeText: 'Total',
                    badgeColor: AppColors.cyan,
                    isDark: isDark,
                    trailingWidget: _MiniBarSparkline(color: AppColors.cyan),
                    onTap: () => widget.onNavigate(1),
                  ),
                  _ModernKpiCard(
                    title: 'No Depósito',
                    value: '${metrics.disponivel}',
                    badgeText: metrics.total > 0 ? '${((metrics.disponivel / metrics.total) * 100).toStringAsFixed(0)}%' : '0%',
                    badgeColor: AppColors.success,
                    isDark: isDark,
                    trailingWidget: _GaugeArc(
                      ratio: metrics.total > 0 ? (metrics.disponivel / metrics.total) : 0.8,
                      color: AppColors.success,
                    ),
                    onTap: () => widget.onNavigate(1, statusFilter: 'NO_DEPOSITO'),
                  ),
                  _ModernKpiCard(
                    title: 'Alocados em Setor',
                    value: '${metrics.noSetor}',
                    badgeText: 'Setores',
                    badgeColor: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    trailingWidget: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.domain_outlined, color: Color(0xFF8B5CF6), size: 18),
                    ),
                    onTap: () => widget.onNavigate(1, statusFilter: 'NO_SETOR'),
                  ),
                  _ModernKpiCard(
                    title: 'Cautelados em Missão',
                    value: '${metrics.cautelado}',
                    badgeText: 'Em Campo',
                    badgeColor: AppColors.warning,
                    isDark: isDark,
                    trailingWidget: const _PulseSparkline(color: AppColors.warning),
                    onTap: () => widget.onNavigate(2),
                  ),
                  _ModernKpiCard(
                    title: 'Em Manutenção',
                    value: '${metrics.manutencao}',
                    badgeText: 'Atenção',
                    badgeColor: AppColors.danger,
                    isDark: isDark,
                    trailingWidget: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                    ),
                    onTap: () => widget.onNavigate(3),
                  ),
                ];

                if (constraints.maxWidth >= 980) {
                  return Row(
                    children: [
                      for (int i = 0; i < kpiCards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: kpiCards[i]),
                      ],
                    ],
                  );
                }

                final columns = constraints.maxWidth >= 600 ? 3 : 2;
                final spacing = 12.0;
                final totalSpacing = spacing * (columns - 1);
                final itemWidth = (constraints.maxWidth - totalSpacing) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: kpiCards.map<Widget>((card) => SizedBox(width: itemWidth, child: card)).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // 3. SEÇÃO CENTRAL: FLUXO DE MOVIMENTAÇÕES + RADAR DE MISSÕES ATIVAS
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 920;
                final flowWidget = Container(
                    height: 280,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fluxo Operacional de Movimentações',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Movimentações de estoque vs Devoluções de Missões',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0E121B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.cyan,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('Saídas', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF818CF8),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('Devoluções', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: CustomPaint(
                            painter: _WaveChartPainter(isDark: isDark),
                            child: Container(),
                          ),
                        ),
                      ],
                    ),
                  );
                final missionsWidget = Container(
                    height: 280,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Missões e Cautelas Ativas',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.cyan.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_recentCautelas.length} ativas',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cyan,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => widget.onNavigate(2),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 24),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Ver todas', style: TextStyle(fontSize: 11, color: AppColors.cyan)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Row(
                            children: [
                              // Radar Visual Galeão
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                                ),
                                child: CustomPaint(
                                  painter: _RadarPainter(),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Lista de Missões
                              Expanded(
                                child: _isLoadingActivities
                                    ? const Center(child: CircularProgressIndicator())
                                    : _recentCautelas.isEmpty
                                        ? Center(
                                            child: Text(
                                              'Nenhuma missão ativa no momento.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          )
                                        : ListView.separated(
                                            itemCount: _recentCautelas.length,
                                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                                            itemBuilder: (ctx, i) {
                                              final c = _recentCautelas[i];
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF101520) : const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: AppColors.cyan,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            c.nome,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          Text(
                                                            '${c.itensCautelados} itens • ${c.tipo == 'MISSAO' ? 'Missão' : 'Fixa'}',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.arrow_forward_ios, size: 12),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (_) => CautelaDetailDialog(
                                                            cautela: c,
                                                            onUpdated: _loadDashboardActivities,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                if (isNarrow) {
                  return Column(
                    children: [
                      flowWidget,
                      const SizedBox(height: 16),
                      missionsWidget,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: flowWidget),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: missionsWidget),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // 4. SEÇÃO INFERIOR: DISTRIBUIÇÃO POR CATEGORIA + MOVIMENTAÇÕES RECENTES
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 920;
                final donutWidget = Container(
                    height: 260,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Distribuição por Categoria',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 110,
                                height: 110,
                                child: CustomPaint(
                                  painter: _DonutChartPainter(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _CategoryLegendItem(label: 'Notebooks & PCs', color: AppColors.cyan, isDark: isDark),
                                    const SizedBox(height: 6),
                                    _CategoryLegendItem(label: 'Servidores & Rack', color: const Color(0xFF38BDF8), isDark: isDark),
                                    const SizedBox(height: 6),
                                    _CategoryLegendItem(label: 'Rádios & Com.', color: const Color(0xFF818CF8), isDark: isDark),
                                    const SizedBox(height: 6),
                                    _CategoryLegendItem(label: 'Periféricos & Cabos', color: const Color(0xFFA855F7), isDark: isDark),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                final recentWidget = Container(
                    height: 260,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151D2A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Movimentações Recentes em Tempo Real',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () => widget.onNavigate(6),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(60, 24),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Ver histórico', style: TextStyle(fontSize: 11, color: AppColors.cyan)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Header da Tabela
                        Row(
                          children: [
                            const SizedBox(width: 100, child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                            const SizedBox(width: 100, child: Text('BMP / ITEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                            Expanded(child: Text('RESPONSÁVEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))),
                            const SizedBox(width: 110, child: Text('TIMESTAMP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          ],
                        ),
                        const Divider(height: 12),
                        Expanded(
                          child: _isLoadingActivities
                              ? const Center(child: CircularProgressIndicator())
                              : _recentMovements.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Nenhuma movimentação registrada recentemente.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _recentMovements.length,
                                      separatorBuilder: (_, __) => const Divider(height: 8, thickness: 0.5),
                                      itemBuilder: (ctx, i) {
                                        final m = _recentMovements[i];
                                        Color badgeColor;
                                        String badgeText = m.tipoMovimentacao;
                                        switch (m.tipoMovimentacao.toUpperCase()) {
                                          case 'DEVOLUCAO':
                                            badgeColor = AppColors.success;
                                            badgeText = 'Disponível';
                                            break;
                                          case 'TRANSFERENCIA':
                                          case 'CAUTELA':
                                            badgeColor = AppColors.cyan;
                                            badgeText = 'Cautela';
                                            break;
                                          default:
                                            badgeColor = AppColors.warning;
                                            badgeText = 'Manutenção';
                                        }

                                        return Row(
                                          children: [
                                            SizedBox(
                                              width: 100,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: badgeColor.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                                                  ),
                                                  child: Text(
                                                    badgeText,
                                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 100,
                                              child: Text(
                                                'BMP-${11000 + (m.itemId % 9000)}',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                m.itemNome ?? 'Material #${m.itemId}',
                                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                AppDateUtils.formatDateTime(m.criadoEm),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  );

                if (isNarrow) {
                  return Column(
                    children: [
                      donutWidget,
                      const SizedBox(height: 16),
                      recentWidget,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: donutWidget),
                    const SizedBox(width: 16),
                    Expanded(flex: 7, child: recentWidget),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Componentes Auxiliares Elegantes (Estilo LogiFlow)
// ---------------------------------------------------------------------------

class _ModernKpiCard extends StatefulWidget {
  final String title;
  final String value;
  final String badgeText;
  final Color badgeColor;
  final bool isDark;
  final Widget trailingWidget;
  final VoidCallback onTap;

  const _ModernKpiCard({
    required this.title,
    required this.value,
    required this.badgeText,
    required this.badgeColor,
    required this.isDark,
    required this.trailingWidget,
    required this.onTap,
  });

  @override
  State<_ModernKpiCard> createState() => _ModernKpiCardState();
}

class _ModernKpiCardState extends State<_ModernKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.identity()..translate(0.0, _isHovered ? -3.0 : 0.0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.isDark
                ? (_isHovered ? const Color(0xFF1B2438) : const Color(0xFF151D2A))
                : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.badgeColor.withOpacity(0.8)
                  : (widget.isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0)),
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.badgeColor.withOpacity(0.18)
                    : Colors.black.withOpacity(widget.isDark ? 0.3 : 0.04),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  widget.trailingWidget,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Mini Bar Sparkline
class _MiniBarSparkline extends StatelessWidget {
  final Color color;
  const _MiniBarSparkline({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(8, 0.4),
        const SizedBox(width: 3),
        _bar(14, 0.6),
        const SizedBox(width: 3),
        _bar(18, 0.8),
        const SizedBox(width: 3),
        _bar(12, 0.5),
        const SizedBox(width: 3),
        _bar(22, 1.0),
      ],
    );
  }

  Widget _bar(double h, double opacity) {
    return Container(
      width: 4,
      height: h,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// Mini Gauge Arc
class _GaugeArc extends StatelessWidget {
  final double ratio;
  final Color color;
  const _GaugeArc({required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 22,
      child: CustomPaint(
        painter: _GaugePainter(ratio: ratio, color: color),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double ratio;
  final Color color;
  _GaugePainter({required this.ratio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFF232B3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * ratio.clamp(0.0, 1.0),
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Pulse Sparkline
class _PulseSparkline extends StatelessWidget {
  final Color color;
  const _PulseSparkline({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 20,
      child: CustomPaint(
        painter: _PulseLinePainter(color: color),
      ),
    );
  }
}

class _PulseLinePainter extends CustomPainter {
  final Color color;
  _PulseLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..lineTo(size.width * 0.25, size.height * 0.5)
      ..lineTo(size.width * 0.4, 0)
      ..lineTo(size.width * 0.6, size.height)
      ..lineTo(size.width * 0.75, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Wave Chart Painter (LogiFlow neon wave chart)
class _WaveChartPainter extends CustomPainter {
  final bool isDark;
  _WaveChartPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grid horizontal lines
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF232B3E) : const Color(0xFFE2E8F0)).withOpacity(0.5)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = h * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Cyan curve (Saídas)
    final cyanPaint = Paint()
      ..color = AppColors.cyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cyanFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.cyan.withOpacity(0.25),
          AppColors.cyan.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final pathCyan = Path()
      ..moveTo(0, h * 0.7)
      ..cubicTo(w * 0.2, h * 0.2, w * 0.35, h * 0.9, w * 0.5, h * 0.3)
      ..cubicTo(w * 0.65, h * 0.6, w * 0.8, h * 0.1, w, h * 0.5);

    final fillPathCyan = Path.from(pathCyan)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(fillPathCyan, cyanFillPaint);
    canvas.drawPath(pathCyan, cyanPaint);

    // Indigo curve (Devoluções)
    final indigoPaint = Paint()
      ..color = const Color(0xFF818CF8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pathIndigo = Path()
      ..moveTo(0, h * 0.85)
      ..cubicTo(w * 0.2, h * 0.45, w * 0.35, h * 0.7, w * 0.5, h * 0.6)
      ..cubicTo(w * 0.65, h * 0.4, w * 0.8, h * 0.35, w, h * 0.4);

    canvas.drawPath(pathIndigo, indigoPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Radar Visual Galeão
class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = AppColors.cyan.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius * 0.35, ringPaint);
    canvas.drawCircle(center, radius * 0.7, ringPaint);
    canvas.drawCircle(center, radius * 0.95, ringPaint);

    // Cross lines
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), ringPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), ringPaint);

    // Sweep slice
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          AppColors.cyan.withOpacity(0.0),
          AppColors.cyan.withOpacity(0.35),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius * 0.95, sweepPaint);

    // Glowing blip points (Postos Operacionais)
    final blipPaint = Paint()..color = AppColors.cyan;
    canvas.drawCircle(Offset(center.dx + 15, center.dy - 20), 3, blipPaint);
    canvas.drawCircle(Offset(center.dx - 22, center.dy + 12), 2.5, blipPaint);
    canvas.drawCircle(Offset(center.dx + 18, center.dy + 25), 2.5, blipPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Donut Chart Painter
class _DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;

    void drawSegment(double startAngle, double sweepAngle, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    drawSegment(-math.pi / 2, 2.2, AppColors.cyan);
    drawSegment(0.8, 1.4, const Color(0xFF38BDF8));
    drawSegment(2.3, 1.1, const Color(0xFF818CF8));
    drawSegment(3.5, 0.8, const Color(0xFFA855F7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Legenda de Categoria
class _CategoryLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _CategoryLegendItem({required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
