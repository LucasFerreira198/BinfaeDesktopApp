import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/stock_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/item_detail_dialog.dart';

class MaintenanceView extends StatefulWidget {
  final void Function(int targetIndex)? onNavigate;

  const MaintenanceView({super.key, this.onNavigate});

  @override
  State<MaintenanceView> createState() => _MaintenanceViewState();
}

class _MaintenanceViewState extends State<MaintenanceView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stock = Provider.of<StockProvider>(context);

    final waitingItems = stock.repairWaitingItems.where((i) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return i.nome.toLowerCase().contains(q) ||
          (i.bmp?.toLowerCase().contains(q) ?? false) ||
          (i.codigoInterno?.toLowerCase().contains(q) ?? false) ||
          (i.numeroSerie?.toLowerCase().contains(q) ?? false) ||
          (i.defeitoManutencao?.toLowerCase().contains(q) ?? false) ||
          i.origemLocalNome.toLowerCase().contains(q);
    }).toList();

    final repairedItems = stock.repairedItems.where((i) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return i.nome.toLowerCase().contains(q) ||
          (i.bmp?.toLowerCase().contains(q) ?? false) ||
          (i.codigoInterno?.toLowerCase().contains(q) ?? false) ||
          (i.numeroSerie?.toLowerCase().contains(q) ?? false) ||
          (i.defeitoManutencao?.toLowerCase().contains(q) ?? false) ||
          (i.laudoReparo?.toLowerCase().contains(q) ?? false) ||
          i.origemLocalNome.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================================
          // 1. TACTICAL SUBHEADER & ACTIONS (Google Stitch #06_MaintenanceView)
          // =========================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;

                final headerInfo = Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.handyman_outlined, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              const Text(
                                'BANCADA TÉCNICA & GESTÃO DE MANUTENÇÃO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'MOD-04 // LAB-TI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.tertiary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BAGL SEC-TEC',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: AppColors.tertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Diagnósticos de hardware militar, laudos de conformidade eletrônica e controle de reincorporação ao acervo.',
                            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => stock.syncData(),
                      icon: const Icon(Icons.sync, size: 15, color: AppColors.tertiary),
                      label: const Text('Sincronizar', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => widget.onNavigate?.call(1),
                      icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF00285D)),
                      label: const Text(
                        '+ Nova OS / Entrada',
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF00285D)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: headerInfo),
                      const SizedBox(width: 14),
                      actionButtons,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    const SizedBox(height: 12),
                    actionButtons,
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 2. LIVE TRIAGE COUNTERS (Google Stitch #06_MaintenanceView)
          // =========================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final counters = [
                _buildTriageCard('Na Bancada / Diagnóstico', '${stock.repairWaitingItems.length}', 'ATIVAS', Icons.precision_manufacturing, AppColors.error),
                _buildTriageCard('Aguardando Peça / RMA', '00', 'ESPERA', Icons.hourglass_top, AppColors.secondary),
                _buildTriageCard('Consertados / Pronto Retorno', '${stock.repairedItems.length}', 'PRONTOS', Icons.check_circle_outline, AppColors.tertiary),
                _buildTriageCard('Concluídos Este Mês', '14', 'TOTAL', Icons.verified, AppColors.primary),
              ];

              if (width >= 900) {
                return Row(
                  children: [
                    for (int i = 0; i < counters.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: counters[i]),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: counters.map((c) => SizedBox(width: (width - 10) / 2, child: c)).toList(),
              );
            },
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 3. TAB CONTROLLER & SEARCH BAR (Google Stitch #06_MaintenanceView)
          // =========================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 880;

              final searchInput = Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar por material, BMP, defeito informado ou setor de origem...',
                    hintStyle: const TextStyle(fontSize: 11, color: AppColors.outline),
                    prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 14, color: AppColors.outline),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              );

              final tabsBar = Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  labelStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.build_circle_outlined, size: 14, color: AppColors.error),
                          const SizedBox(width: 6),
                          const Text('Na Bancada / Aguardando'),
                          const SizedBox(width: 6),
                          _buildCountBadge('${waitingItems.length}', AppColors.error),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: AppColors.tertiary),
                          const SizedBox(width: 6),
                          const Text('Consertados / Falta Devolver'),
                          const SizedBox(width: 6),
                          _buildCountBadge('${repairedItems.length}', AppColors.tertiary),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 5, child: searchInput),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: tabsBar),
                  ],
                );
              }

              return Column(
                children: [
                  searchInput,
                  const SizedBox(height: 10),
                  tabsBar,
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // =========================================================================
          // 4. TAB VIEWS CONTENT (Google Stitch #06_MaintenanceView)
          // =========================================================================
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWaitingTab(waitingItems, stock),
                _buildRepairedTab(repairedItems, stock),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTriageCard(String title, String count, String tag, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.outline),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 22,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tag,
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  static Widget _buildCountBadge(String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count,
        style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildWaitingTab(List<ItemModel> items, StockProvider stock) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_outlined, size: 48, color: AppColors.tertiary.withOpacity(0.6)),
            const SizedBox(height: 10),
            const Text(
              'Bancada liberada! Nenhum material pendente de reparo.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return _TacticalMaintenanceCard(
          item: item,
          isRepaired: false,
          onConclude: () => _openConcludeRepairDialog(item, stock),
          onInspect: () {
            showDialog(
              context: context,
              builder: (_) => ItemDetailDialog(item: item, onNavigateView: widget.onNavigate),
            );
          },
        );
      },
    );
  }

  Widget _buildRepairedTab(List<ItemModel> items, StockProvider stock) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.outline.withOpacity(0.5)),
            const SizedBox(height: 10),
            const Text(
              'Nenhum material consertado aguardando devolução.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return _TacticalMaintenanceCard(
          item: item,
          isRepaired: true,
          onReturn: () async {
            await stock.returnRepairedItem(item.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  content: Text('Material ${item.nome} devolvido ao acervo com sucesso!', style: const TextStyle(color: AppColors.tertiary)),
                ),
              );
            }
          },
          onInspect: () {
            showDialog(
              context: context,
              builder: (_) => ItemDetailDialog(item: item, onNavigateView: widget.onNavigate),
            );
          },
        );
      },
    );
  }

  void _openConcludeRepairDialog(ItemModel item, StockProvider stock) {
    final laudoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.tertiary),
        ),
        title: Row(
          children: const [
            Icon(Icons.verified, color: AppColors.tertiary, size: 20),
            SizedBox(width: 8),
            Text('Laudo Técnico & Conclusão de Reparo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Material: ${item.nome} (${item.bmp ?? "S/N"})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12.5)),
              const SizedBox(height: 4),
              Text('Defeito inicial: ${item.defeitoManutencao ?? "Não especificado"}', style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 14),
              const Text('Laudo Técnico / Ações Realizadas:', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              TextField(
                controller: laudoCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 12.5, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Descreva os reparos realizados, componentes substituídos e testes efetuados...',
                  hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.outline)),
          ),
          ElevatedButton(
            onPressed: () async {
              final laudo = laudoCtrl.text.trim();
              if (laudo.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    content: Text('Por favor, informe o laudo técnico do reparo.', style: TextStyle(color: AppColors.warning)),
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              await stock.concludeRepair(item.id, laudo);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    content: Text('Reparo do item ${item.nome} concluído!', style: const TextStyle(color: AppColors.tertiary)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tertiary,
              foregroundColor: const Color(0xFF003827),
            ),
            child: const Text('Concluir Reparo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _TacticalMaintenanceCard extends StatelessWidget {
  final ItemModel item;
  final bool isRepaired;
  final VoidCallback? onConclude;
  final VoidCallback? onReturn;
  final VoidCallback onInspect;

  const _TacticalMaintenanceCard({
    required this.item,
    required this.isRepaired,
    this.onConclude,
    this.onReturn,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isRepaired ? AppColors.tertiary : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: BMP, Title, OS Badge, Inspect button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.bmp ?? 'BMP-${item.id.toString().padLeft(6, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      item.nome,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        isRepaired ? 'CONSERTADO / PRONTO' : 'EM MANUTENÇÃO',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onInspect,
                icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primary),
                tooltip: 'Inspecionar Material',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Diagnostic / Defect box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.error),
                    const SizedBox(width: 4),
                    const Text('Defeito Informado: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error)),
                    Expanded(
                      child: Text(
                        item.defeitoManutencao ?? 'Falha técnica reportada pelo operador',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isRepaired && item.laudoReparo != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 13, color: AppColors.tertiary),
                      const SizedBox(width: 4),
                      const Text('Laudo Técnico: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
                      Expanded(
                        child: Text(
                          item.laudoReparo!,
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Origem: ${item.origemLocalNome} • S/N: ${item.numeroSerie ?? "N/A"}',
                style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppColors.outline),
              ),
              if (!isRepaired && onConclude != null)
                ElevatedButton.icon(
                  onPressed: onConclude,
                  icon: const Icon(Icons.check_circle, size: 14, color: Color(0xFF003827)),
                  label: const Text('Emitir Laudo / Concluir', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF003827))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                )
              else if (isRepaired && onReturn != null)
                ElevatedButton.icon(
                  onPressed: onReturn,
                  icon: const Icon(Icons.assignment_return, size: 14, color: Color(0xFF00285D)),
                  label: const Text('Devolver ao Setor / Depósito', style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF00285D))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
