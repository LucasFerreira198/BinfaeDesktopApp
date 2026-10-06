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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER DO MÓDULO DE MANUTENÇÃO
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 850;
                final titleColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEAB308), Color(0xFFCA8A04)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEAB308).withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.handyman_rounded, color: Colors.black, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Manutenção e Reparos de TI',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestão de bancada técnica, diagnóstico de falhas, conclusão de reparos e retorno ao acervo',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                );

                final badgesRow = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSummaryBadge(
                      label: 'Na Bancada',
                      count: stock.repairWaitingItems.length,
                      color: const Color(0xFFEAB308),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryBadge(
                      label: 'Falta Devolver',
                      count: stock.repairedItems.length,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleColumn,
                      const SizedBox(height: 12),
                      badgesRow,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    titleColumn,
                    badgesRow,
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // 2. BARRA DE CONTROLE: BUSCA E TAB BAR MODERNA
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 850;
                final searchWidget = Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131B2B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF232D42) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Buscar por material, BMP, defeito informado ou setor de origem...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    ),
                  );
                final tabWidget = Container(
                    height: 42,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131B2B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF232D42) : Colors.transparent,
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
                      unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      unselectedLabelStyle: const TextStyle(fontSize: 12),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.build_circle_outlined, size: 15, color: Color(0xFFEAB308)),
                              const SizedBox(width: 6),
                              const Text('Na Bancada / Aguardando'),
                              const SizedBox(width: 6),
                              _tabCounterBadge(stock.repairWaitingItems.length, const Color(0xFFEAB308), isDark),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              const Text('Consertados / Falta Devolver'),
                              const SizedBox(width: 6),
                              _tabCounterBadge(stock.repairedItems.length, const Color(0xFF10B981), isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchWidget,
                      const SizedBox(height: 10),
                      tabWidget,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 4, child: searchWidget),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: tabWidget),
                  ],
                );
              },
            ),

            const SizedBox(height: 18),

            // 3. CONTEÚDO DAS ABAS
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Aba 1: Na Bancada / Aguardando Reparo
                  _buildWaitingList(waitingItems, isDark, stock),

                  // Aba 2: Consertados / Falta Devolver
                  _buildRepairedList(repairedItems, isDark, stock),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ABA 1: ITENS AGUARDANDO REPARO ---
  Widget _buildWaitingList(List<ItemModel> items, bool isDark, StockProvider stock) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.task_alt_rounded,
        title: 'Nenhum material aguardando conserto!',
        subtitle: _searchQuery.isNotEmpty
            ? 'Nenhum item em reparo corresponde à busca "$_searchQuery".'
            : 'Todos os equipamentos estão operacionais ou já foram consertados.',
        isDark: isDark,
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final item = items[idx];
        return _buildMaintenanceCard(
          item: item,
          isRepairedTab: false,
          isDark: isDark,
          stock: stock,
        );
      },
    );
  }

  // --- ABA 2: ITENS CONSERTADOS / AGUARDANDO DEVOLUÇÃO ---
  Widget _buildRepairedList(List<ItemModel> items, bool isDark, StockProvider stock) {
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhum material pendente de devolução',
        subtitle: _searchQuery.isNotEmpty
            ? 'Nenhum item consertado corresponde à busca "$_searchQuery".'
            : 'Quando você concluir o reparo de um material, ele aparecerá aqui para ser devolvido ao setor de origem.',
        isDark: isDark,
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final item = items[idx];
        return _buildMaintenanceCard(
          item: item,
          isRepairedTab: true,
          isDark: isDark,
          stock: stock,
        );
      },
    );
  }

  // --- CARD MODERNO DE ITEM EM MANUTENÇÃO ---
  Widget _buildMaintenanceCard({
    required ItemModel item,
    required bool isRepairedTab,
    required bool isDark,
    required StockProvider stock,
  }) {
    final defectText = item.defeitoManutencao ?? 'Defeito técnico não especificado';
    final repairReport = item.laudoReparo;
    final originLocation = item.origemLocalNome;

    String dateStr = '';
    if (item.dataEntradaManutencao != null) {
      try {
        final dt = DateTime.parse(item.dataEntradaManutencao!).toLocal();
        dateStr = DateFormat("dd/MM/yyyy 'às' HH:mm").format(dt);
      } catch (_) {
        dateStr = item.dataEntradaManutencao!;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRepairedTab
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFFEAB308).withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1: Identificação, Nome, BMP e Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone do equipamento
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getItemIcon(item.nome),
                    size: 20,
                    color: isRepairedTab ? const Color(0xFF10B981) : const Color(0xFFEAB308),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Informações do Item
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.nome,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Badge de Status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isRepairedTab ? const Color(0xFF10B981) : const Color(0xFFEAB308)).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isRepairedTab ? const Color(0xFF10B981) : const Color(0xFFEAB308)).withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRepairedTab ? Icons.check_circle : Icons.handyman,
                                size: 12,
                                color: isRepairedTab ? const Color(0xFF10B981) : const Color(0xFFEAB308),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isRepairedTab ? 'Pronto p/ Devolução' : 'Na Bancada',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isRepairedTab ? const Color(0xFF10B981) : const Color(0xFFEAB308),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.bmp != null) ...[
                          Text(
                            'BMP: ${item.bmp}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.cyan,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (item.numeroSerie != null && item.numeroSerie!.isNotEmpty) ...[
                          Text(
                            'S/N: ${item.numeroSerie}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          'Cat: ${item.subgrupo?.nome ?? "Geral"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Linha 2: DESTAQUE DO TEXTO DO DEFEITO / ERRO RELATADO (Solicitado pelo Usuário)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B0E) : const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFEAB308).withOpacity(isDark ? 0.4 : 0.6),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFEAB308)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEFEITO INFORMADO / DIAGNÓSTICO:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFFEAB308),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        defectText,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFFEF08A) : const Color(0xFF713F12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Se estiver na aba de consertados, mostra também o laudo da solução realizada
          if (isRepairedTab && repairReport != null && repairReport.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D281E) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(isDark ? 0.4 : 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_outlined, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SERVIÇO REALIZADO / LAUDO TÉCNICO:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          repairReport,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Linha 3: Local de Origem + Data + Botões de Ação
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              // Metadados de Origem
              Row(
                children: [
                  Icon(
                    item.estaEmSetor ? Icons.domain_outlined : Icons.warehouse_outlined,
                    size: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Veio de: $originLocation',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.schedule,
                      size: 13,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),

              // Botões de Ação
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ItemDetailDialog(item: item),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: isDark ? const Color(0xFF2E3A52) : const Color(0xFFCBD5E1)),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('Ver Ficha', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 10),

                  if (!isRepairedTab)
                    // Botão para Concluir Reparo (Move para a Aba 2)
                    ElevatedButton.icon(
                      onPressed: () => _showCompleteRepairDialog(item, stock),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 15),
                      label: const Text('Concluir Reparo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  else
                    // Botão para Confirmar Devolução (Local antigo ou novo lugar)
                    ElevatedButton.icon(
                      onPressed: () => _showReturnDialog(item, stock),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.assignment_return_outlined, size: 16),
                      label: const Text('Confirmar Devolução', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MODAL: CONCLUIR REPARO (MOVE PARA ABA DE FALTA DEVOLVER) ---
  void _showCompleteRepairDialog(ItemModel item, StockProvider stock) {
    final reportController = TextEditingController(text: 'Reparo efetuado e testado na bancada técnica.');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF131B2B) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 10),
            const Text('Concluir Reparo Técnico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirma a finalização da manutenção de "${item.nome}"?',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'O material será movido para a aba "Consertados / Falta Devolver" para que o responsável realize a entrega.',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reportController,
                maxLines: 3,
                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Laudo Técnico / Serviço Realizado',
                  hintText: 'Ex: Substituída fonte de alimentação, desoxidação e limpeza interna...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await stock.moveItem(
                  itemId: item.id,
                  tipoMovimentacao: 'CONCLUIR_REPARO',
                  quantidade: item.quantidade,
                  motivo: reportController.text.trim().isNotEmpty ? reportController.text.trim() : 'Reparo concluído',
                );
                if (mounted) {
                  _tabController.animateTo(1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF10B981),
                      content: Text('Reparo concluído! O material foi movido para "Consertados / Falta Devolver".'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.danger, content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: const Text('Confirmar Conserto', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- MODAL: CONFIRMAR DEVOLUÇÃO (VOLTAR PRO LOCAL ANTIGO OU NOVO LUGAR) ---
  void _showReturnDialog(ItemModel item, StockProvider stock) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int? originalLocationId = item.origemLocalId;
    final String originalLocationName = item.origemLocalNome;

    // Modo de devolução: 'ORIGINAL' ou 'NOVO'
    String returnMode = (originalLocationId != null) ? 'ORIGINAL' : 'NOVO';
    int? selectedNewLocationId = originalLocationId;
    final noteController = TextEditingController(text: 'Material consertado e devolvido ao acervo');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: isDark ? const Color(0xFF131B2B) : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.assignment_return_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                const Text('Confirmar Devolução do Material', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Para onde deseja devolver "${item.nome}"?',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  // Opção 1: Voltar para o local antigo dele
                  if (originalLocationId != null) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setModalState(() => returnMode = 'ORIGINAL'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: returnMode == 'ORIGINAL'
                              ? AppColors.primary.withOpacity(0.12)
                              : (isDark ? const Color(0xFF1A2338) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: returnMode == 'ORIGINAL'
                                ? AppColors.primary
                                : (isDark ? const Color(0xFF2E3A52) : const Color(0xFFCBD5E1)),
                            width: returnMode == 'ORIGINAL' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: 'ORIGINAL',
                              groupValue: returnMode,
                              onChanged: (val) => setModalState(() => returnMode = val!),
                              activeColor: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Voltar para o local de origem anterior (Recomendado)',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '📍 $originalLocationName',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: returnMode == 'ORIGINAL' ? AppColors.primaryLight : Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Opção 2: Escolher um novo local
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setModalState(() => returnMode = 'NOVO'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: returnMode == 'NOVO'
                            ? AppColors.primary.withOpacity(0.12)
                            : (isDark ? const Color(0xFF1A2338) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: returnMode == 'NOVO'
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF2E3A52) : const Color(0xFFCBD5E1)),
                          width: returnMode == 'NOVO' ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Radio<String>(
                                value: 'NOVO',
                                groupValue: returnMode,
                                onChanged: (val) => setModalState(() => returnMode = val!),
                                activeColor: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Escolher um novo local físico / setor',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),

                          // Dropdown para escolher novo local caso a opção esteja ativa
                          if (returnMode == 'NOVO') ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: DropdownButtonFormField<int>(
                                value: selectedNewLocationId,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF151D2A) : Colors.white,
                                decoration: InputDecoration(
                                  labelText: 'Selecione o novo destino',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: stock.locations.map((loc) {
                                  final isSetor = loc.tipo?.toUpperCase() == 'SETOR';
                                  return DropdownMenuItem<int>(
                                    value: loc.id,
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSetor ? Icons.domain_outlined : Icons.warehouse_outlined,
                                          size: 14,
                                          color: isSetor ? const Color(0xFF8B5CF6) : AppColors.cyan,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isSetor ? 'Setor: ${loc.nome}' : (loc.caminhoCompleto ?? loc.nome),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSetor ? FontWeight.bold : FontWeight.normal,
                                              color: isSetor ? (isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9)) : null,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setModalState(() => selectedNewLocationId = val),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Observação da Devolução (Opcional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Confirmar Retorno ao Acervo', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final int? targetId = (returnMode == 'ORIGINAL') ? originalLocationId : selectedNewLocationId;
                  if (targetId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Selecione um local de destino para o material.')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  try {
                    await stock.moveItem(
                      itemId: item.id,
                      tipoMovimentacao: 'RETORNO_MANUTENCAO',
                      quantidade: item.quantidade,
                      destinoLocalId: targetId,
                      motivo: noteController.text.trim().isNotEmpty ? noteController.text.trim() : 'Retorno de manutenção',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text('Material devolvido com sucesso! Status atualizado para DISPONÍVEL.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: AppColors.danger, content: Text('Erro: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- HELPERS VISUAIS ---
  Widget _buildSummaryBadge({
    required String label,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabCounterBadge(int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getItemIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('optiplex') || lower.contains('computador') || lower.contains('desktop') || lower.contains('pc')) {
      return Icons.computer;
    } else if (lower.contains('notebook') || lower.contains('laptop') || lower.contains('dell')) {
      return Icons.laptop_chromebook;
    } else if (lower.contains('monitor') || lower.contains('tela')) {
      return Icons.desktop_windows_outlined;
    } else if (lower.contains('switch') || lower.contains('roteador') || lower.contains('cisco')) {
      return Icons.router_outlined;
    } else if (lower.contains('nobreak') || lower.contains('apc') || lower.contains('ups')) {
      return Icons.battery_charging_full_outlined;
    } else if (lower.contains('rádio') || lower.contains('ht') || lower.contains('motorola') || lower.contains('apx')) {
      return Icons.settings_remote_outlined;
    }
    return Icons.devices_other;
  }
}
