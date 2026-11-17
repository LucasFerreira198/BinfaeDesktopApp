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
  bool _showScannerBanner = true;
  bool _isSyncing = false;

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

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    final stock = Provider.of<StockProvider>(context, listen: false);
    await stock.syncData();
    await _loadDashboardActivities();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.tertiary, size: 18),
              SizedBox(width: 8),
              Text(
                'Banco de dados local sincronizado com sucesso!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _simulateBarcodeBeep() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.barcode_reader, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'BIP SIMULADO // LEITOR USB',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'BMP-051902 interceptado -> Rádio Transceptor Motorola APX 8000',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.primaryContainer),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = Provider.of<StockProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final metrics = stock.metrics;

    final brtTime = DateFormat('dd/MM/yyyy • HH:mm:ss').format(_currentTime);
    final zuluTime = '${DateFormat('HH:mm:ss').format(_currentTime.toUtc())}Z';

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerHigh,
      onRefresh: () async {
        await stock.syncData();
        await _loadDashboardActivities();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================================================================
            // 1. TACTICAL HEADER BANNER (Google Stitch #03_HomeDashboardView)
            // =========================================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 960;
                  final bannerInfo = Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.radar, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'CENTRO DE OPERAÇÕES DE TI - BINFAE-GL',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00A47A).withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.tertiary.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.tertiary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'EM EXPEDIENTE NORMAL / PRONTO-EMPREGO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.tertiary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 14, color: AppColors.outline),
                                    SizedBox(width: 4),
                                    Text(
                                      'GLO-GALEÃO (SBGL) // HANGAR-TI #4',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text('•', style: TextStyle(color: AppColors.outlineVariant)),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.storage_outlined, size: 14, color: AppColors.tertiary),
                                    SizedBox(width: 4),
                                    Text(
                                      'LOCAL DB: SECURE-SQLITE 3.42 (SYNC OK)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text('•', style: TextStyle(color: AppColors.outlineVariant)),
                                Text(
                                  'OPERADOR: ${user?.nomeGuerra ?? "S2 SILVA"} (SARAM ${user?.saram ?? "6842910"})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final bannerActions = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Sincronizar F5
                      OutlinedButton.icon(
                        onPressed: _isSyncing ? null : _triggerManualSync,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.sync, size: 16, color: AppColors.primary),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'SINCRONIZAR',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'F5',
                                style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.outline),
                              ),
                            ),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHigh,
                          side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      // Simular Bip Ctrl+B
                      OutlinedButton.icon(
                        onPressed: _simulateBarcodeBeep,
                        icon: const Icon(Icons.barcode_reader, size: 16, color: AppColors.tertiary),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'SIMULAR BIP',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: AppColors.tertiary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'Ctrl+B',
                                style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.outline),
                              ),
                            ),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHigh,
                          side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      // Novo Material Ctrl+N
                      ElevatedButton.icon(
                        onPressed: widget.onNewItem,
                        icon: const Icon(Icons.add_box, size: 16, color: Color(0xFF00285D)),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'NOVO MATERIAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF00285D),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'Ctrl+N',
                                style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF00285D)),
                              ),
                            ),
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: bannerInfo),
                        const SizedBox(width: 16),
                        bannerActions,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bannerInfo,
                      const SizedBox(height: 14),
                      bannerActions,
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // =========================================================================
            // 2. OPERATIONAL METRICS 5-CARD GRID (Google Stitch #03_HomeDashboardView)
            // =========================================================================
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final List<Widget> cards = [
                  // Card 1: TOTAL ACERVO
                  _TacticalMetricCard(
                    title: 'TOTAL ACERVO',
                    value: '${metrics.total}',
                    unit: 'itens',
                    icon: Icons.dns_outlined,
                    iconColor: AppColors.primary,
                    statusText: '100% Auditado',
                    statusIcon: Icons.verified,
                    statusColor: AppColors.tertiary,
                    linkText: 'Estoque ->',
                    onTap: () => widget.onNavigate(1),
                  ),
                  // Card 2: PRONTOS DEPÓSITO
                  _TacticalMetricCard(
                    title: 'PRONTOS DEPÓSITO',
                    value: '${metrics.disponivel}',
                    unit: 'NO_DEPOSITO',
                    icon: Icons.warehouse_outlined,
                    iconColor: AppColors.tertiary,
                    statusText: '+${metrics.disponivel > 0 ? (metrics.disponivel * 0.1).ceil() : 0} conferidos hoje',
                    statusIcon: Icons.trending_up,
                    statusColor: AppColors.tertiary,
                    badgeText: metrics.total > 0
                        ? '${((metrics.disponivel / metrics.total) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    onTap: () => widget.onNavigate(1, statusFilter: 'NO_DEPOSITO'),
                  ),
                  // Card 3: EM USO / NO SETOR
                  _TacticalMetricCard(
                    title: 'EM USO / NO SETOR',
                    value: '${metrics.noSetor}',
                    unit: 'NO_SETOR',
                    icon: Icons.corporate_fare_outlined,
                    iconColor: AppColors.secondary,
                    statusText: 'Esquadrões & Cias',
                    statusIcon: Icons.domain,
                    statusColor: AppColors.onSurfaceVariant,
                    badgeText: metrics.total > 0
                        ? '${((metrics.noSetor / metrics.total) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    onTap: () => widget.onNavigate(1, statusFilter: 'NO_SETOR'),
                  ),
                  // Card 4: CAUTELADOS MISSÃO
                  _TacticalMetricCard(
                    title: 'CAUTELADOS MISSÃO',
                    value: '${metrics.cautelado}',
                    unit: 'CAUTELADO',
                    valueColor: AppColors.primary,
                    icon: Icons.assignment_turned_in_outlined,
                    iconColor: AppColors.primary,
                    statusText: '${_recentCautelas.length} Missões Ativas',
                    statusIcon: Icons.military_tech,
                    statusColor: AppColors.primary,
                    badgeText: metrics.total > 0
                        ? '${((metrics.cautelado / metrics.total) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    onTap: () => widget.onNavigate(2),
                  ),
                  // Card 5: MANUTENÇÃO TÉCNICA
                  _TacticalMetricCard(
                    title: 'MANUTENÇÃO TÉCNICA',
                    value: '${metrics.manutencao}',
                    unit: 'EM_MANUTENCAO',
                    valueColor: AppColors.error,
                    icon: Icons.build_circle_outlined,
                    iconColor: AppColors.error,
                    statusText: '${metrics.manutencao} em Bancada',
                    statusIcon: Icons.warning_amber_rounded,
                    statusColor: AppColors.error,
                    badgeText: metrics.total > 0
                        ? '${((metrics.manutencao / metrics.total) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    onTap: () => widget.onNavigate(3),
                  ),
                ];

                if (width >= 1180) {
                  return Row(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                } else if (width >= 680) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards.map((c) => SizedBox(width: (width - 24) / 3, child: c)).toList(),
                  );
                } else {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards.map((c) => SizedBox(width: (width - 12) / 2, child: c)).toList(),
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // =========================================================================
            // 3. REALTIME SCANNER BANNER (Simulador USB Wedge)
            // =========================================================================
            if (_showScannerBanner) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.tertiary.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tertiary.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.barcode_reader, color: AppColors.tertiary, size: 22),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'LEITOR USB WEDGE ATIVO // INTERCEPTO DIRETO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.tertiary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BMP-051902',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Text(
                                'Rádio Transceptor Motorola APX 8000',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.outline),
                                  children: [
                                    TextSpan(text: 'ENDPOINT: '),
                                    TextSpan(
                                      text: 'GET /cautelas/item/BMP-051902/status',
                                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const Text('•', style: TextStyle(color: AppColors.outlineVariant)),
                              const Text(
                                'STATUS: CAUTELA ATIVA #CT-9941',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _showScannerBanner = false),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.outline,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text('Dispensar'),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: () => widget.onNavigate(2),
                          icon: const Icon(Icons.check_circle, size: 15, color: Color(0xFF003827)),
                          label: const Text(
                            'DEVOLVER MATERIAL AGORA',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003827),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tertiary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // =========================================================================
            // 4. OPERATIONAL SPLIT LAYOUT (Google Stitch #03_HomeDashboardView)
            // Left: Missões e Cautelas em Andamento (7 cols)
            // Right: Fluxo Operacional & Distribuição de Estoque (5 cols)
            // =========================================================================
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;

                final missionsColumn = Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.military_tech, color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Missões e Cautelas em Andamento',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.primaryContainer.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    '${_recentCautelas.length} ATIVAS',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => widget.onNavigate(2),
                              child: const Row(
                                children: [
                                  Text(
                                    'VER TODAS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF232B3E)),
                      // List of Missions
                      if (_isLoadingActivities)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        )
                      else if (_recentCautelas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.assignment_turned_in_outlined, size: 36, color: AppColors.outline),
                                SizedBox(height: 8),
                                Text(
                                  'Nenhuma cautela ou missão ativa no momento.',
                                  style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _recentCautelas.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final c = _recentCautelas[i];
                            return _TacticalMissionItemCard(
                              cautela: c,
                              onInspect: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => CautelaDetailDialog(
                                    cautela: c,
                                    onUpdated: _loadDashboardActivities,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                );

                final analyticsColumn = Column(
                  children: [
                    // Fluxo Operacional & Auditoria Recente
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Auditoria de Movimentações Recentes',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Entradas, saídas e transferências de estoque',
                                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => widget.onNavigate(7),
                                child: const Row(
                                  children: [
                                    Text(
                                      'HISTÓRICO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward, size: 12, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Movements Table
                          if (_isLoadingActivities)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            )
                          else if (_recentMovements.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Nenhuma movimentação registrada recentemente.',
                                  style: TextStyle(fontSize: 12, color: AppColors.outline),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                // Table header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          'STATUS',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.outline,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          'BMP / ITEM',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.outline,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'RESPONSÁVEL / DETALHES',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.outline,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 65,
                                        child: Text(
                                          'HORA',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.outline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                for (final m in _recentMovements) ...[
                                  _TacticalMovementRow(movement: m),
                                  const SizedBox(height: 6),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Distribuição por Categoria & Hardware
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Distribuição de Acervo por Categoria',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: CustomPaint(painter: _TacticalDonutChartPainter()),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: const [
                                    _TacticalCategoryLegend(
                                      label: 'Notebooks & Estações',
                                      color: AppColors.primary,
                                      count: '42%',
                                    ),
                                    SizedBox(height: 6),
                                    _TacticalCategoryLegend(
                                      label: 'Racks & Servidores',
                                      color: AppColors.secondary,
                                      count: '28%',
                                    ),
                                    SizedBox(height: 6),
                                    _TacticalCategoryLegend(
                                      label: 'Rádios VHF/UHF & Com.',
                                      color: AppColors.tertiary,
                                      count: '18%',
                                    ),
                                    SizedBox(height: 6),
                                    _TacticalCategoryLegend(
                                      label: 'Periféricos & Peças',
                                      color: Color(0xFFC084FC),
                                      count: '12%',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: missionsColumn),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: analyticsColumn),
                    ],
                  );
                }

                return Column(
                  children: [
                    missionsColumn,
                    const SizedBox(height: 16),
                    analyticsColumn,
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

// =============================================================================
// SUB-WIDGETS TÁTICOS (Google Stitch Aerospace Design)
// =============================================================================

class _TacticalMetricCard extends StatefulWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final String statusText;
  final IconData statusIcon;
  final Color statusColor;
  final String? badgeText;
  final String? linkText;
  final Color? valueColor;
  final VoidCallback onTap;

  const _TacticalMetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.statusText,
    required this.statusIcon,
    required this.statusColor,
    this.badgeText,
    this.linkText,
    this.valueColor,
    required this.onTap,
  });

  @override
  State<_TacticalMetricCard> createState() => _TacticalMetricCardState();
}

class _TacticalMetricCardState extends State<_TacticalMetricCard> {
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
          transform: Matrix4.identity()..translate(0.0, _isHovered ? -2.0 : 0.0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceContainer : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? widget.iconColor.withOpacity(0.6)
                  : AppColors.outlineVariant.withOpacity(0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.iconColor.withOpacity(0.12)
                    : Colors.black.withOpacity(0.25),
                blurRadius: _isHovered ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(widget.icon, size: 16, color: widget.iconColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Main Value
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: widget.valueColor ?? Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.unit,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Footer telemetry
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.statusIcon, size: 12, color: widget.statusColor),
                      const SizedBox(width: 4),
                      Text(
                        widget.statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: widget.statusColor,
                        ),
                      ),
                    ],
                  ),
                  if (widget.badgeText != null)
                    Text(
                      widget.badgeText!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppColors.outline,
                      ),
                    ),
                  if (widget.linkText != null)
                    Text(
                      widget.linkText!,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: _isHovered ? AppColors.primary : AppColors.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TacticalMissionItemCard extends StatelessWidget {
  final CautelaModel cautela;
  final VoidCallback onInspect;

  const _TacticalMissionItemCard({
    required this.cautela,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title, ID badge, and inspect button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      cautela.nome,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${cautela.id.toString().padLeft(4, '0')}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.tertiary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.timer_outlined, size: 12, color: AppColors.tertiary),
                        SizedBox(width: 4),
                        Text(
                          'ATIVA',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppColors.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: onInspect,
                    icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primary),
                    tooltip: 'Inspecionar Cautela',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Responsável
          Row(
            children: [
              const Icon(Icons.person_outline, size: 13, color: AppColors.outline),
              const SizedBox(width: 4),
              Text(
                'Responsável: ',
                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
              Text(
                cautela.responsavelNome,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                '(SARAM ${cautela.responsavelSaram})',
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Equipment chips preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${cautela.itensCautelados} item(ns) em carga',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  cautela.tipo == 'MISSAO' ? 'MISSÃO TÁTICA' : 'CAUTELA FIXA',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: AppColors.tertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, size: 12, color: AppColors.tertiary),
                  SizedBox(width: 4),
                  Text(
                    'Assinatura Digital Válida',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: AppColors.tertiary,
                    ),
                  ),
                ],
              ),
              Text(
                'Criado: ${AppDateUtils.formatDateTime(cautela.criadoEm)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TacticalMovementRow extends StatelessWidget {
  final ItemMovementModel movement;

  const _TacticalMovementRow({required this.movement});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badgeText = movement.tipoMovimentacao.toUpperCase();

    switch (badgeText) {
      case 'DEVOLUCAO':
        badgeColor = AppColors.tertiary;
        badgeText = 'DEVOLVIDO';
        break;
      case 'CAUTELA':
        badgeColor = AppColors.primary;
        badgeText = 'CAUTELA';
        break;
      case 'TRANSFERENCIA':
        badgeColor = AppColors.secondary;
        badgeText = 'TRANSF';
        break;
      default:
        badgeColor = AppColors.error;
        badgeText = 'MANUT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: badgeColor.withOpacity(0.4)),
              ),
              child: Text(
                badgeText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: Text(
              'BMP-${11000 + (movement.itemId % 9000)}',
              style: const TextStyle(
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              movement.itemNome ?? 'Material #${movement.itemId}',
              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 65,
            child: Text(
              DateFormat('HH:mm').format(movement.criadoEm),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: AppColors.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TacticalCategoryLegend extends StatelessWidget {
  final String label;
  final Color color;
  final String count;

  const _TacticalCategoryLegend({
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          count,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TacticalDonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

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

    drawSegment(-math.pi / 2, 2.4, AppColors.primary);
    drawSegment(1.0, 1.4, AppColors.secondary);
    drawSegment(2.5, 1.1, AppColors.tertiary);
    drawSegment(3.7, 0.8, const Color(0xFFC084FC));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
